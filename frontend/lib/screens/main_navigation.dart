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

  Widget _buildSidebarItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required ThemeData theme,
    required bool isDark,
  }) {
    final isSelected = _currentIndex == index;
    final activeColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
          if (index == 3 || index == 4) {
            _refreshProfile();
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
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white70 : Colors.grey.shade700),
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                  color: isSelected
                      ? activeColor
                      : (isDark ? Colors.white70 : Colors.grey.shade800),
                ),
              ),
            ],
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

    final List<Widget> screens = [
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

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Sidebar Navigation
            Container(
              width: 260,
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
                  // App Brand Logo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/brandlogo.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Kreavana',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Nav Items
                  Expanded(
                    child: ListView(
                      children: [
                        _buildSidebarItem(
                          icon: Icons.dashboard_outlined,
                          activeIcon: Icons.dashboard,
                          label: 'Dashboard',
                          index: 0,
                          theme: theme,
                          isDark: isDark,
                        ),
                        _buildSidebarItem(
                          icon: Icons.explore_outlined,
                          activeIcon: Icons.explore,
                          label: 'Jelajahi',
                          index: 1,
                          theme: theme,
                          isDark: isDark,
                        ),
                        _buildSidebarItem(
                          icon: Icons.chat_bubble_outline,
                          activeIcon: Icons.chat_bubble,
                          label: 'Pesan',
                          index: 2,
                          theme: theme,
                          isDark: isDark,
                        ),
                        _buildSidebarItem(
                          icon: Icons.notifications_none_outlined,
                          activeIcon: Icons.notifications,
                          label: 'Notifikasi',
                          index: 3,
                          theme: theme,
                          isDark: isDark,
                        ),
                        _buildSidebarItem(
                          icon: Icons.person_outline,
                          activeIcon: Icons.person,
                          label: 'Profil Saya',
                          index: 4,
                          theme: theme,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  // User Info bottom card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? const Color(0xFF2D2A3E)
                              : Colors.grey.shade200,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: 0.2,
                          ),
                          backgroundImage: _currentUser.avatarUrl != null
                              ? NetworkImage(_currentUser.avatarUrl!)
                              : null,
                          child: _currentUser.avatarUrl == null
                              ? Icon(
                                  Icons.person,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
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
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Keluar Akun'),
                                content: const Text(
                                  'Apakah Anda yakin ingin keluar dari Kreavana?',
                                ),
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
                                    child: const Text(
                                      'Keluar',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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
                        index: _currentIndex,
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
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: CustomDiamondBottomBar(
        currentIndex: _currentIndex,
        isDark: isDark,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 3 || index == 4) {
            _refreshProfile();
          }
        },
        items: [
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
