import '../../../services/badge_service.dart';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../app/subrole_theme_engine.dart';
import '../../../models/user_model.dart';
import '../../../services/api_service.dart';
import '../services/dashboard_service.dart';
import '../../../widgets/subrole_right_sidebar.dart';
import '../../../screens/explore_screen.dart';
import '../../../screens/global_search_screen.dart';
import '../../../screens/notifications_screen.dart';
import '../../../screens/direct_message_screen.dart';
import '../../../screens/profile_screen.dart';

class CreatorAnimatorDashboardScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel> onUserUpdated;

  const CreatorAnimatorDashboardScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<CreatorAnimatorDashboardScreen> createState() =>
      _CreatorAnimatorDashboardScreenState();
}

class _CreatorAnimatorDashboardScreenState
    extends State<CreatorAnimatorDashboardScreen> {
  final Color _accentColor =
      SubRoleThemeEngine.getAccentColor('creator', 'animator');
  bool _isLoading = true;
  List<Map<String, String>> _realtimeStats = [];

  @override
  void initState() {
    super.initState();
    _fetchRealtimeData();
  }

  Future<void> _fetchRealtimeData() async {
    try {
      final stats = await DashboardService.getStats(subRole: 'editor', roleType: 'creator');
      if (mounted) {
        setState(() {
          _realtimeStats = stats;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      appBar: _buildAppBar(isDark),
      body: RefreshIndicator(
        onRefresh: _fetchRealtimeData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 24 : 16,
            16,
            isDesktop ? 24 : 16,
            110,
          ),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroBanner(isDark),
                          const SizedBox(height: 24),
                          _buildMetricsRow(isDark),
                          const SizedBox(height: 24),
                          _buildRenderQueueSection(isDark),
                          const SizedBox(height: 24),
                          _buildShowreelSection(isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 3,
                      child: SubRoleRightSidebar(
                        user: widget.user,
                        onUserUpdated: widget.onUserUpdated,
                        isDark: isDark,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroBanner(isDark),
                    const SizedBox(height: 24),
                    _buildMetricsRow(isDark),
                    const SizedBox(height: 24),
                    SubRoleRightSidebar(
                      user: widget.user,
                      onUserUpdated: widget.onUserUpdated,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),
                    _buildRenderQueueSection(isDark),
                    const SizedBox(height: 24),
                    _buildShowreelSection(isDark),
                  ],
                ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      toolbarHeight: 75,
      title: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GlobalSearchScreen(user: widget.user),
                ),
              ),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1830) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(
                      Icons.search,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Cari tender animasi 3D, proyek motion graphic...',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildAppBarBadge(Icons.notifications_none_outlined, '3', isDark),
          const SizedBox(width: 4),
          _buildAppBarBadge(Icons.chat_bubble_outline, '1', isDark),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(
                  user: widget.user,
                  onUserUpdated: widget.onUserUpdated,
                  onLogout: () => Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              ),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: _accentColor.withValues(alpha: 0.12),
              backgroundImage: widget.user.avatarUrl?.isNotEmpty == true
                  ? NetworkImage(
                      ApiService.resolveAssetUrl(widget.user.avatarUrl!),
                    )
                  : null,
              child: widget.user.avatarUrl?.isNotEmpty != true
                  ? Icon(Icons.person, color: _accentColor, size: 20)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarBadge(IconData icon, String count, bool isDark) {
    final isNotification = icon == Icons.notifications_none_outlined;
    return ListenableBuilder(
      listenable: BadgeService(),
      builder: (context, _) {
        final badgeCount = isNotification ? BadgeService().unreadNotificationsText : BadgeService().unreadMessagesText;
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => isNotification
                    ? NotificationsScreen(userId: '')
                    : const DirectMessageScreen(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2A3E) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 20, color: isDark ? Colors.white : Colors.black87),
                if (badgeCount.isNotEmpty && badgeCount != '0')
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badgeCount,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _accentColor,
            HSLColor.fromColor(_accentColor).withLightness(0.2).toColor(),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Studio Animasi 3D & VFX',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Kreator Animasi: ${widget.user.name} 🎬',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Kelola antrian render 3D, kirim storyboard ke klien, dan terima pembayaran bertahap (milestone) untuk proyek animasi Anda.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      user: widget.user,
                      onUserUpdated: widget.onUserUpdated,
                      onLogout: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _accentColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('Lengkapi Profil', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExploreScreen(user: widget.user),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_task_rounded, size: 18),
                label: const Text('Cari Proyek Animasi'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(bool isDark) {
    final metrics = _realtimeStats.isNotEmpty
        ? _realtimeStats.map((item) {
            return {
              'title': item['label'] ?? 'Metrik 3D',
              'val': item['value'] ?? '0',
              'icon': Icons.tune_rounded,
            };
          }).toList()
        : [
            {'title': 'Proyek 3D Aktif', 'val': '2 Proyek', 'icon': Icons.view_in_ar},
            {'title': 'Status Render', 'val': '85% Frame Complete', 'icon': Icons.tune},
            {'title': 'Rating Klien', 'val': '4.95 / 5.0', 'icon': Icons.star},
            {'title': 'Pendapatan Escrow', 'val': 'Rp 18.500.000', 'icon': Icons.account_balance_wallet},
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isMobile ? 2 : 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isMobile ? 1.4 : 1.6,
          ),
          itemBuilder: (context, index) {
            final m = metrics[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardBg : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _accentColor.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          m['title'] as String,
                          style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon((m['icon'] as IconData?) ?? Icons.image_outlined, color: _accentColor, size: 20),
                    ],
                  ),
                  Text(m['val'] as String, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.textDark)),
                  Text('3D Engine Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _accentColor)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRenderQueueSection(bool isDark) {
    final jobs = [
      {'title': 'Animasi Mascot 3D Iklan Minuman', 'client': 'PT Nusantara Beverage', 'milestone': 'Stage 2: Rigging & Lighting', 'progress': 0.75},
      {'title': 'Motion Graphic Explainer App', 'client': 'Fintech Go', 'milestone': 'Stage 3: Render 4K Delivery', 'progress': 0.95},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Milestone & Pipeline Proyek Animasi',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: jobs.map((j) {
            final prog = j['progress'] as double;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardBg : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(j['title'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textDark)),
                      Text('${(prog * 100).toInt()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _accentColor)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Klien: ${j['client']} • ${j['milestone']}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: prog,
                      minHeight: 6,
                      backgroundColor: _accentColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildShowreelSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.video_library_rounded, color: _accentColor, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Galeri Showreel & File 3D (.FBX/.GLTF)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tampilkan aset 3D interaktif yang dapat diputar 360° langsung di browser klien Anda.',
                  style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Kelola Showreel'),
          ),
        ],
      ),
    );
  }
}
