import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/request_model.dart' hide GeoPoint;

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // REQUEST METHODS
  // ============================================================

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

  // Get pending requests (for drivers) - FIXED INDEX REQUIRED
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
  // In firestore_service.dart
  Future<void> updateRequestStatus(
    String requestId,
    String status, {
    String? driverId,
    String? driverName,
  }) async {
    Map<String, dynamic> updates = {'status': status};

    if (driverId != null) updates['driverId'] = driverId;
    if (driverName != null) updates['driverName'] = driverName;

    // Add timestamps based on status
    if (status == 'accepted') {
      updates['acceptedAt'] = FieldValue.serverTimestamp();
    } else if (status == 'arrived') {
      updates['arrivedAt'] = FieldValue.serverTimestamp();
    } else if (status == 'completed') {
      updates['completedAt'] = FieldValue.serverTimestamp();
    }
    // For 'cancelled', no extra timestamp (or you could add cancelledAt)

    // 🔥 IMPORTANT: Always perform the update
    await _firestore.collection('requests').doc(requestId).update(updates);
  }

  // Get request by ID
  Future<RequestModel?> getRequestById(String requestId) async {
    try {
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
    } catch (e) {
      print('Error getting request: $e');
      return null;
    }
  }

  // ============================================================
  // DRIVER LOCATION METHODS
  // ============================================================

  // Update driver location in real-time
  Future<void> updateDriverLocation(
    String driverId,
    double lat,
    double lng,
    String status,
  ) async {
    try {
      await _firestore.collection('drivers_location').doc(driverId).set({
        'location': GeoPoint(lat, lng),
        'status': status,
        'lastUpdate': FieldValue.serverTimestamp(),
        'driverId': driverId,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating driver location: $e');
    }
  }

  // Get driver live location
  Stream<DocumentSnapshot> getDriverLocation(String driverId) {
    return _firestore.collection('drivers_location').doc(driverId).snapshots();
  }

  // Get all active drivers locations (for admin live tracking)
  Stream<QuerySnapshot> getAllDriversLocations() {
    return _firestore.collection('drivers_location').snapshots();
  }

  // ============================================================
  // USER MANAGEMENT METHODS
  // ============================================================

  // Get all users (for admin)
  Stream<QuerySnapshot> getAllUsers() {
    return _firestore.collection('users').snapshots();
  }

  // Get user by ID
  Future<DocumentSnapshot> getUserById(String userId) async {
    return await _firestore.collection('users').doc(userId).get();
  }

  // Update user status (activate/deactivate)
  Future<void> updateUserStatus(String userId, bool isActive) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user status: $e');
      rethrow;
    }
  }

  // Update user role
  Future<void> updateUserRole(String userId, String newRole) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': newRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user role: $e');
      rethrow;
    }
  }

  // Delete user
  Future<void> deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      print('Error deleting user: $e');
      rethrow;
    }
  }

  // Get active drivers (for admin)
  Stream<QuerySnapshot> getActiveDrivers() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  // Get all drivers
  Stream<QuerySnapshot> getAllDrivers() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .snapshots();
  }

  // Get all patients
  Stream<QuerySnapshot> getAllPatients() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .snapshots();
  }

  // ============================================================
  // DRIVER REJECTION TRACKING
  // ============================================================

  // Add rejected driver to request
  Future<void> addRejectedDriver(String requestId, String driverId) async {
    try {
      await _firestore
          .collection('requests')
          .doc(requestId)
          .collection('rejected_drivers')
          .doc(driverId)
          .set({
            'driverId': driverId,
            'rejectedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error adding rejected driver: $e');
    }
  }

  // Check if driver has rejected a request
  Future<bool> hasDriverRejected(String requestId, String driverId) async {
    try {
      final docRef = _firestore
          .collection('requests')
          .doc(requestId)
          .collection('rejected_drivers')
          .doc(driverId);

      final docSnapshot = await docRef.get();
      return docSnapshot.exists;
    } catch (e) {
      print("Error checking if driver has rejected: $e");
      return false;
    }
  }

  // Get all rejected drivers for a request
  Future<List<String>> getRejectedDrivers(String requestId) async {
    try {
      final querySnapshot = await _firestore
          .collection('requests')
          .doc(requestId)
          .collection('rejected_drivers')
          .get();

      return querySnapshot.docs
          .map((doc) => doc['driverId'] as String)
          .toList();
    } catch (e) {
      print('Error getting rejected drivers: $e');
      return [];
    }
  }

  // ============================================================
  // NEARBY DRIVERS (Using GeoHash or Simple Filter)
  // ============================================================

  // Get nearest available drivers (simplified version)
  Future<List<QueryDocumentSnapshot>> getNearestDrivers(
    double lat,
    double lng,
    double radiusKm,
  ) async {
    try {
      // Get all active drivers
      QuerySnapshot drivers = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .where('isActive', isEqualTo: true)
          .get();

      // For production, you'd use geohashes or GeoFire
      // Here we return all active drivers
      // The distance filtering will be done on the client side
      return drivers.docs;
    } catch (e) {
      print('Error getting nearest drivers: $e');
      return [];
    }
  }

  // ============================================================
  // STATISTICS / REPORTS (For Admin)
  // ============================================================

  // Get total users count by role
  Future<Map<String, int>> getUserStats() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();

      int patients = 0;
      int drivers = 0;
      int admins = 0;

      for (var doc in usersSnapshot.docs) {
        final role = doc.data()['role'] as String?;
        switch (role) {
          case 'patient':
            patients++;
            break;
          case 'driver':
            drivers++;
            break;
          case 'admin':
            admins++;
            break;
        }
      }

      return {
        'patients': patients,
        'drivers': drivers,
        'admins': admins,
        'total': usersSnapshot.docs.length,
      };
    } catch (e) {
      print('Error getting user stats: $e');
      return {'patients': 0, 'drivers': 0, 'admins': 0, 'total': 0};
    }
  }

  // Get request statistics
  Future<Map<String, dynamic>> getRequestStats() async {
    try {
      final requestsSnapshot = await _firestore.collection('requests').get();

      int pending = 0;
      int accepted = 0;
      int enroute = 0;
      int completed = 0;
      int cancelled = 0;

      for (var doc in requestsSnapshot.docs) {
        final status = doc.data()['status'] as String?;
        switch (status) {
          case 'pending':
            pending++;
            break;
          case 'accepted':
            accepted++;
            break;
          case 'enroute':
            enroute++;
            break;
          case 'completed':
            completed++;
            break;
          case 'cancelled':
            cancelled++;
            break;
        }
      }

      return {
        'pending': pending,
        'accepted': accepted,
        'enroute': enroute,
        'completed': completed,
        'cancelled': cancelled,
        'total': requestsSnapshot.docs.length,
      };
    } catch (e) {
      print('Error getting request stats: $e');
      return {
        'pending': 0,
        'accepted': 0,
        'enroute': 0,
        'completed': 0,
        'cancelled': 0,
        'total': 0,
      };
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  // Get driver's current request (active trip)
  Future<RequestModel?> getDriverActiveRequest(String driverId) async {
    final snapshot = await _firestore
        .collection('requests')
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['accepted', 'enroute', 'arrived'])
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      return RequestModel.fromMap(
        snapshot.docs.first.id,
        snapshot.docs.first.data(),
      );
    }
    return null;
  }

  // Get patient's current active request
  Future<RequestModel?> getPatientActiveRequest(String patientId) async {
    try {
      final querySnapshot = await _firestore
          .collection('requests')
          .where('patientId', isEqualTo: patientId)
          .where(
            'status',
            whereIn: ['pending', 'accepted', 'enroute', 'arrived'],
          )
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return RequestModel.fromMap(doc.id, doc.data());
      }
      return null;
    } catch (e) {
      print('Error getting patient active request: $e');
      return null;
    }
  }

  // Add these methods inside FirestoreService class

  // Get available drivers (online, active, and not on a trip)
  Future<List<QueryDocumentSnapshot>> getAvailableDrivers() async {
    // First get all online drivers
    final driversSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .where('isOnline', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .get();

    // Filter out drivers who are already on a trip
    List<QueryDocumentSnapshot> available = [];
    for (var doc in driversSnapshot.docs) {
      final driverId = doc.id;
      final activeRequest = await getDriverActiveRequest(driverId);
      if (activeRequest == null) {
        available.add(doc);
      }
    }
    return available;
  }

  // Get pending requests that have at least one rejected driver
  Stream<QuerySnapshot> getRejectedRequests() {
    // This is complex because we need to filter requests that have rejected_drivers subcollection.
    // Simplest: get all pending requests and filter client-side (since pending count is usually small)
    return _firestore
        .collection('requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Check if a request has any rejections
  Future<bool> hasRejections(String requestId) async {
    final rejections = await _firestore
        .collection('requests')
        .doc(requestId)
        .collection('rejected_drivers')
        .limit(1)
        .get();
    return rejections.docs.isNotEmpty;
  }

  // Get list of drivers who rejected a request
  Future<List<String>> getRejectedDriverIds(String requestId) async {
    final snapshot = await _firestore
        .collection('requests')
        .doc(requestId)
        .collection('rejected_drivers')
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  // Reassign a request to a new driver (admin action)
  Future<void> reassignRequest(
    String requestId,
    String newDriverId,
    String newDriverName,
  ) async {
    await _firestore.collection('requests').doc(requestId).update({
      'driverId': newDriverId,
      'driverName': newDriverName,
      'status': 'pending', // reset to pending so driver can accept
      'acceptedAt': null, // clear acceptance timestamp
      'assignedByAdmin': true,
      'assignedAt': FieldValue.serverTimestamp(),
    });
    // Optionally, clear the rejected_drivers subcollection for this request
    final rejectionsRef = _firestore
        .collection('requests')
        .doc(requestId)
        .collection('rejected_drivers');
    final snap = await rejectionsRef.get();
    for (var doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  // Get all drivers (for admin list) with online/offline status
  Stream<QuerySnapshot> getAllDriversWithStatus() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .snapshots();
  }
}
