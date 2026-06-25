import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'dashboard_screen.dart';
import 'direct_message_screen.dart';
import 'explore_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_verification_screen.dart';
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
    final result = await ProfileService.getProfile(_currentUser.id);
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _currentUser = result['user'];
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
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 14,
                        color: isSelected
                            ? activeColor
                            : (isDark
                                ? Colors.white70
                                : Colors.grey.shade800),
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
            NotificationsScreen(userId: _currentUser.id),
            ProfileScreen(
              user: _currentUser,
              onUserUpdated: _onUserUpdated,
              onLogout: _onLogout,
            ),
          ]
        : [
            DashboardScreen(user: _currentUser, onUserUpdated: _onUserUpdated),
            ExploreScreen(user: _currentUser),
            const DirectMessageScreen(),
            NotificationsScreen(userId: _currentUser.id),
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
                                        () => _isSidebarCollapsed = false),
                                  ),
                                ),
                              ],
                            )
                          : Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
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
                                        () => _isSidebarCollapsed = true),
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
                                    backgroundImage: _currentUser.avatarUrl !=
                                                null &&
                                            _currentUser.avatarUrl!.isNotEmpty
                                        ? NetworkImage(_currentUser.avatarUrl!)
                                        : const AssetImage(
                                                'assets/brandlogo.png')
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
                                  backgroundImage: _currentUser.avatarUrl !=
                                              null &&
                                          _currentUser.avatarUrl!.isNotEmpty
                                      ? NetworkImage(_currentUser.avatarUrl!)
                                      : const AssetImage(
                                              'assets/brandlogo.png')
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
                                  icon: const Icon(Icons.logout_rounded,
                                      color: Colors.redAccent, size: 20),
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
              child: IndexedStack(
                index: activeIndex,
                children: screens,
              ),
            ),
          ],
        ),
      );
    }

    // ─── Mobile Layout ─────────────────────────────────────────────────
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: activeIndex,
        children: screens,
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