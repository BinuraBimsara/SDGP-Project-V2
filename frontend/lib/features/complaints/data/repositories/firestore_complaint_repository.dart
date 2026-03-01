import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';

/// Firestore-backed implementation of [ComplaintRepository].
///
/// Reads complaints from the live `complaints` collection in Firestore.
/// Write operations will be added in the next commit.
class FirestoreComplaintRepository implements ComplaintRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Reference to the top-level complaints collection.
  CollectionReference<Map<String, dynamic>> get _complaintsRef =>
      _firestore.collection('complaints');

  @override
  Future<List<Complaint>> getComplaints({
    String? category,
    double? userLat,
    double? userLng,
  }) async {
    Query<Map<String, dynamic>> query = _complaintsRef
        .orderBy('timestamp', descending: true);

    // Optional category filter
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    final snapshot = await query.get();

    return snapshot.docs
        .map((doc) => Complaint.fromFirestore(doc))
        .toList();
  }

  @override
  Future<Complaint?> getComplaintById(String id) async {
    final doc = await _complaintsRef.doc(id).get();
    if (!doc.exists) return null;
    return Complaint.fromFirestore(doc);
  }

  // ── Write operations (placeholder — implemented in next commit) ──

  @override
  Future<Complaint> createComplaint(Complaint complaint) async {
    throw UnimplementedError('createComplaint will be implemented next');
  }

  @override
  Future<Complaint> toggleUpvote(String complaintId) async {
    throw UnimplementedError('toggleUpvote will be implemented next');
  }

  @override
  Future<int> addComment(String complaintId, String author, String text) async {
    throw UnimplementedError('addComment will be implemented next');
  }

  @override
  Future<Complaint> updateStatus(String complaintId, String newStatus) async {
    throw UnimplementedError('updateStatus will be implemented next');
  }
}
