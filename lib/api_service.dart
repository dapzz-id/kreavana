import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  static Future<List<dynamic>> fetchChats() async {
    final response = await http.get(Uri.parse('$baseUrl/chats'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load chats');
    }
  }

  static Future<List<dynamic>> fetchMessages(String chatId) async {
    final response = await http.get(Uri.parse('$baseUrl/chats/$chatId/messages'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load messages');
    }
  }

  static Future<Map<String, dynamic>> sendMessage(String chatId, String text) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chats/$chatId/messages'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'message': text}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to send message');
    }
  }

  static Future<Map<String, dynamic>> createGroup(String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/groups'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create group');
    }
  }

  static Future<List<dynamic>> fetchGroupMembers(String chatId) async {
    final response = await http.get(Uri.parse('$baseUrl/groups/$chatId/members'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load members');
    }
  }

  static Future<void> addGroupMember(String chatId, int userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/groups/$chatId/members'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_id': userId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to add member');
    }
  }

  static Future<void> updateGroupSettings(String chatId, bool onlyAdmin) async {
    final response = await http.put(
      Uri.parse('$baseUrl/groups/$chatId/settings'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'only_admin_can_add': onlyAdmin}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update settings');
    }
  }

  static Future<List<dynamic>> searchUsers(String query) async {
    final response = await http.get(Uri.parse('$baseUrl/users/search?q=$query'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to search users');
    }
  }

  static Future<Map<String, dynamic>> startPersonalChat(int userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chats/personal'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_id': userId}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to start chat');
    }
  }

  static Future<void> kickMember(String chatId, String userId) async {
    final response = await http.delete(Uri.parse('$baseUrl/groups/$chatId/members/$userId'));
    if (response.statusCode != 200) {
      throw Exception('Failed to kick member');
    }
  }

  static Future<void> makeAdmin(String chatId, String userId) async {
    final response = await http.put(Uri.parse('$baseUrl/groups/$chatId/members/$userId/admin'));
    if (response.statusCode != 200) {
      throw Exception('Failed to make admin');
    }
  }

  static Future<void> leaveGroup(String chatId) async {
    final response = await http.post(Uri.parse('$baseUrl/groups/$chatId/leave'));
    if (response.statusCode != 200) {
      throw Exception('Failed to leave group');
    }
  }

  static Future<List<dynamic>> fetchInvitations() async {
    final response = await http.get(Uri.parse('$baseUrl/invitations'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load invitations');
    }
  }

  static Future<void> respondInvitation(String chatId, bool accept) async {
    final response = await http.post(
      Uri.parse('$baseUrl/invitations/$chatId/respond'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'accept': accept}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to respond to invitation');
    }
  }
}
