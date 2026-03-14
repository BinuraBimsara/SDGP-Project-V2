import 'package:image_picker/image_picker.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';

/// Abstract repository interface for complaint operations.
///
/// To switch databases, create a new class that implements this interface
/// (e.g., PostgresComplaintRepository, SupabaseComplaintRepository)
/// and swap it in main.dart.
abstract class ComplaintRepository {
  /// Fetch all complaints, optionally filtered by [category].
  Future<List<Complaint>> getComplaints({
    String? category,
    double? userLat,
    double? userLng,
  });

  /// Fetch a single complaint by its [id].
  Future<Complaint?> getComplaintById(String id);

  /// Create a new complaint. Optionally attach [images] to upload.
  /// Returns the created complaint with its ID.
  Future<Complaint> createComplaint(Complaint complaint, {List<XFile>? images});

  /// Toggle the upvote on a complaint for the current user.
  /// Returns the updated complaint.
  Future<Complaint> toggleUpvote(String complaintId);

  /// Add a comment to a complaint. Returns the updated comment count.
  /// [authorId] is the Firebase UID of the commenter.
  /// [parentCommentId] is set when replying to an existing comment.
  /// [isOfficial] marks the comment as from a government official.
  Future<int> addComment(
    String complaintId,
    String author,
    String text, {
    required String authorId,
    String? parentCommentId,
    bool isOfficial = false,
  });

  /// Fetch all comments for a complaint, ordered by timestamp ascending.
  Future<List<Map<String, dynamic>>> getComments(String complaintId);

  /// Delete a single comment from a complaint. Also deletes child replies.
  Future<void> deleteComment(String complaintId, String commentId);

  /// Update the status of a complaint (e.g., 'Pending' → 'In Progress' → 'Resolved').
  Future<Complaint> updateStatus(String complaintId, String newStatus);

  /// Delete a complaint and all its associated data (comments, images).
  /// Only the original author should be able to delete their complaint.
  Future<void> deleteComplaint(String complaintId);
}
