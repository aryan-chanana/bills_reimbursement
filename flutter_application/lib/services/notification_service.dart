import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Background/terminated notifications are displayed automatically by FCM on Android
}

class NotificationService {
  static const _channelId = 'bills_channel';
  static const _channelName = 'Bills Reimbursement';

  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static final _messaging = FirebaseMessaging.instance;

  /// Call once from main() after Firebase.initializeApp()
  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // Local notifications for foreground display
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings),
    );

    // High-importance channel required for heads-up notifications on Android 8+
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          importance: Importance.high,
        ));

    // Re-upload token whenever Firebase rotates it
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final employeeId = prefs.getInt('employee_id')?.toString();
        final password = prefs.getString('password');
        if (employeeId != null && password != null) {
          await ApiService.updateFcmToken(employeeId, password, newToken);
        }
      } catch (_) {}
    });

    // Show foreground messages as a local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final n = message.notification;
      if (n == null) return;
      _localNotifications.show(
        message.hashCode,
        n.title,
        n.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });
  }

  /// Request OS permission and return the FCM device token
  static Future<String?> requestPermissionAndGetToken() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    return await _messaging.getToken();
  }
}
