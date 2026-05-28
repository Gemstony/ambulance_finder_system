import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/gps_service.dart';
import 'package:geocoding/geocoding.dart';

class LocationProvider extends ChangeNotifier {
  // State variables
  Position? _currentLocation;
  Position? _driverLocation; // For patient tracking driver
  bool _isLoading = false;
  bool _isTracking = false;
  String? _errorMessage;
  String? _currentAddress;

  // Location stream subscription
  Stream<Position>? _locationStream;
  StreamSubscription<Position>? _locationSubscription;
  DateTime _lastAddressUpdate = DateTime(2000);
  static const _addressUpdateInterval = Duration(seconds: 30);

  // Getters
  Position? get currentLocation => _currentLocation;
  Position? get driverLocation => _driverLocation;
  bool get isLoading => _isLoading;
  bool get isTracking => _isTracking;
  String? get errorMessage => _errorMessage;
  String get currentAddress => _currentAddress ?? 'Getting address...';

  String get formattedCurrentLocation {
    if (_currentLocation == null) return 'Location unknown';
    return '${_currentLocation!.latitude.toStringAsFixed(6)}, ${_currentLocation!.longitude.toStringAsFixed(6)}';
  }

  String get formattedDriverLocation {
    if (_driverLocation == null) return 'Driver location unknown';
    return '${_driverLocation!.latitude.toStringAsFixed(6)}, ${_driverLocation!.longitude.toStringAsFixed(6)}';
  }

  // ============================================================
  // GET CURRENT LOCATION (ONE TIME)
  // ============================================================
  Future<bool> getCurrentLocation() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final location = await GpsService.getCurrentLocation();
      if (location != null) {
        _currentLocation = location;
        await _updateAddress(); // fetch address
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Could not get current location. Please check GPS.';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error getting location: ${e.toString()}';
      _setLoading(false);
      return false;
    }
  }

  // ============================================================
  // START REAL-TIME LOCATION TRACKING (FOR DRIVERS)
  // ============================================================
  Future<bool> startTracking({Function(Position)? onLocationUpdate}) async {
    _isTracking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final hasPermission = await GpsService.checkAndRequestPermission();
      if (!hasPermission) {
        _errorMessage = 'Location permission denied';
        _isTracking = false;
        notifyListeners();
        return false;
      }

      await getCurrentLocation();

      _locationStream = GpsService.getLocationStream();
      _locationSubscription = _locationStream?.listen((position) async {
        _currentLocation = position;
        // Throttle address updates
        if (DateTime.now().difference(_lastAddressUpdate) >
            _addressUpdateInterval) {
          await _updateAddress();
        }
        if (onLocationUpdate != null) onLocationUpdate(position);
        notifyListeners();
      });
      return true;
    } catch (e) {
      _errorMessage = 'Failed to start tracking: ${e.toString()}';
      _isTracking = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================================
  // STOP REAL-TIME TRACKING
  // ============================================================
  void stopTracking() {
    _locationSubscription?.cancel();
    _isTracking = false;
    notifyListeners();
  }

  // ============================================================
  // UPDATE DRIVER LOCATION (FOR PATIENT TRACKING)
  // ============================================================
  Future<void> _updateAddress() async {
    if (_currentLocation == null) return;

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        List<String> addressParts = [];

        void addIfValid(String? value) {
          if (value == null || value.trim().isEmpty) return;

          String cleaned = value.trim();

          // Skip plus codes or numeric-heavy values
          bool looksInvalid =
              cleaned.contains('+') || RegExp(r'^\d+$').hasMatch(cleaned);

          if (!looksInvalid) {
            addressParts.add(cleaned);
          }
        }

        addIfValid(p.name);
        addIfValid(p.street);
        addIfValid(p.subLocality);
        addIfValid(p.locality);
        addIfValid(p.subAdministrativeArea);
        addIfValid(p.administrativeArea);
        addIfValid(p.country);

        // Remove duplicates
        addressParts = addressParts.toSet().toList();

        _currentAddress = addressParts.join(', ');

        if (_currentAddress!.isEmpty) {
          _currentAddress = 'Location found';
        }
      } else {
        _currentAddress = 'Address not found';
      }
    } catch (e) {
      debugPrint('Address error: $e');
      _currentAddress = 'Unable to get address';
    }

    _lastAddressUpdate = DateTime.now();
    notifyListeners();
  }

  // ============================================================
  // CALCULATE DISTANCE TO A LOCATION
  // ============================================================
  double getDistanceTo(double targetLat, double targetLon) {
    if (_currentLocation == null) return 0.0;

    return GpsService.calculateDistance(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      targetLat,
      targetLon,
    );
  }

  // ============================================================
  // GET FORMATTED DISTANCE TO A LOCATION
  // ============================================================
  String getFormattedDistanceTo(double targetLat, double targetLon) {
    final distance = getDistanceTo(targetLat, targetLon);
    return GpsService.formatDistance(distance);
  }

  // ============================================================
  // GET ESTIMATED TIME TO A LOCATION
  // ============================================================
  Duration getEstimatedTimeTo(double targetLat, double targetLon) {
    final distance = getDistanceTo(targetLat, targetLon);
    return GpsService.calculateEstimatedTime(distance);
  }

  // ============================================================
  // GET FORMATTED ESTIMATED TIME
  // ============================================================
  String getFormattedEstimatedTimeTo(double targetLat, double targetLon) {
    final duration = getEstimatedTimeTo(targetLat, targetLon);
    return GpsService.formatDuration(duration);
  }

  // ============================================================
  // CALCULATE DISTANCE BETWEEN TWO LOCATIONS
  // ============================================================
  double calculateDistanceBetween({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    return GpsService.calculateDistance(lat1, lon1, lat2, lon2);
  }

  // ============================================================
  // CHECK IF LOCATION IS AVAILABLE
  // ============================================================
  bool get hasLocation => _currentLocation != null;

  // ============================================================
  // CHECK IF DRIVER LOCATION IS AVAILABLE
  // ============================================================
  bool get hasDriverLocation => _driverLocation != null;

  // ============================================================
  // CHECK IF PATIENT IS NEAR AMBULANCE (WITHIN 50 METERS)
  // ============================================================
  bool isAmbulanceNearby(
    double ambulanceLat,
    double ambulanceLon, {
    double thresholdMeters = 50,
  }) {
    if (_currentLocation == null) return false;

    final distance = calculateDistanceBetween(
      lat1: _currentLocation!.latitude,
      lon1: _currentLocation!.longitude,
      lat2: ambulanceLat,
      lon2: ambulanceLon,
    );

    return distance <= thresholdMeters;
  }

  // ============================================================
  // CLEAR DRIVER LOCATION
  // ============================================================
  void clearDriverLocation() {
    _driverLocation = null;
    notifyListeners();
  }

  // ============================================================
  // CLEAR ERROR
  // ============================================================
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ============================================================
  // RESET ALL STATE
  // ============================================================
  void resetState() {
    stopTracking();
    _currentLocation = null;
    _driverLocation = null;
    _currentAddress = null;
    _isLoading = false;
    _isTracking = false;
    _errorMessage = null;
    notifyListeners();
  }

  // ============================================================
  // PRIVATE HELPER METHODS
  // ============================================================
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // ============================================================
  // DISPOSE (Clean up streams)
  // ============================================================
  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }
}
