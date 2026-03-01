class AdminComplaint {
  final String id;
  final String citizenId;
  final String title;
  final String description;
  final String category;
  final String status;
  final int urgencyScore;
  final DateTime timestamp;

  const AdminComplaint({
    required this.id,
    required this.citizenId,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.urgencyScore,
    required this.timestamp,
  });

  factory AdminComplaint.fromFirestore(Map<String, dynamic> data, String id) {
    final timestampValue = data['timestamp'];

    DateTime parsedTimestamp;
    if (timestampValue is DateTime) {
      parsedTimestamp = timestampValue;
    } else if (timestampValue is String) {
      parsedTimestamp = DateTime.tryParse(timestampValue) ?? DateTime.now();
    } else {
      parsedTimestamp = DateTime.now();
    }

    return AdminComplaint(
      id: id,
      citizenId: (data['citizenId'] ?? '').toString(),
      title: (data['title'] ?? 'Complaint').toString(),
      description: (data['description'] ?? '').toString(),
      category: (data['category'] ?? 'Other').toString(),
      status: (data['status'] ?? 'pending').toString(),
      urgencyScore: (data['urgencyScore'] as num?)?.toInt() ?? 1,
      timestamp: parsedTimestamp,
    );
  }

  AdminComplaint copyWith({
    String? id,
    String? citizenId,
    String? title,
    String? description,
    String? category,
    String? status,
    int? urgencyScore,
    DateTime? timestamp,
  }) {
    return AdminComplaint(
      id: id ?? this.id,
      citizenId: citizenId ?? this.citizenId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      urgencyScore: urgencyScore ?? this.urgencyScore,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
