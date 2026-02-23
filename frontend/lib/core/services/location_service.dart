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
