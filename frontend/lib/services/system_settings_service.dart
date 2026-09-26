import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class SystemSettingsService {
  SystemSettingsService._();

  static const String _cacheKey = 'cached_system_module_statuses';

  static const Map<String, bool> _defaultStatuses = {
    'direct_message_enabled': true,
    'voice_call_enabled': true,
    'video_call_enabled': true,
    'ai_features_enabled': true,
    'marketplace_enabled': true,
    'collaboration_enabled': true,
    'opportunities_enabled': true,
    'wallet_enabled': true,
    'client_verification_enabled': true,
    'user_registration_enabled': true,
    'creator_registration_enabled': true,
    'maintenance_mode': false,
  };

  /// Global notifier yang bisa di-listen oleh UI (Sidebar, Router, Screen, dll)
  static final ValueNotifier<Map<String, bool>> moduleStatuses =
      ValueNotifier<Map<String, bool>>(Map.from(_defaultStatuses));

  static bool get isDirectMessageEnabled =>
      moduleStatuses.value['direct_message_enabled'] ?? true;

  static bool get isVoiceCallEnabled =>
      moduleStatuses.value['voice_call_enabled'] ?? true;

  static bool get isVideoCallEnabled =>
      moduleStatuses.value['video_call_enabled'] ?? true;

  static bool get isMarketplaceEnabled =>
      moduleStatuses.value['marketplace_enabled'] ?? true;

  static bool get isAiEnabled =>
      moduleStatuses.value['ai_features_enabled'] ?? true;

  static bool get isCollaborationEnabled =>
      moduleStatuses.value['collaboration_enabled'] ?? true;

  static bool get isOpportunitiesEnabled =>
      moduleStatuses.value['opportunities_enabled'] ?? true;

  static bool get isWalletEnabled =>
      moduleStatuses.value['wallet_enabled'] ?? true;

  static bool get isClientVerificationEnabled =>
      moduleStatuses.value['client_verification_enabled'] ?? true;

  static bool get isUserRegistrationEnabled =>
      moduleStatuses.value['user_registration_enabled'] ?? true;

  static bool get isCreatorRegistrationEnabled =>
      moduleStatuses.value['creator_registration_enabled'] ?? true;

  static bool get isMaintenanceMode =>
      moduleStatuses.value['maintenance_mode'] ?? false;

  /// Memuat status dari cache lokal terlebih dahulu, lalu sinkronisasi ke server
  static Future<void> loadModuleStatuses({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(cachedJson);
        final Map<String, bool> cached = Map.from(_defaultStatuses);
        decoded.forEach((k, v) {
          if (v is bool) cached[k] = v;
        });
        moduleStatuses.value = cached;
      }
    } catch (_) {}

    try {
      final response = await ApiService.get('system/module-statuses');
      if (response['status'] == true && response['data'] is Map) {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(response['data']);
        final Map<String, bool> updated = Map.from(moduleStatuses.value);
        data.forEach((k, v) {
          if (v is bool) {
            updated[k] = v;
          } else if (v is num) {
            updated[k] = v == 1;
          }
        });
        moduleStatuses.value = updated;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(updated));
      }
    } catch (_) {}
  }

  /// Update lokal saat admin mengubah toggle di dashboard pengaturan
  static void updateLocalModule(String key, bool enabled) {
    final updated = Map<String, bool>.from(moduleStatuses.value);
    updated[key] = enabled;
    moduleStatuses.value = updated;

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_cacheKey, jsonEncode(updated));
    }).catchError((_) {});
  }
}
