import 'package:cloud_firestore/cloud_firestore.dart';

// GeoPoint class for location coordinates
class GeoPoint {
  final double latitude;
  final double longitude;
  
  GeoPoint(this.latitude, this.longitude);
  
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
  
  factory GeoPoint.fromMap(Map<String, dynamic> data) {
    return GeoPoint(
      data['latitude'] ?? 0.0, 
      data['longitude'] ?? 0.0,
    );
  }
  
  @override
  String toString() => '($latitude, $longitude)';
}

class RequestModel {
  // Request identifiers
  final String requestId;
  final String patientId;
  final String patientName;
  final String patientPhone;
  
  // Location information
  final GeoPoint patientLocation;
  final String? patientAddress;
  
  // Driver information (assigned)
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? ambulanceId;
  final String? ambulanceNumber;
  
  // Request status
  final String status; 
  // Status options:
  // 'pending' - waiting for driver
  // 'accepted' - driver accepted
  // 'enroute' - driver on the way
  // 'arrived' - driver arrived at patient
  // 'patient_loaded' - patient in ambulance
  // 'at_hospital' - arrived at hospital
  // 'completed' - trip complete
  // 'cancelled' - cancelled
  // 'rejected' - rejected by driver
  
  // Emergency details
  final String? emergencyType; // 'accident', 'heart_attack', 'pregnancy', etc.
  final String? severity; // 'low', 'medium', 'high', 'critical'
  final String? notes;
  final String? symptoms;
  
  // Timestamps
  final DateTime timestamp;
  final DateTime? acceptedAt;
  final DateTime? enrouteAt;
  final DateTime? arrivedAt;
  final DateTime? patientLoadedAt;
  final DateTime? atHospitalAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelledReason;
  
  // Rating and feedback
  final double? patientRating; // 1-5 stars
  final String? patientFeedback;
  final double? driverRating;
  final String? driverFeedback;
  
  // Tracking
  final List<Map<String, dynamic>>? locationHistory;
  
  // Constructor
  RequestModel({
    required this.requestId,
    required this.patientId,
    required this.patientName,
    required this.patientPhone,
    required this.patientLocation,
    this.patientAddress,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.ambulanceId,
    this.ambulanceNumber,
    required this.status,
    this.emergencyType,
    this.severity,
    this.notes,
    this.symptoms,
    required this.timestamp,
    this.acceptedAt,
    this.enrouteAt,
    this.arrivedAt,
    this.patientLoadedAt,
    this.atHospitalAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelledReason,
    this.patientRating,
    this.patientFeedback,
    this.driverRating,
    this.driverFeedback,
    this.locationHistory,
  });
  
  // ============================================================
  // CONVERT REQUEST MODEL TO MAP (for Firestore)
  // ============================================================
  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'patientId': patientId,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'patientLocation': {
        'latitude': patientLocation.latitude,
        'longitude': patientLocation.longitude,
      },
      'patientAddress': patientAddress,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'ambulanceId': ambulanceId,
      'ambulanceNumber': ambulanceNumber,
      'status': status,
      'emergencyType': emergencyType,
      'severity': severity,
      'notes': notes,
      'symptoms': symptoms,
      'timestamp': timestamp,
      'acceptedAt': acceptedAt,
      'enrouteAt': enrouteAt,
      'arrivedAt': arrivedAt,
      'patientLoadedAt': patientLoadedAt,
      'atHospitalAt': atHospitalAt,
      'completedAt': completedAt,
      'cancelledAt': cancelledAt,
      'cancelledReason': cancelledReason,
      'patientRating': patientRating,
      'patientFeedback': patientFeedback,
      'driverRating': driverRating,
      'driverFeedback': driverFeedback,
      'locationHistory': locationHistory,
    };
  }
  
  // ============================================================
  // CREATE REQUEST MODEL FROM MAP (from Firestore)
  // ============================================================
  factory RequestModel.fromMap(String id, Map<String, dynamic> data) {
    // Get patient location
    GeoPoint location;
    if (data['patientLocation'] != null) {
      if (data['patientLocation'] is GeoPoint) {
        location = GeoPoint(
          (data['patientLocation'] as GeoPoint).latitude,
          (data['patientLocation'] as GeoPoint).longitude,
        );
      } else {
        location = GeoPoint(
          data['patientLocation']['latitude'] ?? 0.0,
          data['patientLocation']['longitude'] ?? 0.0,
        );
      }
    } else {
      location = GeoPoint(0.0, 0.0);
    }
    
    return RequestModel(
      requestId: id,
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      patientPhone: data['patientPhone'] ?? '',
      patientLocation: location,
      patientAddress: data['patientAddress'],
      driverId: data['driverId'],
      driverName: data['driverName'],
      driverPhone: data['driverPhone'],
      ambulanceId: data['ambulanceId'],
      ambulanceNumber: data['ambulanceNumber'],
      status: data['status'] ?? 'pending',
      emergencyType: data['emergencyType'],
      severity: data['severity'],
      notes: data['notes'],
      symptoms: data['symptoms'],
      timestamp: _parseTimestamp(data['timestamp']),
      acceptedAt: _parseTimestamp(data['acceptedAt']),
      enrouteAt: _parseTimestamp(data['enrouteAt']),
      arrivedAt: _parseTimestamp(data['arrivedAt']),
      patientLoadedAt: _parseTimestamp(data['patientLoadedAt']),
      atHospitalAt: _parseTimestamp(data['atHospitalAt']),
      completedAt: _parseTimestamp(data['completedAt']),
      cancelledAt: _parseTimestamp(data['cancelledAt']),
      cancelledReason: data['cancelledReason'],
      patientRating: data['patientRating'] != null 
          ? (data['patientRating'] as num).toDouble() 
          : null,
      patientFeedback: data['patientFeedback'],
      driverRating: data['driverRating'] != null 
          ? (data['driverRating'] as num).toDouble() 
          : null,
      driverFeedback: data['driverFeedback'],
      locationHistory: data['locationHistory'] != null 
          ? List<Map<String, dynamic>>.from(data['locationHistory']) 
          : null,
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
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isEnroute => status == 'enroute';
  bool get isArrived => status == 'arrived';
  bool get isPatientLoaded => status == 'patient_loaded';
  bool get isAtHospital => status == 'at_hospital';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isActive => !isCompleted && !isCancelled;
  
  // Get status color (for UI)
  String get statusColor {
    switch (status) {
      case 'pending': return 'orange';
      case 'accepted': return 'blue';
      case 'enroute': return 'cyan';
      case 'arrived': return 'green';
      case 'patient_loaded': return 'purple';
      case 'at_hospital': return 'teal';
      case 'completed': return 'grey';
      case 'cancelled': return 'red';
      default: return 'grey';
    }
  }
  
  // Get status display text
  String get statusText {
    switch (status) {
      case 'pending': return 'Pending';
      case 'accepted': return 'Accepted';
      case 'enroute': return 'En Route';
      case 'arrived': return 'Arrived';
      case 'patient_loaded': return 'Patient Loaded';
      case 'at_hospital': return 'At Hospital';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }
  
  // Get severity level
  int get severityLevel {
    switch (severity) {
      case 'low': return 1;
      case 'medium': return 2;
      case 'high': return 3;
      case 'critical': return 4;
      default: return 2;
    }
  }
  
  // Get severity color
  String get severityColor {
    switch (severity) {
      case 'low': return 'green';
      case 'medium': return 'orange';
      case 'high': return 'red';
      case 'critical': return 'darkred';
      default: return 'orange';
    }
  }
  
  // Calculate response time (time from request to arrival)
  Duration? get responseTime {
    if (arrivedAt != null) {
      return arrivedAt!.difference(timestamp);
    }
    return null;
  }
  
  // Format response time
  String get formattedResponseTime {
    final duration = responseTime;
    if (duration == null) return 'N/A';
    
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} minutes';
    } else {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
  }
  
  // Get emergency icon
  String get emergencyIcon {
    switch (emergencyType) {
      case 'accident': return '🚗';
      case 'heart_attack': return '❤️';
      case 'pregnancy': return '👶';
      case 'stroke': return '🧠';
      case 'burn': return '🔥';
      case 'fall': return '🦵';
      default: return '🚑';
    }
  }
  
  // Copy with (for updating)
  RequestModel copyWith({
    String? status,
    String? driverId,
    String? driverName,
    String? driverPhone,
    DateTime? acceptedAt,
    DateTime? enrouteAt,
    DateTime? arrivedAt,
    DateTime? completedAt,
    double? patientRating,
    String? patientFeedback,
  }) {
    return RequestModel(
      requestId: requestId,
      patientId: patientId,
      patientName: patientName,
      patientPhone: patientPhone,
      patientLocation: patientLocation,
      patientAddress: patientAddress,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      ambulanceId: ambulanceId,
      ambulanceNumber: ambulanceNumber,
      status: status ?? this.status,
      emergencyType: emergencyType,
      severity: severity,
      notes: notes,
      symptoms: symptoms,
      timestamp: timestamp,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      enrouteAt: enrouteAt ?? this.enrouteAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      patientLoadedAt: patientLoadedAt,
      atHospitalAt: atHospitalAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt,
      cancelledReason: cancelledReason,
      patientRating: patientRating ?? this.patientRating,
      patientFeedback: patientFeedback ?? this.patientFeedback,
      driverRating: driverRating,
      driverFeedback: driverFeedback,
      locationHistory: locationHistory,
    );
  }
}