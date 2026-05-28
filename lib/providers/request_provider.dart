import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../models/request_model.dart';

class RequestProvider extends ChangeNotifier {
  // Service instance
  final FirestoreService _firestoreService = FirestoreService();

  // State variables
  List<RequestModel> _pendingRequests = [];
  List<RequestModel> _userRequests = [];
  RequestModel? _activeRequest;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<RequestModel> get pendingRequests => _pendingRequests;
  List<RequestModel> get userRequests => _userRequests;
  RequestModel? get activeRequest => _activeRequest;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ============================================================
  // CREATE NEW AMBULANCE REQUEST
  // ============================================================
  // In request_provider.dart
  Future<String?> createEmergencyRequest({
    required String patientId,
    required String patientName,
    required String patientPhone,
    required double latitude,
    required double longitude,
    String? notes,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      // Cancel any existing active requests for this patient
      final activeSnapshot = await FirebaseFirestore.instance
          .collection('requests')
          .where('patientId', isEqualTo: patientId)
          .where(
            'status',
            whereIn: ['pending', 'accepted', 'enroute', 'arrived'],
          )
          .get();

      for (var doc in activeSnapshot.docs) {
        await _firestoreService.updateRequestStatus(doc.id, 'cancelled');
      }

      // Create new request
      final request = RequestModel(
        requestId: '',
        patientId: patientId,
        patientName: patientName,
        patientPhone: patientPhone,
        patientLocation: GeoPoint(latitude, longitude),
        driverId: null,
        driverName: null,
        status: 'pending',
        timestamp: DateTime.now(),
        acceptedAt: null,
        arrivedAt: null,
        completedAt: null,
        notes: notes,
      );

      final requestId = await _firestoreService.createRequest(request);

      if (requestId != null) {
        await NotificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: '🚑 New Emergency Request!',
          body: '$patientName needs ambulance immediately',
        );
        _setLoading(false);
        return requestId;
      } else {
        _errorMessage = 'Failed to create request';
        _setLoading(false);
        return null;
      }
    } catch (e) {
      _errorMessage = 'Error creating request: ${e.toString()}';
      _setLoading(false);
      return null;
    }
  }

  // ============================================================
  // GET PENDING REQUESTS (FOR DRIVERS)
  // ============================================================
  void listenToPendingRequests(String driverId) {
    _firestoreService.getPendingRequests().listen((snapshot) async {
      List<RequestModel> allRequests = snapshot.docs.map((doc) {
        return RequestModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();

      // Filter out requests that this driver has already rejected
      List<RequestModel> filtered = [];
      for (var request in allRequests) {
        bool rejected = await _firestoreService.hasDriverRejected(
          request.requestId,
          driverId,
        );
        if (!rejected) {
          filtered.add(request);
        }
      }

      _pendingRequests = filtered;
      _pendingRequests.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      notifyListeners();
    });
  }

  // ============================================================
  // GET USER SPECIFIC REQUESTS
  // ============================================================
  void listenToUserRequests(String userId, String role) {
    _firestoreService.getUserRequests(userId, role).listen((snapshot) {
      _userRequests = snapshot.docs.map((doc) {
        return RequestModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();

      // Sort by timestamp (newest first)
      _userRequests.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Set active request (pending or accepted or enroute)
      final activeRequests = _userRequests
          .where(
            (req) =>
                req.status == 'pending' ||
                req.status == 'accepted' ||
                req.status == 'enroute' ||
                req.status == 'arrived',
          )
          .toList();
      _activeRequest = activeRequests.isNotEmpty ? activeRequests.first : null;

      notifyListeners();
    });
  }

  // ============================================================
  // ACCEPT REQUEST (BY DRIVER)
  // ============================================================
  Future<bool> acceptRequest(
    String requestId,
    String driverId,
    String driverName,
  ) async {
    _setLoading(true);

    try {
      await _firestoreService.updateRequestStatus(
        requestId,
        'accepted',
        driverId: driverId,
        driverName: driverName,
      );

      //TODO: Notify patient that request was accepted
      await NotificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: '✅ Request Accepted',
        body: 'Driver $driverName is on their way to you',
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to accept request: ${e.toString()}';
      _setLoading(false);
      return false;
    }
  }

  // ============================================================
  // TODO: UPDATE REQUEST STATUS
  // ============================================================
  Future<bool> updateRequestStatus(String requestId, String status) async {
    _setLoading(true);

    try {
      await _firestoreService.updateRequestStatus(requestId, status);

      // Send appropriate notifications based on status
      if (status == 'enroute') {
        await NotificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: '🚑 Ambulance En Route',
          body: 'Ambulance is on its way to your location',
        );
      } else if (status == 'arrived') {
        await NotificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: '📍 Ambulance Arrived',
          body: 'Ambulance has arrived at your location',
        );
      } else if (status == 'completed') {
        await NotificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: '✅ Trip Completed',
          body: 'Your ambulance trip has been completed',
        );
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update status: ${e.toString()}';
      _setLoading(false);
      return false;
    }
  }

  // ============================================================
  // CANCEL REQUEST
  // ============================================================
  Future<bool> cancelRequest(String requestId) async {
    _setLoading(true);

    try {
      await _firestoreService.updateRequestStatus(requestId, 'cancelled');
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to cancel request: ${e.toString()}';
      _setLoading(false);
      return false;
    }
  }

  // ============================================================
  // GET SINGLE REQUEST DETAILS
  // ============================================================
  Future<RequestModel?> getRequestById(String requestId) async {
    try {
      return await _firestoreService.getRequestById(requestId);
    } catch (e) {
      _errorMessage = 'Failed to get request: ${e.toString()}';
      return null;
    }
  }

  // ============================================================
  // GET NEARBY DRIVERS
  // ============================================================
  Future<List<QueryDocumentSnapshot>> getNearbyDrivers(
    double lat,
    double lng,
    double radiusKm,
  ) async {
    try {
      return await _firestoreService.getNearestDrivers(lat, lng, radiusKm);
    } catch (e) {
      _errorMessage = 'Failed to get nearby drivers: ${e.toString()}';
      return [];
    }
  }

  // ============================================================
  // CLEAR ACTIVE REQUEST
  // ============================================================
  void clearActiveRequest() {
    _activeRequest = null;
    notifyListeners();
  }

  // ============================================================
  // CLEAR ERROR
  // ============================================================
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ============================================================
  // RESET STATE
  // ============================================================
  void resetState() {
    _pendingRequests = [];
    _userRequests = [];
    _activeRequest = null;
    _isLoading = false;
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

  // Inside RequestProvider

  // Driver rejects request
  Future<bool> rejectRequest(String requestId, String driverId) async {
    _setLoading(true);
    try {
      await _firestoreService.addRejectedDriver(requestId, driverId);
      // Optionally, remove this request from local pendingRequests list
      _pendingRequests.removeWhere((req) => req.requestId == requestId);
      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to reject: $e';
      _setLoading(false);
      return false;
    }
  }

  // Patient confirms arrival
  Future<bool> confirmArrival(String requestId) async {
    _setLoading(true);
    try {
      await _firestoreService.updateRequestStatus(requestId, 'completed');
      _activeRequest = null;
      // Also remove from userRequests? Optional
      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to confirm arrival: $e';
      _setLoading(false);
      return false;
    }
  }
}
