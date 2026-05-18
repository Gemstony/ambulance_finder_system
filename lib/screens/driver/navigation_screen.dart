import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/gps_service.dart';
import '../../utils/colors.dart';

class NavigationScreen extends StatefulWidget {
  final String requestId;
  final String patientName;
  final double patientLat;
  final double patientLng;
  final String patientPhone;

  const NavigationScreen({
    super.key,
    required this.requestId,
    required this.patientName,
    required this.patientLat,
    required this.patientLng,
    required this.patientPhone,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _currentStatus = 'accepted';
  bool _isLoading = false;
  double _currentDistance = 0;
  Duration _currentEta = Duration.zero;
  LatLng? _currentLocation;
  
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
    _updateRequestStatus('enroute');
    _setupMarkers();
  }

  void _setupMarkers() {
    // Patient marker
    _markers.add(
      Marker(
        markerId: const MarkerId('patient'),
        position: LatLng(widget.patientLat, widget.patientLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: widget.patientName, snippet: 'Patient Location'),
      ),
    );
  }

  void _updateDriverMarker(LatLng position) {
    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == 'driver');
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'You', snippet: 'Current Location'),
        ),
      );
    });
  }

  void _drawRoute(LatLng currentPos) {
    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [currentPos, LatLng(widget.patientLat, widget.patientLng)],
          color: AppColors.primaryGreen,
          width: 4,
        ),
      );
    });
  }

  Future<void> _startLocationUpdates() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    await locationProvider.startTracking(
      onLocationUpdate: (position) async {
        final currentPos = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentLocation = currentPos;
          _currentDistance = GpsService.calculateDistance(
            position.latitude,
            position.longitude,
            widget.patientLat,
            widget.patientLng,
          );
          _currentEta = GpsService.calculateEstimatedTime(_currentDistance);
        });
        
        _updateDriverMarker(currentPos);
        _drawRoute(currentPos);
        
        // Auto zoom to fit if map is initialized
        if (_mapController != null) {
          _zoomToFit(currentPos, LatLng(widget.patientLat, widget.patientLng));
        }
        
        // Update location in Firestore
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final user = authProvider.currentUser;
        if (user != null) {
          await _firestoreService.updateDriverLocation(
            user.uid,
            position.latitude,
            position.longitude,
            _currentStatus,
          );
        }
      },
    );
  }

  void _zoomToFit(LatLng driver, LatLng patient) {
    double minLat = driver.latitude < patient.latitude ? driver.latitude : patient.latitude;
    double maxLat = driver.latitude > patient.latitude ? driver.latitude : patient.latitude;
    double minLng = driver.longitude < patient.longitude ? driver.longitude : patient.longitude;
    double maxLng = driver.longitude > patient.longitude ? driver.longitude : patient.longitude;
    
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.01, minLng - 0.01),
          northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
        ),
        50,
      ),
    );
  }

  Future<void> _updateRequestStatus(String status) async {
    setState(() => _currentStatus = status);
    await _firestoreService.updateRequestStatus(widget.requestId, status);
  }

  Future<void> _markAsArrived() async {
    setState(() => _isLoading = true);
    await _updateRequestStatus('arrived');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Arrived at Location!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('You have arrived at the patient\'s location.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _markAsLoaded();
            },
            child: const Text('Load Patient'),
          ),
        ],
      ),
    );
    
    setState(() => _isLoading = false);
  }

  Future<void> _markAsLoaded() async {
    setState(() => _isLoading = true);
    await _updateRequestStatus('patient_loaded');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Patient loaded. Proceed to hospital.'),
        backgroundColor: Colors.green,
      ),
    );
    
    setState(() => _isLoading = false);
  }

  Future<void> _completeTrip() async {
    setState(() => _isLoading = true);
    await _updateRequestStatus('completed');
    
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/driver-home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Navigate to ${widget.patientName}'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Calling ${widget.patientPhone}...')),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          if (_currentLocation != null)
            GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
                _zoomToFit(_currentLocation!, LatLng(widget.patientLat, widget.patientLng));
              },
              initialCameraPosition: CameraPosition(
                target: _currentLocation!,
                zoom: 14,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            )
          else
            const Center(child: CircularProgressIndicator()),
          
          // Bottom Card
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient Info
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.veryLightGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person, color: AppColors.primaryGreen),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.patientName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              widget.patientPhone,
                              style: TextStyle(fontSize: 12, color: AppColors.grey),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            GpsService.formatDistance(_currentDistance),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                          ),
                          Text(
                            'ETA: ${GpsService.formatDuration(_currentEta)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.primaryGreen),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : _currentStatus == 'arrived'
                              ? _markAsLoaded
                              : _currentStatus == 'patient_loaded'
                                  ? _completeTrip
                                  : _markAsArrived,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _currentStatus == 'arrived'
                                  ? '✅ PATIENT LOADED'
                                  : _currentStatus == 'patient_loaded'
                                      ? '🏥 COMPLETE TRIP'
                                      : '📍 MARK AS ARRIVED',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}