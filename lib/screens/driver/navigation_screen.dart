import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/request_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/gps_service.dart';
import '../../utils/colors.dart';

class NavigationScreen extends StatefulWidget {
  final String requestId;
  final String patientName;
  final double patientLat;
  final double patientLng;

  const NavigationScreen({
    super.key,
    required this.requestId,
    required this.patientName,
    required this.patientLat,
    required this.patientLng,
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

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
    _updateRequestStatus('enroute');
  }

  void _startLocationUpdates() {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    locationProvider.startTracking(
      onLocationUpdate: (position) async {
        // Update distance to patient
        _updateDistanceToPatient(position.latitude, position.longitude);
        
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

  void _updateDistanceToPatient(double currentLat, double currentLng) {
    final distance = GpsService.calculateDistance(
      currentLat,
      currentLng,
      widget.patientLat,
      widget.patientLng,
    );
    setState(() {
      _currentDistance = distance;
      _currentEta = GpsService.calculateEstimatedTime(distance);
    });
  }

  Future<void> _updateRequestStatus(String status) async {
    setState(() => _currentStatus = status);
    await _firestoreService.updateRequestStatus(widget.requestId, status);
  }

  Future<void> _markAsArrived() async {
    setState(() => _isLoading = true);
    await _updateRequestStatus('arrived');
    
    // Show dialog
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
          CustomButton(
            text: 'Load Patient',
            onPressed: () {
              Navigator.pop(context);
              _markAsLoaded();
            },
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
                const SnackBar(content: Text('Calling patient...')),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.veryLightGreen, AppColors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Status Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(Icons.navigation, color: AppColors.primaryGreen, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Destination',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.patientName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Icon(Icons.straighten, color: AppColors.primaryGreen),
                            const SizedBox(height: 4),
                            Text(
                              GpsService.formatDistance(_currentDistance),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Text('Distance', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Icon(Icons.timer, color: Colors.orange),
                            const SizedBox(height: 4),
                            Text(
                              GpsService.formatDuration(_currentEta),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Text('ETA', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Map Placeholder (in real app, use Google Map)
            Container(
              margin: const EdgeInsets.all(16),
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryGreen, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map, size: 60, color: AppColors.primaryGreen),
                  const SizedBox(height: 8),
                  Text(
                    'Map View',
                    style: TextStyle(color: AppColors.primaryGreen),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Navigation from your location to patient',
                    style: TextStyle(fontSize: 12, color: AppColors.grey),
                  ),
                ],
              ),
            ),
            
            // Status Timeline
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _buildStatusTimeline(),
            ),
            
            const Spacer(),
            
            // Action Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: CustomButton(
                text: _currentStatus == 'arrived' 
                    ? '✅ PATIENT LOADED' 
                    : _currentStatus == 'patient_loaded'
                        ? '🏥 COMPLETE TRIP'
                        : '📍 MARK AS ARRIVED',
                onPressed: _currentStatus == 'arrived'
                    ? _markAsLoaded
                    : _currentStatus == 'patient_loaded'
                        ? _completeTrip
                        : _markAsArrived,
                isEmergency: true,
                height: 55,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline() {
    final List<Map<String, dynamic>> steps = [
      {'label': 'Accepted', 'key': 'accepted', 'icon': Icons.check_circle, 'completed': true},
      {'label': 'En Route', 'key': 'enroute', 'icon': Icons.directions_car, 'completed': _currentStatus != 'accepted'},
      {'label': 'Arrived', 'key': 'arrived', 'icon': Icons.location_on, 'completed': _currentStatus == 'arrived' || _currentStatus == 'patient_loaded'},
      {'label': 'Loaded', 'key': 'patient_loaded', 'icon': Icons.people, 'completed': _currentStatus == 'patient_loaded'},
    ];
    
    return Column(
      children: [
        Row(
          children: List.generate(steps.length, (index) {
            final step = steps[index];
            final isCompleted = step['completed'];
            
            return Expanded(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCompleted ? AppColors.primaryGreen : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(step['icon'], color: Colors.white, size: 20),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step['label'],
                    style: TextStyle(
                      fontSize: 10,
                      color: isCompleted ? AppColors.primaryGreen : AppColors.grey,
                      fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isEmergency;
  final double height;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isEmergency = false,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isEmergency ? AppColors.primaryGreen : AppColors.primaryGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
