import 'package:flutter/material.dart';
import 'upgrade_plan_modal.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/services/auth_service.dart';
import '../services/api_service.dart';
import '../screens/main_navigation.dart';
import '../screens/creator_service_screen.dart';
import '../screens/tender_kolaborasi_screen.dart';
import '../screens/mitra_komunitas_screen.dart';
import '../screens/laporan_screen.dart';
import '../screens/realisasi_anggaran_screen.dart';
import '../screens/monitoring_evaluasi_screen.dart';
import '../screens/dokumen_instansi_screen.dart';
import '../screens/pengumuman_publik_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/tim_hak_akses_screen.dart';
import 'creator_sidebar_menus.dart';

class DesktopSidebarLayout extends StatefulWidget {
  final Widget child;
  final UserModel user;
  final String activeRoute;
  final ValueChanged<UserModel>? onUserUpdated;
  final VoidCallback? onLogout;

  const DesktopSidebarLayout({
    super.key,
    required this.child,
    required this.user,
    required this.activeRoute,
    this.onUserUpdated,
    this.onLogout,
  });

  @override
  State<DesktopSidebarLayout> createState() => _DesktopSidebarLayoutState();
}

class _DesktopSidebarLayoutState extends State<DesktopSidebarLayout> {
  bool _isSidebarCollapsed = false;
  final ScrollController _sidebarScrollController = ScrollController();
  static double _savedSidebarScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _sidebarScrollController.hasClients) {
        _sidebarScrollController.jumpTo(_savedSidebarScrollOffset);
      }
    });
  }

  @override
  void dispose() {
    _sidebarScrollController.dispose();
    super.dispose();
  }

  bool get _hasSpecificCreatorSubRole =>
      CreatorSidebarMenus.hasSpecificSubRole(widget.user.subRole);

  bool get _isCreatorUser => CreatorSidebarMenus.isCreatorUser(widget.user);

  bool get _isGovernment {
    final sub = CreatorSidebarMenus.normalizeSubRole(widget.user.subRole);
    return (widget.user.role == 'user' || widget.user.role == 'creator') &&
        (sub == 'government' ||
            sub == 'institution' ||
            sub == 'pemerintah' ||
            sub == 'instansi');
  }

  void _pushNoAnimation(Widget destination) {
    if (_sidebarScrollController.hasClients) {
      _savedSidebarScrollOffset = _sidebarScrollController.offset;
    }
    Navigator.pushReplacement(
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

  static bool isServiceKey(String route) {
    return route.startsWith('foto_') ||
        route.startsWith('video_') ||
        route.startsWith('edit_') ||
        route.startsWith('desain_') ||
        route.startsWith('mc_') ||
        route.startsWith('singer_') ||
        route.startsWith('talent_') ||
        route.startsWith('mua_') ||
        route.startsWith('wo_') ||
        route.startsWith('eo_') ||
        route.startsWith('drone_') ||
        route.startsWith('konten_') ||
        route.startsWith('komunitas_');
  }

  void _goToMain(int index) {
    if (_sidebarScrollController.hasClients) {
      _savedSidebarScrollOffset = _sidebarScrollController.offset;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MainNavigation(initialUser: widget.user, initialIndex: index),
      ),
      (route) => false,
    );
  }

  void _pushService(String serviceKey) {
    _pushNoAnimation(
      CreatorServiceScreen(
        user: widget.user,
        serviceKey: serviceKey,
        onUserUpdated: widget.onUserUpdated,
      ),
    );
  }

  void _pushLink(String route) {
    if (route == widget.activeRoute) return;
    // Routes that are in MainNavigation's IndexedStack — go to index instead
    switch (route) {
      case 'kolaborasi':
        _goToMain(5);
        return;
      case 'marketplace':
        _goToMain(3);
        return;
      case 'reputasi':
        _goToMain(6);
        return;
      case 'pembayaran':
        _goToMain(7);
        return;
      case 'pengaturan':
        _goToMain(8);
        return;
      case 'proyek_saya':
        _goToMain(2);
        return;
      case 'agenda':
        _goToMain(4);
        return;
      case 'explore':
        _goToMain(1);
        return;
      case 'pengaturan_akun':
        _goToMain(8);
        return;
    }
    // Routes that push new screens (not in IndexedStack)
    Widget? destination;
    switch (route) {
      case 'tender_kolaborasi':
        destination = TenderKolaborasiScreen(user: widget.user);
        break;
      case 'mitra_komunitas':
        destination = MitraKomunitasScreen(user: widget.user);
        break;
      case 'laporan':
        destination = LaporanScreen(user: widget.user);
        break;
      case 'realisasi_anggaran':
        destination = RealisasiAnggaranScreen(user: widget.user);
        break;
      case 'monitoring_evaluasi':
        destination = MonitoringEvaluasiScreen(user: widget.user);
        break;
      case 'dokumen_instansi':
        destination = DokumenInstansiScreen(user: widget.user);
        break;
      case 'pengumuman_publik':
        destination = PengumumanPublikScreen(user: widget.user);
        break;
      case 'profil_instansi':
        destination = ProfileScreen(
          user: widget.user,
          onUserUpdated: widget.onUserUpdated ?? (_) {},
          onLogout: _onLogout,
        );
        break;
      case 'tim_hak_akses':
        destination = TimHakAksesScreen(user: widget.user);
        break;
    }
    if (destination != null) {
      _pushNoAnimation(destination);
    }
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

  Widget _buildNavRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isSelected,
    required bool isDark,
    bool isCollapsed = false,
  }) {
    final activeColor = AppTheme.primaryPurple;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 8 : 16,
        vertical: 4,
      ),
      child: Tooltip(
        message: isCollapsed ? label : '',
        child: InkWell(
          onTap: onTap,
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

  Widget _buildSectionHeader(String title, bool isDark) {
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

  Widget _buildUpgradePromoCard(bool isDark) {
    final isCreator = widget.user.role == 'creator';
    return Column(
      children: [
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryPurple, AppTheme.deepPurple],
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
                      foregroundColor: AppTheme.primaryPurple,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    if (!isDesktop) {
      return widget.child;
    }

    final sidebarWidth = _isSidebarCollapsed ? 78.0 : 260.0;
    final collapsed = _isSidebarCollapsed;

    final showTopPortofolioAgenda =
        !_isCreatorUser || !_hasSpecificCreatorSubRole;
    final layananTitle = CreatorSidebarMenus.layananSectionTitle(
      widget.user.subRole,
    );
    final layananItems = CreatorSidebarMenus.layananItems(widget.user.subRole);
    final hasLayanan = layananTitle != null && layananItems.isNotEmpty;
    final showKolaborasi = CreatorSidebarMenus.showKolaborasiInLainnya(
      widget.user.subRole,
    );

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
                    child: collapsed
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/brandlogo.png',
                                width: 30,
                                height: 30,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.auto_awesome,
                                  color: AppTheme.primaryPurple,
                                  size: 20,
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
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Image.asset(
                                  'assets/brandlogo.png',
                                  width: 36,
                                  height: 36,
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
                      children: [
                        _buildNavRow(
                          icon: Icons.home_outlined,
                          label: 'Beranda',
                          onTap: () => _goToMain(0),
                          isSelected: false,
                          isDark: isDark,
                          isCollapsed: collapsed,
                        ),
                        _buildNavRow(
                          icon: Icons.explore_outlined,
                          label: 'Rekomendasi Peluang',
                          onTap: () => _goToMain(1),
                          isSelected: false,
                          isDark: isDark,
                          isCollapsed: collapsed,
                        ),
                        _buildNavRow(
                          icon: Icons.folder_outlined,
                          label: 'Proyek Saya',
                          onTap: () => _goToMain(2),
                          isSelected: false,
                          isDark: isDark,
                          isCollapsed: collapsed,
                        ),
                        if (showTopPortofolioAgenda) ...[
                          _buildNavRow(
                            icon: Icons.photo_library_outlined,
                            label: 'Portofolio',
                            onTap: () => _goToMain(3),
                            isSelected: false,
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Agenda',
                            onTap: () => _goToMain(4),
                            isSelected: false,
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                        ],
                        if (_isGovernment) ...[
                          if (!collapsed) ...[
                            const SizedBox(height: 18),
                            _buildSectionHeader('PENGELOLAAN', isDark),
                          ] else ...[
                            const SizedBox(height: 8),
                          ],
                          _buildNavRow(
                            icon: Icons.campaign_outlined,
                            label: 'Peluang & Program',
                            onTap: () => _pushLink('proyek_saya'),
                            isSelected: widget.activeRoute == 'proyek_saya',
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.event_outlined,
                            label: 'Kegiatan & Event',
                            onTap: () => _pushLink('agenda'),
                            isSelected: widget.activeRoute == 'agenda',
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.handshake_outlined,
                            label: 'Tender & Kolaborasi',
                            onTap: () => _pushLink('tender_kolaborasi'),
                            isSelected:
                                widget.activeRoute == 'tender_kolaborasi',
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.people_outlined,
                            label: 'Daftar Kreator & Vendor',
                            onTap: () => _pushLink('explore'),
                            isSelected: widget.activeRoute == 'explore',
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.diversity_3_outlined,
                            label: 'Mitra & Komunitas',
                            onTap: () => _pushLink('mitra_komunitas'),
                            isSelected: widget.activeRoute == 'mitra_komunitas',
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          if (!collapsed) ...[
                            const SizedBox(height: 18),
                            _buildSectionHeader('PEMANTAUAN', isDark),
                          ] else ...[
                            const SizedBox(height: 8),
                          ],
                          _buildNavRow(
                            icon: Icons.work_outline,
                            label: 'Proyek Aktif',
                            onTap: () => _pushLink('proyek_saya'),
                            isSelected: widget.activeRoute == 'proyek_saya',
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.summarize_outlined,
                            label: 'Laporan Kegiatan',
                            onTap: () => _pushLink('laporan'),
                            isSelected: widget.activeRoute == 'laporan',
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.account_balance_outlined,
                            label: 'Realisasi Anggaran',
                            onTap: () => _pushLink('realisasi_anggaran'),
                            isSelected:
                                widget.activeRoute == 'realisasi_anggaran',
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.monitor_outlined,
                            label: 'Monitoring & Evaluasi',
                            onTap: () => _pushLink('monitoring_evaluasi'),
                            isSelected:
                                widget.activeRoute == 'monitoring_evaluasi',
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          if (!collapsed) ...[
                            const SizedBox(height: 18),
                            _buildSectionHeader('DATA & DOKUMEN', isDark),
                          ] else ...[
                            const SizedBox(height: 8),
                          ],
                          _buildNavRow(
                            icon: Icons.badge_outlined,
                            label: 'Data Kreator',
                            onTap: () => _pushLink('explore'),
                            isSelected: widget.activeRoute == 'explore',
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.folder_outlined,
                            label: 'Dokumen Instansi',
                            onTap: () => _pushLink('dokumen_instansi'),
                            isSelected:
                                widget.activeRoute == 'dokumen_instansi',
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.campaign_outlined,
                            label: 'Pengumuman Publik',
                            onTap: () => _pushLink('pengumuman_publik'),
                            isSelected:
                                widget.activeRoute == 'pengumuman_publik',
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          if (!collapsed) ...[
                            const SizedBox(height: 18),
                            _buildSectionHeader('PENGATURAN', isDark),
                          ] else ...[
                            const SizedBox(height: 8),
                          ],
                          _buildNavRow(
                            icon: Icons.account_balance_outlined,
                            label: 'Profil Instansi',
                            onTap: () => _pushLink('profil_instansi'),
                            isSelected: widget.activeRoute == 'profil_instansi',
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.settings_outlined,
                            label: 'Pengaturan Akun',
                            onTap: () => _pushLink('pengaturan_akun'),
                            isSelected: widget.activeRoute == 'pengaturan_akun',
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.admin_panel_settings_outlined,
                            label: 'Tim & Hak Akses',
                            onTap: () => _pushLink('tim_hak_akses'),
                            isSelected: widget.activeRoute == 'tim_hak_akses',
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                        ] else ...[
                          if (hasLayanan) ...[
                            if (!collapsed) ...[
                              const SizedBox(height: 18),
                              _buildSectionHeader(layananTitle, isDark),
                            ],
                            ...layananItems.map(
                              (entry) => _buildNavRow(
                                icon: entry.icon,
                                label: entry.label,
                                onTap: () {
                                  final key = entry.serviceKey;
                                  if (key != null && isServiceKey(key)) {
                                    _pushService(key);
                                  }
                                },
                                isSelected:
                                    widget.activeRoute == entry.serviceKey,
                                isDark: isDark,
                                isCollapsed: collapsed,
                              ),
                            ),
                          ],
                          if (!collapsed) ...[
                            const SizedBox(height: 18),
                            _buildSectionHeader('LAINNYA', isDark),
                          ] else ...[
                            const SizedBox(height: 8),
                          ],
                          if (showKolaborasi) ...[
                            _buildNavRow(
                              icon: Icons.handshake_outlined,
                              label: 'Kolaborasi',
                              onTap: () => _pushLink('kolaborasi'),
                              isSelected: widget.activeRoute == 'kolaborasi',
                              isDark: isDark,
                              isCollapsed: collapsed,
                            ),
                          ],
                          _buildNavRow(
                            icon: Icons.star_border,
                            label: 'Reputasi',
                            onTap: () => _pushLink('reputasi'),
                            isSelected: widget.activeRoute == 'reputasi',
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.payment_outlined,
                            label: 'Pembayaran',
                            onTap: () => _pushLink('pembayaran'),
                            isSelected: widget.activeRoute == 'pembayaran',
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.workspace_premium_outlined,
                            label: 'Upgrade Plan / Paket',
                            onTap: () => UpgradePlanModal.show(context),
                            isSelected: false,
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.settings_outlined,
                            label: 'Pengaturan',
                            onTap: () => _pushLink('pengaturan'),
                            isSelected: widget.activeRoute == 'pengaturan',
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          if (!collapsed) _buildUpgradePromoCard(isDark),
                        ],
                      ],
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
                  Container(
                    padding: EdgeInsets.all(collapsed ? 10 : 16),
                    child: collapsed
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message:
                                    '${widget.user.name} (@${widget.user.username})',
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isDark
                                      ? const Color(0xFF2D2A3E)
                                      : Colors.grey.shade200,
                                  backgroundImage:
                                      widget.user.avatarUrl != null &&
                                          widget.user.avatarUrl!.isNotEmpty
                                      ? NetworkImage(
                                          ApiService.resolveAssetUrl(
                                            widget.user.avatarUrl!,
                                          ),
                                        )
                                      : const AssetImage('assets/brandlogo.png')
                                            as ImageProvider,
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
                                    widget.user.avatarUrl != null &&
                                        widget.user.avatarUrl!.isNotEmpty
                                    ? NetworkImage(
                                        ApiService.resolveAssetUrl(
                                          widget.user.avatarUrl!,
                                        ),
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
                                      widget.user.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '@${widget.user.username}',
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
                  ),
                ],
              ),
            ),
          ),

          // ─── Konten utama ─────────────────────────────────────────
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}
