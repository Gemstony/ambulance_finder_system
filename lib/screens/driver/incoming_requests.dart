import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/gps_service.dart';
import '../../utils/colors.dart';
import 'navigation_screen.dart';

class IncomingRequests extends StatefulWidget {
  const IncomingRequests({super.key});

  @override
  State<IncomingRequests> createState() => _IncomingRequestsState();
}

class _IncomingRequestsState extends State<IncomingRequests> {
  String _filter = 'all'; // all, high, medium, low
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  void _loadRequests() {
    final requestProvider = Provider.of<RequestProvider>(context, listen: false);
    requestProvider.listenToPendingRequests();
  }

  Future<void> _acceptRequest(String requestId, String patientName, double lat, double lng) async {
    setState(() => _isLoading = true);
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final requestProvider = Provider.of<RequestProvider>(context, listen: false);
    final userData = authProvider.currentUserData;
    
    if (userData == null) return;
    
    final success = await requestProvider.acceptRequest(
      requestId,
      userData.uid,
      userData.fullName,
    );
    
    setState(() => _isLoading = false);
    
    if (success && mounted) {
      // Navigate to navigation screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => NavigationScreen(
            requestId: requestId,
            patientName: patientName,
            patientLat: lat,
            patientLng: lng,
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(requestProvider.errorMessage ?? 'Failed to accept request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<dynamic> _getFilteredRequests(List<dynamic> requests) {
    if (_filter == 'all') return requests;
    return requests.where((req) => req.severity == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final requestProvider = Provider.of<RequestProvider>(context);
    final pendingRequests = requestProvider.pendingRequests;
    final filteredRequests = _getFilteredRequests(pendingRequests);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming Requests'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Filter Button
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
            : pendingRequests.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () async => _loadRequests(),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredRequests.length,
                      itemBuilder: (context, index) {
                        final request = filteredRequests[index];
                        return _buildRequestCard(request);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 80, color: AppColors.grey),
          const SizedBox(height: 16),
          Text(
            'No incoming requests',
            style: TextStyle(fontSize: 18, color: AppColors.darkGrey),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure you are online to receive requests',
            style: TextStyle(fontSize: 14, color: AppColors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadRequests,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(request) {
    final distance = GpsService.calculateDistance(
      Provider.of<LocationProvider>(context).currentLocation?.latitude ?? 0,
      Provider.of<LocationProvider>(context).currentLocation?.longitude ?? 0,
      request.patientLocation.latitude,
      request.patientLocation.longitude,
    );
    
    final eta = GpsService.calculateEstimatedTime(distance);
    
    Color severityColor;
    switch (request.severity) {
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
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with severity
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
                    request.emergencyType == 'accident' ? Icons.car_crash :
                    request.emergencyType == 'heart_attack' ? Icons.favorite :
                    request.emergencyType == 'stroke' ? Icons.psychology :
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
                        request.patientName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${request.severity?.toUpperCase() ?? 'URGENT'} EMERGENCY',
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
                    _formatTime(request.timestamp),
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
                // Phone
                Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: AppColors.primaryGreen),
                    const SizedBox(width: 8),
                    Text(
                      request.patientPhone,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Location
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: AppColors.darkRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${request.patientLocation.latitude.toStringAsFixed(6)}, ${request.patientLocation.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Notes
                if (request.notes != null && request.notes!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.veryLightGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.note, size: 14, color: AppColors.primaryGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request.notes!,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
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
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _acceptRequest(
                          request.requestId,
                          request.patientName,
                          request.patientLocation.latitude,
                          request.patientLocation.longitude,
                        ),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('ACCEPT REQUEST'),
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
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Request declined')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours} hours ago';
  }
}