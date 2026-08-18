import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../utils/app_errors.dart';
import 'auth_service.dart';

/// Service untuk Google Sign-In.
///
/// - **Web**: menggunakan Firebase Auth `signInWithPopup()` (modern, bebas iframe error).
/// - **Mobile (Android/iOS)**: menggunakan package `google_sign_in` seperti biasa.
class GoogleAuthService {
  // Mobile-only: ambil idToken dari Google Sign-In native
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Apakah platform ini mendukung Google Sign-In?
  static bool get isSupported =>
      kIsWeb || (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  /// Sign In dengan Google — otomatis pilih strategi berdasarkan platform.
  static Future<Map<String, dynamic>> signInWithGoogle() async {
    if (!isSupported) {
      return {
        'success': false,
        'message': 'Google Sign-In belum didukung di platform ini.',
      };
    }

    if (kIsWeb) {
      return _signInWithGoogleWeb();
    } else {
      return _signInWithGoogleMobile();
    }
  }

  // ---------------------------------------------------------------------------
  // Web: Firebase Auth signInWithPopup (modern OAuth, bukan GAPI iframe lama)
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> _signInWithGoogleWeb() async {
    try {
      final provider = GoogleAuthProvider();
      provider.addScope('email');
      provider.addScope('profile');

      // signInWithPopup membuka jendela popup login Google
      final userCredential = await FirebaseAuth.instance.signInWithPopup(
        provider,
      );

      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        return {'success': false, 'message': 'Login dibatalkan.'};
      }

      // Ambil ID token dari Firebase (berisi Google identity)
      final String? idToken = await firebaseUser.getIdToken();

      if (idToken == null || idToken.isEmpty) {
        return {
          'success': false,
          'message': 'Gagal mendapatkan token dari Google.',
        };
      }

      // Kirim ID token ke backend Laravel untuk validasi & pembuatan sesi
      final result = await AuthService.socialLogin(
        provider: 'google',
        idToken: idToken,
        email: firebaseUser.email ?? '',
        name:
            firebaseUser.displayName ??
            (firebaseUser.email ?? '').split('@').first,
        photoUrl: firebaseUser.photoURL,
      );

      // Sign out dari Firebase (sesi dikelola oleh backend Laravel, bukan Firebase)
      await FirebaseAuth.instance.signOut();

      return result;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return {'success': false, 'message': 'Login dibatalkan.'};
      }
      return {
        'success': false,
        'message': e.message ?? 'Login Google gagal. Coba lagi.',
      };
    } catch (error) {
      return {'success': false, 'message': AppErrors.friendly(error)};
    }
  }

  // ---------------------------------------------------------------------------
  // Mobile (Android / iOS): google_sign_in package (sudah terbukti bekerja)
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> _signInWithGoogleMobile() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return {'success': false, 'message': 'Login dibatalkan.'};
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
      return {'success': false, 'message': AppErrors.friendly(error)};
    }
  }

  // ---------------------------------------------------------------------------
  // Sign Out
  // ---------------------------------------------------------------------------
  static Future<void> signOut() async {
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signOut();
      } else {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      // silent
    }
  }

  static Future<bool> isSignedIn() async {
    try {
      if (!isSupported) return false;
      if (kIsWeb) {
        return FirebaseAuth.instance.currentUser != null;
      }
      return await _googleSignIn.isSignedIn();
    } catch (e) {
      return false;
    }
  }

  /// Silent sign-in untuk restore sesi (mobile only).
  static Future<Map<String, dynamic>> silentSignIn() async {
    if (!isSupported || kIsWeb) {
      return {'success': false, 'message': 'Tidak didukung di platform ini.'};
    }

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn
          .signInSilently();

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
      return {'success': false, 'message': AppErrors.friendly(error)};
    }
  }
}
