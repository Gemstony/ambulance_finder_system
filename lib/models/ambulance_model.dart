import 'package:cloud_firestore/cloud_firestore.dart';
import 'request_model.dart' hide GeoPoint;

class AmbulanceModel {
  // Basic information
  final String ambulanceId;
  final String registrationNumber;
  final String driverId;
  final String driverName;
  final String driverPhone;
  
  // Ambulance details
  final String type; // 'basic', 'advanced', 'icu', 'mobile_icu'
  final String model;
  final String year;
  final String color;
  
  // Status
  final String status; // 'available', 'on_route', 'on_scene', 'returning', 'offline', 'maintenance'
  final bool isActive;
  
  // Location
  final GeoPoint? currentLocation;
  final DateTime? lastLocationUpdate;
  
  // Equipment
  final List<String>? equipment; // ['oxygen', 'defibrillator', 'stretcher', etc.]
  final bool hasOxygen;
  final bool hasDefibrillator;
  final bool hasVentilator;
  final bool hasMonitor;
  
  // Capacity
  final int maxPatients;
  final int currentPatients;
  
  // Hospital assignment
  final String? baseHospitalId;
  final String? baseHospitalName;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime? lastMaintenanceDate;
  final DateTime? nextMaintenanceDate;
  
  // Metrics
  final int totalTrips;
  final double averageResponseTime; // in minutes
  
  // Constructor
  AmbulanceModel({
    required this.ambulanceId,
    required this.registrationNumber,
    required this.driverId,
    required this.driverName,
    required this.driverPhone,
    required this.type,
    required this.model,
    required this.year,
    this.color = 'White',
    required this.status,
    this.isActive = true,
    this.currentLocation,
    this.lastLocationUpdate,
    this.equipment,
    this.hasOxygen = true,
    this.hasDefibrillator = true,
    this.hasVentilator = false,
    this.hasMonitor = true,
    this.maxPatients = 2,
    this.currentPatients = 0,
    this.baseHospitalId,
    this.baseHospitalName,
    required this.createdAt,
    this.lastMaintenanceDate,
    this.nextMaintenanceDate,
    this.totalTrips = 0,
    this.averageResponseTime = 0.0,
  });
  
  // ============================================================
  // CONVERT AMBULANCE MODEL TO MAP (for Firestore)
  // ============================================================
  Map<String, dynamic> toMap() {
    return {
      'ambulanceId': ambulanceId,
      'registrationNumber': registrationNumber,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'type': type,
      'model': model,
      'year': year,
      'color': color,
      'status': status,
      'isActive': isActive,
      'currentLocation': currentLocation != null 
          ? {
              'latitude': currentLocation!.latitude,
              'longitude': currentLocation!.longitude,
            }
          : null,
      'lastLocationUpdate': lastLocationUpdate,
      'equipment': equipment,
      'hasOxygen': hasOxygen,
      'hasDefibrillator': hasDefibrillator,
      'hasVentilator': hasVentilator,
      'hasMonitor': hasMonitor,
      'maxPatients': maxPatients,
      'currentPatients': currentPatients,
      'baseHospitalId': baseHospitalId,
      'baseHospitalName': baseHospitalName,
      'createdAt': createdAt,
      'lastMaintenanceDate': lastMaintenanceDate,
      'nextMaintenanceDate': nextMaintenanceDate,
      'totalTrips': totalTrips,
      'averageResponseTime': averageResponseTime,
    };
  }
  
  // ============================================================
  // CREATE AMBULANCE MODEL FROM MAP (from Firestore)
  // ============================================================
  factory AmbulanceModel.fromMap(String id, Map<String, dynamic> data) {
    // Get current location
    GeoPoint? location;
    if (data['currentLocation'] != null) {
      if (data['currentLocation'] is GeoPoint) {
        location = GeoPoint(
          (data['currentLocation'] as GeoPoint).latitude,
          (data['currentLocation'] as GeoPoint).longitude,
        );
      } else if (data['currentLocation'] is Map) {
        location = GeoPoint(
          data['currentLocation']['latitude'] ?? 0.0,
          data['currentLocation']['longitude'] ?? 0.0,
        );
      }
    }
    
    return AmbulanceModel(
      ambulanceId: id,
      registrationNumber: data['registrationNumber'] ?? '',
      driverId: data['driverId'] ?? '',
      driverName: data['driverName'] ?? '',
      driverPhone: data['driverPhone'] ?? '',
      type: data['type'] ?? 'basic',
      model: data['model'] ?? '',
      year: data['year'] ?? '',
      color: data['color'] ?? 'White',
      status: data['status'] ?? 'offline',
      isActive: data['isActive'] ?? true,
      currentLocation: location,
      lastLocationUpdate: _parseTimestamp(data['lastLocationUpdate']),
      equipment: data['equipment'] != null 
          ? List<String>.from(data['equipment']) 
          : null,
      hasOxygen: data['hasOxygen'] ?? true,
      hasDefibrillator: data['hasDefibrillator'] ?? true,
      hasVentilator: data['hasVentilator'] ?? false,
      hasMonitor: data['hasMonitor'] ?? true,
      maxPatients: data['maxPatients'] ?? 2,
      currentPatients: data['currentPatients'] ?? 0,
      baseHospitalId: data['baseHospitalId'],
      baseHospitalName: data['baseHospitalName'],
      createdAt: _parseTimestamp(data['createdAt']),
      lastMaintenanceDate: _parseTimestamp(data['lastMaintenanceDate']),
      nextMaintenanceDate: _parseTimestamp(data['nextMaintenanceDate']),
      totalTrips: data['totalTrips'] ?? 0,
      averageResponseTime: (data['averageResponseTime'] ?? 0.0).toDouble(),
    );
  }
  
  // Helper to parse timestamps
  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is Timestamp) return timestamp.toDate();
    return DateTime.now();
  }
  
  // ============================================================
  // HELPER METHODS
  // ============================================================
  
  // Status check methods
  bool get isAvailable => status == 'available' && isActive && currentPatients < maxPatients;
  bool get isOnRoute => status == 'on_route';
  bool get isOnScene => status == 'on_scene';
  bool get isReturning => status == 'returning';
  bool get isOffline => status == 'offline';
  bool get needsMaintenance => status == 'maintenance';
  
  // Get status display text
  String get statusText {
    switch (status) {
      case 'available': return 'Available';
      case 'on_route': return 'On Route';
      case 'on_scene': return 'On Scene';
      case 'returning': return 'Returning';
      case 'offline': return 'Offline';
      case 'maintenance': return 'Maintenance';
      default: return status;
    }
  }
  
  // Get status color (for UI)
  String get statusColor {
    switch (status) {
      case 'available': return 'green';
      case 'on_route': return 'blue';
      case 'on_scene': return 'orange';
      case 'returning': return 'cyan';
      case 'offline': return 'grey';
      case 'maintenance': return 'red';
      default: return 'grey';
    }
  }
  
  // Get ambulance type display
  String get typeText {
    switch (type) {
      case 'basic': return 'Basic Life Support (BLS)';
      case 'advanced': return 'Advanced Life Support (ALS)';
      case 'icu': return 'Mobile ICU';
      case 'mobile_icu': return 'Mobile ICU Unit';
      default: return type;
    }
  }
  
  // Get equipment list as string
  String get equipmentList {
    List<String> items = [];
    if (hasOxygen) items.add('Oxygen');
    if (hasDefibrillator) items.add('Defibrillator');
    if (hasVentilator) items.add('Ventilator');
    if (hasMonitor) items.add('Patient Monitor');
    if (equipment != null) items.addAll(equipment!);
    return items.join(', ');
  }
  
  // Check if ambulance has capacity
  bool get hasCapacity => currentPatients < maxPatients;
  
  // Get available capacity
  int get availableCapacity => maxPatients - currentPatients;
  
  // Get ambulance icon based on type
  String get ambulanceIcon {
    switch (type) {
      case 'basic': return '🚑';
      case 'advanced': return '🚨';
      case 'icu': return '🏥';
      default: return '🚑';
    }
  }
  
  // Calculate if maintenance is due
  bool get isMaintenanceDue {
    if (nextMaintenanceDate == null) return false;
    return nextMaintenanceDate!.isBefore(DateTime.now());
  }
  
  // Copy with (for updating)
  AmbulanceModel copyWith({
    String? status,
    GeoPoint? currentLocation,
    int? currentPatients,
    int? totalTrips,
    double? averageResponseTime,
    DateTime? lastLocationUpdate,
    DateTime? lastMaintenanceDate,
    DateTime? nextMaintenanceDate,
  }) {
    return AmbulanceModel(
      ambulanceId: ambulanceId,
      registrationNumber: registrationNumber,
      driverId: driverId,
      driverName: driverName,
      driverPhone: driverPhone,
      type: type,
      model: model,
      year: year,
      color: color,
      status: status ?? this.status,
      isActive: isActive,
      currentLocation: currentLocation ?? this.currentLocation,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      equipment: equipment,
      hasOxygen: hasOxygen,
      hasDefibrillator: hasDefibrillator,
      hasVentilator: hasVentilator,
      hasMonitor: hasMonitor,
      maxPatients: maxPatients,
      currentPatients: currentPatients ?? this.currentPatients,
      baseHospitalId: baseHospitalId,
      baseHospitalName: baseHospitalName,
      createdAt: createdAt,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
      nextMaintenanceDate: nextMaintenanceDate ?? this.nextMaintenanceDate,
      totalTrips: totalTrips ?? this.totalTrips,
      averageResponseTime: averageResponseTime ?? this.averageResponseTime,
    );
  }
}