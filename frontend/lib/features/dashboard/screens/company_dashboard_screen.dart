import '../../../services/badge_service.dart';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../app/subrole_theme_engine.dart';
import '../../../services/theme_transition_service.dart';
import '../../../services/job_contract_service.dart';
import '../../../models/job_contract.dart';
import '../../../services/api_service.dart';
import '../../../widgets/subrole_right_sidebar.dart';
import '../../../screens/global_search_screen.dart';
import '../../../models/user_model.dart';
import '../../../screens/buat_kebutuhan_screen.dart';
import '../../../screens/proyek_saya_screen.dart';
import '../../../screens/notifications_screen.dart';
import '../../../screens/direct_message_screen.dart';
import '../../../screens/profile_screen.dart';
import '../../../screens/explore_screen.dart';
import '../../../screens/ulasan_reputasi_screen.dart';

class CompanyDashboardScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel> onUserUpdated;

  const CompanyDashboardScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<CompanyDashboardScreen> createState() => _CompanyDashboardScreenState();
}

class _CompanyDashboardScreenState extends State<CompanyDashboardScreen> {
  final GlobalKey _themeBtnKey = GlobalKey();

  Color get _brandBlue => SubRoleThemeEngine.getAccentColor('user', 'company');

  int _activeTabIndex = 0;
  int _selectedPillarIndex = 0;

  bool _isLoading = true;
  List<Map<String, dynamic>> _metrics = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _creators = [];
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _tenders = [];

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final results = await Future.wait([
        JobContractService.getUserContracts().catchError((_) => <JobContract>[]),
        ApiService.get('client-dashboard/overview', queryParams: {'role_type': 'user'}).catchError((_) => <String, dynamic>{}),
        ApiService.get('institution/resources', queryParams: {'type': 'tenders'}).catchError((_) => <String, dynamic>{}),
        ApiService.get('institution/resources', queryParams: {'type': 'partners'}).catchError((_) => <String, dynamic>{}),
        ApiService.get('institution/resources', queryParams: {'type': 'budgets'}).catchError((_) => <String, dynamic>{}),
      ]);

      final contracts = results[0] as List<JobContract>;
      final overviewRes = results[1] as Map<String, dynamic>;
      final overview = (overviewRes['data'] as Map<String, dynamic>?) ?? {};
      final summary = (overview['summary'] as Map<String, dynamic>?) ?? {};
      final tenderRes = results[2] as Map<String, dynamic>;
      final tenderData = (tenderRes['data'] as List<dynamic>?) ?? [];
      final partnerRes = results[3] as Map<String, dynamic>;
      final partnerData = (partnerRes['data'] as List<dynamic>?) ?? [];
      final budgetRes = results[4] as Map<String, dynamic>;
      final budgetData = (budgetRes['data'] as List<dynamic>?) ?? [];

      final totalProjects = contracts.isNotEmpty ? contracts.length : (summary['total_projects'] ?? 0);
      final activeProjects = contracts.isNotEmpty 
          ? contracts.where((c) => c.workStatus == 'in_progress').length
          : (summary['active_projects'] ?? 0);

      double totalBudgetVal = 0;
      for (final b in budgetData) {
        if (b is Map<String, dynamic>) {
          final m = b['metadata'] as Map<String, dynamic>? ?? {};
          final val = double.tryParse(m['allocation']?.toString() ?? '') ?? 0;
          totalBudgetVal += val;
        }
      }
      final totalExpenses = totalBudgetVal > 0 
          ? 'Rp ${totalBudgetVal.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.')}'
          : (summary['total_payments'] ?? 'Rp 0');
      final pendingExpenses = summary['pending_payments'] ?? 'Rp 0';

      final loadedMetrics = <Map<String, dynamic>>[
        {
          'label': 'Total Proyek',
          'value': totalProjects.toString(),
          'sub': '$activeProjects sedang berjalan',
          'color': _brandBlue,
          'icon': Icons.business_center_outlined,
        },
        {
          'label': 'Proyek Aktif',
          'value': activeProjects.toString(),
          'sub': 'Dalam pengerjaan & monitoring',
          'color': const Color(0xFF10B981),
          'icon': Icons.trending_up,
        },
        {
          'label': 'Total Nilai Kontrak',
          'value': totalExpenses.toString(),
          'sub': 'Terkonfirmasi & escrow aman',
          'color': const Color(0xFFF59E0B),
          'icon': Icons.account_balance_wallet_outlined,
        },
        {
          'label': 'Menunggu Evaluasi',
          'value': pendingExpenses.toString(),
          'sub': 'Review berkas & approval',
          'color': const Color(0xFF8B5CF6),
          'icon': Icons.hourglass_top_outlined,
        },
      ];

      final loadedProjects = <Map<String, dynamic>>[];
      for (final c in contracts) {
        double progress = 0.5;
        if (c.workStatus == 'completed') {
          progress = 1.0;
        } else if (c.workStatus == 'in_progress') {
          progress = 0.65;
        } else if (c.workStatus == 'review') {
          progress = 0.85;
        } else {
          progress = 0.2;
        }

        loadedProjects.add({
          'title': c.title,
          'creator': c.creatorName.isNotEmpty ? c.creatorName : (c.clientName.isNotEmpty ? c.clientName : 'Kreator Mitra'),
          'progress': progress,
          'status': c.workStatus,
        });
      }

      final loadedCreators = <Map<String, dynamic>>[];
      for (final p in partnerData) {
        if (p is Map<String, dynamic>) {
          final meta = p['metadata'] as Map<String, dynamic>? ?? {};
          loadedCreators.add({
            'name': p['title'] ?? 'Mitra B2B',
            'cat': meta['category'] ?? 'Creative Partner',
            'rating': '4.9',
            'verified': true,
          });
        }
      }
      if (loadedCreators.isEmpty) {
        final vendorList = overview['vendor_recommendations'] as List<dynamic>? ?? [];
        for (final v in vendorList) {
          if (v is Map<String, dynamic>) {
            loadedCreators.add({
              'name': (v['name'] ?? v['user_name'] ?? 'Mitra B2B').toString(),
              'cat': (v['category'] ?? v['sub_role'] ?? 'Creative Partner').toString(),
              'rating': (v['rating'] ?? '4.9').toString(),
              'verified': true,
            });
          }
        }
      }

      final loadedActivities = <Map<String, dynamic>>[];
      final actList = overview['activity_feed'] as List<dynamic>? ?? [];
      for (final a in actList) {
        if (a is Map<String, dynamic>) {
          loadedActivities.add({
            'title': (a['title'] ?? a['message'] ?? 'Aktivitas sistem').toString(),
            'time': (a['time'] ?? a['created_at_human'] ?? 'Baru saja').toString(),
          });
        }
      }

      final loadedTenders = <Map<String, dynamic>>[];
      for (final t in tenderData) {
        if (t is Map<String, dynamic>) {
          final meta = t['metadata'] as Map<String, dynamic>? ?? {};
          final rawBudget = meta['budget'];
          String formattedBudget = 'Rp 0';
          if (rawBudget != null) {
            final bNum = double.tryParse(rawBudget.toString()) ?? 0;
            formattedBudget = 'Rp ${bNum.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
          }
          loadedTenders.add({
            'title': t['title'] ?? 'RFP Proyek Korporat',
            'desc': t['description'] ?? '',
            'category': meta['category'] ?? 'Pengadaan Kreatif',
            'budget': formattedBudget,
            'status': t['status'] ?? 'open',
            'deadline': meta['deadline'] ?? '2026-11-30',
          });
        }
      }

      if (mounted) {
        setState(() {
          _metrics = loadedMetrics;
          _projects = loadedProjects;
          _creators = loadedCreators;
          _activities = loadedActivities;
          _tenders = loadedTenders;
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
                                _buildHeroBanner(isDark),
                                const SizedBox(height: 20),
                                _buildTabNavigation(isDark),
                                const SizedBox(height: 20),
                                _buildActiveTabContent(isDark, isDesktop),
                                const SizedBox(height: 24),
                                _buildFooterSection(isDark),
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
                          const SizedBox(height: 16),
                          _buildTabNavigation(isDark),
                          const SizedBox(height: 16),
                          _buildActiveTabContent(isDark, isDesktop),
                          const SizedBox(height: 20),
                          SubRoleRightSidebar(
                            user: widget.user,
                            onUserUpdated: widget.onUserUpdated,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 24),
                          _buildFooterSection(isDark),
                        ],
                      ),
              ),
            ),
    );
  }

  // ── APP BAR ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      toolbarHeight: 75,
      automaticallyImplyLeading: false,
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
                    Expanded(
                      child: Text(
                        'Cari kreator, vendor mitra, atau paket proyek korporat...',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
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
              final box = _themeBtnKey.currentContext?.findRenderObject() as RenderBox?;
              final origin = box != null
                  ? box.localToGlobal(box.size.center(Offset.zero))
                  : const Offset(0, 0);
              ThemeTransitionService.animateToggle(origin: origin, toDark: !isDark);
            },
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _brandBlue.withValues(alpha: 0.1),
                child: Icon(Icons.business_rounded, color: _brandBlue, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Corporate / Perusahaan',
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

  Widget _buildAppBarBadge(IconData icon, String count, bool isDark) {
    final isNotification = icon == Icons.notifications_none_outlined;
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
            if (count.isNotEmpty && count != '0')
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
                    count,
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
  }

  // ── HERO BANNER (SESUAI HEADER INFOGRAFIS) ─────────────────────────────────
  Widget _buildHeroBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFF1E3A8A), const Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 14),
                              SizedBox(width: 6),
                              Text(
                                '#KolaborasiMembawaDampak',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Brand • Portofolio • Instansi • BUMN • Swasta',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Role Corporate / Perusahaan',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Temukan Talenta, Bangun Kolaborasi, Wujudkan Proyek',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kreavana membantu perusahaan menemukan kreator, talenta, dan mitra terbaik untuk mendukung kebutuhan komunikasi, pemasaran, event, dan proyek kreatif lainnya.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BuatKebutuhanScreen(user: widget.user)),
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('Buka Tender / RFP Proyek'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E3A8A),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ExploreScreen(user: widget.user)),
                ),
                icon: const Icon(Icons.search_rounded, size: 18, color: Colors.white),
                label: const Text('Cari & Pilih Kreator/Mitra', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white70),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── TAB BAR NAVIGATION ────────────────────────────────────────────────────
  Widget _buildTabNavigation(bool isDark) {
    final tabs = [
      {'title': 'Ikhtisar & Alur Kerja', 'icon': Icons.dashboard_customize_rounded},
      {'title': 'Ekosistem 5 Pilar', 'icon': Icons.hub_rounded},
      {'title': 'Cari Talenta & Vendor', 'icon': Icons.people_alt_rounded},
      {'title': 'Tender & Pengadaan (RFP)', 'icon': Icons.assignment_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final idx = entry.key;
          final tab = entry.value;
          final isSelected = _activeTabIndex == idx;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _activeTabIndex = idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _brandBlue
                      : (isDark ? AppTheme.cardBg : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? _brandBlue
                        : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _brandBlue.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tab['title'] as String,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── ACTIVE TAB CONTENT ────────────────────────────────────────────────────
  Widget _buildActiveTabContent(bool isDark, bool isDesktop) {
    switch (_activeTabIndex) {
      case 1:
        return _buildEcosystemPillarsSection(isDark);
      case 2:
        return _buildTalentAndVendorsSection(isDark);
      case 3:
        return _buildTendersSection(isDark);
      case 0:
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWorkflowSection(isDark),
            const SizedBox(height: 20),
            _buildWhyJoinSection(isDark),
            const SizedBox(height: 20),
            _buildMetricCards(isDark),
            const SizedBox(height: 20),
            _buildProjectsAndActivitiesGrid(isDark, isDesktop),
          ],
        );
    }
  }

  // ── ALUR KERJA CORPORATE / PERUSAHAAN (6 LANGKAH INTERAKTIF) ───────────────
  Widget _buildWorkflowSection(bool isDark) {
    final steps = [
      {
        'num': '1',
        'title': 'Daftar & Lengkapi Profil Perusahaan',
        'sub': 'Identitas, bidang usaha, kebutuhan',
        'desc': 'Lengkapi data identitas legalitas, profil industri perusahaan, NPWP, dan preferensi vendor mitra.',
        'icon': Icons.domain_verification_rounded,
        'actionLabel': 'Kelola Profil Perusahaan',
        'action': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(
                  user: widget.user,
                  onUserUpdated: widget.onUserUpdated,
                  onLogout: () {},
                ),
              ),
            ),
      },
      {
        'num': '2',
        'title': 'Cari & Pilih Kreator/Mitra',
        'sub': 'Filter sesuai kebutuhan',
        'desc': 'Temukan kreator terverifikasi, studio produksi, EO, atau vendor spesialis sesuai kriteria portofolio & budget.',
        'icon': Icons.person_search_rounded,
        'actionLabel': 'Jelajahi Kreator & Vendor',
        'action': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ExploreScreen(user: widget.user)),
            ),
      },
      {
        'num': '3',
        'title': 'Hubungi & Diskusi',
        'sub': 'Negosiasi, brief, penawaran',
        'desc': 'Buka sesi diskusi terpusat via Direct Message untuk membahas creative brief, timeline, dan negosiasi penawaran harga.',
        'icon': Icons.forum_rounded,
        'actionLabel': 'Buka Diskusi & Brief',
        'action': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DirectMessageScreen()),
            ),
      },
      {
        'num': '4',
        'title': 'Proses & Eksekusi Proyek',
        'sub': 'Laporan progres, monitoring',
        'desc': 'Pantau milestone pengerjaan secara transparan dengan escrow terproteksi hingga pekerjaan selesai memuaskan.',
        'icon': Icons.published_with_changes_rounded,
        'actionLabel': 'Pantau Progres Proyek',
        'action': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProyekSayaScreen(user: widget.user)),
            ),
      },
      {
        'num': '5',
        'title': 'Evaluasi & Tindak Lanjut',
        'sub': 'Penilaian kualitas, review',
        'desc': 'Verifikasi deliverable akhir, berikan rating bintang, ulasan kualitas, dan feedback untuk apresiasi mitra.',
        'icon': Icons.star_rate_rounded,
        'actionLabel': 'Evaluasi & Beri Ulasan',
        'action': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => UlasanReputasiScreen(user: widget.user)),
            ),
      },
      {
        'num': '6',
        'title': 'Bangun Reputasi & Kolaborasi Baru',
        'sub': 'Proyek berikutnya, kemitraan',
        'desc': 'Jadikan talenta favorit sebagai mitra langganan, inisiasi proyek lanjutan, atau buka pengadaan tender baru.',
        'icon': Icons.auto_graph_rounded,
        'actionLabel': 'Inisiasi Kolaborasi Baru',
        'action': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BuatKebutuhanScreen(user: widget.user)),
            ),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _brandBlue.withValues(alpha: 0.2)),
        boxShadow: [
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _brandBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.alt_route_rounded, color: _brandBlue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alur Kerja Corporate / Perusahaan',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '6 Tahapan terstandarisasi untuk kolaborasi proyek yang aman, transparan, dan terukur.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 750;
              final crossAxisCount = isWide ? 3 : 2;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: steps.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isWide ? 1.45 : 1.25,
                ),
                itemBuilder: (context, i) {
                  final s = steps[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _showWorkflowStepModal(context, s, isDark),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
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
                              CircleAvatar(
                                radius: 13,
                                backgroundColor: _brandBlue,
                                child: Text(
                                  s['num'] as String,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Icon(
                                s['icon'] as IconData,
                                size: 20,
                                color: _brandBlue,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            s['title'] as String,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s['sub'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Text(
                                'Aksi Detail',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _brandBlue,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 12, color: _brandBlue),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showWorkflowStepModal(BuildContext context, Map<String, dynamic> step, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.cardBg : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _brandBlue,
                    child: Text(
                      step['num'] as String,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step['title'] as String,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          step['sub'] as String,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                step['desc'] as String,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    (step['action'] as VoidCallback)();
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(step['actionLabel'] as String),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── EKOSISTEM & SINERGI 5 PILAR ───────────────────────────────────────────
  Widget _buildEcosystemPillarsSection(bool isDark) {
    final pillars = [
      {
        'name': 'Perusahaan / Corporate',
        'desc': 'Brand, Portofolio, Instansi, BUMN, Swasta, dll',
        'color': _brandBlue,
        'icon': Icons.business_rounded,
        'got': [
          'Akses ke kreator, talenta, dan penyedia jasa profesional',
          'Solusi kreatif untuk kebutuhan komunikasi, pemasaran, event, dan proyek khusus',
          'Efisiensi waktu dan biaya',
          'Transparansi harga dan kualitas',
          'Dukungan penuh dari tim Kreavana',
        ],
        'give': [
          'Informasi kebutuhan dan proyek',
          'Feedback & rating objektif',
          'Kerja sama jangka panjang',
          'Referensi & testimoni kredibel',
          'Kesempatan promosi brand',
        ],
      },
      {
        'name': 'Mitra / Vendor / Jasa',
        'desc': 'Studio, Event Organizer, Creative House, Percetakan, Properti, dll',
        'color': const Color(0xFFEA580C),
        'icon': Icons.handshake_rounded,
        'got': [
          'Proyek & klien enterprise baru',
          'Visibilitas bisnis berskala nasional',
          'Pengelolaan portofolio & paket layanan',
          'Kolaborasi dengan kreator lain',
          'Pertumbuhan pendapatan berkelanjutan',
        ],
        'give': [
          'Layanan & paket kerja sama B2B',
          'Kualitas tinggi & tepat waktu',
          'Harga kompetitif dan terstandarisasi',
          'Testimoni & rekam jejak terverifikasi',
        ],
      },
      {
        'name': 'Kreator / Freelancer',
        'desc': 'Fotografer, Videografer, Desainer, Content Creator, Talenta, dll',
        'color': const Color(0xFFDC2626),
        'icon': Icons.palette_rounded,
        'got': [
          'Akses peluang proyek korporat & job bernilai tinggi',
          'Portofolio digital yang terstruktur rapi',
          'Jaringan dan kolaborasi lintas disiplin',
          'Reputasi & rating terpercaya',
          'Tools komunikasi & manajemen proyek',
        ],
        'give': [
          'Karya, keahlian, dan portofolio profesional',
          'Partisipasi aktif di komunitas',
          'Rekomendasi & review timbal balik',
          'Kontribusi nyata pada ekosistem kreatif',
        ],
      },
      {
        'name': 'Sponsor / Pendukung',
        'desc': 'Brand, Perusahaan, Komunitas, Instansi, dll',
        'color': const Color(0xFF059669),
        'icon': Icons.campaign_rounded,
        'got': [
          'Eksposur brand yang lebih luas di ekosistem',
          'Asosiasi positif dengan komunitas kreatif aktif',
          'Kampanye komunikasi yang lebih efektif',
          'Citra positif dan engagement tinggi',
          'Peluang kolaborasi jangka panjang',
        ],
        'give': [
          'Dukungan pendanaan & sponsorship',
          'Program & event kolaboratif bersama',
          'Kesempatan promosi brand terarah',
          'Kontribusi pada pertumbuhan ekosistem',
        ],
      },
      {
        'name': 'Tim Kreavana',
        'desc': 'Operasional, Marketing, IT, Partnership, dll',
        'color': const Color(0xFF7C3AED),
        'icon': Icons.hub_rounded,
        'got': [
          'Pencapaian target & pertumbuhan platform',
          'Pengembangan skill & pengalaman industri',
          'Lingkungan kerja yang dinamis',
          'Dampak sosial nyata bagi ekonomi kreatif',
        ],
        'give': [
          'Layanan terbaik untuk seluruh pengguna',
          'Pengembangan fitur berkelanjutan & inovasi',
          'Perluasan jaringan dan relasi strategis',
          'Eksekusi program & kemitraan terpercaya',
        ],
      },
    ];

    final current = pillars[_selectedPillarIndex];
    final pColor = current['color'] as Color;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _brandBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.hub_rounded, color: _brandBlue, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ekosistem & Sinergi Multi-Pilar Kreavana',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pusat sinergi yang mempertemukan perusahaan dengan kreator, vendor, sponsor, dan ekosistem.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: pillars.asMap().entries.map((entry) {
                final i = entry.key;
                final p = entry.value;
                final isSel = _selectedPillarIndex == i;
                final c = p['color'] as Color;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(p['icon'] as IconData, size: 16, color: isSel ? Colors.white : c),
                    label: Text(p['name'] as String),
                    selected: isSel,
                    selectedColor: c,
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (_) => setState(() => _selectedPillarIndex = i),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: pColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: pColor.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: pColor,
                      child: Icon(current['icon'] as IconData, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            current['name'] as String,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            current['desc'] as String,
                            style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 650;
                    final gotList = current['got'] as List<String>;
                    final giveList = current['give'] as List<String>;

                    final gotWidget = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Manfaat yang Didapat',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...gotList.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('✔ ', style: TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                                Expanded(child: Text(item, style: const TextStyle(fontSize: 12, height: 1.35))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );

                    final giveWidget = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.volunteer_activism_rounded, color: _brandBlue, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Manfaat yang Diberikan ke Kreavana',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...giveList.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('✔ ', style: TextStyle(color: _brandBlue, fontSize: 12)),
                                Expanded(child: Text(item, style: const TextStyle(fontSize: 12, height: 1.35))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: gotWidget),
                          const SizedBox(width: 24),
                          Expanded(child: giveWidget),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        gotWidget,
                        const Divider(height: 24),
                        giveWidget,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── KENAPA BERGABUNG DENGAN KREAVANA? (VALUE PROPOSITION) ───────────────────
  Widget _buildWhyJoinSection(bool isDark) {
    final values = [
      {
        'title': 'Lebih mudah menemukan talent & mitra',
        'desc': 'Kurasi kreator dan vendor terpercaya berstandar enterprise',
        'icon': Icons.saved_search_rounded,
        'color': _brandBlue,
      },
      {
        'title': 'Proses efisien dan transparan',
        'desc': 'Brief terstandarisasi, pantauan milestone, dan escrow aman',
        'icon': Icons.bolt_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'title': 'Jaringan yang lebih luas',
        'desc': 'Terhubung ke ribuan mitra kreatif multi-disiplin se-Indonesia',
        'icon': Icons.groups_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'Mendukung pertumbuhan bisnis',
        'desc': 'Hasil proyek berkualitas yang mempercepat akselerasi dan ROI',
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFF8B5CF6),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kenapa Bergabung dengan Kreavana?',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '"Karena di sini, kebutuhan bertemu dengan potensi, dan setiap kolaborasi menciptakan nilai."',
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width > 850 ? 4 : (width > 480 ? 2 : 1);
              final childAspectRatio = width > 850 ? 1.05 : (width > 480 ? 1.25 : 2.6);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: values.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: childAspectRatio,
                ),
                itemBuilder: (context, i) {
                  final v = values[i];
                  final col = v['color'] as Color;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: col.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: col.withValues(alpha: 0.15),
                          child: Icon(v['icon'] as IconData, size: 16, color: col),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          v['title'] as String,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, height: 1.25),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: Text(
                            v['desc'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ── METRIC CARDS ──────────────────────────────────────────────────────────
  Widget _buildMetricCards(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 650;
        final count = isWide ? 4 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isWide ? 1.55 : 1.35,
          ),
          itemBuilder: (context, i) {
            final m = _metrics[i];
            final color = m['color'] as Color;

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        m['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(m['icon'] as IconData, size: 16, color: color),
                      ),
                    ],
                  ),
                  Text(
                    m['value'] as String,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
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
          },
        );
      },
    );
  }

  // ── PROYEK & AKTIVITAS GRID ───────────────────────────────────────────────
  Widget _buildProjectsAndActivitiesGrid(bool isDark, bool isDesktop) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildActiveProjectsCard(isDark),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActivityCard(isDark),
        ),
      ],
    );
  }

  Widget _buildActiveProjectsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Proyek Aktif & Berjalan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProyekSayaScreen(user: widget.user)),
                ),
                child: const Text('Lihat Semua', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._projects.take(4).map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          p['title'] as String,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${((p['progress'] as double) * 100).round()}%',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p['creator'] as String,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: p['progress'] as double,
                      minHeight: 5,
                      backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(_brandBlue),
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

  Widget _buildActivityCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Log Operasional & Aktivitas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              Text(
                'Hari ini',
                style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._activities.take(4).map(
            (act) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: _brandBlue.withValues(alpha: 0.1),
                    child: Icon(Icons.check_circle_outline_rounded, color: _brandBlue, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(act['title'] as String, style: const TextStyle(fontSize: 12, height: 1.3)),
                        const SizedBox(height: 2),
                        Text(act['time'] as String, style: const TextStyle(fontSize: 10, color: Colors.grey)),
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

  // ── TAB: TALENTA & VENDOR ─────────────────────────────────────────────────
  Widget _buildTalentAndVendorsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardBg : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Rekomendasi Kreator & Vendor Terverifikasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ExploreScreen(user: widget.user)),
                    ),
                    icon: const Icon(Icons.explore_rounded, size: 16),
                    label: const Text('Buka Direktori Lengkap'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandBlue,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._creators.map(
                (c) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _brandBlue.withValues(alpha: 0.15),
                        child: Text(
                          (c['name'] as String).isNotEmpty ? (c['name'] as String)[0] : 'V',
                          style: TextStyle(fontWeight: FontWeight.bold, color: _brandBlue),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded, size: 14, color: Colors.blue),
                              ],
                            ),
                            Text(c['cat'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(c['rating'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DirectMessageScreen()),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          side: BorderSide(color: _brandBlue),
                        ),
                        child: Text('Hubungi', style: TextStyle(fontSize: 11, color: _brandBlue)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── TAB: TENDER & PENGADAAN (RFP) ─────────────────────────────────────────
  Widget _buildTendersSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardBg : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Daftar Pengadaan & Tender Proyek (RFP)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BuatKebutuhanScreen(user: widget.user)),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Buka Tender Baru'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandBlue,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._tenders.map(
                (t) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _brandBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              t['category'] as String,
                              style: TextStyle(color: _brandBlue, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (t['status'] == 'open' ? const Color(0xFF10B981) : Colors.amber).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              (t['status'] as String).toUpperCase(),
                              style: TextStyle(
                                color: t['status'] == 'open' ? const Color(0xFF10B981) : Colors.amber.shade800,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(t['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(t['desc'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Pagu: ${t['budget']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('Deadline: ${t['deadline']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── FOOTER EKOSISTEM ──────────────────────────────────────────────────────
  Widget _buildFooterSection(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hub_rounded, size: 14, color: _brandBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Kreavana — Lebih dari Sekadar Platform, Ini Adalah Ekosistem',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
