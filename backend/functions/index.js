const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Example: Send notification when a complaint gets 10+ upvotes
// exports.onUpvoteMilestone = functions.firestore
//   .document("complaints/{complaintId}")
//   .onUpdate(async (change, context) => {
//     const before = change.before.data();
//     const after = change.after.data();
//     if (before.upvoteCount < 10 && after.upvoteCount >= 10) {
//       // Send push notification to complaint author
//     }
//   });

// Placeholder — add your Cloud Functions here
exports.helloWorld = functions.https.onRequest((req, res) => {
    res.send("SpotIT Backend is running!");
});
