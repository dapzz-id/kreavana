import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_service.dart';

class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();

  static Future<void> initialize() async {
    try {
      if (!kIsWeb) {
        const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidInitSettings);
        await _notificationsPlugin.initialize(settings: initSettings);
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = 1; 

      if (token != null) {
        await _initPusher(token, userId);
      }
    } catch (e) {
      debugPrint('Push Notification Init Error: $e');
    }
  }

  static Future<void> _initPusher(String token, int userId) async {
    try {
      await _pusher.init(
        apiKey: 'kreavana_key', // From .env PUSHER_APP_KEY / REVERB_APP_KEY
        cluster: 'mt1',
        onEvent: _onEvent,
        authEndpoint: '${ApiService.baseUrl.replaceAll('/api', '')}/broadcasting/auth',
        authParams: {
          'headers': {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          }
        },
      );
      
      // Connect to reverb over ws
      // Note: Make sure Reverb is running on wsHost: 10.0.2.2 or localhost
      await _pusher.connect();
      
      await _pusher.subscribe(
        channelName: 'private-App.Models.User.$userId',
      );
    } catch (e) {
      print('Pusher init error: $e');
    }
  }

  static void _onEvent(PusherEvent event) {
    if (event.eventName == 'App\\Events\\NotificationSent') {
      final data = jsonDecode(event.data.toString());
      final notif = data['notification'];
      
      _showNotification(notif['title'] ?? 'Notifikasi', notif['message'] ?? 'Ada pemberitahuan baru');
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
