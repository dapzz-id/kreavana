import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/upgrade_plan_modal.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../features/auth/services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/api_service.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/dashboard/screens/govt_dashboard_screen.dart';
import 'tender_kolaborasi_screen.dart';
import 'mitra_komunitas_screen.dart';
import 'realisasi_anggaran_screen.dart';
import 'monitoring_evaluasi_screen.dart';
import 'dokumen_instansi_screen.dart';
import 'pengumuman_publik_screen.dart';
import 'marketing_dashboard_screen.dart';
import 'tim_hak_akses_screen.dart';
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
import 'laporan_screen.dart';
import 'pengaturan_screen.dart';
import 'wallet_screen.dart';
import '../features/dashboard/screens/company_dashboard_screen.dart';
import '../features/dashboard/screens/eo_dashboard_screen.dart';
import '../features/dashboard/screens/wo_dashboard_screen.dart';
import '../features/dashboard/screens/school_dashboard_screen.dart';
import '../features/dashboard/screens/tourism_dashboard_screen.dart';
import '../features/dashboard/screens/individual_dashboard_screen.dart';
import '../features/dashboard/screens/community_dashboard_screen.dart';
import '../features/dashboard/screens/creator_general_dashboard_screen.dart';
import '../features/dashboard/screens/creator_fotografer_dashboard_screen.dart';
import '../features/dashboard/screens/creator_videografer_dashboard_screen.dart';
import '../features/dashboard/screens/creator_editor_dashboard_screen.dart';
import '../features/dashboard/screens/creator_desainer_dashboard_screen.dart';
import '../features/dashboard/screens/creator_mua_dashboard_screen.dart';
import '../features/dashboard/screens/creator_talent_dashboard_screen.dart';
import '../features/dashboard/screens/creator_drone_dashboard_screen.dart';
import '../features/dashboard/screens/creator_content_dashboard_screen.dart';
import '../features/dashboard/screens/creator_animator_dashboard_screen.dart';
import '../features/dashboard/screens/umkm_dashboard_screen.dart';
import '../features/dashboard/screens/agency_dashboard_screen.dart';
import 'creator_service_screen.dart';
import 'direct_message_screen.dart';
import '../app/subrole_theme_engine.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/creator_sidebar_menus.dart';
import '../widgets/kreavana_ai_floating_widget.dart';
import 'kreavana_ai_screen.dart';
import 'admin_system_settings_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  bool _isSidebarCollapsed = false;
  bool _isMobileDrawerOpen = false;
  final Set<int> _loadedScreenIndices = {};
  String? _activeGovRoute;
  final ScrollController _sidebarScrollController = ScrollController();
  static double _savedSidebarScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.initialUser;
    _currentIndex = widget.initialIndex;
    _loadedScreenIndices.add(widget.initialIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshProfile();
        if (_sidebarScrollController.hasClients) {
          _sidebarScrollController.jumpTo(_savedSidebarScrollOffset);
        }
      }
    });
  }

  @override
  void dispose() {
    _sidebarScrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    if (_currentUser.isGuest || _currentUser.id == null) return;
    final result = await ProfileService.getProfile(_currentUser.id ?? '');
    if (mounted) {
      setState(() {
        if (result.success == true && result.user != null) {
          _currentUser = result.user!;
        }
      });
    }
  }

  void _onUserUpdated(UserModel updatedUser) {
    setState(() => _currentUser = updatedUser);
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
    final isSelected = activeIndex == index;
    final defaultAccent = SubRoleThemeEngine.getAccentColorForUser(_currentUser);
    final activeColor = isAi ? const Color(0xFF8B5CF6) : defaultAccent;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 8 : 12,
        vertical: 2,
      ),
      child: Tooltip(
        message: isCollapsed ? label : '',
        child: InkWell(
          onTap: () {
            if (isMobileDrawer) {
              Navigator.pop(context);
            }
            _navigateToScreenIndex(index);
            if (_currentUser.isAdmin) {
              if (index == 2 || index == 3) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _refreshProfile();
                });
              }
            } else {
              if (index == 9 || index == 10) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _refreshProfile();
                });
              }
            }
          },
          borderRadius: BorderRadius.circular(12),
          hoverColor: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 0 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: isDark ? 0.18 : 0.09)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(
                      color: activeColor.withValues(alpha: isDark ? 0.35 : 0.2),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                if (!isCollapsed && isSelected) ...[
                  Container(
                    width: 3.5,
                    height: 16,
                    decoration: BoxDecoration(
                      gradient: isAi
                          ? const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                            )
                          : AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (isAi && isSelected)
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Icon(
                      activeIcon,
                      color: Colors.white,
                      size: 20,
                    ),
                  )
                else if (isAi)
                  Icon(
                    icon,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                    size: 20,
                  )
                else
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected
                        ? activeColor
                        : (isDark ? AppTheme.textMuted : AppTheme.textSecondary),
                    size: 20,
                  ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 13.5,
                        color: isSelected
                            ? (isDark ? Colors.white : activeColor)
                            : (isDark ? Colors.white70 : AppTheme.textPrimary),
                        letterSpacing: isSelected ? 0.1 : 0,
                      ),
                    ),
                  ),
                  if (isAi)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                              )
                            : null,
                        color: isSelected
                            ? null
                            : (isDark
                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.2)
                                : const Color(0xFF8B5CF6).withValues(alpha: 0.12)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'AI',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF8B5CF6),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
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
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 8 : 12,
        vertical: 2,
      ),
      child: Tooltip(
        message: isCollapsed ? label : '',
        child: InkWell(
          onTap: () {
            if (isMobileDrawer) {
              Navigator.pop(context);
            }
            onTap();
          },
          borderRadius: BorderRadius.circular(12),
          hoverColor: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 0 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: isDark ? 0.18 : 0.09)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(
                      color: activeColor.withValues(alpha: isDark ? 0.35 : 0.2),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                if (!isCollapsed && isSelected) ...[
                  Container(
                    width: 3.5,
                    height: 16,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  icon,
                  color: isSelected
                      ? activeColor
                      : (isDark ? AppTheme.textMuted : AppTheme.textSecondary),
                  size: 20,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 13.5,
                        color: isSelected
                            ? (isDark ? Colors.white : activeColor)
                            : (isDark ? Colors.white70 : AppTheme.textPrimary),
                        letterSpacing: isSelected ? 0.1 : 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _isCreatorUser => CreatorSidebarMenus.isCreatorUser(_currentUser);

  bool get _hasSpecificCreatorSubRole =>
      CreatorSidebarMenus.hasSpecificSubRole(_currentUser.subRole);

  /// Index → URL mapping (kebalikan dari _routeIndexMap di app_router.dart)
  static const _indexRouteMap = {
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

  static const _adminIndexRouteMap = {
    0: AppRoutes.adminDashboard,
    1: AppRoutes.adminVerification,
    2: AppRoutes.adminResolution,
    3: AppRoutes.adminSystemSettings,
    4: AppRoutes.notifikasi,
    5: AppRoutes.profil,
  };

  void _navigateToScreenIndex(int index) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    if (_sidebarScrollController.hasClients) {
      _savedSidebarScrollOffset = _sidebarScrollController.offset;
    }
    setState(() {
      _currentIndex = index;
      _loadedScreenIndices.add(index);
      _activeGovRoute = null;
    });
    // Sync URL di web
    final route = _currentUser.isAdmin
        ? _adminIndexRouteMap[index]
        : _indexRouteMap[index];
    if (route != null && mounted) {
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
    final isCreator = _currentUser.role == 'creator';
    final accentColor = SubRoleThemeEngine.getAccentColorForUser(_currentUser);
    return Column(
      children: [
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: SubRoleThemeEngine.getGradient(
                _currentUser.role,
                _currentUser.subRole,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.workspace_premium_outlined,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  isCreator ? 'Upgrade Akun Kreator' : 'Upgrade Plan & Paket',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isCreator
                      ? 'Tingkatkan peluang & fitur premium untuk kreator.'
                      : 'Nikmati kuota lebih tinggi, fitur AI, dan prioritas proyek.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => UpgradePlanModal.show(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Upgrade Sekarang',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
      _buildUpgradePromoCard(isDark, isCollapsed: isCollapsed),
    ];
  }

  void _handleCreatorMenuEntry(CreatorSidebarMenuEntry entry) {
    if (entry.serviceKey != null) {
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

  void _pushGovScreen(Widget destination) {
    if (_sidebarScrollController.hasClients) {
      _savedSidebarScrollOffset = _sidebarScrollController.offset;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            child,
      ),
    );
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
          isSelected: index != null && _currentIndex == index,
          isMobileDrawer: isMobileDrawer,
        );
      }),
      const SizedBox(height: 18),
      _buildSidebarSectionHeader('LAINNYA', isDark, isCollapsed: isCollapsed),
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
      if (CreatorSidebarMenus.showKolaborasiInLainnya(_currentUser.subRole))
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
        icon: Icons.star_border,
        activeIcon: Icons.star,
        label: 'Reputasi',
        index: 6,
        theme: theme,
        isDark: isDark,
        isCollapsed: isCollapsed,
        isMobileDrawer: isMobileDrawer,
      ),
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
          label: 'Verifikasi Kreator',
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
      if (_isCreatorUser) _buildSidebarItem(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore,
        label: 'Rekomendasi Peluang',
        index: 1,
        theme: theme,
        isDark: isDark,
        isCollapsed: isCollapsed,
        isMobileDrawer: isMobileDrawer,
      ),
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
      if (!_hasSpecificCreatorSubRole) ...[
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
      ] else if (!isCollapsed &&
          !_isGovernment &&
          !_hasSpecificCreatorSubRole) ...[
        const SizedBox(height: 18),
        _buildSidebarSectionHeader('LAINNYA', isDark),
      ],
      if (_isGovernment) ...[
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
          onTap: () {
            setState(() => _activeGovRoute = 'tender_kolaborasi');
            _pushGovScreen(TenderKolaborasiScreen(user: _currentUser));
          },
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
          onTap: () {
            setState(() => _activeGovRoute = 'mitra_komunitas');
            _pushGovScreen(MitraKomunitasScreen(user: _currentUser));
          },
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
          icon: Icons.work_outline,
          label: 'Proyek Aktif',
          onTap: () => _navigateToScreenIndex(2),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _currentIndex == 2 && _activeGovRoute == null,
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarLink(
          icon: Icons.summarize_outlined,
          label: 'Laporan Kegiatan',
          onTap: () {
            setState(() => _activeGovRoute = 'laporan');
            _pushGovScreen(LaporanScreen(user: _currentUser));
          },
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _activeGovRoute == 'laporan',
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarLink(
          icon: Icons.account_balance_outlined,
          label: 'Realisasi Anggaran',
          onTap: () {
            setState(() => _activeGovRoute = 'realisasi_anggaran');
            _pushGovScreen(RealisasiAnggaranScreen(user: _currentUser));
          },
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _activeGovRoute == 'realisasi_anggaran',
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarLink(
          icon: Icons.monitor_outlined,
          label: 'Monitoring & Evaluasi',
          onTap: () {
            setState(() => _activeGovRoute = 'monitoring_evaluasi');
            _pushGovScreen(MonitoringEvaluasiScreen(user: _currentUser));
          },
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
          icon: Icons.badge_outlined,
          label: 'Data Kreator',
          onTap: () => _navigateToScreenIndex(1),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _currentIndex == 1 && _activeGovRoute == null,
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarLink(
          icon: Icons.folder_outlined,
          label: 'Dokumen Instansi',
          onTap: () {
            setState(() => _activeGovRoute = 'dokumen_instansi');
            _pushGovScreen(DokumenInstansiScreen(user: _currentUser));
          },
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _activeGovRoute == 'dokumen_instansi',
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarLink(
          icon: Icons.campaign_outlined,
          label: 'Pengumuman Publik',
          onTap: () {
            setState(() => _activeGovRoute = 'pengumuman_publik');
            _pushGovScreen(PengumumanPublikScreen(user: _currentUser));
          },
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
          onTap: () {
            setState(() => _activeGovRoute = 'profil_instansi');
            _pushGovScreen(
              ProfileScreen(
                user: _currentUser,
                onUserUpdated: _onUserUpdated,
                onLogout: _onLogout,
              ),
            );
          },
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
          onTap: () {
            setState(() => _activeGovRoute = 'tim_hak_akses');
            _pushGovScreen(TimHakAksesScreen(user: _currentUser));
          },
          isDark: isDark,
          isCollapsed: isCollapsed,
          isSelected: _activeGovRoute == 'tim_hak_akses',
          isMobileDrawer: isMobileDrawer,
        ),
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
          color: isDark
              ? const Color(0xFF1E1C2B)
              : const Color(0xFFF8FAFC),
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
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Masuk atau daftar baru',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
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
                              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login_rounded, size: 14, color: Colors.white),
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
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Daftar',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF334155),
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

  Widget _buildMobileDrawer(
    BuildContext context,
    bool isDark,
    ThemeData theme,
  ) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF141221) : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              height: 65,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: Row(
                children: [
                  Image.asset(
                    'assets/brandlogo.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.auto_awesome,
                      color: AppTheme.primaryPurple,
                      size: 24,
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
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? const Color(0xFF2D2A3E) : Colors.grey.shade200,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8),
                children: _buildSidebarItemsList(
                  theme: theme,
                  isDark: isDark,
                  isCollapsed: false,
                  isMobileDrawer: true,
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? const Color(0xFF2D2A3E) : Colors.grey.shade200,
            ),
            _buildUserBottomCard(isDark: isDark, isCollapsed: false),
          ],
        ),
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

    final subRole = (_currentUser.subRole ?? '').toLowerCase().trim();
    switch (subRole) {
      case 'umkm':
        return UmkmDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'brand_agency':
      case 'agency':
        return AgencyDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'government':
      case 'institution':
      case 'pemerintah':
      case 'instansi':
        return GovtDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'company':
      case 'business':
      case 'corporate':
      case 'perusahaan':
      case 'bisnis':
        return CompanyDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'event_organizer':
      case 'eo':
        return EoDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'wedding_organizer':
      case 'wo':
        return WoDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'school':
      case 'education':
      case 'campus':
      case 'sekolah':
      case 'kampus':
        return SchoolDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'tourism':
      case 'desa_wisata':
      case 'pariwisata':
        return TourismDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'individual':
      case 'personal':
      case 'family':
      case 'pribadi':
      case 'individu':
      case 'keluarga':
        return IndividualDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'community':
      case 'komunitas':
        return CommunityDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'animator':
      case '3d_animator':
      case 'motion_designer':
        return CreatorAnimatorDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      default:
        // Tampilan Klien Umum (Default untuk akun baru atau sub_role kosong / umum / null)
        return DashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );
    }
  }

  Widget _buildCreatorDashboardScreen() {
    final subRole = (_currentUser.subRole ?? '').toLowerCase().trim();
    switch (subRole) {
      case 'government':
      case 'institution':
      case 'pemerintah':
      case 'instansi':
        return GovtDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'fotografer':
      case 'photographer':
      case 'foto':
        return CreatorFotograferDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'videografer':
      case 'videographer':
      case 'video':
        return CreatorVideograferDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'editor':
      case 'photo_editor':
      case 'video_editor':
        return CreatorEditorDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'desainer':
      case 'designer':
      case 'graphic_designer':
      case 'desain':
        return CreatorDesainerDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'mua':
      case 'makeup_artist':
      case 'makeup':
        return CreatorMuaDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'talent':
      case 'model':
      case 'talent_model':
      case 'mc':
      case 'singer':
      case 'penyanyi':
        return CreatorTalentDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'wedding_organizer':
      case 'wo':
        return WoDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'event_organizer':
      case 'eo':
        return EoDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'community':
      case 'komunitas':
        return CommunityDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'drone':
      case 'drone_pilot':
      case 'pilot_drone':
        return CreatorDroneDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'content_creator':
      case 'influencer':
      case 'ugc':
        return CreatorContentDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      case 'animator':
      case '3d_animator':
      case 'motion_designer':
        return CreatorAnimatorDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );

      default:
        // Kreator Umum (Default untuk kreator baru yang belum memilih kategori)
        return CreatorGeneralDashboardScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        );
    }
  }

  bool get _isGovernment {
    final sub = CreatorSidebarMenus.normalizeSubRole(_currentUser.subRole);
    return (_currentUser.role == 'user' || _currentUser.role == 'creator') &&
        (sub == 'government' ||
            sub == 'institution' ||
            sub == 'pemerintah' ||
            sub == 'instansi');
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
        4 => NotificationsScreen(userId: _currentUser.id ?? ''),
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
      1 => ExploreScreen(user: _currentUser),
      2 => ProyekSayaScreen(user: _currentUser),
      3 => MarketplaceKaryaScreen(user: _currentUser),
      4 => const AgendaScreen(),
      5 => KolaborasiScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        ),
      6 => UlasanReputasiScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        ),
      7 => WalletScreen(
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
      10 => NotificationsScreen(userId: _currentUser.id ?? ''),
      11 => const DirectMessageScreen(),
      12 => PeluangProyekScreen(user: _currentUser),
      13 => CreatorCalendarScreen(
          user: _currentUser,
          onUserUpdated: _onUserUpdated,
        ),
      14 => KreavanaAiScreen(user: _currentUser),
      _ => const SizedBox.shrink(),
    };
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
      (index) => _buildScreenAt(index),
    );
    final sidebarWidth = _isSidebarCollapsed ? 78.0 : 260.0;
    final bool hasPageFab =
        !_currentUser.isAdmin &&
        switch (activeIndex) {
          2 => true, // ProyekSayaScreen ('Buat Proyek Baru')
          3 => _currentUser.isCreator, // MarketplaceKaryaScreen ('Jual Karya')
          4 => true, // AgendaScreen ('Tambah Agenda')
          5 => true, // KolaborasiScreen ('Ajukan Kolaborasi')
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
      final mobileBottomNavIndex = switch (activeIndex) {
        0 => 0,
        1 => 1,
        2 => 2,
        11 => 3,
        9 => 4,
        _ => -1,
      };

      scaffoldWidget = Scaffold(
        drawer: _buildMobileDrawer(context, isDark, theme),
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
            final targetIndex = switch (navIndex) {
              0 => 0,
              1 => 1,
              2 => 2,
              3 => 11,
              4 => 9,
              _ => 0,
            };
            _navigateToScreenIndex(targetIndex);
          },
          items: _currentUser.isAdmin
              ? [
                  const BottomNavItem(
                    icon: Icons.admin_panel_settings_outlined,
                    activeIcon: Icons.admin_panel_settings,
                    label: 'Admin',
                  ),
                  const BottomNavItem(
                    icon: Icons.verified_user_outlined,
                    activeIcon: Icons.verified_user,
                    label: 'Verifikasi',
                  ),
                  const BottomNavItem(
                    icon: Icons.notifications_none_outlined,
                    activeIcon: Icons.notifications,
                    label: 'Notifikasi',
                  ),
                  const BottomNavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'Profil',
                  ),
                ]
              : [
                  const BottomNavItem(
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard,
                    label: 'Dashboard',
                  ),
                  const BottomNavItem(
                    icon: Icons.explore_outlined,
                    activeIcon: Icons.explore,
                    label: 'Jelajahi',
                  ),
                  const BottomNavItem(
                    icon: Icons.work_outline,
                    activeIcon: Icons.work,
                    label: 'Proyek',
                  ),
                  const BottomNavItem(
                    icon: Icons.chat_bubble_outline,
                    activeIcon: Icons.chat_bubble,
                    label: 'Pesan',
                  ),
                  const BottomNavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'Profil',
                  ),
                ],
        ),
      );
    }

    return Stack(
      children: [
        scaffoldWidget,
        if (!_isMobileDrawerOpen && activeIndex != 14)
          KreavanaAiFloatingWidget(hasPageFab: hasPageFab),
      ],
    );
  }
}
