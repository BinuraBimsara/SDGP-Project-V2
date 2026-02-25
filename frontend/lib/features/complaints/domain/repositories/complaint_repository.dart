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

  /// Create a new complaint. Returns the created complaint with its ID.
  Future<Complaint> createComplaint(Complaint complaint);

  /// Toggle the upvote on a complaint for the current user.
  /// Returns the updated complaint.
  Future<Complaint> toggleUpvote(String complaintId);

  /// Add a comment to a complaint. Returns the updated comment count.
  Future<int> addComment(String complaintId, String author, String text);

  /// Update the status of a complaint (e.g., 'Pending' → 'In Progress' → 'Resolved').
  Future<Complaint> updateStatus(String complaintId, String newStatus);
}
