// placeholder for map_service.dart
// lib/services/map_service.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapService {
  // Calculates a route between two points. For a real-world project, you would
  // integrate an engine like OSRM here to get actual road-based routes.
  static Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    // This is a placeholder that draws a straight line.
    // In a later step, you will replace this with a call to a real routing engine.
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
    return [start, end];
  }

  // Helper method to format distance for UI display (e.g., "1.2 km")
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} meters';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  // Calculates a simple straight-line distance using the Haversine formula.
  static double calculateDistance(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000; // Radius of the earth in meters
    double lat1Rad = p1.latitude * pi / 180;
    double lat2Rad = p2.latitude * pi / 180;
    double deltaLat = (p2.latitude - p1.latitude) * pi / 180;
    double deltaLng = (p2.longitude - p1.longitude) * pi / 180;

    double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
            sin(deltaLng / 2) * sin(deltaLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;

    return distance;
  }
}