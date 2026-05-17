import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );
    
    await _notifications.initialize(settings: settings);
  }
  
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ambulance_channel',
      'Ambulance Notifications',
      channelDescription: 'Notifications for ambulance requests',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );
    
    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
  
  static Future<void> showEmergencyNotification(String patientName, String patientLocation) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: '🚑 Emergency Request!',
      body: '$patientName needs ambulance at $patientLocation',
    );
  }
  
  static Future<void> showRequestAcceptedNotification(String driverName) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: '✅ Request Accepted',
      body: 'Driver $driverName is on their way to you',
    );
  }
}