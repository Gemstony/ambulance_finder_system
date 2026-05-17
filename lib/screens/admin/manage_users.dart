import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../utils/colors.dart';

class ManageUsers extends StatefulWidget {
  const ManageUsers({Key? key}) : super(key: key);

  @override
  State<ManageUsers> createState() => _ManageUsersState();
}

class _ManageUsersState extends State<ManageUsers> {
  final FirestoreService _firestoreService = FirestoreService();
  String _searchQuery = '';
  String _filterRole = 'all';
  
  final List<String> _roles = ['all', 'patient', 'driver', 'admin'];

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
                    return _buildUserCard(user);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(QueryDocumentSnapshot user) {
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5),
        ],
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withOpacity(0.1),
          child: Text(
            userData['fullName']?.substring(0, 1).toUpperCase() ?? 'U',
            style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          userData['fullName'] ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.bold),
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
        trailing: IconButton(
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                userData['isActive'] == true ? Icons.block : Icons.check_circle,
                color: userData['isActive'] == true ? Colors.red : Colors.green,
              ),
              title: Text(userData['isActive'] == true ? 'Deactivate User' : 'Activate User'),
              onTap: () async {
                Navigator.pop(context);
                await _firestoreService.updateUserStatus(userId, !(userData['isActive'] ?? true));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('User ${userData['isActive'] == true ? 'deactivated' : 'activated'}')),
                );
                setState(() {});
              },
            ),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: Colors.blue),
              title: const Text('Change Role'),
              onTap: () => _showChangeRoleDialog(userId, userData['role']),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete User', style: TextStyle(color: Colors.red)),
              onTap: () => _showDeleteConfirmDialog(userId),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeRoleDialog(String userId, String currentRole) {
    final newRole = currentRole == 'patient' ? 'driver' : currentRole == 'driver' ? 'admin' : 'patient';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change User Role'),
        content: Text('Change role from $currentRole to $newRole?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance.collection('users').doc(userId).update({'role': newRole});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Role changed to $newRole')),
              );
              setState(() {});
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance.collection('users').doc(userId).delete();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User deleted')),
              );
              setState(() {});
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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