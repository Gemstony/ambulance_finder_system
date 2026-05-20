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

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  MapController? _mapController;
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

  @override
  void initState() {
    super.initState();
    _loadPatientLocation();
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


  Future<void> _loadPatientLocation() async {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    await locationProvider.getCurrentLocation();
    final loc = locationProvider.currentLocation;
    if (loc != null) {
      setState(() {
        _patientLocation = LatLng(loc.latitude, loc.longitude);
        _updatePatientMarker();
      });
      if (_mapController != null) {
        _mapController!.move(_patientLocation!, 14);
      }
    }
  }

  void _updatePatientMarker() {
    if (_patientLocation == null) return;
    setState(() {
      _markers.removeWhere((m) => m.point == _patientLocation);
      _markers.add(
        Marker(
          point: _patientLocation!,
          width: 80,
          height: 80,
          child: const Icon(Icons.person, color: Colors.red, size: 40),
        ),
      );
    });
  }

  void _updateDriverMarker() {
    if (_driverLocation == null) return;
    setState(() {
      _markers.removeWhere((m) => m.point == _driverLocation);
      _markers.add(
        Marker(
          point: _driverLocation!,
          width: 80,
          height: 80,
          child: const Icon(Icons.local_hospital, color: Colors.blue, size: 40),
        ),
      );
    });
  }

  void _drawRoute() {
    if (_patientLocation == null || _driverLocation == null) return;
    setState(() {
      _polylines = [
        Polyline(
          points: [_driverLocation!, _patientLocation!],
          strokeWidth: 4,
          color: AppColors.primaryGreen,
        ),
      ];
    });
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
    } else if (maxSpan > 0.1) {
      zoom = 11.5;
    } else if (maxSpan > 0.05) {
      zoom = 13;
    }
    _mapController?.move(LatLng(midLat, midLng), zoom);
  }

  Future<void> _getActiveRequest() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    _requestSubscription = FirebaseFirestore.instance
        .collection('requests')
        .where('patientId', isEqualTo: userId)
        .where(
          'status',
          whereIn: [
            'pending',
            'accepted',
            'enroute',
            'arrived',
            'patient_loaded',
          ],
        )
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

              // Get patient location from request data
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
          } else {
            // No active request
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
                _updateDriverMarker();
                _updateMarkers();
                _drawRoute();
              });
              if (_mapController != null &&
                  _patientLocation != null &&
                  _driverLocation != null) {
                _zoomToFitBoth();
              }
            }
          }
        });
  }

  double _calculateDistance() {
    if (_patientLocation == null || _driverLocation == null) return 0;
    final distance = Distance();
    return distance.as(
      LengthUnit.Kilometer,
      _driverLocation!,
      _patientLocation!,
    );
  }

  String _formatDistance(double km) {
    if (km <= 0) return 'Calculating...';
    // TODO: i will fix this distance problem letter, for now i will just show distance in meters
    return '${km.toStringAsFixed(0)} m';
  }

  String _formatEta(double km) {
    if (km <= 0) return 'Calculating...';
    // Assume average speed 40 km/h -> 0.666 km per minute
    final minutes = (km / 0.666).round();
    return '$minutes min';
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
      ),
      body: Stack(
        children: [
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
              ],
            )
          else
            const Center(child: CircularProgressIndicator()),
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
                    Text(
                      'Driver: $_driverName',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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
                        Text('ETA: $eta'),
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
                                  content: Text(
                                    'Arrival confirmed. Thank you!',
                                  ),
                                ),
                              );
                              Navigator.pop(context); // or navigate to home
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
