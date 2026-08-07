import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_service.dart';

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
    // clientId hanya digunakan di web; di mobile diambil dari google-services.json
    clientId: kIsWeb
        ? const String.fromEnvironment(
            'GOOGLE_WEB_CLIENT_ID',
            defaultValue: '',
          )
        : null,
    // serverClientId untuk backend verification (opsional)
    serverClientId: kIsWeb
        ? const String.fromEnvironment(
            'GOOGLE_WEB_CLIENT_ID',
            defaultValue: '',
          )
        : null,
  );

  /// Check if Google Sign-In is supported on this platform
  static bool get isSupported => kIsWeb || Platform.isAndroid || Platform.isIOS;

  static Future<Map<String, dynamic>> signInWithGoogle() async {
    if (!isSupported) {
      return {
        'success': false,
        'message': 'Google Sign-In belum didukung di platform ini.',
      };
    }

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return {'success': false, 'message': 'Login dibatalkan'};
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      if (idToken == null && accessToken == null) {
        return {
          'success': false,
          'message': 'Gagal mendapatkan token dari Google.',
        };
      }

      final result = await AuthService.socialLogin(
        provider: 'google',
        idToken: idToken ?? '',
        accessToken: accessToken,
        email: googleUser.email,
        name: googleUser.displayName ?? googleUser.email.split('@').first,
        photoUrl: googleUser.photoUrl,
      );

      return result;
    } catch (error) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan: ${error.toString()}',
      };
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {}
  }

  static Future<bool> isSignedIn() async {
    try {
      if (!isSupported) return false;
      return await _googleSignIn.isSignedIn();
    } catch (e) {
      return false;
    }
  }

  static Future<GoogleSignInAccount?> getCurrentUser() async {
    try {
      return _googleSignIn.currentUser;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> silentSignIn() async {
    if (!isSupported) {
      return {'success': false, 'message': 'Tidak didukung di platform ini.'};
    }

    try {
      final GoogleSignInAccount? googleUser =
          await _googleSignIn.signInSilently();

      if (googleUser == null) {
        return {'success': false, 'message': 'Tidak ada session Google.'};
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      if (idToken == null && accessToken == null) {
        return {'success': false, 'message': 'Gagal mendapatkan token.'};
      }

      final result = await AuthService.socialLogin(
        provider: 'google',
        idToken: idToken ?? '',
        accessToken: accessToken,
        email: googleUser.email,
        name: googleUser.displayName ?? googleUser.email.split('@').first,
        photoUrl: googleUser.photoUrl,
      );

      return result;
    } catch (error) {
      return {'success': false, 'message': 'Silent sign-in gagal.'};
    }
  }
}
