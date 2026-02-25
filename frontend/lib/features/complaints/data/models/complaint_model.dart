/// Complaint model – pure Dart, no Firebase dependency.
/// When backend is ready, add fromDocument/toJson with Firestore types here.
class Complaint {
  final String id;
  final String title;
  final String description;
  final String category;
  final String imageUrl;
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
    required this.imageUrl,
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

  Complaint copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? imageUrl,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
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
