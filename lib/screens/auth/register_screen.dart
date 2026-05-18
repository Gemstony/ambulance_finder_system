import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';
import '../../utils/colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);
  
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  String _selectedRole = 'patient';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  Future<void> _handleRegister() async {
    if (_fullNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }
    
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.register(
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      role: _selectedRole,
    );
    
    setState(() => _isLoading = false);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_selectedRole registered successfully!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration failed. Try again.')),
      );
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.primaryGreen),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 16),
              Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign up to get emergency help',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.darkGrey,
                ),
              ),
              const SizedBox(height: 32),
              CustomTextField(
                controller: _fullNameController,
                label: 'Full Name',
                hint: 'Enter your full name',
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'Enter your email',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _phoneController,
                label: 'Phone Number',
                hint: 'Enter your phone number',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Enter your password',
                prefixIcon: Icons.lock_outline,
                suffixIcon: _obscurePassword ? Icons.visibility_off : Icons.visibility,
                onSuffixTap: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                hint: 'Confirm your password',
                prefixIcon: Icons.lock_outline,
                suffixIcon: _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                onSuffixTap: () {
                  setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                },
                obscureText: _obscureConfirmPassword,
              ),
              const SizedBox(height: 16),
              Text(
                'Register as:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkGrey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile(
                      title: const Text('Patient'),
                      value: 'patient',
                      groupValue: _selectedRole,
                      onChanged: (value) {
                        setState(() => _selectedRole = value.toString());
                      },
                      activeColor: AppColors.primaryGreen,
                      tileColor: _selectedRole == 'patient' 
                          ? AppColors.veryLightGreen 
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile(
                      title: const Text('Driver'),
                      value: 'driver',
                      groupValue: _selectedRole,
                      onChanged: (value) {
                        setState(() => _selectedRole = value.toString());
                      },
                      activeColor: AppColors.primaryGreen,
                      tileColor: _selectedRole == 'driver' 
                          ? AppColors.veryLightGreen 
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Register',
                onPressed: _handleRegister,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: TextStyle(color: AppColors.darkGrey),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'Login',
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}