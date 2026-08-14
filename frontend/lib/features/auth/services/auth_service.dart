import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/user_model.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_session_state.dart';
import '../../../services/secure_storage_service.dart';
import '../../../services/realtime_service.dart';
import '../../../services/fcm_service.dart';
import '../../../services/encryption_service.dart';

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

    if (result['status'] == true && result['data'] != null) {
      final data = result['data'];
      final accessToken = data['access_token'];
      final refreshToken = data['refresh_token']; // Parse from JSON

      if (accessToken is! String || accessToken.isEmpty) {
        return {'success': false, 'message': 'Login gagal.'};
      }

      authSignedOutNotifier.value = false;
      await saveTokens(access: accessToken, refresh: refreshToken);

      Map<String, dynamic>? userDataToSave;

      if (data['user'] is Map<String, dynamic>) {
        userDataToSave = Map<String, dynamic>.from(data['user'] as Map);
      }

      final profileResult = await ApiService.get('profile/identity');
      if (profileResult['status'] == true && profileResult['data'] != null) {
        final pData = profileResult['data'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(profileResult['data'] as Map)
            : null;
        if (pData != null) {
          userDataToSave = {...?userDataToSave, ...pData};
        }
      }

      if (userDataToSave != null) {
        await saveUserData(userDataToSave);
        final user = UserModel.fromJson(userDataToSave);
        
        RealtimeService().init(user.id ?? '', accessToken);
        FCMService().init();
        
        // Initialize E2EE Keys
        EncryptionService().initializeKeys();
        
        return {
          'success': true,
          'message': result['message'] ?? 'Login berhasil.',
          'user': user,
        };
      }

      return {
        'success': false,
        'message': 'Login berhasil, tetapi profil pengguna gagal dimuat.',
      };
    }

    return result;
  }

  /// Logout dan clear session
  static Future<void> logout() async {
    try {
      await ApiService.post('auth/logout', {});
    } finally {
      RealtimeService().dispose();
      await clearSession();
    }
  }

  static Future<void> saveTokens({required String access, String? refresh}) async {
    final secureStorage = SecureStorageService();
    await secureStorage.saveToken(access);
    if (refresh != null && refresh.isNotEmpty) {
      await secureStorage.saveRefreshToken(refresh);
    }
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
    authSignedOutNotifier.value = true;
    final secureStorage = SecureStorageService();
    await secureStorage.clearTokens();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
  }

  /// Cek apakah sudah login
  static Future<bool> isLoggedIn() async {
    final secureStorage = SecureStorageService();
    final token = await secureStorage.getToken();
    return token != null && token.isNotEmpty;
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

  /// Ubah kata sandi user yang sedang login
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return ApiService.post('auth/user/change-password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  /// Tetapkan kata sandi awal untuk user baru dari social login
  static Future<Map<String, dynamic>> setInitialPassword({
    required String newPassword,
  }) async {
    return ApiService.post('auth/user/set-initial-password', {
      'password': newPassword,
    });
  }

  /// Social Login (Google, Apple, etc.)
  /// Backend harus punya endpoint POST /auth/social
  static Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String idToken,
    String? accessToken,
    String? email,
    String? name,
    String? photoUrl,
  }) async {
    final result = await ApiService.post('auth/social', {
      'provider': provider,
      'id_token': idToken,
      'access_token': accessToken,
      'email': email,
      'name': name,
      'photo_url': photoUrl,
    });

    if (result['status'] == true && result['data'] != null) {
      final data = result['data'];
      final token = data['access_token'];
      final refreshToken = data['refresh_token']; // Extract refresh token for social login
      final bool isNewUser = data['is_new_user'] == true;
      
      if (token is! String || token.isEmpty) {
        return {'success': false, 'message': 'Login gagal.'};
      }

      authSignedOutNotifier.value = false;
      await saveTokens(access: token, refresh: refreshToken);

      // Get profile
      Map<String, dynamic>? userDataToSave;
      final profileResult = await ApiService.get('profile/identity');
      if (profileResult['status'] == true && profileResult['data'] != null) {
        userDataToSave = profileResult['data'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(profileResult['data'] as Map)
            : null;
      }

      if (userDataToSave == null) {
        final meResult = await ApiService.get('auth/me');
        final meData = meResult['data'];
        if (meResult['status'] == true && meData is Map<String, dynamic>) {
          final user = meData['user'];
          if (user is Map<String, dynamic>) {
            userDataToSave = Map<String, dynamic>.from(user);
          }
        }
      }

      if (userDataToSave != null) {
        await saveUserData(userDataToSave);
        final user = UserModel.fromJson(userDataToSave);
        
        // Initialize E2EE Keys
        EncryptionService().initializeKeys();
        
        return {
          'success': true,
          'message': 'Login berhasil dengan $provider.',
          'user': user,
          'is_new_user': isNewUser,
        };
      }

      return {
        'success': false,
        'message': 'Login berhasil, tetapi profil gagal dimuat.',
      };
    }

    return {
      'success': false,
      'message': result['message'] ?? 'Login dengan $provider gagal.',
    };
  }
}
