import 'package:cloud_firestore/cloud_firestore.dart';

/// Complaint model with Firestore serialization support.
class Complaint {
  final String id;
  final String title;
  final String description;
  final String category;
  final String imageUrl;
  final List<String> imageUrls;
  final String status;
  final int upvoteCount;
  final int commentCount;
  final DateTime timestamp;
  final String authorId;
  final String locationName;
  final double? latitude;
  final double? longitude;
  final bool isUpvoted;

  /// Transient property to hold the calculated distance from a specific location
  final double? distanceInMeters;

  Complaint({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.imageUrl = '',
    this.imageUrls = const [],
    required this.status,
    required this.upvoteCount,
    this.commentCount = 0,
    required this.timestamp,
    required this.authorId,
    this.locationName = '',
    this.latitude,
    this.longitude,
    this.isUpvoted = false,
    this.distanceInMeters,
  });

  /// Create a Complaint from a Firestore document snapshot.
  factory Complaint.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle imageUrls: support both single imageUrl and list of imageUrls
    final List<String> urls = [];
    if (data['imageUrls'] != null && data['imageUrls'] is List) {
      urls.addAll(List<String>.from(data['imageUrls']));
    } else if (data['imageUrl'] != null &&
        (data['imageUrl'] as String).isNotEmpty) {
      urls.add(data['imageUrl'] as String);
    }

    // Handle timestamp: could be Firestore Timestamp or ISO string
    DateTime ts;
    if (data['timestamp'] is Timestamp) {
      ts = (data['timestamp'] as Timestamp).toDate();
    } else if (data['createdAt'] is Timestamp) {
      ts = (data['createdAt'] as Timestamp).toDate();
    } else if (data['timestamp'] is String) {
      ts = DateTime.tryParse(data['timestamp'] as String) ?? DateTime.now();
    } else {
      ts = DateTime.now();
    }

    return Complaint(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? 'Other',
      imageUrl: urls.isNotEmpty ? urls.first : '',
      imageUrls: urls,
      status: data['status'] as String? ?? 'Pending',
      upvoteCount: (data['upvoteCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      timestamp: ts,
      authorId: data['authorId'] as String? ?? '',
      locationName: data['locationName'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }

  /// Convert to a Firestore-ready map (for writing to the database).
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'status': status,
      'upvoteCount': upvoteCount,
      'commentCount': commentCount,
      'timestamp': Timestamp.fromDate(timestamp),
      'authorId': authorId,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Complaint copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? imageUrl,
    List<String>? imageUrls,
    String? status,
    int? upvoteCount,
    int? commentCount,
    DateTime? timestamp,
    String? authorId,
    String? locationName,
    double? latitude,
    double? longitude,
    bool? isUpvoted,
    double? distanceInMeters,
  }) {
    return Complaint(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      status: status ?? this.status,
      upvoteCount: upvoteCount ?? this.upvoteCount,
      commentCount: commentCount ?? this.commentCount,
      timestamp: timestamp ?? this.timestamp,
      authorId: authorId ?? this.authorId,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isUpvoted: isUpvoted ?? this.isUpvoted,
      distanceInMeters: distanceInMeters ?? this.distanceInMeters,
    );
  }

  /// Legacy JSON serialization (used by dummy data and Google Maps API).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'status': status,
      'upvoteCount': upvoteCount,
      'commentCount': commentCount,
      'timestamp': timestamp.toIso8601String(),
      'authorId': authorId,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'isUpvoted': isUpvoted,
    };
  }

  String get locationString {
    if (locationName.isNotEmpty) return locationName;
    if (latitude != null && longitude != null) {
      return '${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}';
    }
    return 'Unknown location';
  }
}
