import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/location_provider.dart';
import '../../utils/colors.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controller = Completer();
  
  LatLng? _patientLocation;
  LatLng? _driverLocation;
  String? _driverId;
  String? _requestId;
  String _requestStatus = 'pending';
  String _driverName = 'Assigning driver...';
  String _driverPhone = '';
  
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  
  StreamSubscription? _driverLocationSubscription;
  StreamSubscription? _requestSubscription;

  @override
  void initState() {
    super.initState();
    _loadPatientLocation();
    _getActiveRequest();
  }

  Future<void> _loadPatientLocation() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    await locationProvider.getCurrentLocation();
    final loc = locationProvider.currentLocation;
    if (loc != null) {
      setState(() {
        _patientLocation = LatLng(loc.latitude, loc.longitude);
        _updatePatientMarker();
      });
      
      // Move camera to patient location
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_patientLocation!, 14),
        );
      }
    }
  }

  Future<void> _getActiveRequest() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    _requestSubscription = FirebaseFirestore.instance
        .collection('requests')
        .where('patientId', isEqualTo: userId)
        .where('status', whereIn: ['pending', 'accepted', 'enroute', 'arrived', 'patient_loaded'])
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        
        setState(() {
          _requestId = doc.id;
          _requestStatus = data['status'] ?? 'pending';
          _driverId = data['driverId'];
          _driverName = data['driverName'] ?? 'Assigning driver...';
          _driverPhone = data['driverPhone'] ?? '';
        });
        
        if (_driverId != null && _driverId!.isNotEmpty) {
          _listenToDriverLocation(_driverId!);
        }
        
        _updateStatusMarker();
      } else {
        // No active request
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active ambulance request')),
        );
        Navigator.pop(context);
      }
    });
  }

  void _listenToDriverLocation(String driverId) {
    _driverLocationSubscription = FirebaseFirestore.instance
        .collection('drivers_location')
        .doc(driverId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        final location = data['location'] as GeoPoint?;
        
        if (location != null) {
          setState(() {
            _driverLocation = LatLng(location.latitude, location.longitude);
            _updateDriverMarker();
            _drawRoute();
          });
          
          // Auto zoom to show both locations if map is initialized
          if (_mapController != null && _patientLocation != null && _driverLocation != null) {
            _zoomToFitBothLocations();
          }
        }
      }
    });
  }

  void _updatePatientMarker() {
    if (_patientLocation == null) return;
    
    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == 'patient');
      _markers.add(
        Marker(
          markerId: const MarkerId('patient'),
          position: _patientLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Your Location', snippet: 'Patient'),
        ),
      );
    });
  }

  void _updateDriverMarker() {
    if (_driverLocation == null) return;
    
    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == 'driver');
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: _driverName, snippet: 'Ambulance'),
        ),
      );
    });
  }

  void _updateStatusMarker() {
    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == 'status');
      // Status is shown in the card, not as marker
    });
  }

  void _drawRoute() async {
    if (_patientLocation == null || _driverLocation == null) return;
    
    // In production, use Google Maps Directions API
    // For now, we'll draw a simple straight line
    
    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [_driverLocation!, _patientLocation!],
          color: AppColors.primaryGreen,
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    });
  }

  void _zoomToFitBothLocations() {
    if (_patientLocation == null || _driverLocation == null) return;
    
    double minLat = _patientLocation!.latitude < _driverLocation!.latitude 
        ? _patientLocation!.latitude 
        : _driverLocation!.latitude;
    double maxLat = _patientLocation!.latitude > _driverLocation!.latitude 
        ? _patientLocation!.latitude 
        : _driverLocation!.latitude;
    double minLng = _patientLocation!.longitude < _driverLocation!.longitude 
        ? _patientLocation!.longitude 
        : _driverLocation!.longitude;
    double maxLng = _patientLocation!.longitude > _driverLocation!.longitude 
        ? _patientLocation!.longitude 
        : _driverLocation!.longitude;
    
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

  double _calculateDistance() {
    if (_patientLocation == null || _driverLocation == null) return 0;
    
    const double earthRadius = 6371; // km
    
    double lat1 = _patientLocation!.latitude;
    double lon1 = _patientLocation!.longitude;
    double lat2 = _driverLocation!.latitude;
    double lon2 = _driverLocation!.longitude;
    
    double dLat = (lat2 - lat1) * (3.14159 / 180);
    double dLon = (lon2 - lon1) * (3.14159 / 180);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (3.14159 / 180)) * cos(lat2 * (3.14159 / 180)) *
        sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  String _formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  String _formatEta(double km) {
    // Assume average speed 40 km/h in city
    double hours = km / 40;
    int minutes = (hours * 60).round();
    if (minutes < 1) return 'Less than a minute';
    if (minutes < 60) return '$minutes min';
    return '${(minutes / 60).floor()}h ${minutes % 60}min';
  }

  @override
  void dispose() {
    _driverLocationSubscription?.cancel();
    _requestSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final distance = _calculateDistance();
    final eta = _formatEta(distance);
    final distanceText = _formatDistance(distance);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Ambulance'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: _driverPhone.isNotEmpty
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Calling driver at $_driverPhone...')),
                    );
                  }
                : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          if (_patientLocation != null)
            GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
                _controller.complete(controller);
              },
              initialCameraPosition: CameraPosition(
                target: _patientLocation!,
                zoom: 14,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              compassEnabled: true,
            )
          else
            const Center(child: CircularProgressIndicator()),
          
          // Bottom Info Card
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
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Timeline
                  Row(
                    children: [
                      _buildStatusStep(Icons.check_circle, 'Requested', _requestStatus != 'pending'),
                      Expanded(child: Container(height: 2, color: _requestStatus != 'pending' ? Colors.green : Colors.grey)),
                      _buildStatusStep(Icons.check_circle, 'Accepted', _requestStatus == 'accepted' || _requestStatus == 'enroute' || _requestStatus == 'arrived'),
                      Expanded(child: Container(height: 2, color: _requestStatus == 'enroute' || _requestStatus == 'arrived' ? Colors.green : Colors.grey)),
                      _buildStatusStep(Icons.directions_car, 'En Route', _requestStatus == 'enroute' || _requestStatus == 'arrived'),
                      Expanded(child: Container(height: 2, color: _requestStatus == 'arrived' ? Colors.green : Colors.grey)),
                      _buildStatusStep(Icons.location_on, 'Arrived', _requestStatus == 'arrived'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Driver Info
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.veryLightGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.local_hospital, color: AppColors.primaryGreen, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _driverName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Vehicle: Ambulance Unit',
                              style: TextStyle(fontSize: 12, color: AppColors.grey),
                            ),
                          ],
                        ),
                      ),
                      if (_driverLocation != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              distanceText,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                            ),
                            Text(
                              'ETA: $eta',
                              style: TextStyle(fontSize: 12, color: AppColors.primaryGreen),
                            ),
                          ],
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Status Message
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _requestStatus == 'arrived'
                          ? Colors.green.shade50
                          : _requestStatus == 'enroute'
                              ? Colors.orange.shade50
                              : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _requestStatus == 'arrived'
                              ? Icons.check_circle
                              : _requestStatus == 'enroute'
                                  ? Icons.directions_car
                                  : Icons.access_time,
                          color: _requestStatus == 'arrived'
                              ? Colors.green
                              : _requestStatus == 'enroute'
                                  ? Colors.orange
                                  : Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _requestStatus == 'arrived'
                                ? 'Ambulance has arrived at your location!'
                                : _requestStatus == 'enroute'
                                    ? 'Ambulance is on the way. Please stay at your location.'
                                    : _requestStatus == 'accepted'
                                        ? 'Driver has accepted your request and is preparing to depart.'
                                        : 'Waiting for a driver to accept your request...',
                            style: TextStyle(
                              color: _requestStatus == 'arrived'
                                  ? Colors.green
                                  : _requestStatus == 'enroute'
                                      ? Colors.orange
                                      : Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Action Button
                  if (_requestStatus == 'arrived')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Mark as loaded or complete
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ambulance has arrived! Please board.')),
                          );
                        },
                        icon: const Icon(Icons.people),
                        label: const Text('Ambulance Has Arrived'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Center Button to Fit View
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: () {
                if (_patientLocation != null && _driverLocation != null) {
                  _zoomToFitBothLocations();
                } else if (_patientLocation != null) {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(_patientLocation!, 14),
                  );
                }
              },
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryGreen,
              child: const Icon(Icons.fit_screen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStep(IconData icon, String label, bool isCompleted) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isCompleted ? AppColors.primaryGreen : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: isCompleted ? AppColors.primaryGreen : Colors.grey,
            fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}