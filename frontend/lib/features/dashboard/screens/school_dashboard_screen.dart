import '../../../services/badge_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../services/api_service.dart';
import '../../../services/job_contract_service.dart';
import '../../../services/theme_transition_service.dart';
import '../../../screens/global_search_screen.dart';
import '../../../models/user_model.dart';
import '../../../screens/buat_kebutuhan_screen.dart';
import '../../../screens/explore_screen.dart';
import '../../../screens/notifications_screen.dart';
import '../../../screens/direct_message_screen.dart';
import '../../../screens/institution_workspace_screen.dart';
import '../../../screens/tim_hak_akses_screen.dart';
import '../../../widgets/waving_hand_emoji.dart';

class SchoolDashboardScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel> onUserUpdated;

  const SchoolDashboardScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<SchoolDashboardScreen> createState() => _SchoolDashboardScreenState();
}

class _SchoolDashboardScreenState extends State<SchoolDashboardScreen> {
  final GlobalKey _themeBtnKey = GlobalKey();

  static const Color _schoolBlue = Color(0xFF4F46E5);
  static const Color _schoolGreen = Color(0xFF10B981);

  bool _isLoading = true;
  List<Map<String, dynamic>> _resources = [];
  List<Map<String, dynamic>> _recentProjects = [];
  List<Map<String, dynamic>> _recommendedVendors = [];
  List<Map<String, dynamic>> _activityFeed = [];
  List<Map<String, dynamic>> _upcomingAgenda = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        ApiService.get('institution/resources'),
        ApiService.get('client-dashboard/overview?role_type=creator'),
        JobContractService.getUserContracts(),
      ]);

      if (!mounted) return;

      final resResources = results[0] as Map<String, dynamic>;
      final resOverview = results[1] as Map<String, dynamic>;
      final contracts = results[2] as List;

      // 1. Process Institution Resources
      final List<Map<String, dynamic>> loadedResources = [];
      if (resResources['status'] == true && resResources['data'] is List) {
        for (final item in resResources['data']) {
          if (item is Map) {
            loadedResources.add(Map<String, dynamic>.from(item));
          }
        }
      }

      // 2. Process Recent Projects (Tenders / Contracts)
      final List<Map<String, dynamic>> loadedProjects = [];
      final tenders = loadedResources.where((r) => r['resource_type'] == 'tenders').toList();
      for (final t in tenders.take(4)) {
        loadedProjects.add({
          'id': t['id']?.toString() ?? '',
          'title': t['title']?.toString() ?? 'Program Magang',
          'type': t['description']?.toString() ?? 'Program Kolaborasi Industri',
          'status': (t['status'] == 'open' || t['status'] == 'published') ? 'Aktif' : 'Selesai',
        });
      }
      for (final c in contracts.take(4 - loadedProjects.length)) {
        loadedProjects.add({
          'id': c.id,
          'title': c.title,
          'type': 'Kontrak Kerjasama: ${c.creatorName}',
          'status': c.status == 'completed' ? 'Selesai' : 'Berjalan',
        });
      }

      // 3. Process Overview (Vendors & Activity)
      final List<Map<String, dynamic>> loadedVendors = [];
      final List<Map<String, dynamic>> loadedActivities = [];
      if (resOverview['status'] == true && resOverview['data'] is Map) {
        final data = resOverview['data'] as Map;
        final rawVendors = data['vendor_recommendations'];
        if (rawVendors is List) {
          for (final v in rawVendors.take(5)) {
            if (v is Map) {
              loadedVendors.add(Map<String, dynamic>.from(v));
            }
          }
        }

        final rawActivities = data['activity_feed'];
        if (rawActivities is List) {
          for (final a in rawActivities.take(5)) {
            if (a is Map) {
              loadedActivities.add(Map<String, dynamic>.from(a));
            }
          }
        }
      }

      // 4. Process Agenda / Deadlines
      final List<Map<String, dynamic>> loadedAgenda = [];
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      for (final c in contracts) {
        if (c.deadline != null) {
          final dt = c.deadline!;
          loadedAgenda.add({
            'date': '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1].toUpperCase()}',
            'title': c.title,
            'time': 'Tenggat: 23:59 WIB',
          });
        }
      }

      setState(() {
        _resources = loadedResources;
        _recentProjects = loadedProjects;
        _recommendedVendors = loadedVendors;
        _activityFeed = loadedActivities;
        _upcomingAgenda = loadedAgenda;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _tendersCount => _resources.where((r) => r['resource_type'] == 'tenders').length;
  int get _partnersCount => _resources.where((r) => r['resource_type'] == 'partners').length;
  int get _showcasesCount => _resources.where((r) => r['resource_type'] == 'showcases').length;
  int get _membersCount => _resources.where((r) => r['resource_type'] == 'members').length + 1; // +1 Owner

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      appBar: _buildAppBar(isDark),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _schoolBlue),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 24 : 16,
            16,
            isDesktop ? 24 : 16,
            110,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RepaintBoundary(child: _buildHeroBanner(isDark)),
              const SizedBox(height: 24),
              RepaintBoundary(child: _buildMetricCards(isDark)),
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
                        'Cari program, mitra industri, atau portofolio siswa...',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppTheme.textMuted
                              : Colors.grey.shade500,
                        ),
                        overflow: TextOverflow.ellipsis,
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
          IconButton(
            key: _themeBtnKey,
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
            ),
            onPressed: () {
              final box =
                  _themeBtnKey.currentContext?.findRenderObject() as RenderBox?;
              final origin = box != null
                  ? box.localToGlobal(box.size.center(Offset.zero))
                  : const Offset(0, 0);
              ThemeTransitionService.animateToggle(
                origin: origin,
                toDark: !isDark,
              );
            },
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _schoolBlue.withValues(alpha: 0.1),
                child: const Icon(Icons.school, color: _schoolBlue, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Sekolah / Lembaga Pendidikan',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 640;

        final textBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Selamat datang, ${widget.user.name}!',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const WavingHandEmoji(fontSize: 24),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Kelola peluang, program magang PKL, kemitraan industri, dan portofolio karya siswa secara langsung di Kreavana.',
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              ),
            ),
          ],
        );

        final actionBtn = ElevatedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BuatKebutuhanScreen(user: widget.user),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Buka Program / Magang'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _schoolBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              textBlock,
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: actionBtn),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: textBlock),
            const SizedBox(width: 24),
            actionBtn,
          ],
        );
      },
    );
  }

  Widget _buildMetricCards(bool isDark) {
    final metrics = [
      {
        'label': 'Program & Magang',
        'value': '$_tendersCount Program',
        'sub': _tendersCount > 0 ? 'Tersedia di pengadaan' : 'Belum ada program',
        'icon': Icons.work_outline_rounded,
        'color': _schoolBlue,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstitutionWorkspaceScreen(
              user: widget.user,
              resourceType: 'tenders',
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
        ),
      },
      {
        'label': 'Mitra Industri Aktif',
        'value': '$_partnersCount Mitra',
        'sub': _partnersCount > 0 ? 'Kerjasama aktif' : 'Belum ada mitra',
        'icon': Icons.diversity_3_rounded,
        'color': _schoolGreen,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstitutionWorkspaceScreen(
              user: widget.user,
              resourceType: 'partners',
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
        ),
      },
      {
        'label': 'Portofolio Siswa',
        'value': '$_showcasesCount Karya',
        'sub': _showcasesCount > 0 ? 'Karya siap industri' : 'Belum diunggah',
        'icon': Icons.palette_rounded,
        'color': const Color(0xFF8B5CF6),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstitutionWorkspaceScreen(
              user: widget.user,
              resourceType: 'showcases',
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
        ),
      },
      {
        'label': 'Tim & Hak Akses',
        'value': '$_membersCount Staf',
        'sub': 'Kelola pengelola sekolah',
        'icon': Icons.group_rounded,
        'color': const Color(0xFFF59E0B),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TimHakAksesScreen(
              user: widget.user,
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
        ),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 850;
        final isMedium = constraints.maxWidth > 520 && !isWide;

        Widget buildCard(Map<String, dynamic> m) {
          return InkWell(
            onTap: m['onTap'] as VoidCallback?,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardBg : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (m['color'] as Color).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      (m['icon'] as IconData?) ?? Icons.image_outlined,
                      color: m['color'] as Color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    m['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    m['value'] as String,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m['sub'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: metrics.map((m) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: buildCard(m),
                ),
              );
            }).toList(),
          );
        }

        final cardWidth = isMedium
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: metrics.map((m) {
            return SizedBox(
              width: cardWidth,
              child: buildCard(m),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTopThreeColumns(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 700) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _buildLineChartCard(isDark)),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: _buildDonutChartCard(isDark)),
          const SizedBox(width: 16),
          Expanded(flex: 3, child: _buildRecentProjectsCard(isDark)),
        ],
      );
    }
    return Column(
      children: [
        _buildLineChartCard(isDark),
        const SizedBox(height: 16),
        _buildDonutChartCard(isDark),
        const SizedBox(height: 16),
        _buildRecentProjectsCard(isDark),
      ],
    );
  }

  Widget _buildLineChartCard(bool isDark) {
    final tenders = _tendersCount.toDouble();
    final partners = _partnersCount.toDouble();
    final showcases = _showcasesCount.toDouble();
    final members = _membersCount.toDouble();

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Aktivitas Sumber Daya',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _schoolBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Data Realtime',
                  style: TextStyle(
                    fontSize: 10,
                    color: _schoolBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final labels = ['Magang', 'Mitra', 'Karya', 'Tim'];
                        final idx = v.toInt();
                        if (idx >= 0 && idx < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(labels[idx], style: const TextStyle(fontSize: 10)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      FlSpot(0, tenders),
                      FlSpot(1, partners),
                      FlSpot(2, showcases),
                      FlSpot(3, members),
                    ],
                    isCurved: true,
                    color: _schoolBlue,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: _schoolBlue.withValues(alpha: 0.1),
                    ),
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutChartCard(bool isDark) {
    final total = (_tendersCount + _partnersCount + _showcasesCount + _membersCount);
    final hasData = total > 0;

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
            'Distribusi Program Sekolah',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: hasData
                    ? [
                        PieChartSectionData(
                          value: _tendersCount > 0 ? _tendersCount.toDouble() : 1,
                          color: _schoolBlue,
                          radius: 18,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: _partnersCount > 0 ? _partnersCount.toDouble() : 1,
                          color: _schoolGreen,
                          radius: 18,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: _showcasesCount > 0 ? _showcasesCount.toDouble() : 1,
                          color: const Color(0xFF8B5CF6),
                          radius: 18,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: _membersCount.toDouble(),
                          color: const Color(0xFFF59E0B),
                          radius: 18,
                          showTitle: false,
                        ),
                      ]
                    : [
                        PieChartSectionData(
                          value: 1,
                          color: Colors.grey.shade300,
                          radius: 18,
                          showTitle: false,
                        ),
                      ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildCatRow('Program & Magang', '$_tendersCount data', _schoolBlue),
          _buildCatRow('Mitra Industri', '$_partnersCount mitra', _schoolGreen),
          _buildCatRow('Karya Siswa', '$_showcasesCount portofolio', const Color(0xFF8B5CF6)),
          _buildCatRow('Tim Pengelola', '$_membersCount staf', const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _buildCatRow(String name, String val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 11))),
          Text(
            val,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentProjectsCard(bool isDark) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Program Terbaru',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InstitutionWorkspaceScreen(
                        user: widget.user,
                        resourceType: 'tenders',
                        onUserUpdated: widget.onUserUpdated,
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_recentProjects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.work_history_outlined,
                      size: 32,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada program magang/proyek',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._recentProjects.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _schoolBlue.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.school_outlined,
                        color: _schoolBlue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['title']!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            p['type']!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _schoolGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        p['status']!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: _schoolGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomThreeColumns(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 700) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildActivityCard(isDark)),
          const SizedBox(width: 16),
          Expanded(child: _buildFavoriteVendorsCard(isDark)),
          const SizedBox(width: 16),
          Expanded(child: _buildCalendarAndRecs(isDark)),
        ],
      );
    }
    return Column(
      children: [
        _buildActivityCard(isDark),
        const SizedBox(height: 16),
        _buildFavoriteVendorsCard(isDark),
        const SizedBox(height: 16),
        _buildCalendarAndRecs(isDark),
      ],
    );
  }

  Widget _buildActivityCard(bool isDark) {
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
            'Aktivitas Terbaru',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_activityFeed.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Belum ada aktivitas terbaru',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
              ),
            )
          else
            ..._activityFeed.map((act) {
              final title = act['title']?.toString() ?? 'Aktivitas sistem';
              final time = act['time']?.toString() ?? 'Baru saja';
              return _buildActItem(title, time);
            }),
        ],
      ),
    );
  }

  Widget _buildActItem(String title, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: _schoolBlue.withValues(alpha: 0.1),
            child: const Icon(Icons.school, color: _schoolBlue, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFavoriteVendorsCard(bool isDark) {
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
            'Kreator & Vendor Rekomendasi',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_recommendedVendors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Belum ada rekomendasi vendor',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
              ),
            )
          else
            ..._recommendedVendors.map(
              (v) {
                final name = v['name']?.toString() ?? 'Kreator';
                final cat = v['sub_role_label']?.toString() ?? v['category']?.toString() ?? 'Kreator';
                final rating = v['rating']?.toString() ?? '5.0';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _schoolBlue.withValues(alpha: 0.1),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'K',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _schoolBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              cat,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                      Text(
                        rating,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCalendarAndRecs(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
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
                'Kalender & Tenggat Mendatang',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              if (_upcomingAgenda.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Tidak ada tenggat mendatang',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ),
                )
              else
                ..._upcomingAgenda.map(
                  (cal) => _buildCalItem(
                    cal['date']!,
                    cal['title']!,
                    cal['time']!,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _schoolBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _schoolBlue.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tingkatkan Kolaborasi & Kemitraan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              const Text(
                'Temukan lebih banyak mitra industri dan studio magang terverifikasi di Kreavana.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExploreScreen(user: widget.user),
                  ),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: _schoolBlue),
                child: const Text(
                  'Jelajahi Mitra Industri',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalItem(String date, String title, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _schoolBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              date,
              style: const TextStyle(
                color: _schoolBlue,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  time,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
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
}
