import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/destination.dart';
import '../main.dart';

class NotificationService {
  static NotificationService? _instance;
  NotificationService._internal();
  
  static NotificationService get instance {
    _instance ??= NotificationService._internal();
    return _instance!;
  }

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    await _requestNotificationPermissions();
  }

  void _onNotificationTapped(NotificationResponse notificationResponse) {
    if (notificationResponse.id == 999) {
      // This is the monitoring notification - navigate to home screen
      final context = navigatorKey.currentContext;
      if (context != null) {
        // Navigate to home screen
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (route) => false);
      }
    }
  }

  Future<void> _requestNotificationPermissions() async {
    await Permission.notification.request();
    
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> showDestinationAlarm(Destination destination) async {
    const androidDetails = AndroidNotificationDetails(
      'destination_alarm',
      'Destination Alarms',
      channelDescription: 'Notifications when approaching destinations',
      importance: Importance.high,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('alarm'),
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
    );

    const iosDetails = DarwinNotificationDetails(
      sound: 'alarm.wav',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      destination.id.hashCode,
      'Destination Reached!',
      'You are near ${destination.name}',
      details,
    );
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> showPersistentMonitoringNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'monitoring_status',
      'Monitoring Status',
      channelDescription: 'Shows when destination monitoring is active',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999, // Fixed ID for monitoring notification
      'Destination Alarm Active',
      'Monitoring destinations in background. Tap to return to app.',
      details,
    );
  }

  Future<void> cancelMonitoringNotification() async {
    await _notifications.cancel(999);
  }
}