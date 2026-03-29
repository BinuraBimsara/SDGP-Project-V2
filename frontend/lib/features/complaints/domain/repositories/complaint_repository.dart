import 'package:image_picker/image_picker.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';

// ComplaintRepository is an abstract interface — a contract that defines
// what data operations the complaints feature needs.
// The actual Firestore code lives in FirestoreComplaintRepository.
//
// Why use this pattern? It makes the UI code independent of the database.
// You could swap Firestore for any other backend by writing a new class
// that implements this interface and changing one line in main.dart.
abstract class ComplaintRepository {

  // Fetches all complaints from the database.
  // Optional filters: category narrows the results; userLat/userLng makes
  // the results sort by distance from the user's location.
  Future<List<Complaint>> getComplaints({
    String? category,
    double? userLat,
    double? userLng,
  });

  // Fetches a single complaint by its Firestore document ID.
  // Returns null if it doesn't exist (e.g. was deleted).
  Future<Complaint?> getComplaintById(String id);

  // Creates a new complaint in the database.
  // If images are provided they get uploaded to Firebase Storage and the
  // URLs are saved on the complaint document.
  // Returns the created complaint with its auto-generated ID.
  Future<Complaint> createComplaint(Complaint complaint, {List<XFile>? images});

  // Adds or removes the current user's upvote on a complaint.
  // Handled by a Cloud Function so the upvote counter can't be manipulated.
  // Returns the updated complaint with the new count.
  Future<Complaint> toggleUpvote(String complaintId);

  // Adds a comment to a complaint.
  // parentCommentId is set when replying to an existing comment (nested reply).
  // isOfficial marks the comment as coming from a government official.
  // Returns the new total comment count on the complaint.
  Future<int> addComment(
    String complaintId,
    String author,
    String text, {
    required String authorId,
    String? parentCommentId,
    bool isOfficial = false,
  });

  // Fetches all comments for a complaint, ordered oldest first.
  // Returns each comment as a Map with: id, author, authorId, text,
  // parentCommentId, isOfficial, and timestamp.
  Future<List<Map<String, dynamic>>> getComments(String complaintId);

  // Deletes a comment. Also deletes any replies nested under it,
  // and subtracts the total deleted count from the complaint's commentCount.
  Future<void> deleteComment(String complaintId, String commentId);

  // Overwrites the commentCount field on a complaint with a specific number.
  // Used to fix mismatches if the count drifts out of sync with reality.
  Future<void> syncCommentCount(String complaintId, int count);

  // Changes the status of a complaint (Pending / In Progress / Resolved).
  // Returns the complaint with the updated status.
  Future<Complaint> updateStatus(String complaintId, String newStatus);

  // Permanently deletes a complaint and all its comments.
  // Only the original author should call this.
  Future<void> deleteComplaint(String complaintId);
}
