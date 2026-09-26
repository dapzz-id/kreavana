import 'api_service.dart';
import 'system_settings_service.dart';
import '../models/user_model.dart';

class AdminService {
  /// Mendapatkan daftar pengajuan creator, bisa difilter status
  static Future<List<CreatorApplication>> getApplications({
    String? status,
  }) async {
    try {
      final response = await ApiService.get(
        'admin/applications',
        queryParams: {'status': status},
      );

      if (response['status'] == true) {
        final List<dynamic> list = response['data'] ?? [];
        return list.map((json) => CreatorApplication.fromJson(json)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Menyetujui pengajuan creator
  static Future<Map<String, dynamic>> approveApplication(String id) async {
    try {
      final response = await ApiService.post(
        'admin/applications/$id/approve',
        {},
      );
      return response;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Menolak pengajuan creator dengan alasan
  static Future<Map<String, dynamic>> rejectApplication(
    String id,
    String note,
  ) async {
    try {
      final response = await ApiService.post('admin/applications/$id/reject', {
        'admin_note': note,
      });
      return response;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<List<Map<String, dynamic>>> getSystemLogs() async {
    try {
      final response = await ApiService.get('admin/system-logs');
      if (response['status'] == true) {
        return List<Map<String, dynamic>>.from(response['data'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAssignedDisputes() async {
    try {
      final response = await ApiService.get('admin/assigned-disputes');
      if (response['status'] == true) {
        return List<Map<String, dynamic>>.from(response['data'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> decideRefund(
    String disputeId,
    String decision,
    String notes,
    double? refundAmount,
  ) async {
    try {
      final response =
          await ApiService.post('disputes/$disputeId/decision-refund', {
            'decision': decision,
            'notes': notes,
            if (refundAmount != null) 'refund_amount': refundAmount,
          });
      return response;
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> decideCancellation(
    String disputeId,
    String decision,
    String notes,
  ) async {
    try {
      final response = await ApiService.post(
        'disputes/$disputeId/decision-cancellation',
        {'decision': decision, 'notes': notes},
      );
      return response;
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  /// Mengambil daftar modul sistem dan status aktif/nonaktifnya
  static Future<List<Map<String, dynamic>>> getModules() async {
    try {
      final response = await ApiService.get('admin/modules');
      if (response['status'] == true && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Mengubah status aktif/nonaktif sebuah modul
  static Future<Map<String, dynamic>> updateModule(
    String key,
    bool enabled,
  ) async {
    try {
      final response = await ApiService.put('admin/modules/$key', {
        'enabled': enabled,
      });
      if (response['status'] == true) {
        SystemSettingsService.updateLocalModule(key, enabled);
      }
      return response;
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  /// Mengambil konfigurasi AI Engine aktif
  static Future<Map<String, dynamic>?> getAiConfig() async {
    try {
      final response = await ApiService.get('admin/ai-config');
      if (response['status'] == true && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Memperbarui konfigurasi AI Engine (Provider, API Key, Model, Suhu, dll)
  static Future<Map<String, dynamic>> updateAiConfig({
    required String provider,
    String? apiKey,
    required String model,
    double? temperature,
    int? maxTokens,
    String? systemPrompt,
    String? customEndpoint,
  }) async {
    try {
      final response = await ApiService.post('admin/ai-config', {
        'provider': provider,
        if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
        'model': model,
        if (temperature != null) 'temperature': temperature,
        if (maxTokens != null) 'max_tokens': maxTokens,
        if (systemPrompt != null) 'system_prompt': systemPrompt,
        if (customEndpoint != null) 'custom_endpoint': customEndpoint,
      });
      return response;
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  /// Menguji koneksi AI ke provider yang dipilih
  static Future<Map<String, dynamic>> testAiConnection({
    required String provider,
    required String model,
    String? apiKey,
    String? customEndpoint,
  }) async {
    try {
      final response = await ApiService.post('admin/ai-config/test', {
        'provider': provider,
        'model': model,
        if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
        if (customEndpoint != null && customEndpoint.isNotEmpty)
          'custom_endpoint': customEndpoint,
      });
      return response;
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }
}
