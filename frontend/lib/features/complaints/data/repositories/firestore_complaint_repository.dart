import 'dart:math' as math; // used for the Haversine distance formula

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';
import 'package:spotit/core/services/storage_service.dart';

// This class implements the ComplaintRepository interface using Firestore.
// All database reads and writes for complaints go through this class.
// Upvotes and comments are handled by Cloud Functions to keep counts accurate
// even under concurrent access (multiple users hitting upvote at the same time).
class FirestoreComplaintRepository implements ComplaintRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cloud Functions are called with a region because our functions are deployed
  // in asia-south1 (Mumbai), not the default us-central1
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  );

  final StorageService _storageService = StorageService(); // handles image uploads

  // Returns the category string unchanged.
  // Firestore security rules do case-sensitive checks, so we must not alter case.
  String _normalizeCategory(String category) {
    return category;
  }

  // Compares two category strings case-insensitively.
  // Used for client-side filtering after we fetch all complaints.
  bool _categoryMatches(String complaintCategory, String selectedCategory) {
    return complaintCategory.toLowerCase() == selectedCategory.toLowerCase();
  }

  // Shortcut property to the Firestore 'complaints' collection
  CollectionReference<Map<String, dynamic>> get _complaintsRef =>
      _firestore.collection('complaints');

  // ── Read operations ──────────────────────────────────────────────────────────

  @override
  Future<List<Complaint>> getComplaints({
    String? category,
    double? userLat,
    double? userLng,
  }) async {
    // Fetch ALL complaints without a server-side orderBy.
    // Why? Some older documents don't have a 'timestamp' field, and Firestore
    // would exclude them if we used orderBy('timestamp'). We sort client-side instead.
    final snapshot = await _complaintsRef.get();

    // Convert each Firestore document to a Complaint object
    List<Complaint> complaints =
        snapshot.docs.map((doc) => Complaint.fromFirestore(doc)).toList();

    // Filter by category on the client side to avoid needing a composite Firestore index
    if (category != null && category.isNotEmpty) {
      complaints = complaints
          .where((c) => _categoryMatches(c.category, category))
          .toList();
    }

    // Default sort: newest complaints at the top
    complaints.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // If the user's GPS coordinates are provided, calculate how far each complaint
    // is from them and then sort by distance (closest first)
    if (userLat != null && userLng != null) {
      complaints = complaints.map((c) {
        if (c.latitude != null && c.longitude != null) {
          final meters = _haversineMeters(
            userLat,
            userLng,
            c.latitude!,
            c.longitude!,
          );
          return c.copyWith(distanceInMeters: meters); // attach the calculated distance
        }
        return c.copyWith(distanceInMeters: double.maxFinite); // no GPS = put at the end
      }).toList();

      // Sort so the closest complaint is first
      complaints.sort((a, b) {
        final dA = a.distanceInMeters ?? double.maxFinite;
        final dB = b.distanceInMeters ?? double.maxFinite;
        return dA.compareTo(dB);
      });
    }

    return complaints;
  }

  // Calculates the straight-line distance between two GPS coordinates in meters.
  // Uses the Haversine formula which accounts for the curvature of the Earth.
  // p = pi / 180 converts degrees to radians (GPS coordinates are in degrees).
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
    return 12742000 * math.asin(math.sqrt(a)); // 2 * Earth's radius in meters
  }

  @override
  Future<Complaint?> getComplaintById(String id) async {
    final doc = await _complaintsRef.doc(id).get();
    if (!doc.exists) return null; // return null instead of throwing if not found
    return Complaint.fromFirestore(doc);
  }

  // ── Write operations ─────────────────────────────────────────────────────────

  @override
  Future<Complaint> createComplaint(Complaint complaint,
      {List<XFile>? images}) async {
    // Build the exact payload that Firestore security rules allow.
    // The rules check that only these fields are present, so we can't
    // include extra fields like 'isAnonymous' unless the rules allow it.
    final createPayload = <String, dynamic>{
      'title': complaint.title,
      'description': complaint.description,
      'category': _normalizeCategory(complaint.category),
      'imageUrl': complaint.imageUrl,
      'imageUrls': complaint.imageUrls,
      'status': complaint.status,
      'upvoteCount': complaint.upvoteCount,
      'commentCount': complaint.commentCount,
      'timestamp': Timestamp.fromDate(complaint.timestamp),
      'authorId': complaint.authorId,
      'authorName': complaint.authorName,
      'locationName': complaint.locationName,
      'latitude': complaint.latitude,
      'longitude': complaint.longitude,
    };

    // Step 1: Create the complaint document first to get its Firestore ID.
    // We need the ID before we can upload images (the images go in a subfolder named after the ID).
    final docRef = await _complaintsRef.add(createPayload);

    // Step 2: Upload images to Firebase Storage if any were attached
    List<String> imageUrls = [];
    if (images != null && images.isNotEmpty) {
      imageUrls = await _storageService.uploadMultipleImages(
        docRef.id,  // use the just-created complaint ID as the storage folder name
        images,
      );

      // Step 3: Update the complaint document with the image URLs
      // (we couldn't include them in the original write because we needed the ID first)
      await docRef.update({
        'imageUrl': imageUrls.first, // primary image for quick display
        'imageUrls': imageUrls,      // full list for the image gallery
      });
    }

    // Step 4: Re-fetch the complaint to return the final version with all fields
    final snap = await docRef.get();
    return Complaint.fromFirestore(snap);
  }

  @override
  Future<Complaint> toggleUpvote(String complaintId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Call the Cloud Function — it runs a Firestore transaction so the count
    // is always accurate even if two users upvote at exactly the same moment
    final callable = _functions.httpsCallable('toggleUpvote');
    await callable.call({'complaintId': complaintId});

    // Re-fetch and return the complaint with the updated upvoteCount
    final docRef = _complaintsRef.doc(complaintId);
    return Complaint.fromFirestore(await docRef.get());
  }

  @override
  Future<int> addComment(
    String complaintId,
    String author,
    String text, {
    required String authorId,
    String? parentCommentId, // null for top-level comments; set for replies
    bool isOfficial = false,
  }) async {
    final callable = _functions.httpsCallable('addComment');
    try {
      // Try to call the Cloud Function first — it handles everything atomically
      await callable.call({
        'complaintId': complaintId,
        'text': text,
        'parentCommentId': parentCommentId,
      });

      // Force a server fetch to get the updated commentCount after the Cloud Function ran.
      // Source.server bypasses Firestore's local cache to always get the latest number.
      final updatedDoc = await _complaintsRef
          .doc(complaintId)
          .get(const GetOptions(source: Source.server));
      final data = updatedDoc.data();
      return (data?['commentCount'] as num?)?.toInt() ?? 0;

    } on FirebaseFunctionsException {
      // If the Cloud Function fails (e.g. permission error), fall back to
      // writing the comment directly to Firestore
      await _complaintsRef.doc(complaintId).collection('comments').add({
        'authorId': authorId,
        'authorName': author,
        'text': text.trim(),
        'parentCommentId': parentCommentId,
        'isOfficial': isOfficial,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Try to increment the comment count on the complaint document
      try {
        await _complaintsRef.doc(complaintId).update({
          'commentCount': FieldValue.increment(1), // atomic increment
        });
      } catch (_) {
        // If the increment fails (security rules), the UI will use the local count
      }

      // Count the actual comments in Firestore as a fallback count
      final commentsSnapshot =
          await _complaintsRef.doc(complaintId).collection('comments').get();
      return commentsSnapshot.docs.length;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getComments(String complaintId) async {
    final snapshot = await _complaintsRef
        .doc(complaintId)
        .collection('comments')
        .orderBy('timestamp', descending: false) // oldest comment first
        .get();

    // Convert each comment document to a normalized Map.
    // We normalize field names here so the UI doesn't need to handle
    // two different field name conventions ('authorName' vs 'author').
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'author': data['authorName'] as String? ??
            data['author'] as String? ??
            'Anonymous', // try both field names for backwards compatibility
        'authorId': data['authorId'] as String? ?? '',
        'text': data['text'] as String? ?? '',
        'parentCommentId': data['parentCommentId'] as String?, // null = top-level
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

    // Collect the ID of this comment and all nested replies recursively.
    // We need to delete all of them, not just the top-level one.
    final idsToDelete = <String>[commentId];
    Future<void> collectReplies(String parentId) async {
      final replies =
          await commentsCol.where('parentCommentId', isEqualTo: parentId).get();
      for (final reply in replies.docs) {
        idsToDelete.add(reply.id); // add this reply to the delete list
        await collectReplies(reply.id); // and recurse to find its replies too
      }
    }
    await collectReplies(commentId);

    // Delete all collected comments (the original + all nested replies)
    for (final id in idsToDelete) {
      await commentsCol.doc(id).delete();
    }

    // Subtract the deleted count from the total commentCount on the complaint
    try {
      await docRef.update({
        'commentCount': FieldValue.increment(-idsToDelete.length),
      });
    } catch (_) {
      // Best-effort sync — if it fails, the UI will refresh on next load
    }
  }

  @override
  Future<void> syncCommentCount(String complaintId, int count) async {
    // Only run if a user is logged in — Firestore rules require authentication
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('syncCommentCount: User not authenticated');
      return;
    }

    try {
      // Overwrite the commentCount with the correct number
      await _complaintsRef.doc(complaintId).update({
        'commentCount': count,
      });
      debugPrint('syncCommentCount: Synced $complaintId to count=$count');
    } on FirebaseException catch (e) {
      debugPrint('syncCommentCount FirebaseException: ${e.code} - ${e.message}');
    } catch (e) {
      debugPrint('syncCommentCount failed: $e');
    }
  }

  @override
  Future<Complaint> updateStatus(String complaintId, String newStatus) async {
    // Update only the status field — leave everything else untouched
    await _complaintsRef.doc(complaintId).update({
      'status': newStatus, // e.g. 'Pending' → 'In Progress'
    });

    // Re-fetch and return the updated complaint so the UI can refresh
    final doc = await _complaintsRef.doc(complaintId).get();
    return Complaint.fromFirestore(doc);
  }

  @override
  Future<void> deleteComplaint(String complaintId) async {
    final docRef = _complaintsRef.doc(complaintId);

    // Step 1: Delete all comments in the subcollection.
    // Firestore doesn't automatically delete subcollections when you delete a document,
    // so we have to do it manually first.
    final commentsSnapshot = await docRef.collection('comments').get();
    for (final commentDoc in commentsSnapshot.docs) {
      await commentDoc.reference.delete();
    }

    // Step 2: Delete the complaint document itself
    await docRef.delete();
  }
}
