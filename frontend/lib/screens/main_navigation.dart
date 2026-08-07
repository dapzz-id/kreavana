import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'govt_dashboard_screen.dart';
import 'tender_kolaborasi_screen.dart';
import 'mitra_komunitas_screen.dart';
import 'realisasi_anggaran_screen.dart';
import 'monitoring_evaluasi_screen.dart';
import 'dokumen_instansi_screen.dart';
import 'pengumuman_publik_screen.dart';
import 'tim_hak_akses_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'explore_screen.dart';
import 'login_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_verification_screen.dart';
import 'proyek_saya_screen.dart';
import 'agenda_screen.dart';
import 'kolaborasi_screen.dart';
import 'marketplace_karya_screen.dart';
import 'ulasan_reputasi_screen.dart';
import 'laporan_screen.dart';
import 'pengaturan_screen.dart';
import 'wallet_screen.dart';
import 'company_dashboard_screen.dart';
import 'eo_dashboard_screen.dart';
import 'wo_dashboard_screen.dart';
import 'school_dashboard_screen.dart';
import 'tourism_dashboard_screen.dart';
import 'individual_dashboard_screen.dart';
import 'community_dashboard_screen.dart';
import 'creator_general_dashboard_screen.dart';
import 'creator_fotografer_dashboard_screen.dart';
import 'creator_videografer_dashboard_screen.dart';
import 'creator_editor_dashboard_screen.dart';
import 'creator_desainer_dashboard_screen.dart';
import 'creator_mua_dashboard_screen.dart';
import 'creator_talent_dashboard_screen.dart';
import 'creator_drone_dashboard_screen.dart';
import 'creator_content_dashboard_screen.dart';
import 'creator_animator_dashboard_screen.dart';
import 'umkm_dashboard_screen.dart';
import 'agency_dashboard_screen.dart';
import 'creator_service_screen.dart';
import 'direct_message_screen.dart';
import '../app/subrole_theme_engine.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/creator_sidebar_menus.dart';
import '../utils/app_errors.dart';

class MainNavigation extends StatefulWidget {
  final UserModel initialUser;
  final int initialIndex;

  const MainNavigation({super.key, required this.initialUser, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late UserModel _currentUser;
  int _currentIndex = 0;
  bool _isSidebarCollapsed = false;
  String? _activeGovRoute;
  final ScrollController _sidebarScrollController = ScrollController();
  static double _savedSidebarScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.initialUser;
    _currentIndex = widget.initialIndex;
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
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
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
  }) {
    final screensCount = _currentUser.isAdmin ? 4 : 12;
    final activeIndex = _currentIndex >= screensCount ? 0 : _currentIndex;
    final isSelected = activeIndex == index;
    final activeColor = SubRoleThemeEngine.getAccentColorForUser(_currentUser);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 8 : 16,
        vertical: 4,
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
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 0 : 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected
                      ? activeColor
                      : (isDark ? Colors.white70 : Colors.grey.shade700),
                  size: 22,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 14,
                        color: isSelected
                            ? activeColor
                            : (isDark ? Colors.white70 : Colors.grey.shade800),
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
        horizontal: isCollapsed ? 8 : 16,
        vertical: 4,
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
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 0 : 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? activeColor
                      : (isDark ? Colors.white70 : Colors.grey.shade700),
                  size: 22,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 14,
                        color: isSelected
                            ? activeColor
                            : (isDark ? Colors.white70 : Colors.grey.shade800),
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

  void _showDummyActionMessage(String title) {
    AppSnackbar.info(context, '$title belum tersedia.');
  }

  bool get _isCreatorUser => CreatorSidebarMenus.isCreatorUser(_currentUser);

  bool get _hasSpecificCreatorSubRole =>
      CreatorSidebarMenus.hasSpecificSubRole(_currentUser.subRole);

  void _navigateToScreenIndex(int index) {
    if (_sidebarScrollController.hasClients) {
      _savedSidebarScrollOffset = _sidebarScrollController.offset;
    }
    setState(() {
      _currentIndex = index;
      _activeGovRoute = null;
    });
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
    final accentColor = SubRoleThemeEngine.getAccentColorForUser(_currentUser);
    return Column(
      children: [
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: SubRoleThemeEngine.getGradient(_currentUser.role, _currentUser.subRole),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Icon(Icons.workspace_premium_outlined, color: Colors.white, size: 28),
                const SizedBox(height: 8),
                const Text(
                  'Upgrade Akun',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tingkatkan peluang & fitur premium untuk kreator.',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showDummyActionMessage('Upgrade Sekarang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Upgrade Sekarang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
    bool includeMarketplace = true,
    bool isMobileDrawer = false,
  }) {
    return [
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
      if (includeMarketplace)
        _buildSidebarItem(
          icon: Icons.storefront_outlined,
          activeIcon: Icons.storefront,
          label: 'Marketplace Karya',
          index: 3,
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
        transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
      ),
    );
  }

  List<Widget> _buildCreatorSidebarItems({
    required ThemeData theme,
    required bool isDark,
    required bool isCollapsed,
    bool isMobileDrawer = false,
  }) {
    final layananTitle =
        CreatorSidebarMenus.layananSectionTitle(_currentUser.subRole);
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
      _buildSidebarSectionHeader(layananTitle, isDark, isCollapsed: isCollapsed),
      ...layananItems.map(
        (entry) => _buildSidebarLink(
          icon: entry.icon,
          label: entry.label,
          onTap: () => _handleCreatorMenuEntry(entry),
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
      ),
      const SizedBox(height: 18),
      _buildSidebarSectionHeader('LAINNYA', isDark, isCollapsed: isCollapsed),
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
          icon: Icons.notifications_none_outlined,
          activeIcon: Icons.notifications,
          label: 'Notifikasi',
          index: 2,
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
        _buildSidebarItem(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'Profil Saya',
          index: 3,
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
      if (!_isCreatorUser || !_hasSpecificCreatorSubRole) ...[
        _buildSidebarItem(
          icon: Icons.photo_library_outlined,
          activeIcon: Icons.photo_library,
          label: 'Portofolio',
          index: 3,
          theme: theme,
          isDark: isDark,
          isCollapsed: isCollapsed,
          isMobileDrawer: isMobileDrawer,
        ),
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
            _pushGovScreen(ProfileScreen(user: _currentUser, onUserUpdated: _onUserUpdated, onLogout: _onLogout));
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

  Widget _buildUserBottomCard({required bool isDark, required bool isCollapsed}) {
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
                    backgroundColor: isDark ? const Color(0xFF2D2A3E) : Colors.grey.shade200,
                    backgroundImage: _currentUser.avatarUrl != null && _currentUser.avatarUrl!.isNotEmpty
                        ? NetworkImage(ApiService.resolveAssetUrl(_currentUser.avatarUrl!))
                        : null,
                    child: _currentUser.avatarUrl == null || _currentUser.avatarUrl!.isEmpty
                        ? const Icon(Icons.person, color: AppTheme.primaryPurple)
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
                      child: Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isDark ? const Color(0xFF2D2A3E) : Colors.grey.shade200,
                  backgroundImage: _currentUser.avatarUrl != null && _currentUser.avatarUrl!.isNotEmpty
                      ? NetworkImage(ApiService.resolveAssetUrl(_currentUser.avatarUrl!))
                      : const AssetImage('assets/brandlogo.png') as ImageProvider,
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '@${_currentUser.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _showLogoutDialog,
                ),
              ],
            ),
    );
  }

  Widget _buildMobileDrawer(BuildContext context, bool isDark, ThemeData theme) {
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
    if (_currentUser.role == 'creator' || _currentUser.isCreator) {
      return _buildCreatorDashboardScreen();
    }

    final subRole = (_currentUser.subRole ?? '').toLowerCase().trim();
    switch (subRole) {
      case 'umkm':
        return UmkmDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'brand_agency':
      case 'agency':
        return AgencyDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'government':
      case 'institution':
      case 'pemerintah':
      case 'instansi':
        return GovtDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'company':
      case 'business':
      case 'corporate':
      case 'perusahaan':
      case 'bisnis':
        return CompanyDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'event_organizer':
      case 'eo':
        return EoDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'wedding_organizer':
      case 'wo':
        return WoDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'school':
      case 'education':
      case 'campus':
      case 'sekolah':
      case 'kampus':
        return SchoolDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'tourism':
      case 'desa_wisata':
      case 'pariwisata':
        return TourismDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'individual':
      case 'personal':
      case 'family':
      case 'pribadi':
      case 'individu':
      case 'keluarga':
        return IndividualDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'community':
      case 'komunitas':
        return CommunityDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'animator':
      case '3d_animator':
      case 'motion_designer':
        return CreatorAnimatorDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      default:
        // Tampilan Klien Umum (Default untuk akun baru atau sub_role kosong / umum / null)
        return DashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);
    }
  }

  Widget _buildCreatorDashboardScreen() {
    final subRole = (_currentUser.subRole ?? '').toLowerCase().trim();
    switch (subRole) {
      case 'government':
      case 'institution':
      case 'pemerintah':
      case 'instansi':
        return GovtDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'fotografer':
      case 'photographer':
      case 'foto':
        return CreatorFotograferDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'videografer':
      case 'videographer':
      case 'video':
        return CreatorVideograferDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'editor':
      case 'photo_editor':
      case 'video_editor':
        return CreatorEditorDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'desainer':
      case 'designer':
      case 'graphic_designer':
      case 'desain':
        return CreatorDesainerDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'mua':
      case 'makeup_artist':
      case 'makeup':
        return CreatorMuaDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'talent':
      case 'model':
      case 'talent_model':
      case 'mc':
      case 'singer':
      case 'penyanyi':
        return CreatorTalentDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'wedding_organizer':
      case 'wo':
        return WoDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'event_organizer':
      case 'eo':
        return EoDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'community':
      case 'komunitas':
        return CommunityDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'drone':
      case 'drone_pilot':
      case 'pilot_drone':
        return CreatorDroneDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'content_creator':
      case 'influencer':
      case 'ugc':
        return CreatorContentDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'animator':
      case '3d_animator':
      case 'motion_designer':
        return CreatorAnimatorDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      default:
        // Kreator Umum (Default untuk kreator baru yang belum memilih kategori)
        return CreatorGeneralDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    final List<Widget> screens = _currentUser.isAdmin
        ? [
            AdminDashboardScreen(user: _currentUser),
            const AdminVerificationScreen(),
            NotificationsScreen(userId: _currentUser.id ?? ''),
            ProfileScreen(
              user: _currentUser,
              onUserUpdated: _onUserUpdated,
              onLogout: _onLogout,
            ),
          ]
        : [
            _buildClientDashboardScreen(), // 0
            ExploreScreen(user: _currentUser), // 1
            ProyekSayaScreen(user: _currentUser), // 2
            const MarketplaceKaryaScreen(), // 3
            const AgendaScreen(), // 4
            const KolaborasiScreen(), // 5
            const UlasanReputasiScreen(), // 6
            WalletScreen(user: _currentUser, onUserUpdated: _onUserUpdated), // 7
            const PengaturanScreen(), // 8
            ProfileScreen(
              user: _currentUser,
              onUserUpdated: _onUserUpdated,
              onLogout: _onLogout,
            ), // 9
            NotificationsScreen(userId: _currentUser.id ?? ''), // 10
            const DirectMessageScreen(), // 11
          ];

    final activeIndex = _currentIndex >= screens.length ? 0 : _currentIndex;

    if (isDesktop) {
      final sidebarWidth = _isSidebarCollapsed ? 78.0 : 260.0;

      return Scaffold(
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
                      child: ListView(
                        controller: _sidebarScrollController,
                        padding: const EdgeInsets.only(top: 12),
                        children: _buildSidebarItemsList(
                          theme: theme,
                          isDark: isDark,
                          isCollapsed: _isSidebarCollapsed,
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
                    _buildUserBottomCard(isDark: isDark, isCollapsed: _isSidebarCollapsed),
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
    }

    // ─── Mobile Layout ─────────────────────────────────────────────────
    final mobileBottomNavIndex = switch (activeIndex) {
      0 => 0,
      1 => 1,
      2 => 2,
      11 => 3,
      9 => 4,
      _ => -1,
    };

    return Scaffold(
      drawer: _buildMobileDrawer(context, isDark, theme),
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
}
