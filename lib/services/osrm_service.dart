import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';

class OSRMService {
  // Use the public OSRM demo server (free, no API key)
  static const String baseUrl = 'http://router.project-osrm.org/route/v1/driving/';

  /// Fetch a road-based route between two points.
  /// Returns a list of LatLng points (the path), distance in meters, and duration in seconds.
  static Future<Map<String, dynamic>> getRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
        '$baseUrl${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson'
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
        final route = data['routes'][0];
        final geometry = route['geometry'];
        final distance = route['distance']?.toDouble() ?? 0.0; // meters
        final duration = route['duration']?.toDouble() ?? 0.0; // seconds

        // Extract coordinates from GeoJSON
        final coordinates = geometry['coordinates'] as List;
        final List<LatLng> points = coordinates.map((coord) {
          // GeoJSON format: [longitude, latitude]
          return LatLng(coord[1], coord[0]);
        }).toList();

        return {
          'points': points,
          'distance': distance,
          'duration': duration,
        };
      } else {
        throw Exception('No route found: ${data['code']}');
      }
    } else {
      throw Exception('Failed to fetch route: ${response.statusCode}');
    }
  }

  /// Get route between two points, with fallback to straight line if OSRM fails.
  static Future<List<LatLng>> getRouteWithFallback(LatLng start, LatLng end) async {
    try {
      final result = await getRoute(start, end);
      return result['points'] as List<LatLng>;
    } catch (e) {
      print('OSRM failed: $e, using straight line fallback');
      return [start, end];
    }
  }
}