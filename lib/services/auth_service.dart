import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  /// Register user baru
  static Future<Map<String, dynamic>> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    final result = await ApiService.post('auth/register.php', {
      'name': name,
      'username': username,
      'email': email,
      'password': password,
    });
    return result;
  }

  /// Login dan simpan session
  static Future<Map<String, dynamic>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final result = await ApiService.post('auth/login.php', {
      'email': usernameOrEmail,
      'username': usernameOrEmail,
      'password': password,
    });

    if (result['success'] == true && result['data'] != null) {
      final data = result['data'];
      // Simpan token
      if (data['token'] != null) {
        await ApiService.saveToken(data['token']);
      }
      // Simpan user data
      if (data['user'] != null) {
        await ApiService.saveUserData(data['user']);
      }

      final user = UserModel.fromJson(data['user']);
      return {
        'success': true,
        'message': result['message'] ?? 'Login berhasil.',
        'user': user,
      };
    }

    return result;
  }

  /// Logout dan clear session
  static Future<void> logout() async {
    await ApiService.clearSession();
  }

  /// Cek apakah sudah login
  static Future<bool> isLoggedIn() async {
    return await ApiService.isLoggedIn();
  }

  /// Ambil user data lokal
  static Future<UserModel?> getCurrentUser() async {
    final data = await ApiService.getLocalUserData();
    if (data != null) {
      return UserModel.fromJson(data);
    }
    return null;
  }

  /// Update user data lokal setelah perubahan
  static Future<void> updateLocalUser(UserModel user) async {
    await ApiService.saveUserData(user.toJson());
  }
}
