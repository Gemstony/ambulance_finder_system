import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/request_provider.dart';
import '../../utils/colors.dart';
import '../../services/osrm_service.dart';
import '../../services/gps_service.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  late MapController _mapController;
  LatLng? _patientLocation;
  LatLng? _driverLocation;
  String? _driverId, _requestId;
  String _requestStatus = 'pending';
  String _driverName = 'Assigning driver...';
  String _driverPhone = '';

  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  StreamSubscription? _driverLocationSubscription;
  StreamSubscription? _requestSubscription;

  // Driver location status and distance
  bool _hasDriverLocation = false;
  double _currentDistanceMeters = 0.0;
  Duration _currentEta = Duration.zero;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getActiveRequest();
  }

  void _updateMarkers() {
    if (_patientLocation == null) return;
    final markers = <Marker>[
      Marker(
        point: _patientLocation!,
        width: 80,
        height: 80,
        child: const Icon(Icons.person, color: Colors.red, size: 40),
      ),
    ];
    if (_driverLocation != null) {
      markers.add(
        Marker(
          point: _driverLocation!,
          width: 80,
          height: 80,
          child: const Icon(Icons.local_hospital, color: Colors.blue, size: 40),
        ),
      );
    }
    setState(() {
      _markers = markers;
    });
  }

  // Draw route using OSRM, fallback to straight line
  void _drawRoute() async {
    if (_patientLocation == null || _driverLocation == null) return;
    try {
      final route = await OSRMService.getRoute(
        _driverLocation!,
        _patientLocation!,
      );
      final routePoints = route['points'] as List<LatLng>;
      final distance = route['distance'] as double;
      final duration = route['duration'] as double;
      setState(() {
        _currentDistanceMeters = distance;
        _currentEta = Duration(seconds: duration.toInt());
        _polylines = [
          Polyline(
            points: routePoints,
            strokeWidth: 4,
            color: AppColors.primaryGreen,
          ),
        ];
      });
    } catch (e) {
      // Fallback to straight line and use GPS distance
      final distanceMeters = GpsService.calculateDistance(
        _driverLocation!.latitude,
        _driverLocation!.longitude,
        _patientLocation!.latitude,
        _patientLocation!.longitude,
      );
      setState(() {
        _currentDistanceMeters = distanceMeters;
        _currentEta = GpsService.calculateEstimatedTime(distanceMeters);
        _polylines = [
          Polyline(
            points: [_driverLocation!, _patientLocation!],
            strokeWidth: 4,
            color: AppColors.primaryGreen,
          ),
        ];
      });
    }
  }

  void _zoomToFitBoth() {
    if (_patientLocation == null || _driverLocation == null) return;
    final midLat = (_patientLocation!.latitude + _driverLocation!.latitude) / 2;
    final midLng =
        (_patientLocation!.longitude + _driverLocation!.longitude) / 2;
    final latSpan = (_patientLocation!.latitude - _driverLocation!.latitude)
        .abs();
    final lngSpan = (_patientLocation!.longitude - _driverLocation!.longitude)
        .abs();
    final maxSpan = latSpan > lngSpan ? latSpan : lngSpan;
    double zoom = 14;
    if (maxSpan > 0.2) {
      zoom = 10;
    } else if (maxSpan > 0.1)
      zoom = 11.5;
    else if (maxSpan > 0.05)
      zoom = 13;
    _mapController.move(LatLng(midLat, midLng), zoom);
  }

  Future<void> _getActiveRequest() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _requestSubscription = FirebaseFirestore.instance
        .collection('requests')
        .where('patientId', isEqualTo: userId)
        .where('status', whereIn: ['pending', 'accepted', 'enroute', 'arrived'])
        .orderBy('timestamp', descending: true)
        .limit(1)
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

              final geo = data['patientLocation'];
              if (geo != null) {
                if (geo is GeoPoint) {
                  _patientLocation = LatLng(geo.latitude, geo.longitude);
                } else if (geo is Map) {
                  _patientLocation = LatLng(geo['latitude'], geo['longitude']);
                }
                _updateMarkers();
              }
            });
            if (_driverId != null && _driverId!.isNotEmpty) {
              _listenToDriverLocation(_driverId!);
            }
            if (_patientLocation != null) {
              _mapController.move(_patientLocation!, 14);
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No active ambulance request')),
              );
              Navigator.pop(context);
            }
          }
        });
  }

  void _listenToDriverLocation(String driverId) {
    _driverLocationSubscription = FirebaseFirestore.instance
        .collection('drivers_location')
        .doc(driverId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            final location = data['location'] as GeoPoint?;
            if (location != null) {
              setState(() {
                _driverLocation = LatLng(location.latitude, location.longitude);
                _hasDriverLocation = true;
              });
              _updateMarkers();
              _drawRoute(); // updates distance and ETA
              if (_patientLocation != null && _driverLocation != null) {
                _zoomToFitBoth();
              }
            }
          }
        });
  }

  @override
  void dispose() {
    _driverLocationSubscription?.cancel();
    _requestSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Format distance and ETA exactly like driver screen
    String distanceText;
    String etaText;

    if (!_hasDriverLocation) {
      distanceText = _requestStatus == 'pending' ? 'Waiting...' : 'N/A';
      etaText = _requestStatus == 'pending' ? 'Waiting...' : 'N/A';
    } else {
      // Use same formatting as driver: meters if < 1000, else km
      if (_currentDistanceMeters < 1000) {
        distanceText = '${_currentDistanceMeters.toStringAsFixed(0)} m';
      } else {
        distanceText =
            '${(_currentDistanceMeters / 1000).toStringAsFixed(1)} km';
      }
      final minutes = _currentEta.inMinutes;
      etaText = minutes > 0 ? '$minutes min' : '0 min';
    }

    if (_patientLocation == null && _requestStatus == 'pending') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Track Ambulance'),
          backgroundColor: AppColors.primaryGreen,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.grey),
              SizedBox(height: 16),
              Text('No active ambulance request'),
              SizedBox(height: 8),
              Text('Please request an ambulance first'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Ambulance'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: Stack(
        children: [
          // Map always shown – centered on patient location
          if (_patientLocation != null)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _patientLocation!,
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ambulance_finder.app',
                ),
                MarkerLayer(markers: _markers),
                PolylineLayer(polylines: _polylines),
                const Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ),
              ],
            )
          else
            const Center(child: CircularProgressIndicator()),

          // Bottom card
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_hospital, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Driver: $_driverName',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status: $_requestStatus',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Distance: $distanceText'),
                        Text(':'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_driverPhone.isNotEmpty)
                      Text(
                        'Driver Phone: $_driverPhone',
                        style: const TextStyle(color: Colors.black54),
                      ),

                    if (_requestStatus == 'arrived')
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final provider = Provider.of<RequestProvider>(
                              context,
                              listen: false,
                            );
                            bool success = await provider.confirmArrival(
                              _requestId!,
                            );
                            if (success && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Colors.green,
                                  content: Text(
                                    'Arrival confirmed. Thank you!',
                                  ),
                                ),
                              );
                              Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Confirm Ambulance Arrival'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Zoom to fit button
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _zoomToFitBoth,
              child: const Icon(Icons.fit_screen),
            ),
          ),
        ],
      ),
    );
  }
}
