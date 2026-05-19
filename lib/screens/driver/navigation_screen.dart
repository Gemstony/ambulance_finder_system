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
  double _currentDistance = 0;
  Duration _currentEta = Duration.zero;
  LatLng? _currentLocation;

  MapController? _mapController;
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
    _updateRequestStatus('enroute');
    _setupMarkers();
  }

  void _setupMarkers() {
    _markers = [
      Marker(
        point: LatLng(widget.patientLat, widget.patientLng),
        width: 80,
        height: 80,
        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
      ),
    ];
  }

  void _updateDriverMarker(LatLng position) {
    setState(() {
      _markers.removeWhere((m) => m.point == _currentLocation);
      _markers.add(
        Marker(
          point: position,
          width: 80,
          height: 80,
          child: const Icon(Icons.directions_car, color: Colors.blue, size: 40),
        ),
      );
    });
  }

  void _drawRoute(LatLng currentPos) {
    setState(() {
      _polylines = [
        Polyline(
          points: [currentPos, LatLng(widget.patientLat, widget.patientLng)],
          strokeWidth: 4,
          color: AppColors.primaryGreen,
        ),
      ];
    });
  }

  Future<void> _startLocationUpdates() async {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
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
        if (_mapController != null)
          _zoomToFit(currentPos, LatLng(widget.patientLat, widget.patientLng));

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
    final maxSpan =
        (driver.latitude - patient.latitude).abs() >
            (driver.longitude - patient.longitude).abs()
        ? (driver.latitude - patient.latitude).abs()
        : (driver.longitude - patient.longitude).abs();
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
          content: const Text('The ambulance has been marked as arrived.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _markAsLoaded() async {
    setState(() => _isLoading = true);
    await _updateRequestStatus('patient_loaded');
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Patient has been loaded.')));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _completeTrip() async {
    setState(() => _isLoading = true);
    await _updateRequestStatus('completed');
    if (mounted) Navigator.pushReplacementNamed(context, '/driver-home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Navigate to ${widget.patientName}'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: Stack(
        children: [
          if (_currentLocation != null)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation!,
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
                          'Distance: ${_currentDistance.toStringAsFixed(1)} km',
                        ),
                        Text(
                          'ETA: ${_currentEta.inMinutes > 0 ? '${_currentEta.inMinutes} min' : 'Calculating'}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Phone: ${widget.patientPhone}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _markAsArrived,
                            child: const Text('Arrived at Patient'),
                          ),
                        ),
                        // Remove Loaded and Complete buttons
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
