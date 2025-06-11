import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/destination.dart';

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

    await _notifications.initialize(settings);
    await _requestNotificationPermissions();
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
}