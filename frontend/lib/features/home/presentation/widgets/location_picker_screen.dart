import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:spotit/core/services/location_service.dart';

/// Result returned by [LocationPickerScreen].
class LocationPickerResult {
  final LatLng latLng;
  final String address;

  const LocationPickerResult({required this.latLng, required this.address});
}

/// Full-screen map that lets the user drop a pin anywhere on the map.
///
/// If Google Maps fails to load (e.g. missing API key), falls back to
/// a clean address-based location picker using GPS + reverse geocoding.
class LocationPickerScreen extends StatefulWidget {
  final LatLng initialLatLng;

  const LocationPickerScreen({
    super.key,
    this.initialLatLng = const LatLng(6.9271, 79.8612), // Default: Colombo
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen>
    with SingleTickerProviderStateMixin {
  // ── Map ──
  GoogleMapController? _mapController;
  late LatLng _pickedLatLng;
  bool _isMapMoving = false;
  final bool _mapLoadFailed = false;

  // ── Address ──
  String _address = 'Move the map to set location';
  bool _isGeocoding = false;
  Timer? _debounce;

  // ── GPS ──
  bool _isFetchingGps = false;

  // ── Animation (pin bounce) ──
  late AnimationController _pinAnimationController;
  late Animation<double> _pinOffsetAnim;

  // ── Accent ──
  static const _accent = Color(0xFFF9A825);

  @override
  void initState() {
    super.initState();
    _pickedLatLng = widget.initialLatLng;

    _pinAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _pinOffsetAnim = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _pinAnimationController, curve: Curves.easeOut),
    );

    // Initial reverse geocode
    _reverseGeocode(_pickedLatLng);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pinAnimationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Map events ─────────────────────────────────────────────────────────────

  void _onCameraMove(CameraPosition pos) {
    setState(() {
      _pickedLatLng = pos.target;
      _isMapMoving = true;
    });
    _pinAnimationController.forward();
    _debounce?.cancel();
  }

  void _onCameraIdle() {
    setState(() => _isMapMoving = false);
    _pinAnimationController.reverse();
    _reverseGeocode(_pickedLatLng);
  }

  // ── Reverse geocoding ───────────────────────────────────────────────────────

  void _reverseGeocode(LatLng pos) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      setState(() {
        _isGeocoding = true;
        _address = 'Finding address…';
      });
      final addr =
          await LocationService.reverseGeocode(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _address = addr;
        _isGeocoding = false;
      });
    });
  }

  // ── GPS ─────────────────────────────────────────────────────────────────────

  Future<void> _goToMyLocation() async {
    setState(() => _isFetchingGps = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      final myLatLng = LatLng(pos.latitude, pos.longitude);

      if (!_mapLoadFailed) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(myLatLng, 16),
        );
      }

      setState(() => _pickedLatLng = myLatLng);
      _reverseGeocode(myLatLng);
    } on LocationServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isFetchingGps = false);
    }
  }

  // ── Confirm ─────────────────────────────────────────────────────────────────

  void _confirm() {
    Navigator.pop(
      context,
      LocationPickerResult(latLng: _pickedLatLng, address: _address),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5);
    final surface = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final border = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white.withAlpha(130) : Colors.black54;
    final coordColor = isDark ? Colors.white.withAlpha(60) : Colors.black38;

    return Scaffold(
      backgroundColor: bg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(isDark, border),
      body: Stack(
        children: [
          // ── Map or fallback ──
          _mapLoadFailed
              ? _buildFallbackMapArea(bg)
              : _buildGoogleMap(isDark),

          // ── Center Pin (only when map is loaded) ──
          if (!_mapLoadFailed)
            Center(
              child: AnimatedBuilder(
                animation: _pinOffsetAnim,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, _pinOffsetAnim.value - 28),
                  child: _buildPin(),
                ),
              ),
            ),

          // ── Bottom panel ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomPanel(
              surface: surface,
              border: border,
              textColor: textColor,
              subtextColor: subtextColor,
              coordColor: coordColor,
              isDark: isDark,
            ),
          ),

          // ── GPS FAB ──
          Positioned(
            right: 16,
            bottom: 200,
            child: _buildGpsFab(surface, border, isDark),
          ),
        ],
      ),
    );
  }

  // ── Google Map (with theme-aware style) ──────────────────────────────────────

  Widget _buildGoogleMap(bool isDark) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: widget.initialLatLng,
        zoom: 15,
      ),
      onMapCreated: (ctrl) => _mapController = ctrl,
      onCameraMove: _onCameraMove,
      onCameraIdle: _onCameraIdle,
      myLocationButtonEnabled: false,
      myLocationEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      style: isDark ? _darkMapStyle : _lightMapStyle,
    );
  }

  // ── Fallback when map fails ─────────────────────────────────────────────────

  Widget _buildFallbackMapArea(Color bg) {
    return Container(
      color: bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _accent.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.map_rounded, color: _accent, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Map Unavailable',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use the GPS button to set your location',
              style: TextStyle(
                color: Colors.white.withAlpha(120),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(bool isDark, Color border) {
    final pillBg = isDark ? Colors.black.withAlpha(160) : Colors.white.withAlpha(220);
    final pillText = isDark ? Colors.white : Colors.black87;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: _glassButton(
        icon: Icons.arrow_back_ios_new_rounded,
        onTap: () => Navigator.pop(context),
        isDark: isDark,
        border: border,
      ),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: pillBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_searching_rounded, color: _accent, size: 16),
            const SizedBox(width: 8),
            Text(
              'Pick Location',
              style: TextStyle(
                color: pillText,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      centerTitle: true,
    );
  }

  // ── Glass button helper ─────────────────────────────────────────────────────

  Widget _glassButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    required Color border,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withAlpha(160) : Colors.white.withAlpha(220),
            shape: BoxShape.circle,
            border: Border.all(color: border),
          ),
          child: Icon(icon, color: isDark ? Colors.white : Colors.black87, size: 18),
        ),
      ),
    );
  }

  // ── Pin ─────────────────────────────────────────────────────────────────────

  Widget _buildPin() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _accent.withAlpha(_isMapMoving ? 100 : 180),
                blurRadius: _isMapMoving ? 24 : 16,
                spreadRadius: _isMapMoving ? 6 : 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.location_pin,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(height: 2),
        // Pin shadow (squishes when pin lifts)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _isMapMoving ? 28 : 20,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(80),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  // ── GPS FAB ─────────────────────────────────────────────────────────────────

  Widget _buildGpsFab(Color surface, Color border, bool isDark) {
    return GestureDetector(
      onTap: _isFetchingGps ? null : _goToMyLocation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: surface,
          shape: BoxShape.circle,
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 100 : 40),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _isFetchingGps
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                  color: _accent,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.my_location_rounded, color: _accent, size: 22),
      ),
    );
  }

  // ── Bottom panel ─────────────────────────────────────────────────────────────

  Widget _buildBottomPanel({
    required Color surface,
    required Color border,
    required Color textColor,
    required Color subtextColor,
    required Color coordColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 150 : 30),
            blurRadius: 30,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag indicator
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(40) : Colors.black.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // Label
          Text(
            'Selected Location',
            style: TextStyle(
              color: subtextColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),

          // Address row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accent.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on_rounded,
                    color: _accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _isGeocoding
                    ? Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                color: _accent, strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Finding address…',
                            style: TextStyle(
                              color: subtextColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _address,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Coordinates chip
          Text(
            '${_pickedLatLng.latitude.toStringAsFixed(5)}, ${_pickedLatLng.longitude.toStringAsFixed(5)}',
            style: TextStyle(
              color: coordColor,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),

          const SizedBox(height: 20),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: const Text(
                'Confirm Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _isGeocoding ? null : _confirm,
            ),
          ),
        ],
      ),
    );
  }

  // ── Map styles ──────────────────────────────────────────────────────────────

  static const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0d0d0d"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0d0d0d"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1f1f1f"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#303030"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2a2a2a"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#3a3a3a"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#08141a"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#445e75"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#131313"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#0a1c12"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#2d5a27"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#141414"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#2a2a2a"}]},
  {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#f9a825"}]}
]
''';

  static const String _lightMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#f5f5f5"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#e0e0e0"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#e8e8e8"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#d0d0d0"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#c8e6f5"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#6b9dc2"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#c8e6c9"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#4caf50"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#e5e5e5"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#c0c0c0"}]},
  {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#f9a825"}]}
]
''';
}

