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
    _refreshProfile();
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
    setState(() {
      _currentUser = updatedUser;
    });
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Tooltip(
        message: isCollapsed ? label : '',
        child: InkWell(
          onTap: () {
            setState(() {
              _currentIndex = index;
            });
            if (_currentUser.isAdmin) {
              if (index == 2 || index == 3) {
                _refreshProfile();
              }
            } else {
              if (index == 3 || index == 4) {
                _refreshProfile();
              }
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.grey.shade700),
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
                        color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.grey.shade800),
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
            DashboardScreen(
              user: _currentUser,
              onUserUpdated: _onUserUpdated,
            ),
            ExploreScreen(
              user: _currentUser,
            ),
            const DirectMessageScreen(),
            NotificationsScreen(
              userId: _currentUser.id,
            ),
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
          children: [
            // Sidebar Navigation with animated transition
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
              child: Column(
                children: [
                  const SizedBox(height: 28),
                  
                  // App Brand Logo & Toggle Button Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: _isSidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                      children: [
                        if (!_isSidebarCollapsed) ...[
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
                        ] else ...[
                          Image.asset(
                            'assets/brandlogo.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.contain,
                          ),
                        ],
                        
                        // Collapse / Expand toggle button (<)
                        IconButton(
                          icon: Icon(
                            _isSidebarCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _isSidebarCollapsed = !_isSidebarCollapsed;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Nav Items
                  Expanded(
                    child: ListView(
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
                  
                  // User Info bottom card
                  Container(
                    padding: EdgeInsets.all(_isSidebarCollapsed ? 8 : 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? const Color(0xFF2D2A3E)
                              : Colors.grey.shade200,
                        ),
                      ),
                    ),
                    child: _isSidebarCollapsed
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isDark ? const Color(0xFF2D2A3E) : Colors.grey.shade200,
                                backgroundImage: _currentUser.avatarUrl != null && _currentUser.avatarUrl!.isNotEmpty
                                    ? NetworkImage(_currentUser.avatarUrl!)
                                    : const AssetImage('assets/brandlogo.png') as ImageProvider,
                              ),
                              const SizedBox(height: 12),
                              IconButton(
                                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: _showLogoutDialog,
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isDark ? const Color(0xFF2D2A3E) : Colors.grey.shade200,
                                backgroundImage: _currentUser.avatarUrl != null && _currentUser.avatarUrl!.isNotEmpty
                                    ? NetworkImage(_currentUser.avatarUrl!)
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
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                      ),
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
                  ),
                ],
              ),
            ),
            
            // Page body (Centered max-width constraint for desktop look)
            Expanded(
              child: Container(
                color: isDark
                    ? theme.scaffoldBackgroundColor
                    : const Color(0xFFF8FAFC),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        border: Border(
                          left: BorderSide(
                            color: isDark
                                ? const Color(0xFF2D2A3E)
                                : Colors.grey.shade200,
                            width: 1,
                          ),
                          right: BorderSide(
                            color: isDark
                                ? const Color(0xFF2D2A3E)
                                : Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                      ),
                      child: IndexedStack(
                        index: activeIndex,
                        children: screens,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Mobile Layout
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
          setState(() {
            _currentIndex = index;
          });
          if (_currentUser.isAdmin) {
            if (index == 2 || index == 3) {
              _refreshProfile();
            }
          } else {
            if (index == 3 || index == 4) {
              _refreshProfile();
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
