import 'api_service.dart';
import '../models/user_model.dart';

class AdminService {
  /// Mendapatkan daftar pengajuan creator, bisa difilter status
  static Future<List<CreatorApplication>> getApplications({String? status}) async {
    try {
      final response = await ApiService.get('admin/applications', queryParams: {
        'status': status,
      });

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
      final response = await ApiService.post('admin/applications/$id/approve', {});
      return response;
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Menolak pengajuan creator dengan alasan
  static Future<Map<String, dynamic>> rejectApplication(String id, String note) async {
    try {
      final response = await ApiService.post('admin/applications/$id/reject', {
        'admin_note': note,
      });
      return response;
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
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
}
