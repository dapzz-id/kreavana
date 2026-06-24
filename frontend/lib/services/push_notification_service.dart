import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_service.dart';
import 'auth_service.dart';

class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static PusherChannelsClient? _pusher;

  static Future<void> initialize() async {
    try {
      if (!kIsWeb) {
        const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidInitSettings);
        await _notificationsPlugin.initialize(settings: initSettings);
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final currentUser = await AuthService.getCurrentUser();

      if (token != null && currentUser != null) {
        await _initPusher(token, currentUser.id);
      }
    } catch (e) {
      debugPrint('Push Notification Init Error: $e');
    }
  }

  static Future<void> disconnect() async {
    if (_pusher != null) {
      _pusher!.disconnect();
      _pusher = null;
    }
  }

  static Future<void> _initPusher(String token, int userId) async {
    try {
      if (_pusher != null) {
        _pusher!.disconnect();
        _pusher = null;
      }

      _pusher = PusherChannelsClient.websocket(
        options: PusherChannelsOptions.fromHost(
          scheme: 'ws',
          host: ApiService.hostIp,
          port: 8080,
          key: ApiService.keyPusher,
        ),
        connectionErrorHandler: (exception, trace, refresh) {
          print('Pusher notification connection error: $exception');
          Future.delayed(const Duration(seconds: 5), refresh);
        },
      );
      _pusher!.onConnectionEstablished.listen((event) {
        debugPrint('Pusher Notification Connection Event: Connected');
        
        final channel = _pusher!.publicChannel('user.$userId');
        channel.subscribe();
        
        channel.bind('notification.sent').listen((notifEvent) {
          if (notifEvent.data != null) {
            _onEvent(notifEvent.data!);
          }
        });
      });
      _pusher!.connect();
    } catch (e) {
      print('Pusher init error: $e');
    }
  }

  static void _onEvent(dynamic eventData) {
    try {
      final data = eventData is String ? jsonDecode(eventData) : eventData;
      final notif = data['notification'];
      
      if (notif != null) {
        _showNotification(notif['title'] ?? 'Notifikasi', notif['message'] ?? 'Ada pemberitahuan baru');
      }
    } catch (e) {
      print('Error parsing notification: $e');
    }
  }

  static Future<void> _showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'kreavana_channel',
      'Kreavana Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }
}
