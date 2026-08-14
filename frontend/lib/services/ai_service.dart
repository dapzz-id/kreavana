import 'package:flutter/material.dart';
import 'api_service.dart';
import '../widgets/upgrade_plan_modal.dart';

class AiService {
  /// Check if the error from backend is pro subscription entitlement error
  static bool isProSubscriptionRequiredError(dynamic result) {
    if (result is Map<String, dynamic>) {
      return result['error_code'] == 'pro_subscription_required' ||
          (result['message'] != null &&
              result['message'].toString().contains('Pro dan Super'));
    }
    return false;
  }

  /// Show the sleek upgrade plan modal when user attempts to use AI on Basic/Plus tier
  static void promptProUpgrade(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const UpgradePlanModal(),
    );
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
  }) async {
    try {
      final response = await ApiService.post('ai/recommendations', {
        'role': role,
        'niche': niche,
        'budget': budget,
      });
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Direct message AI copilot assistant (smart_reply, polish, summarize)
  static Future<Map<String, dynamic>?> messageAssistant({
    required String mode,
    String? message,
  }) async {
    try {
      final response = await ApiService.post('ai/message-assistant', {
        'mode': mode,
        'message': message,
      });
      return response;
    } catch (e) {
      return null;
    }
  }
}
