import 'dart:ui';
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
import 'kreavana_ai_floating_widget.dart';

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

  bool _isRouteActive(String target) {
    final current = widget.activeRoute.toLowerCase().trim();
    final t = target.toLowerCase().trim();
    if (current == t) return true;

    // Proyek / Kebutuhan (Add, Edit, View Detail, Manage Pelamar)
    if (t == 'proyek_saya' || t == 'proyek') {
      return current == 'proyek_saya' ||
          current == 'proyek' ||
          current == 'kebutuhan_proyek' ||
          current == 'buat_kebutuhan' ||
          current == 'detail_kebutuhan' ||
          current == 'edit_kebutuhan' ||
          current == 'kelola_pelamar' ||
          current.contains('kebutuhan') ||
          current.contains('proyek');
    }

    // Home / Beranda
    if (t == 'beranda' || t == 'home') {
      return current == 'beranda' || current == 'home' || current == 'dashboard';
    }

    // Kreavana AI
    if (t == 'kreavana_ai' || t == 'ai') {
      return current == 'kreavana_ai' || current == 'ai';
    }

    // Rekomendasi Peluang / Explore
    if (t == 'explore' || t == 'peluang' || t == 'rekomendasi_peluang') {
      return current == 'explore' ||
          current == 'peluang' ||
          current == 'rekomendasi_peluang' ||
          current == 'peluang_proyek' ||
          current == 'peluang_lokasi' ||
          current == 'detail_peluang';
    }

    // Portofolio / Marketplace (Add karya, edit karya, detail produk)
    if (t == 'portofolio' || t == 'portfolio' || t == 'marketplace') {
      return current == 'portofolio' ||
          current == 'portfolio' ||
          current == 'marketplace' ||
          current == 'jual_karya' ||
          current == 'tambah_karya' ||
          current == 'tambah_portofolio' ||
          current == 'edit_portofolio' ||
          current == 'detail_portofolio' ||
          current == 'marketplace_detail' ||
          current.contains('portofolio') ||
          current.contains('karya');
    }

    // Agenda / Kegiatan & Event / Jadwal
    if (t == 'agenda' || t == 'jadwal' || t == 'kegiatan_event') {
      return current == 'agenda' ||
          current == 'jadwal' ||
          current == 'kegiatan_event' ||
          current == 'tambah_agenda' ||
          current == 'edit_agenda' ||
          current == 'detail_agenda' ||
          current == 'creator_calendar';
    }

    // Tender & Kolaborasi
    if (t == 'tender_kolaborasi' || t == 'tender') {
      return current == 'tender_kolaborasi' ||
          current == 'tender' ||
          current == 'buat_tender' ||
          current == 'detail_tender' ||
          current == 'edit_tender';
    }

    // Kolaborasi
    if (t == 'kolaborasi') {
      return current == 'kolaborasi' ||
          current == 'buat_kolaborasi' ||
          current == 'detail_kolaborasi' ||
          current == 'edit_kolaborasi';
    }

    // Laporan
    if (t == 'laporan') {
      return current == 'laporan' ||
          current == 'buat_laporan' ||
          current == 'detail_laporan' ||
          current == 'edit_laporan';
    }

    // Realisasi Anggaran
    if (t == 'realisasi_anggaran') {
      return current == 'realisasi_anggaran' ||
          current == 'tambah_anggaran' ||
          current == 'detail_anggaran' ||
          current == 'edit_anggaran';
    }

    // Monitoring & Evaluasi
    if (t == 'monitoring_evaluasi') {
      return current == 'monitoring_evaluasi' ||
          current == 'monev' ||
          current == 'tambah_evaluasi' ||
          current == 'detail_evaluasi';
    }

    // Dokumen Instansi
    if (t == 'dokumen_instansi') {
      return current == 'dokumen_instansi' ||
          current == 'tambah_dokumen' ||
          current == 'detail_dokumen' ||
          current == 'edit_dokumen';
    }

    // Pengumuman Publik
    if (t == 'pengumuman_publik') {
      return current == 'pengumuman_publik' ||
          current == 'buat_pengumuman' ||
          current == 'detail_pengumuman' ||
          current == 'edit_pengumuman';
    }

    // Profil Instansi / Profil
    if (t == 'profil_instansi' || t == 'profil') {
      return current == 'profil_instansi' ||
          current == 'profil' ||
          current == 'edit_profil';
    }

    // Pengaturan
    if (t == 'pengaturan' || t == 'pengaturan_akun') {
      return current == 'pengaturan' ||
          current == 'pengaturan_akun' ||
          current == 'edit_pengaturan' ||
          current == 'verifikasi_identitas' ||
          current == 'pendaftaran_kreator' ||
          current == 'client_verification' ||
          current == 'creator_application';
    }

    // Tim & Hak Akses
    if (t == 'tim_hak_akses') {
      return current == 'tim_hak_akses' ||
          current == 'tambah_anggota' ||
          current == 'edit_akses';
    }

    // Mitra & Komunitas
    if (t == 'mitra_komunitas') {
      return current == 'mitra_komunitas' ||
          current == 'tambah_mitra' ||
          current == 'detail_mitra';
    }

    // Kapasitas & Jadwal
    if (t == 'kapasitas_jadwal') {
      return current == 'kapasitas_jadwal' ||
          current == 'edit_kapasitas' ||
          current == 'tambah_jadwal';
    }

    // Reputasi
    if (t == 'reputasi') {
      return current == 'reputasi' || current == 'ulasan_reputasi';
    }

    // Pembayaran
    if (t == 'pembayaran') {
      return current == 'pembayaran' ||
          current == 'wallet' ||
          current == 'topup' ||
          current == 'withdraw';
    }

    // Creator Services
    if (isServiceKey(t)) {
      return current == t || current.startsWith('${t}_');
    }

    return false;
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
      case 'kapasitas_jadwal':
        _goToMain(13);
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
    Color? activeColor,
  }) {
    final effectiveActiveColor = activeColor ?? AppTheme.primaryPurple;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 8 : 12,
        vertical: 2,
      ),
      child: Tooltip(
        message: isCollapsed ? label : '',
        child: InkWell(
          onTap: onTap,
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
                  ? effectiveActiveColor.withValues(alpha: isDark ? 0.16 : 0.09)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(
                      color: effectiveActiveColor.withValues(alpha: isDark ? 0.3 : 0.2),
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
                      ? effectiveActiveColor
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
                            ? (isDark ? Colors.white : effectiveActiveColor)
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

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
          letterSpacing: 0.9,
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
        _isCreatorUser && !_hasSpecificCreatorSubRole;
    final layananTitle = CreatorSidebarMenus.layananSectionTitle(
      widget.user.subRole,
    );
    final layananItems = CreatorSidebarMenus.layananItems(widget.user.subRole);
    final hasLayanan = layananTitle != null && layananItems.isNotEmpty;
    final showKolaborasi = CreatorSidebarMenus.showKolaborasiInLainnya(
      widget.user.subRole,
    );

    final layoutScaffold = Scaffold(
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
                      children: [
                        _buildNavRow(
                          icon: Icons.home_outlined,
                          label: 'Beranda',
                          onTap: () => _goToMain(0),
                          isSelected: _isRouteActive('beranda'),
                          isDark: isDark,
                          isCollapsed: collapsed,
                        ),
                        _buildNavRow(
                          icon: Icons.auto_awesome_outlined,
                          label: 'Kreavana AI',
                          onTap: () => _goToMain(14),
                          isSelected: _isRouteActive('kreavana_ai') || _isRouteActive('ai'),
                          isDark: isDark,
                          isCollapsed: collapsed,
                          activeColor: const Color(0xFF8B5CF6),
                        ),
                        if (_isCreatorUser) _buildNavRow(
                          icon: Icons.explore_outlined,
                          label: 'Rekomendasi Peluang',
                          onTap: () => _goToMain(1),
                          isSelected: _isRouteActive('explore'),
                          isDark: isDark,
                          isCollapsed: collapsed,
                        ),
                        _buildNavRow(
                          icon: Icons.folder_outlined,
                          label: 'Proyek Saya',
                          onTap: () => _goToMain(2),
                          isSelected: _isRouteActive('proyek_saya'),
                          isDark: isDark,
                          isCollapsed: collapsed,
                        ),
                        if (showTopPortofolioAgenda) ...[
                          _buildNavRow(
                            icon: Icons.photo_library_outlined,
                            label: 'Portofolio',
                            onTap: () => _goToMain(3),
                            isSelected: _isRouteActive('portofolio'),
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Agenda',
                            onTap: () => _goToMain(4),
                            isSelected: _isRouteActive('agenda'),
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
                            isSelected: _isRouteActive('proyek_saya'),
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.event_outlined,
                            label: 'Kegiatan & Event',
                            onTap: () => _pushLink('agenda'),
                            isSelected: _isRouteActive('agenda'),
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.handshake_outlined,
                            label: 'Tender & Kolaborasi',
                            onTap: () => _pushLink('tender_kolaborasi'),
                            isSelected: _isRouteActive('tender_kolaborasi'),
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.people_outlined,
                            label: 'Daftar Kreator & Vendor',
                            onTap: () => _pushLink('explore'),
                            isSelected: _isRouteActive('explore'),
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.diversity_3_outlined,
                            label: 'Mitra & Komunitas',
                            onTap: () => _pushLink('mitra_komunitas'),
                            isSelected: _isRouteActive('mitra_komunitas'),
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
                            isSelected: _isRouteActive('proyek_saya'),
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.summarize_outlined,
                            label: 'Laporan Kegiatan',
                            onTap: () => _pushLink('laporan'),
                            isSelected: _isRouteActive('laporan'),
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.account_balance_outlined,
                            label: 'Realisasi Anggaran',
                            onTap: () => _pushLink('realisasi_anggaran'),
                            isSelected: _isRouteActive('realisasi_anggaran'),
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.monitor_outlined,
                            label: 'Monitoring & Evaluasi',
                            onTap: () => _pushLink('monitoring_evaluasi'),
                            isSelected: _isRouteActive('monitoring_evaluasi'),
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
                            isSelected: _isRouteActive('explore'),
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.folder_outlined,
                            label: 'Dokumen Instansi',
                            onTap: () => _pushLink('dokumen_instansi'),
                            isSelected: _isRouteActive('dokumen_instansi'),
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.campaign_outlined,
                            label: 'Pengumuman Publik',
                            onTap: () => _pushLink('pengumuman_publik'),
                            isSelected: _isRouteActive('pengumuman_publik'),
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
                            isSelected: _isRouteActive('profil_instansi'),
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.settings_outlined,
                            label: 'Pengaturan Akun',
                            onTap: () => _pushLink('pengaturan_akun'),
                            isSelected: _isRouteActive('pengaturan_akun'),
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.admin_panel_settings_outlined,
                            label: 'Tim & Hak Akses',
                            onTap: () => _pushLink('tim_hak_akses'),
                            isSelected: _isRouteActive('tim_hak_akses'),
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
                                  } else if (entry.route != null) {
                                    _pushLink(entry.route!);
                                  }
                                },
                                isSelected: _isRouteActive(entry.serviceKey ?? entry.route ?? ''),
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
                              isSelected: _isRouteActive('kolaborasi'),
                              isDark: isDark,
                              isCollapsed: collapsed,
                            ),
                          ],
                          if (_isCreatorUser) ...[
                            _buildNavRow(
                              icon: Icons.calendar_month_outlined,
                              label: 'Kapasitas & Jadwal',
                              onTap: () => _pushLink('kapasitas_jadwal'),
                              isSelected: _isRouteActive('kapasitas_jadwal'),
                              isDark: isDark,
                              isCollapsed: collapsed,
                            ),
                          ],
                          _buildNavRow(
                            icon: Icons.star_border,
                            label: 'Reputasi',
                            onTap: () => _pushLink('reputasi'),
                            isSelected: _isRouteActive('reputasi'),
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          _buildNavRow(
                            icon: Icons.payment_outlined,
                            label: 'Pembayaran',
                            onTap: () => _pushLink('pembayaran'),
                            isSelected: _isRouteActive('pembayaran'),
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
                            isSelected: _isRouteActive('pengaturan'),
                            isDark: isDark,
                            isCollapsed: collapsed,
                          ),
                          if (!collapsed) _buildUpgradePromoCard(isDark),
                        ],
                      ],
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

    return Stack(
      children: [
        layoutScaffold,
        const KreavanaAiFloatingWidget(hasPageFab: false),
      ],
    );
  }
}
