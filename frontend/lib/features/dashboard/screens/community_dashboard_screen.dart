import '../../../services/badge_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../services/theme_transition_service.dart';
import '../../../screens/global_search_screen.dart';
import '../../../models/user_model.dart';
import '../../../screens/buat_kebutuhan_screen.dart';
import '../../../screens/notifications_screen.dart';
import '../../../screens/direct_message_screen.dart';
import '../../../screens/peluang_proyek_screen.dart';
import '../../../widgets/waving_hand_emoji.dart';
import '../../../services/job_contract_service.dart';
import '../../../models/job_contract.dart';
import '../../../services/api_service.dart';
import '../services/dashboard_service.dart';

class CommunityDashboardScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel> onUserUpdated;

  const CommunityDashboardScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<CommunityDashboardScreen> createState() =>
      _CommunityDashboardScreenState();
}

class _CommunityDashboardScreenState extends State<CommunityDashboardScreen> {
  final GlobalKey _themeBtnKey = GlobalKey();

  static const Color _commPurple = Color(0xFF6D28D9);

  bool _isLoading = true;
  List<Map<String, dynamic>> _metrics = [];
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _activities = [];

  @override
  void initState() {
    super.initState();
    _fetchCommunityData();
  }

  Future<void> _fetchCommunityData() async {
    try {
      final results = await Future.wait([
        JobContractService.getUserContracts().catchError((_) => <JobContract>[]),
        ApiService.get('client-dashboard/overview', queryParams: {'role_type': 'user'}).catchError((_) => <String, dynamic>{}),
        DashboardService.getStats(subRole: 'community', roleType: 'user').catchError((_) => <Map<String, String>>[]),
      ]);

      final contracts = results[0] as List<JobContract>;
      final overviewRes = results[1] as Map<String, dynamic>;
      final overview = (overviewRes['data'] as Map<String, dynamic>?) ?? {};
      final summary = (overview['summary'] as Map<String, dynamic>?) ?? {};

      final totalKegiatan = summary['total_projects'] ?? contracts.length;
      final eventBerjalan = summary['running_projects'] ?? summary['active_projects'] ?? contracts.where((c) => c.workStatus == 'in_progress').length;
      final totalKas = summary['estimated_expenses'] ?? summary['total_payments'] ?? 'Rp 0';
      final anggota = summary['proposals_count'] ?? summary['favorites'] ?? 24;

      final loadedMetrics = <Map<String, dynamic>>[
        {
          'label': 'Total Kegiatan',
          'value': totalKegiatan.toString(),
          'sub': '$eventBerjalan sedang berjalan',
          'color': _commPurple,
          'icon': Icons.groups_outlined,
        },
        {
          'label': 'Anggota Aktif',
          'value': anggota.toString(),
          'sub': 'Dalam komunitas',
          'color': const Color(0xFF10B981),
          'icon': Icons.people_outline,
        },
        {
          'label': 'Event Berjalan',
          'value': eventBerjalan.toString(),
          'sub': 'Aktif bulan ini',
          'color': const Color(0xFFF59E0B),
          'icon': Icons.event_available_outlined,
        },
        {
          'label': 'Kas / Anggaran',
          'value': totalKas.toString(),
          'sub': 'Total teralokasi',
          'color': const Color(0xFFEC4899),
          'icon': Icons.account_balance_wallet_outlined,
        },
      ];

      final loadedEvents = <Map<String, dynamic>>[];
      for (final c in contracts) {
        loadedEvents.add({
          'title': c.title,
          'date': c.scheduledStartDate != null
              ? '${c.scheduledStartDate!.day}/${c.scheduledStartDate!.month}/${c.scheduledStartDate!.year}'
              : 'Segera',
          'participants': c.clientName.isNotEmpty ? c.clientName : 'Komunitas',
        });
      }

      final loadedMembers = <Map<String, dynamic>>[];
      final vendorList = overview['vendor_recommendations'] as List<dynamic>? ?? [];
      for (final v in vendorList) {
        if (v is Map<String, dynamic>) {
          loadedMembers.add({
            'name': (v['name'] ?? v['user_name'] ?? 'Anggota').toString(),
            'role': (v['category'] ?? v['sub_role'] ?? 'Anggota').toString(),
          });
        }
      }

      final loadedActivities = <Map<String, dynamic>>[];
      final actList = overview['activity_feed'] as List<dynamic>? ?? [];
      for (final a in actList) {
        if (a is Map<String, dynamic>) {
          loadedActivities.add({
            'title': (a['title'] ?? a['message'] ?? 'Aktivitas komunitas').toString(),
            'time': (a['time'] ?? a['created_at'] ?? 'Baru saja').toString(),
          });
        }
      }

      if (mounted) {
        setState(() {
          _metrics = loadedMetrics;
          _events = loadedEvents;
          _members = loadedMembers;
          _activities = loadedActivities;
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
              onRefresh: _fetchCommunityData,
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
              _buildHeroBanner(isDark),
              const SizedBox(height: 20),
              _buildMetricCards(isDark),
              const SizedBox(height: 20),
              _buildTopThreeColumns(isDark),
              const SizedBox(height: 20),
              _buildBottomThreeColumns(isDark),
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
                        'Cari anggota, kegiatan, proyek...',
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
                backgroundColor: _commPurple.withValues(alpha: 0.1),
                child: const Icon(Icons.groups, color: _commPurple, size: 20),
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
                    'Akun Komunitas',
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Selamat datang, ${widget.user.name}!',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const WavingHandEmoji(fontSize: 22),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Kelola komunitas, kegiatan, dan jaringan untuk memberi dampak lebih luas.',
                  style: TextStyle(
                    fontSize: 13,
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
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Buat Kegiatan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _commPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCards(bool isDark) {
    final metrics = _metrics.isNotEmpty
        ? _metrics
        : [
            {
              'label': 'Total Kegiatan',
              'value': '0',
              'sub': '0 sedang berjalan',
              'color': _commPurple,
              'icon': Icons.groups_outlined,
            },
            {
              'label': 'Anggota Aktif',
              'value': '0',
              'sub': 'Dalam komunitas',
              'color': const Color(0xFF10B981),
              'icon': Icons.people_outline,
            },
            {
              'label': 'Event Berjalan',
              'value': '0',
              'sub': 'Aktif bulan ini',
              'color': const Color(0xFFF59E0B),
              'icon': Icons.event_available_outlined,
            },
            {
              'label': 'Kas / Anggaran',
              'value': 'Rp 0',
              'sub': 'Total teralokasi',
              'color': const Color(0xFFEC4899),
              'icon': Icons.account_balance_wallet_outlined,
            },
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        Widget buildCard(Map<String, dynamic> m) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(14),
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
                    Text(
                      m['label'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: (m['color'] as Color).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        (m['icon'] as IconData?) ?? Icons.image_outlined,
                        color: m['color'] as Color,
                        size: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  m['value'] as String,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  m['sub'] as String,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        if (isMobile) {
          final rows = <Widget>[];
          for (var i = 0; i < metrics.length; i += 2) {
            final rc = <Widget>[Expanded(child: buildCard(metrics[i]))];
            if (i + 1 < metrics.length) {
              rc.add(const SizedBox(width: 12));
              rc.add(Expanded(child: buildCard(metrics[i + 1])));
            }
            if (i > 0) rows.add(const SizedBox(height: 12));
            rows.add(Row(children: rc));
          }
          return Column(children: rows);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: metrics.map((m) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: buildCard(m),
              ),
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
          Expanded(flex: 2, child: _buildUpcomingEventsCard(isDark)),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: _buildActivityCard(isDark)),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: _buildActiveMembersCard(isDark)),
        ],
      );
    }
    return Column(
      children: [
        _buildUpcomingEventsCard(isDark),
        const SizedBox(height: 16),
        _buildActivityCard(isDark),
        const SizedBox(height: 16),
        _buildActiveMembersCard(isDark),
      ],
    );
  }

  Widget _buildLineChartCard(bool isDark) {
    // Simplified - replaced with upcoming events card
    return _buildUpcomingEventsCard(isDark);
  }

  Widget _buildDonutChartCard(bool isDark) {
    // Simplified - replaced with activity card
    return _buildActivityCard(isDark);
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

  Widget _buildUpcomingEventsCard(bool isDark) {
    final events = _events;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
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
                'Kegiatan Mendatang',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PeluangProyekScreen(user: widget.user),
                    ),
                  );
                },
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy_outlined,
                      size: 32,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada kegiatan',
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
            ...events.take(3).map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _commPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        color: _commPurple,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e['title']!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${e['date']} • ${e['participants']}',
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
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomThreeColumns(bool isDark) {
    // Simplified - only show participation card at bottom
    return _buildParticipationCard(isDark);
  }

  Widget _buildActivityCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aktivitas Terbaru',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 32,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada aktivitas',
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
            ..._activities.take(3).map(
              (act) => _buildActItem(
                act['title'] as String,
                act['time'] as String,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActItem(String title, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _commPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.group_add, color: _commPurple, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 12))),
          Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildActiveMembersCard(bool isDark) {
    final members = _members;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Anggota Aktif',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 32,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada anggota',
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
            ...members.take(3).map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _commPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          (m['name'] as String).isNotEmpty ? (m['name'] as String)[0] : 'A',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        m['name']!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _commPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        m['role']!,
                        style: const TextStyle(
                          fontSize: 9,
                          color: _commPurple,
                          fontWeight: FontWeight.w600,
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

  Widget _buildParticipationCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kategori Favorit',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildCatRow('Fotografi Landscape', '35%', _commPurple),
          _buildCatRow(
            'Street Photography',
            '25%',
            const Color(0xFF10B981),
          ),
          _buildCatRow(
            'Edukasi & Workshop',
            '20%',
            const Color(0xFFF59E0B),
          ),
          _buildCatRow('Hunting & Trip', '12%', const Color(0xFFEC4899)),
          _buildCatRow('Event & Komunitas', '8%', Colors.grey),
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
