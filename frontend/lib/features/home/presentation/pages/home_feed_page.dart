import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotit/features/complaints/data/models/complaint_model.dart';
import 'package:spotit/features/complaints/domain/repositories/complaint_repository.dart';
import 'package:spotit/core/services/location_service.dart';
import 'package:spotit/features/home/presentation/pages/complaint_detail_page.dart';
import 'package:spotit/features/home/presentation/widgets/complaint_card.dart';
import 'package:spotit/features/home/presentation/widgets/location_picker_screen.dart';
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

  // ── User location state ──
  String _locationName = 'Detecting…';
  double _userLat = 6.9271;
  double _userLng = 79.8612;
  bool _locationFetched = false;

  // SharedPreferences keys for caching last known location
  static const _keyLat = 'last_lat';
  static const _keyLng = 'last_lng';
  static const _keyLocName = 'last_loc_name';

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
      _initLocation();
    }
  }

  /// Non-blocking location init:
  /// 1. Instantly load cached location from SharedPreferences (or default).
  /// 2. Immediately load complaints so the user sees the feed within ~1s.
  /// 3. In parallel, request GPS; when it arrives, silently refresh.
  Future<void> _initLocation() async {
    // 1. Load cached location instantly
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

    // 2. Immediately load complaints with cached/default location
    _loadComplaints();

    // 3. Fetch real GPS in background (don't block the UI)
    _fetchLiveLocation(prefs);
  }

  /// Background GPS fetch — updates the feed silently when position arrives.
  Future<void> _fetchLiveLocation(SharedPreferences prefs) async {
    try {
      final pos = await LocationService.getCurrentPosition();
      _userLat = pos.latitude;
      _userLng = pos.longitude;
      _locationFetched = true;

      final address =
          await LocationService.reverseGeocode(pos.latitude, pos.longitude);
      final shortAddr = _shortenAddress(address);

      // Persist for next session
      await prefs.setDouble(_keyLat, pos.latitude);
      await prefs.setDouble(_keyLng, pos.longitude);
      await prefs.setString(_keyLocName, shortAddr);

      if (mounted) {
        setState(() => _locationName = shortAddr);
        // Silently reload complaints with the accurate location
        _loadComplaints();
      }
    } on LocationServiceException {
      // Keep using cached / default — no-op
    }
  }

  /// Shorten a long address to just the locality portion for the chip.
  String _shortenAddress(String address) {
    // Take at most the first two parts (e.g. "Galle Road, Colombo")
    final parts = address.split(', ');
    if (parts.length > 2) return parts.sublist(parts.length - 2).join(', ');
    return address;
  }

  /// Opens the map picker to manually change the feed location.
  Future<void> _changeLocation() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLatLng: LatLng(_userLat, _userLng),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _userLat = result.latLng.latitude;
        _userLng = result.latLng.longitude;
        _locationName = _shortenAddress(result.address);
        _locationFetched = true;
      });
      _loadComplaints();
    }
  }

  Future<void> _loadComplaints() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final filter = (_selectedFilter == 'All') ? null : _selectedFilter;

      final complaints = await _repository.getComplaints(
        category: filter,
        userLat: _userLat,
        userLng: _userLng,
      );

      if (!mounted) return;
      setState(() {
        _complaints = complaints;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading complaints: $e');
      if (mounted) setState(() => _isLoading = false);
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
            onTap: _changeLocation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: const BoxConstraints(maxWidth: 180),
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
        ],
      ),
    );
  }

  // ── Reusable blurred + animated dialog (optimized for low-end devices) ──
  Future<T?> _showBlurredDialog<T>(Widget child) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withAlpha(80),
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (ctx, anim, secondaryAnim, dialogChild) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: anim,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
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

  // _showLocationMockupDialog removed — replaced by _changeLocation above.

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
              // Persist toggle to database (handles both add/remove)
              _repository.toggleUpvote(_complaints[index].id);
            },
            onTap: () async {
              final result = await Navigator.push(
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
