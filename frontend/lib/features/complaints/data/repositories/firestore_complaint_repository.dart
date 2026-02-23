<<<<<<< HEAD
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';

/// Firestore implementation of ComplaintRepository.
///
/// To switch to a different database, create a new class that implements
/// ComplaintRepository and swap it in main.dart.
class FirestoreComplaintRepository implements ComplaintRepository {
  final FirebaseFirestore _firestore;
  final String _userId;

  FirestoreComplaintRepository({
    FirebaseFirestore? firestore,
    required String userId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _userId = userId;

  CollectionReference get _complaintsRef => _firestore.collection('complaints');

  @override
  Future<List<Complaint>> getComplaints({String? category}) async {
    Query query = _complaintsRef.orderBy('timestamp', descending: true);

    if (category != null && category != 'All') {
      query = query.where('category', isEqualTo: category);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Complaint.fromDocument(doc)).toList();
  }

  @override
  Future<Complaint?> getComplaintById(String id) async {
    final doc = await _complaintsRef.doc(id).get();
    if (!doc.exists) return null;
    return Complaint.fromDocument(doc);
  }

  @override
  Future<Complaint> createComplaint(Complaint complaint) async {
    final docRef = await _complaintsRef.add(complaint.toJson());
    final doc = await docRef.get();
    return Complaint.fromDocument(doc);
  }

  @override
  Future<Complaint> toggleUpvote(String complaintId) async {
    final docRef = _complaintsRef.doc(complaintId);
    final upvoteRef = docRef.collection('upvotes').doc(_userId);

    return _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      final upvoteDoc = await transaction.get(upvoteRef);

      if (!doc.exists) throw Exception('Complaint not found');

      final currentCount =
          (doc.data() as Map<String, dynamic>)['upvoteCount'] ?? 0;

      if (upvoteDoc.exists) {
        // Remove upvote
        transaction.delete(upvoteRef);
        transaction.update(docRef, {'upvoteCount': currentCount - 1});
      } else {
        // Add upvote
        transaction.set(upvoteRef, {'timestamp': FieldValue.serverTimestamp()});
        transaction.update(docRef, {'upvoteCount': currentCount + 1});
      }

      // Re-read to return updated complaint
      final updatedDoc = await docRef.get();
      return Complaint.fromDocument(
        updatedDoc,
      ).copyWith(isUpvoted: !upvoteDoc.exists);
    });
  }

  @override
  Future<int> addComment(String complaintId, String author, String text) async {
    final docRef = _complaintsRef.doc(complaintId);

    await docRef.collection('comments').add({
      'author': author,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Increment comment count
    await docRef.update({'commentCount': FieldValue.increment(1)});

    final updated = await docRef.get();
    return (updated.data() as Map<String, dynamic>)['commentCount'] ?? 0;
  }

  @override
  Future<Complaint> updateStatus(String complaintId, String newStatus) async {
    final docRef = _complaintsRef.doc(complaintId);
    await docRef.update({'status': newStatus});
    final doc = await docRef.get();
    return Complaint.fromDocument(doc);
  }
}
=======
// firestore_complaint_repository.dart
//
// NOTE: This file is intentionally disabled for GUI testing mode.
// Firebase/Firestore backend is excluded until backend work begins
// in the /backend folder. The DummyComplaintRepository is used instead.
//
// When backend is ready, restore this file and uncomment the imports.

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:spotit/features/complaints/data/models/complaint_model.dart';
// import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';
//
// class FirestoreComplaintRepository implements ComplaintRepository { ... }
>>>>>>> a2273dd3a72b26e61d482033ab992eee3b7afd05
