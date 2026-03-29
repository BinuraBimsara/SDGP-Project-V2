import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// The Complaint class is the core data model for the app.
// Every reported issue is stored as a Complaint object, saved to Firestore,
// and displayed throughout the citizen and government dashboards.
class Complaint {
  final String id;            // Firestore auto-generated document ID
  final String title;         // short summary (e.g. "Broken road on Main St")
  final String description;   // full details written by the citizen
  final String category;      // one of: Road, Infrastructure, Waste, Lighting, Other
  final String imageUrl;      // URL of the first/primary image (may be empty)
  final List<String> imageUrls; // list of all image URLs for this complaint
  final String status;        // Pending / In Progress / Resolved
  final int upvoteCount;      // total number of citizens who upvoted this
  final int commentCount;     // total number of comments on this complaint
  final DateTime timestamp;   // when the complaint was submitted
  final String authorId;      // Firebase UID of the citizen who submitted it
  final String authorName;    // display name of the author (or "Anonymous")
  final String locationName;  // human-readable location (e.g. "Galle Road, Colombo")
  final double? latitude;     // GPS latitude, null if not provided
  final double? longitude;    // GPS longitude, null if not provided
  final bool isUpvoted;       // whether the current logged-in user has upvoted this
  final bool isAnonymous;     // true if the citizen chose to hide their name

  // List of user UIDs who have upvoted this — used to determine isUpvoted
  final List<String> upvotedBy;

  // Distance from the user's location in meters.
  // This is not stored in Firestore — it's calculated on the client
  // using the Haversine formula and attached to the object temporarily.
  final double? distanceInMeters;

  Complaint({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.imageUrl = '',          // optional — empty if no image was attached
    this.imageUrls = const [],   // optional — empty list by default
    required this.status,
    required this.upvoteCount,
    this.commentCount = 0,
    required this.timestamp,
    required this.authorId,
    this.authorName = '',
    this.locationName = '',
    this.latitude,               // nullable — not all complaints have GPS data
    this.longitude,
    this.isUpvoted = false,
    this.upvotedBy = const [],
    this.distanceInMeters,       // nullable — only set when sorting by distance
    this.isAnonymous = false,
  });

  // Converts a Firestore document snapshot into a Complaint object.
  // Handles multiple field name variations (e.g. 'latitude' vs 'lat')
  // because older documents in the database may use different field names.
  factory Complaint.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Try to read GPS coordinates from multiple possible field names:
    // 'latitude', 'lat', or from a GeoPoint stored in 'location'
    final GeoPoint? geoPoint = data['location'] is GeoPoint
      ? data['location'] as GeoPoint
      : null;
    final double? parsedLatitude = (data['latitude'] as num?)?.toDouble() ??
      (data['lat'] as num?)?.toDouble() ??
      geoPoint?.latitude;
    final double? parsedLongitude = (data['longitude'] as num?)?.toDouble() ??
      (data['lng'] as num?)?.toDouble() ??
      geoPoint?.longitude;

    // Collect image URLs — support both the old single imageUrl field
    // and the new imageUrls array, for backwards compatibility
    final List<String> urls = [];
    if (data['imageUrls'] != null && data['imageUrls'] is List) {
      urls.addAll(List<String>.from(data['imageUrls'])); // new format: array of URLs
    } else if (data['imageUrl'] != null &&
        (data['imageUrl'] as String).isNotEmpty) {
      urls.add(data['imageUrl'] as String); // old format: single URL string
    }

    // Parse the timestamp — could be a Firestore Timestamp object,
    // a 'createdAt' field, or an ISO string from older data
    DateTime ts;
    if (data['timestamp'] is Timestamp) {
      ts = (data['timestamp'] as Timestamp).toDate();
    } else if (data['createdAt'] is Timestamp) {
      ts = (data['createdAt'] as Timestamp).toDate(); // some docs use 'createdAt'
    } else if (data['timestamp'] is String) {
      ts = DateTime.tryParse(data['timestamp'] as String) ?? DateTime.now();
    } else {
      ts = DateTime.now(); // fallback if no timestamp field exists
    }

    // Get the list of users who upvoted, then check if the current user is in it
    final List<String> voters =
        data['upvotedBy'] != null ? List<String>.from(data['upvotedBy']) : [];
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final hasUpvoted = voters.contains(currentUid); // true if this user already upvoted

    return Complaint(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? 'Other',
      imageUrl: urls.isNotEmpty ? urls.first : '', // first image as the primary one
      imageUrls: urls,
      status: data['status'] as String? ?? 'Pending',
      upvoteCount: (data['upvoteCount'] as num?)?.toInt() ?? voters.length, // fallback to voters.length
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      timestamp: ts,
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      locationName: data['locationName'] as String? ?? '',
      latitude: parsedLatitude,
      longitude: parsedLongitude,
      isUpvoted: hasUpvoted,
      upvotedBy: voters,
      isAnonymous: data['isAnonymous'] as bool? ?? false,
    );
  }

  // Converts this Complaint to a Map for writing to Firestore.
  // Note: id is NOT included — Firestore uses the document ID separately.
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
      'timestamp': Timestamp.fromDate(timestamp), // convert to Firestore format
      'authorId': authorId,
      'authorName': authorName,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'isAnonymous': isAnonymous,
    };
  }

  // Creates a copy of this Complaint with specific fields replaced.
  // Used throughout the app to update individual fields without mutating the original.
  // e.g. complaint.copyWith(status: 'Resolved') returns a new object with only status changed.
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
    String? authorName,
    String? locationName,
    double? latitude,
    double? longitude,
    bool? isUpvoted,
    List<String>? upvotedBy,
    double? distanceInMeters,
    bool? isAnonymous,
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
      authorName: authorName ?? this.authorName,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isUpvoted: isUpvoted ?? this.isUpvoted,
      upvotedBy: upvotedBy ?? this.upvotedBy,
      distanceInMeters: distanceInMeters ?? this.distanceInMeters,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }

  // Converts this Complaint to a plain JSON map.
  // Used for passing complaint data to Google Maps and other external tools.
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
      'timestamp': timestamp.toIso8601String(), // ISO string format for JSON
      'authorId': authorId,
      'authorName': authorName,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'isUpvoted': isUpvoted,
      'upvotedBy': upvotedBy,
      'isAnonymous': isAnonymous,
    };
  }

  // Convenience getter — returns the best available location label:
  // 1. The human-readable locationName if it's set
  // 2. The GPS coordinates formatted to 4 decimal places
  // 3. "Unknown location" if neither is available
  String get locationString {
    if (locationName.isNotEmpty) return locationName;
    if (latitude != null && longitude != null) {
      return '${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}';
    }
    return 'Unknown location';
  }
}
