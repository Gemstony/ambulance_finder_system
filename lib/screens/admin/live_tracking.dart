import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../utils/colors.dart';

class LiveTracking extends StatefulWidget {
  const LiveTracking({super.key});

  @override
  State<LiveTracking> createState() => _LiveTrackingState();
}

class _LiveTrackingState extends State<LiveTracking> {
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedView = 'ambulances';
  final MapController _mapController = MapController();
  List<Marker> _markers = [];

  int _activeDrivers = 0;
  int _activeRequests = 0;
  int _availableAmbulances = 0;

  @override
  void initState() {
    super.initState();
    _listenToLocations();
    _fetchStats();
  }

  void _listenToLocations() {
    // Fetch drivers/ambulances and update markers
    FirebaseFirestore.instance
        .collection('drivers_location')
        .snapshots()
        .listen((snapshot) {
          final markers = <Marker>[];
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final geo = data['location'] as GeoPoint?;
            if (geo != null) {
              markers.add(
                Marker(
                  point: LatLng(geo.latitude, geo.longitude),
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.directions_car, color: Colors.blue),
                ),
              );
            }
          }
          setState(() => _markers = markers);
        });
  }

  Future<void> _fetchStats() async {
    // Implement count queries
    setState(() {
      _activeDrivers = 3; // placeholder, replace with actual Firestore count
      _activeRequests = 2;
      _availableAmbulances = 4;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.veryLightGreen, AppColors.white],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildViewButton(
                    'Ambulances',
                    'ambulances',
                    Icons.airport_shuttle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildViewButton('Drivers', 'drivers', Icons.person),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildViewButton('All', 'all', Icons.map)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Active Drivers',
                    _activeDrivers.toString(),
                    Icons.airport_shuttle,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'Active Requests',
                    _activeRequests.toString(),
                    Icons.emergency,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'Available',
                    _availableAmbulances.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryGreen, width: 2),
              ),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(-6.7924, 39.2083),
                  initialZoom: 12,
                ), // Dar es Salaam center
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.ambulance_finder.app',
                  ),
                  MarkerLayer(markers: _markers),
                ],
              ),
            ),
          ),
          _buildActiveResourcesList(),
        ],
      ),
    );
  }

  Widget _buildActiveResourcesList() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Resources',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton(onPressed: () {}, child: const Text('View All')),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.getActiveDrivers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final drivers = snapshot.data!.docs;
                if (drivers.isEmpty) {
                  return const Center(child: Text('No active drivers'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: drivers.length,
                  itemBuilder: (context, index) {
                    final driver = drivers[index];
                    final data = driver.data() as Map<String, dynamic>;
                    return _buildResourceItem(
                      name: data['fullName'] ?? 'Driver',
                      status: data['isOnline'] == true ? 'Online' : 'Offline',
                      location: 'Moving',
                      statusColor: data['isOnline'] == true
                          ? Colors.green
                          : Colors.grey,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewButton(String label, String viewKey, IconData icon) {
    final isSelected = _selectedView == viewKey;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppColors.primaryGreen : Colors.white,
        foregroundColor: isSelected ? Colors.white : AppColors.primaryGreen,
        side: BorderSide(color: AppColors.primaryGreen),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: () {
        setState(() {
          _selectedView = viewKey;
        });
      },
      icon: Icon(icon),
      label: Text(label),
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceItem({
    required String name,
    required String status,
    required String location,
    required Color statusColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: statusColor.withOpacity(0.2),
            child: Icon(Icons.local_hospital, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '$status • $location',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade600),
        ],
      ),
    );
  }
}
