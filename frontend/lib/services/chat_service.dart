import 'api_service.dart';

class ChatService {
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
