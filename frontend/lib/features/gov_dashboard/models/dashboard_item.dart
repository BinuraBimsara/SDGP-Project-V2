/// Represents a single dashboard metric item.
class DashboardItem {
  final String id;
  final String title;
  final int value;

  DashboardItem({
    required this.id,
    required this.title,
    required this.value,
  });
}
