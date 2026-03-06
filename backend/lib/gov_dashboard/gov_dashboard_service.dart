import 'package:cloud_firestore/cloud_firestore.dart';

/// Backend service for government dashboard operations.
/// Handles report queries, status updates, and category analytics.
class GovDashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _complaintsRef =>
      _firestore.collection('complaints');

  /// Fetch all complaints for a specific category, sorted by upvoteCount descending.
  Future<List<Map<String, dynamic>>> getComplaintsByCategory(
    String category,
  ) async {
    final snapshot = await _complaintsRef
        .where('category', isEqualTo: category)
        .orderBy('upvoteCount', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Fetch complaint counts grouped by category.
  Future<Map<String, int>> getCategoryCounts() async {
    final snapshot = await _complaintsRef.get();
    final counts = <String, int>{};

    for (final doc in snapshot.docs) {
      final category = doc.data()['category'] as String? ?? 'Other';
      counts[category] = (counts[category] ?? 0) + 1;
    }

    return counts;
  }

  /// Fetch complaint counts grouped by status.
  Future<Map<String, int>> getStatusCounts() async {
    final snapshot = await _complaintsRef.get();
    final counts = <String, int>{};

    for (final doc in snapshot.docs) {
      final status = doc.data()['status'] as String? ?? 'Pending';
      counts[status] = (counts[status] ?? 0) + 1;
    }

    return counts;
  }

  /// Update the status of a specific complaint.
  Future<void> updateComplaintStatus(
    String complaintId,
    String newStatus,
  ) async {
    await _complaintsRef.doc(complaintId).update({
      'status': newStatus,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
    });
  }
}
