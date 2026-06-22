import '../models/user_model.dart';
import 'api_service.dart';
import 'auth_service.dart';

class ProfileService {
  /// Mendapatkan detail profil dan status aplikasi creator
  static Future<Map<String, dynamic>> getProfile(int userId) async {
    final response = await ApiService.get('profile', queryParams: {
      'user_id': userId.toString(),
    });

    if (response['success'] == true) {
      final data = response['data'];
      final user = UserModel.fromJson(data);
      
      // Update session lokal jika data profil user berubah
      await AuthService.saveUserData(data);

      CreatorApplication? app;
      if (data['application'] != null) {
        app = CreatorApplication.fromJson(data['application']);
      }

      return {
        'success': true,
        'user': user,
        'application': app,
        'user_pihaks': data['user_pihaks'] ?? [],
      };
    } else {
      return {
        'success': false,
        'message': response['message'] ?? 'Gagal mengambil profil.',
      };
    }
  }

  /// Memperbarui informasi profil dasar
  static Future<Map<String, dynamic>> updateProfile({
    required int userId,
    String? name,
    String? phone,
    String? avatarUrl,
    String? selectedPihak,
  }) async {
    final body = {
      'user_id': userId,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (selectedPihak != null) 'selected_pihak': selectedPihak,
    };

    final response = await ApiService.put('profile', body);

    if (response['success'] == true) {
      final user = UserModel.fromJson(response['data']);
      await AuthService.saveUserData(response['data']);
      return {
        'success': true,
        'user': user,
      };
    } else {
      return {
        'success': false,
        'message': response['message'] ?? 'Gagal memperbarui profil.',
      };
    }
  }

  /// Mengajukan permohonan untuk menjadi Creator (Auto-approved di backend untuk demo)
  static Future<Map<String, dynamic>> applyAsCreator({
    required int userId,
    required String pihakCategory,
    required String skillDescription,
    String? portfolioLink,
    String? experience,
  }) async {
    final body = {
      'user_id': userId,
      'pihak_category': pihakCategory,
      'skill_description': skillDescription,
      if (portfolioLink != null) 'portfolio_link': portfolioLink,
      if (experience != null) 'experience': experience,
    };

    final response = await ApiService.post('profile/apply-creator', body);

    if (response['success'] == true) {
      return {
        'success': true,
      };
    } else {
      return {
        'success': false,
        'message': response['message'] ?? 'Gagal memproses pengajuan kreator.',
      };
    }
  }
}
