import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/colors.dart';

class RoleRedirectScreen extends StatefulWidget {
  const RoleRedirectScreen({Key? key}) : super(key: key);

  @override
  State<RoleRedirectScreen> createState() => _RoleRedirectScreenState();
}

class _RoleRedirectScreenState extends State<RoleRedirectScreen> {
  @override
  void initState() {
    super.initState();
    _redirectBasedOnRole();
  }

  Future<void> _redirectBasedOnRole() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Wait for user data to load
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    final userData = authProvider.currentUserData;
    
    if (userData == null) {
      // No user data - go to login
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      // Redirect based on role
      switch (userData.role) {
        case 'patient':
          Navigator.pushReplacementNamed(context, '/patient-home');
          break;
        case 'driver':
          Navigator.pushReplacementNamed(context, '/driver-home');
          break;
        case 'admin':
          Navigator.pushReplacementNamed(context, '/admin-dashboard');
          break;
        default:
          Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.veryLightGreen, AppColors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              ),
              const SizedBox(height: 24),
              Text(
                'Redirecting you...',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.darkGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}