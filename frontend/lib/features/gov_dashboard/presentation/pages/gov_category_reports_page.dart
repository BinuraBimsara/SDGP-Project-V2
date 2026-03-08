import 'package:flutter/material.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/gov_dashboard/presentation/widgets/gov_report_card.dart';
import 'package:spotit/features/home/presentation/pages/complaint_detail_page.dart';
import 'package:spotit/main.dart';

/// Sort modes for report listing.
enum ReportSortMode {
  highestPriority,
  lowestPriority,
  latest,
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
          // ── Report Count & Sort Info ──
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
                GestureDetector(
                  onTap: () => _showFilterDialog(isDark, catColor),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort, size: 14, color: catColor),
                      const SizedBox(width: 4),
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
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RepositoryProvider(
                                      repository: RepositoryProvider.of(context),
                                      child: ComplaintDetailPage(
                                        complaint: _complaints[index],
                                        isOfficial: true,
                                      ),
                                    ),
                                  ),
                                ).then((_) => _loadReports());
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(bool isDark, Color accentColor) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_list_rounded,
                  color: const Color(0xFFF9A825),
                  size: 28,
                ),
                const SizedBox(height: 12),
                Text(
                  'Sort Reports',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Filter reports by priority',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                const SizedBox(height: 20),
                ...ReportSortMode.values.map((mode) {
                  final isSelected = _sortMode == mode;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _sortMode = mode;
                          _sortComplaints();
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFF9A825).withAlpha(isDark ? 40 : 25)
                              : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5)),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: const Color(0xFFF9A825), width: 1.5)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _sortModeIcon(mode),
                              size: 18,
                              color: isSelected
                                  ? const Color(0xFFF9A825)
                                  : (isDark ? Colors.white54 : Colors.black45),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _sortModeLabel(mode),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFFF9A825)
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFFF9A825),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
