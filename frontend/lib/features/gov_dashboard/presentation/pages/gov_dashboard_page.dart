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

// GovDashboardPage is the first screen officials see after logging in.
// It shows:
//   - A welcome card with the official's name and total report count
//   - A grid of complaint categories (Road, Waste, Infrastructure, etc.)
//     with the count of complaints in each category
//   - A status overview bar (Pending / In Progress / Resolved counts)
//     that you can tap to drill into that filtered list
class GovDashboardPage extends StatefulWidget {
  const GovDashboardPage({super.key});

  @override
  State<GovDashboardPage> createState() => _GovDashboardPageState();
}

class _GovDashboardPageState extends State<GovDashboardPage> {
  List<Complaint> _allComplaints = []; // all complaints loaded from Firestore
  bool _isLoading = true;              // shows a spinner while loading

  // Location state — used to show "near you" context in the header
  String _locationName = 'Detecting…'; // shown in the location pill
  double _userLat = 6.9271;            // default: Colombo
  double _userLng = 79.8612;
  bool _locationFetched = false;       // true once GPS or cached coords are ready

  // SharedPreferences keys for caching the last known location between sessions
  static const _keyLat = 'last_lat';
  static const _keyLng = 'last_lng';
  static const _keyLocName = 'last_loc_name';

  // Category definitions — label shown on the tile, query category used for filtering,
  // icon, and color. Each category matches a value in the Firestore 'category' field.
  static const List<Map<String, dynamic>> _categories = [
    {
      'label': 'Road Damage',
      'queryCategory': 'Road Damage', // what we search Firestore for
      'icon': Icons.remove_road,
      'color': Color(0xFFE91E63),
    },
    {'label': 'Infrastructure', 'icon': Icons.construction, 'color': Color(0xFF2196F3)},
    {'label': 'Waste', 'icon': Icons.delete_outline, 'color': Color(0xFF4CAF50)},
    {'label': 'Lighting', 'icon': Icons.lightbulb_outline, 'color': Color(0xFFFF9800)},
    {'label': 'Other', 'icon': Icons.more_horiz, 'color': Color(0xFF607D8B)},
  ];

  @override
  void initState() {
    super.initState();
    _initLocation(); // load cached location, then try to get live GPS
  }

  // Loads the location from cache first (instant display), then gets the
  // live GPS position in the background (updates the display when ready)
  Future<void> _initLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedLat = prefs.getDouble(_keyLat);
    final cachedLng = prefs.getDouble(_keyLng);
    final cachedName = prefs.getString(_keyLocName);

    // If we have a cached location, use it straight away so the UI isn't blank
    if (cachedLat != null && cachedLng != null) {
      _userLat = cachedLat;
      _userLng = cachedLng;
      _locationName = cachedName ?? 'Saved location';
      _locationFetched = true;
    }

    _loadComplaints();           // fetch complaints (can use any coordinates)
    _fetchLiveLocation(prefs);   // then try to improve with live GPS
  }

  // Gets the current GPS position and updates the location state.
  // Saves the new coordinates to SharedPreferences for next app launch.
  Future<void> _fetchLiveLocation(SharedPreferences prefs) async {
    try {
      final pos = await LocationService.getCurrentPosition();
      _userLat = pos.latitude;
      _userLng = pos.longitude;
      _locationFetched = true;

      // Convert the coordinates to a human-readable address
      final address = await LocationService.reverseGeocode(pos.latitude, pos.longitude);
      final shortAddr = _shortenAddress(address);

      // Save to cache so we can use it next time without waiting for GPS
      await prefs.setDouble(_keyLat, pos.latitude);
      await prefs.setDouble(_keyLng, pos.longitude);
      await prefs.setString(_keyLocName, shortAddr);

      if (mounted) setState(() => _locationName = shortAddr);
    } on LocationServiceException {
      // GPS permission denied or timed out — keep the cached or default location
    }
  }

  // Shortens a long address like "Galle Road, Colombo 3, Colombo, Western"
  // down to the last 2 parts: "Colombo 3, Colombo" — fits better in the pill
  String _shortenAddress(String address) {
    final parts = address.split(', ');
    if (parts.length > 2) return parts.sublist(parts.length - 2).join(', ');
    return address;
  }

  // Opens the map picker screen so the official can manually choose a location.
  // Updates the displayed location if the user picks a new place.
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

  // Fetches all complaints from Firestore via the repository.
  // Called on init and on pull-to-refresh.
  Future<void> _loadComplaints() async {
    setState(() => _isLoading = true);
    try {
      final repo = RepositoryProvider.of(context); // get the complaint data source
      final complaints = await repo.getComplaints(); // fetch all without filtering
      if (mounted) {
        setState(() {
          _allComplaints = complaints;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Returns true if two category strings match, with special handling for Road/Road Damage
  // since both "Road" and "Road Damage" should count in the Road Damage tile
  bool _categoryMatches(String complaintCategory, String selectedCategory) {
    final complaint = complaintCategory.trim().toLowerCase();
    final selected = selectedCategory.trim().toLowerCase();
    if (selected == 'road damage') {
      return complaint == 'road damage' || complaint == 'road'; // both count
    }
    return complaint == selected;
  }

  // Counts how many loaded complaints belong to a given category
  int _countByCategory(String category) {
    return _allComplaints
        .where((c) => _categoryMatches(c.category, category))
        .length;
  }

  // Gets the official's display name from Firebase Auth.
  // Falls back to the email prefix if no display name is set.
  String _getUserName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        return user.displayName!; // e.g. "John Silva"
      }
      if (user.email != null && user.email!.isNotEmpty) {
        return user.email!.split('@').first; // e.g. "john.silva" from "john.silva@gov.lk"
      }
    }
    return 'Official'; // fallback
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: const Color(0xFFF9A825),
        onRefresh: _loadComplaints, // pull down to reload
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // always scrollable for refresh
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(isDark),      // gold welcome banner at the top
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text('Report Categories',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87)),
                  ),
                  _buildLocationBar(isDark), // tappable location pill on the right
                ],
              ),
              const SizedBox(height: 16),
              // Show spinner while loading, or the category grid once loaded
              _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: CircularProgressIndicator(color: Color(0xFFF9A825)),
                      ))
                  : _buildCategoryGrid(isDark),
              const SizedBox(height: 24),
              _buildTotalReportsSummary(isDark), // Pending/In Progress/Resolved counts
            ],
          ),
        ),
      ),
    );
  }

  // The tappable location pill shown next to "Report Categories".
  // Tapping it opens the map picker so the official can change their area focus.
  Widget _buildLocationBar(bool isDark) {
    return GestureDetector(
      onTap: _changeLocation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        constraints: const BoxConstraints(maxWidth: 170), // don't let it get too wide
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withAlpha(26) : Colors.black.withAlpha(26),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _locationFetched
                  ? Icons.location_on             // solid pin = we have coords
                  : Icons.location_searching_rounded, // animated = still fetching
              color: const Color(0xFFF9A825),
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _locationName,
                overflow: TextOverflow.ellipsis, // truncate if the name is too long
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // The gold gradient welcome card at the top of the page
  Widget _buildWelcomeCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF9A825), Color(0xFFF57F17)], // gold gradient
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
                child: const Icon(Icons.shield_outlined, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Welcome back,',
                        style: TextStyle(
                            fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(_getUserName(), // the official's name from Firebase Auth
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Small analytics pill showing total report count
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
                Text('${_allComplaints.length} total reports',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Builds the grid of category tiles using a Wrap widget.
  // Wrap automatically wraps to the next row when tiles don't fit in one row.
  Widget _buildCategoryGrid(bool isDark) {
    return Center(
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        alignment: WrapAlignment.center,
        children: _categories.map((cat) {
          // Use queryCategory for the Firestore query if specified,
          // otherwise fall back to the display label
          final queryCategory = (cat['queryCategory'] as String?) ?? (cat['label'] as String);
          final count = _countByCategory(queryCategory);
          return SizedBox(
            // Each tile takes 1/3 of the available width (3 tiles per row)
            width: (MediaQuery.of(context).size.width - 40 - 28) / 3,
            child: _buildCategoryTile(
              label: cat['label'] as String,
              queryCategory: queryCategory,
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

  // A tappable card showing one complaint category with its icon and count.
  // Tapping it navigates to GovCategoryReportsPage filtered to that category.
  Widget _buildCategoryTile({
    required String label,
    required String queryCategory,
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
              // The repository provider must be re-wrapped here because
              // the new route doesn't inherit from the parent's widget tree
              repository: RepositoryProvider.of(context),
              child: GovCategoryReportsPage(
                category: queryCategory,
                title: label,
              ),
            ),
          ),
        ).then((_) => _loadComplaints()); // reload counts when returning from detail
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withAlpha(40) : Colors.black.withAlpha(12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Coloured icon inside a lightly tinted background circle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(25), // very light tint of the category color
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(label, // e.g. "Road Damage"
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            // The big number — how many complaints are in this category
            Text('$count',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }

  // Shows the Pending / In Progress / Resolved counts as tappable chips.
  // Tapping one navigates to the filtered list of complaints with that status.
  Widget _buildTotalReportsSummary(bool isDark) {
    // Count complaints in each status group
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
            color: isDark ? Colors.black.withAlpha(40) : Colors.black.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status Overview',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatusChip('Pending', pending, const Color(0xFFEF5350), isDark),   // red
              const SizedBox(width: 12),
              _buildStatusChip('In Progress', inProgress, const Color(0xFFFF9800), isDark), // orange
              const SizedBox(width: 12),
              _buildStatusChip('Resolved', resolved, const Color(0xFF4CAF50), isDark), // green
            ],
          ),
        ],
      ),
    );
  }

  // A single tappable status chip showing a count and label.
  // Expanded so all three chips share equal width.
  Widget _buildStatusChip(String label, int count, Color color, bool isDark) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // Navigate to the full list of complaints with this status
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RepositoryProvider(
                repository: RepositoryProvider.of(context),
                child: GovStatusReportsPage(status: label),
              ),
            ),
          ).then((_) => _loadComplaints()); // refresh counts on return
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withAlpha(isDark ? 30 : 20), // very faint tinted background
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text('$count',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
