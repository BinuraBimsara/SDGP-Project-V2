import 'package:flutter/material.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/gov_dashboard/presentation/widgets/gov_report_card.dart';
import 'package:spotit/features/home/presentation/pages/complaint_detail_page.dart';
import 'package:spotit/main.dart';

/// Page that shows all reports filtered by a specific status (Pending, In Progress, Resolved).
class GovStatusReportsPage extends StatefulWidget {
  final String status;

  const GovStatusReportsPage({super.key, required this.status});

  @override
  State<GovStatusReportsPage> createState() => _GovStatusReportsPageState();
}

class _GovStatusReportsPageState extends State<GovStatusReportsPage> {
  List<Complaint> _complaints = [];
  List<Complaint> _allStatusComplaints = [];
  bool _isLoading = true;
  String _sortMode = 'Highest Priority';
  String _selectedCategory = 'All';

  static const Map<String, Color> _statusColors = {
    'Pending': Color(0xFFEF5350),
    'In Progress': Color(0xFFFF9800),
    'Resolved': Color(0xFF4CAF50),
  };

  static const Map<String, IconData> _statusIcons = {
    'Pending': Icons.pending_outlined,
    'In Progress': Icons.autorenew_rounded,
    'Resolved': Icons.check_circle_outline,
  };

  static const List<String> _sortOptions = [
    'Highest Priority',
    'Lowest Priority',
    'Latest',
    'Most Upvoted',
    'Most Downvoted',
  ];

  static const List<Map<String, dynamic>> _categories = [
    {'label': 'All', 'icon': Icons.all_inclusive, 'color': Color(0xFFF9A825)},
    {'label': 'Road Damage', 'icon': Icons.remove_road, 'color': Color(0xFFE91E63)},
    {'label': 'Infrastructure', 'icon': Icons.construction, 'color': Color(0xFF2196F3)},
    {'label': 'Waste', 'icon': Icons.delete_outline, 'color': Color(0xFF4CAF50)},
    {'label': 'Lighting', 'icon': Icons.lightbulb_outline, 'color': Color(0xFFFF9800)},
    {'label': 'Other', 'icon': Icons.more_horiz, 'color': Color(0xFF607D8B)},
  ];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final repo = RepositoryProvider.of(context);
      final all = await repo.getComplaints();
      if (mounted) {
        setState(() {
          _allStatusComplaints = all
              .where((c) => c.status == widget.status)
              .toList();
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    if (_selectedCategory == 'All') {
      _complaints = List.from(_allStatusComplaints);
    } else {
      _complaints = _allStatusComplaints
          .where((c) => c.category == _selectedCategory)
          .toList();
    }
    _sortComplaints();
  }

  void _sortComplaints() {
    switch (_sortMode) {
      case 'Highest Priority':
      case 'Most Upvoted':
        _complaints.sort((a, b) => b.upvoteCount.compareTo(a.upvoteCount));
        break;
      case 'Lowest Priority':
      case 'Most Downvoted':
        _complaints.sort((a, b) => a.upvoteCount.compareTo(b.upvoteCount));
        break;
      case 'Latest':
        _complaints.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
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

  void _showFilterDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                ..._sortOptions.map((option) {
                  final isSelected = _sortMode == option;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _sortMode = option;
                          _sortComplaints();
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                            Text(
                              option,
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

  void _showCategoryFilterDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                  Icons.category_rounded,
                  color: const Color(0xFFF9A825),
                  size: 28,
                ),
                const SizedBox(height: 12),
                Text(
                  'Select Category',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Filter by report category',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                const SizedBox(height: 20),
                ..._categories.map((cat) {
                  final label = cat['label'] as String;
                  final icon = cat['icon'] as IconData;
                  final color = cat['color'] as Color;
                  final isSelected = _selectedCategory == label;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = label;
                          _applyFilters();
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withAlpha(isDark ? 40 : 25)
                              : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5)),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: color, width: 1.5)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(icon, size: 18, color: isSelected ? color : (isDark ? Colors.white54 : Colors.black45)),
                            const SizedBox(width: 12),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? color
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              Icon(Icons.check_circle, color: color, size: 20),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _statusColors[widget.status] ?? const Color(0xFF607D8B);
    final statusIcon = _statusIcons[widget.status] ?? Icons.circle;

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
            Icon(statusIcon, color: statusColor, size: 22),
            const SizedBox(width: 8),
            Text(
              widget.status,
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
          // ── Report Count & Filter Info ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                if (_selectedCategory != 'All') ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = 'All';
                        _applyFilters();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedCategory,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.close_rounded, size: 12, color: statusColor),
                        ],
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: _showCategoryFilterDialog,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.category_rounded, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        _selectedCategory,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _showFilterDialog,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        _sortMode,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
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
            'No ${widget.status.toLowerCase()} reports',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reports with this status will appear here.',
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
