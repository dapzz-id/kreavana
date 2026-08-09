import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../app/subrole_theme_engine.dart';
import '../../../models/user_model.dart';
import '../services/dashboard_service.dart';
import '../../../widgets/dashboard_stats_charts.dart';
import '../../../widgets/subrole_right_sidebar.dart';
import '../../../screens/explore_screen.dart';
import '../../../screens/global_search_screen.dart';
import '../../../screens/notifications_screen.dart';
import '../../../screens/direct_message_screen.dart';

class AgencyDashboardScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel> onUserUpdated;

  const AgencyDashboardScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<AgencyDashboardScreen> createState() => _AgencyDashboardScreenState();
}

class _AgencyDashboardScreenState extends State<AgencyDashboardScreen> {
  final Color _accentColor = SubRoleThemeEngine.getAccentColor('user', 'brand_agency');
  bool _isLoading = true;
  List<Map<String, String>> _realtimeStats = [];
  Map<String, List<Map<String, String>>> _allSubRoleStats = {};

  @override
  void initState() {
    super.initState();
    _fetchRealtimeData();
  }

  Future<void> _fetchRealtimeData() async {
    try {
      final stats = await DashboardService.getStats(subRole: 'editor', roleType: 'user');
      final allStats = await DashboardService.getAllSubRoleStats(
        subRoleSlugs: ['photographer', 'videographer', 'editor', 'event_organizer'],
        roleType: 'user',
      );
      if (mounted) {
        setState(() {
          _realtimeStats = stats;
          _allSubRoleStats = allStats;
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
                          _buildCampaignMetrics(isDark),
                          const SizedBox(height: 24),
                          _buildChartSection(isDark),
                          const SizedBox(height: 24),
                          _buildActiveCampaigns(isDark),
                          const SizedBox(height: 24),
                          _buildTalentScoutingGrid(isDark),
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
                    _buildCampaignMetrics(isDark),
                    const SizedBox(height: 24),
                    _buildChartSection(isDark),
                    const SizedBox(height: 24),
                    SubRoleRightSidebar(
                      user: widget.user,
                      onUserUpdated: widget.onUserUpdated,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),
                    _buildActiveCampaigns(isDark),
                    const SizedBox(height: 24),
                    _buildTalentScoutingGrid(isDark),
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
                      'Cari talent influencer, fotografer komersial, sutradara...',
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.campaign_rounded, size: 16, color: _accentColor),
                const SizedBox(width: 6),
                Text(
                  'Creative Agency',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _accentColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildAppBarBadge(Icons.notifications_none_outlined, '3', isDark),
          const SizedBox(width: 4),
          _buildAppBarBadge(Icons.chat_bubble_outline, '1', isDark),
        ],
      ),
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
            HSLColor.fromColor(_accentColor).withLightness(0.25).toColor(),
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
              'Campaign Management & Talent Sourcing',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Selamat datang, ${widget.user.name}! 🚀',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Kelola rilis campaign brand, rekrut tim kreatif multi-disiplin, dan audit pembagian dana escrow proyek iklan Anda.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExploreScreen(user: widget.user),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _accentColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.post_add_rounded, size: 18),
            label: const Text('Rilis Brief Campaign Baru', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignMetrics(bool isDark) {
    final metrics = _realtimeStats.isNotEmpty
        ? _realtimeStats.map((item) {
            return {
              'title': item['label'] ?? 'Metrik Campaign',
              'val': item['value'] ?? '0',
              'icon': Icons.pie_chart_rounded,
            };
          }).toList()
        : [
            {'title': 'Active Campaigns', 'val': '5 Brand', 'icon': Icons.campaign},
            {'title': 'Roster Talent Active', 'val': '28 Kreator', 'icon': Icons.groups},
            {'title': 'Escrow Budget', 'val': 'Rp 85.000.000', 'icon': Icons.account_balance_wallet},
            {'title': 'Media Deliverables', 'val': '94% On Time', 'icon': Icons.verified},
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
                  Text(m['val'] as String, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.textDark)),
                  Text('Agency Verified', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _accentColor)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChartSection(bool isDark) {
    final subRolesList = [
      {'slug': 'photographer', 'name': 'Fotografi', 'color': _accentColor},
      {'slug': 'videographer', 'name': 'Videografi', 'color': Colors.redAccent},
      {'slug': 'editor', 'name': 'Editing', 'color': Colors.purple},
      {'slug': 'event_organizer', 'name': 'Event', 'color': Colors.blue},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
      ),
      child: DashboardStatsCharts(
        subRoleList: subRolesList,
        allSubRoleStats: _allSubRoleStats,
        selectedSubRole: 'photographer',
        currentRole: 'user',
        isDark: isDark,
      ),
    );
  }

  Widget _buildActiveCampaigns(bool isDark) {
    final campaigns = [
      {'brand': 'Skincare Campaign Q3', 'client': 'Aura Beauty Co.', 'budget': 'Rp 35.000.000', 'status': 'Production (6 Kreator)'},
      {'brand': 'Summer Fashion Commercial', 'client': 'Urban Threads', 'budget': 'Rp 50.000.000', 'status': 'Post-Production'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Brief & Campaign Aktif Agency',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: campaigns.map((c) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardBg : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _accentColor.withValues(alpha: 0.12),
                    child: Icon(Icons.movie_creation, color: _accentColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c['brand']!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textDark)),
                        const SizedBox(height: 2),
                        Text('Client: ${c['client']!} • Budget: ${c['budget']!}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(c['status']!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _accentColor)),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTalentScoutingGrid(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_rounded, color: _accentColor, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fitur Agency Direct Booking & Rate Card Roster',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  'Akses langsung portofolio resolusi tinggi, rate card khusus agency, dan klausa NDA otomatis.',
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
            child: const Text('Buka Roster Kreator'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarBadge(IconData icon, String count, bool isDark) {
    final isNotification = icon == Icons.notifications_none_outlined;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => isNotification
                ? NotificationsScreen(userId: widget.user.id ?? '')
                : const DirectMessageScreen(),
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1830) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
          ),
          if (count.isNotEmpty)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count,
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
