import 'package:flutter/foundation.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'dart:async';
import 'badge_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  PusherChannelsClient? _pusher;
  bool _subscribed = false;

  void init(String userId, String token) {
    if (userId.isEmpty || _pusher != null) return;

    try {
      final pusherKey = dotenv.env['PUSHER_KEY'];
      if (pusherKey == null || pusherKey.isEmpty) {
        debugPrint('Realtime Init Error: PUSHER_KEY is missing from .env');
        return;
      }

      final options = PusherChannelsOptions.fromHost(
        scheme: 'ws',
        host: '127.0.0.1',
        port: 8080,
        key: pusherKey,
      );

      final authEndpoint =
          dotenv.env['API_BASE_URL']?.replaceAll(
            '/api',
            '/api/broadcasting/auth',
          ) ??
          'http://127.0.0.1:8000/api/broadcasting/auth';

      _pusher = PusherChannelsClient.websocket(
        options: options,
        connectionErrorHandler: (exception, trace, refresh) {
          debugPrint('Realtime connection error: $exception');
          _subscribed = false;
          Future.delayed(const Duration(seconds: 3), refresh);
        },
      );

      _pusher!.onConnectionEstablished.listen((_) {
        debugPrint('✅ Realtime Connected');
        _subscribeToUser(userId, token, authEndpoint);
      });

      _pusher!.connect();
    } catch (e) {
      debugPrint('Realtime Init Error: $e');
    }
  }

  void _subscribeToUser(String userId, String token, String authEndpoint) {
    if (_subscribed || _pusher == null) return;

    try {
      final channel = _pusher!.privateChannel(
        'user.$userId',
        authorizationDelegate:
            EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
              authorizationEndpoint: Uri.parse(authEndpoint),
              headers: {'Authorization': 'Bearer $token'},
            ),
      );

      channel.subscribe();

      channel.bind('App\\Events\\MessageSent').listen((event) {
        debugPrint('📩 New Message Event via Realtime!');
        BadgeService().incrementUnreadMessages();
      });

      channel.bind('App\\Events\\NotificationSent').listen((event) {
        debugPrint('🔔 New Notification Event via Realtime!');
        BadgeService().incrementUnreadNotifications();
      });

      _subscribed = true;
    } catch (e) {
      debugPrint('Realtime Subscribe Error: $e');
    }
  }

  void dispose() {
    _pusher?.disconnect();
    _pusher?.dispose();
    _pusher = null;
    _subscribed = false;
  }
}
