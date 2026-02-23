import 'package:flutter/material.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';
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
      final complaints = await _repository.getComplaints(category: filter);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Main Filters pill
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFilter = 'All';
                });
                _loadComplaints();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9A825),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.filter_list_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
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
            const SizedBox(width: 8),
            // Category pills with animation
            ..._filters.where((f) => f != 'All').map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFilter = isSelected ? 'All' : filter;
                    });
                    _loadComplaints();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF9A825).withAlpha(50)
                          : isDark
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFF9A825)
                            : isDark
                                ? Colors.white.withAlpha(25)
                                : Colors.black.withAlpha(25),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFF9A825).withAlpha(80),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFF9A825)
                            : isDark
                                ? Colors.white.withAlpha(150)
                                : Colors.black54,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: isSelected ? 13.5 : 13,
                      ),
                      child: Text(filter),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
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
