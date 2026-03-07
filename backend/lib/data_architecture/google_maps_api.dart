import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

/// Uses Google Maps Distance Matrix API to calculate road-distances.
/// Falls back to Haversine straight-line distance if the API key is missing or invalid.
class GoogleMapsMockAPI {
  // Geocoding / Distance Matrix API key.
  // Pass at build-time:  flutter run --dart-define=MAPS_API_KEY=<key>
  // Falls back to empty string when not provided.
  static const String _apiKey =
      String.fromEnvironment('MAPS_API_KEY', defaultValue: '');

  /// Calculates the Haversine distance between two coordinates in kilometers.
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }

  /// Takes a user's location and a raw list of complaint JSON dictionaries,
  /// queries Google Maps Distance Matrix API for exact travel distances,
  /// and returns the list sorted from closest to farthest.
  ///
  /// This simulates a robust backend query relying on accurate map data!
  static Future<List<Map<String, dynamic>>> fetchNearbyComplaints({
    required double userLat,
    required double userLng,
    required List<Map<String, dynamic>> rawComplaints,
    String? category,
  }) async {
    List<Map<String, dynamic>> filtered = List.from(rawComplaints);

    // Apply category filter if provided
    if (category != null && category != 'All') {
      filtered = filtered
          .where(
            (c) =>
                (c['category'] as String).toLowerCase() ==
                category.toLowerCase(),
          )
          .toList();
    }

    if (filtered.isEmpty) return filtered;

    if (_apiKey.isEmpty) {
      print(
          'WARNING: Real Google Maps API Key not set. Falling back to computational Haversine distance.');
      _applyHaversine(userLat, userLng, filtered);
    } else {
      // 1. Prepare destinations string: lat,lng|lat,lng...
      final destinations = filtered
          .where((c) => c['latitude'] != null && c['longitude'] != null)
          .map((c) => '${c['latitude']},${c['longitude']}')
          .join('|');

      if (destinations.isEmpty) return filtered;

      // 2. Query Google Maps API
      final url =
          Uri.parse('https://maps.googleapis.com/maps/api/distancematrix/json'
              '?origins=$userLat,$userLng'
              '&destinations=$destinations'
              '&key=$_apiKey');

      try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK') {
            final elements = data['rows'][0]['elements'] as List;
            int elementIndex = 0;

            for (var complaint in filtered) {
              if (complaint['latitude'] != null &&
                  complaint['longitude'] != null) {
                final element = elements[elementIndex];
                if (element['status'] == 'OK') {
                  // distance in meters
                  final meters = element['distance']['value'] as int;
                  complaint['distanceInMeters'] = meters.toDouble();
                } else {
                  // fallback to haversine if specific destination fails routing bounds
                  complaint['distanceInMeters'] = _calculateDistance(
                          userLat,
                          userLng,
                          complaint['latitude'],
                          complaint['longitude']) *
                      1000;
                }
                elementIndex++;
              }
            }
          } else {
            print('Google Maps API Error: ${data['status']}');
            _applyHaversine(userLat, userLng, filtered);
          }
        } else {
          _applyHaversine(userLat, userLng, filtered);
        }
      } catch (e) {
        print('HTTP Request Error: $e');
        _applyHaversine(userLat, userLng, filtered);
      }
    }

    // Sort by exact calculated distance (closest first)
    filtered.sort((a, b) {
      final distA = a['distanceInMeters'] as double? ?? double.maxFinite;
      final distB = b['distanceInMeters'] as double? ?? double.maxFinite;
      return distA.compareTo(distB);
    });

    return filtered;
  }

  static void _applyHaversine(
      double userLat, double userLng, List<Map<String, dynamic>> filtered) {
    for (var complaint in filtered) {
      if (complaint['latitude'] != null && complaint['longitude'] != null) {
        complaint['distanceInMeters'] = _calculateDistance(
              userLat,
              userLng,
              complaint['latitude'] as double,
              complaint['longitude'] as double,
            ) *
            1000;
      }
    }
  }
}
