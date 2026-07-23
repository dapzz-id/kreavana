import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'dashboard_screen.dart';
import 'govt_dashboard_screen.dart';
import 'tender_kolaborasi_screen.dart';
import 'mitra_komunitas_screen.dart';
import 'realisasi_anggaran_screen.dart';
import 'monitoring_evaluasi_screen.dart';
import 'dokumen_instansi_screen.dart';
import 'pengumuman_publik_screen.dart';
import 'tim_hak_akses_screen.dart';
import 'direct_message_screen.dart';
import 'explore_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_verification_screen.dart';
import 'buat_kebutuhan_screen.dart';
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
import '../widgets/custom_bottom_nav_bar.dart';

class MainNavigation extends StatefulWidget {
  final UserModel initialUser;

  const MainNavigation({super.key, required this.initialUser});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late UserModel _currentUser;
  int _currentIndex = 0;
  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.initialUser;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshProfile();
    });
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
  }) {
    final screensCount = _currentUser.isAdmin ? 4 : 5;
    final activeIndex = _currentIndex >= screensCount ? 0 : _currentIndex;
    final isSelected = activeIndex == index;
    final activeColor = theme.colorScheme.primary;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 8 : 16,
        vertical: 4,
      ),
      child: Tooltip(
        message: isCollapsed ? label : '',
        child: InkWell(
          onTap: () {
            setState(() => _currentIndex = index);
            if (_currentUser.isAdmin) {
              if (index == 2 || index == 3) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _refreshProfile();
                });
              }
            } else {
              if (index == 3 || index == 4) {
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
  }) {
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
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(icon, color: isDark ? Colors.white70 : Colors.grey.shade700, size: 22),
                if (!isCollapsed) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.grey.shade800,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title belum tersedia.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildClientDashboardScreen() {
    if (_currentUser.role == 'creator' || _currentUser.isCreator) {
      return _buildCreatorDashboardScreen();
    }

    final subRole = (_currentUser.subRole ?? '').toLowerCase().trim();
    switch (subRole) {
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
        return CreatorTalentDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'drone':
      case 'drone_pilot':
      case 'pilot_drone':
        return CreatorDroneDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      case 'content_creator':
      case 'influencer':
      case 'ugc':
        return CreatorContentDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);

      default:
        // Kreator Umum (Default untuk kreator baru yang belum memilih kategori)
        return CreatorGeneralDashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated);
    }
  }

  bool get _isGovernment =>
      (_currentUser.role == 'user' || _currentUser.role == 'creator') &&
      (_currentUser.subRole == 'government' || _currentUser.subRole == 'institution');

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
            _buildClientDashboardScreen(),
            ExploreScreen(user: _currentUser),
            const DirectMessageScreen(),
            NotificationsScreen(userId: _currentUser.id ?? ''),
            ProfileScreen(
              user: _currentUser,
              onUserUpdated: _onUserUpdated,
              onLogout: _onLogout,
            ),
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
                    // Tinggi: 20 (top) + 48 (content) + 20 (bottom) = 88px
                    // Nilai ini juga dipakai sebagai toolbarHeight AppBar
                    // di setiap screen agar header konten sejajar.
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
                        padding: const EdgeInsets.only(top: 12),
                        children: _currentUser.isAdmin
                            ? [
                                _buildSidebarItem(
                                  icon: Icons.admin_panel_settings_outlined,
                                  activeIcon: Icons.admin_panel_settings,
                                  label: 'Dasbor Admin',
                                  index: 0,
                                  theme: theme,
                                  isDark: isDark,
                                  isCollapsed: _isSidebarCollapsed,
                                ),
                                _buildSidebarItem(
                                  icon: Icons.verified_user_outlined,
                                  activeIcon: Icons.verified_user,
                                  label: 'Verifikasi Kreator',
                                  index: 1,
                                  theme: theme,
                                  isDark: isDark,
                                  isCollapsed: _isSidebarCollapsed,
                                ),
                                _buildSidebarItem(
                                  icon: Icons.notifications_none_outlined,
                                  activeIcon: Icons.notifications,
                                  label: 'Notifikasi',
                                  index: 2,
                                  theme: theme,
                                  isDark: isDark,
                                  isCollapsed: _isSidebarCollapsed,
                                ),
                                _buildSidebarItem(
                                  icon: Icons.person_outline,
                                  activeIcon: Icons.person,
                                  label: 'Profil Saya',
                                  index: 3,
                                  theme: theme,
                                  isDark: isDark,
                                  isCollapsed: _isSidebarCollapsed,
                                ),
                              ]
                            : [
                                _buildSidebarItem(
                                  icon: Icons.dashboard_outlined,
                                  activeIcon: Icons.dashboard,
                                  label: 'Dashboard',
                                  index: 0,
                                  theme: theme,
                                  isDark: isDark,
                                  isCollapsed: _isSidebarCollapsed,
                                ),
                                _buildSidebarItem(
                                  icon: Icons.explore_outlined,
                                  activeIcon: Icons.explore,
                                  label: 'Jelajahi',
                                  index: 1,
                                  theme: theme,
                                  isDark: isDark,
                                  isCollapsed: _isSidebarCollapsed,
                                ),
                                _buildSidebarItem(
                                  icon: Icons.chat_bubble_outline,
                                  activeIcon: Icons.chat_bubble,
                                  label: 'Pesan',
                                  index: 2,
                                  theme: theme,
                                  isDark: isDark,
                                  isCollapsed: _isSidebarCollapsed,
                                ),
                                _buildSidebarItem(
                                  icon: Icons.notifications_none_outlined,
                                  activeIcon: Icons.notifications,
                                  label: 'Notifikasi',
                                  index: 3,
                                  theme: theme,
                                  isDark: isDark,
                                  isCollapsed: _isSidebarCollapsed,
                                ),
                                _buildSidebarItem(
                                  icon: Icons.person_outline,
                                  activeIcon: Icons.person,
                                  label: 'Profil Saya',
                                  index: 4,
                                  theme: theme,
                                  isDark: isDark,
                                  isCollapsed: _isSidebarCollapsed,
                                ),
                                if (!_isSidebarCollapsed) ...[
                                  const SizedBox(height: 18),
                                  if (_isGovernment)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        'PENGELOLAAN',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white54 : Colors.grey.shade500,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    )
                                  else
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        'Lainnya',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white70 : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                ],
                                if (_isGovernment) ...[
                                  _buildSidebarLink(
                                    icon: Icons.campaign_outlined,
                                    label: 'Peluang & Program',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProyekSayaScreen())),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  _buildSidebarLink(
                                    icon: Icons.event_outlined,
                                    label: 'Kegiatan & Event',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgendaScreen())),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  _buildSidebarLink(
                                    icon: Icons.handshake_outlined,
                                    label: 'Tender & Kolaborasi',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TenderKolaborasiScreen())),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  _buildSidebarLink(
                                    icon: Icons.people_outlined,
                                    label: 'Daftar Kreator & Vendor',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExploreScreen(user: _currentUser))),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  _buildSidebarLink(
                                    icon: Icons.diversity_3_outlined,
                                    label: 'Mitra & Komunitas',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MitraKomunitasScreen())),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  if (!_isSidebarCollapsed) ...[
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
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProyekSayaScreen())),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  _buildSidebarLink(
                                    icon: Icons.summarize_outlined,
                                    label: 'Laporan Kegiatan',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LaporanScreen())),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  _buildSidebarLink(
                                    icon: Icons.account_balance_outlined,
                                    label: 'Realisasi Anggaran',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RealisasiAnggaranScreen())),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  _buildSidebarLink(
                                    icon: Icons.monitor_outlined,
                                    label: 'Monitoring & Evaluasi',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MonitoringEvaluasiScreen())),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  if (!_isSidebarCollapsed) ...[
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
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExploreScreen(user: _currentUser))),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  _buildSidebarLink(
                                    icon: Icons.folder_outlined,
                                    label: 'Dokumen Instansi',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DokumenInstansiScreen())),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  _buildSidebarLink(
                                    icon: Icons.campaign_outlined,
                                    label: 'Pengumuman Publik',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PengumumanPublikScreen())),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  if (!_isSidebarCollapsed) ...[
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
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(user: _currentUser, onUserUpdated: _onUserUpdated, onLogout: _onLogout))),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  _buildSidebarLink(
                                    icon: Icons.settings_outlined,
                                    label: 'Pengaturan Akun',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PengaturanScreen())),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  _buildSidebarLink(
                                    icon: Icons.admin_panel_settings_outlined,
                                    label: 'Tim & Hak Akses',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TimHakAksesScreen())),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                ] else ...[
                                  _buildSidebarLink(
                                    icon: Icons.add_box_outlined,
                                    label: 'Buat Kebutuhan',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BuatKebutuhanScreen())),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  _buildSidebarLink(
                                    icon: Icons.search_outlined,
                                    label: 'Cari Kreator',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExploreScreen(user: _currentUser))),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  _buildSidebarLink(
                                    icon: Icons.work_outline,
                                    label: 'Proyek Saya',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProyekSayaScreen())),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  _buildSidebarLink(
                                    icon: Icons.calendar_today_outlined,
                                    label: 'Agenda',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgendaScreen())),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  _buildSidebarLink(
                                    icon: Icons.handshake_outlined,
                                    label: 'Kolaborasi',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KolaborasiScreen())),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  _buildSidebarLink(
                                    icon: Icons.storefront_outlined,
                                    label: 'Marketplace Karya',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketplaceKaryaScreen())),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  _buildSidebarLink(
                                    icon: Icons.star_border,
                                    label: 'Ulasan & Reputasi',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UlasanReputasiScreen())),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  _buildSidebarLink(
                                    icon: Icons.payment_outlined,
                                    label: 'Pembayaran',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WalletScreen(user: _currentUser, onUserUpdated: _onUserUpdated))),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  _buildSidebarLink(
                                    icon: Icons.report_outlined,
                                    label: 'Laporan',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LaporanScreen())),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                  _buildSidebarLink(
                                    icon: Icons.settings_outlined,
                                    label: 'Pengaturan',
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PengaturanScreen())),
                                    isDark: isDark,
                                    isCollapsed: _isSidebarCollapsed,
                                  ),
                                ],
                                if (!_isSidebarCollapsed) ...[
                                  const SizedBox(height: 18),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1A1830) : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF2D2A3E) : Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.headset_mic_outlined,
                                              color: theme.colorScheme.primary,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          const Text(
                                            'Butuh Bantuan?',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tim support siap membantu kapan saja.',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton(
                                              onPressed: () => _showDummyActionMessage('Hubungi Support'),
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                side: BorderSide(
                                                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Text(
                                                'Hubungi Support',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: theme.colorScheme.primary,
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
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1A1830) : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF2D2A3E) : Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withValues(alpha: 0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.workspace_premium_outlined,
                                              color: Colors.orange,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          const Text(
                                            'Dapatkan Lebih Banyak\nManfaat',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tingkatkan akun untuk fitur prioritas & laporan lengkap.',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () => _showDummyActionMessage('Upgrade Sekarang'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: theme.colorScheme.primary,
                                                foregroundColor: Colors.white,
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
                      padding: EdgeInsets.all(_isSidebarCollapsed ? 10 : 16),
                      child: _isSidebarCollapsed
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message:
                                      '${_currentUser.name} (@${_currentUser.username})',
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: isDark
                                        ? const Color(0xFF2D2A3E)
                                        : Colors.grey.shade200,
                                    backgroundImage:
                                        _currentUser.avatarUrl != null &&
                                            _currentUser.avatarUrl!.isNotEmpty
                                        ? NetworkImage(_currentUser.avatarUrl!)
                                        : const AssetImage(
                                                'assets/brandlogo.png',
                                              )
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
                                      _currentUser.avatarUrl != null &&
                                          _currentUser.avatarUrl!.isNotEmpty
                                      ? NetworkImage(_currentUser.avatarUrl!)
                                      : const AssetImage('assets/brandlogo.png')
                                            as ImageProvider,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                    ),
                  ],
                ),
              ),
            ),

            // ─── Konten utama — full width sisa layar ─────────────────
            // Tidak ada ConstrainedBox(maxWidth) agar konten penuh.
            // AppBar sticky di-handle oleh masing-masing screen dengan
            // toolbarHeight: 88 agar sejajar dengan brand row sidebar.
            Expanded(
              child: IndexedStack(index: activeIndex, children: screens),
            ),
          ],
        ),
      );
    }

    // ─── Mobile Layout ─────────────────────────────────────────────────
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: IndexedStack(index: activeIndex, children: screens),
            ),
            // Add padding at bottom to account for nav bar height
            const SizedBox(height: 0),
          ],
        ),
      ),
      bottomNavigationBar: CustomDiamondBottomBar(
        currentIndex: activeIndex,
        isDark: isDark,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (_currentUser.isAdmin) {
            if (index == 2 || index == 3) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _refreshProfile();
              });
            }
          } else {
            if (index == 3 || index == 4) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _refreshProfile();
              });
            }
          }
        },
        items: _currentUser.isAdmin
            ? [
                CustomNavItem(
                  icon: Icons.admin_panel_settings_outlined,
                  activeIcon: Icons.admin_panel_settings,
                  label: 'Admin',
                ),
                CustomNavItem(
                  icon: Icons.verified_user_outlined,
                  activeIcon: Icons.verified_user,
                  label: 'Verifikasi',
                ),
                CustomNavItem(
                  icon: Icons.notifications_none_outlined,
                  activeIcon: Icons.notifications,
                  label: 'Notifikasi',
                ),
                CustomNavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profil',
                ),
              ]
            : [
                CustomNavItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Dashboard',
                ),
                CustomNavItem(
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore,
                  label: 'Jelajahi',
                ),
                CustomNavItem(
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  label: 'Pesan',
                ),
                CustomNavItem(
                  icon: Icons.notifications_none_outlined,
                  activeIcon: Icons.notifications,
                  label: 'Notifikasi',
                ),
                CustomNavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profil',
                ),
              ],
      ),
    );
  }
}
