/// Represents a citizen-submitted report.
class CitizenReport {
  final String id;
  final String title;
  final String description;
  final String category;
  final int upvotes;
  final int downvotes;
  final DateTime createdAt;

  CitizenReport({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.upvotes = 0,
    this.downvotes = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
