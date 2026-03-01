import 'package:spotit/features/complaints/data/dummy_complaints.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';
import 'package:backend/data_architecture/google_maps_api.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math' as math;

/// In-memory implementation using dummy data.
/// Use this during development when Firebase is not available.
class DummyComplaintRepository implements ComplaintRepository {
  final List<Complaint> _complaints = DummyComplaints.getComplaints();

  // Fixed Colombo Coordinates
  static const LatLng _colomboLocation = LatLng(6.9271, 79.8612);

  // Simple haversine formula to compute distance accurately between LatLngs
  double _calculateDistanceMeters(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000; // in meters
    final double lat1 = p1.latitude * math.pi / 180;
    final double lat2 = p2.latitude * math.pi / 180;
    final double dLat = (p2.latitude - p1.latitude) * math.pi / 180;
    final double dLon = (p2.longitude - p1.longitude) * math.pi / 180;

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  @override
  Future<List<Complaint>> getComplaints({
    String? category,
    double? userLat,
    double? userLng,
  }) async {
    final lat = userLat ?? _colomboLocation.latitude;
    final lng = userLng ?? _colomboLocation.longitude;

    // Pass the dummy complaints to our Google Maps API Backend
    final rawDocs = _complaints.map((c) => c.toJson()).toList();

    // Fetch async remote locations via HTTP Google Maps API
    final sortedData = await GoogleMapsMockAPI.fetchNearbyComplaints(
      userLat: lat,
      userLng: lng,
      rawComplaints: rawDocs,
      category: category,
    );

    // Convert the returned JSON back to Complaint objects,
    // preserving proper state objects intact!
    return sortedData.map((data) {
      final base = _complaints.firstWhere((c) => c.id == data['id']);
      return base.copyWith(
        distanceInMeters: data['distanceInMeters'] != null
            ? (data['distanceInMeters'] as num).toDouble()
            : null,
      );
    }).toList();
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
  Future<Complaint> createComplaint(Complaint complaint,
      {List<XFile>? images}) async {
    Complaint complaintWithDistance = complaint;

    // Auto-calculate distance for the new complaint as well
    if (complaint.latitude != null && complaint.longitude != null) {
      final double distInMeters = _calculateDistanceMeters(
          _colomboLocation, LatLng(complaint.latitude!, complaint.longitude!));
      complaintWithDistance =
          complaint.copyWith(distanceInMeters: distInMeters);
    }

    _complaints.insert(0, complaintWithDistance);
    return complaintWithDistance;
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

  @override
  Future<List<Map<String, dynamic>>> getComments(String complaintId) async {
    // Dummy repository returns empty comments
    return [];
  }
}
