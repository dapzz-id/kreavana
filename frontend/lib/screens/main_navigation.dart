import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/upgrade_plan_modal.dart';
import '../widgets/auth_guard_dialog.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../features/auth/services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/api_service.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import 'marketing_dashboard_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'explore_screen.dart';
import '../services/user_store.dart';
import '../services/app_router.dart';
import 'package:go_router/go_router.dart';
import '../features/dashboard/screens/admin_dashboard_screen.dart';
import '../features/dashboard/screens/admin_resolution_screen.dart';
import 'admin_verification_screen.dart';
import 'creator_calendar_screen.dart';
import 'proyek_saya_screen.dart';
import 'agenda_screen.dart';
import 'kolaborasi_screen.dart';
import 'marketplace_karya_screen.dart';
import 'peluang_proyek_screen.dart';
import 'ulasan_reputasi_screen.dart';
import 'pengaturan_screen.dart';
import 'wallet_screen.dart';
import '../features/dashboard/screens/community_dashboard_screen.dart';
import 'creator_service_screen.dart';
import 'direct_message_screen.dart';
import '../app/subrole_theme_engine.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/creator_sidebar_menus.dart';
import '../widgets/kreavana_ai_floating_widget.dart';
import 'kreavana_ai_screen.dart';
import 'admin_system_settings_screen.dart';
import '../services/system_settings_service.dart';
import '../widgets/feature_disabled_view.dart';
import '../widgets/app_sweet_alert.dart';
import '../widgets/sidebar_hover_tile.dart';
import '../services/sidebar_scroll_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'not_found_screen.dart';
import '../services/badge_service.dart';
import '../widgets/role_navigation_helper.dart';

class MainNavigation extends StatefulWidget {
  final UserModel initialUser;
  final int initialIndex;

  const MainNavigation({
    super.key,
    required this.initialUser,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late UserModel _currentUser;
  int _currentIndex = 0;
  int _messageScreenVersion = 0;
  bool _isSidebarCollapsed = false;
  final GlobalKey<ScaffoldState> _mobileScaffoldKey = GlobalKey<ScaffoldState>();

  String _activeRouteKeyForIndex(int activeIndex) {
    if (_currentUser.isAdmin) {
      return switch (activeIndex) {
        0 => 'admin_dashboard',
        1 => 'admin_verification',
        2 => 'admin_resolution',
        3 => 'admin_settings',
        4 => 'admin_notifications',
        5 => 'admin_profile',
        _ => 'admin_dashboard',
      };
    }
    return switch (activeIndex) {
      0 => 'beranda',
      1 => 'explore',
      2 => 'proyek_saya',
      3 => 'marketplace',
      4 => 'agenda',
      5 => 'kolaborasi',
      6 => 'reputasi',
      7 => 'pembayaran',
      8 => 'pengaturan',
      9 => 'profil',
      10 => 'notifikasi',
      11 => 'pesan',
      12 => 'peluang_proyek',
      13 => 'kapasitas_jadwal',
      14 => 'ai',
      _ => 'beranda',
    };
  }

  Widget _buildRoleMobileDrawer(
    BuildContext context, {
    required String activeRouteKey,
    required int activeMainNavIndex,
    required int unreadMessages,
    required int unreadNotifications,
  }) {
    return RoleNavigationHelper.buildMobileDrawer(
      context: context,
      user: _currentUser,
      activeRoute: activeRouteKey,
      activeMainNavIndex: activeMainNavIndex,
      unreadMessages: unreadMessages,
      unreadNotifications: unreadNotifications,
      onSelectEntry: (entry) {
        if (entry.isAiAction) {
          if (!RoleNavigationHelper.checkGuestGuard(
            context,
            _currentUser,
            mainNavIndex: 14,
            guestActionLabel: entry.guestActionLabel,
          )) {
            return;
          }
          _navigateToScreenIndex(14);
          return;
        }
        final creatorEntry = entry.creatorServiceEntry;
        if (creatorEntry != null) {
          _handleCreatorMenuEntry(creatorEntry);
          return;
        }
        if (!RoleNavigationHelper.checkGuestGuard(
          context,
          _currentUser,
          mainNavIndex: entry.mainNavIndex,
          guestActionLabel: entry.guestActionLabel,
        )) {
          return;
        }
        if (entry.mainNavIndex != null) {
          _navigateToScreenIndex(entry.mainNavIndex!);
        } else if (entry.routePath != null) {
          _navigateToRoute(entry.routePath!);
        }
      },
      onOpenUpgrade: () =>
          UpgradePlanModal.show(context, user: _currentUser),
      onOpenProfile: () {
        if (_currentUser.isAdmin) {
          _navigateToScreenIndex(5);
        } else if (_isSchool || _isGovernment) {
          _navigateToRoute(AppRoutes.profilInstitusi);
        } else {
          _navigateToScreenIndex(9);
        }
      },
      onLogout: _showLogoutDialog,
    );
  }
  bool _isMobileDrawerOpen = false;
  final Set<int> _loadedScreenIndices = {};
  final Map<int, Widget> _screenCache = {};
  String? _activeGovRoute;
  late final ScrollController _sidebarScrollController;

  @override
  void initState() {
    super.initState();
    _sidebarScrollController = SidebarScrollManager.createController();
    _currentUser = widget.initialUser;
    _currentIndex = widget.initialIndex;
    _loadedScreenIndices.add(widget.initialIndex);
    SystemSettingsService.moduleStatuses.addListener(_onModuleStatusesChanged);
    currentUserNotifier.addListener(_onUserNotifierChanged);
    SidebarScrollManager.restoreScroll(_sidebarScrollController);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshProfile();
      }
    });
  }

  @override
  void didUpdateWidget(MainNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != _currentIndex) {
      setState(() {
        _currentIndex = widget.initialIndex;
        if (widget.initialIndex == 11) {
          _messageScreenVersion++;
          _screenCache.remove(widget.initialIndex);
        }
        _loadedScreenIndices.add(widget.initialIndex);
        _activeGovRoute = null;
      });
    }
    if (widget.initialUser != oldWidget.initialUser &&
        widget.initialUser != _currentUser) {
      setState(() {
        _currentUser = widget.initialUser;
        _screenCache.clear();
      });
    }
  }

  @override
  void dispose() {
    currentUserNotifier.removeListener(_onUserNotifierChanged);
    SystemSettingsService.moduleStatuses.removeListener(_onModuleStatusesChanged);
    _sidebarScrollController.dispose();
    super.dispose();
  }

  void _onUserNotifierChanged() {
    final newUser = currentUserNotifier.value;
    if (newUser != null && mounted && newUser != _currentUser) {
      setState(() {
        _currentUser = newUser;
        _screenCache.clear();
      });
    }
  }

  void _onModuleStatusesChanged() {
    if (mounted) {
      _screenCache.clear();
      setState(() {});
    }
  }

  Future<void> _refreshProfile() async {
    if (_currentUser.isGuest || _currentUser.id == null) return;
    final result = await ProfileService.getProfile(_currentUser.id ?? '');
    if (mounted) {
      setState(() {
        if (result.success == true && result.user != null) {
          _currentUser = result.user!;
          _screenCache.clear();
          currentUserNotifier.value = result.user!;
        }
      });
    }
  }

  void _onUserUpdated(UserModel updatedUser) {
    setState(() {
      _currentUser = updatedUser;
      _screenCache.clear();
    });
    currentUserNotifier.value = updatedUser;
  }

  void _onLogout() async {
    await AuthService.logout();
    currentUserNotifier.value = null;
    if (mounted) context.go(AppRoutes.login);
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar Akun'),
        content: const Text('Apakah Anda yakin ingin keluar dari Kreavana?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _onLogout();
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required ThemeData theme,
    required bool isDark,
    bool isCollapsed = false,
    bool isMobileDrawer = false,
    bool isAi = false,
  }) {
    final screensCount = _currentUser.isAdmin ? 6 : 15;
    final activeIndex = _currentIndex >= screensCount ? 0 : _currentIndex;
    final isSelected = activeIndex == index && _activeGovRoute == null;
    final defaultAccent = SubRoleThemeEngine.getAccentColorForUser(
      _currentUser,
    );
    final activeColor = isAi
        ? (_isCompany ? defaultAccent : const Color(0xFF8B5CF6))
        : defaultAccent;

    return SidebarHoverTile(
      icon: icon,
      activeIcon: activeIcon,
      label: label,
      onTap: () {
        if (isMobileDrawer) Navigator.pop(context);
        _navigateToScreenIndex(index);
        final shouldRefresh = _currentUser.isAdmin
            ? index == 2 || index == 3
            : index == 9 || index == 10;
        if (shouldRefresh) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _refreshProfile();
          });
        }
      },
      isSelected: isSelected,
      isDark: isDark,
      isCollapsed: isCollapsed,
      activeColor: activeColor,
      trailing: isAi
          ? Text(
              'AI',
              style: TextStyle(
                color: _isCompany ? defaultAccent : const Color(0xFF8B5CF6),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    );
  }

  Widget _buildSidebarLink({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    bool isCollapsed = false,
    bool isSelected = false,
    bool isMobileDrawer = false,
  }) {
    final activeColor = SubRoleThemeEngine.getAccentColorForUser(_currentUser);
    return SidebarHoverTile(
      icon: icon,
      label: label,
      onTap: () {
        if (isMobileDrawer) {
          Navigator.pop(context);
        }
        onTap();
      },
      isSelected: isSelected,
      isDark: isDark,
      isCollapsed: isCollapsed,
      activeColor: activeColor,
    );
  }

  bool get _isCreatorUser => CreatorSidebarMenus.isCreatorUser(_currentUser);

  bool get _hasSpecificCreatorSubRole =>
      CreatorSidebarMenus.hasSpecificSubRole(_currentUser.subRole);

  bool get _isCompany {
    final sub = CreatorSidebarMenus.normalizeSubRole(_currentUser.subRole);
    return !_currentUser.isAdmin &&
        (sub == 'company' ||
            sub == 'corporate' ||
            sub == 'business' ||
            sub == 'perusahaan' ||
            sub == 'bisnis' ||
            _currentUser.username == 'corporate_demo' ||
            _currentUser.email.startsWith('corporate@'));
  }

  static const _protectedIndexActionMap = {
    2: 'mengakses Manajemen Proyek',
    4: 'mengakses Agenda & Jadwal',
    5: 'mengakses Ruang Kolaborasi',
    6: 'melihat Ulasan & Reputasi',
    7: 'mengakses Dompet & Keuangan',
    8: 'membuka Pengaturan Akun',
    9: 'mengakses Profil Akun',
    10: 'melihat Notifikasi',
    11: 'mengakses Pesan & Chat',
    13: 'mengakses Kapasitas & Jadwal',
  };

  void _navigateToScreenIndex(int index) {
    if (_currentUser.isGuest && _protectedIndexActionMap.containsKey(index)) {
      AuthGuardDialog.show(
        context,
        actionName: _protectedIndexActionMap[index]!,
      );
      return;
    }

    if (!_currentUser.isAdmin) {
      if ((index == 1 || index == 12) && (_currentUser.isInstitution || _currentUser.isCorporate)) {
        AppSweetAlert.warning(
          context,
          'Menu Jelajahi tidak tersedia untuk akun ${_currentUser.isInstitution ? "Institusi Pendidikan" : "Corporate / Perusahaan"}.',
          title: 'Akses Dibatasi',
        );
        return;
      }
      if (_currentUser.isInstitution && _currentUser.isInstitutionStaff) {
        if (index == 2 && !_currentUser.hasInstitutionPermission('program_magang')) {
          AppSweetAlert.error(
            context,
            'Anda tidak memiliki izin untuk mengakses fitur Program & Magang.',
            title: 'Akses Ditolak (403)',
          );
          return;
        }
        if (index == 4 && !_currentUser.hasInstitutionPermission('kegiatan_event')) {
          AppSweetAlert.error(
            context,
            'Anda tidak memiliki izin untuk mengakses fitur Kegiatan & Event.',
            title: 'Akses Ditolak (403)',
          );
          return;
        }
      }
      if (index == 3 && !SystemSettingsService.isMarketplaceEnabled) {
        AppSweetAlert.warning(
          context,
          'Fitur Marketplace sedang dinonaktifkan oleh administrator.',
          title: 'Fitur Dinonaktifkan',
        );
        return;
      }
      if (index == 14 && !SystemSettingsService.isAiEnabled) {
        AppSweetAlert.warning(
          context,
          'Fitur Kreavana AI sedang dinonaktifkan oleh administrator.',
          title: 'Fitur Dinonaktifkan',
        );
        return;
      }
      if (index == 5 && !SystemSettingsService.isCollaborationEnabled) {
        AppSweetAlert.warning(
          context,
          'Fitur Kolaborasi sedang dinonaktifkan oleh administrator.',
          title: 'Fitur Dinonaktifkan',
        );
        return;
      }
      if (index == 5 && (_currentUser.isClient || !_isCreatorUser)) {
        AppSweetAlert.info(
          context,
          'Ruang Kolaborasi dirancang khusus untuk akun kreator berkarya bersama. Silakan gunakan menu Proyek Saya untuk mengelola proyek Anda.',
          title: 'Khusus Akun Kreator',
        );
        return;
      }
      if (index == 7 && !SystemSettingsService.isWalletEnabled) {
        AppSweetAlert.warning(
          context,
          'Fitur Pembayaran/Dompet sedang dinonaktifkan oleh administrator.',
          title: 'Fitur Dinonaktifkan',
        );
        return;
      }
      if (index == 11 && !SystemSettingsService.isDirectMessageEnabled) {
        AppSweetAlert.warning(
          context,
          'Fitur Pesan Langsung sedang dinonaktifkan oleh administrator.',
          title: 'Fitur Dinonaktifkan',
        );
        return;
      }
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    if (_sidebarScrollController.hasClients) {
      SidebarScrollManager.savedOffset = _sidebarScrollController.offset;
    }
    setState(() {
      _currentIndex = index;
      if (index == 11) {
        _messageScreenVersion++;
        _screenCache.remove(index);
      }
      _loadedScreenIndices.add(index);
      _activeGovRoute = null;
    });
    // Sync URL di web
    final route = AppRoutes.getRouteForIndex(
      index,
      isAdmin: _currentUser.isAdmin,
    );
    if (mounted) {
      context.go(route);
    }
  }

  Widget _buildSidebarSectionHeader(
    String title,
    bool isDark, {
    bool isCollapsed = false,
  }) {
    if (isCollapsed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white54 : Colors.grey.shade500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildUpgradePromoCard(bool isDark, {bool isCollapsed = false}) {
    if (isCollapsed) return const SizedBox.shrink();
    final effectiveUser = currentUserNotifier.value ?? _currentUser;
    final currentTier = effectiveUser.subscriptionTier.toLowerCase();
    final isSuper = currentTier == 'super';
    final isPro = currentTier == 'pro';
    final isPlus = currentTier == 'plus';

    final isGov = _isGovernment;
    final isSchool = _isSchool;
    final isCorporate = effectiveUser.role == 'corporate' ||
        effectiveUser.role == 'company' ||
        _isCompany;
    final isCreator = effectiveUser.role == 'creator' || _isCreatorUser;

    final String promoTitle;
    final String promoDesc;
    final String buttonLabel;

    if (isSuper) {
      promoTitle = 'Paket Super Aktif';
      promoDesc = 'Semua fitur & kuota premium tertinggi telah aktif.';
      buttonLabel = 'Lihat Detail Paket';
    } else if (isPro) {
      promoTitle = 'Paket Pro Aktif';
      promoDesc = 'Tingkatkan ke Super untuk kuota call & storage maksimal.';
      buttonLabel = 'Upgrade ke Super';
    } else if (isPlus) {
      promoTitle = 'Paket Plus Aktif';
      promoDesc = 'Tingkatkan ke Pro/Super untuk fitur AI & boost lebih tinggi.';
      buttonLabel = 'Tingkatkan Paket';
    } else if (isGov) {
      promoTitle = 'Upgrade Akun Pemerintah';
      promoDesc = 'Tingkatkan peluang & fitur premium untuk instansi pemerintah.';
      buttonLabel = 'Upgrade Sekarang';
    } else if (isSchool) {
      promoTitle = 'Upgrade Akun Institusi';
      promoDesc = 'Tingkatkan peluang & fitur premium untuk institusi pendidikan.';
      buttonLabel = 'Upgrade Sekarang';
    } else if (isCorporate) {
      promoTitle = 'Upgrade Akun Corporate';
      promoDesc = 'Tingkatkan peluang & fitur premium untuk corporate.';
      buttonLabel = 'Upgrade Sekarang';
    } else if (isCreator) {
      promoTitle = 'Upgrade Akun Kreator';
      promoDesc = 'Tingkatkan peluang & fitur premium untuk kreator.';
      buttonLabel = 'Upgrade Sekarang';
    } else {
      promoTitle = 'Upgrade Akun';
      promoDesc = 'Tingkatkan peluang & fitur premium akun Anda.';
      buttonLabel = 'Upgrade Sekarang';
    }

    final accentColor = SubRoleThemeEngine.getAccentColor(
      effectiveUser.role,
      effectiveUser.subRole,
    );

    return Column(
      children: [
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: SubRoleThemeEngine.getGradient(
                effectiveUser.role,
                effectiveUser.subRole,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  promoTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  promoDesc,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => UpgradePlanModal.show(context, user: effectiveUser),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      buttonLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  List<Widget> _buildDefaultLainnyaItems({
    required ThemeData theme,
    required bool isDark,
    required bool isCollapsed,
    bool isMobileDrawer = false,
  }) {
    return [
      if (!_currentUser.isClient &&
          ((_isCreatorUser && SystemSettingsService.isCollaborationEnabled) ||
              _currentUser.isAdmin))
        _buildSidebarItem(
          icon: Icons.handshake_outlined,
          activeIcon: Icons.handshake,
          label: 'Kolaborasi',
          index: 5,
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
      if (_isCreatorUser)
        _buildSidebarItem(
          icon: Icons.calendar_month_outlined,
          activeIcon: Icons.calendar_month,
          label: 'Kapasitas & Jadwal',
          index: 13,
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
      if (_isCreatorUser)
        _buildSidebarItem(
          icon: Icons.work_outline,
          activeIcon: Icons.work,
          label: 'Job Seek',
          index: 12,
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
      _buildSidebarItem(
        icon: Icons.star_border,
        activeIcon: Icons.star,
        label: 'Reputasi',
        index: 6,
        theme: theme,
        isDark: isDark,
        isCollapsed: isCollapsed,
        isMobileDrawer: isMobileDrawer,
      ),
      if (SystemSettingsService.isWalletEnabled || _currentUser.isAdmin)
        _buildSidebarItem(
          icon: Icons.payment_outlined,
          activeIcon: Icons.payment,
          label: 'Pembayaran',
          index: 7,
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
      if (!isMobileDrawer)
        _buildSidebarLink(
          icon: Icons.workspace_premium_outlined,
          label: 'Upgrade Plan / Paket',
          onTap: () => UpgradePlanModal.show(context),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: false,
          isMobileDrawer: isMobileDrawer,
        ),
      _buildSidebarItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'Pengaturan',
        index: 8,
        theme: theme,
        isDark: isDark,
        isCollapsed: isCollapsed,
        isMobileDrawer: isMobileDrawer,
      ),
      if (!isMobileDrawer)
        _buildUpgradePromoCard(isDark, isCollapsed: isCollapsed),
    ];
  }

  void _handleCreatorMenuEntry(CreatorSidebarMenuEntry entry) {
    if (entry.serviceKey != null) {
      if (entry.serviceKey!.startsWith('komunitas_')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommunityDashboardScreen(
              user: _currentUser,
              initialServiceKey: entry.serviceKey,
              onUserUpdated: _onUserUpdated,
              showSidebar: true,
            ),
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreatorServiceScreen(
            user: _currentUser,
            serviceKey: entry.serviceKey!,
            onUserUpdated: _onUserUpdated,
          ),
        ),
      );
      return;
    }
    final index = switch (entry.route) {
      'marketplace' => 3,
      'agenda' => 4,
      'proyek' => 2,
      'kolaborasi' => 5,
      'kapasitas_jadwal' => 13,
      _ => null,
    };
    if (index != null) _navigateToScreenIndex(index);
  }

  void _navigateToRoute(String path) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    if (_sidebarScrollController.hasClients) {
      SidebarScrollManager.savedOffset = _sidebarScrollController.offset;
    }
    setState(() {
      _isMobileDrawerOpen = false;
      _activeGovRoute = null;
    });
    if (mounted) {
      context.go(path);
    }
  }

  List<Widget> _buildCreatorSidebarItems({
    required ThemeData theme,
    required bool isDark,
    required bool isCollapsed,
    bool isMobileDrawer = false,
  }) {
    final layananTitle = CreatorSidebarMenus.layananSectionTitle(
      _currentUser.subRole,
    );
    final layananItems = CreatorSidebarMenus.layananItems(_currentUser.subRole);

    if (layananTitle == null || layananItems.isEmpty) {
      return _buildDefaultLainnyaItems(
        theme: theme,
        isDark: isDark,
        isCollapsed: isCollapsed,
        isMobileDrawer: isMobileDrawer,
      );
    }

    return [
      const SizedBox(height: 18),
      _buildSidebarSectionHeader(
        layananTitle,
        isDark,
        isCollapsed: isCollapsed,
      ),
      ...layananItems.map((entry) {
        final index = switch (entry.route) {
          'marketplace' => 3,
          'agenda' => 4,
          'proyek' => 2,
          'kolaborasi' => 5,
          'kapasitas_jadwal' => 13,
          _ => null,
        };
        return _buildSidebarLink(
          icon: entry.icon,
          label: entry.label,
          onTap: () => _handleCreatorMenuEntry(entry),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected:
              index != null && _currentIndex == index && _activeGovRoute == null,
          isMobileDrawer: isMobileDrawer,
        );
      }),
      const SizedBox(height: 18),
      _buildSidebarSectionHeader('LAINNYA', isDark, isCollapsed: isCollapsed),
      if (!_currentUser.isClient &&
          CreatorSidebarMenus.showKolaborasiInLainnya(_currentUser.subRole) &&
          (SystemSettingsService.isCollaborationEnabled || _currentUser.isAdmin))
        _buildSidebarItem(
          icon: Icons.handshake_outlined,
          activeIcon: Icons.handshake,
          label: 'Kolaborasi',
          index: 5,
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
      _buildSidebarItem(
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month,
        label: 'Kapasitas & Jadwal',
        index: 13,
        theme: theme,
        isDark: isDark,
        isCollapsed: isCollapsed,
        isMobileDrawer: isMobileDrawer,
      ),
      _buildSidebarItem(
        icon: Icons.star_border,
        activeIcon: Icons.star,
        label: 'Reputasi',
        index: 6,
        theme: theme,
        isDark: isDark,
        isCollapsed: isCollapsed,
        isMobileDrawer: isMobileDrawer,
      ),
      if (SystemSettingsService.isWalletEnabled || _currentUser.isAdmin)
        _buildSidebarItem(
          icon: Icons.payment_outlined,
          activeIcon: Icons.payment,
          label: 'Pembayaran',
          index: 7,
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
      if (!isMobileDrawer)
        _buildSidebarLink(
          icon: Icons.workspace_premium_outlined,
          label: 'Upgrade Plan / Paket',
          onTap: () => UpgradePlanModal.show(context),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: false,
          isMobileDrawer: isMobileDrawer,
        ),
      _buildSidebarItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'Pengaturan',
        index: 8,
        theme: theme,
        isDark: isDark,
        isCollapsed: isCollapsed,
        isMobileDrawer: isMobileDrawer,
      ),
      if (!isMobileDrawer)
        _buildUpgradePromoCard(isDark, isCollapsed: isCollapsed),
    ];
  }

  List<Widget> _buildSidebarItemsList({
    required ThemeData theme,
    required bool isDark,
    required bool isCollapsed,
    bool isMobileDrawer = false,
  }) {
    if (_currentUser.isAdmin) {
      return [
        _buildSidebarItem(
          icon: Icons.admin_panel_settings_outlined,
          activeIcon: Icons.admin_panel_settings,
          label: 'Dasbor Admin',
          index: 0,
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarItem(
          icon: Icons.verified_user_outlined,
          activeIcon: Icons.verified_user,
          label: 'Verifikasi Akun',
          index: 1,
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarItem(
          icon: Icons.warning_amber_rounded,
          activeIcon: Icons.warning,
          label: 'Resolusi & Dispute',
          index: 2,
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarItem(
          icon: Icons.settings_suggest_outlined,
          activeIcon: Icons.settings_suggest_rounded,
          label: 'Pengaturan Sistem',
          index: 3,
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarItem(
          icon: Icons.notifications_none_outlined,
          activeIcon: Icons.notifications,
          label: 'Notifikasi',
          index: 4,
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarItem(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'Profil Saya',
          index: 5,
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
      ];
    }

    return [
      _buildSidebarItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Beranda',
        index: 0,
        theme: theme,
        isDark: isDark,
        isCollapsed: isCollapsed,
        isMobileDrawer: isMobileDrawer,
      ),
      if (SystemSettingsService.isAiEnabled || _currentUser.isAdmin)
        _buildSidebarItem(
          icon: Icons.auto_awesome_outlined,
          activeIcon: Icons.auto_awesome_rounded,
          label: 'Kreavana AI',
          index: 14,
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
          isAi: true,
        ),
      if (_isCreatorUser && !_isGovernment && !_isSchool && !_isCompany)
        _buildSidebarItem(
          icon: Icons.explore_outlined,
          activeIcon: Icons.explore,
          label: 'Rekomendasi Peluang',
          index: 1,
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
      if (!_isGovernment)
        _buildSidebarItem(
          icon: Icons.folder_outlined,
          activeIcon: Icons.folder,
          label: 'Proyek Saya',
          index: 2,
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
      if (SystemSettingsService.isDirectMessageEnabled || _currentUser.isAdmin)
        _buildSidebarItem(
          icon: Icons.chat_bubble_outline_rounded,
          activeIcon: Icons.chat_bubble_rounded,
          label: 'Direct Message',
          index: 11,
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
      if (_isSchool && (SystemSettingsService.isWalletEnabled || _currentUser.isAdmin))
        _buildSidebarItem(
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet_rounded,
          label: 'Dompet & Pembayaran',
          index: 7,
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
      if (!_hasSpecificCreatorSubRole && !_isCompany && !_isSchool && !_isGovernment) ...[
        if (SystemSettingsService.isMarketplaceEnabled || _currentUser.isAdmin)
          _buildSidebarItem(
            icon: Icons.storefront_outlined,
            activeIcon: Icons.storefront,
            label: 'Marketplace',
            index: 3,
            theme: theme,
            isDark: isDark,
            isCollapsed: isCollapsed,
            isMobileDrawer: isMobileDrawer,
          ),
        if (_isCreatorUser)
          _buildSidebarItem(
            icon: Icons.calendar_today_outlined,
            activeIcon: Icons.calendar_today,
            label: 'Agenda',
            index: 4,
            theme: theme,
            isDark: isDark,
            isCollapsed: isCollapsed,
            isMobileDrawer: isMobileDrawer,
          ),
      ],
      if (!isCollapsed && _isGovernment) ...[
        const SizedBox(height: 18),
        _buildSidebarSectionHeader('PENGELOLAAN', isDark),
      ] else if (!isCollapsed && _isCompany) ...[
        const SizedBox(height: 18),
        _buildSidebarSectionHeader('PENGELOLAAN PERUSAHAAN', isDark),
      ] else if (!isCollapsed &&
          !_isGovernment &&
          !_isSchool &&
          !_isCompany &&
          !_hasSpecificCreatorSubRole) ...[
        const SizedBox(height: 18),
        _buildSidebarSectionHeader('LAINNYA', isDark),
      ],
      if (_isSchool) ...[
        if (_currentUser.hasInstitutionPermission('program_magang') ||
            _currentUser.hasInstitutionPermission('kegiatan_event') ||
            _currentUser.hasInstitutionPermission('mitra_industri') ||
            _currentUser.hasInstitutionPermission('karya_siswa')) ...[
          if (!isCollapsed) ...[
            const SizedBox(height: 18),
            _buildSidebarSectionHeader('PENGELOLAAN INSTITUSI', isDark),
          ],
          if (_currentUser.hasInstitutionPermission('program_magang'))
            _buildSidebarLink(
              icon: Icons.work_outline,
              label: 'Program & Magang',
              onTap: () => _navigateToRoute(AppRoutes.programMagang),
              isDark: isDark,
              isCollapsed: isCollapsed,
              isSelected: _activeGovRoute == 'program_magang',
              isMobileDrawer: isMobileDrawer,
            ),
          if (_currentUser.hasInstitutionPermission('kegiatan_event'))
            _buildSidebarLink(
              icon: Icons.event_outlined,
              label: 'Kegiatan & Event',
              onTap: () => _navigateToScreenIndex(4),
              isDark: isDark,
              isCollapsed: isCollapsed,
              isSelected: _currentIndex == 4 && _activeGovRoute == null,
              isMobileDrawer: isMobileDrawer,
            ),
          if (_currentUser.hasInstitutionPermission('mitra_industri'))
            _buildSidebarLink(
              icon: Icons.diversity_3_outlined,
              label: 'Mitra Industri & Sanggar',
              onTap: () => _navigateToRoute(AppRoutes.mitraIndustri),
              isDark: isDark,
              isCollapsed: isCollapsed,
              isSelected: _activeGovRoute == 'mitra_komunitas',
              isMobileDrawer: isMobileDrawer,
            ),
          if (_currentUser.hasInstitutionPermission('karya_siswa'))
            _buildSidebarLink(
              icon: Icons.palette_outlined,
              label: 'Karya & Portofolio Peserta',
              onTap: () => _navigateToRoute(AppRoutes.karyaSiswa),
              isDark: isDark,
              isCollapsed: isCollapsed,
              isSelected: _activeGovRoute == 'karya_siswa',
              isMobileDrawer: isMobileDrawer,
            ),
        ],
        if (_currentUser.hasInstitutionPermission('dokumen_institusi')) ...[
          if (!isCollapsed) ...[
            const SizedBox(height: 18),
            _buildSidebarSectionHeader('DATA & DOKUMEN', isDark),
          ],
          _buildSidebarLink(
            icon: Icons.folder_outlined,
            label: 'Dokumen & MoU',
            onTap: () => _navigateToRoute(AppRoutes.dokumenInstitusi),
            isDark: isDark,
            isCollapsed: isCollapsed,
            isSelected: _activeGovRoute == 'dokumen_instansi',
            isMobileDrawer: isMobileDrawer,
          ),
        ],
        if (!isCollapsed) ...[
          const SizedBox(height: 18),
          _buildSidebarSectionHeader('PENGATURAN', isDark),
        ],
        if (_currentUser.isInstitutionAdmin)
          _buildSidebarLink(
            icon: Icons.account_balance_outlined,
            label: 'Profil Institusi',
            onTap: () => _navigateToRoute(AppRoutes.profilInstitusi),
            isDark: isDark,
            isCollapsed: isCollapsed,
            isSelected: _activeGovRoute == 'profil_instansi',
            isMobileDrawer: isMobileDrawer,
          ),
        _buildSidebarLink(
          icon: Icons.settings_outlined,
          label: 'Pengaturan Akun',
          onTap: () => _navigateToScreenIndex(8),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _currentIndex == 8 && _activeGovRoute == null,
          isMobileDrawer: isMobileDrawer,
        ),
        if (_currentUser.isInstitutionAdmin)
          _buildSidebarLink(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Tim & Hak Akses',
            onTap: () => _navigateToRoute(AppRoutes.timHakAkses),
            isDark: isDark,
            isCollapsed: isCollapsed,
            isSelected: _activeGovRoute == 'tim_hak_akses',
            isMobileDrawer: isMobileDrawer,
          ),
        if (!isMobileDrawer)
          _buildUpgradePromoCard(isDark, isCollapsed: isCollapsed),
      ] else if (_isGovernment) ...[
        _buildSidebarLink(
          icon: Icons.campaign_outlined,
          label: 'Peluang & Program',
          onTap: () => _navigateToScreenIndex(2),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _currentIndex == 2 && _activeGovRoute == null,
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarLink(
          icon: Icons.event_outlined,
          label: 'Kegiatan & Event',
          onTap: () => _navigateToScreenIndex(4),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _currentIndex == 4 && _activeGovRoute == null,
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarLink(
          icon: Icons.handshake_outlined,
          label: 'Tender & Kolaborasi',
          onTap: () => _navigateToRoute(AppRoutes.pengadaanVendor),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _activeGovRoute == 'tender_kolaborasi',
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarLink(
          icon: Icons.people_outlined,
          label: 'Daftar Kreator & Vendor',
          onTap: () => _navigateToScreenIndex(1),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _currentIndex == 1 && _activeGovRoute == null,
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarLink(
          icon: Icons.diversity_3_outlined,
          label: 'Mitra & Komunitas',
          onTap: () => _navigateToRoute(AppRoutes.mitraIndustri),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _activeGovRoute == 'mitra_komunitas',
          isMobileDrawer: isMobileDrawer,
        ),
        if (!isCollapsed) ...[
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'PEMANTAUAN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white54 : Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
        _buildSidebarLink(
          icon: Icons.summarize_outlined,
          label: 'Laporan Kegiatan',
          onTap: () => _navigateToRoute(AppRoutes.laporanKegiatan),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _activeGovRoute == 'laporan',
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarLink(
          icon: Icons.account_balance_outlined,
          label: 'Realisasi Anggaran',
          onTap: () => _navigateToRoute(AppRoutes.realisasiAnggaran),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _activeGovRoute == 'realisasi_anggaran',
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarLink(
          icon: Icons.monitor_outlined,
          label: 'Monitoring & Evaluasi',
          onTap: () => _navigateToRoute(AppRoutes.monitoringEvaluasi),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _activeGovRoute == 'monitoring_evaluasi',
          isMobileDrawer: isMobileDrawer,
        ),
        if (!isCollapsed) ...[
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'DATA & DOKUMEN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white54 : Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
        _buildSidebarLink(
          icon: Icons.folder_outlined,
          label: 'Dokumen Instansi',
          onTap: () => _navigateToRoute(AppRoutes.dokumenInstitusi),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _activeGovRoute == 'dokumen_instansi',
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarLink(
          icon: Icons.campaign_outlined,
          label: 'Pengumuman Publik',
          onTap: () => _navigateToRoute(AppRoutes.pengumumanInstitusi),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _activeGovRoute == 'pengumuman_publik',
          isMobileDrawer: isMobileDrawer,
        ),
        if (!isCollapsed) ...[
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'PENGATURAN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white54 : Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
        _buildSidebarLink(
          icon: Icons.account_balance_outlined,
          label: 'Profil Instansi',
          onTap: () => _navigateToRoute(AppRoutes.profilInstitusi),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _activeGovRoute == 'profil_instansi',
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarLink(
          icon: Icons.settings_outlined,
          label: 'Pengaturan Akun',
          onTap: () => _navigateToScreenIndex(8),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _currentIndex == 8 && _activeGovRoute == null,
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarLink(
          icon: Icons.admin_panel_settings_outlined,
          label: 'Tim & Hak Akses',
          onTap: () => _navigateToRoute(AppRoutes.timHakAkses),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _activeGovRoute == 'tim_hak_akses',
          isMobileDrawer: isMobileDrawer,
        ),
        if (!isMobileDrawer)
          _buildUpgradePromoCard(isDark, isCollapsed: isCollapsed),
      ] else if (_isCompany) ...[
        _buildSidebarLink(
          icon: Icons.work_outline_rounded,
          label: 'Lowongan Kerja & Magang',
          onTap: () => _navigateToRoute(AppRoutes.lowonganCorporate),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _activeGovRoute == 'lowongan_magang',
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarLink(
          icon: Icons.assignment_outlined,
          label: 'Pengadaan & Tender (RFP)',
          onTap: () => _navigateToRoute(AppRoutes.pengadaanVendor),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _activeGovRoute == 'tender_kolaborasi',
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarLink(
          icon: Icons.business_center_outlined,
          label: 'Mitra & Vendor B2B',
          onTap: () => _navigateToRoute(AppRoutes.mitraIndustri),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _activeGovRoute == 'mitra_komunitas',
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarLink(
          icon: Icons.verified_outlined,
          label: 'Otorisasi PO & MoU',
          onTap: () => _navigateToRoute(AppRoutes.dokumenInstitusi),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _activeGovRoute == 'dokumen_instansi',
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarLink(
          icon: Icons.account_balance_outlined,
          label: 'Alokasi Anggaran & Pajak',
          onTap: () => _navigateToRoute(AppRoutes.realisasiAnggaran),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _activeGovRoute == 'realisasi_anggaran',
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarLink(
          icon: Icons.summarize_outlined,
          label: 'Laporan & Audit B2B',
          onTap: () => _navigateToRoute(AppRoutes.laporanKegiatan),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _activeGovRoute == 'laporan',
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarLink(
          icon: Icons.storefront_outlined,
          label: 'Cari Kreator & Vendor',
          onTap: () {
            if (_currentUser.isGuest) {
              AuthGuardDialog.show(context, actionName: 'mencari kreator & vendor');
              return;
            }
            _navigateToScreenIndex(3);
          },
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _currentIndex == 3 && _activeGovRoute == null,
          isMobileDrawer: isMobileDrawer,
        ),
        if (!isCollapsed) ...[
          const SizedBox(height: 18),
          _buildSidebarSectionHeader('LAINNYA', isDark),
        ],
        if (SystemSettingsService.isWalletEnabled || _currentUser.isAdmin)
          _buildSidebarItem(
            icon: Icons.payment_outlined,
            activeIcon: Icons.payment,
            label: 'Pembayaran',
            index: 7,
            theme: theme,
            isDark: isDark,
            isCollapsed: isCollapsed,
            isMobileDrawer: isMobileDrawer,
          ),
        if (!isMobileDrawer)
          _buildSidebarLink(
            icon: Icons.workspace_premium_outlined,
            label: 'Upgrade Plan / Paket',
            onTap: () => UpgradePlanModal.show(context),
            isDark: isDark,
            isCollapsed: isCollapsed,
            isSelected: false,
            isMobileDrawer: isMobileDrawer,
          ),
        _buildSidebarItem(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings,
          label: 'Pengaturan',
          index: 8,
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
        if (!isMobileDrawer)
          _buildUpgradePromoCard(isDark, isCollapsed: isCollapsed),
      ] else if (_isCreatorUser && _hasSpecificCreatorSubRole) ...[
        ..._buildCreatorSidebarItems(
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
      ] else ...[
        ..._buildDefaultLainnyaItems(
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
      ],
    ];
  }

  Widget _buildUserBottomCard({
    required bool isDark,
    required bool isCollapsed,
  }) {
    if (_currentUser.isGuest) {
      if (isCollapsed) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          alignment: Alignment.center,
          child: Tooltip(
            message: 'Masuk / Daftar Akun',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go(AppRoutes.login),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.login_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1C2B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_circle_outlined,
                    size: 16,
                    color: Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Akses Akun',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Masuk atau daftar baru',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark
                              ? Colors.white60
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.go(AppRoutes.login),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.login_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Masuk',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.go(AppRoutes.register),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7.5),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : const Color(0xFFCBD5E1),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 14,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF334155),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Daftar',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(isCollapsed ? 10 : 16),
      child: isCollapsed
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: '${_currentUser.name} (@${_currentUser.username})',
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: isDark
                        ? const Color(0xFF2D2A3E)
                        : Colors.grey.shade200,
                    backgroundImage:
                        _currentUser.avatarUrl != null &&
                            _currentUser.avatarUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(
                            ApiService.resolveAssetUrl(_currentUser.avatarUrl!),
                          )
                        : null,
                    child:
                        _currentUser.avatarUrl == null ||
                            _currentUser.avatarUrl!.isEmpty
                        ? const Icon(
                            Icons.person,
                            color: AppTheme.primaryPurple,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Tooltip(
                  message: 'Keluar',
                  child: InkWell(
                    onTap: _showLogoutDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.logout_rounded,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isDark
                      ? const Color(0xFF2D2A3E)
                      : Colors.grey.shade200,
                  backgroundImage:
                      _currentUser.avatarUrl != null &&
                          _currentUser.avatarUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(
                          ApiService.resolveAssetUrl(_currentUser.avatarUrl!),
                        )
                      : const AssetImage('assets/brandlogo.png')
                            as ImageProvider,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentUser.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '@${_currentUser.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _showLogoutDialog,
                ),
              ],
            ),
    );
  }

  Widget _buildClientDashboardScreen() {
    if (_currentUser.isMarketing) {
      return MarketingDashboardScreen(user: _currentUser);
    }
    if (_currentUser.role == 'creator' || _currentUser.isCreator) {
      return _buildCreatorDashboardScreen();
    }

    return DashboardScreen(
      user: _currentUser,
      onUserUpdated: _onUserUpdated,
    );
  }

  Widget _buildCreatorDashboardScreen() {
    return DashboardScreen(
      user: _currentUser,
      onUserUpdated: _onUserUpdated,
    );
  }

  bool get _isGovernment {
    final sub = CreatorSidebarMenus.normalizeSubRole(_currentUser.subRole);
    return (_currentUser.role == 'user' || _currentUser.role == 'creator') &&
        (sub == 'government' ||
            sub == 'pemerintah' ||
            sub == 'instansi');
  }

  bool get _isSchool {
    if (_currentUser.isInstitution) return true;
    final sub = CreatorSidebarMenus.normalizeSubRole(_currentUser.subRole);
    final role = _currentUser.role.toLowerCase().trim();
    final verif = _currentUser.verificationType?.toLowerCase().trim() ?? '';
    final uname = _currentUser.username.toLowerCase().trim();
    return (role == 'user' || role == 'creator' || role == 'institution' || role == 'school') &&
        (sub == 'institution' ||
            sub == 'institusi' ||
            sub == 'school' ||
            sub == 'education' ||
            sub == 'campus' ||
            sub == 'sekolah' ||
            sub == 'kampus' ||
            verif == 'institution' ||
            uname.contains('institution') ||
            uname.contains('sekolah') ||
            uname.contains('smk'));
  }

  Widget _buildScreenAt(int index) {
    if (!_loadedScreenIndices.contains(index)) {
      return const SizedBox.shrink();
    }

    if (_currentUser.isAdmin) {
      return switch (index) {
        0 => AdminDashboardScreen(user: _currentUser),
        1 => const AdminVerificationScreen(),
        2 => AdminResolutionScreen(user: _currentUser),
        3 => AdminSystemSettingsScreen(user: _currentUser),
        4 => NotificationsScreen(
          userId: _currentUser.id ?? '',
          user: _currentUser,
        ),
        5 => ProfileScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
          onLogout: _onLogout,
        ),
        _ => const SizedBox.shrink(),
      };
    }

    return switch (index) {
      0 => _buildClientDashboardScreen(),
      1 => _currentUser.isCorporate
          ? NotFoundScreen(
              title: 'Akses Dibatasi (403)',
              message:
                  'Fitur Jelajahi Kolaborasi tidak tersedia untuk akun Corporate / Perusahaan.',
              user: _currentUser,
            )
          : ExploreScreen(user: _currentUser),
      2 => ProyekSayaScreen(user: _currentUser),
      3 => (!SystemSettingsService.isMarketplaceEnabled && !_currentUser.isAdmin)
          ? FeatureDisabledView(
              featureName: 'Marketplace',
              icon: Icons.storefront_outlined,
              onBackToHome: () => _navigateToScreenIndex(0),
            )
          : MarketplaceKaryaScreen(user: _currentUser),
      4 => const AgendaScreen(),
      5 => (!SystemSettingsService.isCollaborationEnabled && !_currentUser.isAdmin)
          ? FeatureDisabledView(
              featureName: 'Kolaborasi',
              icon: Icons.handshake_outlined,
              onBackToHome: () => _navigateToScreenIndex(0),
            )
          : (_currentUser.isClient || (!_isCreatorUser && !_currentUser.isAdmin))
              ? FeatureDisabledView(
                  featureName: 'Kolaborasi (Khusus Kreator)',
                  icon: Icons.handshake_outlined,
                  onBackToHome: () => _navigateToScreenIndex(0),
                )
              : KolaborasiScreen(
                  user: _currentUser,
                  onUserUpdated: _onUserUpdated,
                ),
      6 => UlasanReputasiScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        ),
      7 => (!SystemSettingsService.isWalletEnabled && !_currentUser.isAdmin)
          ? FeatureDisabledView(
              featureName: 'Pembayaran & Dompet',
              icon: Icons.account_balance_wallet_outlined,
              onBackToHome: () => _navigateToScreenIndex(0),
            )
          : WalletScreen(
              user: _currentUser,
              onUserUpdated: _onUserUpdated,
            ),
      8 => PengaturanScreen(
        user: _currentUser,
        onUserUpdated: _onUserUpdated,
        onLogout: _onLogout,
      ),
      9 => ProfileScreen(
        user: _currentUser,
        onUserUpdated: _onUserUpdated,
        onLogout: _onLogout,
      ),
      10 => NotificationsScreen(
        userId: _currentUser.id ?? '',
        user: _currentUser,
      ),
      11 => (!SystemSettingsService.isDirectMessageEnabled && !_currentUser.isAdmin)
          ? FeatureDisabledView(
              featureName: 'Pesan Langsung (Direct Message)',
              icon: Icons.chat_bubble_outline_rounded,
              onBackToHome: () => _navigateToScreenIndex(0),
            )
          : DirectMessageScreen(
              key: ValueKey('messages_$_messageScreenVersion'),
              currentUser: _currentUser,
              showSidebar: false,
            ),
      12 => (_currentUser.isInstitution || _currentUser.isCorporate)
          ? NotFoundScreen(
              title: 'Akses Dibatasi (403)',
              message:
                  'Fitur Peluang Proyek tidak tersedia untuk akun ${_currentUser.isInstitution ? "Institusi Pendidikan" : "Corporate / Perusahaan"}.',
              user: _currentUser,
            )
          : PeluangProyekScreen(user: _currentUser),
      13 => CreatorCalendarScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        ),
      14 => (!SystemSettingsService.isAiEnabled && !_currentUser.isAdmin)
          ? FeatureDisabledView(
              featureName: 'Kreavana AI',
              icon: Icons.auto_awesome_rounded,
              onBackToHome: () => _navigateToScreenIndex(0),
            )
          : KreavanaAiScreen(user: _currentUser),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _getCachedScreen(int index) {
    if (!_loadedScreenIndices.contains(index)) {
      return const SizedBox.shrink();
    }
    return _screenCache.putIfAbsent(index, () => _buildScreenAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    final totalScreenCount = _currentUser.isAdmin ? 6 : 15;
    final activeIndex = _currentIndex >= totalScreenCount ? 0 : _currentIndex;
    _loadedScreenIndices.add(activeIndex);

    final List<Widget> screens = List.generate(
      totalScreenCount,
      _getCachedScreen,
    );
    final sidebarWidth = _isSidebarCollapsed ? 78.0 : 260.0;
    final bool hasPageFab =
        !_currentUser.isAdmin &&
        switch (activeIndex) {
          2 => true, // ProyekSayaScreen ('Buat Proyek Baru')
          3 => _currentUser.isCreator, // MarketplaceKaryaScreen ('Jual Karya')
          4 => true, // AgendaScreen ('Tambah Agenda')
          5 => _isCreatorUser, // KolaborasiScreen ('Ajukan Kolaborasi')
          11 => true, // DirectMessageScreen
          _ => false,
        };

    Widget scaffoldWidget;

    if (isDesktop) {
      scaffoldWidget = Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Sidebar ───────────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: sidebarWidth,
              height: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141221) : Colors.white,
                border: Border(
                  right: BorderSide(
                    color: isDark
                        ? const Color(0xFF2D2A3E)
                        : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: ClipRect(
                child: Column(
                  children: [
                    // ── Brand row ──────────────────────────────────────
                    Container(
                      height: 75,
                      alignment: Alignment.center,
                      child: _isSidebarCollapsed
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/brandlogo.png',
                                  width: 30,
                                  height: 30,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const Center(
                                    child: Icon(
                                      Icons.auto_awesome,
                                      color: AppTheme.primaryPurple,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.chevron_right_rounded,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.grey.shade600,
                                      size: 18,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => setState(
                                      () => _isSidebarCollapsed = false,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  Image.asset(
                                    'assets/brandlogo.png',
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => const Center(
                                      child: Icon(
                                        Icons.auto_awesome,
                                        color: AppTheme.primaryPurple,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Kreavana',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: Icon(
                                      Icons.chevron_left_rounded,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.grey.shade700,
                                      size: 20,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => setState(
                                      () => _isSidebarCollapsed = true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),

                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark
                          ? const Color(0xFF2D2A3E)
                          : Colors.grey.shade200,
                    ),

                    // ── Nav items ──────────────────────────────────────
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: const MaterialScrollBehavior().copyWith(
                          dragDevices: {
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.touch,
                            PointerDeviceKind.stylus,
                            PointerDeviceKind.trackpad,
                          },
                        ),
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is ScrollUpdateNotification) {
                              if (notification.metrics.axis == Axis.vertical) {
                                SidebarScrollManager.savedOffset =
                                    notification.metrics.pixels;
                              }
                            }
                            return false;
                          },
                          child: RawScrollbar(
                            controller: _sidebarScrollController,
                            thumbVisibility: false,
                            thickness: 4,
                            radius: const Radius.circular(4),
                            thumbColor: isDark
                                ? Colors.white.withValues(alpha: 0.25)
                                : Colors.black.withValues(alpha: 0.2),
                            child: ListView(
                              controller: _sidebarScrollController,
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.only(top: 12, bottom: 20),
                              children: _buildSidebarItemsList(
                                theme: theme,
                                isDark: isDark,
                                isCollapsed: _isSidebarCollapsed,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Bottom user card ───────────────────────────────
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark
                          ? const Color(0xFF2D2A3E)
                          : Colors.grey.shade200,
                    ),
                    _buildUserBottomCard(
                      isDark: isDark,
                      isCollapsed: _isSidebarCollapsed,
                    ),
                  ],
                ),
              ),
            ),

            // ─── Konten utama — full width sisa layar ─────────────────
            Expanded(
              child: IndexedStack(index: activeIndex, children: screens),
            ),
          ],
        ),
      );
    } else {
      // ─── Mobile Layout ─────────────────────────────────────────────────
      return ListenableBuilder(
        listenable: Listenable.merge([
          BadgeService(),
          SystemSettingsService.moduleStatuses,
        ]),
        builder: (context, _) {
          final badges = BadgeService();
          final activeRouteKey = _activeRouteKeyForIndex(activeIndex);
          final dests = RoleNavigationHelper.getMobileBottomNavDestinations(
            _currentUser,
            unreadMessages: badges.unreadMessages,
            unreadNotifications: badges.unreadNotifications,
          );
          final mobileBottomNavIndex =
              RoleNavigationHelper.resolveActiveBottomNavIndex(
                dests,
                activeRouteKey,
                mainNavIndex: activeIndex,
              );

          final mobileScaffold = Scaffold(
            key: _mobileScaffoldKey,
            drawer: _buildRoleMobileDrawer(
              context,
              activeRouteKey: activeRouteKey,
              activeMainNavIndex: activeIndex,
              unreadMessages: badges.unreadMessages,
              unreadNotifications: badges.unreadNotifications,
            ),
            onDrawerChanged: (isOpen) {
              setState(() {
                _isMobileDrawerOpen = isOpen;
              });
            },
            body: SafeArea(
              bottom: false,
              child: IndexedStack(index: activeIndex, children: screens),
            ),
            bottomNavigationBar: CustomBottomNavBar(
              currentIndex: mobileBottomNavIndex,
              onTap: (navIndex) {
                if (navIndex < 0 || navIndex >= dests.length) return;
                final dest = dests[navIndex];
                if (dest.isMenuTrigger) {
                  _mobileScaffoldKey.currentState?.openDrawer();
                  return;
                }
                if (!RoleNavigationHelper.checkGuestGuard(
                  context,
                  _currentUser,
                  mainNavIndex: dest.mainNavIndex,
                )) {
                  return;
                }
                if (dest.mainNavIndex != null) {
                  if (dest.mainNavIndex == 11 &&
                      Navigator.of(context).canPop()) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                  _navigateToScreenIndex(dest.mainNavIndex!);
                } else if (dest.routePath != null) {
                  _navigateToRoute(dest.routePath!);
                }
              },
              items: dests.map((d) => d.toBottomNavItem()).toList(),
            ),
          );

          return KreavanaShellScope(
            onOpenDrawer: () => _mobileScaffoldKey.currentState?.openDrawer(),
            child: Stack(
              children: [
                mobileScaffold,
                if (!_isMobileDrawerOpen &&
                    activeIndex != 14 &&
                    (SystemSettingsService.isAiEnabled || _currentUser.isAdmin))
                  KreavanaAiFloatingWidget(hasPageFab: hasPageFab),
              ],
            ),
          );
        },
      );
    }

    return Stack(
      children: [
        scaffoldWidget,
        if (!_isMobileDrawerOpen &&
            activeIndex != 14 &&
            (SystemSettingsService.isAiEnabled || _currentUser.isAdmin))
          KreavanaAiFloatingWidget(hasPageFab: hasPageFab),
      ],
    );
  }
}
