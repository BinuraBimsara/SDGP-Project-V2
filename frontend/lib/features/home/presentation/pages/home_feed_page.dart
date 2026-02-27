import 'package:flutter/material.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';
import 'package:spotit/core/services/location_service.dart';
import 'package:spotit/features/home/presentation/pages/complaint_detail_page.dart';
import 'package:spotit/features/home/presentation/widgets/complaint_card.dart';
import 'package:spotit/main.dart';

class HomeFeedPage extends StatefulWidget {
  const HomeFeedPage({super.key});

  @override
  State<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage> {
  List<Complaint> _complaints = [];
  String? _selectedFilter;
  bool _isLoading = true;
  late ComplaintRepository _repository;

  final List<String> _filters = [
    'All',
    'Waste',
    'Lighting',
    'Pothole',
    'Infrastructure',
    'Utilities',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository = RepositoryProvider.of(context);
    if (_isLoading) {
      _selectedFilter = 'All';
      _loadComplaints();
    }
  }

  Future<void> _loadComplaints() async {
    setState(() => _isLoading = true);
    try {
      final filter = (_selectedFilter == 'All') ? null : _selectedFilter;

      // Simulate fetching current user location (Colombo fallback if missing)
      final locationService = LocationService();
      final position = await locationService.determinePosition();

      final complaints = await _repository.getComplaints(
        category: filter,
        userLat: position.latitude,
        userLng: position.longitude,
      );

      setState(() {
        _complaints = complaints;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading complaints: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFiltersBar(),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFF9A825)),
                )
              : _buildFeed(),
        ),
      ],
    );
  }

  Widget _buildFiltersBar() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Filter Button
          GestureDetector(
            onTap: _showFilterDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9A825),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_list_rounded,
                      color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Filters',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Location Button
          GestureDetector(
            onTap: _showLocationMockupDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black54,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Colombo',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.filter_list_rounded,
                    color: Color(0xFFF9A825),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Select Category',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: _filters.map((category) {
                  final isSelected = _selectedFilter == category;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? const Color(0xFFF9A825)
                          : isDark
                              ? Colors.white.withValues(alpha: 0.4)
                              : Colors.black38,
                      size: 22,
                    ),
                    title: Text(
                      category,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      setDialogState(() {
                        _selectedFilter = category;
                      });
                      setState(() {
                        _selectedFilter = category;
                      });
                      // Close dialog and load new filters
                      Navigator.pop(context);
                      _loadComplaints();
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.black45,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLocationMockupDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.map_rounded, color: Color(0xFFF9A825), size: 22),
              const SizedBox(width: 8),
              Text(
                'Change Location',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on,
                          color: Color(0xFFEF5350), size: 40),
                      SizedBox(height: 8),
                      Text(
                        'Google Maps Mock UI Component',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Drag the pin to set your current location for the feed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Location updated successfully!'),
                    backgroundColor: const Color(0xFFF9A825),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF9A825),
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Location'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeed() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_complaints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: isDark ? Colors.white.withAlpha(80) : Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(
              'No complaints found',
              style: TextStyle(
                color: isDark ? Colors.white.withAlpha(128) : Colors.black45,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: ListView.builder(
        key: ValueKey(_selectedFilter),
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: _complaints.length,
        itemBuilder: (context, index) {
          return ComplaintCard(
            complaint: _complaints[index],
            onUpvoteChanged: (isUpvoted) {
              setState(() {
                final complaintIndex = _complaints.indexWhere(
                  (c) => c.id == _complaints[index].id,
                );
                if (complaintIndex != -1) {
                  final old = _complaints[complaintIndex];
                  _complaints[complaintIndex] = old.copyWith(
                    isUpvoted: isUpvoted,
                    upvoteCount: old.upvoteCount + (isUpvoted ? 1 : -1),
                  );
                }
              });
              // Persist to database
              _repository.toggleUpvote(_complaints[index].id);
            },
            onTap: () async {
              final result = await Navigator.push<Complaint>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ComplaintDetailPage(complaint: _complaints[index]),
                ),
              );
              if (result != null) {
                setState(() {
                  final i = _complaints.indexWhere((c) => c.id == result.id);
                  if (i != -1) {
                    _complaints[i] = result;
                  }
                });
              }
            },
          );
        },
      ),
    );
  }
}
