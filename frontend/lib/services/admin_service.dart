import 'api_service.dart';
import '../models/user_model.dart';

class AdminService {
  /// Mendapatkan daftar pengajuan creator, bisa difilter status
  static Future<List<CreatorApplication>> getApplications({String? status}) async {
    try {
      final response = await ApiService.get('admin/applications', queryParams: {
        'status': ?status,
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
}
