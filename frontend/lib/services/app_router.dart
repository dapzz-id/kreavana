import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../screens/main_navigation.dart';
import 'user_store.dart';
import 'auth_session_state.dart';
// navigatorKey didefinisikan di main.dart dan di-share ke GoRouter
import 'navigator_key.dart';

/// Semua path URL aplikasi Kreavana.
///
/// Di Web, URL di browser akan berubah sesuai tab/halaman yang aktif.
/// Di Mobile, routing ini tetap bekerja tapi URL tidak terlihat oleh user.
class AppRoutes {
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
};

const _adminRouteIndexMap = {
  AppRoutes.adminDashboard: 0,
  AppRoutes.adminVerification: 1,
  AppRoutes.adminResolution: 2,
  AppRoutes.notifikasi: 3,
  AppRoutes.profil: 4,
};

/// Route-route yang tidak memerlukan autentikasi.
const _publicRoutes = [AppRoutes.login, AppRoutes.register];

/// GoRouter instance global aplikasi.
final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: AppRoutes.beranda,
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

    // Belum login → paksa ke /login (kecuali sudah di halaman public)
    if ((user == null || isSignedOut) && !isPublic) {
      return AppRoutes.login;
    }

    // Sudah login → jangan biarkan akses /login atau /register
    if (user != null && !isSignedOut && isPublic) {
      return AppRoutes.beranda;
    }

    return null; // Tidak ada redirect
  },
  routes: [
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

    // ── Authenticated routes (semua via MainNavigation) ──────────────────
    ...{..._routeIndexMap.keys, ..._adminRouteIndexMap.keys}.map(
      (path) => GoRoute(
        path: path,
        builder: (context, state) {
          final user = currentUserNotifier.value!;
          final initialIndex = user.isAdmin 
              ? (_adminRouteIndexMap[path] ?? 0)
              : (_routeIndexMap[path] ?? 0);
          return MainNavigation(
            initialUser: user,
            initialIndex: initialIndex,
          );
        },
      ),
    ),

    // ── Root redirect ────────────────────────────────────────────────────
    GoRoute(
      path: '/',
      redirect: (_, __) =>
          currentUserNotifier.value != null ? AppRoutes.beranda : AppRoutes.login,
    ),
  ],
);
