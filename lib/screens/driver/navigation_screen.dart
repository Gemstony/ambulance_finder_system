import 'package:ambulance_finder_system/screens/driver/driver_home.dart';
import 'package:ambulance_finder_system/services/osrm_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  double _currentDistanceMeters = 0;
  Duration _currentEta = Duration.zero;
  LatLng? _currentLocation;

  late MapController _mapController;
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _setupMarkers();
    _startLocationUpdates();
    _updateRequestStatus('enroute');
  }

  void _setupMarkers() {
    // Start with only the patient marker
    _markers = [
      Marker(
        point: LatLng(widget.patientLat, widget.patientLng),
        width: 80,
        height: 80,
        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
      ),
    ];
  }

  void _updateMarkers(LatLng? driverPos) {
    final markers = <Marker>[
      Marker(
        point: LatLng(widget.patientLat, widget.patientLng),
        width: 80,
        height: 80,
        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
      ),
    ];
    if (driverPos != null) {
      markers.add(
        Marker(
          point: driverPos,
          width: 80,
          height: 80,
          child: const Icon(Icons.directions_car, color: Colors.blue, size: 40),
        ),
      );
    }
    setState(() {
      _markers = markers;
    });
  }

  Future<void> _drawRoute(LatLng start, LatLng end) async {
    try {
      final route = await OSRMService.getRoute(start, end);
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
      // Fallback to straight line
      setState(() {
        _polylines = [
          Polyline(
            points: [start, end],
            strokeWidth: 4,
            color: AppColors.primaryGreen,
          ),
        ];
      });
    }
  }

  Future<void> _startLocationUpdates() async {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    await locationProvider.startTracking(
      onLocationUpdate: (position) async {
        final currentPos = LatLng(position.latitude, position.longitude);

        // Only calculate distance if we have both locations
        final distanceMeters = GpsService.calculateDistance(
          position.latitude,
          position.longitude,
          widget.patientLat,
          widget.patientLng,
        );

        setState(() {
          _currentLocation = currentPos;
          _currentDistanceMeters = distanceMeters;
          _currentEta = GpsService.calculateEstimatedTime(distanceMeters);
        });

        _updateMarkers(currentPos);

        // Draw route only if we have both locations
        if (_currentLocation != null) {
          await _drawRoute(
            currentPos,
            LatLng(widget.patientLat, widget.patientLng),
          );
          _zoomToFit(currentPos, LatLng(widget.patientLat, widget.patientLng));
        }

        final user = Provider.of<AuthProvider>(
          context,
          listen: false,
        ).currentUser;
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
    final midLat = (driver.latitude + patient.latitude) / 2;
    final midLng = (driver.longitude + patient.longitude) / 2;
    final latDiff = (driver.latitude - patient.latitude).abs();
    final lngDiff = (driver.longitude - patient.longitude).abs();
    final maxSpan = latDiff > lngDiff ? latDiff : lngDiff;
    double zoom = 14;
    if (maxSpan > 0.2) {
      zoom = 10;
    } else if (maxSpan > 0.1)
      zoom = 11.5;
    else if (maxSpan > 0.05)
      zoom = 13;
    _mapController.move(LatLng(midLat, midLng), zoom);
  }

  Future<void> _updateRequestStatus(String status) async {
    setState(() => _currentStatus = status);
    await _firestoreService.updateRequestStatus(widget.requestId, status);
  }

  Future<void> _markAsArrived() async {
    setState(() => _isLoading = true);
    await _updateRequestStatus('arrived');
    if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Driver Arrived'),
          content: const Text(
            'The ambulance has been marked as arrived. The patient will now confirm.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Congratulations! Request completed.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const DriverHome()),
                );
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasDriverLocation = _currentLocation != null;
    final etaMinutes = _currentEta.inMinutes;

    return Scaffold(
      appBar: AppBar(
        title: Text('Navigate to ${widget.patientName}'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: Stack(
        children: [
          // Map – always shown, centered on patient location
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(widget.patientLat, widget.patientLng),
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ambulance_finder.app',
              ),
              MarkerLayer(markers: _markers),
              PolylineLayer(polylines: _polylines),
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ),
              ),
            ],
          ),
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
                    Text(
                      'Patient: ${widget.patientName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Distance: ${_currentDistanceMeters.toStringAsFixed(0)} m',
                        ),
                        Text(':'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Phone: ${widget.patientPhone}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    if (!hasDriverLocation)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Getting your location...'),
                            ],
                          ),
                        ),
                      ),
                    if (hasDriverLocation)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _markAsArrived,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                              ),
                              child: const Text('Arrived at Patient'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
