import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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
    final result = await ApiService.post('auth/register', {
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
    final result = await ApiService.post('auth/login', {
      'email': usernameOrEmail,
      'password': password,
    });

    if (result['success'] == true && result['data'] != null) {
      final data = result['data'];
      
      // Simpan tokens dari Laravel JWT API
      await saveTokens(
        access: data['access_token'] ?? data['token'] ?? '',
        refresh: data['refresh_token'] ?? '',
        session: data['session_token'] ?? '',
      );

      // Simpan user data
      if (data['user'] != null) {
        await saveUserData(data['user']);
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
    // Optionally call logout endpoint
    await ApiService.post('auth/logout', {});
    await clearSession();
  }

  // Save tokens (Access, Refresh, Session)
  static Future<void> saveTokens({required String access, required String refresh, required String session}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', access); // Main token used in headers
    await prefs.setString('refresh_token', refresh);
    await prefs.setString('session_token', session);
  }

  // Save user data locally
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(userData));
  }

  // Get local user data
  static Future<Map<String, dynamic>?> getLocalUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('user_data');
    if (data != null) {
      return jsonDecode(data);
    }
    return null;
  }

  // Clear session
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('session_token');
    await prefs.remove('user_data');
  }

  /// Cek apakah sudah login
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('auth_token') &&
        prefs.getString('auth_token')!.isNotEmpty;
  }

  /// Ambil user data lokal
  static Future<UserModel?> getCurrentUser() async {
    final data = await getLocalUserData();
    if (data != null) {
      return UserModel.fromJson(data);
    }
    return null;
  }

  /// Update user data lokal setelah perubahan
  static Future<void> updateLocalUser(UserModel user) async {
    await saveUserData(user.toJson());
  }
}
