import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../utils/colors.dart';

class ManageUsers extends StatefulWidget {
  const ManageUsers({super.key});

  @override
  State<ManageUsers> createState() => _ManageUsersState();
}

class _ManageUsersState extends State<ManageUsers> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String _searchQuery = '';
  String _filterRole = 'all';
  String? _currentAdminId;
  String? _currentAdminRole;
  
  final List<String> _roles = ['all', 'patient', 'driver', 'admin'];

  @override
  void initState() {
    super.initState();
    _getCurrentAdminInfo();
  }

  Future<void> _getCurrentAdminInfo() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      setState(() {
        _currentAdminId = currentUser.uid;
      });
      
      // Get current admin role
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _currentAdminRole = doc.data()?['role'];
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5),
                ],
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.primaryGreen),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ),
          
          // Role Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _roles.map((role) {
                final isSelected = _filterRole == role;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(role.toUpperCase()),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _filterRole = role),
                      backgroundColor: Colors.white,
                      selectedColor: AppColors.primaryGreen,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.darkGrey,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Users List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.getAllUsers(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No users found'));
                }
                
                var users = snapshot.data!.docs;
                
                // Apply filters
                if (_filterRole != 'all') {
                  users = users.where((doc) => doc['role'] == _filterRole).toList();
                }
                
                if (_searchQuery.isNotEmpty) {
                  users = users.where((doc) {
                    final name = doc['fullName']?.toString().toLowerCase() ?? '';
                    final email = doc['email']?.toString().toLowerCase() ?? '';
                    return name.contains(_searchQuery) || email.contains(_searchQuery);
                  }).toList();
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isCurrentAdmin = user.id == _currentAdminId;
                    return _buildUserCard(user, isCurrentAdmin);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(QueryDocumentSnapshot user, bool isCurrentAdmin) {
    final userData = user.data() as Map<String, dynamic>;
    final role = userData['role'] ?? 'patient';
    
    Color roleColor;
    switch (role) {
      case 'admin': roleColor = Colors.red;
      case 'driver': roleColor = Colors.blue;
      default: roleColor = AppColors.primaryGreen;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrentAdmin ? AppColors.veryLightGreen : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5),
        ],
        border: isCurrentAdmin ? Border.all(color: AppColors.primaryGreen, width: 1) : null,
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withOpacity(0.1),
          child: Text(
            userData['fullName']?.substring(0, 1).toUpperCase() ?? 'U',
            style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Text(
              userData['fullName'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (isCurrentAdmin) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'YOU',
                  style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(userData['email'] ?? 'No email'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                role.toUpperCase(),
                style: TextStyle(fontSize: 10, color: roleColor),
              ),
            ),
          ],
        ),
        trailing: isCurrentAdmin
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Current Admin',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showUserOptionsDialog(user.id, userData),
              ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(Icons.phone, 'Phone', userData['phone'] ?? 'Not provided'),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.calendar_today, 'Joined', _formatDate(userData['createdAt'])),
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.toggle_on,
                  'Status',
                  userData['isActive'] == true ? 'Active' : 'Inactive',
                  color: userData['isActive'] == true ? Colors.green : Colors.red,
                ),
                if (role == 'driver') ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.airport_shuttle, 'Vehicle', userData['vehicleNumber'] ?? 'Not assigned'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.grey),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.grey)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 12, color: color ?? AppColors.darkGrey),
          ),
        ),
      ],
    );
  }

  void _showUserOptionsDialog(String userId, Map<String, dynamic> userData) {
    final isActive = userData['isActive'] ?? true;
    final currentRole = userData['role'] ?? 'patient';
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Activate/Deactivate Option
            ListTile(
              leading: Icon(
                isActive ? Icons.block : Icons.check_circle,
                color: isActive ? Colors.red : Colors.green,
              ),
              title: Text(isActive ? 'Deactivate User' : 'Activate User'),
              subtitle: Text(
                isActive ? 'User will not be able to login' : 'User will regain access',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await _firestoreService.updateUserStatus(userId, !isActive);
                  _showSnackBar(
                    'User ${userData['fullName']} ${!isActive ? 'deactivated' : 'activated'} successfully!'
                  );
                  setState(() {});
                } catch (e) {
                  _showSnackBar('Failed to update user status: ${e.toString()}', isError: true);
                }
              },
            ),
            
            const Divider(),
            
            // Change Role Option - With full role selection
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: Colors.blue),
              title: const Text('Change Role'),
              subtitle: Text('Current role: ${currentRole.toUpperCase()}'),
              onTap: () {
                Navigator.pop(context);
                _showRoleSelectionDialog(userId, currentRole);
              },
            ),
            
            const Divider(),
            
            // Delete User Option
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete User', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Permanently remove user', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmDialog(userId, userData['fullName'] ?? 'this user');
              },
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Role Selection Dialog with all 3 options
  void _showRoleSelectionDialog(String userId, String currentRole) {
    String? selectedRole = currentRole;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Change User Role'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select new role for this user:'),
                const SizedBox(height: 16),
                // Radio buttons for each role
                RadioListTile<String>(
                  title: const Text('👤 Patient', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('Can request ambulances only'),
                  value: 'patient',
                  groupValue: selectedRole,
                  onChanged: (value) => setStateDialog(() => selectedRole = value),
                  activeColor: AppColors.primaryGreen,
                  tileColor: selectedRole == 'patient' ? AppColors.veryLightGreen : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                RadioListTile<String>(
                  title: const Text('🚑 Driver', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('Can accept and respond to emergencies'),
                  value: 'driver',
                  groupValue: selectedRole,
                  onChanged: (value) => setStateDialog(() => selectedRole = value),
                  activeColor: Colors.blue,
                  tileColor: selectedRole == 'driver' ? Colors.blue.shade50 : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                RadioListTile<String>(
                  title: const Text('👑 Admin', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('Full system access - manage all users'),
                  value: 'admin',
                  groupValue: selectedRole,
                  onChanged: (value) => setStateDialog(() => selectedRole = value),
                  activeColor: Colors.red,
                  tileColor: selectedRole == 'admin' ? Colors.red.shade50 : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedRole == currentRole) {
                    Navigator.pop(context);
                    _showSnackBar('No changes made - role is already $currentRole');
                    return;
                  }
                  
                  Navigator.pop(context);
                  
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .update({'role': selectedRole});
                    
                    _showSnackBar('Role changed from $currentRole to $selectedRole successfully!');
                    setState(() {});
                  } catch (e) {
                    _showSnackBar('Failed to change role: ${e.toString()}', isError: true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm Change'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete "$userName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );
              
              try {
                // Delete user document from Firestore
                await FirebaseFirestore.instance.collection('users').doc(userId).delete();
                
                // Close loading dialog
                Navigator.pop(context);
                
                _showSnackBar('User "$userName" deleted successfully!');
                setState(() {});
              } catch (e) {
                // Close loading dialog
                Navigator.pop(context);
                _showSnackBar('Failed to delete user: ${e.toString()}', isError: true);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'Unknown';
  }
}