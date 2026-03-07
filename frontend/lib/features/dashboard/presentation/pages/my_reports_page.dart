import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';
import 'package:spotit/features/home/presentation/pages/complaint_detail_page.dart';
import 'package:spotit/features/home/presentation/widgets/complaint_card.dart';
import 'package:spotit/main.dart';

class MyReportsPage extends StatefulWidget {
  const MyReportsPage({super.key});

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  List<Complaint> _allComplaints = [];
  List<Complaint> _filteredComplaints = [];
  String _selectedFilter = 'All';
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
      _loadMyReports();
    }
  }

  Future<void> _loadMyReports() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load all complaints and filter by current user's authorId
      final complaints = await _repository.getComplaints();
      final myComplaints =
          complaints.where((c) => c.authorId == user.uid).toList();

      setState(() {
        _allComplaints = myComplaints;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading my reports: $e');
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    if (_selectedFilter == 'All') {
      _filteredComplaints = List.from(_allComplaints);
    } else {
      _filteredComplaints =
          _allComplaints.where((c) => c.category == _selectedFilter).toList();
    }
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
                      'Filter your reports by type',
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
                          setState(() {
                            _selectedFilter = category;
                            _applyFilter();
                          });
                          Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildFiltersBar(isDark),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFF9A825)),
                  )
                : RefreshIndicator(
                    onRefresh: _loadMyReports,
                    color: const Color(0xFFF9A825),
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    displacement: 40,
                    strokeWidth: 2.5,
                    child: _buildFeed(isDark),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersBar(bool isDark) {
    final bool hasActiveFilter = _selectedFilter != 'All';

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
                  setState(() {
                    _selectedFilter = 'All';
                    _applyFilter();
                  });
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
                        _selectedFilter,
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
        ],
      ),
    );
  }

  Widget _buildFeed(bool isDark) {
    if (_filteredComplaints.isEmpty) {
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
                    Icons.article_outlined,
                    size: 48,
                    color: isDark ? Colors.white.withAlpha(80) : Colors.black26,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFilter == 'All'
                        ? 'No reports yet'
                        : 'No $_selectedFilter reports',
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
        itemCount: _filteredComplaints.length,
        itemBuilder: (context, index) {
          return ComplaintCard(
            complaint: _filteredComplaints[index],
            onUpvoteChanged: (isUpvoted) {
              setState(() {
                final complaintIndex = _allComplaints.indexWhere(
                  (c) => c.id == _filteredComplaints[index].id,
                );
                if (complaintIndex != -1) {
                  final old = _allComplaints[complaintIndex];
                  _allComplaints[complaintIndex] = old.copyWith(
                    isUpvoted: isUpvoted,
                    upvoteCount: old.upvoteCount + (isUpvoted ? 1 : -1),
                  );
                  _applyFilter();
                }
              });
              _repository.toggleUpvote(_filteredComplaints[index].id);
            },
            onTap: () async {
              final result = await Navigator.push<Complaint>(
                context,
                MaterialPageRoute(
                  builder: (_) => ComplaintDetailPage(
                      complaint: _filteredComplaints[index]),
                ),
              );
              if (result != null) {
                _loadMyReports();
              }
            },
          );
        },
      ),
    );
  }
}
