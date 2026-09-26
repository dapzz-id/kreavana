import '../../../services/badge_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../app/subrole_theme_engine.dart';
import '../../../models/user_model.dart';
import '../../../services/theme_transition_service.dart';
import '../services/dashboard_service.dart';
import '../../../widgets/subrole_right_sidebar.dart';
import '../../../widgets/dashboard_stats_charts.dart';
import '../../../screens/buat_kebutuhan_screen.dart';
import '../../../screens/proyek_saya_screen.dart';
import '../../../screens/agenda_screen.dart';
import '../../../screens/marketplace_karya_screen.dart';
import '../../../screens/explore_screen.dart';
import '../../../screens/notifications_screen.dart';
import '../../../screens/direct_message_screen.dart';
import '../../../screens/global_search_screen.dart';
import '../../../screens/realisasi_anggaran_screen.dart';
import '../../../screens/pengumuman_publik_screen.dart';
import '../../../widgets/waving_hand_emoji.dart';

class GovtDashboardScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel> onUserUpdated;

  const GovtDashboardScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<GovtDashboardScreen> createState() => _GovtDashboardScreenState();
}

class _GovtDashboardScreenState extends State<GovtDashboardScreen> {
  final GlobalKey _themeBtnKey = GlobalKey();

  Color get _govBlue => SubRoleThemeEngine.getAccentColor('user', 'government');
  Color get _govLight => _govBlue.withValues(alpha: 0.7);
  Map<String, List<Map<String, String>>> _allSubRoleStats = {};
  bool _isLoadingStats = true;
  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final allStats = await DashboardService.getAllSubRoleStats(
        subRoleSlugs: ['government', 'institution', 'company', 'community'],
        roleType: 'user',
      );
      if (mounted) {
        setState(() {
          _allSubRoleStats = allStats;
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStats = false);
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
        onRefresh: _fetchStats,
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
                          RepaintBoundary(child: _buildHeroBanner(isDark)),
                          const SizedBox(height: 24),
                          RepaintBoundary(child: _buildMetricCards(isDark)),
                          const SizedBox(height: 24),
                          RepaintBoundary(child: _buildChartSection(isDark)),
                          const SizedBox(height: 24),
                          RepaintBoundary(child: _buildTopThreeColumns(isDark)),
                          const SizedBox(height: 24),
                          RepaintBoundary(child: _buildBottomThreeColumns(isDark)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 3,
                      child: RepaintBoundary(
                        child: SubRoleRightSidebar(
                          user: widget.user,
                          onUserUpdated: widget.onUserUpdated,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RepaintBoundary(child: _buildHeroBanner(isDark)),
                    const SizedBox(height: 24),
                    RepaintBoundary(child: _buildMetricCards(isDark)),
                    const SizedBox(height: 24),
                    RepaintBoundary(child: _buildChartSection(isDark)),
                    const SizedBox(height: 24),
                    RepaintBoundary(
                      child: SubRoleRightSidebar(
                        user: widget.user,
                        onUserUpdated: widget.onUserUpdated,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 24),
                    RepaintBoundary(child: _buildTopThreeColumns(isDark)),
                    const SizedBox(height: 24),
                    RepaintBoundary(child: _buildBottomThreeColumns(isDark)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildChartSection(bool isDark) {
    final subRolesList = [
      {'slug': 'government', 'name': 'Pemerintah', 'color': _govBlue},
      {'slug': 'institution', 'name': 'Instansi', 'color': Colors.teal},
      {'slug': 'company', 'name': 'Perusahaan', 'color': Colors.blue},
      {'slug': 'community', 'name': 'Komunitas', 'color': Colors.cyan},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _govBlue.withValues(alpha: 0.2)),
      ),
      child: DashboardStatsCharts(
        subRoleList: subRolesList,
        allSubRoleStats: _allSubRoleStats,
        selectedSubRole: 'government',
        currentRole: 'user',
        isDark: isDark,
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
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
                  color: isDark
                      ? const Color(0xFF1A1830)
                      : Colors.grey.shade100,
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
                    Expanded(
                      child: Text(
                        'Cari vendor, program, atau laporan...',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppTheme.textMuted
                              : Colors.grey.shade500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '⌘K',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.textMuted
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          ListenableBuilder(
            listenable: BadgeService(),
            builder: (_, _) => _buildAppBarBadge(
              Icons.notifications_none_outlined,
              BadgeService().unreadNotificationsText,
              isDark,
            ),
          ),
          const SizedBox(width: 4),
          ListenableBuilder(
            listenable: BadgeService(),
            builder: (_, _) => _buildAppBarBadge(
              Icons.chat_bubble_outline,
              BadgeService().unreadMessagesText,
              isDark,
            ),
          ),
          const SizedBox(width: 12),
          Builder(
            builder: (btnCtx) => IconButton(
              key: _themeBtnKey,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => RotationTransition(
                  turns: Tween(begin: 0.75, end: 1.0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  key: ValueKey(isDark),
                  size: 20,
                ),
              ),
              onPressed: () {
                final box =
                    _themeBtnKey.currentContext?.findRenderObject()
                        as RenderBox?;
                final origin = box != null
                    ? box.localToGlobal(box.size.center(Offset.zero))
                    : const Offset(0, 0);
                ThemeTransitionService.animateToggle(
                  origin: origin,
                  toDark: !isDark,
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _govBlue.withValues(alpha: 0.1),
                child: Icon(
                  Icons.account_balance_outlined,
                  color: _govBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.user.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Administrator Instansi',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              ),
            ],
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
        final badgeCount = isNotification
            ? BadgeService().unreadNotificationsText
            : BadgeService().unreadMessagesText;
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
                Icon(
                  icon,
                  size: 20,
                  color: isDark ? Colors.white : Colors.black87,
                ),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
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

  // ── Hero Banner ────────────────────────────────────────────────────────────
  Widget _buildHeroBanner(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 620;
        final introduction = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Selamat datang, ${widget.user.name}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const WavingHandEmoji(fontSize: 22),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Kelola program, temukan talenta kreatif, dan wujudkan kolaborasi terbaik untuk masyarakat.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
        );
        final createButton = ElevatedButton.icon(
          onPressed: () => _navigateTo('Buat Program'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Buat Peluang / Program Baru'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _govBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        return Container(
          padding: EdgeInsets.all(isNarrow ? 16 : 20),
          decoration: BoxDecoration(
            color: isDark
                ? _govBlue.withValues(alpha: 0.12)
                : _govBlue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _govBlue.withValues(alpha: 0.18)),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    introduction,
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: createButton),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: introduction),
                    const SizedBox(width: 20),
                    createButton,
                  ],
                ),
        );
      },
    );
  }

  // ── Dashboard metrics ─────────────────────────────────────────────────────
  Widget _buildMetricCards(bool isDark) {
    final stats = _allSubRoleStats['government'] ?? [];
    const metricColors = [
      Color(0xFF0F766E),
      Color(0xFF2563EB),
      Color(0xFFD97706),
      Color(0xFF16A34A),
    ];
    const metricIcons = [
      Icons.campaign_outlined,
      Icons.event_outlined,
      Icons.work_outline,
      Icons.groups_2_outlined,
    ];

    if (_isLoadingStats || stats.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardBg : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isLoadingStats ? Icons.hourglass_top_rounded : Icons.insights,
              color: _govBlue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isLoadingStats
                    ? 'Memuat ringkasan statistik...'
                    : 'Statistik belum tersedia untuk ditampilkan.',
                style: TextStyle(
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 190).floor().clamp(1, 4);
        final spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: stats.take(4).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final stat = entry.value;
            final color = metricColors[index % metricColors.length];
            final icon = metricIcons[index % metricIcons.length];

            return SizedBox(
              width: cardWidth,
              child: Container(
                constraints: const BoxConstraints(minHeight: 132),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardBg : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.11),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: color, size: 18),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.trending_up_rounded,
                          color: color.withValues(alpha: 0.65),
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      stat['value'] ?? '0',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stat['label'] ?? 'Statistik',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildEmptyDashboardState({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _govBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: _govBlue, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardPanelHeader({
    required String title,
    Widget? trailing,
    VoidCallback? onAction,
    String? actionTooltip,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ] else if (onAction != null)
          IconButton(
            onPressed: onAction,
            tooltip: actionTooltip,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            icon: Icon(Icons.arrow_forward_rounded, color: _govBlue, size: 20),
          ),
      ],
    );
  }

  // ── Top 3 Columns: Chart, Donut, Programs ─────────────────────────────────
  Widget _buildTopThreeColumns(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildLineChartCard(isDark)),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _buildDonutChartCard(isDark)),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: _buildRecentProgramsCard(isDark)),
            ],
          );
        }
        return Column(
          children: [
            _buildLineChartCard(isDark),
            const SizedBox(height: 16),
            _buildDonutChartCard(isDark),
            const SizedBox(height: 16),
            _buildRecentProgramsCard(isDark),
          ],
        );
      },
    );
  }

  // ── Line Chart: Ringkasan Program & Kegiatan ──────────────────────────────
  Widget _buildLineChartCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDashboardPanelHeader(
            title: 'Ringkasan Program & Kegiatan',
            trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      '6 Bulan Terakhir',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 14,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 5,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppTheme.textMuted
                              : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (v, _) {
                        const labels = [
                          'Jan \'25',
                          'Feb \'25',
                          'Mar \'25',
                          'Apr \'25',
                          'Mei \'25',
                          'Jun \'25',
                        ];
                        final i = v.toInt();
                        if (i < 0 || i >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark
                                  ? AppTheme.textMuted
                                  : Colors.grey.shade500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 8),
                      FlSpot(1, 10),
                      FlSpot(2, 11),
                      FlSpot(3, 14),
                      FlSpot(4, 12),
                      FlSpot(5, 13),
                    ],
                    isCurved: true,
                    color: _govLight,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 2,
                            strokeColor: _govLight,
                          ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 5),
                      FlSpot(1, 7),
                      FlSpot(2, 8),
                      FlSpot(3, 9),
                      FlSpot(4, 8),
                      FlSpot(5, 10),
                    ],
                    isCurved: true,
                    color: const Color(0xFF10B981),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 2,
                            strokeColor: const Color(0xFF10B981),
                          ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) {
                      final label = s.barIndex == 0
                          ? 'Rencana: ${s.y.toInt()}'
                          : 'Aktif: ${s.y.toInt()}';
                      return LineTooltipItem(
                        label,
                        TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot(_govLight, 'Rencana Program'),
              const SizedBox(width: 20),
              _buildLegendDot(const Color(0xFF10B981), 'Program Aktif'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  // ── Donut Chart: Program Berdasarkan Kategori ─────────────────────────────
  Widget _buildDonutChartCard(bool isDark) {
    final List<Map<String, dynamic>> categories = [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Program Berdasarkan Kategori',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          if (categories.isEmpty)
            _buildEmptyDashboardState(
              icon: Icons.donut_small_outlined,
              title: 'Belum ada data kategori',
              description: 'Ringkasan kategori akan tampil setelah data tersedia.',
              isDark: isDark,
            )
          else ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: categories.map((c) {
                    return PieChartSectionData(
                      value: c['percent'] as double,
                      color: c['color'] as Color,
                      radius: 20,
                      showTitle: false,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Column(
                children: [
                  Text(
                    categories.length.toString(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Total Kategori',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.textMuted
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...categories.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: c['color'] as Color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c['name'] as String,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(c['percent'] as double).toStringAsFixed(1)}% (${c['count']})',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          Center(
            child: TextButton.icon(
              onPressed: () => _navigateTo('Lihat Semua Kategori'),
              icon: const Text(
                'Lihat Semua Kategori',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              label: const Icon(Icons.arrow_forward, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ── Recent Programs List ──────────────────────────────────────────────────
  Widget _buildRecentProgramsCard(bool isDark) {
    final List<Map<String, dynamic>> programs = [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDashboardPanelHeader(
            title: 'Kegiatan / Program Terbaru',
            onAction: () => _navigateTo('Lihat Semua Kegiatan'),
            actionTooltip: 'Lihat semua kegiatan',
          ),
          const SizedBox(height: 8),
          if (programs.isEmpty)
            _buildEmptyDashboardState(
              icon: Icons.event_note_outlined,
              title: 'Belum ada kegiatan terbaru',
              description: 'Kegiatan dan program terbaru akan tampil di sini.',
              isDark: isDark,
            )
          else
            ...programs.map((program) => _buildProgramListItem(program, isDark)),
        ],
      ),
    );
  }

  Widget _buildProgramListItem(Map<String, dynamic> program, bool isDark) {
    return InkWell(
      onTap: () => _navigateTo('Lihat Semua Program'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardBg : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (program['status_color'] as Color).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                program['icon'] as IconData,
                color: program['status_color'] as Color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    program['title'] as String,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 10,
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        program['date'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppTheme.textMuted
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (program['status_color'] as Color).withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                program['status'] as String,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: program['status_color'] as Color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom 3 Columns: Activity, Vendors, Anggaran + Pengumuman ───────────
  Widget _buildBottomThreeColumns(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildActivityCard(isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildVendorLeaderboardCard(isDark)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAnggaranCard(isDark),
                    const SizedBox(height: 16),
                    _buildPengumumanCard(isDark),
                  ],
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            _buildActivityCard(isDark),
            const SizedBox(height: 16),
            _buildVendorLeaderboardCard(isDark),
            const SizedBox(height: 16),
            _buildAnggaranCard(isDark),
            const SizedBox(height: 16),
            _buildPengumumanCard(isDark),
          ],
        );
      },
    );
  }

  // ── Aktivitas Terbaru ─────────────────────────────────────────────────────
  Widget _buildActivityCard(bool isDark) {
    final List<Map<String, dynamic>> activities = [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDashboardPanelHeader(
            title: 'Aktivitas Terbaru',
            onAction: () => _navigateTo('Lihat Semua Aktivitas'),
            actionTooltip: 'Lihat semua aktivitas',
          ),
          const SizedBox(height: 8),
          if (activities.isEmpty)
            _buildEmptyDashboardState(
              icon: Icons.history_outlined,
              title: 'Belum ada aktivitas',
              description: 'Aktivitas terbaru akan tercatat di bagian ini.',
              isDark: isDark,
            )
          else
            ...activities.map((activity) => _buildActivityItem(activity, isDark)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity, bool isDark) {
    return InkWell(
      onTap: () => _navigateTo('Lihat Semua Aktivitas'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardBg : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (activity['color'] as Color).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                activity['icon'] as IconData,
                color: activity['color'] as Color,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity['title'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activity['subtitle'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              activity['time'] as String,
              style: TextStyle(
                fontSize: 9,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Kreator & Vendor Terbaik ──────────────────────────────────────────────
  Widget _buildVendorLeaderboardCard(bool isDark) {
    final List<Map<String, dynamic>> vendors = [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDashboardPanelHeader(
            title: 'Kreator & Vendor Terbaik',
            onAction: () => _navigateTo('Cari Vendor'),
            actionTooltip: 'Cari vendor',
          ),
          const SizedBox(height: 8),
          if (vendors.isEmpty)
            _buildEmptyDashboardState(
              icon: Icons.storefront_outlined,
              title: 'Belum ada rekomendasi vendor',
              description: 'Jelajahi daftar kreator dan vendor untuk memulai.',
              isDark: isDark,
            )
          else
            ...vendors.map((vendor) => _buildVendorRankItem(vendor, isDark)),
        ],
      ),
    );
  }

  Widget _buildVendorRankItem(Map<String, dynamic> vendor, bool isDark) {
    final rank = vendor['rank'] as int;
    final rankColor = vendor['color'] as Color;

    return InkWell(
      onTap: () => _navigateTo('Cari Vendor'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: rankColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: rank <= 3
                    ? Icon(
                        Icons.emoji_events_outlined,
                        size: 14,
                        color: rankColor,
                      )
                    : Text(
                        rank.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: rankColor,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 16,
              backgroundColor: _govLight.withValues(alpha: 0.1),
              child: Icon(Icons.store_outlined, size: 14, color: _govLight),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor['name'] as String,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    vendor['category'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                const SizedBox(width: 3),
                Text(
                  vendor['rating'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.bookmark_border, size: 18, color: _govLight),
          ],
        ),
      ),
    );
  }

  // ── Realisasi Anggaran ────────────────────────────────────────────────────
  Widget _buildAnggaranCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDashboardPanelHeader(
            title: 'Realisasi Anggaran',
            onAction: () => _navigateTo('Lihat Detail'),
            actionTooltip: 'Lihat detail anggaran',
          ),
          const SizedBox(height: 8),
          _buildEmptyDashboardState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Data anggaran belum tersedia',
            description: 'Realisasi akan tampil setelah data anggaran tercatat.',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  // ── Pengumuman Terbaru ────────────────────────────────────────────────────
  Widget _buildPengumumanCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDashboardPanelHeader(
            title: 'Pengumuman Terbaru',
            onAction: () => _navigateTo('Pengumuman Publik'),
            actionTooltip: 'Lihat semua pengumuman',
          ),
          const SizedBox(height: 12),
          _buildEmptyDashboardState(
            icon: Icons.campaign_outlined,
            title: 'Belum ada pengumuman terbaru',
            description: 'Pengumuman yang diterbitkan instansi akan tampil di sini.',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  void _navigateTo(String feature) {
    switch (feature) {
      case 'Buat Program':
      case 'Buat Kebutuhan':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BuatKebutuhanScreen(user: widget.user)),
        );
        break;
      case 'Cari Vendor':
      case 'Cari Kreator':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ExploreScreen(user: widget.user)),
        );
        break;
      case 'Lengkapi Profil':
      case 'Lihat Profil':
      case 'Lihat Semua Kategori':
      case 'Rincian':
      case 'Rincian Anggaran':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RealisasiAnggaranScreen(user: widget.user),
          ),
        );
        break;
      case 'Lihat Semua':
      case 'Lihat Semua Program':
      case 'Lihat Semua Aktivitas':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProyekSayaScreen(user: widget.user),
          ),
        );
        break;
      case 'Lihat Semua Kegiatan':
      case 'Lihat Semua Agenda':
      case 'Lihat Kalender':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AgendaScreen()),
        );
        break;
      case 'Lihat Semua Laporan':
      case 'Buka Semua Aset':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MarketplaceKaryaScreen(
              user: widget.user,
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
        );
        break;
      case 'Lihat Detail':
      case 'Lihat Detail Anggaran':
      case 'Realisasi Anggaran':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RealisasiAnggaranScreen(user: widget.user),
          ),
        );
        break;
      case 'Lihat Pengumuman':
      case 'Pengumuman Publik':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PengumumanPublikScreen(user: widget.user),
          ),
        );
        break;
      case 'Notifikasi':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotificationsScreen(userId: widget.user.id ?? ''),
          ),
        );
        break;
      case 'Pesan':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DirectMessageScreen()),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fitur "$feature" segera hadir!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    }
  }
}
