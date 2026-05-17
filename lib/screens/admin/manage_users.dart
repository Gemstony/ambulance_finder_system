import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../utils/colors.dart';

class ManageUsers extends StatefulWidget {
  const ManageUsers({Key? key}) : super(key: key);

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

  // ============================================================
  // NEW: SHOW ADD USER DIALOG
  // ============================================================
  void _showAddUserDialog() {
    final TextEditingController fullNameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    
    String selectedRole = 'patient';
    bool isLoading = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.person_add, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                const Text('Add New User'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Full Name Field
                  TextField(
                    controller: fullNameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter full name',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Email Field
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter email address',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Phone Field
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'Enter phone number',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Password Field
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter password (min 6 characters)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Role Selection
                  const Text(
                    'Select Role:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildRoleRadio(
                          title: 'Patient',
                          icon: Icons.person,
                          role: 'patient',
                          selectedRole: selectedRole,
                          color: AppColors.primaryGreen,
                          onChanged: (value) {
                            setStateDialog(() => selectedRole = value!);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildRoleRadio(
                          title: 'Driver',
                          icon: Icons.airport_shuttle,
                          role: 'driver',
                          selectedRole: selectedRole,
                          color: Colors.blue,
                          onChanged: (value) {
                            setStateDialog(() => selectedRole = value!);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildRoleRadio(
                          title: 'Admin',
                          icon: Icons.admin_panel_settings,
                          role: 'admin',
                          selectedRole: selectedRole,
                          color: Colors.red,
                          onChanged: (value) {
                            setStateDialog(() => selectedRole = value!);
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Validation
                  if (fullNameController.text.trim().isEmpty) {
                    _showSnackBar('Please enter full name', isError: true);
                    return;
                  }
                  if (emailController.text.trim().isEmpty) {
                    _showSnackBar('Please enter email', isError: true);
                    return;
                  }
                  if (phoneController.text.trim().isEmpty) {
                    _showSnackBar('Please enter phone number', isError: true);
                    return;
                  }
                  if (passwordController.text.length < 6) {
                    _showSnackBar('Password must be at least 6 characters', isError: true);
                    return;
                  }
                  
                  setStateDialog(() => isLoading = true);
                  
                  try {
                    // 1. Create user in Firebase Auth
                    final userCredential = await _auth.createUserWithEmailAndPassword(
                      email: emailController.text.trim(),
                      password: passwordController.text,
                    );
                    
                    // 2. Create user document in Firestore
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userCredential.user!.uid)
                        .set({
                      'uid': userCredential.user!.uid,
                      'fullName': fullNameController.text.trim(),
                      'email': emailController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'role': selectedRole,
                      'isActive': true,
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    
                    setStateDialog(() => isLoading = false);
                    Navigator.pop(dialogContext);
                    
                    _showSnackBar(
                      '${selectedRole.toUpperCase()} "${fullNameController.text.trim()}" added successfully!'
                    );
                    setState(() {});
                    
                  } catch (e) {
                    setStateDialog(() => isLoading = false);
                    
                    // Check if email already exists
                    if (e.toString().contains('email-already-in-use')) {
                      _showSnackBar('Email already exists!', isError: true);
                    } else {
                      _showSnackBar('Failed to add user: ${e.toString()}', isError: true);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add User'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildRoleRadio({
    required String title,
    required IconData icon,
    required String role,
    required String selectedRole,
    required Color color,
    required Function(String?) onChanged,
  }) {
    final isSelected = selectedRole == role;
    return GestureDetector(
      onTap: () => onChanged(role),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
      ),
      // ============================================================
      // NEW: FLOATING ACTION BUTTON
      // ============================================================
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
        elevation: 4,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );
              
              try {
                await FirebaseFirestore.instance.collection('users').doc(userId).delete();
                Navigator.pop(context);
                _showSnackBar('User "$userName" deleted successfully!');
                setState(() {});
              } catch (e) {
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