import 'dart:async';

import 'package:spotit/features/admin/data/models/admin_complaint.dart';

class MockAdminService {
  final StreamController<List<AdminComplaint>> _controller =
      StreamController<List<AdminComplaint>>.broadcast();

  final List<AdminComplaint> _allComplaints = [
    AdminComplaint(
      id: 'A001',
      citizenId: 'CIT-110',
      title: 'Street light not working',
      description: 'Main road lamp has been off for three nights near school.',
      category: 'Lighting',
      status: 'pending',
      urgencyScore: 4,
      timestamp: DateTime(2026, 2, 28, 21, 00),
    ),
    AdminComplaint(
      id: 'A002',
      citizenId: 'CIT-231',
      title: 'Overflowing garbage point',
      description: 'Waste bin has not been cleared and blocks the walkway.',
      category: 'Waste',
      status: 'in_progress',
      urgencyScore: 5,
      timestamp: DateTime(2026, 2, 27, 8, 45),
    ),
    AdminComplaint(
      id: 'A003',
      citizenId: 'CIT-145',
      title: 'Pothole near junction',
      description: 'Large pothole causing two-wheelers to skid in rain.',
      category: 'Pothole',
      status: 'pending',
      urgencyScore: 5,
      timestamp: DateTime(2026, 2, 28, 18, 10),
    ),
    AdminComplaint(
      id: 'A004',
      citizenId: 'CIT-998',
      title: 'Blocked drain line',
      description: 'Drain is clogged and water remains stagnant.',
      category: 'Infrastructure',
      status: 'resolved',
      urgencyScore: 3,
      timestamp: DateTime(2026, 2, 26, 11, 30),
    ),
    AdminComplaint(
      id: 'A005',
      citizenId: 'CIT-772',
      title: 'Water leakage from pipeline',
      description: 'Continuous leak from roadside pipe near bus halt.',
      category: 'Utilities',
      status: 'in_progress',
      urgencyScore: 4,
      timestamp: DateTime(2026, 2, 28, 7, 55),
    ),
    AdminComplaint(
      id: 'A006',
      citizenId: 'CIT-621',
      title: 'Illegal dumping spot',
      description: 'Open area behind market is used for illegal dumping.',
      category: 'Waste',
      status: 'pending',
      urgencyScore: 2,
      timestamp: DateTime(2026, 2, 25, 16, 20),
    ),
    AdminComplaint(
      id: 'A007',
      citizenId: 'CIT-304',
      title: 'Traffic signal timing issue',
      description: 'Signal remains red too long and causes heavy congestion.',
      category: 'Infrastructure',
      status: 'resolved',
      urgencyScore: 3,
      timestamp: DateTime(2026, 2, 24, 9, 5),
    ),
    AdminComplaint(
      id: 'A008',
      citizenId: 'CIT-122',
      title: 'Manhole cover damaged',
      description: 'Cracked manhole cover poses serious risk to vehicles.',
      category: 'Pothole',
      status: 'pending',
      urgencyScore: 5,
      timestamp: DateTime(2026, 2, 28, 10, 40),
    ),
    AdminComplaint(
      id: 'A009',
      citizenId: 'CIT-887',
      title: 'Street sign missing',
      description: 'Directional signboard missing after recent road works.',
      category: 'Infrastructure',
      status: 'in_progress',
      urgencyScore: 1,
      timestamp: DateTime(2026, 2, 23, 14, 15),
    ),
    AdminComplaint(
      id: 'A010',
      citizenId: 'CIT-450',
      title: 'Recurring power outage',
      description: 'Power drops every evening for the entire block.',
      category: 'Utilities',
      status: 'pending',
      urgencyScore: 4,
      timestamp: DateTime(2026, 2, 28, 19, 25),
    ),
  ];

  String _selectedCategory = 'All';
  String _selectedStatus = 'All';

  MockAdminService() {
    _emit();
  }

  Stream<List<AdminComplaint>> watchComplaints() => _controller.stream;

  List<String> get categories {
    final categorySet = _allComplaints.map((item) => item.category).toSet();
    final sorted = categorySet.toList()..sort();
    return ['All', ...sorted];
  }

  List<String> get statuses => const [
        'All',
        'pending',
        'in_progress',
        'resolved',
      ];

  void setCategoryFilter(String category) {
    _selectedCategory = category;
    _emit();
  }

  void setStatusFilter(String status) {
    _selectedStatus = status;
    _emit();
  }

  void updateComplaintStatus({
    required String complaintId,
    required String newStatus,
  }) {
    final index = _allComplaints.indexWhere((item) => item.id == complaintId);
    if (index == -1) return;

    _allComplaints[index] = _allComplaints[index].copyWith(
      status: newStatus,
      timestamp: DateTime.now(),
    );

    _emit();
  }

  void _emit() {
    final filtered = _allComplaints.where((item) {
      final matchCategory =
          _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchStatus =
          _selectedStatus == 'All' || item.status == _selectedStatus;
      return matchCategory && matchStatus;
    }).toList();

    filtered.sort((a, b) {
      final byUrgency = b.urgencyScore.compareTo(a.urgencyScore);
      if (byUrgency != 0) return byUrgency;
      return b.timestamp.compareTo(a.timestamp);
    });

    _controller.add(filtered);
  }

  void dispose() {
    _controller.close();
  }
}
