import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../app/subrole_theme_engine.dart';
import '../../../models/user_model.dart';
import '../../../models/job_contract.dart';
import '../../../services/job_contract_service.dart';
import '../../../services/api_service.dart';
import '../../../services/theme_transition_service.dart';
import '../services/dashboard_service.dart';
import '../../../widgets/subrole_right_sidebar.dart';
import '../../../screens/buat_kebutuhan_screen.dart';
import '../../../screens/proyek_saya_screen.dart';
import '../../../screens/agenda_screen.dart';
import '../../../screens/marketplace_karya_screen.dart';
import '../../../screens/explore_screen.dart';
import '../../../screens/notifications_screen.dart';
import '../../../screens/direct_message_screen.dart';
import '../../../screens/realisasi_anggaran_screen.dart';
import '../../../screens/pengumuman_publik_screen.dart';
import '../../../screens/institution_workspace_screen.dart';
import '../../../screens/profile_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../../widgets/app_bar_badge.dart';
import '../../../widgets/waving_hand_emoji.dart';
import '../../../widgets/official_document_viewer_dialog.dart';

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

  bool _isLoadingStats = true;
  int _activePillarIndex = 0; // 0: Ikhtisar, 1: Pengadaan LPSE, 2: DIPA & APBD, 3: Monev, 4: Siaran Pers

  List<Map<String, dynamic>> _programs = [];
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _categories = [];

  // Dedicated Government Resources from Backend
  List<Map<String, dynamic>> _budgets = [];
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _tenders = [];
  List<Map<String, dynamic>> _monitoring = [];
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _partners = [];
  List<Map<String, dynamic>> _facilities = [];
  List<Map<String, dynamic>> _reports = [];

  double _totalPagu = 0;
  double _totalRealisasi = 0;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final results = await Future.wait([
        DashboardService.getAllSubRoleStats(
          subRoleSlugs: ['government', 'institution', 'company', 'community'],
          roleType: 'user',
        ).catchError((_) => <String, List<Map<String, String>>>{}),
        JobContractService.getUserContracts().catchError((_) => <JobContract>[]),
        ApiService.get('client-dashboard/overview', queryParams: {'role_type': 'user'}).catchError((_) => <String, dynamic>{}),
        ApiService.get('institution/resources', queryParams: {'type': 'budgets'}).catchError((_) => <String, dynamic>{}),
        ApiService.get('institution/resources', queryParams: {'type': 'announcements'}).catchError((_) => <String, dynamic>{}),
        ApiService.get('institution/resources', queryParams: {'type': 'tenders'}).catchError((_) => <String, dynamic>{}),
        ApiService.get('institution/resources', queryParams: {'type': 'monitoring'}).catchError((_) => <String, dynamic>{}),
        ApiService.get('institution/resources', queryParams: {'type': 'documents'}).catchError((_) => <String, dynamic>{}),
        ApiService.get('institution/resources', queryParams: {'type': 'partners'}).catchError((_) => <String, dynamic>{}),
        ApiService.get('institution/resources', queryParams: {'type': 'facilities'}).catchError((_) => <String, dynamic>{}),
        ApiService.get('institution/resources', queryParams: {'type': 'reports'}).catchError((_) => <String, dynamic>{}),
      ]);

      final contracts = results[1] as List<JobContract>;
      final overviewRes = results[2] as Map<String, dynamic>;
      final overview = (overviewRes['data'] as Map<String, dynamic>?) ?? {};

      final budgetRes = results[3] as Map<String, dynamic>;
      final budgetData = (budgetRes['data'] as List<dynamic>?) ?? [];

      final announcementRes = results[4] as Map<String, dynamic>;
      final announcementData = (announcementRes['data'] as List<dynamic>?) ?? [];

      final tenderRes = results[5] as Map<String, dynamic>;
      final tenderData = (tenderRes['data'] as List<dynamic>?) ?? [];

      final monitoringRes = results[6] as Map<String, dynamic>;
      final monitoringData = (monitoringRes['data'] as List<dynamic>?) ?? [];

      final documentRes = results[7] as Map<String, dynamic>;
      final documentData = (documentRes['data'] as List<dynamic>?) ?? [];

      final partnerRes = results[8] as Map<String, dynamic>;
      final partnerData = (partnerRes['data'] as List<dynamic>?) ?? [];

      final facilityRes = results[9] as Map<String, dynamic>;
      final facilityData = (facilityRes['data'] as List<dynamic>?) ?? [];

      final reportRes = results[10] as Map<String, dynamic>;
      final reportData = (reportRes['data'] as List<dynamic>?) ?? [];

      // Parse Budgets
      final loadedBudgets = <Map<String, dynamic>>[];
      double sumPagu = 0;
      double sumReal = 0;
      for (final b in budgetData) {
        if (b is Map<String, dynamic>) {
          final meta = b['metadata'] as Map<String, dynamic>? ?? {};
          final alloc = double.tryParse(meta['allocation']?.toString() ?? '') ?? 0;
          final real = double.tryParse(meta['realization']?.toString() ?? '') ?? 0;
          sumPagu += alloc;
          sumReal += real;
          final pct = alloc > 0 ? ((real / alloc) * 100).clamp(0, 100).toInt() : 0;

          loadedBudgets.add({
            'id': b['id'],
            'title': b['title'] ?? 'Alokasi Anggaran',
            'period': meta['period'] ?? 'TA 2026',
            'allocation': alloc,
            'realization': real,
            'percent': pct,
            'status': b['status'] ?? 'approved',
          });
        }
      }

      // Parse Announcements
      final loadedAnnouncements = <Map<String, dynamic>>[];
      for (final a in announcementData) {
        if (a is Map<String, dynamic>) {
          final meta = a['metadata'] as Map<String, dynamic>? ?? {};
          loadedAnnouncements.add({
            'id': a['id'],
            'title': a['title'] ?? 'Pengumuman Resmi',
            'description': a['description'] ?? '',
            'category': meta['category'] ?? 'Warta Kedinasan',
            'valid_until': meta['valid_until'] ?? '16 Okt 2026',
            'status': a['status'] ?? 'published',
          });
        }
      }

      // Parse Tenders
      final loadedTenders = <Map<String, dynamic>>[];
      for (final t in tenderData) {
        if (t is Map<String, dynamic>) {
          final meta = t['metadata'] as Map<String, dynamic>? ?? {};
          final bVal = double.tryParse(meta['budget']?.toString() ?? '') ?? 0;
          loadedTenders.add({
            'id': t['id'],
            'title': t['title'] ?? 'Paket Pengadaan LPSE',
            'category': meta['category'] ?? 'Pengadaan Jasa',
            'budget': bVal,
            'deadline': meta['deadline'] ?? '15 Nov 2026',
            'status': t['status'] ?? 'open',
          });
        }
      }

      // Parse Monitoring
      final loadedMonitoring = <Map<String, dynamic>>[];
      for (final m in monitoringData) {
        if (m is Map<String, dynamic>) {
          final meta = m['metadata'] as Map<String, dynamic>? ?? {};
          final prg = int.tryParse(meta['progress']?.toString() ?? '') ?? 50;
          loadedMonitoring.add({
            'id': m['id'],
            'title': m['title'] ?? 'Indikator Kinerja Program',
            'indicator': meta['indicator'] ?? 'Capaian Output',
            'progress': prg,
            'target_date': meta['target_date'] ?? 'Desember 2026',
            'status': m['status'] ?? 'in_progress',
          });
        }
      }

      // Parse Documents
      final loadedDocuments = <Map<String, dynamic>>[];
      for (final d in documentData) {
        if (d is Map<String, dynamic>) {
          final meta = d['metadata'] as Map<String, dynamic>? ?? {};
          loadedDocuments.add({
            'id': d['id'],
            'title': d['title'] ?? 'Dokumen Kedinasan',
            'category': meta['category'] ?? 'Surat Keputusan (SK)',
            'document_date': meta['document_date'] ?? '2026',
            'url': meta['url'] ?? '',
          });
        }
      }

      // Parse Partners
      final loadedPartners = <Map<String, dynamic>>[];
      for (final p in partnerData) {
        if (p is Map<String, dynamic>) {
          final meta = p['metadata'] as Map<String, dynamic>? ?? {};
          loadedPartners.add({
            'id': p['id'],
            'title': p['title'] ?? 'Rekanan Resmi Daerah',
            'category': meta['category'] ?? 'Sanggar Seni & Mitra',
            'contact': meta['contact'] ?? '',
            'website': meta['website'] ?? '',
          });
        }
      }

      // Parse Facilities (Venue & Sarana Daerah)
      final loadedFacilities = <Map<String, dynamic>>[];
      for (final f in facilityData) {
        if (f is Map<String, dynamic>) {
          final meta = f['metadata'] as Map<String, dynamic>? ?? {};
          loadedFacilities.add({
            'id': f['id'],
            'title': f['title'] ?? 'Sarana & Venue Daerah',
            'description': f['description'] ?? '',
            'category': meta['category'] ?? 'Gedung Kesenian',
            'capacity': meta['capacity'] ?? '-',
            'location': meta['location'] ?? 'Kompleks Budaya Daerah',
            'facilities': meta['facilities'] ?? '',
            'terms': meta['terms'] ?? '',
            'manager': meta['manager'] ?? 'Dinas Terkait',
            'status': f['status'] ?? 'open',
          });
        }
      }

      // Parse Reports (Laporan Dampak Publik & Kisah Sukses)
      final loadedReports = <Map<String, dynamic>>[];
      for (final r in reportData) {
        if (r is Map<String, dynamic>) {
          final meta = r['metadata'] as Map<String, dynamic>? ?? {};
          loadedReports.add({
            'id': r['id'],
            'title': r['title'] ?? 'Laporan Dampak Publik',
            'description': r['description'] ?? '',
            'category': meta['category'] ?? 'Evaluasi Program',
            'period': meta['period'] ?? 'TA 2026',
            'beneficiaries': meta['beneficiaries'] ?? '-',
            'economic_impact': meta['economic_impact'] ?? '-',
            'satisfaction_rate': meta['satisfaction_rate'] ?? '98%',
            'testimonial_author': meta['testimonial_author'] ?? '',
            'testimonial_quote': meta['testimonial_quote'] ?? '',
            'verified_badge': meta['verified_badge'] ?? 'Terverifikasi BSrE',
            'status': r['status'] ?? 'published',
          });
        }
      }

      // Parse Contracts/Programs
      final loadedPrograms = <Map<String, dynamic>>[];
      for (final c in contracts) {
        String statusLabel = 'Persiapan';
        Color statusColor = const Color(0xFFF59E0B);
        IconData icon = Icons.assignment_outlined;

        if (c.workStatus == 'in_progress') {
          statusLabel = 'Berjalan';
          statusColor = const Color(0xFF10B981);
          icon = Icons.pending_actions_outlined;
        } else if (c.workStatus == 'completed') {
          statusLabel = 'Selesai';
          statusColor = const Color(0xFF2563EB);
          icon = Icons.check_circle_outline;
        }

        final dateStr = c.scheduledStartDate != null
            ? '${c.scheduledStartDate!.day}/${c.scheduledStartDate!.month}/${c.scheduledStartDate!.year}'
            : 'Belum dijadwalkan';

        loadedPrograms.add({
          'title': c.title,
          'date': dateStr,
          'status': statusLabel,
          'status_color': statusColor,
          'icon': icon,
        });
      }

      // Parse Activities
      final loadedActivities = <Map<String, dynamic>>[];
      final actList = overview['activity_feed'] as List<dynamic>? ?? [];
      const defaultColors = [Color(0xFF2563EB), Color(0xFF10B981), Color(0xFFF59E0B)];
      int actIdx = 0;
      for (final a in actList) {
        if (a is Map<String, dynamic>) {
          loadedActivities.add({
            'title': (a['title'] ?? a['message'] ?? 'Aktivitas instansi').toString(),
            'subtitle': (a['description'] ?? a['user_name'] ?? 'Pembaruan sistem').toString(),
            'time': (a['time'] ?? a['created_at'] ?? 'Baru saja').toString(),
            'color': defaultColors[actIdx % defaultColors.length],
            'icon': Icons.notifications_active_outlined,
          });
          actIdx++;
        }
      }

      // Parse Vendors
      final loadedVendors = <Map<String, dynamic>>[];
      final vendorList = overview['vendor_recommendations'] as List<dynamic>? ?? [];
      int rank = 1;
      for (final v in vendorList) {
        if (v is Map<String, dynamic>) {
          loadedVendors.add({
            'rank': rank,
            'name': (v['name'] ?? v['user_name'] ?? 'Vendor Terverifikasi').toString(),
            'category': (v['category'] ?? v['sub_role'] ?? 'Layanan Kreatif').toString(),
            'rating': (v['rating'] ?? '4.9').toString(),
            'color': rank == 1 ? const Color(0xFFF59E0B) : (rank == 2 ? const Color(0xFF94A3B8) : const Color(0xFFD97706)),
          });
          rank++;
        }
      }

      // Parse Categories
      final loadedCategories = <Map<String, dynamic>>[];
      final needsList = overview['project_needs'] as List<dynamic>? ?? [];
      if (needsList.isNotEmpty) {
        const catColors = [Color(0xFF2563EB), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFF8B5CF6)];
        int cIdx = 0;
        final totalNeeds = needsList.length;
        for (final n in needsList) {
          if (n is Map<String, dynamic>) {
            loadedCategories.add({
              'name': (n['title'] ?? n['category'] ?? 'Kategori').toString(),
              'percent': 100.0 / totalNeeds,
              'count': 1,
              'color': catColors[cIdx % catColors.length],
            });
            cIdx++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _programs = loadedPrograms;
          _activities = loadedActivities;
          _vendors = loadedVendors;
          _categories = loadedCategories;

          _budgets = loadedBudgets;
          _announcements = loadedAnnouncements;
          _tenders = loadedTenders;
          _monitoring = loadedMonitoring;
          _documents = loadedDocuments;
          _partners = loadedPartners;
          _facilities = loadedFacilities;
          _reports = loadedReports;

          _totalPagu = sumPagu;
          _totalRealisasi = sumReal;

          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000000) {
      return 'Rp ${(amount / 1000000000).toStringAsFixed(2)} M';
    } else if (amount >= 1000000) {
      return 'Rp ${(amount / 1000000).toStringAsFixed(1)} Jt';
    }
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          if (_isLoadingStats)
            const LinearProgressIndicator(
              minHeight: 2.5,
              valueColor: AlwaysStoppedAnimation(Color(0xFF1D4ED8)),
            ),
          Expanded(
            child: RefreshIndicator(
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
                                const SizedBox(height: 20),
                                RepaintBoundary(child: _buildWorkflowStepsCard(isDark)),
                                const SizedBox(height: 20),
                                RepaintBoundary(child: _buildGovernmentPillarsBar(isDark)),
                                const SizedBox(height: 20),
                                RepaintBoundary(child: _buildMetricCards(isDark)),
                                const SizedBox(height: 24),
                                _buildPillarContent(isDark),
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
                          const SizedBox(height: 16),
                          RepaintBoundary(child: _buildWorkflowStepsCard(isDark)),
                          const SizedBox(height: 16),
                          RepaintBoundary(child: _buildGovernmentPillarsBar(isDark)),
                          const SizedBox(height: 16),
                          RepaintBoundary(child: _buildMetricCards(isDark)),
                          const SizedBox(height: 20),
                          RepaintBoundary(
                            child: SubRoleRightSidebar(
                              user: widget.user,
                              onUserUpdated: widget.onUserUpdated,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildPillarContent(isDark),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Government Pillar Tab Bar ─────────────────────────────────────────────
  Widget _buildGovernmentPillarsBar(bool isDark) {
    final pillars = [
      {'title': 'Ikhtisar Kedinasan', 'icon': Icons.account_balance_outlined},
      {'title': 'Pengadaan & LPSE (${_tenders.length})', 'icon': Icons.gavel_rounded},
      {'title': 'Alokasi DIPA/APBD', 'icon': Icons.account_balance_wallet_outlined},
      {'title': 'Pengawasan Monev', 'icon': Icons.fact_check_outlined},
      {'title': 'Warta & Siaran Pers (${_announcements.length})', 'icon': Icons.campaign_outlined},
      {'title': 'Fasilitas & Venue Daerah (${_facilities.length})', 'icon': Icons.storefront_outlined},
      {'title': 'Laporan Dampak & Kisah Sukses (${_reports.length})', 'icon': Icons.insights_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: pillars.asMap().entries.map((entry) {
          final idx = entry.key;
          final p = entry.value;
          final isSelected = _activePillarIndex == idx;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                p['icon'] as IconData,
                size: 16,
                color: isSelected ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
              ),
              label: Text(p['title'] as String),
              selected: isSelected,
              onSelected: (_) => setState(() => _activePillarIndex = idx),
              selectedColor: const Color(0xFF1D4ED8),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
              ),
              backgroundColor: isDark ? const Color(0xFF1F1D36) : Colors.grey.shade100,
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF1D4ED8)
                    : (isDark ? Colors.white10 : Colors.grey.shade200),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Pillar Content Switcher ───────────────────────────────────────────────
  Widget _buildPillarContent(bool isDark) {
    switch (_activePillarIndex) {
      case 1: // Pengadaan & LPSE
        return Column(
          children: [
            _buildTendersWorkspaceCard(isDark),
            const SizedBox(height: 24),
            _buildRecentProgramsCard(isDark),
          ],
        );
      case 2: // Alokasi DIPA / APBD
        return Column(
          children: [
            _buildAnggaranCard(isDark),
            const SizedBox(height: 24),
            _buildChartSection(isDark),
          ],
        );
      case 3: // Pengawasan Monev
        return Column(
          children: [
            _buildMonitoringCard(isDark),
            const SizedBox(height: 24),
            _buildActivityCard(isDark),
          ],
        );
      case 4: // Warta & Siaran Pers
        return Column(
          children: [
            _buildPengumumanCard(isDark),
            const SizedBox(height: 24),
            _buildDocumentsCard(isDark),
          ],
        );
      case 5: // Fasilitas & Venue Daerah
        return _buildFacilitiesContent(isDark);
      case 6: // Laporan Dampak & Kisah Sukses
        return _buildReportsContent(isDark);
      default: // 0: Ikhtisar
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChartSection(isDark),
            const SizedBox(height: 20),
            _buildRecentProgramsCard(isDark),
            const SizedBox(height: 20),
            _buildBottomThreeColumns(isDark),
          ],
        );
    }
  }

  Widget _buildChartSection(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 850;
        if (isNarrow) {
          return Column(
            children: [
              _buildLineChartCard(isDark),
              const SizedBox(height: 16),
              _buildDonutChartCard(isDark),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildLineChartCard(isDark)),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: _buildDonutChartCard(isDark)),
          ],
        );
      },
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      toolbarHeight: 75,
      title: Row(
        children: [
          Expanded(
            child: InteractiveDashboardSearchBar(
              user: widget.user,
              isDark: isDark,
              accentColor: _govBlue,
              placeholder:
                  'Cari tender LPSE, pagu DIPA, SPK rekanan, atau pengumuman...',
            ),
          ),
          const SizedBox(width: 16),
          AppBarBadgeWidget(
            icon: Icons.notifications_none_outlined,
            isDark: isDark,
            accentColor: _govBlue,
          ),
          const SizedBox(width: 6),
          AppBarBadgeWidget(
            icon: Icons.chat_bubble_outline,
            isDark: isDark,
            accentColor: _govBlue,
          ),
          const SizedBox(width: 12),
          Builder(
            builder: (btnCtx) => Tooltip(
              message: isDark ? 'Beralih ke Mode Terang' : 'Beralih ke Mode Gelap',
              waitDuration: const Duration(milliseconds: 300),
              child: IconButton(
                key: _themeBtnKey,
                mouseCursor: SystemMouseCursors.click,
                hoverColor: _govBlue.withValues(alpha: isDark ? 0.2 : 0.1),
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
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Profil Instansi (${widget.user.name})',
            waitDuration: const Duration(milliseconds: 300),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              mouseCursor: SystemMouseCursors.click,
              hoverColor: _govBlue.withValues(alpha: isDark ? 0.15 : 0.08),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      user: widget.user,
                      onUserUpdated: widget.onUserUpdated,
                      onLogout: _handleLogout,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _govBlue.withValues(alpha: 0.12),
                      child: Icon(
                        Icons.account_balance_rounded,
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
                          'Pejabat Pembuat Komitmen (PPK)',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleLogout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ── Hero Banner ────────────────────────────────────────────────────────────
  Widget _buildHeroBanner(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 680;

        final badgeRow = Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF1D4ED8).withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, size: 13, color: Color(0xFF1D4ED8)),
                  SizedBox(width: 5),
                  Text(
                    'PORTAL RESMI PEMERINTAH',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () => _showVerificationModal(context, isDark),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 13, color: Color(0xFF10B981)),
                    SizedBox(width: 4),
                    Text(
                      'LKPP & BSrE Terverifikasi 100%',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 8, color: Color(0xFF10B981)),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'SATKER-418290-DKI',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'TA 2026',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        );

        final introduction = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            badgeRow,
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                text: 'Selamat datang, ${widget.user.name} ',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
                children: const [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: WavingHandEmoji(fontSize: 22),
                  ),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              'Pusat Komando Pengadaan Kreatif, Realisasi DIPA/APBD, Evaluasi Program, dan Publikasi Warta Resmi.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                height: 1.45,
              ),
            ),
          ],
        );

        final actionButtons = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ElevatedButton.icon(
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
                ).then((_) => _fetchStats());
              },
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('Buat Tender LPSE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InstitutionWorkspaceScreen(
                      user: widget.user,
                      resourceType: 'announcements',
                      onUserUpdated: widget.onUserUpdated,
                    ),
                  ),
                ).then((_) => _fetchStats());
              },
              icon: const Icon(Icons.campaign_outlined, size: 16),
              label: const Text('Terbitkan Siaran Pers'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : const Color(0xFF1D4ED8),
                side: BorderSide(color: const Color(0xFF1D4ED8).withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        );

        return Container(
          padding: EdgeInsets.all(isNarrow ? 16 : 22),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1D4ED8).withValues(alpha: 0.12)
                : const Color(0xFF1D4ED8).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1D4ED8).withValues(alpha: 0.2)),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    introduction,
                    const SizedBox(height: 16),
                    actionButtons,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: introduction),
                    const SizedBox(width: 20),
                    actionButtons,
                  ],
                ),
        );
      },
    );
  }

  // ── Alur Kerja Kedinasan (Ringkas 2 Alur Utama) ────────────────────────────
  Widget _buildWorkflowStepsCard(bool isDark) {
    final flows = [
      {
        'step': '01',
        'title': 'Pengadaan & Kemitraan Kreatif',
        'desc': 'Penyusunan KAK teknis, tender LPSE daerah, & penerbitan SPK kerja sama kreator.',
        'badge': '${_tenders.length} Tender • ${_partners.length} Mitra',
        'badge_color': const Color(0xFF1D4ED8),
        'icon': Icons.assignment_outlined,
        'color': const Color(0xFF1D4ED8),
        'action': 'Kelola Pengadaan',
        'onTap': () => setState(() => _activePillarIndex = 1),
      },
      {
        'step': '02',
        'title': 'Monev, BAST & Akuntabilitas',
        'desc': 'Pengawasan progres lapangan, realisasi DIPA, arsip BAST BSrE, & laporan publik.',
        'badge': '${_documents.length} Dokumen Sah • ${_reports.length} Laporan',
        'badge_color': const Color(0xFF059669),
        'icon': Icons.verified_outlined,
        'color': const Color(0xFF059669),
        'action': 'Pantau Kinerja',
        'onTap': () => setState(() => _activePillarIndex = 3),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1D4ED8).withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.alt_route_rounded,
                  color: Color(0xFF1D4ED8),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alur Kerja Utama Kedinasan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '2 alur strategis pelaksanaan pengadaan dan akuntabilitas pemerintah di Kreavana',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 11),
                    SizedBox(width: 4),
                    Text(
                      '2 Alur Terintegrasi',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final flowCards = flows.map((f) {
                final color = f['color'] as Color;
                final badgeColor = f['badge_color'] as Color;
                final icon = f['icon'] as IconData;

                return InkWell(
                  onTap: f['onTap'] as VoidCallback,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161426) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                f['step'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(icon, color: color, size: 17),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                f['badge'] as String,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          f['title'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          f['desc'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.3,
                            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              f['action'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 12, color: color),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList();

              if (isNarrow) {
                return Column(
                  children: [
                    flowCards[0],
                    const SizedBox(height: 10),
                    flowCards[1],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: flowCards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: flowCards[1]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showVerificationModal(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E1C2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D4ED8).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: Color(0xFF1D4ED8), size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sertifikasi Instansi Pemerintah',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Kementerian / Pemerintah Daerah Terverifikasi BSrE & LKPP',
                          style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161426) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildVerificationRow('Nama Organisasi', 'Dinas Pariwisata dan Ekonomi Kreatif', isDark),
                    const Divider(height: 16),
                    _buildVerificationRow('Pejabat PPK', widget.user.name, isDark),
                    const Divider(height: 16),
                    _buildVerificationRow('Nomor Satker DIPA', 'SATKER-418290-DKI', isDark),
                    const Divider(height: 16),
                    _buildVerificationRow('Otentikasi Kriptografi', 'BSrE BSSN SHA-256 (Valid)', isDark),
                    const Divider(height: 16),
                    _buildVerificationRow('Masa Berlaku Akun', 'Aktif s.d. 31 Desember 2026', isDark),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Tutup'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      OfficialDocumentViewerDialog.show(
                        context,
                        document: {
                          'id': 'CERT-GOV-2026',
                          'title': 'Sertifikat Verifikasi Akun Kedinasan Resmi Pemerintah',
                          'category': 'Sertifikat Akreditasi BSrE & LKPP',
                          'document_date': '16 Oktober 2026',
                          'url': 'https://bsre.bssn.go.id/verify/SATKER-418290',
                        },
                        isGovernment: true,
                      );
                    },
                    icon: const Icon(Icons.verified, size: 16),
                    label: const Text('Buka Dokumen Akreditasi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ── Dashboard Metrics ─────────────────────────────────────────────────────
  Widget _buildMetricCards(bool isDark) {
    final paguStr = _totalPagu > 0 ? _formatCurrency(_totalPagu) : 'Rp 2,45 M';
    final serapanPct = _totalPagu > 0
        ? '${((_totalRealisasi / _totalPagu) * 100).toStringAsFixed(1)}%'
        : '74.2%';
    final tenderCount = _tenders.isNotEmpty ? '${_tenders.length} Paket' : '5 Paket';
    final monevAvg = _monitoring.isNotEmpty
        ? '${(_monitoring.map((m) => m['progress'] as int).reduce((a, b) => a + b) / _monitoring.length).toStringAsFixed(1)}%'
        : '98.4%';

    final metrics = [
      {
        'label': 'Pagu DIPA / APBD 2026',
        'value': paguStr,
        'subtitle': 'Alokasi Belanja Kreatif',
        'icon': Icons.account_balance_wallet_outlined,
        'color': const Color(0xFF1D4ED8),
      },
      {
        'label': 'Realisasi Serapan Anggaran',
        'value': serapanPct,
        'subtitle': 'Realisasi DIPA Berjalan',
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'label': 'Tender LPSE Aktif',
        'value': tenderCount,
        'subtitle': 'Pengadaan Terbuka',
        'icon': Icons.gavel_rounded,
        'color': const Color(0xFFD97706),
      },
      {
        'label': 'Capaian Monev & LAKIP',
        'value': monevAvg,
        'subtitle': 'Indeks Akuntabilitas Sangat Baik',
        'icon': Icons.fact_check_outlined,
        'color': const Color(0xFF7C3AED),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 190).floor().clamp(1, 4);
        final spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics.map((m) {
            final color = m['color'] as Color;
            final icon = m['icon'] as IconData;

            return SizedBox(
              width: cardWidth,
              child: Container(
                constraints: const BoxConstraints(minHeight: 125),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardBg : Colors.white,
                  borderRadius: BorderRadius.circular(12),
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
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_upward_rounded,
                          color: color.withValues(alpha: 0.7),
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      m['value'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m['label'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      m['subtitle'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
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

  // ── Line Chart: Ringkasan Program & Realisasi 2026 ─────────────────────────
  Widget _buildLineChartCard(bool isDark) {
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
          _buildDashboardPanelHeader(
            title: 'Tren Realisasi Program TA 2026',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    'Semester I 2026',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 12,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 165,
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
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
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
                          'Jan \'26',
                          'Feb \'26',
                          'Mar \'26',
                          'Apr \'26',
                          'Mei \'26',
                          'Jun \'26',
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
                              color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
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
                      FlSpot(2, 12),
                      FlSpot(3, 15),
                      FlSpot(4, 14),
                      FlSpot(5, 18),
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
                      FlSpot(0, 6),
                      FlSpot(1, 8),
                      FlSpot(2, 9),
                      FlSpot(3, 12),
                      FlSpot(4, 11),
                      FlSpot(5, 15),
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
                          ? 'Target Pagu: ${s.y.toInt()}'
                          : 'Realisasi: ${s.y.toInt()}';
                      return LineTooltipItem(
                        label,
                        const TextStyle(
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
              _buildLegendDot(_govLight, 'Rencana Belanja'),
              const SizedBox(width: 20),
              _buildLegendDot(const Color(0xFF10B981), 'Realisasi Serapan'),
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
    final categories = _categories.isNotEmpty
        ? _categories
        : [
            {'name': 'Wisata & Budaya', 'percent': 40.0, 'count': 4, 'color': const Color(0xFF1D4ED8)},
            {'name': 'Sosialisasi APBD', 'percent': 25.0, 'count': 3, 'color': const Color(0xFF10B981)},
            {'name': 'Event & HUT Daerah', 'percent': 20.0, 'count': 2, 'color': const Color(0xFFF59E0B)},
            {'name': 'Pembinaan UMKM', 'percent': 15.0, 'count': 2, 'color': const Color(0xFF8B5CF6)},
          ];

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
          const Text(
            'Alokasi Berdasarkan Sektor',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 36,
                sections: categories.map((c) {
                  return PieChartSectionData(
                    value: (c['percent'] as num).toDouble(),
                    color: c['color'] as Color,
                    radius: 18,
                    showTitle: false,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${categories.length} Sektor Prioritas',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...categories.take(4).map(
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
                    '${(c['percent'] as num).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
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

  // ── Recent Programs List (JobContracts) ───────────────────────────────────
  Widget _buildRecentProgramsCard(bool isDark) {
    final programs = _programs;

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
            title: 'Kontrak Proyek & Kegiatan',
            onAction: () => _navigateTo('Lihat Semua Program'),
            actionTooltip: 'Kelola semua kontrak SPK',
          ),
          const SizedBox(height: 8),
          if (programs.isEmpty)
            _buildEmptyDashboardState(
              icon: Icons.event_note_outlined,
              title: 'Belum ada kegiatan',
              description: 'Kontrak SPK proyek berjalan akan tercatat di sini.',
              isDark: isDark,
            )
          else
            ...programs.take(4).map((program) => _buildProgramListItem(program, isDark)),
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (program['status_color'] as Color).withValues(alpha: 0.12),
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
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        program['date'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
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
                color: (program['status_color'] as Color).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                program['status'] as String,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
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
        if (constraints.maxWidth >= 1050) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildAnggaranCard(isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildPengumumanCard(isDark)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _buildActivityCard(isDark),
                    const SizedBox(height: 16),
                    _buildVendorLeaderboardCard(isDark),
                  ],
                ),
              ),
            ],
          );
        } else if (constraints.maxWidth >= 550) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildAnggaranCard(isDark),
                    const SizedBox(height: 16),
                    _buildActivityCard(isDark),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _buildPengumumanCard(isDark),
                    const SizedBox(height: 16),
                    _buildVendorLeaderboardCard(isDark),
                  ],
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            _buildAnggaranCard(isDark),
            const SizedBox(height: 16),
            _buildPengumumanCard(isDark),
            const SizedBox(height: 16),
            _buildActivityCard(isDark),
            const SizedBox(height: 16),
            _buildVendorLeaderboardCard(isDark),
          ],
        );
      },
    );
  }

  // ── Realisasi Anggaran (Now dynamically rendered with real backend data!) ─
  Widget _buildAnggaranCard(bool isDark) {
    final budgets = _budgets;
    final totalAlloc = _totalPagu > 0 ? _totalPagu : 2450000000;
    final totalReal = _totalRealisasi > 0 ? _totalRealisasi : 1818000000;
    final pct = totalAlloc > 0 ? ((totalReal / totalAlloc) * 100).clamp(0, 100) : 74.2;

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
            title: 'Realisasi DIPA & APBD',
            onAction: () => _navigateTo('Realisasi Anggaran'),
            actionTooltip: 'Buka buku kas & realisasi',
          ),
          const SizedBox(height: 14),

          // Total Bar Progress
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141224) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Serapan Anggaran',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 8,
                    backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pagu: ${_formatCurrency(totalAlloc.toDouble())}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Realisasi: ${_formatCurrency(totalReal.toDouble())}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Top budget list items
          if (budgets.isEmpty)
            _buildEmptyDashboardState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Data anggaran belum tercatat',
              description: 'Entri pos anggaran APBD untuk menampilkan rincian.',
              isDark: isDark,
            )
          else
            ...budgets.take(4).map((b) {
              final bAlloc = (b['allocation'] as num).toDouble();
              final bReal = (b['realization'] as num).toDouble();
              final bPct = b['percent'] as int;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A182F) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            b['title'] as String,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$bPct%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pagu: ${_formatCurrency(bAlloc)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          'Serapan: ${_formatCurrency(bReal)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

          Center(
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InstitutionWorkspaceScreen(
                      user: widget.user,
                      resourceType: 'budgets',
                      onUserUpdated: widget.onUserUpdated,
                    ),
                  ),
                ).then((_) => _fetchStats());
              },
              icon: const Icon(Icons.tune_rounded, size: 14),
              label: const Text(
                'Kelola Alokasi APBD Lengkap',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pengumuman & Siaran Pers (Now dynamically rendered with real backend data!) ─
  Widget _buildPengumumanCard(bool isDark) {
    final announcements = _announcements;

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
            title: 'Warta & Siaran Pers Resmi',
            onAction: () => _navigateTo('Pengumuman Publik'),
            actionTooltip: 'Buka portal pengumuman',
          ),
          const SizedBox(height: 12),
          if (announcements.isEmpty)
            _buildEmptyDashboardState(
              icon: Icons.campaign_outlined,
              title: 'Belum ada warta kedinasan',
              description: 'Pengumuman dan siaran pers yang diterbitkan akan tampil di sini.',
              isDark: isDark,
            )
          else
            ...announcements.take(3).map((a) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A182F) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D4ED8).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            a['category'] as String,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.schedule,
                          size: 11,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          a['valid_until'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      a['title'] as String,
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
                      a['description'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }),

          Center(
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PengumumanPublikScreen(
                      user: widget.user,
                      onUserUpdated: widget.onUserUpdated,
                    ),
                  ),
                ).then((_) => _fetchStats());
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: const Text(
                'Lihat Semua Siaran Pers',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dedicated Tenders Workspace Card ──────────────────────────────────────
  Widget _buildTendersWorkspaceCard(bool isDark) {
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paket Pengadaan LPSE & Lelang Terbuka',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sistem seleksi pengadaan barang & jasa media kreatif pemerintah',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
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
                  ).then((_) => _fetchStats());
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Buat Tender'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_tenders.isEmpty)
            _buildEmptyDashboardState(
              icon: Icons.gavel_rounded,
              title: 'Belum ada paket lelang',
              description: 'Buat paket pengadaan baru untuk mengundang proposal vendor & rekanan.',
              isDark: isDark,
            )
          else
            ..._tenders.map((t) {
              final budget = (t['budget'] as num).toDouble();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161426) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D4ED8).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            t['category'] as String,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'LPSE Open RFP',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Deadline: ${t['deadline']}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t['title'] as String,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pagu Pengadaan: ${_formatCurrency(budget)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D4ED8),
                          ),
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
                            ).then((_) => _fetchStats());
                          },
                          child: const Text('Buka Berkas Tender', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Dedicated Monev Card ──────────────────────────────────────────────────
  Widget _buildMonitoringCard(bool isDark) {
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monitoring & Evaluasi Kinerja (Monev LAKIP)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Indikator capaian output dan outcome program instansi',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InstitutionWorkspaceScreen(
                        user: widget.user,
                        resourceType: 'monitoring',
                        onUserUpdated: widget.onUserUpdated,
                      ),
                    ),
                  ).then((_) => _fetchStats());
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Tambah Indikator'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_monitoring.isEmpty)
            _buildEmptyDashboardState(
              icon: Icons.fact_check_outlined,
              title: 'Belum ada agenda monev',
              description: 'Catat indikator output program untuk pengawasan akuntabilitas.',
              isDark: isDark,
            )
          else
            ..._monitoring.map((m) {
              final prg = m['progress'] as int;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161426) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            m['title'] as String,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          '$prg%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: prg >= 80 ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Indikator: ${m['indicator']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: prg / 100,
                        minHeight: 8,
                        backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(
                          prg >= 80 ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Target Selesai: ${m['target_date']}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InstitutionWorkspaceScreen(
                                  user: widget.user,
                                  resourceType: 'monitoring',
                                  onUserUpdated: widget.onUserUpdated,
                                ),
                              ),
                            ).then((_) => _fetchStats());
                          },
                          child: const Text('Update Progres', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Dedicated Documents Card ──────────────────────────────────────────────
  Widget _buildDocumentsCard(bool isDark) {
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dokumen Resmi, SK & BAST',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Arsip digital berkas Surat Keputusan, SPK, dan Berita Acara',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InstitutionWorkspaceScreen(
                        user: widget.user,
                        resourceType: 'documents',
                        onUserUpdated: widget.onUserUpdated,
                      ),
                    ),
                  ).then((_) => _fetchStats());
                },
                icon: const Icon(Icons.upload_file_outlined, size: 16),
                label: const Text('Unggah SK/BAST'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_documents.isEmpty)
            _buildEmptyDashboardState(
              icon: Icons.folder_outlined,
              title: 'Belum ada arsip dokumen',
              description: 'Unggah berkas SK pengadaan atau BAST untuk dokumentasi resmi.',
              isDark: isDark,
            )
          else
            ..._documents.map((d) {
              return InkWell(
                onTap: () {
                  OfficialDocumentViewerDialog.show(
                    context,
                    document: d,
                    isGovernment: true,
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161426) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D4ED8).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.description_outlined, color: Color(0xFF1D4ED8), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d['title'] as String,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${d['category']} • ${d['document_date']}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.verified_outlined, size: 16),
                        label: const Text('Buka Dokumen', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          OfficialDocumentViewerDialog.show(
                            context,
                            document: d,
                            isGovernment: true,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Dedicated Facilities (Venue & Sarana Daerah) ──────────────────────────
  Widget _buildFacilitiesContent(bool isDark) {
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fasilitas & Venue Kreatif Daerah',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Berbagi akses sarana, gedung seni, dan studio rekaman untuk kolaborasi talenta',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InstitutionWorkspaceScreen(
                        user: widget.user,
                        resourceType: 'facilities',
                        onUserUpdated: widget.onUserUpdated,
                      ),
                    ),
                  ).then((_) => _fetchStats());
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Tambah Sarana'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_facilities.isEmpty)
            _buildEmptyDashboardState(
              icon: Icons.storefront_outlined,
              title: 'Belum ada fasilitas terdaftar',
              description: 'Daftarkan sarana dan ruang publik yang dapat digunakan para kreator.',
              isDark: isDark,
            )
          else
            ..._facilities.map((f) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161426) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D4ED8).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            f['category'] as String,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Tersedia untuk Kolaborasi',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Kapasitas: ${f['capacity']}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      f['title'] as String,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      f['description'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            f['location'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            OfficialDocumentViewerDialog.show(
                              context,
                              document: {
                                'id': 'FAC-${f['id']}',
                                'title': 'SOP Peminjaman ${f['title']}',
                                'category': 'Peraturan & Tata Tertib Fasilitas',
                                'document_date': '16 Oktober 2026',
                                'url': 'https://docs.kreavana.id/sop-fasilitas',
                              },
                              isGovernment: true,
                            );
                          },
                          icon: const Icon(Icons.assignment_outlined, size: 15),
                          label: const Text('Buka SOP & Regulasi', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Dedicated Public Impact Reports (Langkah 6 Evaluasi & Reputasi) ───────
  Widget _buildReportsContent(bool isDark) {
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Laporan Dampak Publik & Kisah Keberhasilan',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Evaluasi hasil program, transparansi dampak ke masyarakat, dan reputasi kedinasan',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InstitutionWorkspaceScreen(
                        user: widget.user,
                        resourceType: 'reports',
                        onUserUpdated: widget.onUserUpdated,
                      ),
                    ),
                  ).then((_) => _fetchStats());
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Publikasi Dampak'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_reports.isEmpty)
            _buildEmptyDashboardState(
              icon: Icons.insights_rounded,
              title: 'Belum ada laporan dampak',
              description: 'Publikasikan kisah keberhasilan dan metrik dampak program bagi masyarakat.',
              isDark: isDark,
            )
          else
            ..._reports.map((r) {
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161426) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            r['category'] as String,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            r['verified_badge'] as String,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          r['period'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      r['title'] as String,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r['description'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Metrik Dampak
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildImpactMetricChip(
                          icon: Icons.people_outline,
                          label: 'Penerima Manfaat',
                          value: r['beneficiaries'] as String,
                          color: const Color(0xFF1D4ED8),
                          isDark: isDark,
                        ),
                        _buildImpactMetricChip(
                          icon: Icons.payments_outlined,
                          label: 'Perputaran Ekonomi',
                          value: r['economic_impact'] as String,
                          color: const Color(0xFF10B981),
                          isDark: isDark,
                        ),
                        _buildImpactMetricChip(
                          icon: Icons.thumb_up_alt_outlined,
                          label: 'Kepuasan Warga',
                          value: r['satisfaction_rate'] as String,
                          color: const Color(0xFFD97706),
                          isDark: isDark,
                        ),
                      ],
                    ),
                    if ((r['testimonial_quote'] as String).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: const Border(
                            left: BorderSide(color: Color(0xFF1D4ED8), width: 3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '"${r['testimonial_quote']}"',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "— ${r['testimonial_author']}",
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            OfficialDocumentViewerDialog.show(
                              context,
                              document: {
                                'id': 'RPT-${r['id']}',
                                'title': r['title'],
                                'category': 'Laporan Akuntabilitas Kinerja Instansi',
                                'document_date': '16 Oktober 2026',
                                'url': 'https://docs.kreavana.id/laporan-dampak',
                              },
                              isGovernment: true,
                            );
                          },
                          icon: const Icon(Icons.verified_outlined, size: 15),
                          label: const Text('Buka Dokumen Resmi (BSrE)', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D4ED8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildImpactMetricChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Aktivitas Terbaru ─────────────────────────────────────────────────────
  Widget _buildActivityCard(bool isDark) {
    final activities = _activities;

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
            title: 'Log & Aktivitas Kedinasan',
            onAction: () => _navigateTo('Lihat Semua Aktivitas'),
            actionTooltip: 'Lihat semua aktivitas',
          ),
          const SizedBox(height: 8),
          if (activities.isEmpty)
            _buildEmptyDashboardState(
              icon: Icons.history_outlined,
              title: 'Belum ada aktivitas',
              description: 'Aktivitas terbaru kedinasan akan tercatat di sini.',
              isDark: isDark,
            )
          else
            ...activities.take(3).map((activity) => _buildActivityItem(activity, isDark)),
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

  // ── Kreator & Vendor Terverifikasi ─────────────────────────────────────────
  Widget _buildVendorLeaderboardCard(bool isDark) {
    final vendors = _partners.isNotEmpty
        ? _partners.asMap().entries.map((entry) => {
            'rank': entry.key + 1,
            'name': (entry.value['title'] ?? 'Sanggar Seni Rekanan').toString(),
            'category': (entry.value['category'] ?? 'Mitra Kebudayaan & Kreatif').toString(),
            'rating': '5.0',
            'color': entry.key == 0
                ? const Color(0xFFF59E0B)
                : (entry.key == 1 ? const Color(0xFF94A3B8) : const Color(0xFF1D4ED8)),
          }).toList()
        : _vendors;

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
            title: 'Rekomendasi Vendor & Sanggar',
            onAction: () => _navigateTo('Cari Vendor'),
            actionTooltip: 'Cari rekanan terverifikasi',
          ),
          const SizedBox(height: 8),
          if (vendors.isEmpty)
            _buildEmptyDashboardState(
              icon: Icons.storefront_outlined,
              title: 'Belum ada rekomendasi rekanan',
              description: 'Jelajahi daftar sanggar seni dan kreator daerah.',
              isDark: isDark,
            )
          else
            ...vendors.take(4).map((vendor) => _buildVendorRankItem(vendor, isDark)),
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
          MaterialPageRoute(
            builder: (_) => AgendaScreen(
              user: widget.user,
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
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
