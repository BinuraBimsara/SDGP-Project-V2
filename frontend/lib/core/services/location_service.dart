import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// LocationService handles everything related to the device's GPS.
// It's a static utility class (private constructor, all static methods)
// so you never need to create an instance — just call LocationService.method().
//
// It handles three things:
//   1. Checking and requesting GPS permissions
//   2. Getting the device's current GPS coordinates
//   3. Converting coordinates to a readable address (reverse geocoding)
class LocationService {
  LocationService._(); // private constructor — prevents instantiation

  // ── Step 1: Permission ──────────────────────────────────────────────────────

  // Checks whether the app has permission to use location, and requests it
  // if needed. Throws a LocationServiceException with a clear message if:
  //   - The device has location services turned off in settings
  //   - The user denies permission when the dialog appears
  //   - The user has permanently denied permission (must go to app settings)
  static Future<void> ensurePermission() async {
    // First check if the device's location service is enabled at all
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException(
        'Location services are disabled. Please enable them in your device settings.',
      );
    }

    // Check the current permission status
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // Show the system permission dialog to the user
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // User pressed "Deny" — can't use location
        throw const LocationServiceException(
          'Location permission was denied. Please allow location access to use this feature.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // User previously checked "Never ask again" — must go to phone settings manually
      throw const LocationServiceException(
        'Location permission is permanently denied. Please enable it in your device settings.',
      );
    }
  }

  // ── Step 2: Current Position ────────────────────────────────────────────────

  // Returns the device's current GPS position (latitude + longitude).
  // Calls ensurePermission() first so callers don't need to check themselves.
  // Uses medium accuracy to get a fast fix without draining the battery.
  static Future<Position> getCurrentPosition() async {
    await ensurePermission(); // always check permission before using GPS
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium, // good balance of speed and battery
        timeLimit: Duration(seconds: 15),  // fail if no fix in 15 seconds
      ),
    );
  }

  // ── Step 3: Reverse Geocoding ───────────────────────────────────────────────

  // Converts GPS coordinates into a human-readable address string.
  // The result is as specific as possible — falling back to progressively less
  // specific labels if parts of the address are missing:
  //   1. "Main Street, Colombo 3, Colombo" (most specific)
  //   2. "Colombo"
  //   3. "Western"
  //   4. "6.93456, 79.84567" (raw coordinates as last resort)
  static Future<String> reverseGeocode(
      double latitude, double longitude) async {
    try {
      // The geocoding package calls Google's reverse geocoding API
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return _coordFallback(latitude, longitude);

      final p = placemarks.first; // use the top-ranked result

      // Build a comma-separated address from the most useful parts
      final parts = <String>[
        if ((p.thoroughfare ?? '').isNotEmpty) p.thoroughfare!,      // street name
        if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,         // neighbourhood
        if ((p.locality ?? '').isNotEmpty)
          p.locality!                                                  // city
        else if ((p.subAdministrativeArea ?? '').isNotEmpty)
          p.subAdministrativeArea!                                     // district
        else if ((p.administrativeArea ?? '').isNotEmpty)
          p.administrativeArea!,                                       // province
      ];

      final label = parts.join(', ');
      return label.isNotEmpty ? label : _coordFallback(latitude, longitude);
    } catch (_) {
      // If the API call fails for any reason, fall back to raw coordinates
      return _coordFallback(latitude, longitude);
    }
  }

  // Returns a formatted coordinate string like "6.92710, 79.86120"
  // Used as a fallback when no address can be determined
  static String _coordFallback(double lat, double lng) =>
      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}

// ── Custom exception ────────────────────────────────────────────────────────
// A specific exception type for location errors so callers can catch it
// separately from other exceptions and show appropriate messages.
class LocationServiceException implements Exception {
  final String message;
  const LocationServiceException(this.message);

  @override
  String toString() => 'LocationServiceException: $message';
}
