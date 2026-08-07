import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'api_service.dart';
import 'badge_service.dart';

class ChatService {
  static PusherChannelsClient? _pusher;
  static bool _isConnected = false;
  static final Set<String> _subscribedChatIds = {};
  static final Set<String> _pendingChatIds = {};
  static final StreamController<Map<String, dynamic>> _messageStreamController = StreamController.broadcast();
  static final StreamController<Map<String, dynamic>> _deletedMessageStreamController = StreamController.broadcast();
  
  static Stream<Map<String, dynamic>> get messageStream => _messageStreamController.stream;
  static Stream<Map<String, dynamic>> get deletedMessageStream => _deletedMessageStreamController.stream;

  static Future<void> markAsRead(String chatId) async {
    await ApiService.post('chats/$chatId/read', {});
  }

  /// Lightweight presence ping - updates last_online on server
  static Future<void> pingPresence() async {
    try {
      await ApiService.post('presence/ping', {});
    } catch (e) {
      // Silently ignore presence ping failures
    }
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
        debugPrint('Pusher chat connection error: $exception');
        _isConnected = false;
        Future.delayed(const Duration(seconds: 5), refresh);
      },
    );

    _pusher!.onConnectionEstablished.listen((event) {
      debugPrint('✅ Pusher Chat Connection Established');
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
    debugPrint('📡 Subscribed to chat.$chatId (connected: $_isConnected)');

    channel.bind('message.sent').listen((event) {
      debugPrint('📨 Received message.sent event on chat.$chatId');
      if (event.data != null) {
        try {
          final data = event.data is String ? jsonDecode(event.data) : event.data;
          final msg = data['message'];
          if (msg != null) {
            msg['chat_id'] = chatId;
            _messageStreamController.add(Map<String, dynamic>.from(msg));
            // Refresh badge counts so UI updates immediately for unread messages
            try {
              BadgeService().fetchCounts();
            } catch (_) {}
          }
        } catch (e) {
          debugPrint('Error parsing message event: $e');
        }
      }
    });

    channel.bind('message.deleted').listen((event) {
      debugPrint('🗑️ Received message.deleted event on chat.$chatId');
      if (event.data != null) {
        try {
          final data = event.data is String ? jsonDecode(event.data) : event.data;
          final payload = data['payload'] ?? data;
          if (payload != null && payload['id'] != null) {
            _deletedMessageStreamController.add({
              'chat_id': chatId,
              'id': payload['id'].toString(),
              'scope': payload['scope'] ?? 'everyone',
            });
          }
        } catch (e) {
          debugPrint('Error parsing message.deleted event: $e');
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
        debugPrint('⏳ Queued subscription for chat.$chatId (waiting for connection)');
      }
    } catch (e) {
      debugPrint('Pusher chat error: $e');
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
    if (response['status'] == true && response['data'] is List) {
      return response['data'];
    }
    return [];
  }

  static Future<List<dynamic>> fetchMessages(String chatId) async {
    final response = await ApiService.get('chats/$chatId/messages');
    if (response['status'] == true && response['data'] is List) {
      return response['data'];
    }
    return [];
  }

  static Future<Map<String, dynamic>> sendMessage(String chatId, String text, {String? replyToId}) async {
    final body = <String, dynamic>{
      'type': 'text',
      'message': text,
    };
    if (replyToId != null) body['reply_to_id'] = replyToId;

    final response = await ApiService.post('chats/$chatId/messages', body);
    return response;
  }

  static Future<Map<String, dynamic>> sendAudioMessage(String chatId, String filePath, {String? replyToId}) async {
    final bytes = await File(filePath).readAsBytes();
    final ext = filePath.split('.').last.toLowerCase();
    final mime = _getAudioMime(ext);
    return sendAudioBytes(chatId, bytes, mime, replyToId: replyToId);
  }

  static Future<Map<String, dynamic>> sendAudioBytes(String chatId, Uint8List bytes, String mimeType, {String? replyToId}) async {
    final base64Data = base64Encode(bytes);
    final body = <String, dynamic>{
      'type': 'audio',
      'message': 'Voice note',
      'media': 'data:$mimeType;base64,$base64Data',
    };
    if (replyToId != null) body['reply_to_id'] = replyToId;

    final response = await ApiService.post('chats/$chatId/messages', body);
    return response;
  }

  static String _getAudioMime(String extension) {
    switch (extension) {
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
        return 'audio/m4a';
      case 'webm':
        return 'audio/webm';
      case 'ogg':
        return 'audio/ogg';
      default:
        return 'audio/aac';
    }
  }

  static Future<Map<String, dynamic>> deleteMessage(String chatId, String messageId, {String scope = 'me'}) async {
    final response = await ApiService.post('chats/$chatId/messages/$messageId/delete', {
      'scope': scope,
    });
    return response;
  }

  static Future<Map<String, dynamic>> createGroup(String name, String description) async {
    final res = await ApiService.post('groups', {'name': name, 'description': description});
    return res;
  }

  static Future<List<dynamic>> fetchGroupMembers(String chatId) async {
    final response = await ApiService.get('groups/$chatId/members');
    if (response['status'] == true && response['data'] is List) {
      return response['data'];
    }
    return [];
  }

  static Future<void> addGroupMember(String chatId, String userId) async {
    await ApiService.post('groups/$chatId/members', {'user_id': userId});
  }

  static Future<void> updateGroupSettings(String chatId, bool onlyAdmin) async {
    await ApiService.put('groups/$chatId/settings', {'only_admin_can_add': onlyAdmin});
  }

  static Future<List<dynamic>> searchUsers(String query) async {
    final response = await ApiService.get('users/search?q=$query');
    if (response['status'] == true && response['data'] is List) {
      return response['data'];
    }
    return [];
  }

  /// Daftar kontak (admin, kreator, klien) untuk memulai obrolan/panggilan.
  static Future<List<dynamic>> fetchContacts() async {
    final response = await ApiService.get('users/contacts');
    if (response['status'] == true && response['data'] is List) {
      return response['data'];
    }
    return [];
  }

  static Future<Map<String, dynamic>> startPersonalChat(String userId) async {
    final response = await ApiService.post('chats/personal', {'user_id': userId});
    return response;
  }

  static Future<void> kickMember(String chatId, String userId) async {
    await ApiService.delete('groups/$chatId/members/$userId');
  }

  static Future<void> updateGroupDetails(String chatId, String name, String description) async {
    await ApiService.put('groups/$chatId/details', {
      'name': name,
      'description': description,
    });
  }

  static Future<void> makeAdmin(String chatId, String userId) async {
    await ApiService.put('groups/$chatId/members/$userId/admin', {});
  }

  static Future<void> leaveGroup(String chatId) async {
    await ApiService.post('groups/$chatId/leave', {});
  }

  static Future<List<dynamic>> fetchInvitations() async {
    final response = await ApiService.get('invitations');
    if (response['status'] == true && response['data'] is List) {
      return response['data'];
    }
    return [];
  }

  static Future<void> respondInvitation(String chatId, bool accept) async {
    await ApiService.post('invitations/$chatId/respond', {'accept': accept});
  }
}
