import 'package:flutter/material.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/gov_dashboard/presentation/widgets/gov_report_card.dart';
import 'package:spotit/main.dart';

/// Sort modes for report listing.
enum ReportSortMode {
  highestPriority,
  lowestPriority,
  latest,
  mostUpvoted,
  mostDownvoted,
}

/// Page that shows all reports under a specific category.
/// Default sort: highest priority (most upvotes first).
class GovCategoryReportsPage extends StatefulWidget {
  final String category;

  const GovCategoryReportsPage({super.key, required this.category});

  @override
  State<GovCategoryReportsPage> createState() => _GovCategoryReportsPageState();
}

class _GovCategoryReportsPageState extends State<GovCategoryReportsPage> {
  List<Complaint> _complaints = [];
  bool _isLoading = true;
  ReportSortMode _sortMode = ReportSortMode.highestPriority;

  static const Map<String, Color> _categoryColors = {
    'Road Damage': Color(0xFFE91E63),
    'Infrastructure': Color(0xFF2196F3),
    'Waste': Color(0xFF4CAF50),
    'Lighting': Color(0xFFFF9800),
    'Other': Color(0xFF607D8B),
  };

  static const Map<String, IconData> _categoryIcons = {
    'Road Damage': Icons.remove_road,
    'Infrastructure': Icons.construction,
    'Waste': Icons.delete_outline,
    'Lighting': Icons.lightbulb_outline,
    'Other': Icons.more_horiz,
  };

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final repo = RepositoryProvider.of(context);
      final all = await repo.getComplaints(category: widget.category);
      if (mounted) {
        setState(() {
          _complaints = all;
          _sortComplaints();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sortComplaints() {
    switch (_sortMode) {
      case ReportSortMode.highestPriority:
        _complaints.sort((a, b) => b.upvoteCount.compareTo(a.upvoteCount));
        break;
      case ReportSortMode.lowestPriority:
        _complaints.sort((a, b) => a.upvoteCount.compareTo(b.upvoteCount));
        break;
      case ReportSortMode.latest:
        _complaints.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case ReportSortMode.mostUpvoted:
        _complaints.sort((a, b) => b.upvoteCount.compareTo(a.upvoteCount));
        break;
      case ReportSortMode.mostDownvoted:
        _complaints.sort((a, b) => a.upvoteCount.compareTo(b.upvoteCount));
        break;
    }
  }

  String _sortModeLabel(ReportSortMode mode) {
    switch (mode) {
      case ReportSortMode.highestPriority:
        return 'Highest Priority';
      case ReportSortMode.lowestPriority:
        return 'Lowest Priority';
      case ReportSortMode.latest:
        return 'Latest';
      case ReportSortMode.mostUpvoted:
        return 'Most Upvoted';
      case ReportSortMode.mostDownvoted:
        return 'Most Downvoted';
    }
  }

  IconData _sortModeIcon(ReportSortMode mode) {
    switch (mode) {
      case ReportSortMode.highestPriority:
        return Icons.arrow_upward;
      case ReportSortMode.lowestPriority:
        return Icons.arrow_downward;
      case ReportSortMode.latest:
        return Icons.access_time;
      case ReportSortMode.mostUpvoted:
        return Icons.thumb_up_outlined;
      case ReportSortMode.mostDownvoted:
        return Icons.thumb_down_outlined;
    }
  }

  Future<void> _onStatusChanged(String complaintId, String newStatus) async {
    try {
      final repo = RepositoryProvider.of(context);
      await repo.updateStatus(complaintId, newStatus);
      await _loadReports();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catColor = _categoryColors[widget.category] ?? const Color(0xFF607D8B);
    final catIcon = _categoryIcons[widget.category] ?? Icons.more_horiz;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(catIcon, color: catColor, size: 22),
            const SizedBox(width: 8),
            Text(
              widget.category,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Sort/Filter Bar ──
          _buildSortBar(isDark, catColor),

          // ── Report Count ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_complaints.length} reports',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                const Spacer(),
                Text(
                  _sortModeLabel(_sortMode),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: catColor,
                  ),
                ),
              ],
            ),
          ),

          // ── Report List ──
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFF9A825)),
                  )
                : _complaints.isEmpty
                    ? _buildEmptyState(isDark)
                    : RefreshIndicator(
                        color: const Color(0xFFF9A825),
                        onRefresh: _loadReports,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: _complaints.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return GovReportCard(
                              complaint: _complaints[index],
                              priorityRank: index + 1,
                              onStatusChanged: _onStatusChanged,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortBar(bool isDark, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ReportSortMode.values.map((mode) {
            final isSelected = _sortMode == mode;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _sortModeIcon(mode),
                      size: 14,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _sortModeLabel(mode),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white60 : Colors.black54),
                      ),
                    ),
                  ],
                ),
                backgroundColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                selectedColor: accentColor,
                checkmarkColor: Colors.white,
                showCheckmark: false,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? accentColor : Colors.transparent,
                  ),
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _sortMode = mode;
                      _sortComplaints();
                    });
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          const SizedBox(height: 16),
          Text(
            'No reports in this category',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reports will appear here when citizens\nsubmit them.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }
}
