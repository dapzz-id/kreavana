import '../models/user_model.dart';
import 'api_service.dart';
import '../features/auth/services/auth_service.dart';

class ProfileFetchResult {
  final bool success;
  final String? message;
  final UserModel? user;
  final CreatorApplication? application;
  final List<String> userSubRoles;

  const ProfileFetchResult({
    required this.success,
    this.message,
    this.user,
    this.application,
    this.userSubRoles = const [],
  });
}

class ActionCommandResult {
  final bool success;
  final String? message;
  final UserModel? user;

  const ActionCommandResult({required this.success, this.message, this.user});
}

class ProfileService {
  /// Mendapatkan detail profil dan status aplikasi creator
  static Future<ProfileFetchResult> getProfile(String userId) async {
    // Jalankan request ke granular endpoints secara bersamaan
    final results = await Future.wait([
      ApiService.get('profile/identity'),
      ApiService.get('profile/application'),
    ]);

    final identityResponse = results[0];
    final applicationResponse = results[1];

    if (identityResponse['status'] == true) {
      final userData = identityResponse['data'];
      final user = UserModel.fromJson(userData);

      // Update session lokal jika data profil user berubah
      await AuthService.saveUserData(userData);

      CreatorApplication? app;
      if (applicationResponse['status'] == true &&
          applicationResponse['data'] != null) {
        app = CreatorApplication.fromJson(applicationResponse['data']);
      }

      return ProfileFetchResult(
        success: true,
        user: user,
        application: app,
        userSubRoles: List<String>.from(userData['user_subRoles'] ?? const []),
      );
    } else {
      return ProfileFetchResult(
        success: false,
        message: identityResponse['message'] ?? 'Gagal mengambil profil.',
      );
    }
  }

  /// Memperbarui informasi profil dasar
  static Future<ActionCommandResult> updateProfile({
    required String userId,
    String? name,
    String? phone,
    String? avatarUrl,
    String? selectedSubRole,
  }) async {
    final body = {
      'user_id': userId,
      'name': ?name,
      'phone': ?phone,
      'avatar_url': ?avatarUrl,
      'selected_sub_role': ?selectedSubRole,
    };

    final response = await ApiService.put('profile', body);

    if (response['status'] == true && response['data'] != null) {
      final userData =
          response['data'] is Map && response['data']['user'] != null
          ? response['data']['user'] as Map<String, dynamic>
          : response['data'] as Map<String, dynamic>;
      final user = UserModel.fromJson(userData);
      await AuthService.saveUserData(userData);
      return ActionCommandResult(success: true, user: user);
    } else {
      return ActionCommandResult(
        success: false,
        message: response['message'] ?? 'Gagal memperbarui profil.',
      );
    }
  }

  /// Mengajukan permohonan untuk menjadi Creator (verifikasi KTP + review admin)
  static Future<ActionCommandResult> applyAsCreator({
    required String userId,
    required String subRoleCategory,
    required String skillDescription,
    required String nik,
    required String fullNameKtp,
    required String addressKtp,
    required String ktpPhotoBase64,
    required String selfiePhotoBase64,
    required String birthPlace,
    required String birthDate,
    String? portfolioLink,
    String? experience,
  }) async {
    final body = {
      'user_id': userId,
      'sub_role_category': subRoleCategory,
      'skill_description': skillDescription,
      'nik': nik,
      'full_name_ktp': fullNameKtp,
      'address_ktp': addressKtp,
      'ktp_photo_url': ktpPhotoBase64,
      'selfie_photo_url': selfiePhotoBase64,
      'birth_place': birthPlace,
      'birth_date': birthDate,
      'portfolio_link': ?portfolioLink,
      'experience': ?experience,
    };

    final response = await ApiService.post('profile/apply-creator', body);

    if (response['status'] == true) {
      return const ActionCommandResult(success: true);
    } else {
      return ActionCommandResult(
        success: false,
        message: response['message'] ?? 'Gagal memproses pengajuan kreator.',
      );
    }
  }
}
