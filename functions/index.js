/**
 * SpotIT Cloud Functions — Backend Logic
 *
 * Firebase Cloud Functions handle all server-side work for SpotIT:
 * - Validating and creating complaints
 * - Sending push notifications to citizens and officials
 * - Handling upvotes and comments
 * - Automatically setting up user profiles on sign-up
 *
 * Region: asia-south1 (Mumbai — closest to Sri Lanka)
 */

// Import the parts of the Firebase Functions SDK we need
const {setGlobalOptions} = require("firebase-functions/v2/options");
const {onRequest, onCall, HttpsError} = require("firebase-functions/v2/https");
const {user: authUser} = require("firebase-functions/v1/auth");
const {onDocumentCreated, onDocumentUpdated} =
  require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

// Initialise Firebase Admin — gives us server-level access to Firestore,
// Auth, and Firebase Messaging (no API key needed on the server side)
admin.initializeApp();
const db = admin.firestore(); // shortcut to the Firestore database

// Constants used for validating complaints
const REPORT_CATEGORIES = ["Road", "Infrastructure", "Waste", "Other"];
const REPORT_STATUSES = ["Pending", "In Progress", "Resolved"];
const MAX_REPORT_IMAGES = 5;
const MAX_REPORT_IMAGE_BYTES = 10 * 1024 * 1024; // 10 MB in bytes
const MAX_COMMENT_LENGTH = 1000; // characters

// Validates all the fields in a complaint before it's saved to Firestore.
// Returns an array of error messages. If the array is empty, the data is valid.
function validateReportDraft(payload) {
  const errors = [];

  // Title must exist and be between 5 and 120 characters
  const title = (payload.title || "").trim();
  if (!title) {
    errors.push("Title is required.");
  } else if (title.length < 5 || title.length > 120) {
    errors.push("Title must be 5-120 characters.");
  }

  // Description must exist and be between 10 and 1000 characters
  const description = (payload.description || "").trim();
  if (!description) {
    errors.push("Description is required.");
  } else if (description.length < 10 || description.length > 1000) {
    errors.push("Description must be 10-1000 characters.");
  }

  // Category must be one of the allowed values
  if (!REPORT_CATEGORIES.includes(payload.category)) {
    errors.push("Category is not supported.");
  }

  // Author ID is required so we know who submitted the complaint
  if (!payload.authorId || String(payload.authorId).trim() === "") {
    errors.push("Author ID is required.");
  }

  // Location name can be empty but can't be too long
  if (payload.locationName && payload.locationName.length > 120) {
    errors.push("Location name is too long.");
  }

  // Latitude and longitude must both be provided or both be absent
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

  // Image URLs must start with http or https to be valid
  if (payload.imageUrl) {
    const imageUrl = String(payload.imageUrl);
    if (!imageUrl.startsWith("http://") &&
        !imageUrl.startsWith("https://")) {
      errors.push("Image URL must be http/https.");
    }
  }

  // Validate each URL in an imageUrls array if provided
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

  // Validate each object in an images array if provided (has url + sizeBytes)
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

// Set default options for all functions — max 10 instances to control costs
setGlobalOptions({maxInstances: 10, region: "asia-south1"});

// ─── sendNotification (internal helper) ──────────────────────────────────────
// This is not exported — it's only called internally by other Cloud Functions.
// It does two things for every notification:
//   1. Saves the notification to Firestore (users/{uid}/notifications)
//      so the citizen/official can see it in the Notifications page
//   2. Sends a push notification to the user's device via FCM
//      so they see a banner even when the app is closed
async function sendNotification(uid, title, body, extra = {}) {
  // Step 1: Save to Firestore for in-app notification history
  await db.collection("users").doc(uid)
      .collection("notifications").add({
        title,
        body,
        read: false, // starts as unread
        createdAt:
        admin.firestore.FieldValue.serverTimestamp(),
        ...extra, // spread in any extra fields like chatId, type, complaintId
      });

  // Step 2: Send a push notification via FCM
  // We first read the user's document to get their FCM token.
  // The token uniquely identifies their device for push delivery.
  const userSnap = await db
      .collection("users").doc(uid).get();
  const fcmToken = userSnap.exists ?
    userSnap.data().fcmToken : null;

  if (fcmToken) {
    // FCM requires all data payload values to be strings — convert them here
    const stringData = {};
    for (const [key, value] of Object.entries(extra)) {
      stringData[key] = String(value || "");
    }

    try {
      await admin.messaging().send({
        token: fcmToken,             // which device to deliver to
        notification: {title, body}, // shown in the system notification bar
        data: stringData,            // extra data the app can read silently
        android: {
          priority: "high", // wake the device even if battery saver is on
          notification: {
            channelId: "spotit_notifications", // must match channel ID in Flutter
            priority: "high",
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        },
        apns: {
          // On iPhone, priority 10 means deliver immediately (not batched)
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              alert: {title, body},
              sound: "default", // use the default notification sound
              badge: 1,         // show a badge count on the app icon
            },
          },
        },
      });
      logger.info(`Push notification sent to ${uid}: ${title}`);
    } catch (err) {
      // Log the failure but don't crash — the Firestore notification is still saved
      logger.warn(`FCM push failed for ${uid}`, err);
    }
  } else {
    // User hasn't saved an FCM token yet (maybe they denied permission)
    // The notification is still saved in Firestore so they can see it in-app
    logger.info(
        `No FCM token for ${uid}, ` +
      `notification stored in Firestore only`,
    );
  }
}

// ─── Health Check ─────────────────────────────────────────────────────────────
// A simple HTTP endpoint to verify the Cloud Functions are running.
// Call: GET https://<region>-<project>.cloudfunctions.net/healthCheck
exports.healthCheck = onRequest((req, res) => {
  logger.info("Health-check hit", {structuredData: true});
  res.status(200).json({
    status: "ok",
    project: "spotit-lk",
    timestamp: new Date().toISOString(),
  });
});

// ─── Auto-create user profile on sign-up ──────────────────────────────────────
// This Firestore trigger fires every time a new account is created via Firebase Auth
// (e.g. Google Sign-In, email/password). It creates a profile document in the
// 'users' collection so the app can store extra fields like name and role.
exports.onUserCreated = authUser().onCreate((userRecord) => {
  const uid = userRecord.uid;

  // Default profile — all new accounts start as citizens
  const profile = {
    displayName: userRecord.displayName || "",
    email: userRecord.email || "",
    photoURL: userRecord.photoURL || "",
    role: "citizen", // can be changed to "government" via setUserRole
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  logger.info(`Creating profile for new user: ${uid}`, {uid, profile});

  // Write the profile to users/{uid}
  return db.collection("users").doc(uid).set(profile).catch((err) => {
    logger.error(`Failed to create profile for ${uid}`, err);
  });
});

// ─── Complaint created trigger ─────────────────────────────────────────────────
// Runs automatically when a new document appears in the 'complaints' collection.
// It validates required fields, sets default values, and notifies all officials.
exports.onComplaintCreated = onDocumentCreated(
    "complaints/{complaintId}",
    async (event) => {
      const snap = event.data;
      if (!snap) return;

      const data = snap.data();
      const complaintId = event.params.complaintId;

      // Check all required fields exist — delete the document if anything is missing
      const requiredFields = ["title", "description", "category", "authorId"];
      const missing = requiredFields.filter((f) => !data[f]);

      if (missing.length > 0) {
        logger.warn(
            `Complaint ${complaintId} missing fields: ${missing.join(", ")}`,
        );
        await snap.ref.delete(); // remove the invalid document
        return;
      }

      // Apply default values for any fields the client didn't provide
      const defaults = {};
      if (!data.status) defaults.status = "Pending";                   // default status
      if (data.upvoteCount === undefined) defaults.upvoteCount = 0;    // start at 0 upvotes
      if (data.commentCount === undefined) defaults.commentCount = 0;  // start at 0 comments
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

      // Notify every government official so they can review the new complaint
      try {
        const officialsSnap = await db.collection("users")
            .where("role", "==", "government").get();

        // Use author's name unless they chose to remain anonymous
        const authorName = data.isAnonymous ?
          "Anonymous Citizen" :
          (data.authorName || "A citizen");

        // Send a notification to each official in parallel
        const notifPromises = [];
        officialsSnap.forEach((officialDoc) => {
          const officialUid = officialDoc.id;
          if (officialUid === data.authorId) return; // don't notify themselves
          notifPromises.push(
              sendNotification(
                  officialUid,
                  "New Complaint Reported",
                  `${authorName} reported: "${data.title}"`,
                  {
                    complaintId,
                    type: "new_complaint",
                    category: data.category || "",
                  },
              ),
          );
        });
        await Promise.all(notifPromises); // wait for all to finish
        logger.info(
            `Notified ${notifPromises.length} officials ` +
          `about complaint ${complaintId}`,
        );
      } catch (err) {
        logger.warn(
            `Failed to notify officials for ${complaintId}`,
            err,
        );
      }
    },
);

// ─── Complaint status update trigger ──────────────────────────────────────────
// Runs when any complaint document is updated.
// If the status changed (e.g. "Pending" → "In Progress"), this:
//   1. Records the change in a statusHistory array for audit purposes
//   2. Notifies the complaint's author with the new status
exports.onComplaintUpdated = onDocumentUpdated(
    "complaints/{complaintId}",
    async (event) => {
      const before = event.data.before.data(); // data before the update
      const after = event.data.after.data();   // data after the update
      const complaintId = event.params.complaintId;

      // Only do anything if the status field actually changed
      if (before.status === after.status) return;

      // Build a history entry recording the transition
      const transition = {
        from: before.status,
        to: after.status,
        changedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      logger.info(
          `Complaint ${complaintId} status: ` +
      `${before.status} -> ${after.status}`,
      );

      // Append the transition to an array on the complaint document
      await event.data.after.ref.update({
        statusHistory:
        admin.firestore.FieldValue.arrayUnion(
            transition, // arrayUnion adds to the array without making duplicates
        ),
      });

      // Notify the original complainant that their status changed
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

// ─── Toggle upvote (callable) ──────────────────────────────────────────────────
// Called from the app when a user taps the upvote button on a complaint.
// Uses a Firestore transaction to ensure atomic updates — either both the
// subcollection doc and the count update, or neither does.
exports.toggleUpvote = onCall(async (request) => {
  // Reject if the user is not logged in
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
      .collection("upvotes").doc(uid); // one doc per user per complaint

  // A transaction reads and writes atomically — no concurrent users can interfere
  const result = await db.runTransaction(async (tx) => {
    const complaintSnap = await tx.get(complaintRef);
    if (!complaintSnap.exists) {
      throw new HttpsError("not-found", "Complaint not found.");
    }

    const upvoteSnap = await tx.get(upvoteRef);

    if (upvoteSnap.exists) {
      // User already upvoted — remove it (toggle off)
      tx.delete(upvoteRef);
      tx.update(complaintRef, {
        upvoteCount: admin.firestore.FieldValue.increment(-1), // decrease count
        upvotedBy: admin.firestore.FieldValue.arrayRemove(uid),
      });
      return {upvoted: false};
    } else {
      // User hasn't upvoted yet — add their upvote (toggle on)
      tx.set(upvoteRef, {
        createdAt:
          admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.update(complaintRef, {
        upvoteCount: admin.firestore.FieldValue.increment(1), // increase count
        upvotedBy: admin.firestore.FieldValue.arrayUnion(uid),
      });
      return {upvoted: true};
    }
  });

  logger.info(
      `User ${uid} ` +
    `${result.upvoted ? "upvoted" : "removed upvote from"} ` +
    `complaint ${complaintId}`,
  );
  return result; // returned to the Flutter app so it can update the UI
});

// ─── Add comment (callable) ────────────────────────────────────────────────────
// Called from the app when a user submits a comment on a complaint.
// Creates the comment doc and increments the comment count atomically.
exports.addComment = onCall(async (request) => {
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

  // Make sure the complaint actually exists before we write to it
  const complaintSnap = await complaintRef.get();
  if (!complaintSnap.exists) {
    throw new HttpsError("not-found", "Complaint not found.");
  }

  // Look up the author's display name and role from their profile
  const userSnap = await db
      .collection("users").doc(uid).get();
  const authorName = userSnap.exists ?
    userSnap.data().displayName || "Anonymous" :
    "Anonymous";
  const role = userSnap.exists ? userSnap.data().role : null;
  const isOfficial = role === "government" || role === "official";

  // Create the comment document in the complaints/{id}/comments subcollection
  const commentDoc = await commentsRef.add({
    authorId: uid,
    authorName,
    text: cleanText,
    parentCommentId: parentCommentId || null, // null for top-level comments
    isOfficial, // true if the commenter is a government official
    timestamp:
      admin.firestore.FieldValue.serverTimestamp(),
  });

  // Increment the comment count on the complaint document
  await complaintRef.update({
    commentCount:
      admin.firestore.FieldValue.increment(1),
  });

  logger.info(
      `Comment ${commentDoc.id} added to ` +
    `complaint ${complaintId} by ${uid}`,
  );

  return {
    commentId: commentDoc.id,
    authorName,
  };
});

// ─── Create report (callable) ──────────────────────────────────────────────────
// Called from the Flutter app when a citizen submits a new complaint.
// Validates the data server-side before writing to Firestore.
exports.createReport = onCall(async (request) => {
  if (!request.auth) {
    throw new Error("You must be signed in to submit a report.");
  }

  const uid = request.auth.uid;
  const payload = request.data || {};

  // Run all field validations and throw if any fail
  const errors = validateReportDraft(payload);
  if (errors.length > 0) {
    throw new Error(errors.join(" "));
  }

  // Parse coordinates to numbers (they might arrive as strings from the app)
  const latitude = payload.latitude !== undefined ?
    Number(payload.latitude) : null;
  const longitude = payload.longitude !== undefined ?
    Number(payload.longitude) : null;

  // Build the complaint document
  const report = {
    title: payload.title.trim(),
    description: payload.description.trim(),
    category: payload.category,
    status: REPORT_STATUSES.includes(payload.status) ?
      payload.status : "Pending", // default to Pending if not provided
    upvoteCount: 0,
    commentCount: 0,
    authorId: payload.authorId,
    imageUrl: payload.imageUrl || "",
    locationName: payload.locationName || "",
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  // Only include geo fields if both lat and lng were provided
  if (latitude !== null && longitude !== null) {
    report.latitude = latitude;
    report.longitude = longitude;
    // GeoPoint is a Firestore type used for geospatial queries
    report.position = {
      geopoint: new admin.firestore.GeoPoint(latitude, longitude),
    };
  }

  const docRef = await db.collection("complaints").add(report);

  logger.info(`Report ${docRef.id} created by ${uid}`);

  return {id: docRef.id}; // app uses this ID to navigate to the complaint detail
});

// ─── Get dashboard stats (callable, gov only) ──────────────────────────────────
// Returns complaint counts grouped by status and category.
// Only accessible by users with the "government" role.
exports.getDashboardStats = onCall(async (request) => {
  if (!request.auth) {
    throw new Error("Authentication required.");
  }

  const uid = request.auth.uid;

  // Check the caller has a government role before returning any data
  const userSnap = await db
      .collection("users").doc(uid).get();
  if (!userSnap.exists ||
    userSnap.data().role !== "government") {
    throw new Error(
        "Access denied. Government role required.",
    );
  }

  // Fetch all complaints and build the stats object
  const snap = await db
      .collection("complaints").get();

  const stats = {
    total: 0,
    byStatus: {
      "Pending": 0,
      "In Progress": 0,
      "Resolved": 0,
    },
    byCategory: {}, // built dynamically based on what categories exist
  };

  snap.forEach((doc) => {
    const data = doc.data();
    stats.total++;

    // Bucket by status
    const status = data.status || "Pending";
    if (stats.byStatus[status] !== undefined) {
      stats.byStatus[status]++;
    } else {
      stats.byStatus[status] = 1;
    }

    // Bucket by category
    const cat = data.category || "Uncategorized";
    stats.byCategory[cat] =
      (stats.byCategory[cat] || 0) + 1;
  });

  logger.info(`Dashboard stats requested by ${uid}`, {stats});
  return stats;
});

// ─── Set user role (callable, admin only) ──────────────────────────────────────
// Lets a government account promote another user to "government" or demote them
// back to "citizen". Also sets Firebase Auth custom claims so security rules
// can enforce role-based access.
exports.setUserRole = onCall(async (request) => {
  if (!request.auth) {
    throw new Error("Authentication required.");
  }

  const callerUid = request.auth.uid;
  const {targetUid, role} = request.data;

  // Only allow valid roles
  const validRoles = ["citizen", "government"];
  if (!targetUid || !role || !validRoles.includes(role)) {
    throw new Error(
        "targetUid and role (citizen|government) " +
      "are required.",
    );
  }

  // Only government users are allowed to change roles
  const callerSnap = await db
      .collection("users").doc(callerUid).get();
  if (!callerSnap.exists ||
    callerSnap.data().role !== "government") {
    throw new Error(
        "Access denied. Government role required.",
    );
  }

  // Set the custom claims on the Firebase Auth account
  // These claims are embedded in the user's ID token and checked by security rules
  await admin.auth()
      .setCustomUserClaims(targetUid, {role});

  // Also update the Firestore profile so the app can read the role directly
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

// ─── Chat message notification trigger ────────────────────────────────────────
// Runs every time a new message document is created under:
// chats/{chatId}/messages/{messageId}
//
// It reads the parent chat document to find out who the sender and recipient are,
// then sends a push notification to the other person.
exports.onChatMessageCreated = onDocumentCreated(
    "chats/{chatId}/messages/{messageId}",
    async (event) => {
      const snap = event.data;
      if (!snap) return;

      const messageData = snap.data();
      const chatId = event.params.chatId;
      const senderId = messageData.senderId || "";

      // Read the parent chat doc to find the participants
      const chatDoc = await db.collection("chats").doc(chatId).get();
      if (!chatDoc.exists) {
        logger.warn(`Chat ${chatId} not found for message notification`);
        return;
      }

      const chat = chatDoc.data();
      const officialId = chat.officialId || "";
      const citizenId = chat.citizenId || "";

      // Figure out who to notify — the person who did NOT send this message
      let recipientId = "";
      let senderLabel = "";
      if (senderId === officialId) {
        // Official sent the message → notify the citizen
        recipientId = citizenId;
        senderLabel = chat.officialName || "Government Official";
      } else if (senderId === citizenId) {
        // Citizen sent the message → notify the official
        recipientId = officialId;
        senderLabel = chat.citizenName || "Citizen";
      } else {
        // Sender is neither participant — something is wrong
        logger.warn(`Unknown sender ${senderId} in chat ${chatId}`);
        return;
      }

      if (!recipientId) {
        logger.info(`No recipient to notify for chat ${chatId}`);
        return;
      }

      // Truncate the message to 100 characters for the notification preview
      const messageText = (messageData.text || "").substring(0, 100);

      // Send the notification with chatId and type so the app can open the right chat
      await sendNotification(
          recipientId,
          `Message from ${senderLabel}`,
          messageText || "Sent a message",
          {
            chatId,
            complaintId: chat.complaintId || "",
            type: "chat_message", // used by the notifications page to make the card tappable
          },
      );

      logger.info(
          `Chat notification sent: ${senderId} -> ${recipientId} ` +
        `in chat ${chatId}`,
      );
    },
);

// ─── Mark all notifications as read (callable) ────────────────────────────────
// Called from the app when the user presses "Mark all read".
// Batch-updates up to 'limit' notification documents to read: true.
exports.markAllNotificationsRead =
  onCall(async (request) => {
    if (!request.auth) {
      throw new HttpsError(
          "unauthenticated",
          "You must be signed in.",
      );
    }

    const uid = request.auth.uid;
    const limit = Math.min(
        Number(request.data?.limit) || 100,
        500, // hard cap to avoid overloading Firestore
    );

    // Find all unread notifications for this user
    const snap = await db
        .collection("users")
        .doc(uid)
        .collection("notifications")
        .where("read", "==", false)
        .limit(limit)
        .get();

    if (snap.empty) return {updated: 0};

    // Use a batch write so all updates happen in one network request
    const batch = db.batch();
    snap.docs.forEach((doc) => {
      batch.update(doc.ref, {read: true});
    });
    await batch.commit();

    logger.info(
        `Marked ${snap.size} notifications as read for ${uid}`,
    );
    return {updated: snap.size};
  });
