import 'dart:ui';
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
    'Road Damage',
    'Infrastructure',
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
              : RefreshIndicator(
                  onRefresh: _loadComplaints,
                  color: const Color(0xFFF9A825),
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  displacement: 40,
                  strokeWidth: 2.5,
                  child: _buildFeed(),
                ),
        ),
      ],
    );
  }

  Widget _buildFiltersBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool hasActiveFilter =
        _selectedFilter != null && _selectedFilter != 'All';

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
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

          // Selected Category Chip (only when not 'All')
          if (hasActiveFilter) ...[
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(-0.2, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: GestureDetector(
                key: ValueKey(_selectedFilter),
                onTap: () {
                  // Tapping the chip resets to 'All'
                  setState(() => _selectedFilter = 'All');
                  _loadComplaints();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF9A825).withAlpha(120),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedFilter!,
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFF9A825)
                              : const Color(0xFFE65100),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: isDark
                            ? const Color(0xFFF9A825)
                            : const Color(0xFFE65100),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const Spacer(),

          // Location Button
          GestureDetector(
            onTap: _showLocationMockupDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withAlpha(26)
                      : Colors.black.withAlpha(26),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on,
                    color: isDark ? Colors.white70 : Colors.black54,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Colombo',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
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

  // ── Reusable blurred + animated dialog ──
  Future<T?> _showBlurredDialog<T>(Widget child) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withAlpha(80),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, secondaryAnim, dialogChild) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 12 * anim.value,
            sigmaY: 12 * anim.value,
          ),
          child: ScaleTransition(
            scale: curved,
            child: FadeTransition(
              opacity: anim,
              child: dialogChild,
            ),
          ),
        );
      },
      pageBuilder: (ctx, anim, secondaryAnim) {
        return Center(child: child);
      },
    );
  }

  void _showFilterDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _showBlurredDialog(
      Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(20)
                  : Colors.black.withAlpha(15),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(80),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  children: [
                    const Icon(
                      Icons.filter_list_rounded,
                      color: Color(0xFFF9A825),
                      size: 28,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Select Category',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Filter complaints by type',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // ── Category List ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: _filters.map((category) {
                    final isSelected = _selectedFilter == category;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedFilter = category);
                          Navigator.pop(context);
                          _loadComplaints();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFF9A825)
                                    .withAlpha(isDark ? 40 : 30)
                                : isDark
                                    ? Colors.white.withAlpha(8)
                                    : Colors.grey.withAlpha(15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFF9A825).withAlpha(120)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFFF9A825)
                                        : isDark
                                            ? Colors.white
                                            : Colors.black87,
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFFF9A825),
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // ── Close action ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white54 : Colors.black45,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLocationMockupDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _showBlurredDialog(
      Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(20)
                  : Colors.black.withAlpha(15),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(80),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  children: [
                    const Icon(
                      Icons.map_rounded,
                      color: Color(0xFFF9A825),
                      size: 28,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Change Location',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // ── Map Mock ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(12),
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
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Drag the pin to set your current location for the feed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ── Actions ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              isDark ? Colors.white54 : Colors.black45,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  const Text('Location updated successfully!'),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeed() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_complaints.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
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
                      color:
                          isDark ? Colors.white.withAlpha(128) : Colors.black45,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pull down to refresh',
                    style: TextStyle(
                      color:
                          isDark ? Colors.white.withAlpha(80) : Colors.black26,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: ListView.builder(
        key: ValueKey(_selectedFilter),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: _complaints.length,
        itemBuilder: (context, index) {
          return ComplaintCard(
            complaint: _complaints[index],
            onUpvoteChanged: (isUpvoted) {
              // Only update locally for immediate UI feedback
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
              // Persist to database — only increment, not decrement
              if (isUpvoted) {
                _repository.toggleUpvote(_complaints[index].id);
              }
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
                // Reload complaints to get fresh data from Firebase
                _loadComplaints();
              }
            },
          );
        },
      ),
    );
  }
}
