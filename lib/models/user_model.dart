import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  // Basic information
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String role; // 'patient', 'driver', 'admin'
  
  // Optional fields
  final String? profileImage;
  final String? ambulanceId; // Only for drivers
  final String? hospitalId; // For drivers assigned to specific hospital
  
  // Status fields
  final bool isActive;
  final bool isOnline; // For drivers - toggle online/offline
  
  // Timestamps
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final DateTime? updatedAt;
  
  // Driver specific
  final String? vehicleNumber;
  final String? vehicleType; // 'basic', 'advanced', 'icu'
  
  // Patient specific
  final String? emergencyContact;
  final String? emergencyContactPhone;
  final List<String>? medicalConditions;
  
  // Constructor
  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.profileImage,
    this.ambulanceId,
    this.hospitalId,
    this.isActive = true,
    this.isOnline = false,
    required this.createdAt,
    this.lastLoginAt,
    this.updatedAt,
    this.vehicleNumber,
    this.vehicleType,
    this.emergencyContact,
    this.emergencyContactPhone,
    this.medicalConditions,
  });
  
  // ============================================================
  // CONVERT USER MODEL TO MAP (for Firestore)
  // ============================================================
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'profileImage': profileImage,
      'ambulanceId': ambulanceId,
      'hospitalId': hospitalId,
      'isActive': isActive,
      'isOnline': isOnline,
      'createdAt': createdAt,
      'lastLoginAt': lastLoginAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
      'vehicleNumber': vehicleNumber,
      'vehicleType': vehicleType,
      'emergencyContact': emergencyContact,
      'emergencyContactPhone': emergencyContactPhone,
      'medicalConditions': medicalConditions,
    };
  }
  
  // ============================================================
  // CREATE USER MODEL FROM MAP (from Firestore)
  // ============================================================
  factory UserModel.fromMap(String id, Map<String, dynamic> data) {
    return UserModel(
      uid: id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'patient',
      profileImage: data['profileImage'],
      ambulanceId: data['ambulanceId'],
      hospitalId: data['hospitalId'],
      isActive: data['isActive'] ?? true,
      isOnline: data['isOnline'] ?? false,
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as dynamic)?.toDate(),
      updatedAt: (data['updatedAt'] as dynamic)?.toDate(),
      vehicleNumber: data['vehicleNumber'],
      vehicleType: data['vehicleType'],
      emergencyContact: data['emergencyContact'],
      emergencyContactPhone: data['emergencyContactPhone'],
      medicalConditions: data['medicalConditions'] != null 
          ? List<String>.from(data['medicalConditions']) 
          : null,
    );
  }
  
  // ============================================================
  // HELPER METHODS
  // ============================================================
  
  // Check if user is patient
  bool get isPatient => role == 'patient';
  
  // Check if user is driver
  bool get isDriver => role == 'driver';
  
  // Check if user is admin
  bool get isAdmin => role == 'admin';
  
  // Check if driver is available
  bool get isDriverAvailable => isDriver && isActive && isOnline;
  
  // Get display name
  String get displayName => fullName;
  
  // Get initials for avatar
  String get initials {
    List<String> nameParts = fullName.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (nameParts.isNotEmpty) {
      return nameParts[0][0].toUpperCase();
    }
    return 'U';
  }
  
  // Copy with (for updating)
  UserModel copyWith({
    String? fullName,
    String? phone,
    String? profileImage,
    bool? isActive,
    bool? isOnline,
    String? ambulanceId,
    String? vehicleNumber,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      uid: uid,
      fullName: fullName ?? this.fullName,
      email: email,
      phone: phone ?? this.phone,
      role: role,
      profileImage: profileImage ?? this.profileImage,
      ambulanceId: ambulanceId ?? this.ambulanceId,
      hospitalId: hospitalId,
      isActive: isActive ?? this.isActive,
      isOnline: isOnline ?? this.isOnline,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      updatedAt: DateTime.now(),
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleType: vehicleType,
      emergencyContact: emergencyContact,
      emergencyContactPhone: emergencyContactPhone,
      medicalConditions: medicalConditions,
    );
  }
}