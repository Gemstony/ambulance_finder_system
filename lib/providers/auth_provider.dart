import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  // Service instance
  final AuthService _authService = AuthService();
  
  // State variables
  UserModel? _currentUserData;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Getters
  UserModel? get currentUserData => _currentUserData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // Get current Firebase user (basic auth user)
  User? get currentUser => _authService.getCurrentUser();
  
  // Check if user is logged in
  bool get isLoggedIn => _authService.getCurrentUser() != null;
  
  // Get user role
  String? get userRole => _currentUserData?.role;
  
  // ============================================================
  // LOGIN FUNCTION
  // ============================================================
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;
    
    try {
      final userData = await _authService.loginWithEmail(email, password);
      
      if (userData != null) {
        _currentUserData = userData;
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Invalid email or password';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'Login failed: ${e.toString()}';
      _setLoading(false);
      return false;
    }
  }
  
  // ============================================================
  // REGISTER FUNCTION
  // ============================================================
  Future<bool> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    
    try {
      final userData = await _authService.registerWithEmail(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
        role: role,
      );
      
      _setLoading(false);
      
      if (userData != null) {
        return true;
      } else {
        _errorMessage = 'Registration failed. Email might already exist.';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Registration failed: ${e.toString()}';
      _setLoading(false);
      return false;
    }
  }
  
  // ============================================================
  // GET CURRENT USER DATA FROM FIRESTORE
  // ============================================================
  Future<UserModel?> getCurrentUserData() async {
    _setLoading(true);
    
    try {
      _currentUserData = await _authService.getCurrentUserData();
      _setLoading(false);
      notifyListeners();
      return _currentUserData;
    } catch (e) {
      _errorMessage = 'Failed to get user data: ${e.toString()}';
      _setLoading(false);
      return null;
    }
  }
  
  // ============================================================
  // REFRESH USER DATA
  // ============================================================
  Future<void> refreshUserData() async {
    await getCurrentUserData();
  }
  
  // ============================================================
  // UPDATE USER PROFILE
  // ============================================================
  Future<bool> updateUserProfile({
    String? fullName,
    String? phone,
    String? profileImage,
  }) async {
    _setLoading(true);
    
    try {
      // This would need a method in auth_service
      // For now, just return true
      _setLoading(false);
      await refreshUserData();
      return true;
    } catch (e) {
      _errorMessage = 'Update failed: ${e.toString()}';
      _setLoading(false);
      return false;
    }
  }
  
  // ============================================================
  // LOGOUT FUNCTION
  // ============================================================
  Future<void> logout() async {
    _setLoading(true);
    
    try {
      await _authService.logout();
      _currentUserData = null;
      _errorMessage = null;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Logout failed: ${e.toString()}';
      _setLoading(false);
    }
  }
  
  // ============================================================
  // CLEAR ERROR
  // ============================================================
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  // ============================================================
  // PRIVATE HELPER METHODS
  // ============================================================
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}