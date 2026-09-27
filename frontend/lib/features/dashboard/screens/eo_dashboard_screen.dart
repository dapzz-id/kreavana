import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../models/user_model.dart';
import '../../../screens/buat_kebutuhan_screen.dart';
import '../../../screens/creator_service_screen.dart';
import '../../../screens/creator_calendar_screen.dart';
import '../../../screens/direct_message_screen.dart';
import '../../../screens/global_search_screen.dart';
import '../../../screens/notifications_screen.dart';
import '../../../screens/kolaborasi_screen.dart';
import '../../../screens/pengaturan_screen.dart';
import '../../../screens/ulasan_reputasi_screen.dart';
import '../../../screens/wallet_screen.dart';
import '../../../services/api_service.dart';
import '../../../services/badge_service.dart';
import '../../../services/theme_transition_service.dart';
import '../../../services/job_contract_service.dart';
import '../../../models/job_contract.dart';
import '../services/dashboard_service.dart';
import '../../../widgets/desktop_sidebar_layout.dart';
import '../../../widgets/upgrade_plan_modal.dart';
import '../../../widgets/waving_hand_emoji.dart';

class EoDashboardEvent {
  final String title;
  final String type;
  final String date;
  final String venue;
  final double progress;
  final String status;
  final Color statusColor;

  const EoDashboardEvent({
    required this.title,
    required this.type,
    required this.date,
    required this.venue,
    required this.progress,
    required this.status,
    required this.statusColor,
  });
}

class EoDashboardVendor {
  final String name;
  final String category;
  final String rating;
  final String events;
  final IconData icon;

  const EoDashboardVendor({
    required this.name,
    required this.category,
    required this.rating,
    required this.events,
    required this.icon,
  });
}

class EoDashboardScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel> onUserUpdated;

  const EoDashboardScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<EoDashboardScreen> createState() => _EoDashboardScreenState();
}

class _EoDashboardScreenState extends State<EoDashboardScreen> {
  final GlobalKey _themeBtnKey = GlobalKey();

  static const Color _eoPurple = Color(0xFF6366F1);

  bool _isLoading = true;
  List<EoDashboardEvent> _events = [];
  List<EoDashboardVendor> _vendors = [];
  List<Map<String, dynamic>> _metrics = [];
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
    _loadEoData();
  }

  Future<void> _loadEoData() async {
    try {
      final results = await Future.wait([
        JobContractService.getUserContracts().catchError((_) => <JobContract>[]),
        DashboardService.getStats(subRole: 'event_organizer', roleType: 'creator').catchError((_) => <Map<String, String>>[]),
        ApiService.get('client-dashboard/overview', queryParams: {'role_type': 'creator'}).catchError((_) => <String, dynamic>{}),
      ]);

      final contracts = results[0] as List<JobContract>;
      final stats = results[1] as List<Map<String, String>>;
      final overviewRes = results[2] as Map<String, dynamic>;
      final overview = (overviewRes['data'] as Map<String, dynamic>?) ?? {};

      final loadedEvents = <EoDashboardEvent>[];
      int upcoming = 0;
      int inProgress = 0;
      int prep = 0;
      int completed = 0;

      for (final c in contracts) {
        Color statusColor;
        double progress;
        String statusLabel;
        switch (c.workStatus.toLowerCase()) {
          case 'in_progress':
            statusLabel = 'Sedang Berjalan';
            statusColor = const Color(0xFF10B981);
            progress = 0.65;
            inProgress++;
            break;
          case 'review':
          case 'pending':
            statusLabel = 'Dalam Persiapan';
            statusColor = const Color(0xFFF59E0B);
            progress = 0.35;
            prep++;
            break;
          case 'completed':
            statusLabel = 'Selesai';
            statusColor = const Color(0xFF6366F1);
            progress = 1.0;
            completed++;
            break;
          default:
            statusLabel = 'Akan Datang';
            statusColor = const Color(0xFF94A3B8);
            progress = 0.15;
            upcoming++;
        }

        loadedEvents.add(EoDashboardEvent(
          title: c.title,
          type: 'Event & Proyek',
          date: c.scheduledStartDate != null
              ? '${c.scheduledStartDate!.day}/${c.scheduledStartDate!.month}/${c.scheduledStartDate!.year}'
              : 'Jadwal Ditentukan',
          venue: c.clientName.isNotEmpty ? c.clientName : 'Lokasi Ditentukan',
          progress: progress,
          status: statusLabel,
          statusColor: statusColor,
        ));
      }

      final loadedVendors = <EoDashboardVendor>[];
      final vendorList = overview['vendor_recommendations'] as List<dynamic>? ?? [];
      for (final v in vendorList) {
        if (v is Map<String, dynamic>) {
          loadedVendors.add(EoDashboardVendor(
            name: (v['name'] ?? v['user_name'] ?? 'Vendor Mitra').toString(),
            category: (v['category'] ?? v['sub_role'] ?? 'Vendor').toString(),
            rating: (v['rating'] ?? '4.9').toString(),
            events: '${v['reviews_count'] ?? 10}+ Event',
            icon: Icons.storefront_outlined,
          ));
        }
      }

      final loadedActivities = <Map<String, dynamic>>[];
      final actList = overview['activity_feed'] as List<dynamic>? ?? [];
      for (final a in actList) {
        if (a is Map<String, dynamic>) {
          loadedActivities.add({
            'title': (a['title'] ?? a['message'] ?? 'Aktivitas sistem').toString(),
            'time': (a['created_at_human'] ?? a['time'] ?? 'Baru saja').toString(),
            'icon': Icons.notifications_active_outlined,
            'color': _eoPurple,
          });
        }
      }

      final totalEventVal = stats.isNotEmpty
          ? (stats.firstWhere(
                (s) => s['label']?.toLowerCase().contains('event') == true,
                orElse: () => {'value': contracts.length.toString()},
              )['value'] ?? contracts.length.toString())
          : contracts.length.toString();

      final loadedMetrics = [
        {
          'label': 'Total Event',
          'value': totalEventVal,
          'sub': '${contracts.length} proyek terdaftar',
          'icon': Icons.festival_outlined,
          'color': _eoPurple,
        },
        {
          'label': 'Event Berjalan',
          'value': inProgress.toString(),
          'sub': 'Persiapan & on-going',
          'icon': Icons.play_circle_outline_rounded,
          'color': const Color(0xFF10B981),
        },
        {
          'label': 'Vendor Mitra',
          'value': loadedVendors.length.toString(),
          'sub': '${loadedVendors.length} mitra terhubung',
          'icon': Icons.handshake_outlined,
          'color': const Color(0xFFF59E0B),
        },
        {
          'label': 'Anggaran Dikelola',
          'value': overview['summary']?['estimated_expenses']?.toString() ?? 'Rp 0',
          'sub': 'Realisasi anggaran aktif',
          'icon': Icons.account_balance_wallet_outlined,
          'color': const Color(0xFF3B82F6),
        },
      ];

      if (mounted) {
        setState(() {
          _events = loadedEvents;
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
    final isCompact = screenWidth < 700;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      appBar: _buildAppBar(isDark),
      drawer: isCompact ? _buildMobileDrawer(isDark) : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEoData,
              child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 24 : 16,
            16,
            isDesktop ? 24 : 16,
            100,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroBanner(isDark),
              const SizedBox(height: 20),
              _buildMetricCards(isDark),
              const SizedBox(height: 20),
              if (isDesktop) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          _buildLineChartCard(isDark),
                          const SizedBox(height: 20),
                          _buildActiveEventsCard(isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          _buildDonutChartCard(isDark),
                          const SizedBox(height: 20),
                          _buildTopVendorsCard(isDark),
                          const SizedBox(height: 20),
                          _buildSpendingAndRecs(isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                _buildLineChartCard(isDark),
                const SizedBox(height: 16),
                _buildActiveEventsCard(isDark),
                const SizedBox(height: 16),
                _buildDonutChartCard(isDark),
                const SizedBox(height: 16),
                _buildTopVendorsCard(isDark),
                const SizedBox(height: 16),
                _buildSpendingAndRecs(isDark),
              ],
              const SizedBox(height: 20),
              _buildActivityCard(isDark),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    final isCompact = MediaQuery.of(context).size.width < 700;

    return AppBar(
      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
      elevation: 0,
      toolbarHeight: 70,
      automaticallyImplyLeading: false,
      leading: isCompact
          ? Builder(
              builder: (context) => IconButton(
                tooltip: 'Buka menu',
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            )
          : null,
      title: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isCompact ? 190 : double.infinity,
                ),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GlobalSearchScreen(user: widget.user),
                    ),
                  ),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1A1830)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.inputBorder
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        Icon(
                          Icons.search,
                          color: isDark
                              ? AppTheme.textMuted
                              : Colors.grey.shade500,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cari event, vendor, atau talent...',
                            style: TextStyle(
                              fontSize: isCompact ? 11.5 : 13,
                              fontWeight: FontWeight.w500,
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
            ),
          ),
          const SizedBox(width: 8),
          ListenableBuilder(
            listenable: BadgeService(),
            builder: (_, _) => _buildAppBarBadge(
              Icons.notifications_none_outlined,
              BadgeService().unreadNotificationsText,
              isDark,
            ),
          ),
          if (isCompact) const SizedBox(width: 8),
          if (!isCompact) ...[
            const SizedBox(width: 6),
            ListenableBuilder(
              listenable: BadgeService(),
              builder: (_, _) => _buildAppBarBadge(
                Icons.chat_bubble_outline,
                BadgeService().unreadMessagesText,
                isDark,
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              key: _themeBtnKey,
              icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 20,
              ),
              onPressed: () {
                final box = _themeBtnKey.currentContext?.findRenderObject()
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
            const SizedBox(width: 8),
          ],
          if (isCompact)
            CircleAvatar(
              radius: 16,
              backgroundColor: _eoPurple.withValues(alpha: 0.1),
              backgroundImage: widget.user.avatarUrl?.isNotEmpty == true
                  ? NetworkImage(
                      ApiService.resolveAssetUrl(widget.user.avatarUrl!),
                    )
                  : null,
              child: widget.user.avatarUrl?.isNotEmpty == true
                  ? null
                  : const Icon(Icons.event, color: _eoPurple, size: 18),
            ),
          if (!isCompact)
            Row(
              children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _eoPurple.withValues(alpha: 0.1),
                backgroundImage: widget.user.avatarUrl?.isNotEmpty == true
                    ? NetworkImage(
                        ApiService.resolveAssetUrl(widget.user.avatarUrl!),
                      )
                    : null,
                child: widget.user.avatarUrl?.isNotEmpty == true
                    ? null
                    : const Icon(Icons.event, color: _eoPurple, size: 20),
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
                    'Event Organizer',
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

  Widget _buildMobileDrawer(bool isDark) {
    void closeDrawer() => Navigator.of(context).pop();
    void openScreen(Widget screen) {
      closeDrawer();
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }

    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.grey.shade200;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.84,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 24, 18, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _eoPurple,
                    _eoPurple.withValues(alpha: 0.82),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor: Colors.white,
                    backgroundImage: widget.user.avatarUrl?.isNotEmpty == true
                        ? NetworkImage(
                            ApiService.resolveAssetUrl(widget.user.avatarUrl!),
                          )
                        : null,
                    child: widget.user.avatarUrl?.isNotEmpty == true
                        ? null
                        : const Icon(Icons.event, color: _eoPurple, size: 25),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Event Organizer',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _mobileSectionLabel('UTAMA', isDark),
            _mobileMenuTile(
              icon: Icons.home_outlined,
              label: 'Beranda',
              onTap: closeDrawer,
            ),
            _mobileMenuTile(
              icon: Icons.add_box_outlined,
              label: 'Buat Event Baru',
              onTap: () {
                closeDrawer();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BuatKebutuhanScreen(user: widget.user),
                  ),
                );
              },
            ),
            Divider(height: 1, color: dividerColor),
            _mobileSectionLabel('LAYANAN EO', isDark),
            _mobileMenuTile(
              icon: Icons.account_balance_outlined,
              label: 'Paket Event',
              onTap: () => openScreen(
                CreatorServiceScreen(
                  user: widget.user,
                  serviceKey: 'eo_paket',
                  onUserUpdated: widget.onUserUpdated,
                ),
              ),
            ),
            _mobileMenuTile(
              icon: Icons.calendar_today_outlined,
              label: 'Jadwal Event',
              onTap: () => openScreen(
                CreatorServiceScreen(
                  user: widget.user,
                  serviceKey: 'eo_jadwal',
                  onUserUpdated: widget.onUserUpdated,
                ),
              ),
            ),
            _mobileMenuTile(
              icon: Icons.handshake_outlined,
              label: 'Vendor Partner',
              onTap: () => openScreen(
                CreatorServiceScreen(
                  user: widget.user,
                  serviceKey: 'eo_vendor',
                  onUserUpdated: widget.onUserUpdated,
                ),
              ),
            ),
            _mobileMenuTile(
              icon: Icons.timeline_outlined,
              label: 'Timeline EO',
              onTap: () => openScreen(
                CreatorServiceScreen(
                  user: widget.user,
                  serviceKey: 'eo_timeline',
                  onUserUpdated: widget.onUserUpdated,
                ),
              ),
            ),
            Divider(height: 1, color: dividerColor),
            _mobileSectionLabel('OPERASIONAL', isDark),
            _mobileMenuTile(
              icon: Icons.handshake_outlined,
              label: 'Kolaborasi',
              onTap: () => openScreen(
                KolaborasiScreen(
                  user: widget.user,
                  onUserUpdated: widget.onUserUpdated,
                ),
              ),
            ),
            _mobileMenuTile(
              icon: Icons.event_available_outlined,
              label: 'Kapasitas & Jadwal',
              onTap: () => openScreen(
                CreatorCalendarScreen(
                  user: widget.user,
                  onUserUpdated: widget.onUserUpdated,
                ),
              ),
            ),
            _mobileMenuTile(
              icon: Icons.star_border_rounded,
              label: 'Reputasi',
              onTap: () => openScreen(
                UlasanReputasiScreen(
                  user: widget.user,
                  onUserUpdated: widget.onUserUpdated,
                ),
              ),
            ),
            _mobileMenuTile(
              icon: Icons.credit_card_outlined,
              label: 'Pembayaran',
              onTap: () => openScreen(
                WalletScreen(
                  user: widget.user,
                  onUserUpdated: widget.onUserUpdated,
                ),
              ),
            ),
            Divider(height: 1, color: dividerColor),
            _mobileSectionLabel('AKUN', isDark),
            _mobileMenuTile(
              icon: Icons.workspace_premium_outlined,
              label: 'Upgrade Akun',
              onTap: () => UpgradePlanModal.show(
                context,
                user: widget.user,
              ),
            ),
            _mobileMenuTile(
              icon: Icons.settings_outlined,
              label: 'Pengaturan',
              onTap: () => openScreen(
                PengaturanScreen(
                  user: widget.user,
                  onUserUpdated: widget.onUserUpdated,
                  onLogout: () {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileSectionLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white54 : Colors.grey.shade500,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _mobileMenuTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon, color: _eoPurple),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }

  Widget _buildHeroBanner(bool isDark) {
    final isCompact = MediaQuery.of(context).size.width < 700;

    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                'Selamat datang, ${widget.user.name}!',
                maxLines: isCompact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const WavingHandEmoji(fontSize: 20),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Pantau progres acara, koordinasi vendor, dan kelola anggaran event Anda dalam satu dasbor.',
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
          ),
        ),
      ],
    );

    final action = ElevatedButton.icon(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BuatKebutuhanScreen(user: widget.user),
        ),
      ),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Buat Event Baru'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _eoPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                intro,
                const SizedBox(height: 18),
                SizedBox(width: double.infinity, child: action),
              ],
            )
          : Row(
              children: [
                Expanded(child: intro),
                const SizedBox(width: 16),
                action,
              ],
            ),
    );
  }

  Widget _buildMetricCards(bool isDark) {
    final metrics = _metrics;

    final isDesktop = MediaQuery.of(context).size.width > 700;

    if (isDesktop) {
      return Row(
        children: metrics.map((m) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildMetricCardItem(m, isDark),
            ),
          );
        }).toList(),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 176,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) =>
          _buildMetricCardItem(metrics[index], isDark),
    );
  }

  Widget _buildMetricCardItem(Map<String, dynamic> m, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (m['color'] as Color).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  (m['icon'] as IconData?) ?? Icons.event_outlined,
                  color: m['color'] as Color,
                  size: 20,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (m['color'] as Color).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.trending_up,
                  size: 14,
                  color: m['color'] as Color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            m['value'] as String,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            m['label'] as String,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            m['sub'] as String,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChartCard(bool isDark) {
    final isCompact = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flex(
            direction: isCompact ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _eoPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.show_chart_rounded,
                      color: _eoPurple,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Tren Pelaksanaan Event',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (isCompact) const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1B2E) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Semester 1 - 2026',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 210,
            child: LineChart(
              LineChartData(
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const months = [
                          'Jan',
                          'Feb',
                          'Mar',
                          'Apr',
                          'Mei',
                          'Jun',
                        ];
                        final idx = value.toInt();
                        if (idx >= 0 && idx < months.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              months[idx],
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.textMuted
                                    : Colors.grey.shade600,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 20,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.textMuted
                                : Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => isDark
                        ? const Color(0xFF2A2638)
                        : const Color(0xFF263238),
                    getTooltipItems: (spots) => spots
                        .map(
                          (spot) => LineTooltipItem(
                            spot.y.toInt().toString(),
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 20),
                      FlSpot(1, 35),
                      FlSpot(2, 38),
                      FlSpot(3, 58),
                      FlSpot(4, 45),
                      FlSpot(5, 55),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: _eoPurple,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _eoPurple.withValues(alpha: 0.12),
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

  Widget _buildDonutChartCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _eoPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.donut_large_rounded,
                  color: _eoPurple,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Status Event Saat Ini',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Builder(
            builder: (_) {
              final total = _statusCounts.values.fold<int>(0, (a, b) => a + b);
              final upcomingCount = _statusCounts['Akan Datang'] ?? 0;
              final inProgressCount = _statusCounts['Sedang Berjalan'] ?? 0;
              final prepCount = _statusCounts['Dalam Persiapan'] ?? 0;
              final completedCount = _statusCounts['Selesai'] ?? 0;

              final upcomingPct = total > 0 ? (upcomingCount / total) * 100 : 0.0;
              final inProgressPct = total > 0 ? (inProgressCount / total) * 100 : 0.0;
              final prepPct = total > 0 ? (prepCount / total) * 100 : 0.0;
              final completedPct = total > 0 ? (completedCount / total) * 100 : 0.0;

              return Column(
                children: [
                  SizedBox(
                    height: 140,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 38,
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
                                    color: _eoPurple,
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
                                    color: Colors.grey.shade400,
                                    radius: 18,
                                    showTitle: false,
                                  ),
                              ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCatRow(
                    'Akan Datang',
                    '$upcomingCount Event (${upcomingPct.toStringAsFixed(0)}%)',
                    _eoPurple,
                  ),
                  _buildCatRow(
                    'Sedang Berjalan',
                    '$inProgressCount Event (${inProgressPct.toStringAsFixed(0)}%)',
                    const Color(0xFF10B981),
                  ),
                  _buildCatRow(
                    'Dalam Persiapan',
                    '$prepCount Event (${prepPct.toStringAsFixed(0)}%)',
                    const Color(0xFFF59E0B),
                  ),
                  _buildCatRow(
                    'Selesai',
                    '$completedCount Event (${completedPct.toStringAsFixed(0)}%)',
                    Colors.grey.shade400,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCatRow(String name, String val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Flexible(
            child: Text(
              val,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveEventsCard(bool isDark) {
    final events = _events;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _eoPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.event_note_outlined,
                      color: _eoPurple,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: const Text(
                      'Event Aktif & Persiapan',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EoEventsScreen(
                        user: widget.user,
                        events: events,
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
          const SizedBox(height: 16),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      size: 40,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Belum ada event terdaftar.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
          ...events.map(
            (e) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1B2E) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.title,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.place_outlined,
                                  size: 13,
                                  color: isDark
                                      ? AppTheme.textMuted
                                      : Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${e.venue} • ${e.date}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark
                                          ? AppTheme.textMuted
                                          : Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: e.statusColor.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          e.status,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: e.statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: e.progress,
                            minHeight: 5,
                            backgroundColor: isDark
                                ? Colors.white10
                                : Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              e.statusColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(e.progress * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _eoPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.handshake_outlined,
                      color: _eoPurple,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: const Text(
                      'Top Vendor Partner',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreatorServiceScreen(
                      user: widget.user,
                      serviceKey: 'eo_vendor',
                      onUserUpdated: widget.onUserUpdated,
                    ),
                  ),
                ),
                child: const Text(
                  'Cari Vendor',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (vendors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 40,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Belum ada mitra vendor terhubung.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
          ...vendors.map(
            (v) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1B2E) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _eoPurple.withValues(alpha: 0.1),
                    child: Icon(
                      v.icon,
                      size: 18,
                      color: _eoPurple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${v.category} • ${v.events}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppTheme.textMuted
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: 13,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          v.rating,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                          ),
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

  Widget _buildSpendingAndRecs(bool isDark) {
    final categories = [
      {
        'name': 'Venue & Lokasi',
        'pct': 0.40,
        'val': 'Rp 89.000.000',
        'color': _eoPurple,
      },
      {
        'name': 'Catering & Konsumsi',
        'pct': 0.25,
        'val': 'Rp 55.600.000',
        'color': const Color(0xFF10B981),
      },
      {
        'name': 'Panggung & Lighting',
        'pct': 0.15,
        'val': 'Rp 33.400.000',
        'color': const Color(0xFFF59E0B),
      },
      {
        'name': 'Dokumentasi & Media',
        'pct': 0.12,
        'val': 'Rp 26.700.000',
        'color': const Color(0xFFEC4899),
      },
      {
        'name': 'Talent & Pengisi Acara',
        'pct': 0.08,
        'val': 'Rp 17.850.000',
        'color': const Color(0xFF3B82F6),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _eoPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.pie_chart_outline_rounded,
                      color: _eoPurple,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: const Text(
                      'Alokasi Anggaran Kategori',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                ),
              ),
              Flexible(
                child: Text(
                  'Total: Rp 222.5M',
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _eoPurple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...categories.map((c) {
            final color = c['color'] as Color;
            final pct = c['pct'] as double;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          c['name'] as String,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '${(pct * 100).toInt()}% • ${c['val']}',
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white70
                                : Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: isDark
                          ? Colors.white10
                          : Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _eoPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: _eoPurple,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: const Text(
                      'Aktivitas & Log Operasional Terbaru',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                ),
              ),
              Text(
                'Hari ini',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Belum ada log aktivitas terbaru.',
                  style: TextStyle(
                    fontSize: 13,
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
                (a['icon'] as IconData?) ?? Icons.notifications_none_rounded,
                (a['color'] as Color?) ?? _eoPurple,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActItem(String title, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
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

class EoEventsScreen extends StatefulWidget {
  final UserModel user;
  final List<EoDashboardEvent> events;

  const EoEventsScreen({
    super.key,
    required this.user,
    required this.events,
  });

  @override
  State<EoEventsScreen> createState() => _EoEventsScreenState();
}

class EoVendorsScreen extends StatefulWidget {
  final UserModel user;
  final List<EoDashboardVendor> vendors;
  final ValueChanged<UserModel>? onUserUpdated;

  const EoVendorsScreen({
    super.key,
    required this.user,
    required this.vendors,
    this.onUserUpdated,
  });

  @override
  State<EoVendorsScreen> createState() => _EoVendorsScreenState();
}

class _EoVendorsScreenState extends State<EoVendorsScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<EoDashboardVendor> get _filteredVendors {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.vendors;
    return widget.vendors.where((vendor) {
      return '${vendor.name} ${vendor.category}'
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vendors = _filteredVendors;

    final page = Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Vendor Partner'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Cari vendor atau kategori layanan...',
              leading: const Icon(Icons.search_rounded),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Hapus pencarian',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _searchController.clear,
                  ),
              ],
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                isDark ? AppTheme.cardBg : Colors.white,
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark
                        ? AppTheme.inputBorder
                        : Colors.grey.shade300,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${vendors.length} vendor tersedia',
                style: TextStyle(
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: vendors.isEmpty
                ? Center(
                    child: Text(
                      'Vendor tidak ditemukan',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade600,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: vendors.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildVendorCard(
                      vendors[index],
                      isDark,
                    ),
                  ),
          ),
        ],
      ),
    );

    return DesktopSidebarLayout(
      user: widget.user,
      activeRoute: 'eo_vendor',
      onUserUpdated: widget.onUserUpdated,
      child: page,
    );
  }

  Widget _buildVendorCard(EoDashboardVendor vendor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
            child: Icon(vendor.icon, color: const Color(0xFF6366F1)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vendor.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${vendor.category} • ${vendor.events}',
                  style: TextStyle(
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, size: 14, color: Colors.amber.shade700),
                const SizedBox(width: 4),
                Text(
                  vendor.rating,
                  style: TextStyle(
                    color: Colors.amber.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EoEventsScreenState extends State<EoEventsScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<EoDashboardEvent> get _filteredEvents {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.events;
    return widget.events.where((event) {
      final searchable = [
        event.title,
        event.type,
        event.date,
        event.venue,
        event.status,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final events = _filteredEvents;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Semua Event'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Cari judul, venue, tipe, atau status event...',
              leading: const Icon(Icons.search_rounded),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Hapus pencarian',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _searchController.clear,
                  ),
              ],
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                isDark ? AppTheme.cardBg : Colors.white,
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark
                        ? AppTheme.inputBorder
                        : Colors.grey.shade300,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              children: [
                Text(
                  '${events.length} event ditampilkan',
                  style: TextStyle(
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: events.isEmpty
                ? Center(
                    child: Text(
                      'Event tidak ditemukan',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade600,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildEventCard(
                      events[index],
                      isDark,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(EoDashboardEvent event, bool isDark) {
    return Container(
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.type,
                      style: TextStyle(
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: event.statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  event.status,
                  style: TextStyle(
                    color: event.statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _buildMeta(Icons.place_outlined, event.venue, isDark),
              _buildMeta(Icons.schedule_outlined, event.date, isDark),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: event.progress,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? Colors.white10
                        : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(event.statusColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(event.progress * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeta(IconData icon, String text, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
