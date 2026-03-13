/**
 * SpotIT Cloud Functions
 *
 * Firebase Cloud Functions for the SpotIT civic-reporting platform.
 * Project: spotit-lk | Region: asia-south1
 */

const {setGlobalOptions} = require("firebase-functions/v2/options");
const {onRequest, onCall, HttpsError} = require("firebase-functions/v2/https");
const {beforeUserCreated} = require("firebase-functions/v2/identity");
const {onDocumentCreated, onDocumentUpdated} =
  require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

// -- Initialise Firebase Admin SDK -------------------------------------------
admin.initializeApp();
const db = admin.firestore();

// -- Report constants -------------------------------------------------------
const REPORT_CATEGORIES = ["Road", "Infrastructure", "Waste", "Other"];
const REPORT_STATUSES = ["Pending", "In Progress", "Resolved"];
const MAX_REPORT_IMAGES = 5;
const MAX_REPORT_IMAGE_BYTES = 10 * 1024 * 1024;
const MAX_COMMENT_LENGTH = 1000;

function validateReportDraft(payload) {
  const errors = [];

  const title = (payload.title || "").trim();
  if (!title) {
    errors.push("Title is required.");
  } else if (title.length < 5 || title.length > 120) {
    errors.push("Title must be 5-120 characters.");
  }

  const description = (payload.description || "").trim();
  if (!description) {
    errors.push("Description is required.");
  } else if (description.length < 10 || description.length > 1000) {
    errors.push("Description must be 10-1000 characters.");
  }

  if (!REPORT_CATEGORIES.includes(payload.category)) {
    errors.push("Category is not supported.");
  }

  if (!payload.authorId || String(payload.authorId).trim() === "") {
    errors.push("Author ID is required.");
  }

  if (payload.locationName && payload.locationName.length > 120) {
    errors.push("Location name is too long.");
  }

  const hasLat = payload.latitude !== undefined && payload.latitude !== null;
  const hasLng = payload.longitude !== undefined && payload.longitude !== null;
  if (hasLat !== hasLng) {
    errors.push("Latitude and longitude must be provided together.");
  } else if (hasLat && hasLng) {
    const lat = Number(payload.latitude);
    const lng = Number(payload.longitude);
    if (Number.isNaN(lat) || lat < -90 || lat > 90) {
      errors.push("Latitude must be -90 to 90.");
    }
    if (Number.isNaN(lng) || lng < -180 || lng > 180) {
      errors.push("Longitude must be -180 to 180.");
    }
  }

  if (payload.imageUrl) {
    const imageUrl = String(payload.imageUrl);
    if (!imageUrl.startsWith("http://") &&
        !imageUrl.startsWith("https://")) {
      errors.push("Image URL must be http/https.");
    }
  }

  if (Array.isArray(payload.imageUrls)) {
    if (payload.imageUrls.length > MAX_REPORT_IMAGES) {
      errors.push("Max 5 images are allowed.");
    }
    payload.imageUrls.forEach((url) => {
      const imageUrl = String(url || "");
      if (!imageUrl.startsWith("http://") &&
          !imageUrl.startsWith("https://")) {
        errors.push("Image URL must be http/https.");
      }
    });
  }

  if (Array.isArray(payload.images)) {
    if (payload.images.length > MAX_REPORT_IMAGES) {
      errors.push("Max 5 images are allowed.");
    }
    payload.images.forEach((image) => {
      const imageUrl = String((image || {}).url || "");
      if (!imageUrl.startsWith("http://") &&
          !imageUrl.startsWith("https://")) {
        errors.push("Image URL must be http/https.");
      }
      if (image && image.sizeBytes !== undefined) {
        const sizeBytes = Number(image.sizeBytes);
        if (Number.isNaN(sizeBytes) || sizeBytes < 0) {
          errors.push("Image size must be a positive number.");
        } else if (sizeBytes > MAX_REPORT_IMAGE_BYTES) {
          errors.push("Each image must be 10MB or less.");
        }
      }
    });
  }

  return errors;
}

// -- Global options ----------------------------------------------------------
setGlobalOptions({maxInstances: 10, region: "asia-south1"});

// -- Notification helper (internal) ------------------------------------------
// Sends a push notification via FCM and stores it in Firestore
// for in-app notification history.
/**
 * Send a notification to a user via FCM and store in Firestore.
 * @param {string} uid  - Target user's UID
 * @param {string} title - Notification title
 * @param {string} body  - Notification body text
 * @param {object} [extra] - Optional extra data payload
 */
async function sendNotification(uid, title, body, extra = {}) {
  // 1. Store in Firestore for in-app history
  await db.collection("users").doc(uid)
      .collection("notifications").add({
        title,
        body,
        read: false,
        createdAt:
        admin.firestore.FieldValue.serverTimestamp(),
        ...extra,
      });

  // 2. Try sending FCM push (needs fcmToken on user doc)
  const userSnap = await db
      .collection("users").doc(uid).get();
  const fcmToken = userSnap.exists ?
    userSnap.data().fcmToken : null;

  if (fcmToken) {
    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: {title, body},
        data: extra,
      });
      logger.info(
          `Push sent to ${uid}: ${title}`,
      );
    } catch (err) {
      logger.warn(
          `FCM send failed for ${uid}`, err,
      );
    }
  } else {
    logger.info(
        `No FCM token for ${uid}, ` +
      `notification stored in Firestore only`,
    );
  }
}

/**
 * Queue upvote notifications and emit one alert for each group of 5 new upvotes.
 * @param {string} authorId
 * @param {string} complaintId
 * @param {string} complaintTitle
 */
async function handleUpvoteNotification(authorId, complaintId, complaintTitle) {
  const stateRef = db.collection("users").doc(authorId)
      .collection("notificationState").doc(`upvotes_${complaintId}`);

  const stateSnap = await stateRef.get();
  const pending = stateSnap.exists ?
    (stateSnap.data().pendingUpvotes || 0) : 0;

  const nextPending = pending + 1;

  if (nextPending >= 5) {
    const remainder = nextPending - 5;
    await sendNotification(
        authorId,
        "Report Upvoted",
        "Your report receives 5 new upvotes",
        {complaintId, complaintTitle, type: "upvote"},
    );

    await stateRef.set({
      pendingUpvotes: remainder,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return;
  }

  await stateRef.set({
    pendingUpvotes: nextPending,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
}

// -- Health-check endpoint ---------------------------------------------------
// GET /healthCheck -> verifies the functions runtime is alive
exports.healthCheck = onRequest((req, res) => {
  logger.info("Health-check hit", {structuredData: true});
  res.status(200).json({
    status: "ok",
    project: "spotit-lk",
    timestamp: new Date().toISOString(),
  });
});

// -- Auto-create user profile on sign-up -------------------------------------
// Triggered when a new user is created via Firebase Auth (e.g. Google Sign-In).
// Creates a profile document at users/{uid} with default citizen role.
exports.onUserCreated = beforeUserCreated((event) => {
  const user = event.data;
  const uid = user.uid;

  const profile = {
    displayName: user.displayName || "",
    email: user.email || "",
    photoURL: user.photoURL || "",
    role: "citizen",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  logger.info(`Creating profile for new user: ${uid}`, {uid, profile});

  // Write to Firestore (fire-and-forget; blocking auth is not needed)
  db.collection("users").doc(uid).set(profile).catch((err) => {
    logger.error(`Failed to create profile for ${uid}`, err);
  });

  // Return empty object -- we are not modifying the user record
  return {};
});

// -- Complaint creation validation -------------------------------------------
// Triggered when a new document is created in the complaints collection.
// Validates required fields and auto-sets server-side defaults.
exports.onComplaintCreated = onDocumentCreated(
    "complaints/{complaintId}",
    async (event) => {
      const snap = event.data;
      if (!snap) return;

      const data = snap.data();
      const complaintId = event.params.complaintId;

      // Validate required fields
      const requiredFields = ["title", "description", "category", "authorId"];
      const missing = requiredFields.filter((f) => !data[f]);

      if (missing.length > 0) {
        logger.warn(
            `Complaint ${complaintId} missing fields: ${missing.join(", ")}`,
        );
        // Delete the invalid document
        await snap.ref.delete();
        return;
      }

      // Auto-set server-side defaults
      const defaults = {};
      if (!data.status) defaults.status = "Pending";
      if (data.upvoteCount === undefined) defaults.upvoteCount = 0;
      if (data.commentCount === undefined) defaults.commentCount = 0;
      if (!data.createdAt) {
        defaults.createdAt = admin.firestore.FieldValue.serverTimestamp();
      }

      if (Object.keys(defaults).length > 0) {
        await snap.ref.update(defaults);
        logger.info(
            `Complaint ${complaintId} defaults applied`,
            {complaintId, defaults},
        );
      }

      logger.info(`Complaint ${complaintId} created successfully`);
    },
);

// -- Complaint status update trigger -----------------------------------------
// Triggered when a complaint document is updated.
// If the status field changed, logs the transition into a statusHistory array.
exports.onComplaintUpdated = onDocumentUpdated(
    "complaints/{complaintId}",
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();
      const complaintId = event.params.complaintId;

      // Only act when status actually changed
      if (before.status === after.status) return;

      const transition = {
        from: before.status,
        to: after.status,
        changedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      logger.info(
          `Complaint ${complaintId} status: ` +
      `${before.status} -> ${after.status}`,
      );

      await event.data.after.ref.update({
        statusHistory:
        admin.firestore.FieldValue.arrayUnion(
            transition,
        ),
      });

      // Notify the complaint author about the change
      const authorId = after.authorId;
      if (authorId) {
        await sendNotification(
            authorId,
            "Complaint Status Updated",
            `Your complaint "${after.title}" ` +
        `changed from ${before.status} ` +
        `to ${after.status}.`,
            {complaintId, newStatus: after.status},
        );
      }
    },
);

// -- Toggle upvote (callable) ------------------------------------------------
// Atomically toggles a user's upvote on a complaint.
// Maintains a subcollection complaints/{id}/upvotes/{uid}.
exports.toggleUpvote = onCall({enforceAppCheck: true}, async (request) => {
  // Require authentication
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in to upvote.");
  }

  const uid = request.auth.uid;
  const {complaintId} = request.data;

  if (!complaintId || typeof complaintId !== "string") {
    throw new HttpsError("invalid-argument", "complaintId is required.");
  }

  const complaintRef = db.collection("complaints").doc(complaintId);
  const upvoteRef = complaintRef
      .collection("upvotes").doc(uid);

  const result = await db.runTransaction(async (tx) => {
    const complaintSnap = await tx.get(complaintRef);
    if (!complaintSnap.exists) {
      throw new HttpsError("not-found", "Complaint not found.");
    }

    const complaintData = complaintSnap.data() || {};
    const currentUpvotes = Number(complaintData.upvoteCount || 0);
    const authorId = complaintData.authorId || "";
    const complaintTitle = complaintData.title || "your report";

    const upvoteSnap = await tx.get(upvoteRef);

    if (upvoteSnap.exists) {
      // Remove upvote
      tx.delete(upvoteRef);
      tx.update(complaintRef, {
        upvoteCount: admin.firestore.FieldValue.increment(-1),
      });
      return {
        upvoted: false,
        authorId,
        complaintTitle,
        nextUpvoteCount: Math.max(0, currentUpvotes - 1),
      };
    } else {
      // Add upvote
      tx.set(upvoteRef, {
        createdAt:
          admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.update(complaintRef, {
        upvoteCount: admin.firestore.FieldValue.increment(1),
      });
      return {
        upvoted: true,
        authorId,
        complaintTitle,
        nextUpvoteCount: currentUpvotes + 1,
      };
    }
  });

  if (result.upvoted && result.authorId && result.authorId !== uid) {
    await handleUpvoteNotification(
        result.authorId,
        complaintId,
        result.complaintTitle || "your report",
    );
  }

  logger.info(
      `User ${uid} ` +
    `${result.upvoted ? "upvoted" : "removed upvote from"} ` +
    `complaint ${complaintId}`,
  );
  return result;
});

// -- Add comment (callable) --------------------------------------------------
// Creates a comment document and increments commentCount atomically.
exports.addComment = onCall({enforceAppCheck: true}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in to comment.");
  }

  const uid = request.auth.uid;
  const {complaintId, text, parentCommentId} = request.data;

  if (!complaintId || typeof complaintId !== "string") {
    throw new HttpsError("invalid-argument", "complaintId is required.");
  }

  if (!text || typeof text !== "string") {
    throw new HttpsError("invalid-argument", "text is required.");
  }

  const cleanText = text.trim();
  if (!cleanText) {
    throw new HttpsError("invalid-argument", "Comment text cannot be empty.");
  }
  if (cleanText.length > MAX_COMMENT_LENGTH) {
    throw new HttpsError(
        "invalid-argument",
        `Comment text must be ${MAX_COMMENT_LENGTH} characters or less.`,
    );
  }

  const complaintRef = db
      .collection("complaints").doc(complaintId);
  const commentsRef = complaintRef.collection("comments");

  const complaintSnap = await complaintRef.get();
  if (!complaintSnap.exists) {
    throw new HttpsError("not-found", "Complaint not found.");
  }
  const complaintData = complaintSnap.data() || {};

  // Fetch author display name from user profile
  const userSnap = await db
      .collection("users").doc(uid).get();
  const authorName = userSnap.exists ?
    userSnap.data().displayName || "Anonymous" :
    "Anonymous";
  const role = userSnap.exists ? userSnap.data().role : null;
  const isOfficial = role === "government" || role === "official";

  // Create the comment document
  const commentDoc = await commentsRef.add({
    authorId: uid,
    authorName,
    text: cleanText,
    parentCommentId: parentCommentId || null,
    isOfficial,
    timestamp:
      admin.firestore.FieldValue.serverTimestamp(),
  });

  // Increment comment count on the complaint
  await complaintRef.update({
    commentCount:
      admin.firestore.FieldValue.increment(1),
  });

  logger.info(
      `Comment ${commentDoc.id} added to ` +
    `complaint ${complaintId} by ${uid}`,
  );

  const complaintAuthorId = complaintData.authorId || "";
  const complaintTitle = complaintData.title || "your report";
  if (complaintAuthorId && complaintAuthorId !== uid) {
    const commentActor = isOfficial ?
      "A government official" :
      "A user";
    await sendNotification(
        complaintAuthorId,
        "New Comment",
        `${commentActor} commented on \"${complaintTitle}\"`,
        {
          complaintId,
          commentId: commentDoc.id,
          type: "comment",
          isOfficialComment: isOfficial,
        },
    );
  }

  return {
    commentId: commentDoc.id,
    authorName,
  };
});

// -- Create report (callable) -----------------------------------------------
// Validates and creates a complaint document in Firestore.
exports.createReport = onCall(async (request) => {
  if (!request.auth) {
    throw new Error("You must be signed in to submit a report.");
  }

  const uid = request.auth.uid;
  const payload = request.data || {};

  const errors = validateReportDraft(payload);
  if (errors.length > 0) {
    throw new Error(errors.join(" "));
  }

  const latitude = payload.latitude !== undefined ?
    Number(payload.latitude) : null;
  const longitude = payload.longitude !== undefined ?
    Number(payload.longitude) : null;

  const report = {
    title: payload.title.trim(),
    description: payload.description.trim(),
    category: payload.category,
    status: REPORT_STATUSES.includes(payload.status) ?
      payload.status : "Pending",
    upvoteCount: 0,
    commentCount: 0,
    authorId: payload.authorId,
    imageUrl: payload.imageUrl || "",
    locationName: payload.locationName || "",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (latitude !== null && longitude !== null) {
    report.latitude = latitude;
    report.longitude = longitude;
    report.position = {
      geopoint: new admin.firestore.GeoPoint(latitude, longitude),
    };
  }

  const docRef = await db.collection("complaints").add(report);

  logger.info(
      `Report ${docRef.id} created by ${uid}`,
  );

  return {id: docRef.id};
});

// -- Dashboard stats (callable, gov only) ------------------------------------
// Returns aggregated complaint statistics for the government dashboard.
// Restricted to users with role "government" in their profile.
exports.getDashboardStats = onCall(async (request) => {
  if (!request.auth) {
    throw new Error("Authentication required.");
  }

  const uid = request.auth.uid;

  // Check user role
  const userSnap = await db
      .collection("users").doc(uid).get();
  if (!userSnap.exists ||
    userSnap.data().role !== "government") {
    throw new Error(
        "Access denied. Government role required.",
    );
  }

  // Fetch all complaints
  const snap = await db
      .collection("complaints").get();

  const stats = {
    total: 0,
    byStatus: {
      "Pending": 0,
      "In Progress": 0,
      "Resolved": 0,
    },
    byCategory: {},
  };

  snap.forEach((doc) => {
    const data = doc.data();
    stats.total++;

    // Count by status
    const status = data.status || "Pending";
    if (stats.byStatus[status] !== undefined) {
      stats.byStatus[status]++;
    } else {
      stats.byStatus[status] = 1;
    }

    // Count by category
    const cat = data.category || "Uncategorized";
    stats.byCategory[cat] =
      (stats.byCategory[cat] || 0) + 1;
  });

  logger.info(
      `Dashboard stats requested by ${uid}`,
      {stats},
  );
  return stats;
});

// -- Set user role (callable, admin-only) ------------------------------------
// Assigns a role (citizen / government) to a user.
// Only existing government users can promote others.
exports.setUserRole = onCall(async (request) => {
  if (!request.auth) {
    throw new Error("Authentication required.");
  }

  const callerUid = request.auth.uid;
  const {targetUid, role} = request.data;

  // Validate inputs
  const validRoles = ["citizen", "government"];
  if (!targetUid || !role || !validRoles.includes(role)) {
    throw new Error(
        "targetUid and role (citizen|government) " +
      "are required.",
    );
  }

  // Only government users can assign roles
  const callerSnap = await db
      .collection("users").doc(callerUid).get();
  if (!callerSnap.exists ||
    callerSnap.data().role !== "government") {
    throw new Error(
        "Access denied. Government role required.",
    );
  }

  // Set custom claims on the target user
  await admin.auth()
      .setCustomUserClaims(targetUid, {role});

  // Update Firestore profile
  await db.collection("users").doc(targetUid)
      .update({role});

  logger.info(
      `User ${callerUid} set role of ` +
    `${targetUid} to ${role}`,
  );

  return {
    success: true,
    targetUid,
    role,
  };
});

