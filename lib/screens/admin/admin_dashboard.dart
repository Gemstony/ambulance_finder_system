import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/colors.dart';
import 'manage_users.dart';
import 'live_tracking.dart';
import 'reports_screen.dart';
import '../common/profile_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final FirestoreService _firestoreService = FirestoreService();
  
  // Real data variables
  int _totalUsers = 0;
  int _activeDrivers = 0;
  int _pendingRequests = 0;
  int _completedTrips = 0;
  bool _isLoadingStats = true;
  
  final List<Widget> _screens = [
    const _DashboardHome(),
    const ManageUsers(),
    const LiveTracking(),
    const ReportsScreen(),
  ];
  
  final List<String> _titles = [
    'Admin Dashboard',
    'Manage Users',
    'Live Tracking',
    'Reports',
  ];

  @override
  void initState() {
    super.initState();
    _loadRealTimeStats();
  }
  
  void _loadRealTimeStats() {
    // Listen to users collection for real-time updates
    _firestoreService.getAllUsers().listen((snapshot) {
      if (mounted) {
        setState(() {
          _totalUsers = snapshot.docs.length;
          _activeDrivers = snapshot.docs.where((doc) => 
            doc['role'] == 'driver' && doc['isActive'] == true
          ).length;
        });
      }
    });
    
    // Listen to requests collection for real-time updates
    _firestoreService.getAllRequests().listen((snapshot) {
      if (mounted) {
        setState(() {
          _pendingRequests = snapshot.docs.where((doc) => 
            doc['status'] == 'pending'
          ).length;
          _completedTrips = snapshot.docs.where((doc) => 
            doc['status'] == 'completed'
          ).length;
          _isLoadingStats = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadRealTimeStats();
              setState(() {});
            },
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: AppColors.primaryGreen,
        unselectedItemColor: AppColors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Live Map'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Reports'),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userData = authProvider.currentUserData;
    
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              width: double.infinity,
              decoration: BoxDecoration(gradient: AppColors.primaryGradient),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Text(
                      userData?.initials ?? 'A',
                      style: const TextStyle(
                        fontSize: 32, 
                        fontWeight: FontWeight.bold, 
                        color: AppColors.primaryGreen
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userData?.fullName ?? 'Admin',
                    style: const TextStyle(
                      color: Colors.white, 
                      fontSize: 18, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userData?.email ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              tileColor: _selectedIndex == 0 ? AppColors.veryLightGreen : null,
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Manage Users'),
              tileColor: _selectedIndex == 1 ? AppColors.veryLightGreen : null,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Live Tracking'),
              tileColor: _selectedIndex == 2 ? AppColors.veryLightGreen : null,
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt),
              title: const Text('Reports'),
              tileColor: _selectedIndex == 3 ? AppColors.veryLightGreen : null,
              onTap: () {
                setState(() => _selectedIndex = 3);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('My Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Dashboard Home Widget - With Real Data
class _DashboardHome extends StatefulWidget {
  const _DashboardHome({super.key});

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  final FirestoreService _firestoreService = FirestoreService();
  
  int _totalUsers = 0;
  int _activeDrivers = 0;
  int _pendingRequests = 0;
  int _completedTrips = 0;
  bool _isLoading = true;
  
  List<QueryDocumentSnapshot> _recentRequests = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }
  
  void _loadDashboardData() {
    // Get users data
    _firestoreService.getAllUsers().listen((userSnapshot) {
      if (mounted) {
        setState(() {
          _totalUsers = userSnapshot.docs.length;
          _activeDrivers = userSnapshot.docs.where((doc) => 
            doc['role'] == 'driver' && doc['isActive'] == true && doc['isOnline'] == true
          ).length;
        });
      }
    });
    
    // Get requests data
    _firestoreService.getAllRequests().listen((requestSnapshot) {
      if (mounted) {
        setState(() {
          _pendingRequests = requestSnapshot.docs.where((doc) => 
            doc['status'] == 'pending'
          ).length;
          _completedTrips = requestSnapshot.docs.where((doc) => 
            doc['status'] == 'completed'
          ).length;
          
          // Get recent 5 requests
          _recentRequests = requestSnapshot.docs
              .where((doc) => doc['status'] == 'pending')
              .take(5)
              .toList();
          
          _isLoading = false;
        });
      }
    });
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
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Stats Grid - Smaller Cards
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      _buildStatCard(
                        title: 'Total Users',
                        value: '$_totalUsers',
                        icon: Icons.people,
                        color: Colors.blue,
                      ),
                      _buildStatCard(
                        title: 'Active Drivers',
                        value: '$_activeDrivers',
                        icon: Icons.airport_shuttle,
                        color: AppColors.primaryGreen,
                      ),
                      _buildStatCard(
                        title: 'Pending Requests',
                        value: '$_pendingRequests',
                        icon: Icons.pending,
                        color: Colors.orange,
                      ),
                      _buildStatCard(
                        title: 'Completed Trips',
                        value: '$_completedTrips',
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Quick Actions - Working Buttons
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          title: 'Manage Users',
                          icon: Icons.people,
                          color: Colors.blue,
                          onTap: () {
                            // This will be handled by parent
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActionButton(
                          title: 'Live Tracking',
                          icon: Icons.map,
                          color: AppColors.primaryGreen,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          title: 'View Reports',
                          icon: Icons.receipt,
                          color: Colors.purple,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActionButton(
                          title: 'My Profile',
                          icon: Icons.person,
                          color: AppColors.primaryGreen,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ProfileScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Recent Requests
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent Emergency Requests',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (_recentRequests.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: Text('No pending requests')),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _recentRequests.length > 3 ? 3 : _recentRequests.length,
                            itemBuilder: (context, index) {
                              final request = _recentRequests[index];
                              final data = request.data() as Map<String, dynamic>;
                              return _buildRecentRequestCard(data);
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 5),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: AppColors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 5),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentRequestCard(Map<String, dynamic> request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.veryLightGreen,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.emergency, color: AppColors.darkRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request['patientName'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
                Text(
                  _formatTime(request['timestamp']),
                  style: TextStyle(fontSize: 10, color: AppColors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              request['status'] ?? 'pending',
              style: TextStyle(fontSize: 9, color: Colors.orange.shade700),
            ),
          ),
        ],
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