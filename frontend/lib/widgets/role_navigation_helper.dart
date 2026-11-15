import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/subrole_theme_engine.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/app_router.dart';
import '../services/system_settings_service.dart';
import '../utils/app_errors.dart';
import 'auth_guard_dialog.dart';
import 'creator_sidebar_menus.dart';
import 'custom_bottom_nav_bar.dart';
import 'kreavana_image.dart';
import 'sidebar_hover_tile.dart';

/// Inherited shell controller allowing nested AppBars inside [MainNavigation] or
/// [DesktopSidebarLayout] to detect and open the outer responsive Drawer on mobile.
class KreavanaShellScope extends InheritedWidget {
  final VoidCallback? onOpenDrawer;

  const KreavanaShellScope({
    super.key,
    required this.onOpenDrawer,
    required super.child,
  });

  bool get hasDrawer => onOpenDrawer != null;

  void openDrawer() => onOpenDrawer?.call();

  static KreavanaShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<KreavanaShellScope>();
  }

  @override
  bool updateShouldNotify(KreavanaShellScope oldWidget) =>
      onOpenDrawer != oldWidget.onOpenDrawer;
}

/// Destination entry for the mobile bottom navigation bar.
class MobileBottomNavDest {
  final String routeKey;
  final String? routePath;
  final int? mainNavIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? badgeCount;
  final bool isMenuTrigger;
  final List<String> activeAliases;

  const MobileBottomNavDest({
    required this.routeKey,
    this.routePath,
    this.mainNavIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount,
    this.isMenuTrigger = false,
    this.activeAliases = const [],
  });

  BottomNavItem toBottomNavItem() => BottomNavItem(
        icon: icon,
        activeIcon: activeIcon,
        label: label,
        badgeCount: badgeCount,
      );
}

/// Sidebar / Drawer section and menu entries shared across Desktop Sidebar and Mobile Drawer.
class RoleMenuEntry {
  final String routeKey;
  final String? routePath;
  final int? mainNavIndex;
  final CreatorSidebarMenuEntry? creatorServiceEntry;
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final int? badgeCount;
  final bool isAiAction;
  final String? guestActionLabel;
  final List<String> activeAliases;

  const RoleMenuEntry({
    required this.routeKey,
    this.routePath,
    this.mainNavIndex,
    this.creatorServiceEntry,
    required this.icon,
    this.activeIcon,
    required this.label,
    this.badgeCount,
    this.isAiAction = false,
    this.guestActionLabel,
    this.activeAliases = const [],
  });
}

class RoleMenuSection {
  final String? title;
  final List<RoleMenuEntry> items;

  const RoleMenuSection({
    this.title,
    required this.items,
  });
}

/// Canonical role classification, bottom navigation bar destinations, and full
/// role-based Drawer menu shared between [MainNavigation] and [DesktopSidebarLayout].
class RoleNavigationHelper {
  RoleNavigationHelper._();

  static const Map<int, String> protectedIndexActionMap = {
    2: 'melihat & mengelola proyek saya',
    4: 'membuka agenda kegiatan',
    5: 'mengelola kolaborasi',
    6: 'melihat ulasan & reputasi',
    7: 'mengakses dompet & keuangan',
    8: 'membuka pengaturan akun',
    9: 'melihat profil pengguna',
    10: 'melihat notifikasi',
    11: 'menggunakan pesan langsung',
    13: 'mengatur jadwal kapasitas',
    14: 'menggunakan Kreavana AI',
  };

  static bool isGovernment(UserModel user) => user.isGovernment;

  static bool isSchool(UserModel user) => user.isSchool;

  static bool isCompany(UserModel user) {
    if (user.isAdmin || isSchool(user) || isGovernment(user)) return false;
    return user.isCorporate;
  }

  static bool isCreatorUser(UserModel user) {
    if (user.isAdmin || isSchool(user) || isGovernment(user) || isCompany(user)) {
      return false;
    }
    return CreatorSidebarMenus.isCreatorUser(user);
  }

  static bool hasSpecificCreatorSubRole(UserModel user) {
    if (!isCreatorUser(user)) return false;
    return CreatorSidebarMenus.hasSpecificSubRole(user.subRole);
  }

  static Color accentColorFor(UserModel user) {
    if (user.isAdmin) return const Color(0xFFD97706);
    if (isCompany(user)) return const Color(0xFF2563EB);
    return SubRoleThemeEngine.getAccentColorForUser(user);
  }

  static String roleBadgeLabel(UserModel user) {
    if (user.isGuest) return 'Mode Tamu';
    if (user.isAdmin) return 'Administrator';
    if (isSchool(user)) {
      return user.isInstitutionStaff ? 'Staf Institusi' : 'Institusi Pendidikan';
    }
    if (isGovernment(user)) return 'Instansi Pemerintah';
    if (isCompany(user)) return 'Corporate / B2B';
    if (isCreatorUser(user)) {
      return CreatorSidebarMenus.layananSectionTitle(user.subRole) ?? 'Kreator';
    }
    return 'Client';
  }

  /// Whether a standalone route renders a bottom-right floating action button on mobile.
  static bool routeHasPageFab(UserModel user, String routeKey) {
    final r = routeKey.toLowerCase().trim();
    if (r == 'proyek_saya' ||
        r == 'program_magang' ||
        r == 'program-magang' ||
        r == 'lowongan_magang' ||
        r == 'lowongan' ||
        r == 'internships' ||
        r == 'agenda' ||
        r == 'kapasitas_jadwal' ||
        r == 'creator_calendar' ||
        r == 'pesan' ||
        r == 'chat' ||
        r == 'direct_message') {
      return true;
    }
    if (r == 'marketplace' || r == 'portofolio') {
      return user.isCreator;
    }
    if (r == 'kolaborasi') {
      return isCreatorUser(user);
    }
    return false;
  }

  /// Checks whether a guest user is blocked from the given route/index and opens [AuthGuardDialog].
  static bool checkGuestGuard(
    BuildContext context,
    UserModel user, {
    int? mainNavIndex,
    String? guestActionLabel,
  }) {
    if (!user.isGuest) return true;
    final action = guestActionLabel ??
        (mainNavIndex != null ? protectedIndexActionMap[mainNavIndex] : null);
    if (action == null) return true;
    AuthGuardDialog.show(context, actionName: action);
    return false;
  }

  /// Canonical mobile bottom navigation destinations (max 5 items, matching Desktop role capabilities).
  static List<MobileBottomNavDest> getMobileBottomNavDestinations(
    UserModel user, {
    int unreadMessages = 0,
    int unreadNotifications = 0,
  }) {
    final msgBadge = unreadMessages > 0 ? unreadMessages : null;
    final notifBadge = unreadNotifications > 0 ? unreadNotifications : null;

    if (user.isAdmin) {
      return [
        const MobileBottomNavDest(
          routeKey: 'admin_dashboard',
          routePath: AppRoutes.adminDashboard,
          mainNavIndex: 0,
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
          label: 'Admin',
          activeAliases: ['dashboard'],
        ),
        const MobileBottomNavDest(
          routeKey: 'admin_verification',
          routePath: AppRoutes.adminVerification,
          mainNavIndex: 1,
          icon: Icons.verified_user_outlined,
          activeIcon: Icons.verified_user_rounded,
          label: 'Verifikasi',
          activeAliases: ['verifikasi'],
        ),
        const MobileBottomNavDest(
          routeKey: 'admin_resolution',
          routePath: AppRoutes.adminResolution,
          mainNavIndex: 2,
          icon: Icons.gavel_outlined,
          activeIcon: Icons.gavel_rounded,
          label: 'Resolusi',
          activeAliases: ['resolusi'],
        ),
        MobileBottomNavDest(
          routeKey: 'admin_notifications',
          routePath: AppRoutes.notifikasi,
          mainNavIndex: 4,
          icon: Icons.notifications_outlined,
          activeIcon: Icons.notifications_rounded,
          label: 'Notifikasi',
          badgeCount: notifBadge,
          activeAliases: const ['notifikasi', 'notifications'],
        ),
        const MobileBottomNavDest(
          routeKey: 'menu',
          icon: Icons.menu_rounded,
          activeIcon: Icons.menu_open_rounded,
          label: 'Menu',
          isMenuTrigger: true,
        ),
      ];
    }

    if (isSchool(user)) {
      final list = <MobileBottomNavDest>[
        const MobileBottomNavDest(
          routeKey: 'beranda',
          routePath: AppRoutes.beranda,
          mainNavIndex: 0,
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Beranda',
        ),
      ];

      // Secondary workspace tabs aligned with School Desktop Sidebar & staff RBAC
      final instCandidates = <MobileBottomNavDest>[
        if (user.hasInstitutionPermission('program_magang'))
          const MobileBottomNavDest(
            routeKey: 'program_magang',
            routePath: AppRoutes.programMagang,
            icon: Icons.school_outlined,
            activeIcon: Icons.school_rounded,
            label: 'Magang',
            activeAliases: ['program-magang'],
          ),
        if (user.hasInstitutionPermission('program_magang'))
          const MobileBottomNavDest(
            routeKey: 'proyek_saya',
            routePath: AppRoutes.proyek,
            mainNavIndex: 2,
            icon: Icons.work_outline_rounded,
            activeIcon: Icons.work_rounded,
            label: 'Proyek',
          ),
        if (user.hasInstitutionPermission('karya_siswa'))
          const MobileBottomNavDest(
            routeKey: 'karya_siswa',
            routePath: AppRoutes.karyaSiswa,
            icon: Icons.palette_outlined,
            activeIcon: Icons.palette_rounded,
            label: 'Karya',
            activeAliases: ['showcases'],
          ),
        if (user.hasInstitutionPermission('kegiatan_event'))
          const MobileBottomNavDest(
            routeKey: 'agenda',
            routePath: AppRoutes.agenda,
            mainNavIndex: 4,
            icon: Icons.calendar_today_outlined,
            activeIcon: Icons.calendar_today_rounded,
            label: 'Kegiatan',
            activeAliases: ['kegiatan_event'],
          ),
        if (user.hasInstitutionPermission('mitra_industri'))
          const MobileBottomNavDest(
            routeKey: 'mitra_komunitas',
            routePath: AppRoutes.mitraIndustri,
            icon: Icons.handshake_outlined,
            activeIcon: Icons.handshake_rounded,
            label: 'Mitra',
            activeAliases: ['mitra_industri', 'partners'],
          ),
        if (user.hasInstitutionPermission('dokumen_institusi'))
          const MobileBottomNavDest(
            routeKey: 'dokumen_instansi',
            routePath: AppRoutes.dokumenInstitusi,
            icon: Icons.folder_shared_outlined,
            activeIcon: Icons.folder_shared_rounded,
            label: 'Dokumen',
            activeAliases: ['dokumen_institusi', 'documents'],
          ),
      ];

      for (final c in instCandidates) {
        if (list.length >= 3) break;
        list.add(c);
      }

      if (SystemSettingsService.isDirectMessageEnabled) {
        list.add(
          MobileBottomNavDest(
            routeKey: 'pesan',
            routePath: AppRoutes.pesan,
            mainNavIndex: 11,
            icon: Icons.chat_bubble_outline_rounded,
            activeIcon: Icons.chat_bubble_rounded,
            label: 'Pesan',
            badgeCount: msgBadge,
            activeAliases: const ['chat', 'direct_message'],
          ),
        );
      } else {
        list.add(
          const MobileBottomNavDest(
            routeKey: 'profil_instansi',
            routePath: AppRoutes.profilInstitusi,
            icon: Icons.account_balance_outlined,
            activeIcon: Icons.account_balance_rounded,
            label: 'Institusi',
          ),
        );
      }

      list.add(
        const MobileBottomNavDest(
          routeKey: 'menu',
          icon: Icons.menu_rounded,
          activeIcon: Icons.menu_open_rounded,
          label: 'Menu',
          isMenuTrigger: true,
        ),
      );
      return list;
    }

    if (isCompany(user)) {
      return [
        const MobileBottomNavDest(
          routeKey: 'beranda',
          routePath: AppRoutes.beranda,
          mainNavIndex: 0,
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Beranda',
        ),
        const MobileBottomNavDest(
          routeKey: 'lowongan_magang',
          routePath: AppRoutes.lowonganCorporate,
          icon: Icons.business_center_outlined,
          activeIcon: Icons.business_center_rounded,
          label: 'Lowongan',
          activeAliases: ['lowongan', 'internships', 'buka_lowongan'],
        ),
        const MobileBottomNavDest(
          routeKey: 'proyek_saya',
          routePath: AppRoutes.proyek,
          mainNavIndex: 2,
          icon: Icons.work_outline_rounded,
          activeIcon: Icons.work_rounded,
          label: 'Proyek',
        ),
        if (SystemSettingsService.isDirectMessageEnabled)
          MobileBottomNavDest(
            routeKey: 'pesan',
            routePath: AppRoutes.pesan,
            mainNavIndex: 11,
            icon: Icons.chat_bubble_outline_rounded,
            activeIcon: Icons.chat_bubble_rounded,
            label: 'Pesan',
            badgeCount: msgBadge,
            activeAliases: const ['chat', 'direct_message'],
          )
        else
          const MobileBottomNavDest(
            routeKey: 'tender_kolaborasi',
            routePath: AppRoutes.pengadaanVendor,
            icon: Icons.gavel_outlined,
            activeIcon: Icons.gavel_rounded,
            label: 'Tender',
            activeAliases: ['tenders', 'pengadaan_vendor'],
          ),
        const MobileBottomNavDest(
          routeKey: 'menu',
          icon: Icons.menu_rounded,
          activeIcon: Icons.menu_open_rounded,
          label: 'Menu',
          isMenuTrigger: true,
        ),
      ];
    }

    if (isGovernment(user)) {
      return [
        const MobileBottomNavDest(
          routeKey: 'beranda',
          routePath: AppRoutes.beranda,
          mainNavIndex: 0,
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Beranda',
        ),
        const MobileBottomNavDest(
          routeKey: 'proyek_saya',
          routePath: AppRoutes.proyek,
          mainNavIndex: 2,
          icon: Icons.account_balance_outlined,
          activeIcon: Icons.account_balance_rounded,
          label: 'Program',
        ),
        const MobileBottomNavDest(
          routeKey: 'tender_kolaborasi',
          routePath: AppRoutes.pengadaanVendor,
          icon: Icons.gavel_outlined,
          activeIcon: Icons.gavel_rounded,
          label: 'Tender',
          activeAliases: ['tenders', 'pengadaan_vendor'],
        ),
        if (SystemSettingsService.isDirectMessageEnabled)
          MobileBottomNavDest(
            routeKey: 'pesan',
            routePath: AppRoutes.pesan,
            mainNavIndex: 11,
            icon: Icons.chat_bubble_outline_rounded,
            activeIcon: Icons.chat_bubble_rounded,
            label: 'Pesan',
            badgeCount: msgBadge,
            activeAliases: const ['chat', 'direct_message'],
          )
        else
          const MobileBottomNavDest(
            routeKey: 'realisasi_anggaran',
            routePath: AppRoutes.realisasiAnggaran,
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long_rounded,
            label: 'Anggaran',
            activeAliases: ['budgets'],
          ),
        const MobileBottomNavDest(
          routeKey: 'menu',
          icon: Icons.menu_rounded,
          activeIcon: Icons.menu_open_rounded,
          label: 'Menu',
          isMenuTrigger: true,
        ),
      ];
    }

    if (user.isGuest) {
      return [
        const MobileBottomNavDest(
          routeKey: 'beranda',
          routePath: AppRoutes.beranda,
          mainNavIndex: 0,
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Beranda',
        ),
        const MobileBottomNavDest(
          routeKey: 'explore',
          routePath: AppRoutes.explore,
          mainNavIndex: 1,
          icon: Icons.explore_outlined,
          activeIcon: Icons.explore_rounded,
          label: 'Jelajahi',
        ),
        const MobileBottomNavDest(
          routeKey: 'marketplace',
          routePath: AppRoutes.marketplaceKarya,
          mainNavIndex: 3,
          icon: Icons.storefront_outlined,
          activeIcon: Icons.storefront_rounded,
          label: 'Karya',
          activeAliases: ['portofolio'],
        ),
        const MobileBottomNavDest(
          routeKey: 'peluang_proyek',
          routePath: AppRoutes.peluangProyek,
          mainNavIndex: 12,
          icon: Icons.work_outline_rounded,
          activeIcon: Icons.work_rounded,
          label: 'Peluang',
        ),
        const MobileBottomNavDest(
          routeKey: 'menu',
          icon: Icons.menu_rounded,
          activeIcon: Icons.menu_open_rounded,
          label: 'Menu',
          isMenuTrigger: true,
        ),
      ];
    }

    if (isCreatorUser(user)) {
      return [
        const MobileBottomNavDest(
          routeKey: 'beranda',
          routePath: AppRoutes.beranda,
          mainNavIndex: 0,
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Beranda',
        ),
        if (SystemSettingsService.isOpportunitiesEnabled)
          const MobileBottomNavDest(
            routeKey: 'explore',
            routePath: AppRoutes.explore,
            mainNavIndex: 1,
            icon: Icons.explore_outlined,
            activeIcon: Icons.explore_rounded,
            label: 'Jelajahi',
          )
        else if (SystemSettingsService.isMarketplaceEnabled)
          const MobileBottomNavDest(
            routeKey: 'marketplace',
            routePath: AppRoutes.marketplaceKarya,
            mainNavIndex: 3,
            icon: Icons.storefront_outlined,
            activeIcon: Icons.storefront_rounded,
            label: 'Karya',
          )
        else
          const MobileBottomNavDest(
            routeKey: 'agenda',
            routePath: AppRoutes.agenda,
            mainNavIndex: 4,
            icon: Icons.calendar_today_outlined,
            activeIcon: Icons.calendar_today_rounded,
            label: 'Agenda',
          ),
        const MobileBottomNavDest(
          routeKey: 'proyek_saya',
          routePath: AppRoutes.proyek,
          mainNavIndex: 2,
          icon: Icons.work_outline_rounded,
          activeIcon: Icons.work_rounded,
          label: 'Proyek',
        ),
        if (SystemSettingsService.isDirectMessageEnabled)
          MobileBottomNavDest(
            routeKey: 'pesan',
            routePath: AppRoutes.pesan,
            mainNavIndex: 11,
            icon: Icons.chat_bubble_outline_rounded,
            activeIcon: Icons.chat_bubble_rounded,
            label: 'Pesan',
            badgeCount: msgBadge,
            activeAliases: const ['chat', 'direct_message'],
          )
        else
          const MobileBottomNavDest(
            routeKey: 'kapasitas_jadwal',
            routePath: AppRoutes.kapasitasJadwal,
            mainNavIndex: 13,
            icon: Icons.event_available_outlined,
            activeIcon: Icons.event_available_rounded,
            label: 'Jadwal',
          ),
        const MobileBottomNavDest(
          routeKey: 'menu',
          icon: Icons.menu_rounded,
          activeIcon: Icons.menu_open_rounded,
          label: 'Menu',
          isMenuTrigger: true,
        ),
      ];
    }

    // Standard Client account
    return [
      const MobileBottomNavDest(
        routeKey: 'beranda',
        routePath: AppRoutes.beranda,
        mainNavIndex: 0,
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Beranda',
      ),
      if (SystemSettingsService.isMarketplaceEnabled)
        const MobileBottomNavDest(
          routeKey: 'marketplace',
          routePath: AppRoutes.marketplaceKarya,
          mainNavIndex: 3,
          icon: Icons.storefront_outlined,
          activeIcon: Icons.storefront_rounded,
          label: 'Karya',
          activeAliases: ['portofolio'],
        )
      else
        const MobileBottomNavDest(
          routeKey: 'agenda',
          routePath: AppRoutes.agenda,
          mainNavIndex: 4,
          icon: Icons.calendar_today_outlined,
          activeIcon: Icons.calendar_today_rounded,
          label: 'Agenda',
        ),
      const MobileBottomNavDest(
        routeKey: 'proyek_saya',
        routePath: AppRoutes.proyek,
        mainNavIndex: 2,
        icon: Icons.work_outline_rounded,
        activeIcon: Icons.work_rounded,
        label: 'Proyek',
      ),
      if (SystemSettingsService.isDirectMessageEnabled)
        MobileBottomNavDest(
          routeKey: 'pesan',
          routePath: AppRoutes.pesan,
          mainNavIndex: 11,
          icon: Icons.chat_bubble_outline_rounded,
          activeIcon: Icons.chat_bubble_rounded,
          label: 'Pesan',
          badgeCount: msgBadge,
          activeAliases: const ['chat', 'direct_message'],
        )
      else
        const MobileBottomNavDest(
          routeKey: 'profil',
          routePath: AppRoutes.profil,
          mainNavIndex: 9,
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profil',
          activeAliases: ['profil_akun'],
        ),
      const MobileBottomNavDest(
        routeKey: 'menu',
        icon: Icons.menu_rounded,
        activeIcon: Icons.menu_open_rounded,
        label: 'Menu',
        isMenuTrigger: true,
      ),
    ];
  }

  static int resolveActiveBottomNavIndex(
    List<MobileBottomNavDest> dests,
    String activeRoute, {
    int? mainNavIndex,
  }) {
    final normalized = activeRoute.toLowerCase().trim();
    for (int i = 0; i < dests.length; i++) {
      final d = dests[i];
      if (d.isMenuTrigger) continue;
      if (mainNavIndex != null && d.mainNavIndex == mainNavIndex) {
        return i;
      }
      if (d.routeKey == normalized || d.activeAliases.contains(normalized)) {
        return i;
      }
    }
    return -1;
  }

  /// Complete Desktop-parity section & item tree per user role.
  static List<RoleMenuSection> getRoleMenuSections(
    UserModel user, {
    int unreadMessages = 0,
    int unreadNotifications = 0,
  }) {
    final msgBadge = unreadMessages > 0 ? unreadMessages : null;
    final notifBadge = unreadNotifications > 0 ? unreadNotifications : null;

    if (user.isAdmin) {
      return [
        RoleMenuSection(
          title: 'ADMINISTRATOR',
          items: [
            const RoleMenuEntry(
              routeKey: 'admin_dashboard',
              routePath: AppRoutes.adminDashboard,
              mainNavIndex: 0,
              icon: Icons.dashboard_rounded,
              label: 'Dasbor Admin',
              activeAliases: ['dashboard'],
            ),
            const RoleMenuEntry(
              routeKey: 'admin_verification',
              routePath: AppRoutes.adminVerification,
              mainNavIndex: 1,
              icon: Icons.verified_user_rounded,
              label: 'Verifikasi Akun',
              activeAliases: ['verifikasi'],
            ),
            const RoleMenuEntry(
              routeKey: 'admin_resolution',
              routePath: AppRoutes.adminResolution,
              mainNavIndex: 2,
              icon: Icons.gavel_rounded,
              label: 'Resolusi & Dispute',
              activeAliases: ['resolusi'],
            ),
            const RoleMenuEntry(
              routeKey: 'admin_settings',
              routePath: AppRoutes.adminSystemSettings,
              mainNavIndex: 3,
              icon: Icons.tune_rounded,
              label: 'Pengaturan Sistem',
            ),
            RoleMenuEntry(
              routeKey: 'admin_notifications',
              routePath: AppRoutes.notifikasi,
              mainNavIndex: 4,
              icon: Icons.notifications_rounded,
              label: 'Notifikasi',
              badgeCount: notifBadge,
              activeAliases: const ['notifikasi', 'notifications'],
            ),
            const RoleMenuEntry(
              routeKey: 'admin_profile',
              routePath: AppRoutes.profil,
              mainNavIndex: 5,
              icon: Icons.person_rounded,
              label: 'Profil Saya',
              activeAliases: ['profil'],
            ),
          ],
        ),
      ];
    }

    final school = isSchool(user);
    final gov = isGovernment(user);
    final company = isCompany(user);
    final creator = isCreatorUser(user);
    final hasSubRoleMenus = hasSpecificCreatorSubRole(user);

    final sections = <RoleMenuSection>[];

    // Primary navigation items
    final mainItems = <RoleMenuEntry>[
      const RoleMenuEntry(
        routeKey: 'beranda',
        routePath: AppRoutes.beranda,
        mainNavIndex: 0,
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Beranda',
      ),
      if (SystemSettingsService.isAiEnabled)
        const RoleMenuEntry(
          routeKey: 'ai',
          icon: Icons.auto_awesome_rounded,
          label: 'Kreavana AI',
          isAiAction: true,
          guestActionLabel: 'menggunakan Kreavana AI',
        ),
      if ((creator || user.isGuest) &&
          !gov &&
          !school &&
          !company &&
          SystemSettingsService.isOpportunitiesEnabled)
        const RoleMenuEntry(
          routeKey: 'explore',
          routePath: AppRoutes.explore,
          mainNavIndex: 1,
          icon: Icons.explore_outlined,
          activeIcon: Icons.explore_rounded,
          label: 'Rekomendasi Peluang',
        ),
      if (!gov)
        const RoleMenuEntry(
          routeKey: 'proyek_saya',
          routePath: AppRoutes.proyek,
          mainNavIndex: 2,
          icon: Icons.work_outline_rounded,
          activeIcon: Icons.work_rounded,
          label: 'Proyek Saya',
          guestActionLabel: 'melihat & mengelola proyek saya',
        ),
      if (SystemSettingsService.isDirectMessageEnabled && !user.isGuest)
        RoleMenuEntry(
          routeKey: 'pesan',
          routePath: AppRoutes.pesan,
          mainNavIndex: 11,
          icon: Icons.chat_bubble_outline_rounded,
          activeIcon: Icons.chat_bubble_rounded,
          label: 'Direct Message',
          badgeCount: msgBadge,
          guestActionLabel: 'menggunakan pesan langsung',
          activeAliases: const ['chat', 'direct_message'],
        ),
      if (school && SystemSettingsService.isWalletEnabled)
        const RoleMenuEntry(
          routeKey: 'pembayaran',
          routePath: AppRoutes.wallet,
          mainNavIndex: 7,
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet_rounded,
          label: 'Dompet & Pembayaran',
          activeAliases: ['wallet', 'keuangan'],
        ),
      if (!user.isGuest)
        RoleMenuEntry(
          routeKey: 'notifikasi',
          routePath: AppRoutes.notifikasi,
          mainNavIndex: 10,
          icon: Icons.notifications_outlined,
          activeIcon: Icons.notifications_rounded,
          label: 'Notifikasi',
          badgeCount: notifBadge,
          activeAliases: const ['notifications'],
        ),
      if (!hasSubRoleMenus && !company && !school && !gov) ...[
        if (SystemSettingsService.isMarketplaceEnabled)
          const RoleMenuEntry(
            routeKey: 'marketplace',
            routePath: AppRoutes.marketplaceKarya,
            mainNavIndex: 3,
            icon: Icons.storefront_outlined,
            activeIcon: Icons.storefront_rounded,
            label: 'Marketplace',
            activeAliases: ['portofolio'],
          ),
        const RoleMenuEntry(
          routeKey: 'agenda',
          routePath: AppRoutes.agenda,
          mainNavIndex: 4,
          icon: Icons.calendar_today_outlined,
          activeIcon: Icons.calendar_today_rounded,
          label: 'Agenda',
          guestActionLabel: 'membuka agenda kegiatan',
        ),
      ],
    ];
    sections.add(RoleMenuSection(items: mainItems));

    // Role-specific workspaces
    if (school) {
      final schoolItems = <RoleMenuEntry>[
        if (user.hasInstitutionPermission('program_magang'))
          const RoleMenuEntry(
            routeKey: 'program_magang',
            routePath: AppRoutes.programMagang,
            icon: Icons.school_outlined,
            activeIcon: Icons.school_rounded,
            label: 'Program & Magang',
            activeAliases: ['program-magang'],
          ),
        if (user.hasInstitutionPermission('kegiatan_event'))
          const RoleMenuEntry(
            routeKey: 'agenda',
            routePath: AppRoutes.agenda,
            mainNavIndex: 4,
            icon: Icons.event_note_outlined,
            activeIcon: Icons.event_note_rounded,
            label: 'Kegiatan & Event',
            activeAliases: ['kegiatan_event'],
          ),
        if (user.hasInstitutionPermission('mitra_industri'))
          const RoleMenuEntry(
            routeKey: 'mitra_komunitas',
            routePath: AppRoutes.mitraIndustri,
            icon: Icons.handshake_outlined,
            activeIcon: Icons.handshake_rounded,
            label: 'Mitra Industri & Sanggar',
            activeAliases: ['mitra_industri', 'partners'],
          ),
        if (user.hasInstitutionPermission('karya_siswa'))
          const RoleMenuEntry(
            routeKey: 'karya_siswa',
            routePath: AppRoutes.karyaSiswa,
            icon: Icons.palette_outlined,
            activeIcon: Icons.palette_rounded,
            label: 'Karya & Portofolio Siswa',
            activeAliases: ['showcases'],
          ),
      ];
      if (schoolItems.isNotEmpty) {
        sections.add(
          RoleMenuSection(title: 'PENGELOLAAN SEKOLAH', items: schoolItems),
        );
      }

      if (user.hasInstitutionPermission('dokumen_institusi')) {
        sections.add(
          const RoleMenuSection(
            title: 'DATA & DOKUMEN',
            items: [
              RoleMenuEntry(
                routeKey: 'dokumen_instansi',
                routePath: AppRoutes.dokumenInstitusi,
                icon: Icons.folder_shared_outlined,
                activeIcon: Icons.folder_shared_rounded,
                label: 'Dokumen & MoU',
                activeAliases: ['dokumen_institusi', 'documents'],
              ),
            ],
          ),
        );
      }

      sections.add(
        RoleMenuSection(
          title: 'PENGATURAN',
          items: [
            if (!user.isInstitutionStaff ||
                user.hasInstitutionPermission('profil_institusi'))
              const RoleMenuEntry(
                routeKey: 'profil_instansi',
                routePath: AppRoutes.profilInstitusi,
                icon: Icons.account_balance_outlined,
                activeIcon: Icons.account_balance_rounded,
                label: 'Profil Institusi',
              ),
            const RoleMenuEntry(
              routeKey: 'profil_akun',
              routePath: AppRoutes.profilAkun,
              mainNavIndex: 9,
              icon: Icons.badge_outlined,
              activeIcon: Icons.badge_rounded,
              label: 'Profil Akun (PIC)',
              activeAliases: ['profil'],
            ),
            const RoleMenuEntry(
              routeKey: 'pengaturan',
              routePath: AppRoutes.pengaturan,
              mainNavIndex: 8,
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings_rounded,
              label: 'Pengaturan Akun',
              activeAliases: ['pengaturan_akun'],
            ),
            if (user.isInstitutionAdmin)
              const RoleMenuEntry(
                routeKey: 'tim_hak_akses',
                routePath: AppRoutes.timHakAkses,
                icon: Icons.manage_accounts_outlined,
                activeIcon: Icons.manage_accounts_rounded,
                label: 'Tim & Hak Akses',
              ),
          ],
        ),
      );
      return sections;
    }

    if (gov) {
      sections.add(
        const RoleMenuSection(
          title: 'PORTAL INSTANSI',
          items: [
            RoleMenuEntry(
              routeKey: 'proyek_saya',
              routePath: AppRoutes.proyek,
              mainNavIndex: 2,
              icon: Icons.account_balance_outlined,
              activeIcon: Icons.account_balance_rounded,
              label: 'Peluang & Program',
            ),
            RoleMenuEntry(
              routeKey: 'agenda',
              routePath: AppRoutes.agenda,
              mainNavIndex: 4,
              icon: Icons.event_note_outlined,
              activeIcon: Icons.event_note_rounded,
              label: 'Kegiatan & Event',
            ),
            RoleMenuEntry(
              routeKey: 'tender_kolaborasi',
              routePath: AppRoutes.pengadaanVendor,
              icon: Icons.gavel_outlined,
              activeIcon: Icons.gavel_rounded,
              label: 'Tender & Kolaborasi',
              activeAliases: ['tenders', 'pengadaan_vendor'],
            ),
            RoleMenuEntry(
              routeKey: 'explore',
              routePath: AppRoutes.explore,
              mainNavIndex: 1,
              icon: Icons.people_outline_rounded,
              activeIcon: Icons.people_rounded,
              label: 'Daftar Kreator & Vendor',
            ),
            RoleMenuEntry(
              routeKey: 'mitra_komunitas',
              routePath: AppRoutes.mitraIndustri,
              icon: Icons.groups_outlined,
              activeIcon: Icons.groups_rounded,
              label: 'Mitra & Komunitas',
              activeAliases: ['mitra_industri', 'partners'],
            ),
          ],
        ),
      );
      sections.add(
        const RoleMenuSection(
          title: 'PELAPORAN & MONEV',
          items: [
            RoleMenuEntry(
              routeKey: 'laporan',
              routePath: AppRoutes.laporanKegiatan,
              icon: Icons.analytics_outlined,
              activeIcon: Icons.analytics_rounded,
              label: 'Laporan Kegiatan',
              activeAliases: ['laporan_kegiatan', 'reports'],
            ),
            RoleMenuEntry(
              routeKey: 'realisasi_anggaran',
              routePath: AppRoutes.realisasiAnggaran,
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              label: 'Realisasi Anggaran',
              activeAliases: ['budgets'],
            ),
            RoleMenuEntry(
              routeKey: 'monitoring_evaluasi',
              routePath: AppRoutes.monitoringEvaluasi,
              icon: Icons.assessment_outlined,
              activeIcon: Icons.assessment_rounded,
              label: 'Monitoring & Evaluasi',
              activeAliases: ['monitoring'],
            ),
          ],
        ),
      );
      sections.add(
        const RoleMenuSection(
          title: 'DATA & DOKUMEN',
          items: [
            RoleMenuEntry(
              routeKey: 'dokumen_instansi',
              routePath: AppRoutes.dokumenInstitusi,
              icon: Icons.folder_shared_outlined,
              activeIcon: Icons.folder_shared_rounded,
              label: 'Dokumen Instansi',
              activeAliases: ['documents'],
            ),
            RoleMenuEntry(
              routeKey: 'pengumuman_publik',
              routePath: AppRoutes.pengumumanInstitusi,
              icon: Icons.campaign_outlined,
              activeIcon: Icons.campaign_rounded,
              label: 'Pengumuman Publik',
              activeAliases: ['announcements'],
            ),
          ],
        ),
      );
      sections.add(
        const RoleMenuSection(
          title: 'PENGATURAN',
          items: [
            RoleMenuEntry(
              routeKey: 'profil_instansi',
              routePath: AppRoutes.profilInstitusi,
              icon: Icons.domain_outlined,
              activeIcon: Icons.domain_rounded,
              label: 'Profil Instansi',
            ),
            RoleMenuEntry(
              routeKey: 'pengaturan',
              routePath: AppRoutes.pengaturan,
              mainNavIndex: 8,
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings_rounded,
              label: 'Pengaturan Akun',
              activeAliases: ['pengaturan_akun'],
            ),
            RoleMenuEntry(
              routeKey: 'tim_hak_akses',
              routePath: AppRoutes.timHakAkses,
              icon: Icons.manage_accounts_outlined,
              activeIcon: Icons.manage_accounts_rounded,
              label: 'Tim & Hak Akses',
            ),
          ],
        ),
      );
      return sections;
    }

    if (company) {
      sections.add(
        RoleMenuSection(
          title: 'MANAJEMEN BISNIS B2B',
          items: [
            const RoleMenuEntry(
              routeKey: 'lowongan_magang',
              routePath: AppRoutes.lowonganCorporate,
              icon: Icons.business_center_outlined,
              activeIcon: Icons.business_center_rounded,
              label: 'Lowongan Kerja & Magang',
              activeAliases: ['lowongan', 'internships', 'buka_lowongan'],
            ),
            const RoleMenuEntry(
              routeKey: 'tender_kolaborasi',
              routePath: AppRoutes.pengadaanVendor,
              icon: Icons.gavel_outlined,
              activeIcon: Icons.gavel_rounded,
              label: 'Pengadaan & Tender (RFP)',
              activeAliases: ['tenders', 'pengadaan_vendor'],
            ),
            const RoleMenuEntry(
              routeKey: 'mitra_komunitas',
              routePath: AppRoutes.mitraIndustri,
              icon: Icons.handshake_outlined,
              activeIcon: Icons.handshake_rounded,
              label: 'Mitra & Vendor B2B',
              activeAliases: ['mitra_industri', 'partners'],
            ),
            const RoleMenuEntry(
              routeKey: 'dokumen_instansi',
              routePath: AppRoutes.dokumenInstitusi,
              icon: Icons.description_outlined,
              activeIcon: Icons.description_rounded,
              label: 'Otorisasi PO & MoU',
              activeAliases: ['documents'],
            ),
            const RoleMenuEntry(
              routeKey: 'realisasi_anggaran',
              routePath: AppRoutes.realisasiAnggaran,
              icon: Icons.account_balance_outlined,
              activeIcon: Icons.account_balance_rounded,
              label: 'Alokasi Anggaran & Pajak',
              activeAliases: ['budgets'],
            ),
            const RoleMenuEntry(
              routeKey: 'laporan',
              routePath: AppRoutes.laporanKegiatan,
              icon: Icons.analytics_outlined,
              activeIcon: Icons.analytics_rounded,
              label: 'Laporan & Audit B2B',
              activeAliases: ['laporan_kegiatan', 'reports'],
            ),
            if (SystemSettingsService.isMarketplaceEnabled)
              const RoleMenuEntry(
                routeKey: 'marketplace',
                routePath: AppRoutes.marketplaceKarya,
                mainNavIndex: 3,
                icon: Icons.people_alt_outlined,
                activeIcon: Icons.people_alt_rounded,
                label: 'Cari Kreator & Vendor',
              ),
            if (SystemSettingsService.isWalletEnabled)
              const RoleMenuEntry(
                routeKey: 'pembayaran',
                routePath: AppRoutes.wallet,
                mainNavIndex: 7,
                icon: Icons.account_balance_wallet_outlined,
                activeIcon: Icons.account_balance_wallet_rounded,
                label: 'Pembayaran',
                activeAliases: ['wallet', 'keuangan'],
              ),
            const RoleMenuEntry(
              routeKey: 'profil',
              routePath: AppRoutes.profil,
              mainNavIndex: 9,
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profil Perusahaan',
              activeAliases: ['profil_akun'],
            ),
            const RoleMenuEntry(
              routeKey: 'pengaturan',
              routePath: AppRoutes.pengaturan,
              mainNavIndex: 8,
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings_rounded,
              label: 'Pengaturan',
              activeAliases: ['pengaturan_akun'],
            ),
          ],
        ),
      );
      return sections;
    }

    // Creator sub-role custom services or General Creator / Client
    if (hasSubRoleMenus) {
      final layananTitle = CreatorSidebarMenus.layananSectionTitle(user.subRole);
      final serviceEntries = CreatorSidebarMenus.layananItems(user.subRole);
      if (serviceEntries.isNotEmpty) {
        sections.add(
          RoleMenuSection(
            title: layananTitle ?? 'LAYANAN KREATOR',
            items: serviceEntries
                .map(
                  (e) => RoleMenuEntry(
                    routeKey: e.serviceKey ?? e.route ?? e.label,
                    creatorServiceEntry: e,
                    icon: e.icon,
                    label: e.label,
                  ),
                )
                .toList(),
          ),
        );
      }
    }

    final otherItems = <RoleMenuEntry>[
      if (SystemSettingsService.isCollaborationEnabled &&
          CreatorSidebarMenus.showKolaborasiInLainnya(user.subRole))
        const RoleMenuEntry(
          routeKey: 'kolaborasi',
          routePath: AppRoutes.kolaborasi,
          mainNavIndex: 5,
          icon: Icons.group_work_outlined,
          activeIcon: Icons.group_work_rounded,
          label: 'Kolaborasi',
          guestActionLabel: 'mengelola kolaborasi',
        ),
      if (creator && !user.isGuest)
        const RoleMenuEntry(
          routeKey: 'kapasitas_jadwal',
          routePath: AppRoutes.kapasitasJadwal,
          mainNavIndex: 13,
          icon: Icons.event_available_outlined,
          activeIcon: Icons.event_available_rounded,
          label: 'Kapasitas & Jadwal',
        ),
      if (creator && !user.isGuest)
        const RoleMenuEntry(
          routeKey: 'peluang_proyek',
          routePath: AppRoutes.peluangProyek,
          mainNavIndex: 12,
          icon: Icons.track_changes_outlined,
          activeIcon: Icons.track_changes_rounded,
          label: 'Job Seek',
        ),
      const RoleMenuEntry(
        routeKey: 'reputasi',
        routePath: AppRoutes.reputasi,
        mainNavIndex: 6,
        icon: Icons.star_outline_rounded,
        activeIcon: Icons.star_rounded,
        label: 'Reputasi',
        guestActionLabel: 'melihat ulasan & reputasi',
      ),
      if (SystemSettingsService.isWalletEnabled &&
          (!creator || CreatorSidebarMenus.showPaymentFeature(user.subRole)))
        const RoleMenuEntry(
          routeKey: 'pembayaran',
          routePath: AppRoutes.wallet,
          mainNavIndex: 7,
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet_rounded,
          label: 'Pembayaran',
          guestActionLabel: 'mengakses dompet & keuangan',
          activeAliases: ['wallet', 'keuangan'],
        ),
      const RoleMenuEntry(
        routeKey: 'profil',
        routePath: AppRoutes.profil,
        mainNavIndex: 9,
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profil Saya',
        guestActionLabel: 'melihat profil pengguna',
        activeAliases: ['profil_akun'],
      ),
      const RoleMenuEntry(
        routeKey: 'pengaturan',
        routePath: AppRoutes.pengaturan,
        mainNavIndex: 8,
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label: 'Pengaturan',
        guestActionLabel: 'membuka pengaturan akun',
        activeAliases: ['pengaturan_akun'],
      ),
    ];

    sections.add(RoleMenuSection(title: 'LAINNYA', items: otherItems));
    return sections;
  }

  /// Renders a responsive mobile [Drawer] containing the full desktop-parity role menu,
  /// upgrade promo banner, and authenticated profile / guest login footer.
  static Widget buildMobileDrawer({
    required BuildContext context,
    required UserModel user,
    required String activeRoute,
    int? activeMainNavIndex,
    int unreadMessages = 0,
    int unreadNotifications = 0,
    required void Function(RoleMenuEntry entry) onSelectEntry,
    required VoidCallback onOpenUpgrade,
    required VoidCallback onOpenProfile,
    required VoidCallback onLogout,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = accentColorFor(user);
    final sections = getRoleMenuSections(
      user,
      unreadMessages: unreadMessages,
      unreadNotifications: unreadNotifications,
    );
    final normalizedRoute = activeRoute.toLowerCase().trim();

    bool isEntrySelected(RoleMenuEntry e) {
      if (activeMainNavIndex != null && e.mainNavIndex != null) {
        if (e.mainNavIndex == activeMainNavIndex) return true;
      }
      if (e.routeKey.toLowerCase() == normalizedRoute) return true;
      return e.activeAliases.any((a) => a.toLowerCase() == normalizedRoute);
    }

    return Drawer(
      width: 296,
      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Brand + Role badge header
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/brandlogo.png',
                      width: 34,
                      height: 34,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.auto_awesome_rounded,
                        color: accentColor,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kreavana',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            roleBadgeLabel(user),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Tutup Menu',
                  ),
                ],
              ),
            ),

            // Role-specific sections matching Desktop Sidebar
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                children: [
                  for (final section in sections) ...[
                    if (section.title != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                        child: Text(
                          section.title!,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: isDark
                                ? AppTheme.textMuted
                                : Colors.grey.shade500,
                          ),
                        ),
                      ),
                    for (final entry in section.items)
                      SidebarHoverTile(
                        icon: entry.icon,
                        activeIcon: entry.activeIcon,
                        label: entry.label,
                        isSelected: isEntrySelected(entry),
                        isDark: isDark,
                        activeColor: accentColor,
                        trailing: (entry.badgeCount != null && entry.badgeCount! > 0)
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  entry.badgeCount! > 99
                                      ? '99+'
                                      : '${entry.badgeCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () {
                          Navigator.of(context).pop();
                          onSelectEntry(entry);
                        },
                      ),
                  ],
                  if (!user.isAdmin &&
                      !user.isGuest &&
                      !user.isInstitutionStaff) ...[
                    const SizedBox(height: 12),
                    SidebarHoverTile(
                      icon: Icons.workspace_premium_outlined,
                      activeIcon: Icons.workspace_premium_rounded,
                      label: 'Upgrade Plan / Paket',
                      isSelected: false,
                      isDark: isDark,
                      activeColor: accentColor,
                      onTap: () {
                        Navigator.of(context).pop();
                        onOpenUpgrade();
                      },
                    ),
                  ],
                ],
              ),
            ),

            // User profile / auth footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark2 : Colors.grey.shade50,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
              ),
              child: user.isGuest
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              context.go(AppRoutes.login);
                            },
                            child: const Text('Masuk'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              context.go(AppRoutes.register);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Daftar'),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              Navigator.of(context).pop();
                              onOpenProfile();
                            },
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor:
                                      accentColor.withValues(alpha: 0.14),
                                  child: user.avatarUrl != null &&
                                          user.avatarUrl!.isNotEmpty
                                      ? ClipOval(
                                          child: KreavanaImage(
                                            url: user.avatarUrl,
                                            width: 36,
                                            height: 36,
                                            isAvatar: true,
                                          ),
                                        )
                                      : Icon(
                                          Icons.person_rounded,
                                          color: accentColor,
                                          size: 20,
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.white
                                              : AppTheme.textDark,
                                        ),
                                      ),
                                      Text(
                                        '@${user.username}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? AppTheme.textMuted
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: AppTheme.error,
                            size: 20,
                          ),
                          tooltip: 'Keluar Akun',
                          onPressed: () {
                            Navigator.of(context).pop();
                            onLogout();
                          },
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Convenience helper for denied features on any route.
  static void showDeniedFeatureMessage(BuildContext context, String message) {
    AppSnackbar.warning(context, message);
  }
}
