/**
 * SpotIT Cloud Functions
 *
 * Firebase Cloud Functions for the SpotIT civic-reporting platform.
 * Project: spotit-lk | Region: asia-south1
 */

const {setGlobalOptions} = require("firebase-functions");
const {onRequest, onCall} = require("firebase-functions/v2/https");
const {beforeUserCreated} = require("firebase-functions/v2/identity");
const {onDocumentCreated, onDocumentUpdated} =
  require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

// -- Initialise Firebase Admin SDK -------------------------------------------
admin.initializeApp();
const db = admin.firestore();

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
exports.toggleUpvote = onCall(async (request) => {
  // Require authentication
  if (!request.auth) {
    throw new Error("You must be signed in to upvote.");
  }

  const uid = request.auth.uid;
  const {complaintId} = request.data;

  if (!complaintId) {
    throw new Error("complaintId is required.");
  }

  const complaintRef = db.collection("complaints").doc(complaintId);
  const upvoteRef = complaintRef
      .collection("upvotes").doc(uid);

  const result = await db.runTransaction(async (tx) => {
    const upvoteSnap = await tx.get(upvoteRef);

    if (upvoteSnap.exists) {
      // Remove upvote
      tx.delete(upvoteRef);
      tx.update(complaintRef, {
        upvoteCount: admin.firestore.FieldValue.increment(-1),
      });
      return {upvoted: false};
    } else {
      // Add upvote
      tx.set(upvoteRef, {
        createdAt:
          admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.update(complaintRef, {
        upvoteCount: admin.firestore.FieldValue.increment(1),
      });
      return {upvoted: true};
    }
  });

  logger.info(
      `User ${uid} ` +
    `${result.upvoted ? "upvoted" : "removed upvote from"} ` +
    `complaint ${complaintId}`,
  );
  return result;
});

// -- Add comment (callable) --------------------------------------------------
// Creates a comment document and increments commentCount atomically.
exports.addComment = onCall(async (request) => {
  if (!request.auth) {
    throw new Error("You must be signed in to comment.");
  }

  const uid = request.auth.uid;
  const {complaintId, text} = request.data;

  if (!complaintId || !text) {
    throw new Error(
        "complaintId and text are required.",
    );
  }

  const complaintRef = db
      .collection("complaints").doc(complaintId);
  const commentsRef = complaintRef.collection("comments");

  // Fetch author display name from user profile
  const userSnap = await db
      .collection("users").doc(uid).get();
  const authorName = userSnap.exists ?
    userSnap.data().displayName || "Anonymous" :
    "Anonymous";

  // Create the comment document
  const commentDoc = await commentsRef.add({
    authorId: uid,
    authorName,
    text,
    createdAt:
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

  return {
    commentId: commentDoc.id,
    authorName,
  };
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

