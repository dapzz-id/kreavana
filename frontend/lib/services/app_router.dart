import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/email_verification_screen.dart';
import '../screens/main_navigation.dart';
import '../screens/landing_page_screen.dart';
import '../models/user_model.dart';
import 'user_store.dart';
import 'auth_session_state.dart';
// navigatorKey didefinisikan di main.dart dan di-share ke GoRouter
import 'navigator_key.dart';

/// Semua path URL aplikasi Kreavana.
///
/// Di Web, URL di browser akan berubah sesuai tab/halaman yang aktif.
/// Di Mobile, routing ini tetap bekerja tapi URL tidak terlihat oleh user.
class AppRoutes {
  static const landing = '/';
  static const login = '/login';
  static const register = '/register';
  static const beranda = '/beranda';
  static const explore = '/explore';
  static const proyek = '/proyek';
  static const portfolio = '/portfolio';
  static const marketplaceKarya = '/marketplace-karya';
  static const agenda = '/agenda';
  static const kolaborasi = '/kolaborasi';
  static const reputasi = '/reputasi';
  static const wallet = '/wallet';
  static const pengaturan = '/pengaturan';
  static const profil = '/profil';
  static const notifikasi = '/notifikasi';
  static const pesan = '/pesan';
  static const adminDashboard = '/dashboard';
  static const adminVerification = '/verifikasi';
  static const adminResolution = '/resolusi';
  static const verifyEmail = '/verify-email';
  static const peluangProyek = '/peluang-proyek';
}

const _routeIndexMap = {
  AppRoutes.beranda: 0,
  AppRoutes.explore: 1,
  AppRoutes.proyek: 2,
  AppRoutes.marketplaceKarya: 3,
  AppRoutes.agenda: 4,
  AppRoutes.kolaborasi: 5,
  AppRoutes.reputasi: 6,
  AppRoutes.wallet: 7,
  AppRoutes.pengaturan: 8,
  AppRoutes.profil: 9,
  AppRoutes.notifikasi: 10,
  AppRoutes.pesan: 11,
  AppRoutes.peluangProyek: 12,
};

const _adminRouteIndexMap = {
  AppRoutes.adminDashboard: 0,
  AppRoutes.adminVerification: 1,
  AppRoutes.adminResolution: 2,
  AppRoutes.notifikasi: 3,
  AppRoutes.profil: 4,
};

/// Route-route yang dapat diakses oleh publik/tamu tanpa login.
const _publicRoutes = [
  AppRoutes.landing,
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.verifyEmail,
  AppRoutes.beranda,
  AppRoutes.explore,
  AppRoutes.peluangProyek,
  AppRoutes.marketplaceKarya,
];

/// GoRouter instance global aplikasi.
final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: AppRoutes.login,
  debugLogDiagnostics: kDebugMode,
  refreshListenable: Listenable.merge([
    currentUserNotifier,
    authSignedOutNotifier,
  ]),
  redirect: (context, state) {
    final user = currentUserNotifier.value;
    final isSignedOut = authSignedOutNotifier.value;
    final currentPath = state.matchedLocation;
    final isPublic = _publicRoutes.contains(currentPath);

    // Belum login & mencoba akses halaman terlindungi → redirect ke /login
    if ((user == null || isSignedOut) && !isPublic) {
      return AppRoutes.login;
    }

    // Sudah login & membuka halaman login/register → arahkan ke beranda
    if (user != null && !isSignedOut && (currentPath == AppRoutes.login || currentPath == AppRoutes.register)) {
      return AppRoutes.beranda;
    }

    return null; // Tidak ada redirect
  },
  routes: [
    // ── Public Landing Page ──────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.landing,
      name: 'landing',
      builder: (context, state) {
        final user = currentUserNotifier.value;
        final isSignedOut = authSignedOutNotifier.value;
        if (user != null && !isSignedOut) {
          return MainNavigation(initialUser: user, initialIndex: 0);
        }
        return const LandingPageScreen();
      },
    ),

    // ── Auth routes ─────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: AppRoutes.verifyEmail,
      name: 'verify-email',
      redirect: (context, state) {
        final extra = state.extra;
        if (extra == null) return AppRoutes.login;
        if (extra is String && extra.isEmpty) return AppRoutes.login;
        if (extra is Map &&
            (extra['email'] == null || (extra['email'] as String).isEmpty)) {
          return AppRoutes.login;
        }
        if (extra is! String && extra is! Map) return AppRoutes.login;
        return null;
      },
      builder: (context, state) {
        final extra = state.extra;
        if (extra is Map) {
          return EmailVerificationScreen(
            email: extra['email'] as String,
            autoResend: extra['autoResend'] == true,
          );
        }
        return EmailVerificationScreen(email: extra as String);
      },
    ),

    // ── Main routes (mendukung user terautentikasi dan guest browsing) ───
    ...{..._routeIndexMap.keys, ..._adminRouteIndexMap.keys}.map(
      (path) => GoRoute(
        path: path,
        builder: (context, state) {
          final user = currentUserNotifier.value ?? UserModel.guest();
          final initialIndex = user.isAdmin
              ? (_adminRouteIndexMap[path] ?? 0)
              : (_routeIndexMap[path] ?? 0);
          return MainNavigation(initialUser: user, initialIndex: initialIndex);
        },
      ),
    ),
  ],
);
