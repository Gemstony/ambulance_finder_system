import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/request_provider.dart';
import '../../utils/colors.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({Key? key}) : super(key: key);

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final requestProvider = Provider.of<RequestProvider>(context);
    final activeRequest = requestProvider.activeRequest;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Ambulance'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.veryLightGreen, AppColors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: activeRequest == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_off, size: 80, color: AppColors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No active ambulance request',
                      style: TextStyle(fontSize: 16, color: AppColors.darkGrey),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Status Timeline
                  _buildStatusTimeline(activeRequest.status),
                  
                  const SizedBox(height: 16),
                  
                  // Ambulance Info Card
                  _buildAmbulanceInfoCard(activeRequest),
                  
                  const SizedBox(height: 16),
                  
                  // Location Info
                  _buildLocationInfo(locationProvider, activeRequest),
                  
                  const SizedBox(height: 16),
                  
                  // ETA Card
                  _buildETACard(locationProvider, activeRequest),
                  
                  const SizedBox(height: 16),
                  
                  // Emergency Contacts
                  _buildEmergencyContacts(),
                ],
              ),
      ),
    );
  }
  
  Widget _buildStatusTimeline(String status) {
    final List<Map<String, dynamic>> steps = [
      {'label': 'Requested', 'key': 'pending', 'icon': Icons.add_circle_outline},
      {'label': 'Accepted', 'key': 'accepted', 'icon': Icons.check_circle_outline},
      {'label': 'En Route', 'key': 'enroute', 'icon': Icons.directions_car},
      {'label': 'Arrived', 'key': 'arrived', 'icon': Icons.location_on},
      {'label': 'At Hospital', 'key': 'at_hospital', 'icon': Icons.local_hospital},
    ];
    
    int currentStep = steps.indexWhere((step) => step['key'] == status);
    if (currentStep == -1) currentStep = 0;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip Status',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(steps.length, (index) {
              final isCompleted = index <= currentStep;
              final isCurrent = index == currentStep;
              
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCompleted ? AppColors.primaryGreen : Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        steps[index]['icon'],
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[index]['label'],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCompleted ? AppColors.primaryGreen : AppColors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAmbulanceInfoCard(activeRequest) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.veryLightGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_hospital, color: AppColors.primaryGreen, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activeRequest.driverName ?? 'Assigning Driver...',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  activeRequest.ambulanceNumber ?? 'Ambulance Unit',
                  style: TextStyle(fontSize: 12, color: AppColors.grey),
                ),
              ],
            ),
          ),
          if (activeRequest.driverId != null)
            IconButton(
              icon: const Icon(Icons.phone, color: AppColors.primaryGreen),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Calling driver...')),
                );
              },
            ),
        ],
      ),
    );
  }
  
  Widget _buildLocationInfo(LocationProvider locationProvider, activeRequest) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📍 Location Information', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: AppColors.grey),
              const SizedBox(width: 8),
              Text('You: ${locationProvider.formattedCurrentLocation}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.local_hospital, size: 16, color: AppColors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ambulance: ${locationProvider.hasDriverLocation ? locationProvider.formattedDriverLocation : "Waiting for location..."}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildETACard(LocationProvider locationProvider, activeRequest) {
    final eta = locationProvider.getEstimatedTimeTo(
      activeRequest.patientLocation.latitude,
      activeRequest.patientLocation.longitude,
    );
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer, color: Colors.white, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Estimated Arrival Time', style: TextStyle(color: Colors.white70)),
                Text(
                  locationProvider.getFormattedEstimatedTimeTo(
                    activeRequest.patientLocation.latitude,
                    activeRequest.patientLocation.longitude,
                  ),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmergencyContacts() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📞 Emergency Contacts', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.emergency, color: AppColors.darkRed),
            title: const Text('Emergency Hotline'),
            subtitle: const Text('112 or 115'),
            trailing: IconButton(
              icon: const Icon(Icons.call, color: AppColors.primaryGreen),
              onPressed: () {},
            ),
            dense: true,
          ),
          ListTile(
            leading: const Icon(Icons.local_hospital, color: AppColors.primaryGreen),
            title: const Text('Ambulance Dispatch'),
            subtitle: const Text('118'),
            trailing: IconButton(
              icon: const Icon(Icons.call, color: AppColors.primaryGreen),
              onPressed: () {},
            ),
            dense: true,
          ),
        ],
      ),
    );
  }
}