import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/email_verification_screen.dart';
import '../features/auth/services/auth_service.dart';
import '../screens/main_navigation.dart';
import '../models/user_model.dart';
import '../screens/public_profile_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/institution_workspace_screen.dart';
import '../screens/tim_hak_akses_screen.dart';
import '../screens/corporate_lowongan_screen.dart';
import '../screens/corporate_vacancy_detail_screen.dart';
import '../screens/buat_kebutuhan_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/detail_kebutuhan_screen.dart';
import '../screens/marketplace_detail_screen.dart';
import '../screens/jual_karya_screen.dart';
import '../screens/topup_screen.dart';
import '../screens/withdraw_screen.dart';
import '../screens/transfer_screen.dart';
import '../screens/wallet_history_screen.dart';
import '../screens/kyc_verification_screen.dart';
import '../screens/client_verification_page.dart';
import '../screens/creator_application_page.dart';
import '../screens/addresses_screen.dart';
import '../screens/payment_methods_screen.dart';
import '../screens/storage_management_screen.dart';
import '../screens/help_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/creator_calendar_screen.dart';
import '../services/opportunity_service.dart';
import '../models/opportunity_model.dart';
import '../models/marketplace_item.dart';
import 'user_store.dart';
import 'system_settings_service.dart';
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
  static const adminSystemSettings = '/admin-settings';
  static const verifyEmail = '/verify-email';
  static const peluangProyek = '/peluang-proyek';
  static const kapasitasJadwal = '/kapasitas-jadwal';
  static const aiAssistant = '/ai';

  // Institusi Pendidikan / Sekolah / Kampus
  static const profilAkun = '/profil-akun';
  static const profilInstitusi = '/profil-institusi';
  static const timHakAkses = '/tim-hak-akses';
  static const dokumenInstitusi = '/dokumen-institusi';
  static const pengumumanInstitusi = '/pengumuman-institusi';
  static const monitoringEvaluasi = '/monitoring-evaluasi';
  static const laporanKegiatan = '/laporan-kegiatan';
  static const karyaSiswa = '/karya-siswa';
  static const mitraIndustri = '/mitra-industri';
  static const realisasiAnggaran = '/realisasi-anggaran';

  // Corporate / Perusahaan
  static const lowonganCorporate = '/lowongan-corporate';
  static const detailLowonganCorporate = '/lowongan-corporate/detail';
  static const pengadaanVendor = '/pengadaan-vendor';

  // Halaman 404 & Akses Dibatasi
  static const notFound = '/404';

  // Kebutuhan Proyek & Sub-Halaman
  static const buatKebutuhan = '/buat-kebutuhan';
  static const detailProyek = '/proyek/:id';

  // Marketplace & Jual Karya
  static const detailMarketplace = '/marketplace-karya/:id';
  static const jualKarya = '/jual-karya';

  // Dompet / Wallet Sub-Halaman
  static const walletTopup = '/wallet/topup';
  static const walletWithdraw = '/wallet/withdraw';
  static const walletTransfer = '/wallet/transfer';
  static const walletHistory = '/wallet/riwayat';

  // Verifikasi & Pengajuan Kreator
  static const verifikasiKyc = '/verifikasi-identitas';
  static const verifikasiKlien = '/verifikasi-klien';
  static const daftarKreator = '/daftar-kreator';

  // Pengaturan & Bantuan
  static const pengaturanAlamat = '/pengaturan/alamat';
  static const pengaturanPembayaran = '/pengaturan/metode-pembayaran';
  static const pengaturanPenyimpanan = '/pengaturan/penyimpanan';
  static const bantuan = '/bantuan';
  static const kebijakanPrivasi = '/kebijakan-privasi';

  // Agenda & Kalender
  static const creatorCalendar = '/agenda/kalender';

  /// Index → URL mapping untuk pengguna reguler / kreator / klien
  static const Map<int, String> indexRouteMap = {
    0: AppRoutes.beranda,
    1: AppRoutes.explore,
    2: AppRoutes.proyek,
    3: AppRoutes.marketplaceKarya,
    4: AppRoutes.agenda,
    5: AppRoutes.kolaborasi,
    6: AppRoutes.reputasi,
    7: AppRoutes.wallet,
    8: AppRoutes.pengaturan,
    9: AppRoutes.profil,
    10: AppRoutes.notifikasi,
    11: AppRoutes.pesan,
    12: AppRoutes.peluangProyek,
    13: AppRoutes.kapasitasJadwal,
    14: AppRoutes.aiAssistant,
  };

  /// Index → URL mapping untuk akun administrator
  static const Map<int, String> adminIndexRouteMap = {
    0: AppRoutes.adminDashboard,
    1: AppRoutes.adminVerification,
    2: AppRoutes.adminResolution,
    3: AppRoutes.adminSystemSettings,
    4: AppRoutes.notifikasi,
    5: AppRoutes.profil,
  };

  /// Dapatkan path URL route dari index MainNavigation
  static String getRouteForIndex(int index, {bool isAdmin = false}) {
    if (isAdmin) {
      return adminIndexRouteMap[index] ?? AppRoutes.adminDashboard;
    }
    return indexRouteMap[index] ?? AppRoutes.beranda;
  }
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
  AppRoutes.kapasitasJadwal: 13,
  AppRoutes.aiAssistant: 14,
};

const _adminRouteIndexMap = {
  AppRoutes.adminDashboard: 0,
  AppRoutes.adminVerification: 1,
  AppRoutes.adminResolution: 2,
  AppRoutes.adminSystemSettings: 3,
  AppRoutes.notifikasi: 4,
  AppRoutes.profil: 5,
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
  AppRoutes.aiAssistant,
  AppRoutes.notFound,
  AppRoutes.bantuan,
  AppRoutes.kebijakanPrivasi,
];

/// GoRouter instance global aplikasi.
final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: AppRoutes.beranda,
  debugLogDiagnostics: kDebugMode,
  refreshListenable: Listenable.merge([
    currentUserNotifier,
    authSignedOutNotifier,
    SystemSettingsService.moduleStatuses,
  ]),
  errorBuilder: (context, state) {
    final user = currentUserNotifier.value ?? UserModel.guest();
    return NotFoundScreen(
      user: user,
      path: state.uri.toString(),
    );
  },
  redirect: (context, state) {
    final user = currentUserNotifier.value;
    final isSignedOut = authSignedOutNotifier.value;
    final currentPath = state.matchedLocation;
    final isPublic = _publicRoutes.contains(currentPath);
    final isAdmin = user != null && user.isAdmin;

    // Halaman 404 selalu diizinkan tampil apa adanya
    if (currentPath == AppRoutes.notFound) return null;

    // Belum login & mencoba akses halaman terlindungi via URL bar → redirect ke /login
    if ((user == null || isSignedOut || user.isGuest) && !isPublic) {
      return AppRoutes.login;
    }

    // Sudah login & membuka halaman login/register → arahkan ke beranda
    if (user != null &&
        !isSignedOut &&
        (currentPath == AppRoutes.login || currentPath == AppRoutes.register)) {
      return AppRoutes.beranda;
    }

    // Legacy URL aliases / redirect
    if (currentPath == '/profil-sekolah') return AppRoutes.profilInstitusi;
    if (currentPath == '/lowongan-magang' || currentPath == '/lowongan') {
      return AppRoutes.lowonganCorporate;
    }
    if (currentPath == '/dokumen') return AppRoutes.dokumenInstitusi;
    if (currentPath == '/laporan') return AppRoutes.laporanKegiatan;
    if (currentPath == '/mitra-komunitas' || currentPath == '/mitra') {
      return AppRoutes.mitraIndustri;
    }
    if (currentPath == '/tender-kolaborasi' || currentPath == '/tenders') {
      return AppRoutes.pengadaanVendor;
    }
    if (currentPath == '/pengumuman' || currentPath == '/pengumuman-publik') {
      return AppRoutes.pengumumanInstitusi;
    }

    // Proteksi module jika dinonaktifkan oleh administrator (non-admin dialihkan ke beranda)
    if (!isAdmin) {
      if (currentPath == AppRoutes.marketplaceKarya &&
          !SystemSettingsService.isMarketplaceEnabled) {
        return AppRoutes.beranda;
      }
      if (currentPath == AppRoutes.aiAssistant &&
          !SystemSettingsService.isAiEnabled) {
        return AppRoutes.beranda;
      }
      final isCreator = user != null &&
          !user.isClient &&
          (user.role == 'creator' || user.isCreator);
      if (currentPath == AppRoutes.kolaborasi &&
          (!SystemSettingsService.isCollaborationEnabled || !isCreator)) {
        return AppRoutes.beranda;
      }
      if (currentPath == AppRoutes.wallet &&
          !SystemSettingsService.isWalletEnabled) {
        return AppRoutes.beranda;
      }
    }

    // ── RBAC & Route Permission Guards ──────────────────────────────────
    // 1. Rute Khusus Administrator
    const adminOnlyRoutes = [
      AppRoutes.adminDashboard,
      AppRoutes.adminVerification,
      AppRoutes.adminResolution,
      AppRoutes.adminSystemSettings,
    ];
    if (!isAdmin && adminOnlyRoutes.contains(currentPath)) {
      return AppRoutes.beranda;
    }

    // 2. Rute Khusus Institusi Pendidikan / Sekolah
    // Profil Institusi & Karya Siswa hanya untuk institusi/sekolah atau admin
    if (!isAdmin) {
      final isInst = user != null && user.isInstitution;
      if ((currentPath == AppRoutes.profilInstitusi || currentPath == AppRoutes.karyaSiswa) && !isInst) {
        return currentPath == AppRoutes.profilInstitusi ? AppRoutes.profil : AppRoutes.beranda;
      }

      // Pengadaan & Vendor DILARANG untuk Institusi (khusus Corporate / Pemerintah)
      if (currentPath == AppRoutes.pengadaanVendor && isInst) {
        return AppRoutes.beranda;
      }
    }

    // 3. Rute Khusus Corporate / Perusahaan & Pemerintah
    if (!isAdmin) {
      final isCorp = user != null && user.isCorporate;
      final isGov = user != null && user.isGovernment;
      if ((currentPath == AppRoutes.lowonganCorporate ||
              currentPath == AppRoutes.detailLowonganCorporate) &&
          !isCorp) {
        return AppRoutes.beranda;
      }
      if (currentPath == AppRoutes.pengadaanVendor && !(isCorp || isGov)) {
        return AppRoutes.beranda;
      }
    }

    // 4. Rute Khusus Organisasi Resmi (Institusi, Corporate, Government, Admin)
    const orgRoutes = [
      AppRoutes.timHakAkses,
      AppRoutes.dokumenInstitusi,
      AppRoutes.pengumumanInstitusi,
      AppRoutes.monitoringEvaluasi,
      AppRoutes.laporanKegiatan,
      AppRoutes.mitraIndustri,
      AppRoutes.realisasiAnggaran,
    ];
    if (!isAdmin && orgRoutes.contains(currentPath)) {
      final isOrg = user != null && (user.isInstitution || user.isCorporate || user.isGovernment);
      if (!isOrg) {
        return AppRoutes.beranda;
      }
    }

    // 5. Rute Explore & Peluang Proyek DILARANG untuk Institusi Pendidikan & Corporate (Perusahaan)
    // Sesuai aturan arsitektur: role yang tidak memiliki fitur Explore tidak boleh mengakses URL tersebut
    if (!isAdmin && user != null && !user.isGuest) {
      if (currentPath == AppRoutes.explore || currentPath == AppRoutes.peluangProyek) {
        if (user.isInstitution || user.isCorporate) {
          return AppRoutes.notFound;
        }
      }
    }

    return null; // Tidak ada redirect
  },
  routes: [
    // ── Public Landing / Beranda ─────────────────────────────────────────
    GoRoute(
      path: AppRoutes.landing,
      name: 'landing',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return MainNavigation(initialUser: user, initialIndex: 0);
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
    ...{..._routeIndexMap.keys, ..._adminRouteIndexMap.keys}
        .where((path) => path != AppRoutes.profil)
        .map(
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

    // ── Route Profil (khusus: jika ada query ?id=, buka profil publik pengguna tersebut) ───
    GoRoute(
      path: AppRoutes.profil,
      builder: (context, state) {
        final targetId = state.uri.queryParameters['id'];
        final user = currentUserNotifier.value ?? UserModel.guest();
        if (targetId != null &&
            targetId.isNotEmpty &&
            (user.isGuest || targetId != user.id)) {
          return PublicProfileScreen(
            userId: targetId,
            currentUser: user,
          );
        }
        final initialIndex = user.isAdmin
            ? (_adminRouteIndexMap[AppRoutes.profil] ?? 0)
            : (_routeIndexMap[AppRoutes.profil] ?? 0);
        return MainNavigation(initialUser: user, initialIndex: initialIndex);
      },
    ),

    // ── Dedicated Standalone Pages with RBAC ─────────────────────────────
    GoRoute(
      path: AppRoutes.profilAkun,
      name: 'profil-akun',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return ProfileScreen(
          user: user,
          onUserUpdated: (u) => currentUserNotifier.value = u,
          onLogout: () async {
            await AuthService.logout();
            appRouter.go(AppRoutes.login);
          },
          showSidebar: true,
          isAccountProfileOnly: true,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.profilInstitusi,
      name: 'profil-institusi',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return ProfileScreen(
          user: user,
          onUserUpdated: (u) => currentUserNotifier.value = u,
          onLogout: () async {
            await AuthService.logout();
            appRouter.go(AppRoutes.login);
          },
          showSidebar: true,
          isInstitutionProfileOnly: true,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.timHakAkses,
      name: 'tim-hak-akses',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return TimHakAksesScreen(user: user);
      },
    ),
    GoRoute(
      path: AppRoutes.dokumenInstitusi,
      name: 'dokumen-institusi',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return InstitutionWorkspaceScreen(
          user: user,
          resourceType: 'documents',
          onUserUpdated: (u) => currentUserNotifier.value = u,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.pengumumanInstitusi,
      name: 'pengumuman-institusi',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return InstitutionWorkspaceScreen(
          user: user,
          resourceType: 'announcements',
          onUserUpdated: (u) => currentUserNotifier.value = u,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.monitoringEvaluasi,
      name: 'monitoring-evaluasi',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return InstitutionWorkspaceScreen(
          user: user,
          resourceType: 'monitoring',
          onUserUpdated: (u) => currentUserNotifier.value = u,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.laporanKegiatan,
      name: 'laporan-kegiatan',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return InstitutionWorkspaceScreen(
          user: user,
          resourceType: 'reports',
          onUserUpdated: (u) => currentUserNotifier.value = u,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.karyaSiswa,
      name: 'karya-siswa',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return InstitutionWorkspaceScreen(
          user: user,
          resourceType: 'showcases',
          onUserUpdated: (u) => currentUserNotifier.value = u,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.mitraIndustri,
      name: 'mitra-industri',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return InstitutionWorkspaceScreen(
          user: user,
          resourceType: 'partners',
          onUserUpdated: (u) => currentUserNotifier.value = u,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.lowonganCorporate,
      name: 'lowongan-corporate',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return CorporateLowonganScreen(
          user: user,
          onUserUpdated: (u) => currentUserNotifier.value = u,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.detailLowonganCorporate,
      name: 'detail-lowongan-corporate',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        final item = state.extra as CorporateVacancyItem?;
        final vacancyId = state.uri.queryParameters['id'];
        return CorporateVacancyDetailScreen(
          item: item,
          vacancyId: vacancyId,
          user: user,
          onUserUpdated: (u) => currentUserNotifier.value = u,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.pengadaanVendor,
      name: 'pengadaan-vendor',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return InstitutionWorkspaceScreen(
          user: user,
          resourceType: 'tenders',
          onUserUpdated: (u) => currentUserNotifier.value = u,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.realisasiAnggaran,
      name: 'realisasi-anggaran',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return InstitutionWorkspaceScreen(
          user: user,
          resourceType: 'budgets',
          onUserUpdated: (u) => currentUserNotifier.value = u,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.buatKebutuhan,
      name: 'buat-kebutuhan',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return BuatKebutuhanScreen(user: user);
      },
    ),

    // ── Halaman 404 & Akses Ditolak ─────────────────────────────────────
    GoRoute(
      path: AppRoutes.notFound,
      name: 'not-found',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        final extraMsg = state.extra is String ? state.extra as String : null;
        return NotFoundScreen(
          user: user,
          message: extraMsg,
          path: state.uri.toString(),
        );
      },
    ),

    // ── Kebutuhan Proyek: Detail & Aksi ─────────────────────────────────
    GoRoute(
      path: AppRoutes.detailProyek,
      name: 'detail-proyek',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final user = currentUserNotifier.value ?? UserModel.guest();
        final extraOpp = state.extra is OpportunityModel ? state.extra as OpportunityModel : null;

        if (extraOpp != null) {
          return DetailKebutuhanScreen(
            opportunity: extraOpp,
            user: user,
          );
        }

        // Deep-link URL langsung atau browser refresh via API
        return FutureBuilder<OpportunityModel?>(
          future: OpportunityService.getOpportunityById(id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasData && snapshot.data != null) {
              return DetailKebutuhanScreen(
                opportunity: snapshot.data!,
                user: user,
              );
            }
            return NotFoundScreen(
              title: 'Proyek Tidak Ditemukan',
              message: 'Kebutuhan proyek dengan ID "$id" tidak ditemukan atau sudah ditutup.',
              user: user,
              path: state.uri.toString(),
            );
          },
        );
      },
    ),

    // ── Marketplace Karya: Detail & Jual Karya ──────────────────────────
    GoRoute(
      path: AppRoutes.detailMarketplace,
      name: 'detail-marketplace',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final user = currentUserNotifier.value ?? UserModel.guest();
        final extraItem = state.extra is MarketplaceItem ? state.extra as MarketplaceItem : null;
        return MarketplaceDetailScreen(
          itemId: id,
          initialItem: extraItem,
          user: user,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.jualKarya,
      name: 'jual-karya',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return JualKaryaScreen(user: user);
      },
    ),

    // ── Dompet / Wallet Sub-Halaman ─────────────────────────────────────
    GoRoute(
      path: AppRoutes.walletTopup,
      name: 'wallet-topup',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return TopUpScreen(user: user);
      },
    ),
    GoRoute(
      path: AppRoutes.walletWithdraw,
      name: 'wallet-withdraw',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        final balance = (state.extra as num?)?.toDouble() ?? 0.0;
        return WithdrawScreen(user: user, currentBalance: balance);
      },
    ),
    GoRoute(
      path: AppRoutes.walletTransfer,
      name: 'wallet-transfer',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        final toUser = state.uri.queryParameters['to'];
        return TransferScreen(
          user: user,
          preFilledUsername: toUser,
          onUserUpdated: (u) => currentUserNotifier.value = u,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.walletHistory,
      name: 'wallet-history',
      builder: (context, state) => const WalletHistoryScreen(),
    ),

    // ── Verifikasi Identitas & Pengajuan Kreator ────────────────────────
    GoRoute(
      path: AppRoutes.verifikasiKyc,
      name: 'verifikasi-kyc',
      builder: (context, state) => const KycVerificationScreen(),
    ),
    GoRoute(
      path: AppRoutes.verifikasiKlien,
      name: 'verifikasi-klien',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return ClientVerificationPage(user: user);
      },
    ),
    GoRoute(
      path: AppRoutes.daftarKreator,
      name: 'daftar-kreator',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return CreatorApplicationPage(
          user: user,
          onUserUpdated: (u) => currentUserNotifier.value = u,
        );
      },
    ),

    // ── Pengaturan & Bantuan Sub-Halaman ────────────────────────────────
    GoRoute(
      path: AppRoutes.pengaturanAlamat,
      name: 'pengaturan-alamat',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return AddressesScreen(user: user);
      },
    ),
    GoRoute(
      path: AppRoutes.pengaturanPembayaran,
      name: 'pengaturan-pembayaran',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return PaymentMethodsScreen(user: user);
      },
    ),
    GoRoute(
      path: AppRoutes.pengaturanPenyimpanan,
      name: 'pengaturan-penyimpanan',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return StorageManagementScreen(user: user);
      },
    ),
    GoRoute(
      path: AppRoutes.bantuan,
      name: 'bantuan',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return HelpScreen(user: user);
      },
    ),
    GoRoute(
      path: AppRoutes.kebijakanPrivasi,
      name: 'kebijakan-privasi',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return PrivacyPolicyScreen(user: user);
      },
    ),

    // ── Agenda & Kalender ───────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.creatorCalendar,
      name: 'creator-calendar',
      builder: (context, state) {
        final user = currentUserNotifier.value ?? UserModel.guest();
        return CreatorCalendarScreen(
          user: user,
          onUserUpdated: (u) => currentUserNotifier.value = u,
        );
      },
    ),
  ],
);
