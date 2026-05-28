import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/request_provider.dart';
import '../../widgets/custom_button.dart';
import '../../utils/colors.dart';
import 'request_ambulance.dart';
import 'tracking_screen.dart';
import '../common/profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class PatientHome extends StatefulWidget {
  const PatientHome({super.key});

  @override
  State<PatientHome> createState() => _PatientHomeState();
}

class _PatientHomeState extends State<PatientHome> {
  bool _hasActiveRequest = false;

  // patient_home.dart – add inside _PatientHomeState

  String _currentRequestStatus = '';
  String _currentDriverName = '';
  String _currentDriverPhone = '';

  @override
  void initState() {
    super.initState();
    _getLocation();
    _checkActiveRequest();
    _listenToUserRequests();
  }

  void _listenToUserRequests() {
    final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final requestProvider = Provider.of<RequestProvider>(
      context,
      listen: false,
    );
    requestProvider.listenToUserRequests(userId, 'patient');
    requestProvider.addListener(_onRequestChanged);
  }

  void _onRequestChanged() {
    final requestProvider = Provider.of<RequestProvider>(
      context,
      listen: false,
    );
    final active = requestProvider.activeRequest;

    setState(() {
      if (active != null) {
        _currentRequestStatus = active.status;
        _currentDriverName = active.driverName ?? '';
        _currentDriverPhone = active.driverPhone ?? '';
      } else {
        _currentRequestStatus = '';
        _currentDriverName = '';
        _currentDriverPhone = '';
      }
    });
  }

  @override
  void dispose() {
    final requestProvider = Provider.of<RequestProvider>(
      context,
      listen: false,
    );
    requestProvider.removeListener(_onRequestChanged);
    super.dispose();
  }

  Future<void> _getLocation() async {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    await locationProvider.getCurrentLocation();
  }

  void _checkActiveRequest() {
    final requestProvider = Provider.of<RequestProvider>(
      context,
      listen: false,
    );
    // Check if user has active request
    FirebaseFirestore.instance
        .collection('requests')
        .where(
          'patientId',
          isEqualTo: firebase_auth.FirebaseAuth.instance.currentUser?.uid,
        )
        .where('status', whereIn: ['pending', 'accepted', 'enroute', 'arrived'])
        .snapshots()
        .listen((snapshot) {
          setState(() {
            _hasActiveRequest = snapshot.docs.isNotEmpty;
          });
        });
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
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'accepted':
        return Icons.check_circle;
      case 'enroute':
        return Icons.directions_car;
      case 'arrived':
        return Icons.location_on;
      default:
        return Icons.info;
    }
  }

  String _getStatusMessage(String status, String driverName) {
    switch (status) {
      case 'pending':
        return '🕒 Your request is pending. Waiting for a driver...';
      case 'accepted':
        return '✅ Request accepted! Driver $_currentDriverName is on the way.';
      case 'enroute':
        return '🚑 Ambulance is en route to your location.';
      case 'arrived':
        return '📍 Ambulance has arrived. Please board.';
      default:
        return 'Active request status: $status';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final locationProvider = Provider.of<LocationProvider>(context);
    final userData = authProvider.currentUserData;

    return Scaffold(
      drawer: _buildDrawer(context, authProvider, userData),
      appBar: AppBar(
        title: const Text('Ambulance Finder'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications')),
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Welcome Card - Modern Design
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.health_and_safety,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${userData?.fullName.split(' ').first ?? 'Patient'}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  locationProvider.hasLocation
                                      ? locationProvider.currentAddress
                                      : 'Getting your location...',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        color: AppColors.primaryGreen,
                        onPressed: _getLocation,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),

              // Active Request Banner
              // After the welcome card, before the emergency button

              // Status Card – shows current request info
              if (_currentRequestStatus.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_currentRequestStatus),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getStatusIcon(_currentRequestStatus),
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getStatusMessage(
                                _currentRequestStatus,
                                _currentDriverName,
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_currentRequestStatus == 'accepted' &&
                          _currentDriverName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Driver: $_currentDriverName  |  Phone: $_currentDriverPhone',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TrackingScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _getStatusColor(
                            _currentRequestStatus,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Track Ambulance'),
                      ),
                    ],
                  ),
                ),

              // Emergency Button - Modern
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.darkRed.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CustomButton(
                    text: '🚑 REQUEST AMBULANCE NOW',
                    onPressed: () {
                      if (locationProvider.hasLocation) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RequestAmbulance(),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please wait, getting your location...',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                    isEmergency: true,
                    height: 60,
                  ),
                ),
              ),

              // Features Grid - Modern
              Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.1,
                  children: [
                    _buildModernFeatureCard(
                      icon: Icons.track_changes,
                      title: 'Track Ambulance',
                      subtitle: 'Live location',
                      color: AppColors.primaryGreen,
                      gradient: const [Color(0xFF4CAF50), Color(0xFF81C784)],
                      onTap: () {
                        if (_hasActiveRequest) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TrackingScreen(),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No active ambulance request'),
                            ),
                          );
                        }
                      },
                    ),
                    _buildModernFeatureCard(
                      icon: Icons.history,
                      title: 'Request History',
                      subtitle: 'Past emergencies',
                      color: Colors.orange,
                      gradient: const [Color(0xFFFF9800), Color(0xFFFFB74D)],
                      onTap: () {
                        _showRequestHistoryDialog(context);
                      },
                    ),
                    _buildModernFeatureCard(
                      icon: Icons.emergency,
                      title: 'First Aid Tips',
                      subtitle: 'Emergency guide',
                      color: AppColors.darkRed,
                      gradient: const [Color(0xFFE53935), Color(0xFFEF9A9A)],
                      onTap: () => _showFirstAidDialog(),
                    ),
                    _buildModernFeatureCard(
                      icon: Icons.support_agent,
                      title: 'Help & Support',
                      subtitle: '24/7 assistance',
                      color: Colors.purple,
                      gradient: const [Color(0xFF9C27B0), Color(0xFFCE93D8)],
                      onTap: () => _showSupportDialog(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    AuthProvider authProvider,
    userData,
  ) {
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
                      userData?.initials ?? 'P',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userData?.fullName ?? 'Patient',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
              leading: const Icon(Icons.history),
              title: const Text('Request History'),
              onTap: () {
                Navigator.pop(context);
                _showRequestHistoryDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help & Support'),
              onTap: () {
                Navigator.pop(context);
                _showSupportDialog();
              },
            ),
            const Divider(),
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

  void _showRequestHistoryDialog(BuildContext context) {
    final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Request History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('requests')
                    .where('patientId', isEqualTo: userId)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No requests found'));
                  }

                  final requests = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      final data = request.data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: data['status'] == 'completed'
                                ? Colors.green
                                : data['status'] == 'pending'
                                ? Colors.orange
                                : Colors.blue,
                            child: Icon(
                              data['status'] == 'completed'
                                  ? Icons.check
                                  : data['status'] == 'pending'
                                  ? Icons.pending
                                  : Icons.local_hospital,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            data['status']?.toUpperCase() ?? 'UNKNOWN',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: data['status'] == 'completed'
                                  ? Colors.green
                                  : data['status'] == 'pending'
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                          ),
                          subtitle: Text(
                            'Requested: ${_formatDate(data['timestamp'])}',
                          ),
                          trailing: data['status'] == 'completed' ||
                              data['status'] == 'cancelled'
                              ? null
                              : TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TrackingScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text('Track'),
                                ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.support_agent, color: AppColors.primaryGreen),
            SizedBox(width: 8),
            Text('Help & Support'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📞 Emergency Numbers:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• 115 - Ambulance Service'),
            const Text('• 118 - Health Helpline'),
            const SizedBox(height: 16),
            const Text(
              '💬 Need Assistance?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Email: support@ambulancefinder.com'),
            const Text('Phone: +255 682 961 155'),
            const SizedBox(height: 16),
            const Text(
              '📱 App Support Hours:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Monday - Friday: 8:00 AM - 8:00 PM'),
            const Text('Saturday - Sunday: 9:00 AM - 5:00 PM'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);

              final Uri phoneUri = Uri(scheme: 'tel', path: '+255682961155');

              if (await canLaunchUrl(phoneUri)) {
                await launchUrl(phoneUri);
              } else {
                debugPrint('Could not launch dialer');
              }
            },
            icon: const Icon(Icons.phone),
            label: const Text('Contact Support'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showFirstAidDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('First Aid Tips'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '🚑 Before Ambulance Arrives:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Stay calm and assess the situation'),
              Text('• Don\'t move the person if injured'),
              Text('• Apply pressure to bleeding wounds'),
              Text('• Keep the person warm'),
              SizedBox(height: 12),
              Text(
                '🆘 For Cardiac Emergency:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Call emergency immediately'),
              Text('• Start CPR if trained'),
              Text('• Use AED if available'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'Unknown';
  }
}
