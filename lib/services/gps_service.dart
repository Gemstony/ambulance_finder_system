import 'package:geolocator/geolocator.dart';

class GpsService {
  // Check and request location permission
  static Future<bool> checkAndRequestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    return true;
  }
  
  // Get current location
  static Future<Position?> getCurrentLocation() async {
    bool hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return null;
    
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }
  
  // Listen to location updates (for drivers)
  static Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );
  }
  
  // Calculate distance between two locations (in meters)
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
  
  // Calculate estimated arrival time (assuming 40 km/h average speed in city)
  static Duration calculateEstimatedTime(double distanceInMeters) {
    double averageSpeedMs = 11.11; // 40 km/h = 11.11 m/s
    int seconds = (distanceInMeters / averageSpeedMs).round();
    return Duration(seconds: seconds);
  }
  
  // Format distance for display
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }
  
  // Format duration for display
  static String formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}min';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} min';
    } else {
      return '< 1 min';
    }
  }
}