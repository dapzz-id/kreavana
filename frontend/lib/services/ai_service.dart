import 'package:flutter/material.dart';
import 'api_service.dart';
import '../widgets/upgrade_plan_modal.dart';

class AiService {
  /// Check if the error from backend is pro subscription entitlement error
  static bool isProSubscriptionRequiredError(dynamic result) {
    if (result is Map<String, dynamic>) {
      return result['error_code'] == 'pro_subscription_required' ||
          (result['message'] != null &&
              (result['message'].toString().contains('Plus, Pro') ||
                  result['message'].toString().contains('Pro dan Super') ||
                  result['message'].toString().contains('Paket Plus')));
    }
    return false;
  }

  /// Show the sleek upgrade plan modal when user attempts to use AI on Basic tier
  static void promptProUpgrade(BuildContext context) {
    UpgradePlanModal.show(context);
  }

  /// Summarize report or project content
  static Future<Map<String, dynamic>?> summarizeReport({
    String? title,
    String? content,
    String? description,
    String? context,
  }) async {
    try {
      final response = await ApiService.post('ai/summarize-report', {
        'title': title,
        'content': content,
        'description': description,
        'context': context,
      });
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Get smart AI recommendations for dashboard / opportunities
  static Future<Map<String, dynamic>?> getRecommendations({
    String? role,
    String? niche,
    String? budget,
    String? subRole,
    String? location,
    double? lat,
    double? lng,
  }) async {
    try {
      final response = await ApiService.post('ai/recommendations', {
        'role': role,
        'niche': niche,
        'budget': budget,
        if (subRole != null && subRole.isNotEmpty) 'sub_role': subRole,
        if (location != null && location.isNotEmpty) 'location': location,
        'lat': ?lat,
        'lng': ?lng,
      });
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Direct message AI copilot assistant (smart_reply, polish, summarize, chat)
  static Future<Map<String, dynamic>?> messageAssistant({
    required String mode,
    String? message,
    String? category,
    bool includeDataKreavana = true,
  }) async {
    try {
      final response = await ApiService.post('ai/message-assistant', {
        'mode': mode,
        'message': message,
        'category': category,
        'include_data_kreavana': includeDataKreavana,
      });
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Get all saved AI chat sessions for current authenticated user
  static Future<List<Map<String, dynamic>>> getChatSessions() async {
    try {
      final response = await ApiService.get('ai/chat-sessions');
      if (response['status'] == true && response['data'] is List) {
        return List<Map<String, dynamic>>.from(
          (response['data'] as List).map((e) => Map<String, dynamic>.from(e)),
        );
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Sync/Save a chat session to the user's account in backend
  static Future<bool> syncChatSession({
    required String sessionId,
    required String title,
    required List<Map<String, dynamic>> messages,
  }) async {
    try {
      final response = await ApiService.post('ai/chat-sessions', {
        'session_id': sessionId,
        'title': title,
        'messages': messages,
      });
      return response['status'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a chat session from user's account
  static Future<bool> deleteChatSession(String sessionId) async {
    try {
      final response = await ApiService.delete('ai/chat-sessions/$sessionId');
      return response['status'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Clear all chat sessions from user's account
  static Future<bool> clearChatSessions() async {
    try {
      final response = await ApiService.delete('ai/chat-sessions');
      return response['status'] == true;
    } catch (e) {
      return false;
    }
  }
}
