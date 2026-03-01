import '../models/citizen_report.dart';

/// Pre-built citizen reports for development / testing.
final List<CitizenReport> mockReportsData = [
  CitizenReport(
    id: '1',
    title: 'Pothole on Main Street',
    description: 'Large pothole causing traffic issues',
    category: 'Infrastructure',
    upvotes: 45,
    downvotes: 2,
  ),
  CitizenReport(
    id: '2',
    title: 'Broken Streetlight',
    description: 'Streetlight on Oak Avenue not working',
    category: 'Utilities',
    upvotes: 32,
    downvotes: 1,
  ),
  CitizenReport(
    id: '3',
    title: 'Water Supply Issue',
    description: 'Low water pressure in residential area',
    category: 'Utilities',
    upvotes: 67,
    downvotes: 5,
  ),
];
