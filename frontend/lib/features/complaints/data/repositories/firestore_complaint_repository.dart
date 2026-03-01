import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';
import 'package:spotit/core/services/storage_service.dart';

/// Firestore-backed implementation of [ComplaintRepository].
///
/// Reads and writes complaints from/to the live Firestore `complaints`
/// collection. Upvote and comment operations write directly to Firestore.
class FirestoreComplaintRepository implements ComplaintRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService = StorageService();

  /// Reference to the top-level complaints collection.
  CollectionReference<Map<String, dynamic>> get _complaintsRef =>
      _firestore.collection('complaints');

  // ── Read operations ──────────────────────────────────────────────────────

  @override
  Future<List<Complaint>> getComplaints({
    String? category,
    double? userLat,
    double? userLng,
  }) async {
    // Always fetch all complaints ordered by timestamp
    final snapshot =
        await _complaintsRef.orderBy('timestamp', descending: true).get();

    List<Complaint> complaints =
        snapshot.docs.map((doc) => Complaint.fromFirestore(doc)).toList();

    // Apply category filter client-side to avoid needing a composite index
    if (category != null && category.isNotEmpty) {
      complaints = complaints
          .where((c) => c.category.toLowerCase() == category.toLowerCase())
          .toList();
    }

    return complaints;
  }

  @override
  Future<Complaint?> getComplaintById(String id) async {
    final doc = await _complaintsRef.doc(id).get();
    if (!doc.exists) return null;
    return Complaint.fromFirestore(doc);
  }

  // ── Write operations ─────────────────────────────────────────────────────

  @override
  Future<Complaint> createComplaint(Complaint complaint,
      {List<XFile>? images}) async {
    // 1. Create the complaint document first (to get the ID)
    final docRef = await _complaintsRef.add(complaint.toFirestore());

    // 2. Upload images if provided
    List<String> imageUrls = [];
    if (images != null && images.isNotEmpty) {
      imageUrls = await _storageService.uploadMultipleImages(
        docRef.id,
        images,
      );

      // 3. Update the complaint doc with the image URLs
      await docRef.update({
        'imageUrl': imageUrls.first,
        'imageUrls': imageUrls,
      });
    }

    // 4. Re-fetch and return the final complaint
    final snap = await docRef.get();
    return Complaint.fromFirestore(snap);
  }

  @override
  Future<Complaint> toggleUpvote(String complaintId) async {
    final docRef = _complaintsRef.doc(complaintId);
    final doc = await docRef.get();
    if (!doc.exists) throw Exception('Complaint not found');

    final data = doc.data()!;
    final currentCount = (data['upvoteCount'] as num?)?.toInt() ?? 0;

    // Increment (toggle up). For a full per-user toggle you'd track
    // user IDs in an array, but for now we just increment by 1.
    final newCount = currentCount + 1;

    await docRef.update({
      'upvoteCount': newCount,
    });

    return Complaint.fromFirestore(await docRef.get());
  }

  @override
  Future<int> addComment(String complaintId, String author, String text) async {
    final docRef = _complaintsRef.doc(complaintId);

    // 1. Add comment to the comments subcollection
    await docRef.collection('comments').add({
      'author': author,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. Increment the commentCount on the parent document
    await docRef.update({
      'commentCount': FieldValue.increment(1),
    });

    // 3. Return the updated comment count
    final updatedDoc = await docRef.get();
    final data = updatedDoc.data();
    return (data?['commentCount'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<Map<String, dynamic>>> getComments(String complaintId) async {
    final snapshot = await _complaintsRef
        .doc(complaintId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'author': data['author'] as String? ?? 'Anonymous',
        'text': data['text'] as String? ?? '',
        'timestamp': data['timestamp'] is Timestamp
            ? (data['timestamp'] as Timestamp).toDate()
            : DateTime.now(),
      };
    }).toList();
  }

  @override
  Future<Complaint> updateStatus(String complaintId, String newStatus) async {
    await _complaintsRef.doc(complaintId).update({
      'status': newStatus,
    });

    final doc = await _complaintsRef.doc(complaintId).get();
    return Complaint.fromFirestore(doc);
  }
}
