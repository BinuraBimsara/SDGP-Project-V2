import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotit/core/services/location_service.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/gov_dashboard/presentation/pages/gov_category_reports_page.dart';
import 'package:spotit/features/gov_dashboard/presentation/pages/gov_status_reports_page.dart';
import 'package:spotit/features/home/presentation/widgets/location_picker_screen.dart';
import 'package:spotit/main.dart';

/// Main government dashboard page.
/// Shows a welcome header and category tiles with report counts.
class GovDashboardPage extends StatefulWidget {
  const GovDashboardPage({super.key});

  @override
  State<GovDashboardPage> createState() => _GovDashboardPageState();
}

class _GovDashboardPageState extends State<GovDashboardPage> {
  List<Complaint> _allComplaints = [];
  bool _isLoading = true;

  // ── Location state ──
  String _locationName = 'Detecting…';
  double _userLat = 6.9271;
  double _userLng = 79.8612;
  bool _locationFetched = false;
  static const _keyLat = 'last_lat';
  static const _keyLng = 'last_lng';
  static const _keyLocName = 'last_loc_name';

  // Category definitions matching the report function
  static const List<Map<String, dynamic>> _categories = [
    {'label': 'Road Damage', 'icon': Icons.remove_road, 'color': Color(0xFFE91E63)},
    {'label': 'Infrastructure', 'icon': Icons.construction, 'color': Color(0xFF2196F3)},
    {'label': 'Waste', 'icon': Icons.delete_outline, 'color': Color(0xFF4CAF50)},
    {'label': 'Lighting', 'icon': Icons.lightbulb_outline, 'color': Color(0xFFFF9800)},
    {'label': 'Other', 'icon': Icons.more_horiz, 'color': Color(0xFF607D8B)},
  ];

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedLat = prefs.getDouble(_keyLat);
    final cachedLng = prefs.getDouble(_keyLng);
    final cachedName = prefs.getString(_keyLocName);
    if (cachedLat != null && cachedLng != null) {
      _userLat = cachedLat;
      _userLng = cachedLng;
      _locationName = cachedName ?? 'Saved location';
      _locationFetched = true;
    }
    _loadComplaints();
    _fetchLiveLocation(prefs);
  }

  Future<void> _fetchLiveLocation(SharedPreferences prefs) async {
    try {
      final pos = await LocationService.getCurrentPosition();
      _userLat = pos.latitude;
      _userLng = pos.longitude;
      _locationFetched = true;
      final address = await LocationService.reverseGeocode(pos.latitude, pos.longitude);
      final shortAddr = _shortenAddress(address);
      await prefs.setDouble(_keyLat, pos.latitude);
      await prefs.setDouble(_keyLng, pos.longitude);
      await prefs.setString(_keyLocName, shortAddr);
      if (mounted) setState(() => _locationName = shortAddr);
    } on LocationServiceException {
      // Keep cached/default
    }
  }

  String _shortenAddress(String address) {
    final parts = address.split(', ');
    if (parts.length > 2) return parts.sublist(parts.length - 2).join(', ');
    return address;
  }

  Future<void> _changeLocation() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialLatLng: LatLng(_userLat, _userLng)),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _userLat = result.latLng.latitude;
        _userLng = result.latLng.longitude;
        _locationName = _shortenAddress(result.address);
        _locationFetched = true;
      });
    }
  }

  Future<void> _loadComplaints() async {
    setState(() => _isLoading = true);
    try {
      final repo = RepositoryProvider.of(context);
      final complaints = await repo.getComplaints();
      if (mounted) {
        setState(() {
          _allComplaints = complaints;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _countByCategory(String category) {
    return _allComplaints
        .where((c) => c.category.toLowerCase() == category.toLowerCase())
        .toList()
        .length;
  }

  String _getUserName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        return user.displayName!;
      }
      if (user.email != null && user.email!.isNotEmpty) {
        return user.email!.split('@').first;
      }
    }
    return 'Official';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: const Color(0xFFF9A825),
        onRefresh: _loadComplaints,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Location Bar ──
              _buildLocationBar(isDark),
              const SizedBox(height: 16),

              // ── Welcome Card ──
              _buildWelcomeCard(isDark),
              const SizedBox(height: 28),

              // ── Section Title ──
              Text(
                'Report Categories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // ── Category Grid ──
              _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: CircularProgressIndicator(
                          color: Color(0xFFF9A825),
                        ),
                      ),
                    )
                  : _buildCategoryGrid(isDark),

              const SizedBox(height: 24),

              // ── Total Reports Summary ──
              _buildTotalReportsSummary(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationBar(bool isDark) {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: _changeLocation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 200),
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
                _locationFetched
                    ? Icons.location_on
                    : Icons.location_searching_rounded,
                color: const Color(0xFFF9A825),
                size: 16,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _locationName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF9A825), Color(0xFFF57F17)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF9A825).withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back,',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getUserName(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.analytics_outlined, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${_allComplaints.length} total reports',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(bool isDark) {
    return Center(
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        alignment: WrapAlignment.center,
        children: _categories.map((cat) {
          final count = _countByCategory(cat['label'] as String);
          return SizedBox(
            width: (MediaQuery.of(context).size.width - 40 - 28) / 3,
            child: _buildCategoryTile(
              label: cat['label'] as String,
              icon: cat['icon'] as IconData,
              color: cat['color'] as Color,
              count: count,
              isDark: isDark,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryTile({
    required String label,
    required IconData icon,
    required Color color,
    required int count,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RepositoryProvider(
              repository: RepositoryProvider.of(context),
              child: GovCategoryReportsPage(category: label),
            ),
          ),
        ).then((_) => _loadComplaints());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withAlpha(40)
                  : Colors.black.withAlpha(12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            // Label
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Count
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalReportsSummary(bool isDark) {
    final pending = _allComplaints.where((c) => c.status == 'Pending').length;
    final inProgress = _allComplaints.where((c) => c.status == 'In Progress').length;
    final resolved = _allComplaints.where((c) => c.status == 'Resolved').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha(40)
                : Colors.black.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatusChip('Pending', pending, const Color(0xFFEF5350), isDark),
              const SizedBox(width: 12),
              _buildStatusChip('In Progress', inProgress, const Color(0xFFFF9800), isDark),
              const SizedBox(width: 12),
              _buildStatusChip('Resolved', resolved, const Color(0xFF4CAF50), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color, bool isDark) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RepositoryProvider(
                repository: RepositoryProvider.of(context),
                child: GovStatusReportsPage(status: label),
              ),
            ),
          ).then((_) => _loadComplaints());
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withAlpha(isDark ? 30 : 20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
