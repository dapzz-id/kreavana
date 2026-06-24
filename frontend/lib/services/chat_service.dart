import 'dart:convert';
import 'dart:async';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'api_service.dart';

class ChatService {
  static PusherChannelsClient? _pusher;
  static bool _isConnected = false;
  static final Set<String> _subscribedChatIds = {};
  static final Set<String> _pendingChatIds = {};
  static final StreamController<Map<String, dynamic>> _messageStreamController = StreamController.broadcast();
  
  static Stream<Map<String, dynamic>> get messageStream => _messageStreamController.stream;

  static Future<void> markAsRead(String chatId) async {
    await ApiService.post('chats/$chatId/read', {});
  }

  /// Ensure Pusher client is created and connecting/connected.
  static void _ensureConnected() {
    if (_pusher != null) return;

    _isConnected = false;
    _subscribedChatIds.clear();

    _pusher = PusherChannelsClient.websocket(
      options: PusherChannelsOptions.fromHost(
        scheme: 'ws',
        host: ApiService.hostIp,
        port: 8080,
        key: ApiService.keyPusher,
      ),
      connectionErrorHandler: (exception, trace, refresh) {
        print('Pusher chat connection error: $exception');
        _isConnected = false;
        Future.delayed(const Duration(seconds: 5), refresh);
      },
    );

    _pusher!.onConnectionEstablished.listen((event) {
      print('✅ Pusher Chat Connection Established');
      _isConnected = true;
      // Now subscribe to all channels that were queued while waiting for connection
      final pending = Set<String>.from(_pendingChatIds);
      _pendingChatIds.clear();
      for (final chatId in pending) {
        _bindChannel(chatId);
      }
    });

    _pusher!.connect();
  }

  /// Actually subscribe to a channel and bind the message event listener.
  /// Only called when connection is established.
  static void _bindChannel(String chatId) {
    // Prevent double binding — this is the critical guard
    if (_subscribedChatIds.contains(chatId)) return;
    _subscribedChatIds.add(chatId);

    final channel = _pusher!.publicChannel('chat.$chatId');
    channel.subscribe();
    print('📡 Subscribed to chat.$chatId (connected: $_isConnected)');

    channel.bind('message.sent').listen((event) {
      print('📨 Received message.sent event on chat.$chatId');
      if (event.data != null) {
        try {
          final data = event.data is String ? jsonDecode(event.data) : event.data;
          final msg = data['message'];
          if (msg != null) {
            msg['chat_id'] = chatId;
            _messageStreamController.add(Map<String, dynamic>.from(msg));
          }
        } catch (e) {
          print('Error parsing message event: $e');
        }
      }
    });
  }

  /// Public method to subscribe to a chat channel.
  /// If not yet connected, queues the subscription for when connection is ready.
  static Future<void> subscribeToChat(String chatId) async {
    try {
      _ensureConnected();

      // Already subscribed — skip entirely
      if (_subscribedChatIds.contains(chatId)) return;

      if (_isConnected) {
        _bindChannel(chatId);
      } else {
        _pendingChatIds.add(chatId);
        print('⏳ Queued subscription for chat.$chatId (waiting for connection)');
      }
    } catch (e) {
      print('Pusher chat error: $e');
    }
  }

  static Future<void> unsubscribeFromChat(String chatId) async {
    if (_pusher != null && _subscribedChatIds.contains(chatId)) {
      final channel = _pusher!.publicChannel('chat.$chatId');
      channel.unsubscribe();
      _subscribedChatIds.remove(chatId);
    }
  }

  /// Disconnect and reset all state (e.g. on logout)
  static Future<void> disconnect() async {
    if (_pusher != null) {
      _pusher!.disconnect();
      _pusher = null;
    }
    _isConnected = false;
    _subscribedChatIds.clear();
    _pendingChatIds.clear();
  }

  static Future<List<dynamic>> fetchChats() async {
    final response = await ApiService.get('chats');
    if (response is List) return response;
    if (response is Map && response['success'] == true && response['data'] is List) {
      return response['data'];
    }
    return [];
  }

  static Future<List<dynamic>> fetchMessages(String chatId) async {
    final response = await ApiService.get('chats/$chatId/messages');
    if (response is List) return response;
    if (response is Map && response['success'] == true && response['data'] is List) {
      return response['data'];
    }
    return [];
  }

  static Future<Map<String, dynamic>> sendMessage(String chatId, String text) async {
    final response = await ApiService.post('chats/$chatId/messages', {'message': text});
    if (response is Map<String, dynamic>) return response;
    return {'success': false, 'message': 'Unknown error'};
  }

  static Future<Map<String, dynamic>> createGroup(String name) async {
    final response = await ApiService.post('groups', {'name': name});
    if (response is Map<String, dynamic>) return response;
    return {'success': false};
  }

  static Future<List<dynamic>> fetchGroupMembers(String chatId) async {
    final response = await ApiService.get('groups/$chatId/members');
    if (response is List) return response;
    if (response is Map && response['success'] == true && response['data'] is List) {
      return response['data'];
    }
    return [];
  }

  static Future<void> addGroupMember(String chatId, int userId) async {
    await ApiService.post('groups/$chatId/members', {'user_id': userId});
  }

  static Future<void> updateGroupSettings(String chatId, bool onlyAdmin) async {
    await ApiService.put('groups/$chatId/settings', {'only_admin_can_add': onlyAdmin});
  }

  static Future<List<dynamic>> searchUsers(String query) async {
    final response = await ApiService.get('users/search?q=$query');
    if (response is List) return response;
    if (response is Map && response['success'] == true && response['data'] is List) {
      return response['data'];
    }
    return [];
  }

  static Future<Map<String, dynamic>> startPersonalChat(int userId) async {
    final response = await ApiService.post('chats/personal', {'user_id': userId});
    if (response is Map<String, dynamic>) return response;
    throw Exception('Failed to start personal chat');
  }

  static Future<void> kickMember(String chatId, String userId) async {
    await ApiService.delete('groups/$chatId/members/$userId');
  }

  static Future<void> makeAdmin(String chatId, String userId) async {
    await ApiService.put('groups/$chatId/members/$userId/admin', {});
  }

  static Future<void> leaveGroup(String chatId) async {
    await ApiService.post('groups/$chatId/leave', {});
  }

  static Future<List<dynamic>> fetchInvitations() async {
    final response = await ApiService.get('invitations');
    if (response is List) return response;
    if (response is Map && response['success'] == true && response['data'] is List) {
      return response['data'];
    }
    return [];
  }

  static Future<void> respondInvitation(String chatId, bool accept) async {
    await ApiService.post('invitations/$chatId/respond', {'accept': accept});
  }
}
