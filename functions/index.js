/**
 * SpotIT Cloud Functions
 *
 * Firebase Cloud Functions for the SpotIT civic-reporting platform.
 * Project: spotit-lk | Region: asia-south1
 */

const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

// -- Initialise Firebase Admin SDK -------------------------------------------
admin.initializeApp();
const db = admin.firestore(); // eslint-disable-line no-unused-vars

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
