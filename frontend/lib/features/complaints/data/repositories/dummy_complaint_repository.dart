import 'package:spotit/features/complaints/data/dummy_complaints.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';

/// In-memory implementation using dummy data.
/// Use this during development when Firebase is not available.
class DummyComplaintRepository implements ComplaintRepository {
  final List<Complaint> _complaints = DummyComplaints.getComplaints();

  @override
  Future<List<Complaint>> getComplaints({String? category}) async {
    if (category == null || category == 'All') {
      return List.from(_complaints);
    }
    return _complaints
        .where((c) => c.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  @override
  Future<Complaint?> getComplaintById(String id) async {
    try {
      return _complaints.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Complaint> createComplaint(Complaint complaint) async {
    _complaints.insert(0, complaint);
    return complaint;
  }

  @override
  Future<Complaint> toggleUpvote(String complaintId) async {
    final index = _complaints.indexWhere((c) => c.id == complaintId);
    if (index == -1) throw Exception('Complaint not found');

    final old = _complaints[index];
    final newUpvoted = !old.isUpvoted;
    final updated = old.copyWith(
      isUpvoted: newUpvoted,
      upvoteCount: old.upvoteCount + (newUpvoted ? 1 : -1),
    );
    _complaints[index] = updated;
    return updated;
  }

  @override
  Future<int> addComment(String complaintId, String author, String text) async {
    final index = _complaints.indexWhere((c) => c.id == complaintId);
    if (index == -1) throw Exception('Complaint not found');

    final old = _complaints[index];
    final updated = old.copyWith(commentCount: old.commentCount + 1);
    _complaints[index] = updated;
    return updated.commentCount;
  }

  @override
  Future<Complaint> updateStatus(String complaintId, String newStatus) async {
    final index = _complaints.indexWhere((c) => c.id == complaintId);
    if (index == -1) throw Exception('Complaint not found');

    final updated = _complaints[index].copyWith(status: newStatus);
    _complaints[index] = updated;
    return updated;
  }
}
