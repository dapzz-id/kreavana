import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_service.dart';
import 'badge_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
  // We can't update BadgeService here easily as it's an isolate,
  // but FCM will show the notification in the system tray automatically
  // because it contains a 'notification' payload (if sent correctly).
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    try {
      // 1. Request permission
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      debugPrint('User granted permission: ${settings.authorizationStatus}');

      // 2. Configure local notifications for foreground display
      if (!kIsWeb) {
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        const DarwinInitializationSettings initializationSettingsIOS =
            DarwinInitializationSettings();
        const InitializationSettings initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
        
        await _localNotifications.initialize(settings: initializationSettings);

        // Required for Android 8.0+ foreground notifications
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'high_importance_channel', 
          'High Importance Notifications', 
          description: 'This channel is used for important notifications.',
          importance: Importance.high,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      // 3. Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 4. Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        
        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          
          if (!kIsWeb) {
            _showLocalNotification(message);
          }
          
          // Try to guess if it's a message or notif to increment badge
          if (message.data['type'] == 'chat') {
            BadgeService().incrementUnreadMessages();
          } else {
            BadgeService().incrementUnreadNotifications();
          }
        }
      });

      // 5. Get FCM Token and save it to backend
      String? token = await _firebaseMessaging.getToken(
        vapidKey: kIsWeb ? dotenv.env['FIREBASE_VAPID_KEY'] : null,
      );
      if (token != null) {
        debugPrint('FCM Token: $token');
        await syncTokenToBackend(token);
      }

      // 6. Listen to token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        syncTokenToBackend(newToken);
      });

      _initialized = true;
    } catch (e) {
      debugPrint('FCM Init Error: $e');
    }
  }

  Future<void> syncTokenToBackend(String token) async {
    try {
      await ApiService.post('users/fcm-token', {'fcm_token': token});
      debugPrint('Synced FCM token to backend');
    } catch (e) {
      debugPrint('Failed to sync FCM token: $e');
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  }
}
