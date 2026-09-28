import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:kreavana/screens/direct_message_screen.dart';
import '../../../app/theme.dart';
import '../../../services/theme_transition_service.dart';
import '../../../screens/global_search_screen.dart';
import '../../../models/user_model.dart';
import '../../../screens/buat_kebutuhan_screen.dart';
import '../../../screens/notifications_screen.dart';
import '../../../services/badge_service.dart';
import '../../../screens/proyek_saya_screen.dart';
import '../../../screens/profile_screen.dart';
import '../../../services/job_contract_service.dart';
import '../../../models/job_contract.dart';
import '../../../services/api_service.dart';
import '../services/dashboard_service.dart';

class WoDashboardScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel> onUserUpdated;

  const WoDashboardScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<WoDashboardScreen> createState() => _WoDashboardScreenState();
}

class _WoDashboardScreenState extends State<WoDashboardScreen> {
  final GlobalKey _themeBtnKey = GlobalKey();

  static const Color _woPink = Color(0xFFA855F7);

  bool _isLoading = true;
  List<Map<String, dynamic>> _metrics = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _activities = [];
  Map<String, int> _statusCounts = {
    'Akan Datang': 0,
    'Sedang Berjalan': 0,
    'Dalam Persiapan': 0,
    'Selesai': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadWoData();
  }

  Future<void> _loadWoData() async {
    try {
      final results = await Future.wait([
        JobContractService.getUserContracts().catchError((_) => <JobContract>[]),
        DashboardService.getStats(subRole: 'wedding_organizer', roleType: 'creator').catchError((_) => <Map<String, String>>[]),
        ApiService.get('client-dashboard/overview', queryParams: {'role_type': 'creator'}).catchError((_) => <String, dynamic>{}),
      ]);

      final contracts = results[0] as List<JobContract>;
      final stats = results[1] as List<Map<String, String>>;
      final overviewRes = results[2] as Map<String, dynamic>;
      final overview = (overviewRes['data'] as Map<String, dynamic>?) ?? {};

      int upcoming = 0;
      int inProgress = 0;
      int prep = 0;
      int completed = 0;

      final loadedProjects = <Map<String, dynamic>>[];
      for (final c in contracts) {
        double progress;
        switch (c.workStatus.toLowerCase()) {
          case 'in_progress':
            progress = 0.65;
            inProgress++;
            break;
          case 'review':
          case 'pending':
            progress = 0.35;
            prep++;
            break;
          case 'completed':
            progress = 1.0;
            completed++;
            break;
          default:
            progress = 0.10;
            upcoming++;
        }
        loadedProjects.add({
          'title': c.title,
          'date': c.scheduledStartDate != null
              ? '${c.scheduledStartDate!.day}/${c.scheduledStartDate!.month}/${c.scheduledStartDate!.year}'
              : 'Jadwal Ditentukan',
          'progress': progress,
        });
      }

      final loadedVendors = <Map<String, dynamic>>[];
      final vendorList = overview['vendor_recommendations'] as List<dynamic>? ?? [];
      for (final v in vendorList) {
        if (v is Map<String, dynamic>) {
          loadedVendors.add({
            'name': (v['name'] ?? v['user_name'] ?? 'Vendor').toString(),
            'cat': (v['category'] ?? v['sub_role'] ?? 'Vendor Layanan').toString(),
            'rating': (v['rating'] ?? '4.9').toString(),
          });
        }
      }

      final loadedActivities = <Map<String, dynamic>>[];
      final actList = overview['activity_feed'] as List<dynamic>? ?? [];
      for (final a in actList) {
        if (a is Map<String, dynamic>) {
          loadedActivities.add({
            'title': (a['title'] ?? a['message'] ?? 'Aktivitas sistem').toString(),
            'time': (a['created_at_human'] ?? a['time'] ?? 'Baru saja').toString(),
          });
        }
      }

      final totalEventVal = stats.isNotEmpty
          ? (stats.firstWhere(
                (s) =>
                    s['label']?.toLowerCase().contains('event') == true ||
                    s['label']?.toLowerCase().contains('wedding') == true ||
                    s['label']?.toLowerCase().contains('proyek') == true,
                orElse: () => {'value': contracts.length.toString()},
              )['value'] ??
              contracts.length.toString())
          : contracts.length.toString();

      final loadedMetrics = [
        {
          'label': 'Total Wedding',
          'value': totalEventVal,
          'sub': '${contracts.length} paket/klien terdaftar',
          'icon': Icons.favorite_rounded,
          'color': _woPink,
        },
        {
          'label': 'Sedang Berjalan',
          'value': inProgress.toString(),
          'sub': 'Persiapan & Hari-H',
          'icon': Icons.hourglass_top_rounded,
          'color': const Color(0xFF10B981),
        },
        {
          'label': 'Mitra Vendor',
          'value': loadedVendors.length.toString(),
          'sub': '${loadedVendors.length} mitra aktif',
          'icon': Icons.handshake_outlined,
          'color': const Color(0xFFF59E0B),
        },
        {
          'label': 'Omset Penjualan',
          'value': overview['summary']?['estimated_expenses']?.toString() ?? 'Rp 0',
          'sub': 'Total transaksi aktif',
          'icon': Icons.account_balance_wallet_outlined,
          'color': const Color(0xFF3B82F6),
        },
      ];

      if (mounted) {
        setState(() {
          _projects = loadedProjects;
          _vendors = loadedVendors;
          _activities = loadedActivities;
          _metrics = loadedMetrics;
          _statusCounts = {
            'Akan Datang': upcoming,
            'Sedang Berjalan': inProgress,
            'Dalam Persiapan': prep,
            'Selesai': completed,
          };
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadWoData,
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
                        'Cari proyek pernikahan, vendor, atau paket...',
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
          const SizedBox(width: 20),
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
                backgroundColor: _woPink.withValues(alpha: 0.1),
                child: const Icon(Icons.favorite, color: _woPink, size: 20),
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
                    'Wedding Organizer',
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selamat datang, ${widget.user.name}! 💜',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kelola setiap momen pernikahan dengan mudah dan wujudkan pengalaman terbaik untuk klien Anda.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BuatKebutuhanScreen(user: widget.user)),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Buat Paket / Event Baru'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _woPink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCards(bool isDark) {
    final metrics = _metrics;

    if (metrics.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardBg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
          ),
        ),
        child: Center(
          child: Text(
            'Statistik belum tersedia.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: metrics.map((m) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
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
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Text(
                  m['value'] as String,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (m['sub'] as String?) ?? '',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopThreeColumns(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 900) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _buildLineChartCard(isDark)),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: _buildDonutChartCard(isDark)),
          const SizedBox(width: 16),
          Expanded(flex: 3, child: _buildActiveProjectsCard(isDark)),
        ],
      );
    }
    return Column(
      children: [
        _buildLineChartCard(isDark),
        const SizedBox(height: 16),
        _buildDonutChartCard(isDark),
        const SizedBox(height: 16),
        _buildActiveProjectsCard(isDark),
      ],
    );
  }

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
          const Text(
            'Ringkasan Penjualan',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 20),
                      FlSpot(1, 35),
                      FlSpot(2, 30),
                      FlSpot(3, 72.5),
                      FlSpot(4, 40),
                      FlSpot(5, 60),
                    ],
                    isCurved: true,
                    color: _woPink,
                    barWidth: 3,
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
    final total = _statusCounts.values.fold<int>(0, (a, b) => a + b);
    final upcomingCount = _statusCounts['Akan Datang'] ?? 0;
    final inProgressCount = _statusCounts['Sedang Berjalan'] ?? 0;
    final prepCount = _statusCounts['Dalam Persiapan'] ?? 0;
    final completedCount = _statusCounts['Selesai'] ?? 0;

    final upcomingPct = total > 0 ? (upcomingCount / total) * 100 : 0.0;
    final inProgressPct = total > 0 ? (inProgressCount / total) * 100 : 0.0;
    final prepPct = total > 0 ? (prepCount / total) * 100 : 0.0;
    final completedPct = total > 0 ? (completedCount / total) * 100 : 0.0;

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
            'Proyek Berdasarkan Status',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 35,
                sections: total == 0
                    ? [
                        PieChartSectionData(
                          value: 100,
                          color: isDark ? Colors.white12 : Colors.grey.shade200,
                          radius: 18,
                          showTitle: false,
                        ),
                      ]
                    : [
                        if (upcomingCount > 0)
                          PieChartSectionData(
                            value: upcomingPct,
                            color: _woPink,
                            radius: 18,
                            showTitle: false,
                          ),
                        if (inProgressCount > 0)
                          PieChartSectionData(
                            value: inProgressPct,
                            color: const Color(0xFF10B981),
                            radius: 18,
                            showTitle: false,
                          ),
                        if (prepCount > 0)
                          PieChartSectionData(
                            value: prepPct,
                            color: const Color(0xFFF59E0B),
                            radius: 18,
                            showTitle: false,
                          ),
                        if (completedCount > 0)
                          PieChartSectionData(
                            value: completedPct,
                            color: Colors.grey,
                            radius: 18,
                            showTitle: false,
                          ),
                      ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildCatRow(
            'Akan Datang',
            '$upcomingCount (${upcomingPct.toStringAsFixed(1)}%)',
            _woPink,
          ),
          _buildCatRow(
            'Sedang Berjalan',
            '$inProgressCount (${inProgressPct.toStringAsFixed(1)}%)',
            const Color(0xFF10B981),
          ),
          _buildCatRow(
            'Dalam Persiapan',
            '$prepCount (${prepPct.toStringAsFixed(1)}%)',
            const Color(0xFFF59E0B),
          ),
          _buildCatRow(
            'Selesai',
            '$completedCount (${completedPct.toStringAsFixed(1)}%)',
            Colors.grey,
          ),
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

  Widget _buildActiveProjectsCard(bool isDark) {
    final projects = _projects;

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
                'Proyek Aktif',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProyekSayaScreen(
                        user: widget.user,
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
          if (projects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 36,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada proyek wedding aktif.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...projects.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _woPink.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.favorite_border,
                        color: _woPink,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['title'] as String,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            p['date'] as String,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${((p['progress'] as double) * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
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
          Expanded(child: _buildTopVendorsCard(isDark)),
          const SizedBox(width: 16),
          Expanded(child: _buildPackagesAndRecs(isDark)),
        ],
      );
    }
    return Column(
      children: [
        _buildActivityCard(isDark),
        const SizedBox(height: 16),
        _buildTopVendorsCard(isDark),
        const SizedBox(height: 16),
        _buildPackagesAndRecs(isDark),
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
          if (_activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Belum ada log aktivitas tercatat.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                  ),
                ),
              ),
            )
          else
            ..._activities.map(
              (a) => _buildActItem(
                a['title'] as String,
                a['time'] as String,
              ),
            ),
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
            backgroundColor: _woPink.withValues(alpha: 0.1),
            child: const Icon(Icons.favorite_outline, color: _woPink, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 12))),
          Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTopVendorsCard(bool isDark) {
    final vendors = _vendors;

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
            'Top Vendor Favorit',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (vendors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Belum ada mitra vendor terhubung.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                  ),
                ),
              ),
            )
          else
            ...vendors.map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _woPink.withValues(alpha: 0.1),
                      child: Text(
                        (v['name'] as String? ?? 'V')[0],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (v['name'] as String?) ?? 'Vendor',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            (v['cat'] as String?) ?? 'Layanan',
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
                      (v['rating'] as String?) ?? '4.9',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
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

  Widget _buildPackagesAndRecs(bool isDark) {
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
                'Penjualan Berdasarkan Paket',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              _buildCatRow('Paket Premium', '40% (Rp 102.700.000)', _woPink),
              _buildCatRow(
                'Paket Gold',
                '30% (Rp 77.025.000)',
                const Color(0xFF10B981),
              ),
              _buildCatRow(
                'Paket Silver',
                '20% (Rp 51.350.000)',
                const Color(0xFFF59E0B),
              ),
              _buildCatRow(
                'Paket Intimate',
                '10% (Rp 25.675.000)',
                Colors.grey,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _woPink.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _woPink.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lengkapi Profil Perusahaan Anda',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              const Text(
                'Profil yang lengkap dapat meningkatkan kepercayaan klien dan peluang proyek.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        user: widget.user,
                        onUserUpdated: widget.onUserUpdated,
                        onLogout: () {},
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Lengkapi Sekarang',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
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
