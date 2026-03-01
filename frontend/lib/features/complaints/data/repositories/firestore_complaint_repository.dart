import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';
import 'package:spotit/core/services/storage_service.dart';

/// Firestore-backed implementation of [ComplaintRepository].
///
/// Reads and writes complaints from/to the live Firestore `complaints`
/// collection. Upvote and comment operations use Cloud Functions callables.
class FirestoreComplaintRepository implements ComplaintRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-south1');
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
    Query<Map<String, dynamic>> query =
        _complaintsRef.orderBy('timestamp', descending: true);

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
    final callable = _functions.httpsCallable('toggleUpvote');
    await callable.call<dynamic>({'complaintId': complaintId});

    // Re-fetch the complaint to get the updated upvoteCount
    final doc = await _complaintsRef.doc(complaintId).get();
    return Complaint.fromFirestore(doc);
  }

  @override
  Future<int> addComment(
      String complaintId, String author, String text) async {
    final callable = _functions.httpsCallable('addComment');
    await callable.call<dynamic>({
      'complaintId': complaintId,
      'text': text,
    });

    // Re-fetch the complaint to get the updated commentCount
    final doc = await _complaintsRef.doc(complaintId).get();
    final data = doc.data();
    return (data?['commentCount'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<Complaint> updateStatus(
      String complaintId, String newStatus) async {
    await _complaintsRef.doc(complaintId).update({
      'status': newStatus,
    });

    final doc = await _complaintsRef.doc(complaintId).get();
    return Complaint.fromFirestore(doc);
  }
}
