import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';
import 'package:spotit/core/services/storage_service.dart';

/// Firestore-backed implementation of [ComplaintRepository].
///
/// Reads and writes complaints from/to the live Firestore `complaints`
/// collection. Upvote and comment mutations are delegated to callable
/// Cloud Functions to keep counters server-authoritative.
class FirestoreComplaintRepository implements ComplaintRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  );
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

    // Calculate distance from user and sort closest-first
    if (userLat != null && userLng != null) {
      complaints = complaints.map((c) {
        if (c.latitude != null && c.longitude != null) {
          final meters = _haversineMeters(
            userLat,
            userLng,
            c.latitude!,
            c.longitude!,
          );
          return c.copyWith(distanceInMeters: meters);
        }
        return c.copyWith(distanceInMeters: double.maxFinite);
      }).toList();

      complaints.sort((a, b) {
        final dA = a.distanceInMeters ?? double.maxFinite;
        final dB = b.distanceInMeters ?? double.maxFinite;
        return dA.compareTo(dB);
      });
    }

    return complaints;
  }

  /// Haversine formula — returns straight-line distance in meters.
  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // pi / 180
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742000 * math.asin(math.sqrt(a)); // 2 * R in meters
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final callable = _functions.httpsCallable('toggleUpvote');
    await callable.call({'complaintId': complaintId});

    final docRef = _complaintsRef.doc(complaintId);
    return Complaint.fromFirestore(await docRef.get());
  }

  @override
  Future<int> addComment(
    String complaintId,
    String author,
    String text, {
    required String authorId,
    String? parentCommentId,
    bool isOfficial = false,
  }) async {
    final callable = _functions.httpsCallable('addComment');
    await callable.call({
      'complaintId': complaintId,
      'text': text,
      'parentCommentId': parentCommentId,
    });

    final updatedDoc = await _complaintsRef.doc(complaintId).get();
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
        'author':
            data['authorName'] as String? ?? data['author'] as String? ?? 'Anonymous',
        'authorId': data['authorId'] as String? ?? '',
        'text': data['text'] as String? ?? '',
        'parentCommentId': data['parentCommentId'] as String?,
        'isOfficial': data['isOfficial'] as bool? ?? false,
        'timestamp': data['timestamp'] is Timestamp
            ? (data['timestamp'] as Timestamp).toDate()
            : DateTime.now(),
      };
    }).toList();
  }

  @override
  Future<void> deleteComment(String complaintId, String commentId) async {
    final docRef = _complaintsRef.doc(complaintId);
    final commentsCol = docRef.collection('comments');

    // 1. Recursively collect this comment and all nested replies
    final idsToDelete = <String>[commentId];
    Future<void> collectReplies(String parentId) async {
      final replies =
          await commentsCol.where('parentCommentId', isEqualTo: parentId).get();
      for (final reply in replies.docs) {
        idsToDelete.add(reply.id);
        await collectReplies(reply.id);
      }
    }

    await collectReplies(commentId);

    // 2. Delete all collected comments
    for (final id in idsToDelete) {
      await commentsCol.doc(id).delete();
    }

    // 3. Decrement commentCount by the number of deleted comments
    await docRef.update({
      'commentCount': FieldValue.increment(-idsToDelete.length),
    });
  }

  @override
  Future<Complaint> updateStatus(String complaintId, String newStatus) async {
    await _complaintsRef.doc(complaintId).update({
      'status': newStatus,
    });

    final doc = await _complaintsRef.doc(complaintId).get();
    return Complaint.fromFirestore(doc);
  }

  @override
  Future<void> deleteComplaint(String complaintId) async {
    final docRef = _complaintsRef.doc(complaintId);

    // 1. Delete all comments in the subcollection
    final commentsSnapshot = await docRef.collection('comments').get();
    for (final commentDoc in commentsSnapshot.docs) {
      await commentDoc.reference.delete();
    }

    // 2. Delete the complaint document itself
    await docRef.delete();
  }
}
