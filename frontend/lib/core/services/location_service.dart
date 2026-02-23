<<<<<<< HEAD
import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }
}
=======
// location_service.dart
//
// NOTE: The real implementation uses the `geolocator` package.
// It is intentionally stubbed here for GUI testing mode — the package is
// excluded from pubspec.yaml until backend integration begins.
//
// When ready, add `geolocator: ^12.0.0` to pubspec.yaml and restore the
// implementation below.

/// Stub location service — returns a dummy position for GUI testing.
class LocationService {
  /// Returns a [StubPosition] representing a default location (Colombo, LK).
  Future<StubPosition> determinePosition() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const StubPosition(latitude: 6.9271, longitude: 79.8612);
  }
}

/// Lightweight position placeholder used while geolocator is excluded.
class StubPosition {
  final double latitude;
  final double longitude;
  const StubPosition({required this.latitude, required this.longitude});
}
>>>>>>> a2273dd3a72b26e61d482033ab992eee3b7afd05
