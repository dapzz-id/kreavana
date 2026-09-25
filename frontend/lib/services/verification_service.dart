import 'api_service.dart';
import '../models/user_model.dart';

class VerificationStatusData {
  final bool isVerified;
  final String? verificationType;
  final String? verifiedAt;
  final bool hasPending;
  final CreatorApplication? pendingApplication;
  final CreatorApplication? latestApplication;
  final bool canReuseKtp;
  final Map<String, dynamic>? reusableKtp;

  VerificationStatusData({
    required this.isVerified,
    this.verificationType,
    this.verifiedAt,
    required this.hasPending,
    this.pendingApplication,
    this.latestApplication,
    this.canReuseKtp = false,
    this.reusableKtp,
  });

  factory VerificationStatusData.fromJson(Map<String, dynamic> json) {
    return VerificationStatusData(
      isVerified: json['is_verified'] == true || json['is_verified'] == 1,
      verificationType: json['verification_type']?.toString(),
      verifiedAt: json['verified_at']?.toString(),
      hasPending: json['has_pending'] == true,
      pendingApplication: json['pending_application'] != null
          ? CreatorApplication.fromJson(json['pending_application'])
          : null,
      latestApplication: json['latest_application'] != null
          ? CreatorApplication.fromJson(json['latest_application'])
          : null,
      canReuseKtp: json['can_reuse_ktp'] == true,
      reusableKtp: json['reusable_ktp'] != null
          ? Map<String, dynamic>.from(json['reusable_ktp'])
          : null,
    );
  }
}

class VerificationService {
  /// Mendapatkan status verifikasi pengguna saat ini
  static Future<VerificationStatusData?> getStatus() async {
    try {
      final res = await ApiService.get('verification/status');
      if (res['status'] == true && res['data'] != null) {
        return VerificationStatusData.fromJson(res['data']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Mengajukan verifikasi KTP untuk klien (tidak upgrade ke creator)
  static Future<Map<String, dynamic>> applyClientVerification({
    required String nik,
    required String fullNameKtp,
    String? birthPlace,
    String? birthDate,
    String? addressKtp,
    required String ktpPhotoBase64,
    String? selfiePhotoBase64,
  }) async {
    try {
      final response = await ApiService.post('verification/client', {
        'nik': nik,
        'full_name_ktp': fullNameKtp,
        'birth_place': birthPlace,
        'birth_date': birthDate,
        'address_ktp': addressKtp,
        'ktp_photo_url': ktpPhotoBase64,
        'selfie_photo_url': selfiePhotoBase64,
      });
      return response;
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  /// Mengambil profil publik pengguna (kreator atau klien)
  static Future<Map<String, dynamic>?> getPublicProfile(String userId) async {
    try {
      final res = await ApiService.get('users/$userId/profile');
      if (res['status'] == true && res['data'] != null) {
        return Map<String, dynamic>.from(res['data']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
