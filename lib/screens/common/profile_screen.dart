import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../providers/auth_provider.dart';
import '../../utils/colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isLoading = false;
  final bool _showPasswordDialog = false;
  
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emergencyContactController;
  late TextEditingController _emergencyPhoneController;
  
  // Password change controllers
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  Map<String, dynamic>? _userData;
  String? _userId;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user != null) {
      _userId = user.uid;
      _userEmail = user.email;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _userData = doc.data();
          _fullNameController = TextEditingController(text: _userData?['fullName'] ?? '');
          _phoneController = TextEditingController(text: _userData?['phone'] ?? '');
          _emergencyContactController = TextEditingController(text: _userData?['emergencyContact'] ?? '');
          _emergencyPhoneController = TextEditingController(text: _userData?['emergencyContactPhone'] ?? '');
        });
      }
    }
  }
  
  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    
    try {
      final updates = {
        'fullName': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (_userData?['role'] == 'patient') {
        updates['emergencyContact'] = _emergencyContactController.text.trim();
        updates['emergencyContactPhone'] = _emergencyPhoneController.text.trim();
      }
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .update(updates);
      
      setState(() {
        _isEditing = false;
        _isLoading = false;
        if (_userData != null) {
          _userData!['fullName'] = _fullNameController.text.trim();
          _userData!['phone'] = _phoneController.text.trim();
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
      );
    }
  }
  
  // ============================================================
  // PASSWORD CHANGE FUNCTIONALITY
  // ============================================================
  void _showChangePasswordDialog() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.lock, color: AppColors.primaryGreen),
                SizedBox(width: 8),
                Text('Change Password'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    hintText: 'Enter your current password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    hintText: 'Enter new password (min 6 characters)',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    hintText: 'Confirm your new password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
                  // Validation
                  if (_currentPasswordController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter current password'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  if (_newPasswordController.text.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('New password must be at least 6 characters'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  if (_newPasswordController.text != _confirmPasswordController.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('New passwords do not match'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  
                  setStateDialog(() => _isLoading = true);
                  
                  try {
                    final auth = FirebaseAuth.instance;
                    final user = auth.currentUser;
                    
                    if (user != null && user.email != null) {
                      // Re-authenticate user with current password
                      final credential = EmailAuthProvider.credential(
                        email: user.email!,
                        password: _currentPasswordController.text,
                      );
                      
                      await user.reauthenticateWithCredential(credential);
                      
                      // Change password
                      await user.updatePassword(_newPasswordController.text);
                      
                      setStateDialog(() => _isLoading = false);
                      Navigator.pop(context);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password changed successfully! Please login again.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      
                      // Logout user after password change
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    }
                  } on FirebaseAuthException catch (e) {
                    setStateDialog(() => _isLoading = false);
                    String errorMessage = 'Failed to change password';
                    if (e.code == 'wrong-password') {
                      errorMessage = 'Current password is incorrect';
                    } else if (e.code == 'weak-password') {
                      errorMessage = 'New password is too weak';
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
                    );
                  } catch (e) {
                    setStateDialog(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Change Password'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile'), backgroundColor: AppColors.primaryGreen),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    final role = _userData?['role'] ?? 'patient';
    final isPatient = role == 'patient';
    final isDriver = role == 'driver';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing)
            TextButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save', style: TextStyle(color: Colors.white)),
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
              // Profile Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primaryGreen, width: 3),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.veryLightGreen,
                        child: Text(
                          _userData?['fullName']?.substring(0, 1).toUpperCase() ?? 'U',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _userData?['fullName'] ?? 'User',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: role == 'admin' ? Colors.red.shade50 : 
                               role == 'driver' ? Colors.blue.shade50 : 
                               AppColors.veryLightGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: role == 'admin' ? Colors.red : 
                                 role == 'driver' ? Colors.blue : 
                                 AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Profile Info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoField(
                      label: 'Full Name',
                      value: _userData?['fullName'] ?? '',
                      icon: Icons.person_outline,
                      isEditing: _isEditing,
                      controller: _fullNameController,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoField(
                      label: 'Email',
                      value: _userData?['email'] ?? '',
                      icon: Icons.email_outlined,
                      isEditing: false,
                      isReadOnly: true,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoField(
                      label: 'Phone Number',
                      value: _userData?['phone'] ?? '',
                      icon: Icons.phone_outlined,
                      isEditing: _isEditing,
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                    
                    if (isPatient) ...[
                      const SizedBox(height: 12),
                      _buildInfoField(
                        label: 'Emergency Contact Name',
                        value: _userData?['emergencyContact'] ?? 'Not set',
                        icon: Icons.emergency,
                        isEditing: _isEditing,
                        controller: _emergencyContactController,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoField(
                        label: 'Emergency Contact Phone',
                        value: _userData?['emergencyContactPhone'] ?? 'Not set',
                        icon: Icons.phone,
                        isEditing: _isEditing,
                        controller: _emergencyPhoneController,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                    
                    const SizedBox(height: 20),
                    
                    // Change Password Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showChangePasswordDialog,
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('Change Password'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: AppColors.primaryGreen),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Driver Stats - NO RATING
                    if (isDriver) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Driver Statistics',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatItem('Total Trips', _userData?['totalTrips']?.toString() ?? '0', Icons.airport_shuttle),
                                ),
                                Expanded(
                                  child: _buildStatItem('Response Time', _userData?['avgResponseTime']?.toString() ?? 'N/A', Icons.timer),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoField({
    required String label,
    required String value,
    required IconData icon,
    required bool isEditing,
    TextEditingController? controller,
    bool isReadOnly = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.veryLightGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.primaryGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: AppColors.grey)),
                const SizedBox(height: 2),
                isEditing
                    ? TextFormField(
                        controller: controller,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        keyboardType: keyboardType,
                        readOnly: isReadOnly,
                      )
                    : Text(
                        value,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryGreen, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}