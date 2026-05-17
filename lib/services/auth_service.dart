import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Register new user
  Future<UserModel?> registerWithEmail({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    try {
      // Create user in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create user document in Firestore
      UserModel newUser = UserModel(
        uid: userCredential.user!.uid,
        fullName: fullName,
        email: email,
        phone: phone,
        role: role,
        createdAt: DateTime.now(),
        isActive: true,
      );
      
      await _firestore.collection('users').doc(userCredential.user!.uid).set(newUser.toMap());
      
      return newUser;
    } catch (e) {
      print('Registration error: $e');
      return null;
    }
  }
  
  // Login user
  Future<UserModel?> loginWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Get user data from Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();
      
      if (userDoc.exists) {
        return UserModel.fromMap(userCredential.user!.uid, userDoc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }
  
  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }
  
  // Get current user data from Firestore
  Future<UserModel?> getCurrentUserData() async {
    User? user = _auth.currentUser;
    if (user == null) return null;
    
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      return UserModel.fromMap(user.uid, userDoc.data() as Map<String, dynamic>);
    }
    return null;
  }
  
  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }
  
  // Check if user is logged in
  Stream<User?> get userStream {
    return _auth.authStateChanges();
  }
}