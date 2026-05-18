import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/gps_service.dart';
import '../../utils/colors.dart';
import 'navigation_screen.dart';

class IncomingRequests extends StatefulWidget {
  const IncomingRequests({Key? key}) : super(key: key);

  @override
  State<IncomingRequests> createState() => _IncomingRequestsState();
}

class _IncomingRequestsState extends State<IncomingRequests> {
  String _filter = 'all';
  bool _isLoading = false;
  List<QueryDocumentSnapshot> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  void _loadRequests() {
    FirebaseFirestore.instance
        .collection('requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _pendingRequests = snapshot.docs;
      });
    });
  }

  List<QueryDocumentSnapshot> _getFilteredRequests() {
    if (_filter == 'all') return _pendingRequests;
    return _pendingRequests.where((req) {
      final data = req.data() as Map<String, dynamic>;
      return data['severity'] == _filter;
    }).toList();
  }

  Future<void> _acceptRequest(
    String requestId,
    String patientName,
    double lat,
    double lng,
    String patientPhone,
  ) async {
    setState(() => _isLoading = true);
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userData = authProvider.currentUserData;
    
    if (userData == null) return;
    
    try {
      await FirebaseFirestore.instance.collection('requests').doc(requestId).update({
        'status': 'accepted',
        'driverId': userData.uid,
        'driverName': userData.fullName,
        'driverPhone': userData.phone,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      
      setState(() => _isLoading = false);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => NavigationScreen(
              requestId: requestId,
              patientName: patientName,
              patientLat: lat,
              patientLng: lng,
              patientPhone: patientPhone,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final filteredRequests = _getFilteredRequests();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming Requests'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Requests')),
              const PopupMenuItem(value: 'critical', child: Text('Critical Only')),
              const PopupMenuItem(value: 'high', child: Text('High Priority')),
              const PopupMenuItem(value: 'medium', child: Text('Medium Priority')),
            ],
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : filteredRequests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 80, color: AppColors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No pending requests',
                          style: TextStyle(fontSize: 16, color: AppColors.darkGrey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All patients have been served',
                          style: TextStyle(fontSize: 12, color: AppColors.grey),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async => _loadRequests(),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredRequests.length,
                      itemBuilder: (context, index) {
                        final request = filteredRequests[index];
                        final data = request.data() as Map<String, dynamic>;
                        
                        final patientLat = (data['patientLocation'] as GeoPoint).latitude;
                        final patientLng = (data['patientLocation'] as GeoPoint).longitude;
                        
                        double distance = 0;
                        if (locationProvider.hasLocation) {
                          distance = GpsService.calculateDistance(
                            locationProvider.currentLocation!.latitude,
                            locationProvider.currentLocation!.longitude,
                            patientLat,
                            patientLng,
                          );
                        }
                        
                        final eta = GpsService.calculateEstimatedTime(distance);
                        
                        Color severityColor;
                        switch (data['severity']) {
                          case 'critical': severityColor = Colors.red;
                          case 'high': severityColor = Colors.deepOrange;
                          case 'medium': severityColor = Colors.orange;
                          default: severityColor = Colors.green;
                        }
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: severityColor.withOpacity(0.1),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: severityColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        data['emergencyType'] == 'accident' ? Icons.car_crash :
                                        data['emergencyType'] == 'heart_attack' ? Icons.favorite :
                                        Icons.medical_services,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data['patientName'] ?? 'Unknown',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '${data['severity']?.toUpperCase() ?? 'URGENT'} EMERGENCY',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: severityColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _formatTime(data['timestamp']),
                                        style: TextStyle(fontSize: 10, color: AppColors.darkGrey),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Body
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.phone, size: 16, color: AppColors.primaryGreen),
                                        const SizedBox(width: 8),
                                        Text(
                                          data['patientPhone'] ?? 'No phone',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on, size: 16, color: AppColors.darkRed),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '$patientLat, $patientLng',
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    // Distance and ETA
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              children: [
                                                Icon(Icons.straighten, color: Colors.blue),
                                                const SizedBox(height: 4),
                                                Text(
                                                  GpsService.formatDistance(distance),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const Text('Distance', style: TextStyle(fontSize: 10)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              children: [
                                                Icon(Icons.timer, color: Colors.orange),
                                                const SizedBox(height: 4),
                                                Text(
                                                  GpsService.formatDuration(eta),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const Text('ETA', style: TextStyle(fontSize: 10)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 16),
                                    
                                    // Accept Button
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _acceptRequest(
                                          request.id,
                                          data['patientName'] ?? 'Patient',
                                          patientLat,
                                          patientLng,
                                          data['patientPhone'] ?? '',
                                        ),
                                        icon: const Icon(Icons.check_circle),
                                        label: const Text('ACCEPT & NAVIGATE'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryGreen,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    DateTime time;
    if (timestamp is Timestamp) {
      time = timestamp.toDate();
    } else {
      time = DateTime.parse(timestamp.toString());
    }
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours} hours ago';
  }
}