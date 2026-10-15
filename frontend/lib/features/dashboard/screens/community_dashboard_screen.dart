import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../models/user_model.dart';
import '../../../services/badge_service.dart';
import '../../../services/community_service.dart';
import '../../../services/theme_transition_service.dart';
import '../../../services/chat_service.dart';
import '../../../screens/global_search_screen.dart';
import '../../../screens/notifications_screen.dart';
import '../../../screens/direct_message_screen.dart';
import '../../../widgets/app_breadcrumbs.dart';
import '../../../widgets/desktop_sidebar_layout.dart';
import '../../../utils/app_errors.dart';

class CommunityDashboardScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel> onUserUpdated;
  final String? initialServiceKey;
  final bool showSidebar;

  const CommunityDashboardScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
    this.initialServiceKey,
    this.showSidebar = true,
  });

  @override
  State<CommunityDashboardScreen> createState() =>
      _CommunityDashboardScreenState();
}

class _CommunityDashboardScreenState extends State<CommunityDashboardScreen> {
  final GlobalKey _themeBtnKey = GlobalKey();

  static const Color _commPurple = Color(0xFF6D28D9);

  bool _isLoading = true;
  int _selectedTabIndex = 0; // 0: Kegiatan, 1: Anggota, 2: Pengumuman, 3: Evaluasi
  List<dynamic> _workflowSteps = [];
  List<dynamic> _ecosystemEntities = [];
  List<dynamic> _corePillars = [];
  List<dynamic> _focusSteps = [];
  Map<String, dynamic> _evaluations = {};

  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _metrics = [];

  String? _activeServiceKey;
  final TextEditingController _serviceSearchCtrl = TextEditingController();
  String _serviceSearchQuery = '';
  String _serviceSelectedFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    if (widget.initialServiceKey != null &&
        widget.initialServiceKey!.startsWith('komunitas_')) {
      _activeServiceKey = widget.initialServiceKey;
    }
    _fetchCommunityData();
  }

  @override
  void didUpdateWidget(covariant CommunityDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialServiceKey != oldWidget.initialServiceKey) {
      setState(() {
        _activeServiceKey = widget.initialServiceKey;
        _serviceSearchQuery = '';
        _serviceSearchCtrl.clear();
        _serviceSelectedFilter = 'Semua';
      });
    }
  }

  @override
  void dispose() {
    _serviceSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCommunityData() async {
    try {
      final results = await Future.wait([
        CommunityService.getOverview(communityId: widget.user.id)
            .catchError((_) => <String, dynamic>{}),
        CommunityService.getActivities(communityId: widget.user.id)
            .catchError((_) => <String, dynamic>{}),
        CommunityService.getMembers(communityId: widget.user.id)
            .catchError((_) => <String, dynamic>{}),
        CommunityService.getAnnouncements(communityId: widget.user.id)
            .catchError((_) => <String, dynamic>{}),
      ]);

      final overviewRes = results[0];
      final activitiesRes = results[1];
      final membersRes = results[2];
      final announcementsRes = results[3];

      final ovData = (overviewRes['data'] as Map<String, dynamic>?) ?? {};
      final metricsData = (ovData['metrics'] as Map<String, dynamic>?) ?? {};

      // Parse Activities
      final rawActs = (activitiesRes['data'] as List<dynamic>?) ??
          (ovData['recent_activities'] as List<dynamic>?) ??
          [];
      final loadedActs = rawActs.whereType<Map<String, dynamic>>().toList();

      // Parse Members
      final rawMbrs = (membersRes['data'] as List<dynamic>?) ??
          (ovData['recent_members'] as List<dynamic>?) ??
          [];
      final loadedMbrs = rawMbrs.whereType<Map<String, dynamic>>().toList();

      // Parse Announcements
      final rawAnns = (announcementsRes['data'] as List<dynamic>?) ??
          (ovData['recent_announcements'] as List<dynamic>?) ??
          [];
      final loadedAnns = rawAnns.whereType<Map<String, dynamic>>().toList();

      final totalAct = metricsData['total_activities'] ?? loadedActs.length;
      final activeMbr = metricsData['active_members'] ?? loadedMbrs.length;
      final runningEv = metricsData['running_events'] ??
          loadedActs.where((a) => a['status'] == 'active').length;
      final treasury = metricsData['treasury_balance']?.toString() ?? 'Rp 18.500.000';

      final loadedMetrics = <Map<String, dynamic>>[
        {
          'label': 'Total Kegiatan',
          'value': totalAct.toString(),
          'sub': '$runningEv sedang berjalan',
          'color': _commPurple,
          'icon': Icons.groups_outlined,
        },
        {
          'label': 'Anggota & Mitra',
          'value': activeMbr.toString(),
          'sub': 'Dalam komunitas aktif',
          'color': const Color(0xFF10B981),
          'icon': Icons.people_outline,
        },
        {
          'label': 'Event Berjalan',
          'value': runningEv.toString(),
          'sub': 'Aktif bulan ini',
          'color': const Color(0xFFF59E0B),
          'icon': Icons.event_available_outlined,
        },
        {
          'label': 'Kas / Anggaran',
          'value': treasury,
          'sub': 'Teralokasi & sponsor',
          'color': const Color(0xFFEC4899),
          'icon': Icons.account_balance_wallet_outlined,
        },
      ];

      if (mounted) {
        setState(() {
          _workflowSteps = (ovData['workflow_steps'] as List<dynamic>?) ?? _defaultWorkflow();
          _ecosystemEntities = (ovData['ecosystem_entities'] as List<dynamic>?) ?? _defaultEntities();
          _corePillars = (ovData['core_pillars'] as List<dynamic>?) ?? _defaultPillars();
          _focusSteps = (ovData['focus_steps'] as List<dynamic>?) ?? _defaultFocusSteps();
          _evaluations = (ovData['evaluations'] as Map<String, dynamic>?) ?? _defaultEvaluations();
          _activities = loadedActs;
          _members = loadedMbrs;
          _announcements = loadedAnns;
          _metrics = loadedMetrics;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _workflowSteps = _defaultWorkflow();
          _ecosystemEntities = _defaultEntities();
          _corePillars = _defaultPillars();
          _focusSteps = _defaultFocusSteps();
          _evaluations = _defaultEvaluations();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _defaultWorkflow() {
    return [
      {
        'step': 1,
        'title': 'Bergabung & Membuat Profil',
        'actor': 'Komunitas',
        'status': 'completed',
        'progress': 1.0,
        'description': 'Mendaftar di Kreavana dan melengkapi profil, kategori komunitas (kreatif, hobi, profesi, wilayah), visi & misi, serta portofolio karya.',
      },
      {
        'step': 2,
        'title': 'Verifikasi & Aktivasi',
        'actor': 'Admin Kreavana',
        'status': 'verified',
        'progress': 1.0,
        'description': 'Pemeriksaan kredibilitas oleh tim kurasi Kreavana dan pemberian lencana resmi Komunitas Terverifikasi.',
      },
      {
        'step': 3,
        'title': 'Kelola Kegiatan & Agenda',
        'actor': 'Komunitas',
        'status': 'active',
        'progress': 1.0,
        'description': 'Membuat dan mengatur jadwal kegiatan (workshop, hunting foto, meetup, pameran), kuota peserta, dan alokasi kas/anggaran.',
      },
      {
        'step': 4,
        'title': 'Terhubung dengan Anggota & Mitra',
        'actor': 'Ekosistem',
        'status': 'active',
        'progress': 1.0,
        'description': 'Merekrut anggota kreatif dan membangun kolaborasi aktif dengan mitra studio, EO, vendor, dan kreator lain.',
      },
      {
        'step': 5,
        'title': 'Publikasi & Promosi',
        'actor': 'Komunitas & Kreavana',
        'status': 'active',
        'progress': 1.0,
        'description': 'Mempublikasikan pengumuman resmi dan promosi program bersama ke seluruh ekosistem serta media publik.',
      },
      {
        'step': 6,
        'title': 'Evaluasi & Pengembangan',
        'actor': 'Komunitas',
        'status': 'active',
        'progress': 0.9,
        'description': 'Menganalisis kepuasan anggota, feedback kualitas acara, dampak sosial, dan merumuskan program berikutnya.',
      },
    ];
  }

  List<Map<String, dynamic>> _defaultEntities() {
    return [
      {
        'id': 'creator',
        'name': 'Kreator / Freelancer',
        'subtitle': 'Fotografer, Videografer, Desainer, Content Creator, Talenta, dll',
        'tag': 'Kolaborasi & Talenta',
        'color': const Color(0xFFEF4444),
        'benefits_received': [
          'Akses peluang proyek & job kreatif',
          'Portofolio digital yang terstruktur',
          'Jaringan dan ruang kolaborasi luas',
          'Reputasi & rating terpercaya',
          'Tools komunikasi & manajemen proyek',
        ],
        'benefits_given': [
          'Karya, keahlian dan portofolio berkualitas',
          'Partisipasi aktif di kegiatan komunitas',
          'Rekomendasi & review timbal balik',
          'Kontribusi nyata pada ekosistem kreatif',
        ],
      },
      {
        'id': 'client',
        'name': 'Klien / Pemilik Kebutuhan',
        'subtitle': 'Perusahaan, UMKM, Sekolah, Kampus, EO/WO, Instansi, dll',
        'tag': 'Solusi & Proyek',
        'color': const Color(0xFF0284C7),
        'benefits_received': [
          'Akses ke talenta & penyedia jasa terbaik',
          'Solusi kreatif yang tepat sasaran',
          'Proses pengerjaan lebih cepat & mudah',
          'Transparansi kontrak & keamanan transaksi',
          'Reputasi penyedia jasa transparan',
        ],
        'benefits_given': [
          'Informasi kebutuhan & peluang proyek',
          'Feedback & rating mutu hasil kerja',
          'Kerja sama jangka panjang berkelanjutan',
          'Referensi & testimoni kredibel',
        ],
      },
      {
        'id': 'partner',
        'name': 'Mitra / Vendor / Penyedia Jasa',
        'subtitle': 'Studio, Event Organizer, Creative House, Percetakan, Properti, dll',
        'tag': 'Layanan & Sarana',
        'color': const Color(0xFFF97316),
        'benefits_received': [
          'Peluang proyek & klien baru kontinu',
          'Visibilitas bisnis di kalangan kreator',
          'Pengelolaan portofolio & paket layanan',
          'Kolaborasi dengan kreator dan komunitas lain',
          'Pertumbuhan pendapatan bisnis',
        ],
        'benefits_given': [
          'Layanan & paket kerja sama istimewa',
          'Kualitas layanan tinggi & tepat waktu',
          'Harga kompetitif khusus komunitas',
          'Testimoni & rekam jejak profesional',
        ],
      },
      {
        'id': 'sponsor',
        'name': 'Investor / Sponsor',
        'subtitle': 'Individu, Perusahaan, Brand, Pemerintah, dll',
        'tag': 'Pendanaan & Dampak',
        'color': const Color(0xFF10B981),
        'benefits_received': [
          'Akses ke proyek kreatif potensial',
          'Brand exposure luas di kalangan audiens muda',
          'Dukungan penuh komunitas kreatif aktif',
          'Laporan kegiatan & impact report terukur',
          'Peluang kolaborasi strategis jangka panjang',
        ],
        'benefits_given': [
          'Dukungan pendanaan & sponsorship kegiatan',
          'Program aktivasi & event bersama',
          'Kesempatan promosi brand mutual',
          'Kontribusi pada pertumbuhan ekosistem',
        ],
      },
      {
        'id': 'team',
        'name': 'Tim Kreavana',
        'subtitle': 'Operasional, Marketing, IT, Partnership, dll',
        'tag': 'Fasilitator Platform',
        'color': const Color(0xFF2563EB),
        'benefits_received': [
          'Pencapaian target & pertumbuhan ekosistem',
          'Pengembangan skill & pengalaman praktis',
          'Lingkungan kerja kolaboratif & dinamis',
          'Dampak sosial nyata bagi komunitas',
        ],
        'benefits_given': [
          'Layanan platform terbaik untuk seluruh pengguna',
          'Pengembangan fitur & inovasi berkelanjutan',
          'Perluasan jaringan kemitraan strategis',
          'Eksekusi program & pendampingan komunitas',
        ],
      },
    ];
  }

  List<Map<String, dynamic>> _defaultPillars() {
    return [
      {'name': 'Temukan', 'icon': Icons.search_rounded, 'desc': 'Temukan talenta, peluang, mitra & sponsor'},
      {'name': 'Kolaborasi', 'icon': Icons.handshake_rounded, 'desc': 'Bekerja sama lintas peran dalam ekosistem'},
      {'name': 'Proyek', 'icon': Icons.work_outline_rounded, 'desc': 'Eksekusi event, karya & agenda nyata'},
      {'name': 'Pendapatan', 'icon': Icons.payments_outlined, 'desc': 'Kas komunitas, sponsorship & monetisasi'},
      {'name': 'Bangun Reputasi', 'icon': Icons.verified_outlined, 'desc': 'Review, rating & rekam jejak terpercaya'},
    ];
  }

  List<Map<String, dynamic>> _defaultFocusSteps() {
    return [
      {'title': 'Buat halaman komunitas & lengkapi profil', 'done': true},
      {'title': 'Rekrut komunitas kreatif yang sudah ada', 'done': true},
      {'title': 'Aktifkan fitur diskusi, event, dan kolaborasi', 'done': true},
      {'title': 'Dapatkan feedback untuk pengembangan fitur berikutnya', 'done': true},
    ];
  }

  Map<String, dynamic> _defaultEvaluations() {
    return {
      'average_rating': 4.9,
      'satisfaction_rate': 98.4,
      'on_time_rate': 99.1,
      'total_feedback': 48,
      'social_impact_score': 95,
      'impact_summary':
          'Tingkat kepuasan peserta 98.4%, 0 perselisihan mutu, seluruh agenda berjalan sesuai rundown mutu.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    final page = Scaffold(
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
                child: _activeServiceKey != null
                    ? _buildDedicatedServiceView(isDark, isDesktop, screenWidth)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEcosystemHeroBanner(isDark),
                          const SizedBox(height: 20),
                          _buildWorkflowStepperSection(isDark),
                          const SizedBox(height: 20),
                          _buildMetricCards(isDark),
                          const SizedBox(height: 24),
                          _buildEcosystemHubSection(isDark),
                          const SizedBox(height: 24),
                          _buildInteractiveWorkspacesSection(isDark),
                          const SizedBox(height: 24),
                          _buildFocusEarlySection(isDark),
                        ],
                      ),
              ),
            ),
    );

    if (isDesktop && widget.showSidebar && _activeServiceKey != null) {
      return DesktopSidebarLayout(
        user: widget.user,
        activeRoute: _activeServiceKey!,
        onUserUpdated: widget.onUserUpdated,
        child: page,
      );
    }

    return page;
  }

  // ── APP BAR ─────────────────────────────────────────────────────────────
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
                    Expanded(
                      child: Text(
                        'Cari anggota, agenda, kreator, mitra sponsor...',
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
          const SizedBox(width: 14),
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
                backgroundColor: _commPurple.withValues(alpha: 0.15),
                child: const Icon(Icons.groups_rounded, color: _commPurple, size: 20),
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
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF10B981)),
                      const SizedBox(width: 3),
                      Text(
                        'Komunitas Terverifikasi',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── DEDICATED SERVICE VIEWS (MATCHING IMAGE 1 CONCEPT) ───────────────────
  Widget _buildDedicatedServiceView(bool isDark, bool isDesktop, double screenWidth) {
    final key = _activeServiceKey?.toLowerCase() ?? 'komunitas_kegiatan';

    if (key.contains('anggota')) {
      return _buildAnggotaServiceView(isDark, isDesktop, screenWidth);
    } else if (key.contains('pengumuman')) {
      return _buildPengumumanServiceView(isDark, isDesktop, screenWidth);
    } else if (key.contains('kolaborasi')) {
      return _buildKolaborasiServiceView(isDark, isDesktop, screenWidth);
    } else {
      return _buildKegiatanServiceView(isDark, isDesktop, screenWidth);
    }
  }

  // 1. KEGIATAN KOMUNITAS SERVICE VIEW
  Widget _buildKegiatanServiceView(bool isDark, bool isDesktop, double screenWidth) {
    final total = _activities.length;
    final berjalan = _activities.where((a) => a['status'] == 'active').length;
    final mendatang = _activities.where((a) => a['status'] == 'pending').length;
    final selesai = _activities.where((a) => a['status'] == 'completed').length;
    final dibatalkan = _activities.where((a) => a['status'] == 'cancelled').length;

    final metricData = [
      {
        'status': 'Semua',
        'label': 'Total Kegiatan',
        'value': total.toString(),
        'icon': Icons.folder_special_rounded,
        'color': const Color(0xFF6366F1),
      },
      {
        'status': 'Sedang Berjalan',
        'label': 'Sedang Berjalan',
        'value': berjalan.toString(),
        'icon': Icons.rocket_launch_rounded,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'status': 'Mendatang',
        'label': 'Mendatang / Pending',
        'value': mendatang.toString(),
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'status': 'Selesai',
        'label': 'Selesai',
        'value': selesai.toString(),
        'icon': Icons.check_circle_rounded,
        'color': const Color(0xFF3B82F6),
      },
      {
        'status': 'Dibatalkan',
        'label': 'Dibatalkan',
        'value': dibatalkan.toString(),
        'icon': Icons.hourglass_top_rounded,
        'color': const Color(0xFFF59E0B),
      },
    ];

    final filterOptions = [
      {'key': 'Semua', 'label': 'Semua', 'count': total},
      {'key': 'Sedang Berjalan', 'label': 'Berjalan', 'count': berjalan},
      {'key': 'Mendatang', 'label': 'Mendatang', 'count': mendatang},
      {'key': 'Selesai', 'label': 'Selesai', 'count': selesai},
      {'key': 'Dibatalkan', 'label': 'Dibatalkan', 'count': dibatalkan},
    ];

    final filtered = _activities.where((act) {
      final title = act['title']?.toString().toLowerCase() ?? '';
      final desc = act['description']?.toString().toLowerCase() ?? '';
      final loc = act['location']?.toString().toLowerCase() ?? '';
      final status = act['status']?.toString().toLowerCase() ?? '';

      if (_serviceSearchQuery.isNotEmpty) {
        if (!title.contains(_serviceSearchQuery) &&
            !desc.contains(_serviceSearchQuery) &&
            !loc.contains(_serviceSearchQuery)) {
          return false;
        }
      }

      if (_serviceSelectedFilter == 'Sedang Berjalan') return status == 'active';
      if (_serviceSelectedFilter == 'Mendatang') return status == 'pending';
      if (_serviceSelectedFilter == 'Selesai') return status == 'completed';
      if (_serviceSelectedFilter == 'Dibatalkan') return status == 'cancelled';
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Breadcrumbs ──
        AppBreadcrumbs(
          items: [
            BreadcrumbItem(
              label: 'Beranda',
              icon: Icons.home_rounded,
              onTap: () => setState(() => _activeServiceKey = null),
            ),
            const BreadcrumbItem(
              label: 'Kegiatan',
              icon: Icons.event_note_rounded,
            ),
          ],
        ),
        const SizedBox(height: 4),

        // ── Header Row ──
        _buildServiceHeader(
          title: 'Kegiatan Komunitas',
          subtitle: 'Pantau kebutuhan terbuka, agenda, dan progres kontrak kerja kegiatan Anda.',
          actionLabel: 'Buat Kegiatan Baru',
          onActionTap: _showCreateActivityDialog,
          isDark: isDark,
          isDesktop: isDesktop,
        ),
        const SizedBox(height: 24),

        // ── 5 Metric KPI Cards ──
        _buildServiceSummaryMetrics(metricData, isDark, isDesktop),
        const SizedBox(height: 24),

        // ── Search & Filter Pills ──
        _buildServiceSearchAndFilters(
          filterOptions: filterOptions,
          hintText: 'Cari kegiatan, agenda, atau lokasi...',
          isDark: isDark,
          isDesktop: isDesktop,
        ),
        const SizedBox(height: 20),

        // ── Grid of Cards (Image 1 Style) ──
        if (filtered.isEmpty)
          _buildEmptyServicePlaceholder('Belum ada kegiatan yang sesuai filter pencarian.', isDark)
        else
          _buildServiceCardsGrid(
            items: filtered.map((act) => _buildProyekStyleActivityCard(act, isDark)).toList(),
            isDesktop: isDesktop,
            screenWidth: screenWidth,
          ),
      ],
    );
  }

  // 2. ANGGOTA KOMUNITAS SERVICE VIEW
  Widget _buildAnggotaServiceView(bool isDark, bool isDesktop, double screenWidth) {
    final total = _members.length;
    final koordinator = _members.where((m) => (m['role']?.toString().toLowerCase().contains('koordinator') ?? false)).length;
    final fotoVideo = _members.where((m) {
      final r = m['role']?.toString().toLowerCase() ?? '';
      return r.contains('foto') || r.contains('video') || r.contains('kreator');
    }).length;
    final mitra = _members.where((m) => (m['role']?.toString().toLowerCase().contains('mitra') ?? false)).length;
    final aktif = _members.where((m) => (m['status']?.toString().toLowerCase() == 'active')).length;

    final metricData = [
      {
        'status': 'Semua',
        'label': 'Total Anggota',
        'value': total.toString(),
        'icon': Icons.folder_special_rounded,
        'color': const Color(0xFF6366F1),
      },
      {
        'status': 'Koordinator',
        'label': 'Koordinator Event',
        'value': koordinator.toString(),
        'icon': Icons.campaign_rounded,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'status': 'Kreator',
        'label': 'Kreator Foto & Video',
        'value': fotoVideo.toString(),
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'status': 'Mitra',
        'label': 'Mitra Studio / Vendor',
        'value': mitra.toString(),
        'icon': Icons.hourglass_top_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'status': 'Aktif',
        'label': 'Anggota Aktif',
        'value': aktif.toString(),
        'icon': Icons.check_circle_rounded,
        'color': const Color(0xFF3B82F6),
      },
    ];

    final filterOptions = [
      {'key': 'Semua', 'label': 'Semua', 'count': total},
      {'key': 'Koordinator', 'label': 'Koordinator', 'count': koordinator},
      {'key': 'Kreator', 'label': 'Kreator', 'count': fotoVideo},
      {'key': 'Mitra', 'label': 'Mitra', 'count': mitra},
      {'key': 'Aktif', 'label': 'Aktif', 'count': aktif},
    ];

    final filtered = _members.where((m) {
      final user = (m['user'] as Map<String, dynamic>?) ?? {};
      final name = (user['name'] ?? m['name'] ?? '').toString().toLowerCase();
      final role = (m['role'] ?? '').toString().toLowerCase();
      final subRole = (user['sub_role'] ?? '').toString().toLowerCase();

      if (_serviceSearchQuery.isNotEmpty) {
        if (!name.contains(_serviceSearchQuery) &&
            !role.contains(_serviceSearchQuery) &&
            !subRole.contains(_serviceSearchQuery)) {
          return false;
        }
      }

      if (_serviceSelectedFilter == 'Koordinator') return role.contains('koordinator');
      if (_serviceSelectedFilter == 'Kreator') return role.contains('foto') || role.contains('video') || role.contains('kreator');
      if (_serviceSelectedFilter == 'Mitra') return role.contains('mitra');
      if (_serviceSelectedFilter == 'Aktif') return m['status']?.toString().toLowerCase() == 'active';
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppBreadcrumbs(
          items: [
            BreadcrumbItem(
              label: 'Beranda',
              icon: Icons.home_rounded,
              onTap: () => setState(() => _activeServiceKey = null),
            ),
            const BreadcrumbItem(
              label: 'Anggota',
              icon: Icons.groups_rounded,
            ),
          ],
        ),
        const SizedBox(height: 4),

        _buildServiceHeader(
          title: 'Anggota & Mitra',
          subtitle: 'Pantau kreator binaan, portofolio mitra, dan status keaktifan anggota ekosistem.',
          actionLabel: 'Rekrut Anggota Baru',
          onActionTap: _showAddMemberDialog,
          isDark: isDark,
          isDesktop: isDesktop,
        ),
        const SizedBox(height: 24),

        _buildServiceSummaryMetrics(metricData, isDark, isDesktop),
        const SizedBox(height: 24),

        _buildServiceSearchAndFilters(
          filterOptions: filterOptions,
          hintText: 'Cari nama anggota, peran, atau sub-role kreator...',
          isDark: isDark,
          isDesktop: isDesktop,
        ),
        const SizedBox(height: 20),

        if (filtered.isEmpty)
          _buildEmptyServicePlaceholder('Belum ada anggota yang sesuai filter pencarian.', isDark)
        else
          _buildServiceCardsGrid(
            items: filtered.map((m) => _buildProyekStyleMemberCard(m, isDark)).toList(),
            isDesktop: isDesktop,
            screenWidth: screenWidth,
          ),
      ],
    );
  }

  // 3. PENGUMUMAN KOMUNITAS SERVICE VIEW
  Widget _buildPengumumanServiceView(bool isDark, bool isDesktop, double screenWidth) {
    final total = _announcements.length;
    final umum = _announcements.where((a) => (a['type']?.toString().toLowerCase() == 'general')).length;
    final event = _announcements.where((a) => (a['type']?.toString().toLowerCase() == 'event')).length;
    final penting = _announcements.where((a) => (a['type']?.toString().toLowerCase() == 'important')).length;
    final prioritasTinggi = _announcements.where((a) {
      final p = a['priority']?.toString().toLowerCase() ?? '';
      return p == 'high' || p == 'urgent';
    }).length;

    final metricData = [
      {
        'status': 'Semua',
        'label': 'Total Rilis',
        'value': total.toString(),
        'icon': Icons.folder_special_rounded,
        'color': const Color(0xFF6366F1),
      },
      {
        'status': 'Umum',
        'label': 'Pengumuman Umum',
        'value': umum.toString(),
        'icon': Icons.campaign_rounded,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'status': 'Event',
        'label': 'Agenda & Event',
        'value': event.toString(),
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'status': 'Penting',
        'label': 'Info Penting',
        'value': penting.toString(),
        'icon': Icons.hourglass_top_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'status': 'Prioritas',
        'label': 'Prioritas Tinggi',
        'value': prioritasTinggi.toString(),
        'icon': Icons.check_circle_rounded,
        'color': const Color(0xFF3B82F6),
      },
    ];

    final filterOptions = [
      {'key': 'Semua', 'label': 'Semua', 'count': total},
      {'key': 'Umum', 'label': 'Umum', 'count': umum},
      {'key': 'Event', 'label': 'Event', 'count': event},
      {'key': 'Penting', 'label': 'Penting', 'count': penting},
      {'key': 'Prioritas', 'label': 'Prioritas', 'count': prioritasTinggi},
    ];

    final filtered = _announcements.where((ann) {
      final title = ann['title']?.toString().toLowerCase() ?? '';
      final content = ann['content']?.toString().toLowerCase() ?? '';
      final type = ann['type']?.toString().toLowerCase() ?? '';
      final priority = ann['priority']?.toString().toLowerCase() ?? '';

      if (_serviceSearchQuery.isNotEmpty) {
        if (!title.contains(_serviceSearchQuery) && !content.contains(_serviceSearchQuery)) {
          return false;
        }
      }

      if (_serviceSelectedFilter == 'Umum') return type == 'general';
      if (_serviceSelectedFilter == 'Event') return type == 'event';
      if (_serviceSelectedFilter == 'Penting') return type == 'important';
      if (_serviceSelectedFilter == 'Prioritas') return priority == 'high' || priority == 'urgent';
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppBreadcrumbs(
          items: [
            BreadcrumbItem(
              label: 'Beranda',
              icon: Icons.home_rounded,
              onTap: () => setState(() => _activeServiceKey = null),
            ),
            const BreadcrumbItem(
              label: 'Pengumuman',
              icon: Icons.campaign_rounded,
            ),
          ],
        ),
        const SizedBox(height: 4),

        _buildServiceHeader(
          title: 'Publikasi & Pengumuman',
          subtitle: 'Pantau kebutuhan terbuka, siaran event, dan pesan promosi resmi komunitas.',
          actionLabel: 'Rilis Pengumuman Baru',
          onActionTap: _showCreateAnnouncementDialog,
          isDark: isDark,
          isDesktop: isDesktop,
        ),
        const SizedBox(height: 24),

        _buildServiceSummaryMetrics(metricData, isDark, isDesktop),
        const SizedBox(height: 24),

        _buildServiceSearchAndFilters(
          filterOptions: filterOptions,
          hintText: 'Cari judul pengumuman atau konten pesan rilis...',
          isDark: isDark,
          isDesktop: isDesktop,
        ),
        const SizedBox(height: 20),

        if (filtered.isEmpty)
          _buildEmptyServicePlaceholder('Belum ada pengumuman yang sesuai filter pencarian.', isDark)
        else
          _buildServiceCardsGrid(
            items: filtered.map((ann) => _buildProyekStyleAnnouncementCard(ann, isDark)).toList(),
            isDesktop: isDesktop,
            screenWidth: screenWidth,
          ),
      ],
    );
  }

  // 4. KOLABORASI KOMUNITAS SERVICE VIEW
  Widget _buildKolaborasiServiceView(bool isDark, bool isDesktop, double screenWidth) {
    final kolaborasiList = [
      {
        'title': 'Hunting Foto Akbar & Landscape Nusantara 2026',
        'description': 'Kolaborasi terbuka komunitas fotografi, videografi, dan creator talent di lokasi alam terbuka.',
        'partner': 'Mitra Studio & EO Kreatif Kreavana',
        'partner_id': '01a0d66e-0e74-723a-8e4c-4a09b889480f',
        'status': 'active',
        'budget': 'Rp 12.500.000',
        'date': '28 Nov 2026',
        'progress': 0.85,
        'tag': 'Kontrak Kolaborasi',
      },
      {
        'title': 'Produksi Video Dokumenter Adat & Budaya Lokal',
        'description': 'Proyek patungan dokumentasi kebudayaan, melibatkan pilot drone, editor sinematik dan narator.',
        'partner': 'Dinas Pariwisata & Sponsor Brand',
        'partner_id': '01a0d66e-08c1-709a-a14f-6219f0d05608',
        'status': 'pending',
        'budget': 'Rp 28.000.000',
        'date': '05 Des 2026',
        'progress': 0.40,
        'tag': 'Kemitraan Sponsor',
      },
      {
        'title': 'Pameran Visual Street Photography & Desain Poster',
        'description': 'Ajang kurasi karya terbaik anggota komunitas dipajang di creative hub dan ruang galeri publik.',
        'partner': 'Galeri Seni Ruang Rupa',
        'partner_id': '01a0d66e-129b-70ed-9512-9973038028ef',
        'status': 'active',
        'budget': 'Rp 8.500.000',
        'date': '12 Jan 2027',
        'progress': 0.60,
        'tag': 'Inisiatif Kreatif',
      },
      {
        'title': 'Sharing Session Sponsorship & Pitching Investor',
        'description': 'Bedah portofolio dan simulasi proposal pendanaan event komunitas bersama praktisi industri.',
        'partner': 'Tim Manajemen Kreavana',
        'partner_id': '01a0d66e-048c-7258-bd70-583db0cbf60a',
        'status': 'completed',
        'budget': 'Rp 5.000.000',
        'date': '10 Okt 2026',
        'progress': 1.0,
        'tag': 'Edukasi Komunitas',
      },
    ];

    final total = kolaborasiList.length;
    final berjalan = kolaborasiList.where((k) => k['status'] == 'active').length;
    final pending = kolaborasiList.where((k) => k['status'] == 'pending').length;
    final selesai = kolaborasiList.where((k) => k['status'] == 'completed').length;

    final metricData = [
      {
        'status': 'Semua',
        'label': 'Total Kolaborasi',
        'value': total.toString(),
        'icon': Icons.folder_special_rounded,
        'color': const Color(0xFF6366F1),
      },
      {
        'status': 'Berjalan',
        'label': 'Inisiatif Berjalan',
        'value': berjalan.toString(),
        'icon': Icons.rocket_launch_rounded,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'status': 'Menunggu',
        'label': 'Menunggu Mitra',
        'value': pending.toString(),
        'icon': Icons.hourglass_top_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'status': 'Selesai',
        'label': 'Selesai',
        'value': selesai.toString(),
        'icon': Icons.check_circle_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'status': 'Mitra',
        'label': 'Jejaring Mitra',
        'value': '5 Entitas',
        'icon': Icons.handshake_rounded,
        'color': const Color(0xFF3B82F6),
      },
    ];

    final filterOptions = [
      {'key': 'Semua', 'label': 'Semua', 'count': total},
      {'key': 'Berjalan', 'label': 'Berjalan', 'count': berjalan},
      {'key': 'Menunggu', 'label': 'Menunggu', 'count': pending},
      {'key': 'Selesai', 'label': 'Selesai', 'count': selesai},
    ];

    final filtered = kolaborasiList.where((k) {
      final t = k['title']?.toString().toLowerCase() ?? '';
      final d = k['description']?.toString().toLowerCase() ?? '';
      if (_serviceSearchQuery.isNotEmpty) {
        if (!t.contains(_serviceSearchQuery) && !d.contains(_serviceSearchQuery)) return false;
      }
      if (_serviceSelectedFilter == 'Berjalan') return k['status'] == 'active';
      if (_serviceSelectedFilter == 'Menunggu') return k['status'] == 'pending';
      if (_serviceSelectedFilter == 'Selesai') return k['status'] == 'completed';
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppBreadcrumbs(
          items: [
            BreadcrumbItem(
              label: 'Beranda',
              icon: Icons.home_rounded,
              onTap: () => setState(() => _activeServiceKey = null),
            ),
            const BreadcrumbItem(
              label: 'Kolaborasi Komunitas',
              icon: Icons.handshake_rounded,
            ),
          ],
        ),
        const SizedBox(height: 4),

        _buildServiceHeader(
          title: 'Kolaborasi Komunitas',
          subtitle: 'Pantau inisiatif kolaborasi lintas kreator, proyek patungan, dan kemitraan brand.',
          actionLabel: 'Mulai Kolaborasi Baru',
          onActionTap: _showCreateActivityDialog,
          isDark: isDark,
          isDesktop: isDesktop,
        ),
        const SizedBox(height: 24),

        _buildServiceSummaryMetrics(metricData, isDark, isDesktop),
        const SizedBox(height: 24),

        _buildServiceSearchAndFilters(
          filterOptions: filterOptions,
          hintText: 'Cari judul kolaborasi, inisiatif, atau mitra sponsor...',
          isDark: isDark,
          isDesktop: isDesktop,
        ),
        const SizedBox(height: 20),

        if (filtered.isEmpty)
          _buildEmptyServicePlaceholder('Belum ada inisiatif yang sesuai filter pencarian.', isDark)
        else
          _buildServiceCardsGrid(
            items: filtered.map((item) => _buildProyekStyleKolaborasiCard(item, isDark)).toList(),
            isDesktop: isDesktop,
            screenWidth: screenWidth,
          ),
      ],
    );
  }

  // ── REUSABLE SERVICE HEADER (IMAGE 1 STYLE) ──────────────────────────────
  Widget _buildServiceHeader({
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onActionTap,
    required bool isDark,
    required bool isDesktop,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!isDesktop)
          Padding(
            padding: const EdgeInsets.only(right: 14),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                setState(() => _activeServiceKey = null);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardBg : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                ),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _fetchCommunityData,
          tooltip: 'Segarkan data realtime',
          style: IconButton.styleFrom(
            backgroundColor: isDark ? AppTheme.cardBg : Colors.white,
            side: BorderSide(
              color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (isDesktop) ...[
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: onActionTap,
            icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            label: Text(
              actionLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _commPurple,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── REUSABLE 5 KPI SUMMARY METRICS (IMAGE 1 STYLE) ────────────────────────
  Widget _buildServiceSummaryMetrics(List<Map<String, dynamic>> metricData, bool isDark, bool isDesktop) {
    if (isDesktop) {
      return Row(
        children: metricData.map((m) {
          final isSelected = _serviceSelectedFilter == m['status'];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _buildCommonMetricCard(m, isSelected, isDark),
            ),
          );
        }).toList(),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: metricData.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 10),
        itemBuilder: (context, idx) {
          final m = metricData[idx];
          final isSelected = _serviceSelectedFilter == m['status'];
          return SizedBox(
            width: 155,
            child: _buildCommonMetricCard(m, isSelected, isDark),
          );
        },
      ),
    );
  }

  Widget _buildCommonMetricCard(Map<String, dynamic> m, bool isSelected, bool isDark) {
    final color = m['color'] as Color;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() => _serviceSelectedFilter = m['status'] as String);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardBg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(m['icon'] as IconData, size: 18, color: color),
                ),
                Text(
                  m['value'] as String,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              m['label'] as String,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? color
                    : (isDark ? AppTheme.textMuted : Colors.grey.shade600),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── REUSABLE SEARCH AND FILTER BAR (IMAGE 1 STYLE) ────────────────────────
  Widget _buildServiceSearchAndFilters({
    required List<Map<String, dynamic>> filterOptions,
    required String hintText,
    required bool isDark,
    required bool isDesktop,
  }) {
    final searchField = TextField(
      controller: _serviceSearchCtrl,
      onChanged: (v) => setState(() => _serviceSearchQuery = v.trim().toLowerCase()),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          fontSize: 13,
          color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
        ),
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _serviceSearchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _serviceSearchCtrl.clear();
                  setState(() => _serviceSearchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: isDark ? AppTheme.cardBg : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _commPurple, width: 1.6),
        ),
      ),
    );

    final filterChips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filterOptions.map((opt) {
          final key = opt['key'] as String;
          final label = opt['label'] as String;
          final count = opt['count'] as int;
          final isSel = _serviceSelectedFilter == key;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSel
                          ? Colors.white.withValues(alpha: 0.25)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
              selected: isSel,
              selectedColor: _commPurple,
              backgroundColor: isDark ? AppTheme.cardBg : Colors.white,
              side: BorderSide(
                color: isSel
                    ? _commPurple
                    : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
              ),
              labelStyle: TextStyle(
                color: isSel
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey.shade800),
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
              onSelected: (val) {
                if (val) setState(() => _serviceSelectedFilter = key);
              },
            ),
          );
        }).toList(),
      ),
    );

    if (isDesktop) {
      return Row(
        children: [
          Expanded(flex: 3, child: searchField),
          const SizedBox(width: 16),
          Expanded(flex: 4, child: filterChips),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        searchField,
        const SizedBox(height: 12),
        filterChips,
      ],
    );
  }

  // ── REUSABLE 2-COLUMN RESPONSIVE CARD GRID (IMAGE 1 STYLE) ────────────────
  Widget _buildServiceCardsGrid({
    required List<Widget> items,
    required bool isDesktop,
    required double screenWidth,
  }) {
    if (isDesktop) {
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: items.map((cardWidget) {
          final cardWidth = (screenWidth > 1260 ? 1260 : screenWidth) / 2 - 40;
          return SizedBox(
            width: cardWidth > 450 ? cardWidth : double.infinity,
            child: cardWidget,
          );
        }).toList(),
      );
    }

    return Column(
      children: items.map((cardWidget) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: cardWidget,
        );
      }).toList(),
    );
  }

  Widget _buildEmptyServicePlaceholder(String message, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── EXACT CARDS (IMAGE 1 SPEC) ────────────────────────────────────────────

  // Card 1: Kegiatan
  Widget _buildProyekStyleActivityCard(Map<String, dynamic> act, bool isDark) {
    final id = act['id']?.toString() ?? '';
    final title = act['title']?.toString() ?? 'Kegiatan Komunitas';
    final desc = act['description']?.toString() ?? 'Penyelenggaraan agenda kreatif bersama mitra komunitas.';
    final location = act['location']?.toString() ?? 'Lokasi Ditentukan';
    final dateStr = act['activity_date']?.toString();
    final maxPart = act['max_participants']?.toString() ?? '25';
    final status = act['status']?.toString() ?? 'active';

    String formattedDate = 'Segera';
    if (dateStr != null) {
      try {
        final parsed = DateTime.parse(dateStr);
        formattedDate = DateFormat('dd MMM yyyy').format(parsed);
      } catch (_) {
        formattedDate = dateStr;
      }
    }

    final isDone = status == 'completed';
    final statusColor = isDone
        ? const Color(0xFF3B82F6)
        : (status == 'active'
            ? const Color(0xFF10B981)
            : (status == 'cancelled' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)));

    final statusText = isDone
        ? 'Selesai'
        : (status == 'active'
            ? 'Kontrak Aktif'
            : (status == 'cancelled' ? 'Dibatalkan' : 'Menunggu Persetujuan'));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_available_rounded,
                      size: 14,
                      color: Color(0xFF10B981),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Kegiatan Komunitas',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• $statusText',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          Text(
            desc,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category_outlined, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Agenda Komunitas',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_alt_outlined, size: 13, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 4),
                    Text(
                      'Maks. $maxPart Peserta',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 13, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Lokasi: $location',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.open_in_new_rounded, size: 11, color: Colors.grey.shade500),
                ],
              ),
              const Text(
                '75%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              value: 0.75,
              minHeight: 4,
              backgroundColor: Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation(Color(0xFF10B981)),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  _openDirectChat(
                    targetUserId: act['creator_id']?.toString() ?? act['user_id']?.toString(),
                    targetUserName: title,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                    ),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _showActivityDetail(act),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Text(
                  'Detail Kegiatan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 16, color: Colors.grey),
                padding: EdgeInsets.zero,
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'detail',
                    child: Text('Lihat Detail Lengkap', style: TextStyle(fontSize: 12)),
                  ),
                  if (status != 'active')
                    const PopupMenuItem(
                      value: 'active',
                      child: Text('Tandai Sedang Berjalan', style: TextStyle(fontSize: 12)),
                    ),
                  if (status != 'completed')
                    const PopupMenuItem(
                      value: 'completed',
                      child: Text('Tandai Selesai', style: TextStyle(fontSize: 12)),
                    ),
                  if (status != 'cancelled')
                    const PopupMenuItem(
                      value: 'cancelled',
                      child: Text('Batalkan Kegiatan', style: TextStyle(fontSize: 12)),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Hapus Kegiatan', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                  ),
                ],
                onSelected: (val) {
                  if (val == 'detail') {
                    _showActivityDetail(act);
                  } else if (val == 'delete') {
                    _confirmDeleteActivity(id, title);
                  } else {
                    _updateActivityStatus(id, val);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Card 2: Anggota
  Widget _buildProyekStyleMemberCard(Map<String, dynamic> m, bool isDark) {
    final user = (m['user'] as Map<String, dynamic>?) ?? {};
    final name = (user['name'] ?? m['name'] ?? 'Anggota Komunitas').toString();
    final role = (m['role'] ?? 'Anggota Aktif').toString();
    final subRole = (user['sub_role'] ?? 'Kreator Seni Visual').toString();
    final username = (user['username'] ?? 'kreator_kreavana').toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 14,
                      color: Color(0xFF8B5CF6),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Talenta Komunitas',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '• Anggota Aktif',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          Text(
            'Kreator aktif berkontribusi dalam inisiatif portofolio, produksi karya dan agenda komunitas.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.badge_outlined, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      role,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_outline_rounded, size: 13, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 4),
                    Text(
                      subRole,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 13, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Kreator: @$username',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.open_in_new_rounded, size: 11, color: Colors.grey.shade500),
                ],
              ),
              const Text(
                '100%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              value: 1.0,
              minHeight: 4,
              backgroundColor: Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation(Color(0xFF10B981)),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  _openDirectChat(
                    targetUserId: m['user_id']?.toString() ?? user['id']?.toString(),
                    targetUserName: name,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                    ),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _showMemberDetail(m),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Text(
                  'Detail Anggota',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Card 3: Pengumuman
  Widget _buildProyekStyleAnnouncementCard(Map<String, dynamic> ann, bool isDark) {
    final title = ann['title']?.toString() ?? 'Pengumuman Komunitas';
    final content = ann['content']?.toString() ?? '';
    final type = ann['type']?.toString() ?? 'general';
    final priority = ann['priority']?.toString() ?? 'normal';

    final isUrgent = priority == 'urgent' || priority == 'high';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.campaign_rounded,
                      size: 14,
                      color: Color(0xFF8B5CF6),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Siaran Resmi',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isUrgent ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isUrgent ? '• Prioritas Tinggi' : '• Dipublikasikan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          Text(
            content,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category_outlined, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Tipe: ${type.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 4),
                    Text(
                      'Prioritas ${priority.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined, size: 13, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Pengirim: Admin Komunitas',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.open_in_new_rounded, size: 11, color: Colors.grey.shade500),
                ],
              ),
              const Text(
                '100%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              value: 1.0,
              minHeight: 4,
              backgroundColor: Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation(Color(0xFF10B981)),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                onPressed: () => _confirmDeleteAnnouncement(ann),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _showAnnouncementDetail(ann),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Text(
                  'Detail Pengumuman',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Card 4: Kolaborasi
  Widget _buildProyekStyleKolaborasiCard(Map<String, dynamic> item, bool isDark) {
    final title = item['title']?.toString() ?? 'Kolaborasi Komunitas';
    final desc = item['description']?.toString() ?? '';
    final partner = item['partner']?.toString() ?? 'Mitra Ekosistem';
    final budget = item['budget']?.toString() ?? 'Rp 10.000.000';
    final date = item['date']?.toString() ?? 'Segera';
    final progress = (item['progress'] as num?)?.toDouble() ?? 0.5;
    final status = item['status']?.toString() ?? 'active';

    final isDone = status == 'completed';
    final statusColor = isDone
        ? const Color(0xFF3B82F6)
        : (status == 'active' ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

    final statusText = isDone ? 'Selesai' : (status == 'active' ? 'Kontrak Aktif' : 'Menunggu Persetujuan');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.handshake_rounded,
                      size: 14,
                      color: Color(0xFF10B981),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Kontrak Kerja',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• $statusText',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          Text(
            desc,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.business_center_outlined, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Kontrak Proyek',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.payments_outlined, size: 13, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 4),
                    Text(
                      budget,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.handshake_outlined, size: 13, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Mitra: $partner',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.open_in_new_rounded, size: 11, color: Colors.grey.shade500),
                ],
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  _openDirectChat(
                    targetUserId: item['partner_id']?.toString(),
                    targetUserName: partner,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                    ),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _showKolaborasiDetail(item),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Text(
                  'Detail Kolaborasi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 1. HERO BANNER: EKOSISTEM KREATIVITAS ───────────────────────────────
  Widget _buildEcosystemHeroBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2E1065), const Color(0xFF1E1B4B)]
              : [const Color(0xFFFAF5FF), const Color(0xFFF3E8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _commPurple.withValues(alpha: isDark ? 0.4 : 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _commPurple.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hub_rounded, color: _commPurple, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _commPurple,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'KREAVANA EKOSISTEM',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '✓ Terverifikasi Admin',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ekosistem Kreativitas, Peluang dan Kolaborasi',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tempat di mana potensi bertemu kebutuhan, dan menjadi nilai nyata.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showCreateActivityDialog(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Buat Kegiatan & Agenda'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _commPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showCreateAnnouncementDialog(),
                icon: const Icon(Icons.campaign_outlined, size: 16),
                label: const Text('Rilis Pengumuman & Promosi'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _commPurple,
                  side: const BorderSide(color: _commPurple),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showAddMemberDialog(),
                icon: const Icon(Icons.person_add_outlined, size: 16),
                label: const Text('Rekrut / Undang Anggota'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : Colors.black87,
                  side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 2. ALUR KERJA KOMUNITAS (6 TAHAPAN SISTEMATIS) ──────────────────────
  Widget _buildWorkflowStepperSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _commPurple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.alt_route_rounded, color: _commPurple, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Alur Kerja Komunitas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '6 Tahap Ekosistem',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Siklus tahapan pengelolaan komunitas Kreavana dari registrasi hingga evaluasi terpadu.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 700;
              if (isNarrow) {
                return Column(
                  children: _workflowSteps.map((step) {
                    final stepMap = step is Map<String, dynamic>
                        ? step
                        : Map<String, dynamic>.from(step as Map);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildWorkflowStepCard(stepMap, isDark),
                    );
                  }).toList(),
                );
              }
              // Grid 3 columns for desktop/tablet
              final rows = <Widget>[];
              for (var i = 0; i < _workflowSteps.length; i += 3) {
                final chunk = _workflowSteps.skip(i).take(3).toList();
                rows.add(
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: chunk.map((step) {
                      final stepMap = step is Map<String, dynamic>
                          ? step
                          : Map<String, dynamic>.from(step as Map);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: _buildWorkflowStepCard(stepMap, isDark),
                        ),
                      );
                    }).toList(),
                  ),
                );
                if (i + 3 < _workflowSteps.length) {
                  rows.add(const SizedBox(height: 10));
                }
              }
              return Column(children: rows);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowStepCard(Map<String, dynamic> step, bool isDark) {
    final numStep = step['step'] ?? 1;
    final title = step['title']?.toString() ?? '';
    final actor = step['actor']?.toString() ?? '';
    final status = step['status']?.toString() ?? 'active';

    Color stepColor = _commPurple;
    if (numStep == 2) stepColor = const Color(0xFF0284C7);
    if (numStep == 3) stepColor = const Color(0xFFF59E0B);
    if (numStep == 4) stepColor = const Color(0xFF10B981);
    if (numStep == 5) stepColor = const Color(0xFFEC4899);
    if (numStep == 6) stepColor = const Color(0xFF6366F1);

    return InkWell(
      onTap: () => _showWorkflowStepDetail(step),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1D2E) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: stepColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  numStep.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: stepColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          actor,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: stepColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status == 'completed' || status == 'verified' ? '✓ Aktif' : '• Berjalan',
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ── 3. METRIC CARDS ─────────────────────────────────────────────────────
  Widget _buildMetricCards(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        Widget buildCard(Map<String, dynamic> m) {
          final color = (m['color'] as Color?) ?? _commPurple;
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
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        (m['icon'] as IconData?) ?? Icons.groups_outlined,
                        color: color,
                        size: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  m['value'] as String,
                  style: const TextStyle(
                    fontSize: 22,
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
          for (var i = 0; i < _metrics.length; i += 2) {
            final rc = <Widget>[Expanded(child: buildCard(_metrics[i]))];
            if (i + 1 < _metrics.length) {
              rc.add(const SizedBox(width: 12));
              rc.add(Expanded(child: buildCard(_metrics[i + 1])));
            }
            if (i > 0) rows.add(const SizedBox(height: 12));
            rows.add(Row(children: rc));
          }
          return Column(children: rows);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _metrics.map((m) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: buildCard(m),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  IconData _resolvePillarIcon(dynamic iconData) {
    if (iconData is IconData) return iconData;
    if (iconData is String) {
      switch (iconData.toLowerCase().trim()) {
        case 'search':
          return Icons.search_rounded;
        case 'handshake':
          return Icons.handshake_rounded;
        case 'work':
          return Icons.work_outline_rounded;
        case 'payments':
          return Icons.payments_outlined;
        case 'verified':
          return Icons.verified_outlined;
        default:
          return Icons.star_border_rounded;
      }
    }
    return Icons.star_border_rounded;
  }

  Color _resolveEntityColor(Map<String, dynamic> ent) {
    final rawColor = ent['color'];
    if (rawColor is Color) return rawColor;
    if (rawColor is int) return Color(rawColor);
    final id = ent['id']?.toString() ?? '';
    switch (id) {
      case 'creator':
        return const Color(0xFFEF4444);
      case 'client':
        return const Color(0xFF0284C7);
      case 'partner':
        return const Color(0xFFF97316);
      case 'sponsor':
        return const Color(0xFF10B981);
      case 'team':
        return const Color(0xFF2563EB);
      default:
        return _commPurple;
    }
  }

  // ── 4. EKOSISTEM HUB & 5 ENTITAS KOLABORATIF ─────────────────────────────
  Widget _buildEcosystemHubSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _commPurple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.share_outlined, color: _commPurple, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Ekosistem Kolaborasi Kreatif',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _commPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '5 Pilar Utama',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _commPurple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Komunitas menghubungkan 5 entitas kunci dengan timbal balik manfaat yang jelas dan berkesinambungan.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 14),

          // 5 Core Pillars pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _corePillars.map((p) {
                final name = p['name']?.toString() ?? '';
                final icon = _resolvePillarIcon(p['icon']);
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _commPurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _commPurple.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 14, color: _commPurple),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _commPurple,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // 5 Entities Cards
          Column(
            children: _ecosystemEntities.map((ent) {
              final entMap = ent is Map<String, dynamic>
                  ? ent
                  : Map<String, dynamic>.from(ent as Map);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildEntityCard(entMap, isDark),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEntityCard(Map<String, dynamic> ent, bool isDark) {
    final name = ent['name']?.toString() ?? '';
    final subtitle = ent['subtitle']?.toString() ?? '';
    final tag = ent['tag']?.toString() ?? '';
    final color = _resolveEntityColor(ent);
    final benefitsReceived = (ent['benefits_received'] as List<dynamic>?) ?? [];
    final benefitsGiven = (ent['benefits_given'] as List<dynamic>?) ?? [];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B2E) : const Color(0xFFF9FAFD),
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
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manfaat yang Didapat:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        benefitsReceived.isNotEmpty ? '✓ ${benefitsReceived.first}' : '-',
                        style: const TextStyle(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _commPurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manfaat ke Kreavana:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _commPurple,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        benefitsGiven.isNotEmpty ? '✓ ${benefitsGiven.first}' : '-',
                        style: const TextStyle(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showEntityDetailModal(ent),
              icon: const Icon(Icons.visibility_outlined, size: 14),
              label: const Text('Lihat Seluruh Manfaat Timbal Balik', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 5. PUSAT KENDALI KOMUNITAS (INTERACTIVE WORKSPACES TABS) ─────────────
  Widget _buildInteractiveWorkspacesSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pusat Kendali Komunitas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Kreavana Community Hub',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                _buildTabButton(0, 'Kegiatan & Agenda (${_activities.length})', Icons.event_note_rounded),
                const SizedBox(width: 8),
                _buildTabButton(1, 'Anggota & Mitra (${_members.length})', Icons.groups_rounded),
                const SizedBox(width: 8),
                _buildTabButton(2, 'Publikasi & Promosi (${_announcements.length})', Icons.campaign_rounded),
                const SizedBox(width: 8),
                _buildTabButton(3, 'Evaluasi & Dampak', Icons.insights_rounded),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(18),
            child: _buildSelectedTabContent(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _commPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _commPurple : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent(bool isDark) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildActivitiesTab(isDark);
      case 1:
        return _buildMembersTab(isDark);
      case 2:
        return _buildAnnouncementsTab(isDark);
      case 3:
      default:
        return _buildEvaluationsTab(isDark);
    }
  }

  // TAB 1: KEGIATAN
  Widget _buildActivitiesTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Daftar Kegiatan & Agenda Komunitas',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: _showCreateActivityDialog,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Buat Kegiatan', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _commPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_activities.isEmpty)
          _buildEmptyPlaceholder('Belum ada kegiatan dijadwalkan.', isDark)
        else
          ..._activities.map((act) => _buildActivityItem(act, isDark)),
      ],
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> act, bool isDark) {
    final id = act['id']?.toString() ?? '';
    final title = act['title']?.toString() ?? 'Kegiatan Komunitas';
    final location = act['location']?.toString() ?? 'Lokasi Ditentukan';
    final dateStr = act['activity_date']?.toString();
    final maxPart = act['max_participants']?.toString() ?? '20';
    final status = act['status']?.toString() ?? 'active';

    String formattedDate = 'Segera';
    if (dateStr != null) {
      try {
        final parsed = DateTime.parse(dateStr);
        formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(parsed);
      } catch (_) {
        formattedDate = dateStr;
      }
    }

    final isDone = status == 'completed';
    final statusColor = isDone
        ? const Color(0xFF10B981)
        : (status == 'active' ? _commPurple : const Color(0xFFF59E0B));

    return InkWell(
      onTap: () => _showActivityDetail(act),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1B2E) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.calendar_today_rounded, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 16, color: Colors.grey),
                            padding: EdgeInsets.zero,
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'detail',
                                child: Text('Lihat Detail Lengkap', style: TextStyle(fontSize: 12)),
                              ),
                              if (status != 'active')
                                const PopupMenuItem(
                                  value: 'active',
                                  child: Text('Tandai Sedang Berjalan', style: TextStyle(fontSize: 12)),
                                ),
                              if (status != 'completed')
                                const PopupMenuItem(
                                  value: 'completed',
                                  child: Text('Tandai Selesai', style: TextStyle(fontSize: 12)),
                                ),
                              if (status != 'cancelled')
                                const PopupMenuItem(
                                  value: 'cancelled',
                                  child: Text('Batalkan Kegiatan', style: TextStyle(fontSize: 12)),
                                ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Hapus Kegiatan', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                              ),
                            ],
                            onSelected: (val) {
                              if (val == 'detail') {
                                _showActivityDetail(act);
                              } else if (val == 'delete') {
                                _confirmDeleteActivity(id, title);
                              } else {
                                _updateActivityStatus(id, val);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(formattedDate, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(width: 12),
                      Icon(Icons.place_outlined, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 12, color: _commPurple),
                      const SizedBox(width: 4),
                      Text(
                        'Maksimal $maxPart Peserta',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 2: ANGGOTA & MITRA
  Widget _buildMembersTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Jejaring Anggota & Mitra Ekosistem',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: _showAddMemberDialog,
              icon: const Icon(Icons.person_add_rounded, size: 14),
              label: const Text('Tambah Anggota', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _commPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_members.isEmpty)
          _buildEmptyPlaceholder('Belum ada anggota terdaftar.', isDark)
        else
          ..._members.map((m) => _buildMemberItem(m, isDark)),
      ],
    );
  }

  Widget _buildMemberItem(Map<String, dynamic> m, bool isDark) {
    final user = (m['user'] as Map<String, dynamic>?) ?? {};
    final name = (user['name'] ?? m['name'] ?? 'Anggota Komunitas').toString();
    final role = (m['role'] ?? 'Anggota Aktif').toString();
    final subRole = (user['sub_role'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B2E) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: _commPurple.withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'A',
              style: const TextStyle(fontWeight: FontWeight.bold, color: _commPurple, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _commPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (subRole.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                subRole,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: const Icon(Icons.person_remove_outlined, size: 16, color: Colors.grey),
            tooltip: 'Keluarkan dari Komunitas',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _confirmRemoveMember(m),
          ),
        ],
      ),
    );
  }

  // TAB 3: PUBLIKASI & PENGUMUMAN
  Widget _buildAnnouncementsTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Rilis Publikasi & Pengumuman',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: _showCreateAnnouncementDialog,
              icon: const Icon(Icons.campaign_rounded, size: 14),
              label: const Text('Buat Pengumuman', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _commPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_announcements.isEmpty)
          _buildEmptyPlaceholder('Belum ada pengumuman dirilis.', isDark)
        else
          ..._announcements.map((ann) => _buildAnnouncementItem(ann, isDark)),
      ],
    );
  }

  Widget _buildAnnouncementItem(Map<String, dynamic> ann, bool isDark) {
    final title = ann['title']?.toString() ?? 'Pengumuman';
    final content = ann['content']?.toString() ?? '';
    final type = ann['type']?.toString() ?? 'general';
    final priority = ann['priority']?.toString() ?? 'normal';

    Color badgeColor = _commPurple;
    if (type == 'event') badgeColor = const Color(0xFF10B981);
    if (type == 'warning') badgeColor = const Color(0xFFEF4444);
    if (type == 'important') badgeColor = const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B2E) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      type.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
                  if (priority == 'urgent' || priority == 'high') ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PRIORITAS TINGGI',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.grey),
                    tooltip: 'Hapus Pengumuman',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _confirmDeleteAnnouncement(ann),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // TAB 4: EVALUASI & DAMPAK
  Widget _buildEvaluationsTab(bool isDark) {
    final rating = (_evaluations['average_rating'] as num?)?.toDouble() ?? 4.9;
    final satisfaction = (_evaluations['satisfaction_rate'] as num?)?.toDouble() ?? 98.4;
    final onTime = (_evaluations['on_time_rate'] as num?)?.toDouble() ?? 99.1;
    final impactNotes = _evaluations['impact_summary']?.toString() ??
        'Tingkat kepuasan peserta 98.4%, 0 perselisihan, seluruh agenda berjalan sesuai rundown mutu.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Evaluasi Kegiatan & Laporan Dampak Sosial',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rating Kepuasan', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '$rating / 5.0',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kepuasan Anggota', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      '$satisfaction%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _commPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ketepatan Rundown', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      '$onTime%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _commPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1B2E) : const Color(0xFFF9FAFD),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Catatan Dampak & Pertumbuhan Komunitas:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                impactNotes,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 6. FOKUS AWAL: KOMUNITAS (BERSAMA KITA TUMBUH) ──────────────────────
  Widget _buildFocusEarlySection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC4899).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFFEC4899), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Fokus Awal: Komunitas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Bersama Kita Tumbuh',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEC4899),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Mulai dari komunitas untuk membangun basis pengguna aktif, menguji alur kerja, dan menarik peluang nyata.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 14),
          Column(
            children: _focusSteps.map((step) {
              final title = (step['title'] ?? step).toString();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF10B981)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── DIALOGS & ACTIONS ───────────────────────────────────────────────────
  void _showCreateActivityDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final maxPartCtrl = TextEditingController(text: '25');
    DateTime selectedDate = DateTime.now().add(const Duration(days: 3));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Buat Kegiatan Komunitas Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Judul Kegiatan *', hintText: 'Contoh: Workshop Editing'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locCtrl,
                  decoration: const InputDecoration(labelText: 'Lokasi *', hintText: 'Studio / Alamat Lengkap'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: maxPartCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Maksimal Kuota Peserta'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tanggal Pelaksanaan:'),
                  subtitle: Text(DateFormat('dd MMMM yyyy').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today_rounded),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDlgState(() => selectedDate = picked);
                    }
                  },
                ),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Deskripsi & Arahan Kegiatan'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await CommunityService.createActivity(
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    location: locCtrl.text.trim(),
                    activityDate: selectedDate.toIso8601String(),
                    maxParticipants: int.tryParse(maxPartCtrl.text.trim()),
                  );
                  AppSnackbar.success(context, 'Kegiatan berhasil dijadwalkan!');
                  _fetchCommunityData();
                } catch (e) {
                  AppSnackbar.error(context, 'Gagal membuat kegiatan: $e');
                }
              },
              child: const Text('Jadwalkan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateAnnouncementDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String selectedType = 'general';
    String selectedPriority = 'normal';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Rilis Pengumuman & Promosi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Judul Pengumuman *'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Tipe Pengumuman'),
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('Umum')),
                    DropdownMenuItem(value: 'event', child: Text('Event & Agenda')),
                    DropdownMenuItem(value: 'important', child: Text('Penting')),
                    DropdownMenuItem(value: 'warning', child: Text('Peringatan')),
                  ],
                  onChanged: (val) => setDlgState(() => selectedType = val ?? 'general'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  decoration: const InputDecoration(labelText: 'Prioritas'),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'high', child: Text('Tinggi')),
                    DropdownMenuItem(value: 'urgent', child: Text('Mendesak')),
                  ],
                  onChanged: (val) => setDlgState(() => selectedPriority = val ?? 'normal'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contentCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Isi Pengumuman / Pesan Promosi *'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await CommunityService.createAnnouncement(
                    title: titleCtrl.text.trim(),
                    content: contentCtrl.text.trim(),
                    type: selectedType,
                    priority: selectedPriority,
                  );
                  AppSnackbar.success(context, 'Pengumuman berhasil dipublikasikan!');
                  _fetchCommunityData();
                } catch (e) {
                  AppSnackbar.error(context, 'Gagal membuat pengumuman: $e');
                }
              },
              child: const Text('Publikasikan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMemberDialog() {
    final userIdCtrl = TextEditingController();
    String selectedRole = 'Anggota Aktif Komunitas';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Tambah / Rekrut Anggota Komunitas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: userIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username, Email, atau ID Pengguna *',
                  hintText: 'Contoh: @creator_demo atau email pengguna',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  ActionChip(
                    label: const Text('@creator_demo', style: TextStyle(fontSize: 10)),
                    onPressed: () {
                      setDlgState(() => userIdCtrl.text = 'creator_demo');
                    },
                  ),
                  ActionChip(
                    label: const Text('@animator_demo', style: TextStyle(fontSize: 10)),
                    onPressed: () {
                      setDlgState(() => userIdCtrl.text = 'animator_demo');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: const InputDecoration(labelText: 'Peran dalam Komunitas'),
                items: const [
                  DropdownMenuItem(value: 'Koordinator Event & Agenda', child: Text('Koordinator Event')),
                  DropdownMenuItem(value: 'Kreator Foto & Kurator', child: Text('Kreator Foto')),
                  DropdownMenuItem(value: 'Kreator Video & Dokumentasi', child: Text('Kreator Video')),
                  DropdownMenuItem(value: 'Mitra Studio & Perlengkapan', child: Text('Mitra Studio')),
                  DropdownMenuItem(value: 'Anggota Aktif Komunitas', child: Text('Anggota Aktif')),
                ],
                onChanged: (val) => setDlgState(() => selectedRole = val ?? 'Anggota Aktif Komunitas'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final input = userIdCtrl.text.trim();
                if (input.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await CommunityService.addMember(
                    userId: input,
                    role: selectedRole,
                  );
                  if (mounted) {
                    AppSnackbar.success(context, 'Anggota berhasil ditambahkan ke komunitas!');
                  }
                  _fetchCommunityData();
                } catch (e) {
                  if (mounted) {
                    AppSnackbar.error(context, 'Gagal menambah anggota: $e');
                  }
                }
              },
              child: const Text('Tambahkan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDirectChat({required String? targetUserId, String? targetUserName}) async {
    String cleanId = targetUserId?.trim() ?? '';

    // Fallback ke akun mitra demo jika targetUserId kosong
    if (cleanId.isEmpty) {
      cleanId = '01a0d66e-0e74-723a-8e4c-4a09b889480f'; // Kreavana Demo Event Organizer
    }

    // Jika target adalah akun sendiri, arahkan ke admin demo
    if (widget.user.id != null && widget.user.id == cleanId) {
      cleanId = '01a0d66e-048c-7258-bd70-583db0cbf60a'; // Admin Kreavana
    }

    final nameDisplay = targetUserName != null && targetUserName.isNotEmpty
        ? targetUserName
        : 'Kontak Mitra';

    // Tampilkan modal loading saat menghubungkan ke chat
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: _commPurple),
                const SizedBox(height: 18),
                Text(
                  'Membuka obrolan langsung dengan $nameDisplay...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final res = await ChatService.startPersonalChat(cleanId);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Tutup loading

      if (res['status'] == true && res['data'] != null) {
        final chatData = Map<String, dynamic>.from(res['data']);
        final isDesktop = MediaQuery.of(context).size.width > 800;

        if (isDesktop) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DirectMessageScreen(
                currentUser: widget.user,
                initialChat: chatData,
                chatId: chatData['id']?.toString(),
                targetUserId: cleanId,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                body: ChatDetailSection(
                  chat: chatData,
                  isMobile: true,
                  currentUser: widget.user,
                ),
              ),
            ),
          );
        }
      } else {
        // Fallback navigasi langsung ke DirectMessageScreen dengan targetUserId
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DirectMessageScreen(
              currentUser: widget.user,
              targetUserId: cleanId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DirectMessageScreen(
              currentUser: widget.user,
              targetUserId: cleanId,
            ),
          ),
        );
      }
    }
  }

  void _showActivityDetail(Map<String, dynamic> act) {
    final title = act['title']?.toString() ?? 'Kegiatan Komunitas';
    final desc = act['description']?.toString() ?? 'Tidak ada deskripsi.';
    final location = act['location']?.toString() ?? 'Lokasi Ditentukan';
    final status = act['status']?.toString() ?? 'active';
    final maxPart = act['max_participants']?.toString() ?? '20';
    final dateStr = act['activity_date']?.toString();

    String formattedDate = 'Segera';
    if (dateStr != null) {
      try {
        final parsed = DateTime.parse(dateStr);
        formattedDate = DateFormat('dd MMMM yyyy, HH:mm').format(parsed);
      } catch (_) {
        formattedDate = dateStr;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.event_note_rounded, color: _commPurple),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${status.toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _commPurple)),
            const SizedBox(height: 6),
            Text('Waktu: $formattedDate', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text('Lokasi: $location', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text('Kuota: Maksimal $maxPart Peserta', style: const TextStyle(fontSize: 12)),
            const Divider(height: 20),
            const Text('Deskripsi Kegiatan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(fontSize: 12, height: 1.4)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _commPurple),
            onPressed: () {
              Navigator.pop(ctx);
              _openDirectChat(
                targetUserId: act['creator_id']?.toString() ?? act['user_id']?.toString(),
                targetUserName: title,
              );
            },
            child: const Text('Hubungi Penyelenggara', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMemberDetail(Map<String, dynamic> m) {
    final user = (m['user'] as Map<String, dynamic>?) ?? {};
    final name = (user['name'] ?? m['name'] ?? 'Anggota Komunitas').toString();
    final role = (m['role'] ?? 'Anggota Aktif').toString();
    final subRole = (user['sub_role'] ?? 'Kreator Seni Visual').toString();
    final username = (user['username'] ?? 'kreator_kreavana').toString();
    final email = (user['email'] ?? m['email'] ?? '-').toString();
    final status = (m['status'] ?? 'active').toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _commPurple.withValues(alpha: 0.15),
              child: const Icon(Icons.person_rounded, color: _commPurple, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('@$username', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Peran Komunitas: $role', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Kategori Kreator: $subRole', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text('Email: $email', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text('Status Akun: ${status.toUpperCase()}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            const Text('Kontribusi & Portofolio:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              'Kreator aktif terdaftar dalam direktori ekosistem kreatif komunitas Kreavana dengan hak akses kolaborasi penuh.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmRemoveMember(m);
            },
            child: const Text('Hapus Anggota', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _commPurple),
            onPressed: () {
              Navigator.pop(ctx);
              _openDirectChat(
                targetUserId: m['user_id']?.toString() ?? user['id']?.toString(),
                targetUserName: name,
              );
            },
            child: const Text('Kirim Pesan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAnnouncementDetail(Map<String, dynamic> ann) {
    final title = ann['title']?.toString() ?? 'Pengumuman Komunitas';
    final content = ann['content']?.toString() ?? '';
    final type = ann['type']?.toString() ?? 'general';
    final priority = ann['priority']?.toString() ?? 'normal';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.campaign_rounded, color: _commPurple),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Tipe: ${type.toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _commPurple)),
                const SizedBox(width: 12),
                Text('Prioritas: ${priority.toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFEF4444))),
              ],
            ),
            const Divider(height: 20),
            const Text('Isi Pengumuman:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            Text(content, style: const TextStyle(fontSize: 12, height: 1.5)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDeleteAnnouncement(ann);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _commPurple),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showKolaborasiDetail(Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? 'Kolaborasi Komunitas';
    final desc = item['description']?.toString() ?? '';
    final partner = item['partner']?.toString() ?? 'Mitra Ekosistem';
    final budget = item['budget']?.toString() ?? 'Rp 10.000.000';
    final date = item['date']?.toString() ?? 'Segera';
    final progress = (item['progress'] as num?)?.toDouble() ?? 0.5;
    final status = item['status']?.toString() ?? 'active';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.handshake_rounded, color: _commPurple),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${status.toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF10B981))),
            const SizedBox(height: 6),
            Text('Mitra Terlibat: $partner', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Estimasi Anggaran: $budget', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text('Jadwal Pelaksanaan: $date', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            Text('Progres Pelaksanaan: ${(progress * 100).toInt()}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            const Text('Deskripsi Kolaborasi:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(fontSize: 12, height: 1.4)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _commPurple),
            onPressed: () {
              Navigator.pop(ctx);
              _openDirectChat(
                targetUserId: item['partner_id']?.toString(),
                targetUserName: partner,
              );
            },
            child: const Text('Hubungi Mitra', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateActivityStatus(String id, String newStatus) async {
    try {
      await CommunityService.updateActivity(id: id, status: newStatus);
      if (mounted) {
        AppSnackbar.success(context, 'Status kegiatan berhasil diubah menjadi $newStatus.');
      }
      _fetchCommunityData();
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Gagal memperbarui status: $e');
      }
    }
  }

  void _confirmDeleteActivity(String id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kegiatan?'),
        content: Text('Apakah Anda yakin ingin menghapus kegiatan "$title"? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await CommunityService.deleteActivity(id);
                if (mounted) {
                  AppSnackbar.success(context, 'Kegiatan berhasil dihapus.');
                }
                _fetchCommunityData();
              } catch (e) {
                if (mounted) {
                  AppSnackbar.error(context, 'Gagal menghapus kegiatan: $e');
                }
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAnnouncement(Map<String, dynamic> ann) {
    final id = ann['id']?.toString() ?? '';
    final title = ann['title']?.toString() ?? 'Pengumuman';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pengumuman?'),
        content: Text('Apakah Anda yakin ingin menghapus pengumuman "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await CommunityService.deleteAnnouncement(id);
                if (mounted) {
                  AppSnackbar.success(context, 'Pengumuman berhasil dihapus.');
                }
                _fetchCommunityData();
              } catch (e) {
                if (mounted) {
                  AppSnackbar.error(context, 'Gagal menghapus pengumuman: $e');
                }
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveMember(Map<String, dynamic> m) {
    final id = m['id']?.toString() ?? '';
    final user = (m['user'] as Map<String, dynamic>?) ?? {};
    final name = (user['name'] ?? m['name'] ?? 'Anggota').toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluarkan Anggota?'),
        content: Text('Apakah Anda yakin ingin mengeluarkan "$name" dari keanggotaan komunitas?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await CommunityService.removeMember(id);
                if (mounted) {
                  AppSnackbar.success(context, 'Anggota "$name" berhasil dikeluarkan.');
                }
                _fetchCommunityData();
              } catch (e) {
                if (mounted) {
                  AppSnackbar.error(context, 'Gagal mengeluarkan anggota: $e');
                }
              }
            },
            child: const Text('Keluarkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showWorkflowStepDetail(Map<String, dynamic> step) {
    final numStep = step['step'] ?? 1;
    final title = step['title']?.toString() ?? '';
    final actor = step['actor']?.toString() ?? '';
    final desc = step['description']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: _commPurple,
              child: Text(numStep.toString(), style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 15))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Penanggung Jawab: $actor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _commPurple)),
            const SizedBox(height: 8),
            Text(desc, style: const TextStyle(fontSize: 12, height: 1.4)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  void _showEntityDetailModal(Map<String, dynamic> ent) {
    final name = ent['name']?.toString() ?? '';
    final subtitle = ent['subtitle']?.toString() ?? '';
    final color = _resolveEntityColor(ent);
    final benefitsReceived = (ent['benefits_received'] as List<dynamic>?) ?? [];
    final benefitsGiven = (ent['benefits_given'] as List<dynamic>?) ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              const Text(
                'Manfaat yang Didapat dari Kreavana / Komunitas:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
              ),
              const SizedBox(height: 6),
              ...benefitsReceived.map((b) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(b.toString(), style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  )),
              const SizedBox(height: 14),
              const Text(
                'Manfaat yang Diberikan ke Kreavana / Komunitas:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _commPurple),
              ),
              const SizedBox(height: 6),
              ...benefitsGiven.map((b) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.star_outline_rounded, size: 14, color: _commPurple),
                        const SizedBox(width: 6),
                        Expanded(child: Text(b.toString(), style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  )),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _commPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder(String message, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 32, color: isDark ? Colors.white38 : Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : Colors.grey.shade600)),
          ],
        ),
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
                    : DirectMessageScreen(currentUser: widget.user),
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
