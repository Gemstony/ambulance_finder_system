import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/request_model.dart' hide GeoPoint;

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create emergency request
  Future<String?> createRequest(RequestModel request) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('requests')
          .add(request.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating request: $e');
      return null;
    }
  }

  // Get pending requests (for drivers)
  Stream<QuerySnapshot> getPendingRequests() {
    return _firestore
        .collection('requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Get user's request history
  Stream<QuerySnapshot> getUserRequests(String userId, String role) {
    if (role == 'patient') {
      return _firestore
          .collection('requests')
          .where('patientId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .snapshots();
    } else if (role == 'driver') {
      return _firestore
          .collection('requests')
          .where('driverId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
    return const Stream.empty();
  }

  // Get all requests (for admin reports)
  Stream<QuerySnapshot> getAllRequests() {
    return _firestore
        .collection('requests')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Update request status
  Future<void> updateRequestStatus(
    String requestId,
    String status, {
    String? driverId,
    String? driverName,
  }) async {
    Map<String, dynamic> updates = {'status': status};

    if (driverId != null) updates['driverId'] = driverId;
    if (driverName != null) updates['driverName'] = driverName;

    if (status == 'accepted')
      updates['acceptedAt'] = FieldValue.serverTimestamp();
    if (status == 'arrived')
      updates['arrivedAt'] = FieldValue.serverTimestamp();
    if (status == 'completed')
      updates['completedAt'] = FieldValue.serverTimestamp();

    await _firestore.collection('requests').doc(requestId).update(updates);
  }

  // Update driver location in real-time
  // In firestore_service.dart
  Future<void> updateDriverLocation(
    String driverId,
    double lat,
    double lng,
    String status,
  ) async {
    await _firestore.collection('drivers_location').doc(driverId).set({
      'location': GeoPoint(lat, lng),
      'status': status,
      'lastUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Get driver live location
  Stream<DocumentSnapshot> getDriverLocation(String driverId) {
    return _firestore.collection('drivers_location').doc(driverId).snapshots();
  }

  // Get all active drivers (for admin)
  Stream<QuerySnapshot> getActiveDrivers() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  // Get all users (for admin)
  Stream<QuerySnapshot> getAllUsers() {
    return _firestore.collection('users').snapshots();
  }

  // Update user status
  Future<void> updateUserStatus(String userId, bool isActive) async {
    await _firestore.collection('users').doc(userId).update({
      'isActive': isActive,
    });
  }

  // Get request by ID
  Future<RequestModel?> getRequestById(String requestId) async {
    DocumentSnapshot doc = await _firestore
        .collection('requests')
        .doc(requestId)
        .get();
    if (doc.exists) {
      return RequestModel.fromMap(
        requestId,
        doc.data() as Map<String, dynamic>,
      );
    }
    return null;
  }

  // Get nearest available drivers
  Future<List<QueryDocumentSnapshot>> getNearestDrivers(
    double lat,
    double lng,
    double radiusKm,
  ) async {
    // This is a simplified query. For production, use geohashes
    QuerySnapshot drivers = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .where('isActive', isEqualTo: true)
        .get();

    // Filter by distance in memory (for simplicity)
    List<QueryDocumentSnapshot> nearbyDrivers = [];
    for (var driver in drivers.docs) {
      // In production, store location in driver's document
      // Here we're just returning all active drivers
      nearbyDrivers.add(driver);
    }

    return nearbyDrivers;
  }

  // Add this method to track driver rejections
  Future<void> addRejectedDriver(String requestId, String driverId) async {
    // Store rejection in a subcollection of the request
    await _firestore
        .collection('requests')
        .doc(requestId)
        .collection('rejected_drivers')
        .doc(driverId)
        .set({
          'driverId': driverId,
          'rejectedAt': FieldValue.serverTimestamp(),
        });
  }

  // In your FirestoreService class

  Future<bool> hasDriverRejected(String requestId, String driverId) async {
    try {
      // Reference to the specific document in the rejected_drivers subcollection
      final docRef = _firestore
          .collection('requests')
          .doc(requestId)
          .collection('rejected_drivers')
          .doc(driverId);

      final docSnapshot = await docRef.get();
      // Returns true if the document exists, false otherwise
      return docSnapshot.exists;
    } catch (e) {
      print("Error checking if driver has rejected: $e");
      return false; // Return false in case of error to avoid breaking the app
    }
  }
}
