import '../models/government_stat.dart';

/// Pre-built government statistics for development / testing.
final List<GovernmentStat> mockStatsData = [
  GovernmentStat(id: '1', title: 'Total Reports', value: 150, category: 'reports'),
  GovernmentStat(id: '2', title: 'Resolved', value: 95, category: 'resolved'),
  GovernmentStat(id: '3', title: 'Pending', value: 55, category: 'pending'),
  GovernmentStat(id: '4', title: 'High Priority', value: 18, category: 'priority'),
];
