/**
 * SpotIT Cloud Functions
 *
 * Firebase Cloud Functions for the SpotIT civic-reporting platform.
 * Project: spotit-lk | Region: asia-south1
 */

const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/v2/https");
const {beforeUserCreated} = require("firebase-functions/v2/identity");
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

  // Return empty object — we are not modifying the user record
  return {};
});
