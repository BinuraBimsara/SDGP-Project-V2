import 'package:flutter/material.dart';
import 'package:spotit/features/admin/data/models/admin_complaint.dart';
import 'package:spotit/features/admin/data/services/mock_admin_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late final MockAdminService _service;
  late final Stream<List<AdminComplaint>> _stream;

  String _selectedCategory = 'All';
  String _selectedStatus = 'All';

  @override
  void initState() {
    super.initState();
    _service = MockAdminService();
    _stream = _service.watchComplaints();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, isDesktop),
      drawer: isDesktop ? null : _buildDrawer(context),
      body: isDesktop
          ? Row(
              children: [
                SizedBox(width: 250, child: _buildSidebar(context)),
                Expanded(child: _buildMainContent(context)),
              ],
            )
          : _buildMainContent(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      leading: isDesktop
          ? null
          : Builder(
              builder: (context) => IconButton(
                icon: Icon(
                  Icons.menu_rounded,
                  color: isDark ? Colors.white.withAlpha(204) : Colors.black87,
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.admin_panel_settings_rounded,
              color: Color(0xFFF9A825), size: 20),
          const SizedBox(width: 6),
          Text(
            'Government Dashboard',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      centerTitle: true,
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF101010)
          : Colors.white,
      child: _buildSidebar(context),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.withAlpha(51)),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFFF9A825), size: 24),
              const SizedBox(width: 8),
              Text(
                'SpotIT LK',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        _buildSidebarItem(
          context: context,
          icon: Icons.dashboard_rounded,
          title: 'Admin Overview',
          subtitle: 'Monitor all complaints',
        ),
        _buildSidebarItem(
          context: context,
          icon: Icons.rule_rounded,
          title: 'Voting Disabled',
          subtitle: 'Officials cannot vote',
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              side: BorderSide(
                color: isDark
                    ? Colors.white.withAlpha(51)
                    : Colors.black.withAlpha(31),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Back to Home'),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: textColor.withAlpha(13),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFFF9A825), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: textColor.withAlpha(153), fontSize: 12),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return StreamBuilder<List<AdminComplaint>>(
      stream: _stream,
      builder: (context, snapshot) {
        final complaints = snapshot.data ?? [];

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryHeader(context, complaints),
              const SizedBox(height: 14),
              _buildFilterBar(context),
              const SizedBox(height: 10),
              Expanded(
                child: complaints.isEmpty
                    ? const Center(
                        child: Text('No complaints for the current filters.'),
                      )
                    : isWide
                        ? _buildTable(context, complaints)
                        : _buildCardList(context, complaints),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryHeader(
    BuildContext context,
    List<AdminComplaint> complaints,
  ) {
    final urgentCount = complaints.where((c) => c.urgencyScore >= 4).length;
    final pendingCount = complaints.where((c) => c.status == 'pending').length;
    final resolvedCount =
        complaints.where((c) => c.status == 'resolved').length;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _buildStatCard('Total', complaints.length.toString(), Icons.list_alt),
        _buildStatCard('Urgent', urgentCount.toString(), Icons.priority_high),
        _buildStatCard('Pending', pendingCount.toString(), Icons.schedule),
        _buildStatCard('Resolved', resolvedCount.toString(), Icons.check_circle),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      width: 170,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(15)
              : Colors.black.withAlpha(20),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF9A825), size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final categories = _service.categories;
    final statuses = _service.statuses;

    return Row(
      children: [
        Expanded(
          child: _buildDropdown(
            label: 'Category',
            value: _selectedCategory,
            options: categories,
            onChanged: (value) {
              setState(() => _selectedCategory = value);
              _service.setCategoryFilter(value);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildDropdown(
            label: 'Status',
            value: _selectedStatus,
            options: statuses,
            onChanged: (value) {
              setState(() => _selectedStatus = value);
              _service.setStatusFilter(value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(15)
              : Colors.black.withAlpha(20),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: options
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text('$label: ${_labelize(item)}'),
                  ))
              .toList(),
          onChanged: (newValue) {
            if (newValue != null) onChanged(newValue);
          },
        ),
      ),
    );
  }

  Widget _buildTable(BuildContext context, List<AdminComplaint> complaints) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(15)
              : Colors.black.withAlpha(20),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Complaint')),
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('Urgency')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Updated')),
            DataColumn(label: Text('Change Status')),
          ],
          rows: complaints
              .map(
                (item) => DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text(item.category)),
                    DataCell(Text(item.urgencyScore.toString())),
                    DataCell(_buildStatusBadge(item.status)),
                    DataCell(Text(_formatDate(item.timestamp))),
                    DataCell(
                      _buildStatusDropdown(
                        complaintId: item.id,
                        currentStatus: item.status,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildCardList(BuildContext context, List<AdminComplaint> complaints) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return ListView.builder(
      itemCount: complaints.length,
      itemBuilder: (context, index) {
        final item = complaints[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(15)
                  : Colors.black.withAlpha(20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  _buildStatusBadge(item.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetaChip('Category: ${item.category}'),
                  _buildMetaChip('Urgency: ${item.urgencyScore}'),
                  _buildMetaChip('Updated: ${_formatDate(item.timestamp)}'),
                ],
              ),
              const SizedBox(height: 12),
              _buildStatusDropdown(
                complaintId: item.id,
                currentStatus: item.status,
                fullWidth: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetaChip(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.black54,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(102)),
      ),
      child: Text(
        _labelize(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }

  Widget _buildStatusDropdown({
    required String complaintId,
    required String currentStatus,
    bool fullWidth = false,
  }) {
    return SizedBox(
      width: fullWidth ? double.infinity : 150,
      child: DropdownButtonFormField<String>(
        initialValue: currentStatus,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        items: const [
          DropdownMenuItem(value: 'pending', child: Text('Pending')),
          DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
          DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
        ],
        onChanged: (newValue) {
          if (newValue == null) return;
          _service.updateComplaintStatus(
            complaintId: complaintId,
            newStatus: newValue,
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved':
        return const Color(0xFF2EAA5E);
      case 'in_progress':
        return const Color(0xFFF9A825);
      default:
        return const Color(0xFFE57373);
    }
  }

  String _labelize(String value) {
    if (value == 'All') return value;
    return value
        .split('_')
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String _formatDate(DateTime dateTime) {
    final year = dateTime.year;
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}
