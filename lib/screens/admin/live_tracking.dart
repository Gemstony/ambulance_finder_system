import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/colors.dart';
import '../../models/request_model.dart';
import '../../models/user_model.dart';

class LiveTracking extends StatefulWidget {
  const LiveTracking({super.key});

  @override
  State<LiveTracking> createState() => _LiveTrackingState();
}

class _LiveTrackingState extends State<LiveTracking> {
  final FirestoreService _firestoreService = FirestoreService();
  int _selectedTab = 0; // 0=Drivers, 1=Pending, 2=Rejected, 3=All

  Future<List<DocumentSnapshot>> _getPendingRequestsWithRejections() async {
    final pendingSnapshot = await FirebaseFirestore.instance
        .collection('requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .get();
    List<DocumentSnapshot> result = [];
    for (var doc in pendingSnapshot.docs) {
      if (await _firestoreService.hasRejections(doc.id)) {
        result.add(doc);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Control Panel'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Tab selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildTab('Drivers', 0),
                const SizedBox(width: 8),
                _buildTab('Pending', 1),
                const SizedBox(width: 8),
                _buildTab('Rejected', 2),
                const SizedBox(width: 8),
                _buildTab('All Requests', 3),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _buildDriversTab(),
                _buildPendingRequestsTab(),
                _buildRejectedRequestsTab(),
                _buildAllRequestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGreen : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== DRIVERS TAB ====================
  Widget _buildDriversTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getAllDriversWithStatus(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final drivers = snapshot.data!.docs;
        if (drivers.isEmpty) {
          return const Center(child: Text('No drivers found'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: drivers.length,
          itemBuilder: (context, index) {
            final data = drivers[index].data() as Map<String, dynamic>;
            final driverId = drivers[index].id;
            final isOnline = data['isOnline'] == true;
            final isActive = data['isActive'] == true;
            final name = data['fullName'] ?? 'Driver';
            final phone = data['phone'] ?? 'No phone';
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isOnline ? Colors.green : Colors.grey,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Phone: $phone'),
                    Text('Status: ${isOnline ? "Online" : "Offline"}'),
                    if (!isActive)
                      Text(
                        '⚠️ Deactivated',
                        style: TextStyle(color: Colors.red),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isOnline ? Icons.wifi : Icons.wifi_off,
                        color: isOnline ? Colors.green : Colors.red,
                      ),
                      onPressed: () async {
                        // Toggle online status (admin override)
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(driverId)
                            .update({
                              'isOnline': !isOnline,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${isOnline ? "Offlined" : "Onlined"} $name',
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        isActive ? Icons.block : Icons.check_circle,
                        color: isActive ? Colors.red : Colors.green,
                      ),
                      onPressed: () async {
                        await _firestoreService.updateUserStatus(
                          driverId,
                          !isActive,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${isActive ? "Deactivated" : "Activated"} $name',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==================== PENDING REQUESTS TAB ====================
  Widget _buildPendingRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getPendingRequests(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snapshot.data!.docs;
        if (requests.isEmpty) {
          return const Center(child: Text('No pending requests'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final doc = requests[index];
            final data = doc.data() as Map<String, dynamic>;
            final requestId = doc.id;
            final patientName = data['patientName'] ?? 'Unknown';
            final patientPhone = data['patientPhone'] ?? '';
            final timestamp =
                (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            final location = data['patientLocation'] as Map?;
            final lat = location?['latitude'] ?? 0.0;
            final lng = location?['longitude'] ?? 0.0;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: const Icon(Icons.emergency, color: Colors.orange),
                title: Text(patientName),
                subtitle: Text('Requested: ${_formatDate(timestamp)}'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Phone: $patientPhone'),
                        Text('Location: $lat, $lng'),
                        const Divider(),
                        // Admin can assign driver manually
                        Text('Assign to driver:'),
                        const SizedBox(height: 8),
                        AssignDriverDropdown(requestId: requestId),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Dropdown to assign a driver to a request
  Widget _buildAssignDriverDropdown(String requestId) {
    return FutureBuilder<List<QueryDocumentSnapshot>>(
      future: _firestoreService.getAvailableDrivers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }
        final drivers = snapshot.data!;
        if (drivers.isEmpty) {
          return const Text('No available drivers');
        }
        String? selectedDriverId;
        String? selectedDriverName;
        return Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(border: OutlineInputBorder()),
              hint: const Text('Select driver'),
              items: drivers.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return DropdownMenuItem(
                  value: doc.id,
                  child: Text(data['fullName'] ?? 'Driver'),
                );
              }).toList(),
              onChanged: (value) {
                selectedDriverId = value;
                final doc = drivers.firstWhere((d) => d.id == value);
                selectedDriverName =
                    (doc.data() as Map<String, dynamic>)['fullName'] ??
                    'Driver';
              },
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: selectedDriverId == null
                  ? null
                  : () async {
                      await _firestoreService.reassignRequest(
                        requestId,
                        selectedDriverId!,
                        selectedDriverName!,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Request assigned to driver'),
                        ),
                      );
                    },
              child: const Text('Assign Now'),
            ),
          ],
        );
      },
    );
  }

  // ==================== REJECTED REQUESTS TAB ====================
  Widget _buildRejectedRequestsTab() {
    return FutureBuilder<List<DocumentSnapshot>>(
      future: _getPendingRequestsWithRejections(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No rejected requests'));
        }
        final rejectedRequests = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rejectedRequests.length,
          itemBuilder: (context, index) {
            final doc = rejectedRequests[index];
            final data = doc.data() as Map<String, dynamic>;
            final requestId = doc.id;
            final patientName = data['patientName'] ?? 'Unknown';
            final patientPhone = data['patientPhone'] ?? '';
            final timestamp =
                (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: const Icon(Icons.report_problem, color: Colors.red),
                title: Text(patientName),
                subtitle: Text('Rejected • ${_formatDate(timestamp)}'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Phone: $patientPhone'),
                        const Divider(),
                        Text('Rejected drivers:'),
                        FutureBuilder<List<String>>(
                          future: _firestoreService.getRejectedDriverIds(
                            requestId,
                          ),
                          builder: (ctx, rejectedIds) {
                            if (!rejectedIds.hasData)
                              return const Text('Loading...');
                            return Column(
                              children: rejectedIds.data!
                                  .map((id) => Text('• Driver ID: $id'))
                                  .toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text('Reassign to a new driver:'),
                        AssignDriverDropdown(requestId: requestId),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<DocumentSnapshot>> _filterRequestsWithRejections(
    List<QueryDocumentSnapshot> allPending,
  ) async {
    List<DocumentSnapshot> result = [];
    for (var doc in allPending) {
      if (await _firestoreService.hasRejections(doc.id)) {
        result.add(doc);
      }
    }
    return result;
  }

  // ==================== ALL REQUESTS TAB ====================
  Widget _buildAllRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getAllRequests(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snapshot.data!.docs;
        if (requests.isEmpty) {
          return const Center(child: Text('No requests found'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final doc = requests[index];
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'unknown';
            final patientName = data['patientName'] ?? 'Unknown';
            final timestamp =
                (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            final driverName = data['driverName'] ?? 'Not assigned';
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(status),
                  child: Text(
                    status[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(patientName),
                subtitle: Text(
                  'Status: $status\nDriver: $driverName\nRequested: ${_formatDate(timestamp)}',
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'enroute':
        return Colors.cyan;
      case 'arrived':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class AssignDriverDropdown extends StatefulWidget {
  final String requestId;
  const AssignDriverDropdown({super.key, required this.requestId});

  @override
  State<AssignDriverDropdown> createState() => _AssignDriverDropdownState();
}

class _AssignDriverDropdownState extends State<AssignDriverDropdown> {
  final FirestoreService _firestoreService = FirestoreService();
  String? _selectedDriverId;
  String? _selectedDriverName;
  bool _isAssigning = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QueryDocumentSnapshot>>(
      future: _firestoreService.getAvailableDrivers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }
        final drivers = snapshot.data!;
        if (drivers.isEmpty) {
          return const Text('No available drivers');
        }
        return Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(border: OutlineInputBorder()),
              hint: const Text('Select driver'),
              value: _selectedDriverId,
              items: drivers.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return DropdownMenuItem(
                  value: doc.id,
                  child: Text(data['fullName'] ?? 'Driver'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDriverId = value;
                  final doc = drivers.firstWhere((d) => d.id == value);
                  _selectedDriverName =
                      (doc.data() as Map<String, dynamic>)['fullName'] ??
                      'Driver';
                });
              },
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: (_selectedDriverId == null || _isAssigning)
                  ? null
                  : () async {
                      setState(() => _isAssigning = true);
                      await _firestoreService.reassignRequest(
                        widget.requestId,
                        _selectedDriverId!,
                        _selectedDriverName!,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Request assigned to driver'),
                          ),
                        );
                        setState(() => _isAssigning = false);
                      }
                    },
              child: _isAssigning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Assign Now'),
            ),
          ],
        );
      },
    );
  }
}
