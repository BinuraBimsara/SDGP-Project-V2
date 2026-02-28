/**
 * SpotIT Cloud Functions
 *
 * Firebase Cloud Functions for the SpotIT civic-reporting platform.
 * Project: spotit-lk | Region: asia-south1
 */

const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/v2/https");
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
        statusHistory: admin.firestore.FieldValue.arrayUnion(transition),
      });
    },
);
