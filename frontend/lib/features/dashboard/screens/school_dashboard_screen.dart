import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../app/app_animations.dart';
import '../../../services/api_service.dart';
import '../../../services/job_contract_service.dart';
import '../../../models/job_contract.dart';
import '../../../models/user_model.dart';
import '../../../screens/profile_screen.dart';
import '../../../screens/direct_message_screen.dart';
import '../../../screens/proyek_saya_screen.dart';
import '../../../screens/agenda_screen.dart';
import '../../../screens/marketplace_karya_screen.dart';
import '../../../screens/buat_kebutuhan_screen.dart';
import '../../../services/opportunity_service.dart';
import '../../../models/opportunity_model.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../../widgets/app_bar_badge.dart';
import '../../../widgets/app_sweet_alert.dart';
import '../../../widgets/program_magang_card.dart';
import '../../../services/school_pdf_service.dart';

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

class _SchoolDashboardScreenState extends State<SchoolDashboardScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _themeBtnKey = GlobalKey();

  // ── ATURAN WARNA: CUKUP 1 WARNA UTAMA SOLID (TANPA GRADIENT) ───────────────
  static const Color _schoolColor = Color(0xFF4338CA); // Royal Academic Indigo

  late TabController _tabController;
  int _activeTabIndex = 0;
  int _currentWorkflowStep = 4; // Tahap 5: Kolaborasi & Implementasi

  bool _isLoading = true;
  List<Map<String, dynamic>> _resources = [];
  List<Map<String, dynamic>> _recentProjects = [];
  List<Map<String, dynamic>> _upcomingAgenda = [];

  // Filter states
  String _eventFilter = 'Semua';
  String _oppFilter = 'Semua';
  String _talentFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _activeTabIndex) {
        setState(() => _activeTabIndex = _tabController.index);
      }
    });
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        ApiService.get('institution/resources'),
        JobContractService.getUserContracts().catchError((_) => <JobContract>[]),
        OpportunityService.getOpportunities(limit: 50).catchError((_) => <OpportunityModel>[]),
      ]);

      if (!mounted) return;

      final resResources = results[0] as Map<String, dynamic>;
      final contracts = results[1] as List<JobContract>;
      final myOpportunities = results[2] as List<OpportunityModel>;

      // 1. Process Institution Resources
      final List<Map<String, dynamic>> loadedResources = [];
      if (resResources['status'] == true && resResources['data'] is List) {
        for (final item in resResources['data']) {
          if (item is Map) {
            loadedResources.add(Map<String, dynamic>.from(item));
          }
        }
      }

      // 2. Map Opportunities from Database into resources & tenders
      for (final opp in myOpportunities) {
        final startStr = opp.eventStartDate ?? opp.eventDate ?? opp.deadline ?? opp.createdAt;
        final DateTime start = startStr != null ? (DateTime.tryParse(startStr) ?? DateTime.now()) : DateTime.now();
        final dateStr = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
        final isEvent = opp.type == 'event' ||
            opp.title.toLowerCase().contains('event') ||
            opp.title.toLowerCase().contains('lomba') ||
            opp.title.toLowerCase().contains('showcase') ||
            opp.title.toLowerCase().contains('expo') ||
            opp.title.toLowerCase().contains('hackathon');

        final locName = (opp.location != null && opp.location!.isNotEmpty)
            ? opp.location!
            : (opp.address != null && opp.address!.isNotEmpty ? opp.address! : (widget.user.location ?? 'Lokasi Kampus'));

        if (isEvent) {
          loadedResources.add({
            'id': 'opp_${opp.id}',
            'resource_type': 'events',
            'title': opp.title,
            'description': opp.description ?? 'Kegiatan resmi kampus & industri.',
            'status': opp.status,
            'metadata': {
              'category': (opp.title.toLowerCase().contains('lomba') || opp.title.toLowerCase().contains('hackathon'))
                  ? 'Kompetisi & Lomba'
                  : 'Pameran & Expo',
              'event_date': dateStr,
              'location': locName,
              'registered_participants': opp.applicationsCount,
              'is_competition': opp.title.toLowerCase().contains('lomba') || opp.title.toLowerCase().contains('hackathon'),
            },
          });
        }

        int calculatedQuota = 0;
        for (final r in opp.requirements) {
          if (r.subRoleSlug != 'kualifikasi' && r.quantity > 0) {
            calculatedQuota += r.quantity;
          }
        }
        final quotaText = calculatedQuota > 0 ? '$calculatedQuota Mahasiswa' : '10 Mahasiswa';

        final isMagang = opp.subRoleSlug.toLowerCase().contains('magang') ||
            opp.title.toLowerCase().contains('magang') ||
            opp.title.toLowerCase().contains('pkl') ||
            opp.title.toLowerCase().contains('mbkm') ||
            (opp.description != null && opp.description!.toLowerCase().contains('magang'));

        // Also map to tenders / program magang
        loadedResources.add({
          'id': 'opp_tender_${opp.id}',
          'resource_type': 'tenders',
          'title': opp.title,
          'description': opp.description ?? 'Program kemitraan magang & proyek siswa.',
          'status': opp.status,
          'metadata': {
            'category': isMagang ? 'Program Magang / PKL' : 'Proyek Industri',
            'industry_partner': opp.poster?.name ?? 'Mitra Industri Kreavana',
            'quota': quotaText,
            'allowance': opp.budgetRange ?? 'Sesuai Ketentuan MBKM',
            'duration': '3 - 6 Bulan',
            'applicants_count': opp.applicationsCount,
          },
        });
      }

      // 3. Process Projects from tenders & contracts
      final List<Map<String, dynamic>> loadedProjects = [];
      final tenders = loadedResources.where((r) => r['resource_type'] == 'tenders').toList();
      for (final t in tenders.take(4)) {
        loadedProjects.add({
          'id': t['id']?.toString() ?? '',
          'title': t['title']?.toString() ?? 'Program Magang',
          'type': t['description']?.toString() ?? 'Program Kolaborasi Industri',
          'status': (t['status'] == 'open' || t['status'] == 'published') ? 'Aktif' : 'Berjalan',
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

      // 4. Process Agenda / Deadlines
      final List<Map<String, dynamic>> loadedAgenda = [];
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      for (final c in contracts) {
        if (c.deadline != null || c.scheduledStartDate != null) {
          final start = c.scheduledStartDate ?? c.deadline!;
          final end = c.scheduledEndDate ?? c.deadline ?? start;
          final isSameDay = start.year == end.year && start.month == end.month && start.day == end.day;
          final rangeStr = isSameDay
              ? '${start.day.toString().padLeft(2, '0')} ${months[start.month - 1].toUpperCase()} ${start.year}'
              : '${start.day.toString().padLeft(2, '0')} - ${end.day.toString().padLeft(2, '0')} ${months[start.month - 1].toUpperCase()} ${start.year}';
          final isDeadline = c.deadline != null && c.scheduledStartDate == null;
          loadedAgenda.add({
            'date': rangeStr,
            'title': c.title,
            'time': isDeadline ? 'Tenggat: 23:59 WIB' : '09:00 - 15:00 WIB',
          });
        }
      }

      setState(() {
        _resources = loadedResources;
        _recentProjects = loadedProjects;
        _upcomingAgenda = loadedAgenda;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _resources = [];
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic>? get _profileResource {
    for (final r in _resources) {
      if (r['resource_type'] == 'profile') return r;
    }
    return null;
  }

  // ── GETTERS DATA PER RESOURCE TYPE ─────────────────────────────────────────
  List<Map<String, dynamic>> get _studyPrograms =>
      _resources.where((r) => r['resource_type'] == 'study_programs').toList();

  List<Map<String, dynamic>> get _events =>
      _resources.where((r) => r['resource_type'] == 'events').toList();

  List<Map<String, dynamic>> get _opportunities =>
      _resources.where((r) => r['resource_type'] == 'tenders').toList();

  List<Map<String, dynamic>> get _partners =>
      _resources.where((r) => r['resource_type'] == 'partners').toList();

  List<Map<String, dynamic>> get _talents =>
      _resources.where((r) => r['resource_type'] == 'talents').toList();

  List<Map<String, dynamic>> get _reports =>
      _resources.where((r) => r['resource_type'] == 'reports').toList();

  List<Map<String, dynamic>> get _documents =>
      _resources.where((r) => r['resource_type'] == 'documents').toList();

  List<Map<String, dynamic>> get _showcases =>
      _resources.where((r) => r['resource_type'] == 'showcases').toList();

  int get _tendersCount => _opportunities.length;
  int get _partnersCount => _partners.length;
  int get _showcasesCount => _showcases.length;
  int get _programsCount => _studyPrograms.length;
  int get _talentsCount => _talents.length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: _buildAppBar(isDark),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _schoolColor),
            )
          : RefreshIndicator(
              color: _schoolColor,
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
                    // 1. Header Banner & Identitas Role Sekolah (Solid Color, Tanpa Gradient)
                    _buildHeroBanner(isDark),
                    const SizedBox(height: 20),

                    // 2. Alur Kerja Role Sekolah (6 Tahap)
                    _buildWorkflowStepper(isDark),
                    const SizedBox(height: 24),

                    // 3. Tab Bar Navigation untuk 6 Fitur Utama
                    _buildFeatureTabBar(isDark),
                    const SizedBox(height: 20),

                    // 4. Dynamic Content Berdasarkan Tab Aktif
                    _buildActiveTabContent(isDark),
                  ],
                ),
              ),
            ),
    );
  }

  // ── APP BAR FORMAL SOLID ───────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      toolbarHeight: 72,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          height: 1,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: InteractiveDashboardSearchBar(
              user: widget.user,
              isDark: isDark,
              accentColor: _schoolColor,
              placeholder: 'Cari program studi, mitra industri, magang, atau talenta...',
            ),
          ),
          const SizedBox(width: 14),
          AppBarBadgeWidget(
            icon: Icons.notifications_none_outlined,
            isDark: isDark,
            accentColor: _schoolColor,
          ),
          const SizedBox(width: 8),
          AppBarThemeToggle(
            isDark: isDark,
            btnKey: _themeBtnKey,
            accentColor: _schoolColor,
          ),
          const SizedBox(width: 8),
          AppBarProfileBadge(
            user: widget.user,
            isDark: isDark,
            accentColor: _schoolColor,
            customSubRole: 'Role Sekolah / Kampus',
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
          ),
        ],
      ),
    );
  }

  // ── HERO BANNER RESMI SOLID (TANPA GRADIENT) ───────────────────────────────
  Widget _buildHeroBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _schoolColor, // CUKUP 1 WARNA SOLID
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3730A3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 700;

          final textContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Instansi Pendidikan Terverifikasi',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'Akreditasi A / Unggul (BAN-PT)',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Role Sekolah / Perguruan Tinggi',
                style: TextStyle(
                  fontSize: isCompact ? 20 : 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Menghubungkan Talenta, Ilmu Pengetahuan dan Peluang untuk Masa Depan yang Lebih Baik',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE0E7FF),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kreavana membantu sekolah dan perguruan tinggi membangun jejaring, menemukan peluang kolaborasi, serta mengembangkan potensi mahasiswa, pendidik, dan institusi.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFC7D2FE),
                  height: 1.4,
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              HoverLiftButton(
                borderRadius: BorderRadius.circular(10),
                glowColor: Colors.white,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BuatKebutuhanScreen(user: widget.user),
                      ),
                    ).then((_) => _loadDashboardData());
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('Buka Program / Magang'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _schoolColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
              HoverLiftButton(
                borderRadius: BorderRadius.circular(10),
                glowColor: Colors.white,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AgendaScreen(user: widget.user),
                      ),
                    ).then((_) => _loadDashboardData());
                  },
                  icon: const Icon(Icons.event_available_outlined, size: 16, color: Colors.white),
                  label: const Text('Buat Event / Lomba', style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                textContent,
                const SizedBox(height: 18),
                actions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: textContent),
              const SizedBox(width: 24),
              actions,
            ],
          );
        },
      ),
    );
  }

  // ── ALUR KERJA ROLE SEKOLAH (6 TAHAPAN SESUAI DIAGRAM) ─────────────────────
  Widget _buildWorkflowStepper(bool isDark) {
    final stages = [
      {
        'step': 1,
        'title': 'Registrasi Institusi',
        'desc': 'Data institusi, program studi, kontak, & verifikasi admin',
        'status': 'Selesai',
        'icon': Icons.app_registration_rounded,
      },
      {
        'step': 2,
        'title': 'Verifikasi & Aktivasi',
        'desc': 'Validasi data resmi dan legalitas akreditasi BAN-PT',
        'status': 'Terverifikasi',
        'icon': Icons.verified_user_rounded,
      },
      {
        'step': 3,
        'title': 'Lengkapi Profil',
        'desc': 'Program studi, keunggulan riset, dan kebutuhan kemitraan',
        'status': 'Lengkap',
        'icon': Icons.account_balance_rounded,
      },
      {
        'step': 4,
        'title': 'Akses Peluang',
        'desc': 'Magang PKL/MBKM, proyek, event kolaborasi, & program khusus',
        'status': 'Aktif',
        'icon': Icons.manage_search_rounded,
      },
      {
        'step': 5,
        'title': 'Kolaborasi & Implementasi',
        'desc': 'Terhubung dengan industri, mitra DUDI, vendor, dan komunitas',
        'status': 'Berjalan',
        'icon': Icons.handshake_rounded,
      },
      {
        'step': 6,
        'title': 'Evaluasi & Pengembangan',
        'desc': 'Laporan akuntabilitas, portofolio, reputasi, dan peluang lanjutan',
        'status': 'Siap Lapor',
        'icon': Icons.insights_rounded,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.alt_route_rounded, color: _schoolColor, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Alur Kerja Role Sekolah / Perguruan Tinggi',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _schoolColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _schoolColor.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  'Tahap 5: Kolaborasi Aktif',
                  style: TextStyle(
                    fontSize: 11,
                    color: _schoolColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Proses alur kerja resmi ekosistem Kreavana untuk memastikan tata kelola kemitraan akademik yang kredibel dan berdampak.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: stages.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final s = entry.value;
                    return Expanded(
                      child: InkWell(
                        onTap: () => _showWorkflowStageDetail(s),
                        borderRadius: BorderRadius.circular(10),
                        child: _buildStageItem(s, idx, isDark),
                      ),
                    );
                  }).toList(),
                );
              }

              return Column(
                children: stages.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final s = entry.value;
                  return InkWell(
                    onTap: () => _showWorkflowStageDetail(s),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildStageItem(s, idx, isDark, isHorizontal: true),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStageItem(Map<String, dynamic> stage, int index, bool isDark, {bool isHorizontal = false}) {
    final isCurrent = index == _currentWorkflowStep;
    final isDone = index < _currentWorkflowStep;

    if (isHorizontal) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrent
              ? _schoolColor.withValues(alpha: 0.08)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCurrent ? _schoolColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: isCurrent ? _schoolColor : (isDone ? _schoolColor.withValues(alpha: 0.2) : Colors.grey.shade300),
              child: isDone
                  ? const Icon(Icons.check, size: 14, color: _schoolColor)
                  : Text(
                      '${stage['step']}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCurrent ? Colors.white : Colors.black87,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stage['title'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isCurrent ? _schoolColor : null,
                    ),
                  ),
                  Text(
                    stage['desc'] as String,
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isCurrent ? _schoolColor : (isDone ? _schoolColor.withValues(alpha: 0.1) : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                stage['status'] as String,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isCurrent ? Colors.white : (isDone ? _schoolColor : Colors.grey.shade700),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent
            ? _schoolColor.withValues(alpha: 0.08)
            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? _schoolColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: isCurrent ? _schoolColor : (isDone ? _schoolColor.withValues(alpha: 0.2) : Colors.grey.shade300),
                child: isDone
                    ? const Icon(Icons.check, size: 12, color: _schoolColor)
                    : Text(
                        '${stage['step']}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? Colors.white : Colors.black87,
                        ),
                      ),
              ),
              Text(
                stage['status'] as String,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: isCurrent ? _schoolColor : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            stage['title'] as String,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isCurrent ? _schoolColor : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            stage['desc'] as String,
            style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── FEATURE TAB BAR (SOLID INDIGO NAVIGATION) ──────────────────────────────
  Widget _buildFeatureTabBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          if (_activeTabIndex != index) {
            setState(() => _activeTabIndex = index);
          }
        },
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: _schoolColor, // CUKUP 1 WARNA SOLID
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
        tabs: const [
          Tab(icon: Icon(Icons.dashboard_outlined, size: 16), text: 'Dashboard & KPI'),
          Tab(icon: Icon(Icons.school_outlined, size: 16), text: 'Profil & Program Studi'),
          Tab(icon: Icon(Icons.event_outlined, size: 16), text: 'Kegiatan, Event & Lomba'),
          Tab(icon: Icon(Icons.work_outline, size: 16), text: 'Peluang Magang & Riset'),
          Tab(icon: Icon(Icons.diversity_3_outlined, size: 16), text: 'Direktori Mitra Industri'),
          Tab(icon: Icon(Icons.person_search_outlined, size: 16), text: 'Penelusuran Talenta'),
          Tab(icon: Icon(Icons.assessment_outlined, size: 16), text: 'Analitik & Evaluasi Mutu'),
        ],
      ),
    );
  }

  // ── ROUTER TAB KONTEN DINAMIS ──────────────────────────────────────────────
  Widget _buildActiveTabContent(bool isDark) {
    switch (_activeTabIndex) {
      case 0:
        return _buildTabOverview(isDark);
      case 1:
        return _buildTabStudyPrograms(isDark);
      case 2:
        return _buildTabEvents(isDark);
      case 3:
        return _buildTabOpportunities(isDark);
      case 4:
        return _buildTabPartners(isDark);
      case 5:
        return _buildTabTalents(isDark);
      case 6:
        return _buildTabAnalytics(isDark);
      default:
        return _buildTabOverview(isDark);
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // TAB 0: DASHBOARD & KPI EKSEKUTIF
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildTabOverview(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMetricCards(isDark),
        const SizedBox(height: 24),
        _buildTopColumns(isDark),
        const SizedBox(height: 24),
        _buildBottomColumns(isDark),
      ],
    );
  }

  Widget _buildMetricCards(bool isDark) {
    final metrics = [
      {
        'label': 'Peluang Magang & Riset',
        'value': '$_tendersCount Program',
        'sub': 'Terbuka untuk siswa & dosen',
        'icon': Icons.work_outline_rounded,
        'onTap': () => _tabController.animateTo(3),
      },
      {
        'label': 'Mitra Industri Aktif',
        'value': '$_partnersCount Industri',
        'sub': 'Kerjasama MoU Aktif',
        'icon': Icons.diversity_3_rounded,
        'onTap': () => _tabController.animateTo(4),
      },
      {
        'label': 'Talenta & Portofolio',
        'value': '$_talentsCount Talenta',
        'sub': '$_showcasesCount karya portofolio siap industri',
        'icon': Icons.palette_rounded,
        'onTap': () => _tabController.animateTo(5),
      },
      {
        'label': 'Program Studi Terakreditasi',
        'value': '$_programsCount Prodi',
        'sub': 'Predikat Unggul & A BAN-PT',
        'icon': Icons.school_rounded,
        'onTap': () => _tabController.animateTo(1),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 850;

        Widget card(Map<String, dynamic> m) {
          return InkWell(
            onTap: m['onTap'] as VoidCallback?,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _schoolColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(m['icon'] as IconData, color: _schoolColor, size: 18),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    m['label'] as String,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m['value'] as String,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m['sub'] as String,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (isWide) {
          return Row(
            children: metrics.map((m) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: card(m),
                ),
              );
            }).toList(),
          );
        }

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: metrics.map((m) {
            return SizedBox(
              width: (constraints.maxWidth - 10) / 2,
              child: card(m),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTopColumns(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 750) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _buildLineChartCard(isDark)),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: _buildDonutChartCard(isDark)),
        ],
      );
    }
    return Column(
      children: [
        _buildLineChartCard(isDark),
        const SizedBox(height: 16),
        _buildDonutChartCard(isDark),
      ],
    );
  }

  Widget _buildLineChartCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tren Penyerapan Magang & Kemitraan',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _schoolColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'TA 2025/2026',
                  style: TextStyle(fontSize: 10, color: _schoolColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
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
                        final labels = ['Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
                        final idx = v.toInt();
                        if (idx >= 0 && idx < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
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
                    spots: const [
                      FlSpot(0, 42),
                      FlSpot(1, 58),
                      FlSpot(2, 75),
                      FlSpot(3, 84),
                      FlSpot(4, 91),
                      FlSpot(5, 96),
                    ],
                    isCurved: true,
                    color: _schoolColor, // SOLID COLOR
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: _schoolColor.withValues(alpha: 0.08), // FLAT SOLID TINT
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribusi Sumber Daya Sekolah',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 36,
                sections: [
                  PieChartSectionData(
                    value: _opportunities.length.toDouble().clamp(1, 100),
                    color: _schoolColor,
                    radius: 16,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: _partners.length.toDouble().clamp(1, 100),
                    color: _schoolColor.withValues(alpha: 0.75),
                    radius: 16,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: _talents.length.toDouble().clamp(1, 100),
                    color: _schoolColor.withValues(alpha: 0.5),
                    radius: 16,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: _studyPrograms.length.toDouble().clamp(1, 100),
                    color: _schoolColor.withValues(alpha: 0.25),
                    radius: 16,
                    showTitle: false,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildCatRow('Peluang Magang & Riset', '${_opportunities.length} data', _schoolColor),
          _buildCatRow('Mitra Industri & Vendor', '${_partners.length} industri', _schoolColor.withValues(alpha: 0.75)),
          _buildCatRow('Talenta & Portofolio', '${_talents.length} profil', _schoolColor.withValues(alpha: 0.5)),
          _buildCatRow('Program Studi Unggulan', '${_studyPrograms.length} prodi', _schoolColor.withValues(alpha: 0.25)),
        ],
      ),
    );
  }

  Widget _buildCatRow(String name, String val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 11))),
          Text(val, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBottomColumns(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 750) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildRecentProjectsCard(isDark)),
          const SizedBox(width: 16),
          Expanded(child: _buildAgendaCard(isDark)),
        ],
      );
    }
    return Column(
      children: [
        _buildRecentProjectsCard(isDark),
        const SizedBox(height: 16),
        _buildAgendaCard(isDark),
      ],
    );
  }

  Widget _buildRecentProjectsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Program & Kolaborasi Berjalan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProyekSayaScreen(user: widget.user),
                    ),
                  );
                },
                child: const Text('Buka Halaman Proyek', style: TextStyle(fontSize: 11, color: _schoolColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_recentProjects.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('Belum ada program berjalan', style: TextStyle(fontSize: 12, color: Colors.grey))),
            )
          else
            ..._recentProjects.take(4).map((p) {
              final title = p['title']?.toString() ?? 'Program Kolaborasi';
              final desc = p['type']?.toString() ?? 'Deskripsi';
              final status = p['status']?.toString() ?? 'Berjalan';

              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProyekSayaScreen(user: widget.user),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _schoolColor.withValues(alpha: 0.1),
                        child: const Icon(Icons.school, color: _schoolColor, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(desc, style: const TextStyle(fontSize: 10.5, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _schoolColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(fontSize: 10, color: _schoolColor, fontWeight: FontWeight.bold),
                        ),
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

  Widget _buildAgendaCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Agenda & Tenggat Kemitraan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_upcomingAgenda.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('Tidak ada agenda mendesak', style: TextStyle(fontSize: 12, color: Colors.grey))),
            )
          else
            ..._upcomingAgenda.take(3).map((a) {
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AgendaScreen(user: widget.user),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _schoolColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          a['date'] ?? 'TBA',
                          style: const TextStyle(color: _schoolColor, fontWeight: FontWeight.bold, fontSize: 10.5),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a['title'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(a['time'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
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

  // ═════════════════════════════════════════════════════════════════════════════
  // TAB 1: FITUR 1 - PROFIL INSTITUSI & PROGRAM STUDI
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildTabStudyPrograms(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profil Institusi Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _schoolColor.withValues(alpha: 0.1),
                        child: const Icon(Icons.school, color: _schoolColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profileResource?['title']?.toString().isNotEmpty == true
                                ? _profileResource!['title'].toString()
                                : widget.user.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            () {
                              final meta = _profileResource?['metadata'] as Map<String, dynamic>? ?? {};
                              final npsn = meta['npsn']?.toString();
                              final permit = meta['permit_number']?.toString();
                              final city = meta['city']?.toString() ?? widget.user.location;
                              final parts = [
                                if (npsn != null && npsn.isNotEmpty) 'NPSN: $npsn',
                                if (permit != null && permit.isNotEmpty) 'SK: $permit',
                                if (city != null && city.isNotEmpty) city,
                              ];
                              return parts.isNotEmpty
                                  ? parts.join(' • ')
                                  : ((widget.user.subRole != null && widget.user.subRole!.isNotEmpty)
                                      ? widget.user.subRole!
                                      : 'Institusi Pendidikan');
                            }(),
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddStudyProgramDialog(),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Tambah Program Studi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _schoolColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 8),
              () {
                final pMeta = _profileResource?['metadata'] as Map<String, dynamic>? ?? {};
                final acc = pMeta['accreditation']?.toString();
                final email = pMeta['official_email']?.toString() ?? widget.user.email;
                final phone = pMeta['official_phone']?.toString() ?? widget.user.phone;
                final npsn = pMeta['npsn']?.toString();

                final pills = [
                  if (acc != null && acc.isNotEmpty) _buildProfilePill(Icons.verified, 'Akreditasi: $acc'),
                  if (npsn != null && npsn.isNotEmpty) _buildProfilePill(Icons.badge, 'NPSN: $npsn'),
                  if (email.isNotEmpty) _buildProfilePill(Icons.email, email),
                  if (phone != null && phone.isNotEmpty) _buildProfilePill(Icons.phone, phone),
                ];

                if (pills.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: pills,
                );
              }(),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Daftar Program Studi
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Daftar Program Studi & Vokasi (${_studyPrograms.length})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Berbasis Kurikulum Industri & MBKM',
              style: TextStyle(fontSize: 11, color: _schoolColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_studyPrograms.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.school_outlined, size: 36, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'Belum ada data program studi dari database',
                    style: TextStyle(fontSize: 12.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          )
        else
          ..._studyPrograms.map((prodi) {
            final meta = prodi['metadata'] as Map<String, dynamic>? ?? {};
            final degree = meta['degree']?.toString() ?? '-';
            final acc = meta['accreditation']?.toString() ?? '-';
            final students = meta['total_students']?.toString() ?? '-';
            final rate = meta['employment_rate']?.toString() ?? '-';
            final skills = (meta['featured_skills'] as List?)?.join(', ') ?? '-';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _schoolColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.school, color: _schoolColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                prodi['title'] ?? 'Program Studi',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _schoolColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Akreditasi $acc',
                                style: const TextStyle(color: _schoolColor, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          prodi['description'] ?? '',
                          style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 14,
                          runSpacing: 4,
                          children: [
                            _buildSmallInfo(Icons.school, degree),
                            _buildSmallInfo(Icons.groups, '$students Mahasiswa Aktif'),
                            _buildSmallInfo(Icons.trending_up, 'Serapan Kerja: $rate'),
                            _buildSmallInfo(Icons.stars, 'Skill: $skills'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => _showStudyProgramDetail(prodi),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _schoolColor),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Detail', style: TextStyle(color: _schoolColor, fontSize: 11)),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildProfilePill(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _schoolColor),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // TAB 2: FITUR 2 - MANAJEMEN KEGIATAN, EVENT, DAN LOMBA
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildTabEvents(bool isDark) {
    final filteredEvents = _events.where((e) {
      if (_eventFilter == 'Semua') return true;
      if (_eventFilter == 'Pendaftaran Buka') return e['status'] == 'open';
      if (_eventFilter == 'Berlangsung') return e['status'] == 'in_progress';
      if (_eventFilter == 'Kompetisi / Lomba') {
        final meta = e['metadata'] as Map<String, dynamic>? ?? {};
        return meta['is_competition'] == true;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manajemen Kegiatan, Event & Lomba',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Kelola pameran karya tugas akhir, kompetisi kreatif, dan kuliah umum industri',
                  style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddEventDialog(),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Buat Event Baru'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _schoolColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Filter Pills
        Wrap(
          spacing: 8,
          children: ['Semua', 'Pendaftaran Buka', 'Berlangsung', 'Kompetisi / Lomba'].map((f) {
            final isSel = _eventFilter == f;
            return ChoiceChip(
              label: Text(f),
              selected: isSel,
              selectedColor: _schoolColor,
              labelStyle: TextStyle(
                color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontSize: 11,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              onSelected: (_) => setState(() => _eventFilter = f),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Event List
        if (filteredEvents.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.event_busy_rounded, size: 36, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'Belum ada kegiatan atau event terdaftar.',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          )
        else
          ...filteredEvents.map((ev) {
            final meta = ev['metadata'] as Map<String, dynamic>? ?? {};
            final date = meta['event_date']?.toString() ?? 'TBA';
            final loc = meta['location']?.toString() ?? (widget.user.location ?? 'Kampus');
            final participants = meta['registered_participants']?.toString() ?? '0';
            final category = meta['category']?.toString() ?? 'Event';
            final isComp = meta['is_competition'] == true;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _schoolColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _schoolColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.event, color: _schoolColor, size: 20),
                      const SizedBox(height: 4),
                      Text(
                        date.split('-').last,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _schoolColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _schoolColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(fontSize: 10, color: _schoolColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (isComp) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _schoolColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Lomba / Kompetisi',
                                style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ev['title'] ?? '',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ev['description'] ?? '',
                        style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 14,
                        children: [
                          _buildSmallInfo(Icons.calendar_today, date),
                          _buildSmallInfo(Icons.place, loc),
                          _buildSmallInfo(Icons.people, '$participants Peserta Terdaftar'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _showEventDetail(ev),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _schoolColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  child: const Text('Detail Event', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // TAB 3: FITUR 3 - PELUANG MAGANG, RISET, DAN PROYEK
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildTabOpportunities(bool isDark) {
    final filteredOpps = _opportunities.where((o) {
      if (_oppFilter == 'Semua') return true;
      final meta = o['metadata'] as Map<String, dynamic>? ?? {};
      final cat = meta['category']?.toString() ?? '';
      if (_oppFilter == 'Magang MBKM') return cat.contains('Magang');
      if (_oppFilter == 'Riset Kolaboratif') return cat.contains('Riset');
      if (_oppFilter == 'Proyek Industri') return cat.contains('Proyek');
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Peluang Magang, Riset & Proyek Industri',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Fasilitasi siswa & dosen terlibat dalam program magang bersertifikat dan riset terapan DUDI',
                  style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BuatKebutuhanScreen(user: widget.user),
                  ),
                ).then((_) => _loadDashboardData());
              },
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Buka Peluang Baru'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _schoolColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Filter Chips
        Wrap(
          spacing: 8,
          children: ['Semua', 'Magang MBKM', 'Riset Kolaboratif', 'Proyek Industri'].map((f) {
            final isSel = _oppFilter == f;
            return ChoiceChip(
              label: Text(f),
              selected: isSel,
              selectedColor: _schoolColor,
              labelStyle: TextStyle(
                color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontSize: 11,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              onSelected: (_) => setState(() => _oppFilter = f),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Opportunity Cards
        ...filteredOpps.map((opp) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ProgramMagangCard.fromMap(
              opp,
              onDetailPressed: () => _showOpportunityDetail(opp),
            ),
          );
        }),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // TAB 4: FITUR 4 - DIREKTORI MITRA DAN INDUSTRI
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildTabPartners(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Direktori Mitra Industri & Dunia Usaha (DUDI)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Jejaring studio animasi, software house, production house, dan agency mitra MoU',
                  style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddPartnerDialog(),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Tambah Mitra Baru'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _schoolColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 750;

            Widget partnerCard(Map<String, dynamic> p) {
              final meta = p['metadata'] as Map<String, dynamic>? ?? {};
              final cat = meta['category']?.toString() ?? 'Industri Kreatif';
              final mou = meta['mou_period']?.toString() ?? 'Aktif';
              final pic = meta['pic_name']?.toString() ?? 'PIC Kemitraan';
              final contact = meta['contact']?.toString() ?? 'partner@industry.id';
              final quota = meta['internship_quota_yearly']?.toString() ?? '10';

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _schoolColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.business, color: _schoolColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p['title'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(cat, style: const TextStyle(fontSize: 11, color: _schoolColor, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _schoolColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('MoU Aktif', style: TextStyle(fontSize: 10, color: _schoolColor, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      p['description'] ?? '',
                      style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _buildSmallInfo(Icons.badge_outlined, 'PIC: $pic'),
                        _buildSmallInfo(Icons.history_edu, 'Masa: $mou'),
                        _buildSmallInfo(Icons.group_add, 'Kuota Magang: $quota Siswa/Thn'),
                        _buildSmallInfo(Icons.email_outlined, contact),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _contactPartner(p),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                            label: const Text('Hubungi PIC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _schoolColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _proposeCollaboration(p),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _schoolColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('Ajukan Kerjasama', style: TextStyle(color: _schoolColor, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          onPressed: () => _showPartnerDetail(p),
                          icon: const Icon(Icons.info_outline, size: 16),
                          style: IconButton.styleFrom(
                            backgroundColor: _schoolColor.withValues(alpha: 0.1),
                            foregroundColor: _schoolColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            if (isWide) {
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: _partners.map((p) {
                  return SizedBox(
                    width: (constraints.maxWidth - 14) / 2,
                    child: partnerCard(p),
                  );
                }).toList(),
              );
            }

            return Column(
              children: _partners.map((p) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: partnerCard(p),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // TAB 5: FITUR 5 - SISTEM REKRUTMEN DAN PENELUSURAN TALENTA
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildTabTalents(bool isDark) {
    final filteredTalents = _talents.where((t) {
      if (_talentFilter == 'Semua') return true;
      final meta = t['metadata'] as Map<String, dynamic>? ?? {};
      final role = meta['role_label']?.toString() ?? '';
      if (_talentFilter == 'Mahasiswa') return role.contains('Mahasiswa');
      if (_talentFilter == 'Dosen Pembimbing') return role.contains('Dosen');
      if (_talentFilter == 'Alumni Siap Kerja') return role.contains('Alumni');
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sistem Rekrutmen & Penelusuran Talenta',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Direktori mahasiswa berprestasi, lulusan siap kerja, dan dosen pembimbing riset',
                  style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddTalentDialog(),
              icon: const Icon(Icons.person_add, size: 14),
              label: const Text('Daftarkan Talenta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _schoolColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Filter Chips
        Wrap(
          spacing: 8,
          children: ['Semua', 'Mahasiswa', 'Alumni Siap Kerja', 'Dosen Pembimbing'].map((f) {
            final isSel = _talentFilter == f;
            return ChoiceChip(
              label: Text(f),
              selected: isSel,
              selectedColor: _schoolColor,
              labelStyle: TextStyle(
                color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontSize: 11,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              onSelected: (_) => setState(() => _talentFilter = f),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Talents List
        ...filteredTalents.map((t) {
          final meta = t['metadata'] as Map<String, dynamic>? ?? {};
          final role = meta['role_label']?.toString() ?? 'Talenta';
          final prodi = meta['study_program']?.toString() ?? 'Program Studi';
          final gpa = meta['gpa']?.toString() ?? '3.8';
          final status = meta['status_talent']?.toString() ?? 'Siap Magang';
          final rating = meta['rating']?.toString() ?? '5.0';
          final skills = (meta['skills'] as List?)?.join(', ') ?? 'Creative Arts';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _schoolColor.withValues(alpha: 0.1),
                  child: Text(
                    (t['title']?.toString() ?? 'T')[0].toUpperCase(),
                    style: const TextStyle(color: _schoolColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              t['title'] ?? '',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _schoolColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status,
                              style: const TextStyle(color: _schoolColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$role • $prodi',
                        style: const TextStyle(fontSize: 11.5, color: _schoolColor, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t['description'] ?? '',
                        style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _buildSmallInfo(Icons.star, 'Rating $rating/5.0'),
                          _buildSmallInfo(Icons.grade_outlined, 'IPK: $gpa'),
                          _buildSmallInfo(Icons.code, 'Keahlian: $skills'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => _contactTalent(t),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _schoolColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      child: const Text('Hubungi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton(
                      onPressed: () => _showTalentDetail(t),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _schoolColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: const Text('Profil', style: TextStyle(color: _schoolColor, fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // TAB 6: FITUR 6 - ANALITIK, EVALUASI & DAMPAK YANG DIRASAKAN
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildTabAnalytics(bool isDark) {
    final impacts = [
      {
        'title': 'Peningkatan Kualitas Lulusan',
        'desc': '94.2% lulusan terserap industri dengan kompetensi praktis berbasis portofolio nyata.',
        'metric': '94.2%',
        'icon': Icons.school_outlined,
      },
      {
        'title': 'Jejaring Lebih Luas',
        'desc': '24 mitra industri DUDI, asosiasi profesi ADGI, dan 200+ indie studio kreatif terikat MoU.',
        'metric': '24 Mitra',
        'icon': Icons.diversity_3_outlined,
      },
      {
        'title': 'Inovasi & Riset Berkelanjutan',
        'desc': '14 publikasi jurnal dan 12 HKI hasil riset terapan kolaboratif dosen & mahasiswa.',
        'metric': '12 HKI',
        'icon': Icons.lightbulb_outline,
      },
      {
        'title': 'Reputasi Institusi Meningkat',
        'desc': 'Predikat Akreditasi Unggul BAN-PT dan skor kepuasan mitra industri mencapai 4.9 dari 5.0.',
        'metric': '4.9 / 5.0',
        'icon': Icons.trending_up,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dashboard Analitik & Laporan Akuntabilitas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Capaian indikator kinerja utama (IKU) dan dampak nyata kemitraan di Kreavana',
                  style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _downloadReport(),
              icon: const Icon(Icons.download, size: 14),
              label: const Text('Unduh Laporan Mutu PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _schoolColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 4 Dampak yang dirasakan (Sesuai diagram infografis)
        const Text(
          'Dampak yang Dirasakan Institusi',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 750;

            Widget impactCard(Map<String, dynamic> imp) {
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _schoolColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(imp['icon'] as IconData, color: _schoolColor, size: 18),
                        ),
                        Text(
                          imp['metric'] as String,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _schoolColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(imp['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      imp['desc'] as String,
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, height: 1.35),
                    ),
                  ],
                ),
              );
            }

            if (isWide) {
              return Row(
                children: impacts.map((imp) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: impactCard(imp),
                    ),
                  );
                }).toList(),
              );
            }

            return Column(
              children: impacts.map((imp) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: impactCard(imp),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 24),

        // Laporan Tersimpan
        const Text(
          'Dokumen & Laporan Akuntabilitas Resmi',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        if (_reports.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(
                'Belum ada dokumen laporan akuntabilitas yang tersimpan.',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
            ),
          )
        else
          ..._reports.map((rep) {
            final meta = rep['metadata'] as Map<String, dynamic>? ?? {};
            final period = meta['period']?.toString() ?? '2026';
            final cat = meta['category']?.toString() ?? 'Laporan Kinerja';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _schoolColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.picture_as_pdf_outlined, color: _schoolColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rep['title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('$cat • Periode $period', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _downloadReport(title: rep['title'], rawDoc: rep),
                    icon: const Icon(Icons.download_rounded, size: 14, color: _schoolColor),
                    label: const Text('Unduh PDF', style: TextStyle(color: _schoolColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _schoolColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 20),

        // Dokumen Legalitas & MoU Kemitraan
        const Text(
          'Dokumen Legalitas & MoU Kemitraan Kampus',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        if (_documents.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(
                'Belum ada dokumen MoU atau legalitas kemitraan yang tersimpan.',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
            ),
          )
        else
          ..._documents.map((doc) {
          final meta = doc['metadata'] as Map<String, dynamic>? ?? {};
          final num = meta['document_number'] ?? meta['sk_number'] ?? '-';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _schoolColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.folder_shared_outlined, color: _schoolColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc['title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('Nomor: $num', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _downloadReport(title: doc['title'], rawDoc: doc),
                  icon: const Icon(Icons.download_rounded, size: 14, color: _schoolColor),
                  label: const Text('Unduh PDF', style: TextStyle(color: _schoolColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _schoolColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSmallInfo(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _schoolColor),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // MODAL FORMS & DIALOG UJI COBA FITUR
  // ═════════════════════════════════════════════════════════════════════════════

  void _showWorkflowStageDetail(Map<String, dynamic> stage) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: _schoolColor,
              child: Text(
                '${stage['step']}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(stage['title'] as String, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stage['desc'] as String,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _schoolColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: _schoolColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Status saat ini: ${stage['status']}',
                      style: const TextStyle(color: _schoolColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _currentWorkflowStep = (stage['step'] as int) - 1);
              AppSweetAlert.success(
                context,
                'Tahapan ${stage['title']} aktif dan diverifikasi oleh sistem Kreavana.',
                title: 'Alur Kerja Terverifikasi',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _schoolColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Verifikasi Tahap'),
          ),
        ],
      ),
    );
  }

  void _showAddEventDialog() {
    final titleCtrl = TextEditingController();
    String category = 'Pameran & Expo';
    final descCtrl = TextEditingController();
    final locCtrl = TextEditingController(text: widget.user.location ?? '');
    final quotaCtrl = TextEditingController(text: '100');
    DateTime selectedDate = DateTime.now().add(const Duration(days: 14));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          const eventCategories = [
            ('Pameran & Expo', Icons.campaign_outlined, Color(0xFF2563EB)),
            ('Kompetisi & Lomba', Icons.emoji_events_outlined, Color(0xFFEAB308)),
            ('Workshop & Seminar', Icons.school_outlined, Color(0xFF10B981)),
            ('Showcase Tugas Akhir', Icons.palette_outlined, Color(0xFF8B5CF6)),
          ];

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Buat Kegiatan / Lomba Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kegiatan / Lomba *',
                      hintText: 'Contoh: Creative Game Jam 2026',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(14),
                    dropdownColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                    elevation: 6,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Kategori Kegiatan',
                      prefixIcon: const Icon(Icons.category_outlined, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    selectedItemBuilder: (context) {
                      return eventCategories.map((item) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: item.$3),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  item.$1,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList();
                    },
                    items: eventCategories.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final isLast = i == eventCategories.length - 1;
                      return DropdownMenuItem<String>(
                        value: item.$1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            border: !isLast
                                ? Border(
                                    bottom: BorderSide(
                                      color: isDark
                                          ? const Color(0xFF2D2A42)
                                          : const Color(0xFFF1F5F9),
                                      width: 1,
                                    ),
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: item.$3.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Icon(item.$2, size: 15, color: item.$3),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.$1,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => category = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                        helpText: 'Pilih Tanggal Pelaksanaan Event',
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tanggal Pelaksanaan',
                        suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                      ),
                      child: Text(
                        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Lokasi / Venue Pelaksanaan',
                      hintText: 'Contoh: Aula Kampus / Virtual',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: quotaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Target / Kuota Peserta (Orang)',
                      hintText: 'Contoh: 100',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi Singkat Event',
                      hintText: 'Jelaskan tujuan kegiatan, target audiens, dan fasilitas...',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);

                  final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                  final isComp = category.toLowerCase().contains('lomba') || titleCtrl.text.toLowerCase().contains('lomba');
                  final quotaInt = int.tryParse(quotaCtrl.text.trim()) ?? 50;

                  final newRecord = {
                    'resource_type': 'events',
                    'title': titleCtrl.text.trim(),
                    'description': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : 'Kegiatan resmi kampus & industri.',
                    'status': 'open',
                    'metadata': {
                      'category': category,
                      'event_date': dateStr,
                      'location': locCtrl.text.trim().isNotEmpty ? locCtrl.text.trim() : (widget.user.location ?? '-'),
                      'registered_participants': quotaInt,
                      'is_competition': isComp,
                    },
                  };

                  try {
                    await ApiService.post('institution/resources', newRecord);
                  } catch (_) {}

                  if (!mounted) return;
                  setState(() {
                    _resources.insert(0, newRecord);
                  });

                  AppSweetAlert.success(
                    context,
                    'Event "${titleCtrl.text}" berhasil dipublikasikan dan tersimpan di database.',
                    title: 'Event Berhasil Dibuat',
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: _schoolColor, foregroundColor: Colors.white),
                child: const Text('Simpan & Publikasikan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddPartnerDialog() {
    final titleCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'Studio Animasi & Game');
    final picCtrl = TextEditingController();
    final contactCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tambah Mitra Industri Baru', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Nama Perusahaan / Studio *', hintText: 'Contoh: PT Kreasi Animasi Nusantara'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: catCtrl,
                decoration: const InputDecoration(labelText: 'Kategori Industri'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: picCtrl,
                decoration: const InputDecoration(labelText: 'Nama PIC Kemitraan'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contactCtrl,
                decoration: const InputDecoration(labelText: 'Email / Kontak PIC'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);

              final newRecord = {
                'resource_type': 'partners',
                'title': titleCtrl.text.trim(),
                'description': 'Mitra industri strategis kerjasama vokasi & MBKM.',
                'status': 'published',
                'metadata': {
                  'category': catCtrl.text.trim(),
                  'pic_name': picCtrl.text.trim().isNotEmpty ? picCtrl.text.trim() : 'Direktur Kemitraan',
                  'contact': contactCtrl.text.trim().isNotEmpty ? contactCtrl.text.trim() : 'partner@kreavana.id',
                  'mou_period': '2026 - 2029 (Aktif)',
                  'internship_quota_yearly': 10,
                },
              };

              try {
                await ApiService.post('institution/resources', newRecord);
              } catch (_) {}

              setState(() {
                _resources.insert(0, newRecord);
              });

              if (mounted) {
                AppSweetAlert.success(
                  context,
                  'Mitra industri "${titleCtrl.text}" berhasil ditambahkan.',
                  title: 'Mitra DUDI Ditambahkan',
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _schoolColor, foregroundColor: Colors.white),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showAddStudyProgramDialog() {
    final titleCtrl = TextEditingController();
    final degreeCtrl = TextEditingController(text: 'D4 / Sarjana Terapan');
    final accCtrl = TextEditingController(text: 'Unggul (BAN-PT)');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tambah Program Studi Baru', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Nama Program Studi *', hintText: 'Contoh: D4 Game Technology'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: degreeCtrl,
              decoration: const InputDecoration(labelText: 'Jenjang Pendidikan'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: accCtrl,
              decoration: const InputDecoration(labelText: 'Status Akreditasi'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);

              final newRecord = {
                'resource_type': 'study_programs',
                'title': titleCtrl.text.trim(),
                'description': 'Program studi terakreditasi berbasis kurikulum kemitraan industri.',
                'status': 'published',
                'metadata': {
                  'degree': degreeCtrl.text.trim(),
                  'accreditation': accCtrl.text.trim(),
                  'total_students': 150,
                  'employment_rate': '91.5%',
                },
              };

              try {
                await ApiService.post('institution/resources', newRecord);
              } catch (_) {}

              setState(() {
                _resources.insert(0, newRecord);
              });

              if (mounted) {
                AppSweetAlert.success(
                  context,
                  'Program studi "${titleCtrl.text}" berhasil ditambahkan.',
                  title: 'Prodi Berhasil Ditambahkan',
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _schoolColor, foregroundColor: Colors.white),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showAddTalentDialog() {
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController(text: 'Mahasiswa Tingkat Akhir');
    final skillCtrl = TextEditingController(text: 'UI/UX Design, Flutter');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Daftarkan Talenta Mahasiswa / Dosen', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama Lengkap *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: roleCtrl,
              decoration: const InputDecoration(labelText: 'Peran / Jenjang'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: skillCtrl,
              decoration: const InputDecoration(labelText: 'Keahlian Utama (Pisahkan Koma)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);

              final newRecord = {
                'resource_type': 'talents',
                'title': nameCtrl.text.trim(),
                'description': 'Talenta unggulan terverifikasi siap berkarya di industri kreatif.',
                'status': 'published',
                'metadata': {
                  'role_label': roleCtrl.text.trim(),
                  'study_program': 'Desain Komunikasi Visual',
                  'skills': skillCtrl.text.split(',').map((s) => s.trim()).toList(),
                  'status_talent': 'Siap Magang',
                  'rating': 4.9,
                  'gpa': '3.85',
                },
              };

              try {
                await ApiService.post('institution/resources', newRecord);
              } catch (_) {}

              setState(() {
                _resources.insert(0, newRecord);
              });

              if (mounted) {
                AppSweetAlert.success(
                  context,
                  'Talenta "${nameCtrl.text}" berhasil dimasukkan ke penelusuran industri.',
                  title: 'Talenta Terdaftar',
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _schoolColor, foregroundColor: Colors.white),
            child: const Text('Daftarkan'),
          ),
        ],
      ),
    );
  }

  void _showStudyProgramDetail(Map<String, dynamic> prodi) {
    final meta = prodi['metadata'] as Map<String, dynamic>? ?? {};
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(prodi['title'] ?? 'Program Studi', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prodi['description'] ?? '', style: const TextStyle(fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 14),
            _buildDetailRow('Jenjang', meta['degree']?.toString() ?? '-'),
            _buildDetailRow('Akreditasi', meta['accreditation']?.toString() ?? '-'),
            _buildDetailRow('Mahasiswa Aktif', '${meta['total_students'] ?? 0} Orang'),
            _buildDetailRow('Serapan Industri', meta['employment_rate']?.toString() ?? '-'),
            _buildDetailRow('Ketua Program Studi', meta['head_of_program']?.toString() ?? '-'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  void _showEventDetail(Map<String, dynamic> ev) {
    final meta = ev['metadata'] as Map<String, dynamic>? ?? {};
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(ev['title'] ?? 'Detail Kegiatan', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ev['description'] ?? '', style: const TextStyle(fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 14),
            _buildDetailRow('Kategori', meta['category']?.toString() ?? '-'),
            _buildDetailRow('Tanggal', meta['event_date']?.toString() ?? '-'),
            _buildDetailRow('Lokasi', meta['location']?.toString() ?? '-'),
            _buildDetailRow('Peserta Terdaftar', '${meta['registered_participants'] ?? 0} Orang'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              AppSweetAlert.success(context, 'Data pendaftaran event telah disinkronkan ke portal publik.');
            },
            style: ElevatedButton.styleFrom(backgroundColor: _schoolColor, foregroundColor: Colors.white),
            child: const Text('Sinkronkan'),
          ),
        ],
      ),
    );
  }

  void _showOpportunityDetail(Map<String, dynamic> opp) {
    final meta = opp['metadata'] as Map<String, dynamic>? ?? {};
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(opp['title'] ?? 'Program Magang', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(opp['description'] ?? '', style: const TextStyle(fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 14),
            _buildDetailRow('Mitra Industri', meta['industry_partner']?.toString() ?? '-'),
            _buildDetailRow('Kuota', meta['quota']?.toString() ?? '-'),
            _buildDetailRow('Uang Saku/Honor', meta['allowance']?.toString() ?? '-'),
            _buildDetailRow('Durasi', meta['duration']?.toString() ?? '-'),
            _buildDetailRow('Pendaftar', '${meta['applicants_count'] ?? 0} Mahasiswa'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              AppSweetAlert.success(context, 'Daftar pelamar magang siap diseleksi & dikonversi 20 SKS MBKM.');
            },
            style: ElevatedButton.styleFrom(backgroundColor: _schoolColor, foregroundColor: Colors.white),
            child: const Text('Seleksi Pelamar'),
          ),
        ],
      ),
    );
  }

  void _showPartnerDetail(Map<String, dynamic> p) {
    final meta = p['metadata'] as Map<String, dynamic>? ?? {};
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(p['title'] ?? 'Detail Mitra', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p['description'] ?? '', style: const TextStyle(fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 14),
            _buildDetailRow('Kategori', meta['category']?.toString() ?? '-'),
            _buildDetailRow('Status MoU', meta['mou_period']?.toString() ?? '-'),
            _buildDetailRow('PIC', meta['pic_name']?.toString() ?? '-'),
            _buildDetailRow('Kontak', meta['contact']?.toString() ?? '-'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  void _showTalentDetail(Map<String, dynamic> t) {
    final meta = t['metadata'] as Map<String, dynamic>? ?? {};
    final title = t['title']?.toString() ?? 'Talenta';
    final role = meta['role_label']?.toString() ?? 'Talenta Siswa';
    final prodi = meta['study_program']?.toString() ?? '-';
    final gpa = meta['gpa']?.toString() ?? '-';
    final status = meta['status_talent']?.toString() ?? 'Aktif';
    final skills = (meta['skills'] as List?)?.join(', ') ?? '-';
    final email = meta['email']?.toString() ?? '-';
    final phone = meta['phone']?.toString() ?? '-';
    final achievements = meta['achievements']?.toString() ?? '-';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _schoolColor.withValues(alpha: 0.12),
                    child: Text(
                      title[0].toUpperCase(),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _schoolColor),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('$role • $prodi', style: const TextStyle(fontSize: 12, color: _schoolColor, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _schoolColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(status, style: const TextStyle(fontSize: 10, color: _schoolColor, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Text('IPK: $gpa', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 10),
              Text(
                t['description'] ?? '',
                style: const TextStyle(fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 14),
              _buildDetailRow('Email Akademik', email),
              _buildDetailRow('Kontak WhatsApp', phone),
              _buildDetailRow('Keahlian Unggulan', skills),
              _buildDetailRow('Prestasi & Portofolio', achievements),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _contactTalent(t);
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: const Text('Mulai Chat di Kreavana'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _schoolColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MarketplaceKaryaScreen(user: widget.user),
                        ),
                      );
                    },
                    icon: const Icon(Icons.collections_bookmark_outlined, size: 16, color: _schoolColor),
                    label: const Text('Lihat Karya Siswa', style: TextStyle(color: _schoolColor)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _schoolColor),
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _proposeCollaboration(Map<String, dynamic> p) {
    final meta = p['metadata'] as Map<String, dynamic>? ?? {};
    final title = p['title']?.toString() ?? 'Mitra Industri';
    final pic = meta['pic_name']?.toString() ?? 'PIC Kemitraan';
    final typeCtrl = TextEditingController(text: 'Magang Bersertifikat MBKM (20 SKS)');
    final noteCtrl = TextEditingController(text: 'Kami dari Institut Seni & Rekayasa Kreatif Nusantara ingin menjalin kerjasama kemitraan magang & riset.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Ajukan Kerjasama dengan $title', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ditujukan kepada PIC: $pic', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: typeCtrl,
              decoration: const InputDecoration(labelText: 'Bentuk Kerjasama / Program', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Pesan / Pengantar Kerjasama', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DirectMessageScreen(
                    currentUser: widget.user,
                    initialChat: {
                      'id': 'partner_${p['id'] ?? title.hashCode}',
                      'name': '$pic ($title)',
                      'username': title.toLowerCase().replaceAll(' ', '_'),
                      'role': 'Mitra Industri & DUDI',
                      'sub_role': meta['category']?.toString() ?? 'Industri',
                      'avatar': '',
                      'is_online': true,
                    },
                    showSidebar: false,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Kirim & Buka Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _schoolColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _contactPartner(Map<String, dynamic> p) {
    final meta = p['metadata'] as Map<String, dynamic>? ?? {};
    final title = p['title']?.toString() ?? 'Mitra Industri';
    final pic = meta['pic_name']?.toString() ?? 'PIC Kemitraan';
    final cat = meta['category']?.toString() ?? 'Industri';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DirectMessageScreen(
          currentUser: widget.user,
          initialChat: {
            'id': 'partner_${p['id'] ?? title.hashCode}',
            'name': '$pic ($title)',
            'username': title.toLowerCase().replaceAll(' ', '_'),
            'role': 'Mitra Industri & DUDI',
            'sub_role': cat,
            'avatar': '',
            'is_online': true,
          },
          showSidebar: false,
        ),
      ),
    );
  }

  void _contactTalent(Map<String, dynamic> t) {
    final meta = t['metadata'] as Map<String, dynamic>? ?? {};
    final title = t['title']?.toString() ?? 'Talenta Kreavana';
    final role = meta['role_label']?.toString() ?? 'Talenta Vokasi';
    final prodi = meta['study_program']?.toString() ?? 'Program Studi';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DirectMessageScreen(
          currentUser: widget.user,
          initialChat: {
            'id': 'talent_${t['id'] ?? title.hashCode}',
            'name': title,
            'username': title.toLowerCase().replaceAll(' ', '_'),
            'role': role,
            'sub_role': prodi,
            'avatar': '',
            'is_online': true,
          },
          showSidebar: false,
        ),
      ),
    );
  }

  void _downloadReport({String? title, Map<String, dynamic>? rawDoc}) {
    final doc = rawDoc ?? (_reports.isNotEmpty ? _reports.first : <String, dynamic>{});
    if (doc.isEmpty) {
      AppSweetAlert.info(
        context,
        'Belum ada data laporan resmi yang tersimpan di sistem.',
        title: 'Laporan Belum Tersedia',
      );
      return;
    }
    final meta = (doc['metadata'] as Map<String, dynamic>?) ?? {};
    final docTitle = title ?? doc['title']?.toString() ?? 'Laporan Akuntabilitas Kampus';
    final docNum = meta['document_number']?.toString() ??
        meta['sk_number']?.toString() ??
        meta['doc_number']?.toString() ??
        '-';
    final cat = meta['category']?.toString() ?? 'Laporan Akuntabilitas & Mutu';
    final desc = doc['description']?.toString() ??
        'Dokumen resmi terverifikasi sistem akreditasi vokasi Kreavana.';

    final attributes = <String, String>{
      'Nomor Dokumen / SK': docNum,
      'Kategori Dokumen': cat,
      'Institusi Penerbit': _profileResource?['title']?.toString().isNotEmpty == true
          ? _profileResource!['title'].toString()
          : widget.user.name,
      'Akreditasi Institusi': (_profileResource?['metadata'] as Map?)?['accreditation']?.toString() ?? 'Terakreditasi Resmi',
      'Status Verifikasi': 'Terverifikasi Resmi di Sistem',
    };
    if (meta.containsKey('period')) attributes['Periode Akademik'] = meta['period'].toString();
    if (meta.containsKey('valid_until')) attributes['Masa Berlaku'] = meta['valid_until'].toString();
    if (meta.containsKey('total_interns')) attributes['Mahasiswa Terlibat'] = '${meta['total_interns']} Mahasiswa';
    if (meta.containsKey('completion_rate')) attributes['Tingkat Keberhasilan'] = meta['completion_rate'].toString();
    if (meta.containsKey('partner_satisfaction')) attributes['Indeks Kepuasan Mitra'] = meta['partner_satisfaction'].toString();
    if (meta.containsKey('grade')) attributes['Peringkat Akreditasi'] = meta['grade'].toString();

    SchoolPdfService.downloadOfficialPdf(
      context,
      title: docTitle,
      category: cat,
      docNumber: docNum,
      date: '18 Oktober 2026',
      description: desc,
      attributes: attributes,
      rawDocument: doc,
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
}
