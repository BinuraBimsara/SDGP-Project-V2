import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Centralized service for all location-related operations.
///
/// Provides:
///  - Permission checking / requesting.
///  - Fetching the device's current [Position].
///  - Reverse geocoding a coordinate pair to a human-readable [String].
class LocationService {
  LocationService._();

  // ── Permission ─────────────────────────────────────────────────────────────

  /// Ensures the app has location permissions.
  ///
  /// Throws a [LocationServiceException] if the user denies permission or
  /// the device's location services are disabled.
  static Future<void> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException(
        'Location services are disabled. Please enable them in your device settings.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationServiceException(
          'Location permission was denied. Please allow location access to use this feature.',
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        'Location permission is permanently denied. Please enable it in your device settings.',
      );
    }
  }

  // ── Current Position ────────────────────────────────────────────────────────

  /// Returns the device's current [Position].
  ///
  /// Calls [ensurePermission] first. Uses medium accuracy to balance
  /// speed and battery impact.
  static Future<Position> getCurrentPosition() async {
    await ensurePermission();
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  // ── Reverse Geocoding ───────────────────────────────────────────────────────

  /// Reverse geocodes [latitude] / [longitude] to a human-readable address.
  ///
  /// Returns the best available label, progressively less specific:
  ///  1. `street + subLocality + locality`
  ///  2. `locality`
  ///  3. `subAdministrativeArea`
  ///  4. `administrativeArea`
  ///  5. Raw coordinate fallback: "lat, lng"
  static Future<String> reverseGeocode(
      double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return _coordFallback(latitude, longitude);

      final p = placemarks.first;
      final parts = <String>[
        if ((p.thoroughfare ?? '').isNotEmpty) p.thoroughfare!,
        if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
        if ((p.locality ?? '').isNotEmpty)
          p.locality!
        else if ((p.subAdministrativeArea ?? '').isNotEmpty)
          p.subAdministrativeArea!
        else if ((p.administrativeArea ?? '').isNotEmpty)
          p.administrativeArea!,
      ];

      final label = parts.join(', ');
      return label.isNotEmpty ? label : _coordFallback(latitude, longitude);
    } catch (_) {
      return _coordFallback(latitude, longitude);
    }
  }

  static String _coordFallback(double lat, double lng) =>
      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}

// ── Exception ────────────────────────────────────────────────────────────────

class LocationServiceException implements Exception {
  final String message;
  const LocationServiceException(this.message);

  @override
  String toString() => 'LocationServiceException: $message';
}
