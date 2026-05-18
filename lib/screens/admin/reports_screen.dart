import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'dart:io';
import '../../services/firestore_service.dart';
import '../../utils/colors.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedReportType = 'users';
  bool _isExporting = false;
  
  // Report data
  List<QueryDocumentSnapshot> _users = [];
  List<QueryDocumentSnapshot> _requests = [];
  List<QueryDocumentSnapshot> _completedTrips = [];

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  void _loadReportData() {
    _firestoreService.getAllUsers().listen((snapshot) {
      setState(() => _users = snapshot.docs);
    });
    _firestoreService.getAllRequests().listen((snapshot) {
      setState(() {
        _requests = snapshot.docs;
        _completedTrips = snapshot.docs.where((doc) => 
          doc['status'] == 'completed'
        ).toList();
      });
    });
  }

  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);
    
    try {
      var excel = ex.Excel.createExcel();
      
      if (_selectedReportType == 'users') {
        // Users Report Sheet
        var sheetObject = excel['Users Report'];
        _addUsersReportHeader(sheetObject);
        _addUsersReportData(sheetObject);
        
      } else if (_selectedReportType == 'requests') {
        // Requests Report Sheet
        var sheetObject = excel['Requests Report'];
        _addRequestsReportHeader(sheetObject);
        _addRequestsReportData(sheetObject);
        
      } else if (_selectedReportType == 'completed') {
        // Completed Trips Report
        var sheetObject = excel['Completed Trips'];
        _addCompletedTripsHeader(sheetObject);
        _addCompletedTripsData(sheetObject);
      }
      
      // Save and share
      final dir = await path_provider.getTemporaryDirectory();
      final filePath = '${dir.path}/report_${_selectedReportType}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);
      
      await Share.shareXFiles([XFile(filePath)], 
        text: '${_getReportTitle()} Export',
        subject: 'Ambulance Finder System Report'
      );
      
      setState(() => _isExporting = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report exported successfully!')),
        );
      }
    } catch (e) {
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _addUsersReportHeader(dynamic sheet) {
    sheet.appendRow([
      'Full Name', 'Email', 'Phone', 'Role', 'Status', 'Joined Date'
    ]);
  }

  void _addUsersReportData(dynamic sheet) {
    for (var user in _users) {
      final data = user.data() as Map<String, dynamic>;
      sheet.appendRow([
        data['fullName'] ?? 'Unknown',
        data['email'] ?? 'No email',
        data['phone'] ?? 'No phone',
        data['role'] ?? 'patient',
        data['isActive'] == true ? 'Active' : 'Inactive',
        _formatDate(data['createdAt']),
      ]);
    }
  }

  void _addRequestsReportHeader(dynamic sheet) {
    sheet.appendRow([
      'Patient Name', 'Patient Phone', 'Status', 'Emergency Type', 
      'Severity', 'Driver', 'Requested Date', 'Completed Date'
    ]);
  }

  void _addRequestsReportData(dynamic sheet) {
    for (var request in _requests) {
      final data = request.data() as Map<String, dynamic>;
      sheet.appendRow([
        data['patientName'] ?? 'Unknown',
        data['patientPhone'] ?? 'No phone',
        data['status'] ?? 'pending',
        data['emergencyType'] ?? 'Not specified',
        data['severity'] ?? 'medium',
        data['driverName'] ?? 'Not assigned',
        _formatDate(data['timestamp']),
        _formatDate(data['completedAt']),
      ]);
    }
  }

  void _addCompletedTripsHeader(dynamic sheet) {
    sheet.appendRow([
      'Patient Name', 'Driver Name', 'Response Time', 'Completed Date', 'Rating'
    ]);
  }

  void _addCompletedTripsData(dynamic sheet) {
    for (var trip in _completedTrips) {
      final data = trip.data() as Map<String, dynamic>;
      final responseTime = _calculateResponseTime(data['timestamp'], data['completedAt']);
      sheet.appendRow([
        data['patientName'] ?? 'Unknown',
        data['driverName'] ?? 'Unknown',
        responseTime,
        _formatDate(data['completedAt']),
        data['patientRating']?.toString() ?? 'No rating',
      ]);
    }
  }

  String _calculateResponseTime(dynamic start, dynamic end) {
    if (start == null || end == null) return 'N/A';
    DateTime startTime = start is Timestamp ? start.toDate() : DateTime.parse(start.toString());
    DateTime endTime = end is Timestamp ? end.toDate() : DateTime.parse(end.toString());
    Duration diff = endTime.difference(startTime);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minutes';
    } else {
      return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    }
  }

  String _getReportTitle() {
    switch (_selectedReportType) {
      case 'users': return 'Users Report';
      case 'requests': return 'All Requests Report';
      case 'completed': return 'Completed Trips Report';
      default: return 'Report';
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else {
      date = DateTime.parse(timestamp.toString());
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  int _getTotalCount() {
    switch (_selectedReportType) {
      case 'users': return _users.length;
      case 'requests': return _requests.length;
      case 'completed': return _completedTrips.length;
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.veryLightGreen, AppColors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // Report Type Selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Select Report Type',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReportTypeCard(
                          title: 'Users',
                          icon: Icons.people,
                          type: 'users',
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReportTypeCard(
                          title: 'All Requests',
                          icon: Icons.list_alt,
                          type: 'requests',
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReportTypeCard(
                          title: 'Completed Trips',
                          icon: Icons.check_circle,
                          type: 'completed',
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Summary Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getReportTitle(),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      Text(
                        '${_getTotalCount()} records',
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 24, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),
                  _isExporting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : ElevatedButton.icon(
                          onPressed: _exportToExcel,
                          icon: const Icon(Icons.download),
                          label: const Text('Export to Excel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primaryGreen,
                          ),
                        ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Data Preview
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5),
                ],
              ),
              child: _buildDataPreview(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTypeCard({
    required String title,
    required IconData icon,
    required String type,
    required Color color,
  }) {
    final isSelected = _selectedReportType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedReportType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 24),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataPreview() {
    if (_selectedReportType == 'users') {
      return _buildUsersPreview();
    } else if (_selectedReportType == 'requests') {
      return _buildRequestsPreview();
    } else {
      return _buildCompletedTripsPreview();
    }
  }

  Widget _buildUsersPreview() {
    if (_users.isEmpty) {
      return const Center(child: Text('No users found'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _users.length > 10 ? 10 : _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final data = user.data() as Map<String, dynamic>;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
            child: Text(
              data['fullName']?.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(color: AppColors.primaryGreen),
            ),
          ),
          title: Text(data['fullName'] ?? 'Unknown'),
          subtitle: Text(data['email'] ?? 'No email'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: data['role'] == 'admin' ? Colors.red.shade100 : 
                     data['role'] == 'driver' ? Colors.blue.shade100 : 
                     AppColors.veryLightGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              data['role']?.toUpperCase() ?? 'PATIENT',
              style: TextStyle(
                fontSize: 10,
                color: data['role'] == 'admin' ? Colors.red : 
                       data['role'] == 'driver' ? Colors.blue : 
                       AppColors.primaryGreen,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestsPreview() {
    if (_requests.isEmpty) {
      return const Center(child: Text('No requests found'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _requests.length > 10 ? 10 : _requests.length,
      itemBuilder: (context, index) {
        final request = _requests[index];
        final data = request.data() as Map<String, dynamic>;
        return ListTile(
          leading: const Icon(Icons.emergency, color: AppColors.darkRed),
          title: Text(data['patientName'] ?? 'Unknown'),
          subtitle: Text(data['status'] ?? 'pending'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: data['status'] == 'pending' ? Colors.orange.shade100 : Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              data['status']?.toUpperCase() ?? 'PENDING',
              style: TextStyle(
                fontSize: 10,
                color: data['status'] == 'pending' ? Colors.orange : Colors.green,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompletedTripsPreview() {
    if (_completedTrips.isEmpty) {
      return const Center(child: Text('No completed trips found'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _completedTrips.length > 10 ? 10 : _completedTrips.length,
      itemBuilder: (context, index) {
        final trip = _completedTrips[index];
        final data = trip.data() as Map<String, dynamic>;
        return ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text(data['patientName'] ?? 'Unknown'),
          subtitle: Text('Driver: ${data['driverName'] ?? 'Unknown'}'),
          trailing: Text(
            _formatDate(data['completedAt']),
            style: const TextStyle(fontSize: 12),
          ),
        );
      },
    );
  }
}