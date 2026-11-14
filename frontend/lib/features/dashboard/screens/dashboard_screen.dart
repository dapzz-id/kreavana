import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/app_router.dart';
import '../../../widgets/auth_guard_dialog.dart';
import '../../../app/theme.dart';
import '../../../screens/creator_service_screen.dart';
import '../../../screens/institution_workspace_screen.dart';
import 'community_dashboard_screen.dart';
import '../../../services/api_service.dart';
import '../../../models/user_model.dart';
import '../../../screens/buat_kebutuhan_screen.dart';
import '../../../screens/proyek_saya_screen.dart';
import '../../../screens/laporan_screen.dart';
import '../../../screens/grafik_screen.dart';
import '../../../widgets/ai_recommendation_card.dart';
import '../../../widgets/opportunity_detail_sheet.dart';
import '../../../models/opportunity_model.dart';
import '../../../services/profile_completeness_service.dart';
import '../../../app/subrole_theme_engine.dart';
import '../../../widgets/upgrade_plan_modal.dart';
import '../../../widgets/user_profile_modal.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/job_contract_service.dart';
import '../services/dashboard_service.dart';
import '../../../models/job_contract.dart';
import '../../../widgets/creator_sidebar_menus.dart';
import '../../../widgets/app_bar_badge.dart';
import '../../../screens/detail_kebutuhan_screen.dart';
import '../../../screens/direct_message_screen.dart';
import '../../../services/chat_service.dart';
import '../../../app/app_animations.dart';
import '../../../widgets/app_sweet_alert.dart';
class _RoleDashboardConfig {
  final String badge;
  final String greeting;
  final String subtitle;
  final String primaryButtonLabel;
  final IconData primaryButtonIcon;
  final String secondaryButtonLabel;
  final IconData secondaryButtonIcon;
  final String recommendationTitle;
  final String recommendationNiche;
  final String recommendationRole;
  final List<Map<String, dynamic>> metrics;
  final List<Map<String, dynamic>> quickActions;
  final List<String> aiTips;

  const _RoleDashboardConfig({
    required this.badge,
    required this.greeting,
    required this.subtitle,
    required this.primaryButtonLabel,
    required this.primaryButtonIcon,
    required this.secondaryButtonLabel,
    required this.secondaryButtonIcon,
    required this.recommendationTitle,
    required this.recommendationNiche,
    required this.recommendationRole,
    required this.metrics,
    required this.quickActions,
    required this.aiTips,
  });
}

class DashboardScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel> onUserUpdated;

  const DashboardScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late String _currentRole;
  Map<String, dynamic> _overviewSummary = {};
  List<Map<String, dynamic>> _vendorRecommendations = [];
  List<Map<String, dynamic>> _recommendedOpportunities = [];
  List<Map<String, dynamic>> _projectNeeds = [];
  List<Map<String, dynamic>> _incomingProposals = [];
  List<Map<String, dynamic>> _runningContracts = [];
  List<Map<String, dynamic>> _agenda = [];
  List<Map<String, dynamic>> _projectAssets = [];
  List<Map<String, dynamic>> _activityFeed = [];
  List<JobContract> _contracts = [];
  List<Map<String, String>> _stats = [];

  late AnimationController _statsAnimController;
  late List<Animation<double>> _statsAnims;
  late AnimationController _handWaveController;
  late Animation<double> _handWaveAnimation;

  bool get _isCreator =>
      _currentRole == 'creator' ||
      widget.user.role == 'creator' ||
      widget.user.isCreator;

  bool get _isTalentAndPerformer {
    final sub = CreatorSidebarMenus.normalizeSubRole(widget.user.subRole);
    return sub == 'talent' ||
        sub == 'performer' ||
        sub == 'talent_performer' ||
        sub == 'model' ||
        sub == 'talent_model' ||
        sub == 'actor' ||
        sub == 'aktor' ||
        sub == 'mc' ||
        sub == 'penyanyi' ||
        sub == 'singer' ||
        sub == 'musisi' ||
        sub == 'musician' ||
        sub == 'penari' ||
        sub == 'dancer' ||
        sub == 'voice_over' ||
        sub == 'vo' ||
        sub == 'voiceover';
  }

  bool get _isVendorOrMitra {
    final sub = CreatorSidebarMenus.normalizeSubRole(widget.user.subRole);
    return sub == 'vendor' ||
        sub == 'mitra_pendukung' ||
        sub == 'mitra' ||
        sub == 'penyedia_jasa' ||
        sub == 'studio' ||
        sub == 'rental_alat' ||
        sub == 'rental' ||
        sub == 'wardrobe' ||
        sub == 'dekorasi' ||
        sub == 'katering' ||
        sub == 'printing' ||
        sub == 'lighting' ||
        sub == 'sound' ||
        sub == 'lighting_sound' ||
        sub == 'transportasi' ||
        sub == 'logistik';
  }

  SubRoleThemeConfig get _roleThemeConfig =>
      SubRoleThemeEngine.getConfig(widget.user.role, widget.user.subRole);

  Color get _roleAccentColor => _roleThemeConfig.primaryColor;

  final GlobalKey _themeBtnKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentRole = widget.user.role;
    _statsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _statsAnims = List.generate(
      4,
      (i) => CurvedAnimation(
        parent: _statsAnimController,
        curve: Interval(i * 0.15, 0.6 + i * 0.1, curve: Curves.easeOutCubic),
      ),
    );
    _handWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _handWaveAnimation = Tween<double>(begin: -0.35, end: 0.35).animate(
      CurvedAnimation(parent: _handWaveController, curve: Curves.easeInOut),
    );
    _loadDashboardData();
  }

  @override
  void dispose() {
    _statsAnimController.dispose();
    _handWaveController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user.role != oldWidget.user.role ||
        widget.user.subRole != oldWidget.user.subRole) {
      setState(() => _currentRole = widget.user.role);
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      final sub = CreatorSidebarMenus.normalizeSubRole(widget.user.subRole);
      final roleType = widget.user.role;
      final results = await Future.wait([
        ApiService.get('client-dashboard/overview?role_type=$roleType').catchError((_) => <String, dynamic>{}),
        JobContractService.getUserContracts().catchError((_) => <JobContract>[]),
        if (sub.isNotEmpty)
          DashboardService.getStats(subRole: sub, roleType: roleType).catchError((_) => <Map<String, String>>[])
        else
          Future.value(<Map<String, String>>[]),
      ]);

      if (mounted) {
        final res = results[0] as Map<String, dynamic>;
        final contracts = results[1] as List<JobContract>;
        final stats = results[2] as List<Map<String, String>>;

        setState(() {
          _contracts = contracts;
          _stats = stats;
          final data = res['data'] ?? {};
          if ((res['success'] == true || res['status'] == true) && res['data'] != null) {
            final summary = data['summary'] ?? {};
            _overviewSummary = {
              'active_needs': summary['active_needs']?.toString() ?? '0',
              'proposals_count': summary['proposals_count']?.toString() ?? '0',
              'running_projects':
                  summary['running_projects']?.toString() ?? '0',
              'estimated_expenses':
                  summary['estimated_expenses']?.toString() ?? 'Rp 0',
              'monthly_income': summary['monthly_income']?.toString() ?? 'Rp 0',
            };
          } else {
            _overviewSummary = {
              'active_needs': '0',
              'proposals_count': '0',
              'running_projects': '0',
              'estimated_expenses': 'Rp 0',
              'monthly_income': 'Rp 0',
            };
          }

          _vendorRecommendations = List<Map<String, dynamic>>.from(
            data['vendor_recommendations'] ?? [],
          );
          _recommendedOpportunities = List<Map<String, dynamic>>.from(
            data['recommended_opportunities'] ?? [],
          );
          _projectNeeds = List<Map<String, dynamic>>.from(
            data['project_needs'] ?? [],
          );
          _incomingProposals = List<Map<String, dynamic>>.from(
            data['incoming_proposals'] ?? [],
          );
          _runningContracts = List<Map<String, dynamic>>.from(
            data['running_contracts'] ?? [],
          );
          _agenda = List<Map<String, dynamic>>.from(data['agenda'] ?? []);
          _projectAssets = List<Map<String, dynamic>>.from(
            data['project_assets'] ?? [],
          );
          _activityFeed = List<Map<String, dynamic>>.from(
            data['activity_feed'] ?? [],
          );
        });
        _statsAnimController.forward(from: 0);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _overviewSummary = {
            'active_needs': '0',
            'proposals_count': '0',
            'running_projects': '0',
            'estimated_expenses': 'Rp 0',
            'monthly_income': 'Rp 0',
          };
          _vendorRecommendations = [];
          _recommendedOpportunities = [];
          _projectNeeds = [];
          _incomingProposals = [];
          _runningContracts = [];
          _agenda = [];
          _projectAssets = [];
        });
      }
    }
  }

  void _showDummyActionMessage(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fitur "$action" segera hadir!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  IconData _getHeroIllustrationIcon() {
    if (_isVendorOrMitra) return Icons.storefront_outlined;
    if (_isTalentAndPerformer) return Icons.theater_comedy_outlined;
    final sub = CreatorSidebarMenus.normalizeSubRole(widget.user.subRole);
    if (sub == 'event_organizer' || sub == 'eo') return Icons.festival_outlined;
    if (sub == 'wedding_organizer' || sub == 'wo') return Icons.celebration_outlined;
    if (sub == 'school' || sub == 'education' || sub == 'campus' || sub == 'sekolah' || sub == 'kampus') {
      return Icons.school_outlined;
    }
    if (sub == 'government' || sub == 'pemerintah' || sub == 'instansi') {
      return Icons.account_balance_outlined;
    }
    if (sub == 'company' || sub == 'business' || sub == 'corporate' || sub == 'perusahaan') {
      return Icons.business_center_outlined;
    }
    if (_isCreator) return Icons.camera_alt_outlined;
    return Icons.laptop_mac_outlined;
  }

  String _getSearchHint() {
    if (_isVendorOrMitra) {
      return 'Cari permintaan sewa alat, proyek event EO, atau kolaborasi kreator...';
    }
    if (_isTalentAndPerformer) {
      return 'Cari casting, job panggung, kreator, atau vendor MUA...';
    }
    final sub = CreatorSidebarMenus.normalizeSubRole(widget.user.subRole);
    if (sub == 'event_organizer' || sub == 'eo') {
      return 'Cari event, vendor, atau talent...';
    }
    if (sub == 'wedding_organizer' || sub == 'wo') {
      return 'Cari vendor wedding, paket, atau talent...';
    }
    if (sub == 'school' || sub == 'education' || sub == 'campus' || sub == 'sekolah' || sub == 'kampus') {
      return 'Cari mitra industri, magang, atau karya...';
    }
    if (sub == 'government' || sub == 'pemerintah' || sub == 'instansi') {
      return 'Cari program, talenta daerah, atau pengadaan...';
    }
    if (sub == 'company' || sub == 'business' || sub == 'corporate' || sub == 'perusahaan') {
      return 'Cari vendor, agensi, atau proposal...';
    }
    if (_isCreator) {
      return 'Cari peluang, campaign, komunitas...';
    }
    return 'Cari kreator, layanan, proyek...';
  }

  _RoleDashboardConfig _getRoleConfig() {
    final sub = CreatorSidebarMenus.normalizeSubRole(widget.user.subRole);
    final user = widget.user;
    final name = user.name.trim().isNotEmpty ? user.name.trim() : 'Pengguna';
    final firstName = name.split(' ').first;

    final totalContracts = _contracts.length;
    int inProgressCount = 0;
    for (final c in _contracts) {
      if (c.workStatus.toLowerCase() == 'in_progress') inProgressCount++;
    }

    String? findStatValue(String keyword) {
      final match = _stats.firstWhere(
        (s) => (s['label'] ?? '').toLowerCase().contains(keyword.toLowerCase()),
        orElse: () => {},
      );
      return match['value'];
    }

    // 1. EVENT ORGANIZER (EO)
    if (sub == 'event_organizer' || sub == 'eo') {
      final totalEventVal = findStatValue('event') ?? (totalContracts > 0 ? '$totalContracts' : '15');
      final eventBerjalanVal = inProgressCount > 0 ? '$inProgressCount' : '2';
      final vendorMitraVal = _vendorRecommendations.isNotEmpty ? '${_vendorRecommendations.length}' : '8';
      final anggaranVal = _overviewSummary['estimated_expenses']?.toString() ?? 'Rp 28,5 Jt';

      return _RoleDashboardConfig(
        badge: '✦ MODE EVENT ORGANIZER',
        greeting: 'Halo, $name! 🎪',
        subtitle: 'Pantau progres acara, koordinasi vendor, dan kelola anggaran event Anda dalam satu dasbor.',
        primaryButtonLabel: '+ Buat Event Baru',
        primaryButtonIcon: Icons.festival_outlined,
        secondaryButtonLabel: 'Cari Vendor Mitra',
        secondaryButtonIcon: Icons.search_rounded,
        recommendationTitle: 'Vendor Mitra Rekomendasi',
        recommendationNiche: 'Event & Vendor',
        recommendationRole: 'client',
        metrics: [
          {
            'label': 'Total Event',
            'value': totalEventVal,
            'icon': Icons.festival_outlined,
            'color': const Color(0xFF6366F1),
            'trend': '$totalContracts proyek terdaftar',
            'breakdown': 'Total penyelenggaraan acara dan event aktif terdaftar di akun Anda.',
            'action': 'Jadwal Event',
          },
          {
            'label': 'Event Berjalan',
            'value': eventBerjalanVal,
            'icon': Icons.play_circle_outline_rounded,
            'color': const Color(0xFF10B981),
            'trend': 'Persiapan & on-going',
            'breakdown': 'Event yang saat ini dalam tahap gladi resik, koordinasi teknis, atau eksekusi.',
            'action': 'Timeline EO',
          },
          {
            'label': 'Vendor Partner',
            'value': vendorMitraVal,
            'icon': Icons.handshake_outlined,
            'color': const Color(0xFFF59E0B),
            'trend': '$vendorMitraVal mitra terhubung',
            'breakdown': 'Mitra vendor profesional (dokumentasi, F&B, sound, stage, talent/MC) yang terhubung.',
            'action': 'Vendor Partner',
          },
          {
            'label': 'Anggaran Dikelola',
            'value': anggaranVal,
            'icon': Icons.account_balance_wallet_outlined,
            'color': const Color(0xFF3B82F6),
            'trend': 'Realisasi anggaran aktif',
            'breakdown': 'Total alokasi biaya dan anggaran produksi event yang sedang berjalan.',
            'action': 'Grafik Performa',
          },
        ],
        quickActions: [
          {'icon': Icons.inventory_2_outlined, 'label': 'Paket Event'},
          {'icon': Icons.calendar_month_outlined, 'label': 'Jadwal Event'},
          {'icon': Icons.handshake_outlined, 'label': 'Vendor Partner'},
          {'icon': Icons.timeline_outlined, 'label': 'Timeline EO'},
          {'icon': Icons.payments_outlined, 'label': 'Tarik Saldo'},
          {'icon': Icons.insights_rounded, 'label': 'Grafik Performa'},
        ],
        aiTips: [
          'Siapkan rundown teknis dan checklist perlengkapan H-7 sebelum hari-H acara',
          'Gunakan pembayaran milestone escrow untuk menjamin kejelasan komitmen antar vendor',
          'Sinkronisasi jadwal gladi resik secara real-time dengan seluruh talenta & MC',
        ],
      );
    }

    // 2. WEDDING ORGANIZER (WO)
    if (sub == 'wedding_organizer' || sub == 'wo') {
      final totalWeddingVal = findStatValue('wedding') ?? (totalContracts > 0 ? '$totalContracts' : '12');
      final weddingBerjalanVal = inProgressCount > 0 ? '$inProgressCount' : '3';
      final vendorVal = _vendorRecommendations.isNotEmpty ? '${_vendorRecommendations.length}' : '14';
      final anggaranVal = _overviewSummary['estimated_expenses']?.toString() ?? 'Rp 45 Jt';

      return _RoleDashboardConfig(
        badge: '✦ MODE WEDDING ORGANIZER',
        greeting: 'Halo, $name! 💍',
        subtitle: 'Rencanakan pernikahan impian, koordinasi vendor wedding, dan kelola jadwal acara secara terpadu.',
        primaryButtonLabel: '+ Buat Paket Wedding',
        primaryButtonIcon: Icons.favorite_outline,
        secondaryButtonLabel: 'Cari Vendor Wedding',
        secondaryButtonIcon: Icons.search_rounded,
        recommendationTitle: 'Vendor Wedding Rekomendasi',
        recommendationNiche: 'Pernikahan & Wedding',
        recommendationRole: 'client',
        metrics: [
          {
            'label': 'Paket Wedding',
            'value': totalWeddingVal,
            'icon': Icons.favorite_border,
            'color': const Color(0xFFEC4899),
            'trend': 'Agenda pernikahan terdaftar',
            'breakdown': 'Jumlah jadwal dan paket wedding yang dikelola dalam portofolio Anda.',
            'action': 'Paket Pernikahan',
          },
          {
            'label': 'Jadwal Event',
            'value': weddingBerjalanVal,
            'icon': Icons.calendar_month_outlined,
            'color': const Color(0xFF10B981),
            'trend': 'Persiapan & Hari-H',
            'breakdown': 'Acara pernikahan yang sedang aktif dalam tahap persiapan atau pelaksanaan.',
            'action': 'Jadwal Event',
          },
          {
            'label': 'Vendor Partner',
            'value': vendorVal,
            'icon': Icons.handshake_outlined,
            'color': const Color(0xFFF59E0B),
            'trend': 'MUA, Foto, Dekor & F&B',
            'breakdown': 'Jaringan vendor terpercaya yang siap dikolaborasikan untuk klien pengantin.',
            'action': 'Vendor Partner',
          },
          {
            'label': 'Timeline WO',
            'value': anggaranVal,
            'icon': Icons.timeline_outlined,
            'color': const Color(0xFF8B5CF6),
            'trend': 'Alokasi paket wedding aktif',
            'breakdown': 'Perkiraan total nilai anggaran paket pernikahan yang sedang berlangsung.',
            'action': 'Timeline WO',
          },
        ],
        quickActions: [
          {'icon': Icons.favorite_outline, 'label': 'Paket Pernikahan'},
          {'icon': Icons.calendar_month_outlined, 'label': 'Jadwal Event'},
          {'icon': Icons.handshake_outlined, 'label': 'Vendor Partner'},
          {'icon': Icons.timeline_outlined, 'label': 'Timeline WO'},
          {'icon': Icons.payments_outlined, 'label': 'Tarik Saldo'},
          {'icon': Icons.insights_rounded, 'label': 'Grafik Performa'},
        ],
        aiTips: [
          'Pastikan moodboard pengantin terkonfirmasi oleh vendor dekorasi dan MUA',
          'Lakukan briefing teknis dengan tim fotografer H-3 sebelum akad dan resepsi',
          'Pantau pembayaran termin vendor melalui sistem dompet escrow terjamin',
        ],
      );
    }

    // 3. INSTITUSI PENDIDIKAN / SEKOLAH / KAMPUS
    if (sub == 'school' ||
        sub == 'education' ||
        sub == 'campus' ||
        sub == 'sekolah' ||
        sub == 'kampus' ||
        sub == 'institution' ||
        sub == 'institusi') {
      return _RoleDashboardConfig(
        badge: '✦ MODE INSTITUSI PENDIDIKAN',
        greeting: 'Halo, $name! 🎓',
        subtitle: 'Jembatani talenta siswa dengan industri, kurasi karya kreatif kampus, dan pantau kemitraan industri.',
        primaryButtonLabel: 'Program & Magang',
        primaryButtonIcon: Icons.work_outline,
        secondaryButtonLabel: 'Review Karya Siswa',
        secondaryButtonIcon: Icons.collections_bookmark_outlined,
        recommendationTitle: 'Mitra Industri Rekomendasi',
        recommendationNiche: 'Industri Kreatif',
        recommendationRole: 'client',
        metrics: [
          {
            'label': 'Siswa / Mahasiswa',
            'value': '1.240',
            'icon': Icons.school_outlined,
            'color': const Color(0xFF6366F1),
            'trend': 'Talenta kreatif terdaftar',
            'breakdown': 'Total siswa dan mahasiswa aktif yang terdaftar dalam program kejuruan / kampus.',
            'action': 'Semua Proyek',
          },
          {
            'label': 'Program Magang',
            'value': '18',
            'icon': Icons.work_outline,
            'color': const Color(0xFF10B981),
            'trend': 'Kemitraan industri aktif',
            'breakdown': 'Program magang kerja sama industri yang sedang berjalan untuk mahasiswa.',
            'action': 'Proyek Berjalan',
          },
          {
            'label': 'Mitra Industri',
            'value': '32',
            'icon': Icons.business_outlined,
            'color': const Color(0xFF3B82F6),
            'trend': 'Perusahaan mitra terhubung',
            'breakdown': 'Perusahaan dan studio kreatif yang telah menandatangani MoU kemitraan.',
            'action': 'Cari Mitra Industri',
          },
          {
            'label': 'Karya Disetujui',
            'value': '156',
            'icon': Icons.verified_outlined,
            'color': const Color(0xFFF59E0B),
            'trend': 'Portofolio terverifikasi',
            'breakdown': 'Karya cipta dan portofolio siswa yang telah lulus kurasi standar industri.',
            'action': 'Review Karya',
          },
        ],
        quickActions: [
          {'icon': Icons.work_outline, 'label': 'Program & Magang'},
          {'icon': Icons.collections_bookmark_outlined, 'label': 'Review Karya'},
          {'icon': Icons.badge_outlined, 'label': 'Direktori Talenta'},
          {'icon': Icons.calendar_month_outlined, 'label': 'Atur Jadwal'},
          {'icon': Icons.assessment_outlined, 'label': 'Laporan'},
          {'icon': Icons.insights_rounded, 'label': 'Grafik Performa'},
        ],
        aiTips: [
          'Verifikasi berkas karya siswa sebelum dipublikasikan ke etalase publik Kreavana',
          'Hubungkan siswa magang dengan mentor industri bersertifikat di platform',
          'Gunakan kalender agenda untuk memantau tenggat ujian kompetensi karya',
        ],
      );
    }

    // 4. PEMERINTAH / INSTANSI
    if (sub == 'government' || sub == 'pemerintah' || sub == 'instansi') {
      return _RoleDashboardConfig(
        badge: '✦ MODE INSTANSI PEMERINTAH',
        greeting: 'Halo, $name! 🏛️',
        subtitle: 'Kelola program pemberdayaan ekonomi kreatif daerah, publikasi agenda, dan serapan anggaran kegiatan.',
        primaryButtonLabel: '+ Pengadaan Kreatif',
        primaryButtonIcon: Icons.account_balance_outlined,
        secondaryButtonLabel: 'Kurasi Talenta Daerah',
        secondaryButtonIcon: Icons.groups_outlined,
        recommendationTitle: 'Talenta Kreatif Binaan',
        recommendationNiche: 'Ekonomi Kreatif',
        recommendationRole: 'client',
        metrics: [
          {
            'label': 'Program Daerah',
            'value': '14',
            'icon': Icons.account_balance_outlined,
            'color': const Color(0xFF6366F1),
            'trend': 'Inisiatif ekonomi kreatif',
            'breakdown': 'Program pembinaan, pelatihan, dan inkubasi kreatif daerah yang sedang berjalan.',
            'action': 'Semua Proyek',
          },
          {
            'label': 'Talenta Binaan',
            'value': '340',
            'icon': Icons.groups_outlined,
            'color': const Color(0xFF10B981),
            'trend': 'Pelaku kreatif terdaftar',
            'breakdown': 'Kreator dan pelaku UMKM lokal yang terdaftar dalam basis data binaan daerah.',
            'action': 'Kurasi Talenta',
          },
          {
            'label': 'Proyek Pengadaan',
            'value': '8',
            'icon': Icons.assignment_outlined,
            'color': const Color(0xFF3B82F6),
            'trend': 'Kegiatan pengadaan berjalan',
            'breakdown': 'Paket pengadaan jasa kreatif dan media publikasi pemerintah yang aktif.',
            'action': 'Proyek Berjalan',
          },
          {
            'label': 'Serapan Anggaran',
            'value': 'Rp 120 Jt',
            'icon': Icons.account_balance_wallet_outlined,
            'color': const Color(0xFFF59E0B),
            'trend': 'Alokasi kegiatan aktif',
            'breakdown': 'Realisasi penyerapan anggaran program kreatif daerah terverifikasi.',
            'action': 'Grafik Performa',
          },
        ],
        quickActions: [
          {'icon': Icons.assignment_outlined, 'label': 'Pengadaan Kreatif'},
          {'icon': Icons.search, 'label': 'Kurasi Talenta'},
          {'icon': Icons.compare_arrows, 'label': 'Bandingkan'},
          {'icon': Icons.calendar_month_outlined, 'label': 'Agenda Daerah'},
          {'icon': Icons.assessment_outlined, 'label': 'Laporan'},
          {'icon': Icons.insights_rounded, 'label': 'Grafik Performa'},
        ],
        aiTips: [
          'Buka transparansi syarat teknis agar kreator UMKM daerah dapat berpartisipasi',
          'Pantau serapan anggaran secara bertahap menggunakan invoice escrow resmi',
          'Rilis laporan berkala indeks pertumbuhan ekonomi kreatif kota/kabupaten',
        ],
      );
    }

    // 5. PERUSAHAAN / CORPORATE / BUSINESS
    if (sub == 'company' ||
        sub == 'business' ||
        sub == 'corporate' ||
        sub == 'perusahaan' ||
        sub == 'bisnis' ||
        user.role == 'company' ||
        user.role == 'corporate') {
      return _RoleDashboardConfig(
        badge: '✦ MODE PERUSAHAAN & BRAND',
        greeting: 'Halo, $name! 🏢',
        subtitle: 'Kelola pengadaan jasa kreatif, kampanye brand korporat, dan kolaborasi profesional terverifikasi.',
        primaryButtonLabel: '+ Buka Proyek Korporat',
        primaryButtonIcon: Icons.business_center_outlined,
        secondaryButtonLabel: 'Cari Vendor Mitra',
        secondaryButtonIcon: Icons.search_rounded,
        recommendationTitle: 'Vendor & Agensi Rekomendasi',
        recommendationNiche: 'Brand & Komersial',
        recommendationRole: 'client',
        metrics: [
          {
            'label': 'Kampanye Aktif',
            'value': _overviewSummary['active_needs']?.toString() ?? '6',
            'icon': Icons.campaign_outlined,
            'color': const Color(0xFF3B82F6),
            'trend': 'Brief pengadaan berjalan',
            'breakdown': 'Brief pengadaan kreatif dan promosi brand yang sedang dibuka ke publik.',
            'action': 'Semua Proyek',
          },
          {
            'label': 'Proposal Masuk',
            'value': _overviewSummary['proposals_count']?.toString() ?? '18',
            'icon': Icons.mail_outline,
            'color': const Color(0xFF10B981),
            'trend': 'Penawaran vendor/kreator',
            'breakdown': 'Total proposal dan portofolio masuk dari agency atau kreator terverifikasi.',
            'action': 'Proposal Masuk',
          },
          {
            'label': 'Kontrak Berjalan',
            'value': _overviewSummary['running_projects']?.toString() ?? '4',
            'icon': Icons.folder_open,
            'color': const Color(0xFF6366F1),
            'trend': 'Produksi & eksekusi',
            'breakdown': 'Proyek produksi kampanye yang sedang dalam tahap eksekusi lapangan.',
            'action': 'Proyek Berjalan',
          },
          {
            'label': 'Total Anggaran',
            'value': _overviewSummary['estimated_expenses']?.toString() ?? 'Rp 85 Jt',
            'icon': Icons.account_balance_wallet_outlined,
            'color': const Color(0xFFF59E0B),
            'trend': 'Komitmen dana proyek',
            'breakdown': 'Alokasi komitmen dana korporat yang terlindungi di rekening escrow.',
            'action': 'Grafik Performa',
          },
        ],
        quickActions: [
          {'icon': Icons.business_center_outlined, 'label': 'Buka Proyek Korporat'},
          {'icon': Icons.school_outlined, 'label': 'Buka Program Magang'},
          {'icon': Icons.search, 'label': 'Cari Vendor'},
          {'icon': Icons.compare_arrows, 'label': 'Bandingkan'},
          {'icon': Icons.folder_open, 'label': 'Kontrak Berjalan'},
          {'icon': Icons.insights_rounded, 'label': 'Grafik Performa'},
        ],
        aiTips: [
          'Sertakan NDA digital dalam brief pengadaan proyek sensitif korporasi',
          'Bandingkan portofolio dan ulasan terverifikasi sebelum menyetujui kontrak',
          'Gunakan milestone bertahap untuk menjaga kualitas deliverables setiap fase',
        ],
      );
    }

    // 6. UMKM & BISNIS LOKAL
    if (sub == 'umkm') {
      return _RoleDashboardConfig(
        badge: '✦ MODE UMKM & BISNIS LOKAL',
        greeting: 'Halo, $name! 🛍️',
        subtitle: 'Temukan talenta kreatif terbaik untuk branding produk, konten promosi, dan ekspansi bisnis Anda.',
        primaryButtonLabel: '+ Buat Kebutuhan',
        primaryButtonIcon: Icons.storefront_outlined,
        secondaryButtonLabel: 'Cari Kreator Promosi',
        secondaryButtonIcon: Icons.search_rounded,
        recommendationTitle: 'Kreator Promosi Rekomendasi',
        recommendationNiche: 'Promosi Produk & UMKM',
        recommendationRole: 'client',
        metrics: [
          {
            'label': 'Kebutuhan Aktif',
            'value': _overviewSummary['active_needs']?.toString() ?? '3',
            'icon': Icons.description_outlined,
            'color': const Color(0xFF3B82F6),
            'trend': 'Brief promosi berjalan',
            'breakdown': 'Brief kebutuhan konten dan foto katalog yang sedang mencari kreator.',
            'action': 'Semua Proyek',
          },
          {
            'label': 'Proposal Masuk',
            'value': _overviewSummary['proposals_count']?.toString() ?? '12',
            'icon': Icons.mail_outline,
            'color': const Color(0xFF10B981),
            'trend': 'Penawaran dari kreator',
            'breakdown': 'Kreator yang mengajukan proposal dan tawaran kerja sama untuk UMKM Anda.',
            'action': 'Proposal Masuk',
          },
          {
            'label': 'Proyek Berjalan',
            'value': _overviewSummary['running_projects']?.toString() ?? '2',
            'icon': Icons.folder_open,
            'color': const Color(0xFF14B8A6),
            'trend': 'Desain & konten aktif',
            'breakdown': 'Pengerjaan konten, foto produk, atau video reels yang sedang berjalan.',
            'action': 'Proyek Berjalan',
          },
          {
            'label': 'Est. Pengeluaran',
            'value': _overviewSummary['estimated_expenses']?.toString() ?? 'Rp 2,5 Jt',
            'icon': Icons.account_balance_wallet_outlined,
            'color': const Color(0xFF7C3AED),
            'trend': 'Alokasi biaya promosi',
            'breakdown': 'Total biaya promosi dan pengadaan konten kreatif UMKM Anda.',
            'action': 'Grafik Performa',
          },
        ],
        quickActions: [
          {'icon': Icons.add_circle_outline, 'label': 'Buat Kebutuhan'},
          {'icon': Icons.search, 'label': 'Cari Kreator'},
          {'icon': Icons.insights_rounded, 'label': 'Grafik Performa'},
          {'icon': Icons.compare_arrows, 'label': 'Bandingkan'},
          {'icon': Icons.check_circle_outline, 'label': 'Setujui Proyek'},
          {'icon': Icons.payment, 'label': 'Bayar DP'},
        ],
        aiTips: [
          'Sertakan contoh foto produk dan target audiens agar konten relevan',
          'Cari kreator lokal terdekat untuk memudahkan pengiriman sample produk',
          'Simpan kreator favorit untuk kebutuhan konten promo bulanan Anda',
        ],
      );
    }

    // 7. CREATIVE AGENCY
    if (sub == 'agency' || sub == 'brand_agency') {
      return _RoleDashboardConfig(
        badge: '✦ MODE CREATIVE AGENCY',
        greeting: 'Halo, $name! 🚀',
        subtitle: 'Kelola proyek kampanye kreatif klien, koordinasi talenta, dan pantau milestone produksi.',
        primaryButtonLabel: '+ Buat Brief Kampanye',
        primaryButtonIcon: Icons.campaign_outlined,
        secondaryButtonLabel: 'Cari Talenta Kreatif',
        secondaryButtonIcon: Icons.search_rounded,
        recommendationTitle: 'Talenta Kreatif Rekomendasi',
        recommendationNiche: 'Produksi Kreatif & Media',
        recommendationRole: 'client',
        metrics: [
          {
            'label': 'Kampanye Klien',
            'value': _overviewSummary['active_needs']?.toString() ?? '8',
            'icon': Icons.campaign_outlined,
            'color': const Color(0xFF6366F1),
            'trend': 'Produksi kampanye aktif',
            'breakdown': 'Kampanye klien agency yang sedang dalam tahap rekrutmen talenta & produksi.',
            'action': 'Semua Proyek',
          },
          {
            'label': 'Proposal Masuk',
            'value': _overviewSummary['proposals_count']?.toString() ?? '24',
            'icon': Icons.mail_outline,
            'color': const Color(0xFF10B981),
            'trend': 'Kandidat talenta masuk',
            'breakdown': 'Total lamaran kerja sama dari para kreator lepas untuk kampanye agency.',
            'action': 'Proposal Masuk',
          },
          {
            'label': 'Talenta Bekerja',
            'value': _overviewSummary['running_projects']?.toString() ?? '5',
            'icon': Icons.group_work_outlined,
            'color': const Color(0xFF3B82F6),
            'trend': 'Kontrak produksi berjalan',
            'breakdown': 'Kreator yang sedang aktif menjalankan tugas produksi kampanye.',
            'action': 'Proyek Berjalan',
          },
          {
            'label': 'Total Billing',
            'value': _overviewSummary['estimated_expenses']?.toString() ?? 'Rp 42 Jt',
            'icon': Icons.account_balance_wallet_outlined,
            'color': const Color(0xFFF59E0B),
            'trend': 'Total anggaran produksi',
            'breakdown': 'Total komitmen billing produksi kampanye yang dikelola melalui platform.',
            'action': 'Grafik Performa',
          },
        ],
        quickActions: [
          {'icon': Icons.campaign_outlined, 'label': 'Buat Brief Kampanye'},
          {'icon': Icons.search, 'label': 'Cari Kreator'},
          {'icon': Icons.compare_arrows, 'label': 'Bandingkan'},
          {'icon': Icons.calendar_month_outlined, 'label': 'Atur Jadwal'},
          {'icon': Icons.payment, 'label': 'Bayar DP'},
          {'icon': Icons.insights_rounded, 'label': 'Grafik Performa'},
        ],
        aiTips: [
          'Gunakan template timeline bertahap untuk sinkronisasi tim kreatif',
          'Lakukan kurasi portofolio kreator sebelum merekomendasikan ke brand klien',
          'Gunakan proteksi escrow untuk kepastian pencairan komitmen project fee',
        ],
      );
    }

    // 8. PARIWISATA & DESA WISATA
    if (sub == 'tourism' || sub == 'desa_wisata' || sub == 'pariwisata') {
      return _RoleDashboardConfig(
        badge: '✦ MODE PARIWISATA & DESA WISATA',
        greeting: 'Halo, $name! 🏖️',
        subtitle: 'Promosikan destinasi wisata lokal, gandeng kreator konten, dan tingkatkan daya tarik pengunjung.',
        primaryButtonLabel: '+ Buat Kampanye Wisata',
        primaryButtonIcon: Icons.landscape_outlined,
        secondaryButtonLabel: 'Cari Kreator Konten',
        secondaryButtonIcon: Icons.search_rounded,
        recommendationTitle: 'Kreator Konten Rekomendasi',
        recommendationNiche: 'Wisata & Travel',
        recommendationRole: 'client',
        metrics: [
          {
            'label': 'Kampanye Wisata',
            'value': _overviewSummary['active_needs']?.toString() ?? '4',
            'icon': Icons.landscape_outlined,
            'color': const Color(0xFF10B981),
            'trend': 'Program promosi aktif',
            'breakdown': 'Kampanye promosi destinasi wisata lokal yang sedang berjalan.',
            'action': 'Semua Proyek',
          },
          {
            'label': 'Proposal Masuk',
            'value': _overviewSummary['proposals_count']?.toString() ?? '16',
            'icon': Icons.mail_outline,
            'color': const Color(0xFF3B82F6),
            'trend': 'Kreator & videografer',
            'breakdown': 'Penawaran dari travel vlogger, fotografer lanskap, dan kreator konten.',
            'action': 'Proposal Masuk',
          },
          {
            'label': 'Shooting Berjalan',
            'value': _overviewSummary['running_projects']?.toString() ?? '3',
            'icon': Icons.videocam_outlined,
            'color': const Color(0xFF6366F1),
            'trend': 'Produksi di lokasi wisata',
            'breakdown': 'Tim kreator yang sedang melakukan pengambilan gambar di lokasi.',
            'action': 'Proyek Berjalan',
          },
          {
            'label': 'Alokasi Promosi',
            'value': _overviewSummary['estimated_expenses']?.toString() ?? 'Rp 15 Jt',
            'icon': Icons.account_balance_wallet_outlined,
            'color': const Color(0xFFF59E0B),
            'trend': 'Anggaran branding destinasi',
            'breakdown': 'Total anggaran pengembangan konten visual destinasi wisata.',
            'action': 'Grafik Performa',
          },
        ],
        quickActions: [
          {'icon': Icons.landscape_outlined, 'label': 'Buat Kampanye Wisata'},
          {'icon': Icons.search, 'label': 'Cari Kreator'},
          {'icon': Icons.compare_arrows, 'label': 'Bandingkan'},
          {'icon': Icons.calendar_month_outlined, 'label': 'Atur Jadwal'},
          {'icon': Icons.payment, 'label': 'Bayar DP'},
          {'icon': Icons.insights_rounded, 'label': 'Grafik Performa'},
        ],
        aiTips: [
          'Pilih pilot drone dan videografer berpengalaman untuk visual landscape memukau',
          'Buat paket bundling konten video cinematic dan foto spot Instagramable',
          'Gunakan kalender promosi untuk menyambut musim liburan mendatang',
        ],
      );
    }

    // 9. KOMUNITAS
    if (sub == 'community' || sub == 'komunitas') {
      return _RoleDashboardConfig(
        badge: '✦ MODE KOMUNITAS KREATIF',
        greeting: 'Halo, $name! 👥',
        subtitle: 'Satukan kreator lokal, selenggarakan workshop dan kolaborasi kreatif antar anggota.',
        primaryButtonLabel: '+ Buat Agenda Komunitas',
        primaryButtonIcon: Icons.groups_outlined,
        secondaryButtonLabel: 'Eksplor Kolaborasi',
        secondaryButtonIcon: Icons.handshake_outlined,
        recommendationTitle: 'Kolaborator Rekomendasi',
        recommendationNiche: 'Komunitas & Workshop',
        recommendationRole: 'client',
        metrics: [
          {
            'label': 'Anggota Komunitas',
            'value': '480',
            'icon': Icons.groups_outlined,
            'color': const Color(0xFF6366F1),
            'trend': 'Kreator aktif terdaftar',
            'breakdown': 'Jumlah anggota komunitas kreatif yang terdaftar dan aktif berinteraksi.',
            'action': 'Komunitas',
          },
          {
            'label': 'Event Komunitas',
            'value': '5',
            'icon': Icons.celebration_outlined,
            'color': const Color(0xFF10B981),
            'trend': 'Workshop & gathering aktif',
            'breakdown': 'Agenda kumpul rutin, showcase karya, dan workshop kreatif mendatang.',
            'action': 'Atur Jadwal',
          },
          {
            'label': 'Kolaborasi Berjalan',
            'value': '12',
            'icon': Icons.handshake_outlined,
            'color': const Color(0xFF3B82F6),
            'trend': 'Karya kolaboratif tim',
            'breakdown': 'Proyek karya bersama antar anggota lintas disiplin ilmu kreatif.',
            'action': 'Proyek Berjalan',
          },
          {
            'label': 'Kas & Anggaran',
            'value': _overviewSummary['estimated_expenses']?.toString() ?? 'Rp 6,5 Jt',
            'icon': Icons.account_balance_wallet_outlined,
            'color': const Color(0xFFF59E0B),
            'trend': 'Dana kegiatan komunitas',
            'breakdown': 'Total perputaran dana iuran dan kas kegiatan bersama komunitas.',
            'action': 'Grafik Performa',
          },
        ],
        quickActions: [
          {'icon': Icons.celebration_outlined, 'label': 'Buat Agenda Komunitas'},
          {'icon': Icons.search, 'label': 'Cari Kreator'},
          {'icon': Icons.handshake_outlined, 'label': 'Komunitas'},
          {'icon': Icons.calendar_month_outlined, 'label': 'Atur Jadwal'},
          {'icon': Icons.assessment_outlined, 'label': 'Laporan'},
          {'icon': Icons.insights_rounded, 'label': 'Grafik Performa'},
        ],
        aiTips: [
          'Ajak anggota saling memberi ulasan positif untuk meningkatkan kredibilitas',
          'Buat ruang kolaborasi multi-disiplin seperti desainer bersama animator',
          'Dokumentasikan setiap sesi workshop untuk menarik anggota baru',
        ],
      );
    }

    // 10. FOTOGRAFER
    if (sub == 'fotografer' || sub == 'photographer') {
      return _RoleDashboardConfig(
        badge: '✦ FOTOGRAFER PROFESIONAL',
        greeting: 'Halo, $name! 📸',
        subtitle: 'Kelola jadwal pemotretan, tawarkan paket sesi foto, dan pamerkan portofolio visual terbaik Anda.',
        primaryButtonLabel: 'Upload Foto',
        primaryButtonIcon: Icons.add_photo_alternate_outlined,
        secondaryButtonLabel: 'Atur Jadwal Sesi',
        secondaryButtonIcon: Icons.calendar_month_outlined,
        recommendationTitle: 'Peluang & Sesi Foto Rekomendasi',
        recommendationNiche: 'Fotografi',
        recommendationRole: 'creator',
        metrics: [
          {
            'label': 'Sesi Foto Aktif',
            'value': inProgressCount > 0 ? '$inProgressCount' : '4',
            'icon': Icons.camera_alt_outlined,
            'color': const Color(0xFF6366F1),
            'trend': '↑ 2 sesi minggu ini',
            'breakdown': 'Sesi pemotretan aktif dalam proses penjadwalan & editing.',
            'action': 'Proyek Berjalan',
          },
          {
            'label': 'Jadwal Pemotretan',
            'value': _agenda.isNotEmpty ? '${_agenda.length}' : '6',
            'icon': Icons.calendar_month_outlined,
            'color': const Color(0xFF10B981),
            'trend': 'Jadwal terkonfirmasi',
            'breakdown': 'Sesi foto terdaftar di kalender kerja Anda.',
            'action': 'Atur Jadwal',
          },
          {
            'label': 'Portofolio Foto',
            'value': '28 Foto',
            'icon': Icons.collections_outlined,
            'color': const Color(0xFFF59E0B),
            'trend': 'Karya terpublikasi',
            'breakdown': 'Foto dan album karya yang tampil di marketplace.',
            'action': 'Tambah Karya',
          },
          {
            'label': 'Pendapatan Foto',
            'value': _overviewSummary['monthly_income']?.toString() ?? 'Rp 8,5 Jt',
            'icon': Icons.account_balance_wallet_outlined,
            'color': const Color(0xFF3B82F6),
            'trend': '↑ 18% bulan ini',
            'breakdown': 'Total honorarium dari sesi foto yang telah selesai.',
            'action': 'Grafik Performa',
          },
        ],
        quickActions: [
          {'icon': Icons.add_photo_alternate_outlined, 'label': 'Upload Foto'},
          {'icon': Icons.camera_alt_outlined, 'label': 'Paket Foto'},
          {'icon': Icons.event_available_outlined, 'label': 'Booking Sesi'},
          {'icon': Icons.search, 'label': 'Cari Klien'},
          {'icon': Icons.payments_outlined, 'label': 'Tarik Saldo'},
          {'icon': Icons.insights_rounded, 'label': 'Grafik Performa'},
        ],
        aiTips: [
          'Unggah foto beresolusi tinggi dengan watermark halus untuk portofolio',
          'Pastikan rincian gear kamera dan lensa tertulis jelas di paket foto',
          'Kirim teaser foto H+1 setelah pemotretan untuk memikat klien',
        ],
      );
    }

    // 11. VIDEOGRAFER
    if (sub == 'videografer' || sub == 'videographer') {
      return _RoleDashboardConfig(
        badge: '✦ VIDEOGRAFER PROFESIONAL',
        greeting: 'Halo, $name! 🎥',
        subtitle: 'Kelola jadwal syuting produksi video, tawarkan paket cinematic, dan pamerkan showreel terbaik Anda.',
        primaryButtonLabel: 'Upload Showreel',
        primaryButtonIcon: Icons.video_library_outlined,
        secondaryButtonLabel: 'Jadwal Syuting',
        secondaryButtonIcon: Icons.calendar_month_outlined,
        recommendationTitle: 'Peluang Produksi Video Rekomendasi',
        recommendationNiche: 'Videografi',
        recommendationRole: 'creator',
        metrics: [
          {
            'label': 'Proyek Video',
            'value': inProgressCount > 0 ? '$inProgressCount' : '3',
            'icon': Icons.videocam_outlined,
            'color': const Color(0xFF8B5CF6),
            'trend': 'Produksi aktif',
            'breakdown': 'Proyek video syuting dan pascaproduksi berjalan.',
            'action': 'Proyek Berjalan',
          },
          {
            'label': 'Jadwal Syuting',
            'value': _agenda.isNotEmpty ? '${_agenda.length}' : '5',
            'icon': Icons.calendar_month_outlined,
            'color': const Color(0xFF10B981),
            'trend': 'Lokasi terkonfirmasi',
            'breakdown': 'Jadwal pengambilan gambar aktif di kalender.',
            'action': 'Atur Jadwal',
          },
          {
            'label': 'Showreel Karya',
            'value': '16 Video',
            'icon': Icons.movie_filter_outlined,
            'color': const Color(0xFFF59E0B),
            'trend': 'Koleksi portofolio',
            'breakdown': 'Karya visual cinematic yang diunggah ke profil.',
            'action': 'Tambah Karya',
          },
          {
            'label': 'Pendapatan Video',
            'value': _overviewSummary['monthly_income']?.toString() ?? 'Rp 14,2 Jt',
            'icon': Icons.account_balance_wallet_outlined,
            'color': const Color(0xFF3B82F6),
            'trend': '↑ 22% bulan ini',
            'breakdown': 'Pendapatan dari kontrak video yang telah rampung.',
            'action': 'Grafik Performa',
          },
        ],
        quickActions: [
          {'icon': Icons.video_library_outlined, 'label': 'Upload Showreel'},
          {'icon': Icons.videocam_outlined, 'label': 'Paket Video'},
          {'icon': Icons.calendar_month_outlined, 'label': 'Jadwal Syuting'},
          {'icon': Icons.search, 'label': 'Cari Klien'},
          {'icon': Icons.payments_outlined, 'label': 'Tarik Saldo'},
          {'icon': Icons.insights_rounded, 'label': 'Grafik Performa'},
        ],
        aiTips: [
          'Sertakan teaser video 15 detik di portofolio untuk respons lebih cepat',
          'Cantumkan daftar resolusi perekaman (4K/60fps) dan color profile kamera',
          'Gunakan storage Kreavana untuk pengiriman draft preview ke klien',
        ],
      );
    }

    // 12. EDITOR
    if (sub == 'editor' || sub == 'video_editor') {
      return _RoleDashboardConfig(
        badge: '✦ VIDEO & AUDIO EDITOR',
        greeting: 'Halo, $name! ✂️',
        subtitle: 'Pantau antrean editing video, kelola revisi klien, dan serahkan deliverable tepat waktu.',
        primaryButtonLabel: 'Antrean Editing',
        primaryButtonIcon: Icons.pending_actions_outlined,
        secondaryButtonLabel: 'Upload Draft',
        secondaryButtonIcon: Icons.upload_file_outlined,
        recommendationTitle: 'Peluang Editing & Post-Pro Rekomendasi',
        recommendationNiche: 'Video Editing',
        recommendationRole: 'creator',
        metrics: [
          {
            'label': 'Antrean Edit',
            'value': '5 Proyek',
            'icon': Icons.pending_actions_outlined,
            'color': const Color(0xFF6366F1),
            'trend': 'On progress',
            'breakdown': 'File mentah yang sedang dalam tahap cutting & grading.',
            'action': 'Antrean Editing',
          },
          {
            'label': 'Tenggat Waktu',
            'value': '2 Hari',
            'icon': Icons.timer_outlined,
            'color': const Color(0xFFEF4444),
            'trend': 'Deliverable terdekat',
            'breakdown': 'Sisa batas waktu untuk penyerahan draft review.',
            'action': 'Atur Jadwal',
          },
          {
            'label': 'Revisi Selesai',
            'value': '18 Cut',
            'icon': Icons.done_all_rounded,
            'color': const Color(0xFF10B981),
            'trend': 'Revisi klien approved',
            'breakdown': 'Hasil revisi video yang telah disetujui klien.',
            'action': 'Proyek Berjalan',
          },
          {
            'label': 'Pendapatan Editing',
            'value': _overviewSummary['monthly_income']?.toString() ?? 'Rp 7,8 Jt',
            'icon': Icons.account_balance_wallet_outlined,
            'color': const Color(0xFF3B82F6),
            'trend': '↑ 15% bulan ini',
            'breakdown': 'Hasil dari proyek editing dan color grading.',
            'action': 'Grafik Performa',
          },
        ],
        quickActions: [
          {'icon': Icons.pending_actions_outlined, 'label': 'Antrean Editing'},
          {'icon': Icons.upload_file_outlined, 'label': 'Upload Draft'},
          {'icon': Icons.cut_outlined, 'label': 'Paket Edit'},
          {'icon': Icons.search, 'label': 'Cari Klien'},
          {'icon': Icons.payments_outlined, 'label': 'Tarik Dana'},
          {'icon': Icons.insights_rounded, 'label': 'Grafik Performa'},
        ],
        aiTips: [
          'Export draft dengan resolusi 720p ringan untuk mempercepat review klien',
          'Terapkan batas maksimal 2x revisi minor dalam deskripsi paket edit',
          'Gunakan penamaan file rapi (v1, v2_final) saat mengirimkan deliverable',
        ],
      );
    }

    // 13. DESAINER GRAFIS & BRANDING
    if (sub == 'desainer' ||
        sub == 'designer' ||
        sub == 'graphic_designer' ||
        sub == 'ui_ux') {
      return _RoleDashboardConfig(
        badge: '✦ DESAINER GRAFIS & BRANDING',
        greeting: 'Halo, $name! 🎨',
        subtitle: 'Kelola pesanan desain visual, identitas brand, dan pamerkan portofolio grafis Anda.',
        primaryButtonLabel: 'Upload Karya',
        primaryButtonIcon: Icons.palette_outlined,
        secondaryButtonLabel: 'Proyek Desain',
        secondaryButtonIcon: Icons.design_services_outlined,
        recommendationTitle: 'Peluang Desain & Branding Rekomendasi',
        recommendationNiche: 'Desain Grafis',
        recommendationRole: 'creator',
        metrics: [
          {
            'label': 'Desain Aktif',
            'value': inProgressCount > 0 ? '$inProgressCount' : '4',
            'icon': Icons.brush_outlined,
            'color': const Color(0xFFEC4899),
            'trend': 'Brief dikerjakan',
            'breakdown': 'Pesanan aset visual, logo, dan packaging aktif.',
            'action': 'Proyek Desain',
          },
          {
            'label': 'File Diserahkan',
            'value': '22 Desain',
            'icon': Icons.task_alt_outlined,
            'color': const Color(0xFF10B981),
            'trend': 'Master file terkirim',
            'breakdown': 'File vector dan master desain yang telah selesai.',
            'action': 'Proyek Berjalan',
          },
          {
            'label': 'Aset Karya',
            'value': '45 Aset',
            'icon': Icons.collections_bookmark_outlined,
            'color': const Color(0xFFF59E0B),
            'trend': 'Koleksi marketplace',
            'breakdown': 'Aset template dan mockup di profil kreator.',
            'action': 'Tambah Karya',
          },
          {
            'label': 'Pendapatan Desain',
            'value': _overviewSummary['monthly_income']?.toString() ?? 'Rp 9,2 Jt',
            'icon': Icons.account_balance_wallet_outlined,
            'color': const Color(0xFF3B82F6),
            'trend': '↑ 20% bulan ini',
            'breakdown': 'Pendapatan dari proyek desain visual dan branding.',
            'action': 'Grafik Performa',
          },
        ],
        quickActions: [
          {'icon': Icons.design_services_outlined, 'label': 'Proyek Desain'},
          {'icon': Icons.palette_outlined, 'label': 'Paket Desain'},
          {'icon': Icons.add_photo_alternate_outlined, 'label': 'Upload Karya'},
          {'icon': Icons.search, 'label': 'Cari Klien'},
          {'icon': Icons.payments_outlined, 'label': 'Tarik Dana'},
          {'icon': Icons.insights_rounded, 'label': 'Grafik Performa'},
        ],
        aiTips: [
          'Tampilkan visualisasi mockup 3D untuk presentasi logo atau packaging',
          'Sertakan palet warna HEX dan panduan font dalam penyerahan brand kit',
          'Tawarkan variasi format (PNG transparan, SVG, AI/PSD) dalam paket',
        ],
      );
    }

    // 14. ANIMATOR 3D & MOTION DESIGNER
    if (sub == 'animator' ||
        sub == '3d_animator' ||
        sub == 'motion_designer') {
      return _RoleDashboardConfig(
        badge: '✦ ANIMATOR 3D & MOTION DESIGNER',
        greeting: 'Halo, $name! 🎬',
        subtitle: 'Pantau antrean render animasi 3D, kelola motion graphic, dan serahkan aset digital.',
        primaryButtonLabel: 'Antrean Render',
        primaryButtonIcon: Icons.view_in_ar_outlined,
        secondaryButtonLabel: 'Upload Aset 3D',
        secondaryButtonIcon: Icons.upload_file_outlined,
        recommendationTitle: 'Peluang Animasi & Motion Rekomendasi',
        recommendationNiche: 'Animasi 3D',
        recommendationRole: 'creator',
        metrics: [
          {
            'label': 'Proyek 3D',
            'value': inProgressCount > 0 ? '$inProgressCount' : '2',
            'icon': Icons.view_in_ar_outlined,
            'color': const Color(0xFF8B5CF6),
            'trend': 'Modeling & Rigging',
            'breakdown': 'Proyek karakter dan scene animasi 3D sedang berjalan.',
            'action': 'Proyek Berjalan',
          },
          {
            'label': 'Antrean Render',
            'value': '3 Scene',
            'icon': Icons.hourglass_top_outlined,
            'color': const Color(0xFFF59E0B),
            'trend': 'Render farm aktif',
            'breakdown': 'Scene yang sedang dalam proses baking dan rendering.',
            'action': 'Antrean Render',
          },
          {
            'label': 'Aset Animasi',
            'value': '14 Aset',
            'icon': Icons.animation_outlined,
            'color': const Color(0xFF10B981),
            'trend': 'Model siap jual',
            'breakdown': 'Rigged model dan motion pack di marketplace.',
            'action': 'Tambah Karya',
          },
          {
            'label': 'Pendapatan Animasi',
            'value': _overviewSummary['monthly_income']?.toString() ?? 'Rp 16,5 Jt',
            'icon': Icons.account_balance_wallet_outlined,
            'color': const Color(0xFF3B82F6),
            'trend': '↑ 25% bulan ini',
            'breakdown': 'Hasil dari pesanan animasi dan lisensi aset 3D.',
            'action': 'Grafik Performa',
          },
        ],
        quickActions: [
          {'icon': Icons.view_in_ar_outlined, 'label': 'Antrean Render'},
          {'icon': Icons.upload_file_outlined, 'label': 'Upload Aset 3D'},
          {'icon': Icons.animation_outlined, 'label': 'Paket Animasi'},
          {'icon': Icons.search, 'label': 'Cari Klien'},
          {'icon': Icons.payments_outlined, 'label': 'Tarik Dana'},
          {'icon': Icons.insights_rounded, 'label': 'Grafik Performa'},
        ],
        aiTips: [
          'Sertakan wireframe dan render breakdown di showcase karya',
          'Tentukan framerate (24fps vs 60fps) dan format render di awal brief',
          'Kirim preview playblast resolusi rendah sebelum melakukan final render',
        ],
      );
    }

    // 15. MAKEUP ARTIST (MUA)
    if (sub == 'mua' || sub == 'makeup_artist' || sub == 'makeup') {
      return _RoleDashboardConfig(
        badge: '✦ MAKEUP ARTIST & BEAUTY',
        greeting: 'Halo, $name! 💄',
        subtitle: 'Kelola jadwal booking makeup, tawarkan paket rias pengantin, dan pamerkan portofolio kecantikan.',
        primaryButtonLabel: 'Paket MUA',
        primaryButtonIcon: Icons.brush_outlined,
        secondaryButtonLabel: 'Booking Rias',
        secondaryButtonIcon: Icons.calendar_month_outlined,
        recommendationTitle: 'Peluang Rias & Beauty Rekomendasi',
        recommendationNiche: 'Makeup Artist',
        recommendationRole: 'creator',
        metrics: [
          {
            'label': 'Booking Rias',
            'value': '6 Klien',
            'icon': Icons.face_retouching_natural_outlined,
            'color': const Color(0xFFEC4899),
            'trend': 'Sesi terkonfirmasi',
            'breakdown': 'Jadwal rias wisuda, prewedding, dan wedding mendatang.',
            'action': 'Booking Rias',
          },
          {
            'label': 'Jadwal Makeup',
            'value': _agenda.isNotEmpty ? '${_agenda.length}' : '4',
            'icon': Icons.calendar_month_outlined,
            'color': const Color(0xFF10B981),
            'trend': 'Jadwal minggu ini',
            'breakdown': 'Waktu dan lokasi rias aktif di kalender.',
            'action': 'Atur Jadwal',
          },
          {
            'label': 'Portofolio MUA',
            'value': '32 Look',
            'icon': Icons.photo_library_outlined,
            'color': const Color(0xFFF59E0B),
            'trend': 'Galeri lookbook',
            'breakdown': 'Koleksi riasan natural, bold, dan pengantin di profil.',
            'action': 'Tambah Karya',
          },
          {
            'label': 'Pendapatan Rias',
            'value': _overviewSummary['monthly_income']?.toString() ?? 'Rp 6,8 Jt',
            'icon': Icons.account_balance_wallet_outlined,
            'color': const Color(0xFF3B82F6),
            'trend': '↑ 14% bulan ini',
            'breakdown': 'Total honorarium dari sesi rias yang terlaksana.',
            'action': 'Grafik Performa',
          },
        ],
        quickActions: [
          {'icon': Icons.brush_outlined, 'label': 'Paket MUA'},
          {'icon': Icons.calendar_month_outlined, 'label': 'Booking Rias'},
          {'icon': Icons.photo_library_outlined, 'label': 'Upload Look'},
          {'icon': Icons.search, 'label': 'Cari Klien'},
          {'icon': Icons.payments_outlined, 'label': 'Tarik Saldo'},
          {'icon': Icons.insights_rounded, 'label': 'Grafik Performa'},
        ],
        aiTips: [
          'Foto hasil riasan dengan pencahayaan natural ring-light untuk feed profil',
          'Sertakan daftar merek kosmetik premium yang digunakan dalam paket',
          'Konfirmasi alergi kulit klien H-2 sebelum sesi makeup dimulai',
        ],
      );
    }

    // 16. PILOT DRONE
    if (sub == 'drone' || sub == 'drone_pilot' || sub == 'pilot_drone') {
      return _RoleDashboardConfig(
        badge: '✦ PILOT DRONE & AERIAL CREATOR',
        greeting: 'Halo, $name! 🛸',
        subtitle: 'Kelola misi penerbangan udara, pantau logbook drone, dan tawarkan jasa foto/video aerial.',
        primaryButtonLabel: 'Paket Drone',
        primaryButtonIcon: Icons.flight_takeoff_outlined,
        secondaryButtonLabel: 'Booking Terbang',
        secondaryButtonIcon: Icons.calendar_month_outlined,
        recommendationTitle: 'Peluang Aerial & Mapping Rekomendasi',
        recommendationNiche: 'Pilot Drone',
        recommendationRole: 'creator',
        metrics: [
          {
            'label': 'Sesi Terbang',
            'value': '8 Misi',
            'icon': Icons.flight_outlined,
            'color': const Color(0xFF06B6D4),
            'trend': 'Misi aktif terdaftar',
            'breakdown': 'Misi aerial video dokumentasi dan pemetaan lahan.',
            'action': 'Booking Terbang',
          },
          {
            'label': 'Jadwal Mapping',
            'value': _agenda.isNotEmpty ? '${_agenda.length}' : '3',
            'icon': Icons.calendar_month_outlined,
            'color': const Color(0xFF10B981),
            'trend': 'Izin terbang aman',
            'breakdown': 'Jadwal take-off di lokasi yang terkonfirmasi.',
            'action': 'Atur Jadwal',
          },
          {
            'label': 'Footage Udara',
            'value': '20 Klip',
            'icon': Icons.videocam_outlined,
            'color': const Color(0xFFF59E0B),
            'trend': 'Aset 4K terunggah',
            'breakdown': 'Footage pemandangan dan arsitektur di marketplace.',
            'action': 'Tambah Karya',
          },
          {
            'label': 'Pendapatan Pilot',
            'value': _overviewSummary['monthly_income']?.toString() ?? 'Rp 11,5 Jt',
            'icon': Icons.account_balance_wallet_outlined,
            'color': const Color(0xFF3B82F6),
            'trend': '↑ 19% bulan ini',
            'breakdown': 'Total honorarium dari misi penerbangan drone selesai.',
            'action': 'Grafik Performa',
          },
        ],
        quickActions: [
          {'icon': Icons.flight_takeoff_outlined, 'label': 'Paket Drone'},
          {'icon': Icons.calendar_month_outlined, 'label': 'Booking Terbang'},
          {'icon': Icons.videocam_outlined, 'label': 'Upload Footage'},
          {'icon': Icons.search, 'label': 'Cari Klien'},
          {'icon': Icons.payments_outlined, 'label': 'Tarik Saldo'},
          {'icon': Icons.insights_rounded, 'label': 'Grafik Performa'},
        ],
        aiTips: [
          'Pastikan sertifikat pilot FASI/DKPPU tercantum di badge profil',
          'Cek prakiraan cuaca dan zona larangan terbang (NFZ) sebelum penerbangan',
          'Simpan backup rekaman logbook baterai dan micro-SD segera pasca terbang',
        ],
      );
    }

    // VENDOR & PENYEDIA JASA PENDUKUNG (Role 3: Studio, Rental Alat, MUA, Wardrobe, Dekorasi, Katering, Printing, Lighting, Transportasi)
    if (_isVendorOrMitra) {
      return _RoleDashboardConfig(
        badge: '✦ ROLE 3: VENDOR & PENYEDIA JASA PENDUKUNG',
        greeting: 'Halo, $name! 🏢',
        subtitle: 'Studio, rental alat, MUA, wardrobe, dekorasi, katering, printing, lighting, sound, transportasi, dan jasa pendukung lainnya.',
        primaryButtonLabel: 'Katalog & Harga',
        primaryButtonIcon: Icons.inventory_2_outlined,
        secondaryButtonLabel: 'Atur Ketersediaan',
        secondaryButtonIcon: Icons.calendar_today_outlined,
        recommendationTitle: 'Permintaan Sewa Alat & Jasa Pendukung',
        recommendationNiche: 'Vendor & Jasa Pendukung',
        recommendationRole: 'creator',
        metrics: [
          {
            'label': 'Katalog Produk & Alat',
            'value': '18 Item',
            'icon': Icons.inventory_2_outlined,
            'color': const Color(0xFFD97706),
            'trend': 'Tersedia & Siap Sewa',
            'breakdown': 'Studio, kamera, lighting, wardrobe, dekorasi & armada aktif di katalog.',
            'action': 'Katalog & Harga',
          },
          {
            'label': 'Ketersediaan & Jadwal',
            'value': '8 Booking',
            'icon': Icons.event_available_outlined,
            'color': const Color(0xFF10B981),
            'trend': 'Slot Terjadwal',
            'breakdown': 'Kalender ketersediaan sewa studio, unit gear, dan tim layanan terverifikasi.',
            'action': 'Atur Ketersediaan',
          },
          {
            'label': 'Permintaan Masuk',
            'value': '5 Order Baru',
            'icon': Icons.move_to_inbox_outlined,
            'color': const Color(0xFFEA580C),
            'trend': 'Perlu Konfirmasi',
            'breakdown': 'Permintaan penyewaan & jasa pendukung dari kreator, klien, dan EO.',
            'action': 'Terima Permintaan',
          },
          {
            'label': 'Total Omzet Sewa',
            'value': _overviewSummary['monthly_income']?.toString() ?? 'Rp 28,5 Jt',
            'icon': Icons.verified_rounded,
            'color': const Color(0xFF2563EB),
            'trend': '4.9 ★ (#Dampak)',
            'breakdown': 'Pendapatan riil dari penyewaan unit alat, fasilitas, dan jasa operasional.',
            'action': 'Ulasan & Reputasi',
          },
        ],
        quickActions: [
          {'icon': Icons.inventory_2_outlined, 'label': 'Katalog & Harga'},
          {'icon': Icons.calendar_today_outlined, 'label': 'Atur Ketersediaan'},
          {'icon': Icons.move_to_inbox_outlined, 'label': 'Terima Permintaan'},
          {'icon': Icons.build_circle_outlined, 'label': 'Laksanakan Layanan'},
          {'icon': Icons.star_rate_rounded, 'label': 'Ulasan & Reputasi'},
          {'icon': Icons.travel_explore_outlined, 'label': 'Jelajahi Permintaan Proyek'},
        ],
        aiTips: [
          'Lengkapi spesifikasi unit rental dan syarat deposit pada katalog untuk mempercepat proses booking klien.',
          'Sinkronkan kalender ketersediaan H-1 event besar agar tidak terjadi double-booking antar tim.',
          'Berikan checklist serah-terima (handover) saat unit diambil untuk mempertahankan rating bintang 5.',
        ],
      );
    }

    // 17. TALENT & PERFORMER (Model, Aktor, MC, Penyanyi, Musisi, Penari, VO, dll)
    if (_isTalentAndPerformer) {
      return _RoleDashboardConfig(
        badge: '✦ ROLE TALENT & PERFORMER',
        greeting: 'Halo, $name! 🌟',
        subtitle: 'Tampilkan Bakat, Temukan Peluang, Bangun Reputasi — Ekosistem Kolaborasi dengan Klien, Kreator, Vendor, & Komunitas.',
        primaryButtonLabel: 'Cari Casting & Job',
        primaryButtonIcon: Icons.campaign_outlined,
        secondaryButtonLabel: 'Unggah Showreel',
        secondaryButtonIcon: Icons.smart_display_outlined,
        recommendationTitle: 'Peluang Casting, Job & Event Rekomendasi',
        recommendationNiche: 'Talent & Performer',
        recommendationRole: 'creator',
        metrics: [
          {
            'label': 'Casting & Peluang',
            'value': '6 Panggilan',
            'icon': Icons.campaign_outlined,
            'color': const Color(0xFFEA580C),
            'trend': 'Audisi & Kontrak Aktif',
            'breakdown': 'Peluang casting iklan komersial, pemeran serial/film, MC formal, dan live show.',
            'action': 'Cari Casting & Job',
          },
          {
            'label': 'Jadwal Tampil',
            'value': _agenda.isNotEmpty ? '${_agenda.length} Agenda' : '4 Agenda',
            'icon': Icons.calendar_month_outlined,
            'color': const Color(0xFF10B981),
            'trend': 'Jadwal & Gladi Resik',
            'breakdown': 'Waktu gladi resik, fitting kostum/MUA, dan live performa panggung tercatat rapi.',
            'action': 'Jadwal & Ketersediaan',
          },
          {
            'label': 'Showreel & Comp Card',
            'value': 'Portofolio Aktif',
            'icon': Icons.smart_display_outlined,
            'color': const Color(0xFF8B5CF6),
            'trend': 'Kualitas Terverifikasi',
            'breakdown': 'Kartu komposit (sedcard), video showreel peragaan & performa panggung siap diajukan ke klien.',
            'action': 'Unggah Showreel',
          },
          {
            'label': 'Honor & Reputasi',
            'value': _overviewSummary['monthly_income']?.toString() ?? 'Rp 14,8 Jt',
            'icon': Icons.verified_rounded,
            'color': const Color(0xFF2563EB),
            'trend': '4.9 ★ (#Dampak)',
            'breakdown': 'Total honorarium dari kontrak kerja selesai dan ulasan terpercaya dari klien & mitra ekosistem.',
            'action': 'Rating & Reputasi',
          },
        ],
        quickActions: [
          {'icon': Icons.campaign_outlined, 'label': 'Cari Casting & Job'},
          {'icon': Icons.smart_display_outlined, 'label': 'Unggah Showreel'},
          {'icon': Icons.calendar_today_outlined, 'label': 'Jadwal & Ketersediaan'},
          {'icon': Icons.groups_outlined, 'label': 'Kolaborasi Kreator'},
          {'icon': Icons.handshake_outlined, 'label': 'Mitra Vendor & MUA'},
          {'icon': Icons.stars_rounded, 'label': 'Rating & Ulasan'},
        ],
        aiTips: [
          'Sertakan video showreel 60 detik terbaru untuk casting iklan TVC & video komersial brand ternama',
          'Perbarui kalender panggung & ketersediaan tanggal H-3 sebelum audisi untuk mencegah bentrok jadwal',
          'Manfaatkan jaringan mitra MUA & fotografer Kreavana untuk menyusun comp card standar internasional',
        ],
      );
    }

    // 18. CONTENT CREATOR
    if (sub == 'content_creator' || sub == 'influencer' || sub == 'ugc') {
      return _RoleDashboardConfig(
        badge: '✦ CONTENT CREATOR & INFLUENCER',
        greeting: 'Halo, $name! 📱',
        subtitle: 'Kelola campaign promosi brand, atur jadwal posting, dan pantau engagement rate media kit Anda.',
        primaryButtonLabel: 'Cari Campaign',
        primaryButtonIcon: Icons.campaign_outlined,
        secondaryButtonLabel: 'Paket Konten',
        secondaryButtonIcon: Icons.library_add_check_outlined,
        recommendationTitle: 'Peluang Campaign Brand Rekomendasi',
        recommendationNiche: 'Content Creator',
        recommendationRole: 'creator',
        metrics: [
          {
            'label': 'Campaign Cocok',
            'value': _overviewSummary['active_needs']?.toString() ?? '14',
            'icon': Icons.campaign_outlined,
            'color': const Color(0xFF7C3AED),
            'trend': '↑ 5 campaign baru',
            'breakdown': 'Peluang kolaborasi sponsorship brand sesuai niche Anda.',
            'action': 'Cari Campaign',
          },
          {
            'label': 'Jadwal Posting',
            'value': _agenda.isNotEmpty ? '${_agenda.length}' : '6',
            'icon': Icons.calendar_month_outlined,
            'color': const Color(0xFF10B981),
            'trend': 'Deadline posting aktif',
            'breakdown': 'Jadwal upload konten reels/tiktok/story yang disepakati.',
            'action': 'Jadwal Posting',
          },
          {
            'label': 'Engagement Rate',
            'value': '5.8%',
            'icon': Icons.trending_up,
            'color': const Color(0xFFF59E0B),
            'trend': 'Rata-rata interaksi',
            'breakdown': 'Tingkat like, komen, dan share rata-rata konten Anda.',
            'action': 'Grafik Performa',
          },
          {
            'label': 'Pendapatan Campaign',
            'value': _overviewSummary['monthly_income']?.toString() ?? 'Rp 12,8 Jt',
            'icon': Icons.account_balance_wallet_outlined,
            'color': const Color(0xFF3B82F6),
            'trend': '↑ 24% bulan ini',
            'breakdown': 'Hasil dari endorsement dan campaign yang terlaksana.',
            'action': 'Grafik Performa',
          },
        ],
        quickActions: [
          {'icon': Icons.campaign_outlined, 'label': 'Cari Campaign'},
          {'icon': Icons.library_add_check_outlined, 'label': 'Paket Konten'},
          {'icon': Icons.calendar_month_outlined, 'label': 'Jadwal Posting'},
          {'icon': Icons.add_photo_alternate_outlined, 'label': 'Upload Karya'},
          {'icon': Icons.payments_outlined, 'label': 'Tarik Dana'},
          {'icon': Icons.insights_rounded, 'label': 'Grafik Performa'},
        ],
        aiTips: [
          'Sertakan insight tangkapan layar demografi followers di media kit',
          'Kirim draft video ke klien melalui chat Kreavana sebelum diposting publik',
          'Tulis hashtag dan disclosure kemitraan berbayar secara transparan',
        ],
      );
    }

    // 19. KREATOR SPESIFIK & UMUM (Fallback)
    if (_isCreator || user.role == 'creator' || user.isCreator) {
      final subLabel = sub.isNotEmpty
          ? sub.replaceAll('_', ' ').toUpperCase()
          : 'KREATOR';

      return _RoleDashboardConfig(
        badge: '✦ $subLabel PROFESIONAL',
        greeting: 'Halo, $name! ✨',
        subtitle: 'Temukan campaign & peluang proyek, kelola jadwal produksi, bangun portofolio, dan pantau penghasilan.',
        primaryButtonLabel: 'Cari Peluang Proyek',
        primaryButtonIcon: Icons.search_rounded,
        secondaryButtonLabel: 'Kelola Portofolio',
        secondaryButtonIcon: Icons.collections_bookmark_outlined,
        recommendationTitle: 'Peluang & Campaign Rekomendasi',
        recommendationNiche: 'Peluang Kreatif',
        recommendationRole: 'creator',
        metrics: [
          {
            'label': 'Campaign Cocok',
            'value': _overviewSummary['active_needs']?.toString() ?? '21',
            'icon': Icons.event_available_outlined,
            'color': const Color(0xFF7C3AED),
            'trend': '↑ 5 minggu ini',
            'breakdown': 'Peluang proyek dan kampanye yang cocok dengan sub-role keahlian Anda.',
            'action': 'Cari Peluang Proyek',
          },
          {
            'label': 'Jadwal Posting / Event',
            'value': _agenda.isNotEmpty ? '${_agenda.length}' : '8',
            'icon': Icons.calendar_today_outlined,
            'color': const Color(0xFF10B981),
            'trend': '↑ 2 minggu ini',
            'breakdown': 'Agenda jadwal pemotretan, produksi, atau penyerahan hasil karya aktif.',
            'action': 'Atur Jadwal',
          },
          {
            'label': 'Rating & Win Rate',
            'value': '4.9 • 85%',
            'icon': Icons.star_outline_rounded,
            'color': const Color(0xFF3B82F6),
            'trend': 'Rata-rata profil',
            'breakdown': 'Kepuasan klien dan tingkat persetujuan proposal penawaran Anda.',
            'action': 'Grafik Performa',
          },
          {
            'label': 'Pendapatan Bulan Ini',
            'value': _overviewSummary['monthly_income']?.toString() ?? 'Rp 18,4 Jt',
            'icon': Icons.account_balance_wallet_outlined,
            'color': const Color(0xFFF97316),
            'trend': '↑ 24% bulan lalu',
            'breakdown': 'Total pendapatan dari kontrak proyek yang telah diselesaikan.',
            'action': 'Grafik Performa',
          },
        ],
        quickActions: [
          {'icon': Icons.search, 'label': 'Cari Peluang'},
          {'icon': Icons.description_outlined, 'label': 'Kirim Proposal'},
          {'icon': Icons.insights_rounded, 'label': 'Grafik Performa'},
          {'icon': Icons.calendar_month_outlined, 'label': 'Atur Jadwal'},
          {'icon': Icons.payments_outlined, 'label': 'Tarik Dana'},
          {'icon': Icons.add_photo_alternate_outlined, 'label': 'Tambah Karya'},
        ],
        aiTips: [
          'Perbarui media kit dan portofolio karya terbaru Anda di platform',
          'Ajukan proposal dalam 24 jam pertama saat peluang proyek baru dibuka',
          'Jaga komunikasi yang ramah, transparan, dan tepat waktu dengan klien',
        ],
      );
    }

    // 11. MODE TAMU / CLIENT UMUM (Default)
    return _RoleDashboardConfig(
      badge: user.isGuest ? '✦ MODE TAMU' : '✦ MODE KLIEN',
      greeting: user.isGuest ? 'Halo, Tamu!' : 'Halo, $firstName!',
      subtitle: 'Buat kebutuhan, temukan kreator terbaik, dan pantau proyek dalam satu tempat.',
      primaryButtonLabel: 'Buat Kebutuhan',
      primaryButtonIcon: Icons.add_circle_outline,
      secondaryButtonLabel: 'Cari Kreator',
      secondaryButtonIcon: Icons.search_rounded,
      recommendationTitle: 'Kreator Rekomendasi',
      recommendationNiche: 'Kebutuhan Kreatif',
      recommendationRole: 'client',
      metrics: [
        {
          'label': 'Kebutuhan Aktif',
          'value': _overviewSummary['active_needs']?.toString() ?? '0',
          'icon': Icons.description_outlined,
          'color': const Color(0xFF3B82F6),
          'trend': '↑ 2 minggu ini',
          'breakdown': 'Kebutuhan proyek yang sedang dibuka dan mencari talenta kreator.',
          'action': 'Semua Proyek',
        },
        {
          'label': 'Proposal Masuk',
          'value': _overviewSummary['proposals_count']?.toString() ?? '0',
          'icon': Icons.mail_outline,
          'color': const Color(0xFF10B981),
          'trend': '↑ 6 minggu ini',
          'breakdown': 'Total lamaran dan penawaran kerja sama masuk dari kreator.',
          'action': 'Proposal Masuk',
        },
        {
          'label': 'Proyek Berjalan',
          'value': _overviewSummary['running_projects']?.toString() ?? '0',
          'icon': Icons.folder_open,
          'color': const Color(0xFF14B8A6),
          'trend': '↑ 1 minggu ini',
          'breakdown': 'Kontrak proyek yang sedang aktif berjalan dan dipantau progresnya.',
          'action': 'Proyek Berjalan',
        },
        {
          'label': 'Est. Pengeluaran',
          'value': _overviewSummary['estimated_expenses']?.toString() ?? 'Rp 0',
          'icon': Icons.account_balance_wallet_outlined,
          'color': const Color(0xFF7C3AED),
          'trend': '↑ 12% bulan ini',
          'breakdown': 'Perkiraan total dana terbayar dan komitmen escrow untuk pekerjaan berjalan.',
          'action': 'Grafik Performa',
        },
      ],
      quickActions: [
        {'icon': Icons.add_circle_outline, 'label': 'Buat Kebutuhan'},
        {'icon': Icons.search, 'label': 'Cari Kreator'},
        {'icon': Icons.insights_rounded, 'label': 'Grafik Performa'},
        {'icon': Icons.compare_arrows, 'label': 'Bandingkan'},
        {'icon': Icons.check_circle_outline, 'label': 'Setujui Proyek'},
        {'icon': Icons.payment, 'label': 'Bayar DP'},
      ],
      aiTips: [
        'Buat brief lebih detail agar proposal kreator lebih tepat sasaran',
        'Simpan kreator favorit untuk proyek atau repeat order berikutnya',
        'Gunakan agenda untuk memantau deadline dan progres hasil kerja',
      ],
    );
  }

  void _openCreatorService(String serviceKey) {
    if (widget.user.isGuest) {
      AuthGuardDialog.show(context, actionName: 'mengakses layanan kreator');
      return;
    }
    if (serviceKey.startsWith('komunitas_')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityDashboardScreen(
            user: widget.user,
            initialServiceKey: serviceKey,
            onUserUpdated: widget.onUserUpdated,
            showSidebar: true,
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatorServiceScreen(
          user: widget.user,
          serviceKey: serviceKey,
          onUserUpdated: widget.onUserUpdated,
        ),
      ),
    );
  }

  void _openInstitutionWorkspace([String resourceType = 'dashboard']) {
    if (widget.user.isGuest) {
      AuthGuardDialog.show(context, actionName: 'mengakses workspace institusi');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InstitutionWorkspaceScreen(
          user: widget.user,
          resourceType: resourceType,
          onUserUpdated: widget.onUserUpdated,
        ),
      ),
    );
  }

  void _navigateTo(String feature) {
    final clean = feature.replaceAll('+', '').replaceAll('🔍', '').replaceAll('📁', '').trim();
    final sub = CreatorSidebarMenus.normalizeSubRole(widget.user.subRole);

    switch (clean) {
      // ── Layanan Vendor & Jasa Pendukung (Role 3) ──
      case 'Katalog & Harga':
      case 'Unggah Katalog':
      case 'Katalog Produk & Alat':
      case 'Katalog Vendor':
        _openCreatorService('vendor_katalog');
        break;
      case 'Atur Ketersediaan':
      case 'Jadwal & Ketersediaan':
      case 'Jadwal & Ketersediaan Alat':
      case 'Kalender Sewa':
      case 'Ketersediaan Sewa':
        _openCreatorService('vendor_ketersediaan');
        break;
      case 'Terima Permintaan':
      case 'Permintaan Sewa':
      case 'Order Masuk':
      case 'Pesanan & Order Masuk':
      case 'Permintaan & Pesanan':
        _openCreatorService('vendor_permintaan');
        break;
      case 'Laksanakan Layanan':
      case 'Operasional & Handover':
      case 'Status Handover':
      case 'Eksekusi Layanan':
      case 'Layanan & Operasional':
        _openCreatorService('vendor_operasional');
        break;
      case 'Ulasan & Reputasi':
      case 'Ulasan Vendor':
      case 'Bangun Reputasi':
      case 'Reputasi & Ulasan Klien':
        _openCreatorService('vendor_reputasi');
        break;
      case 'Jelajahi Permintaan Proyek':
      case 'Cari Permintaan Proyek':
        context.go(AppRoutes.peluangProyek);
        break;

      // ── Layanan EO ──
      case 'Paket Event':
        _openCreatorService('eo_paket');
        break;
      case 'Jadwal Event':
        if (sub == 'event_organizer' || sub == 'eo') {
          _openCreatorService('eo_jadwal');
        } else if (sub == 'wedding_organizer' || sub == 'wo') {
          _openCreatorService('wo_jadwal');
        } else {
          context.go(AppRoutes.agenda);
        }
        break;
      case 'Vendor Partner':
      case 'Vendor Terhubung':
        if (sub == 'wedding_organizer' || sub == 'wo') {
          _openCreatorService('wo_vendor');
        } else {
          _openCreatorService('eo_vendor');
        }
        break;
      case 'Timeline EO':
        _openCreatorService('eo_timeline');
        break;

      // ── Layanan WO ──
      case 'Paket Pernikahan':
      case 'Buat Paket Wedding':
        _openCreatorService('wo_paket');
        break;
      case 'Timeline WO':
        _openCreatorService('wo_timeline');
        break;
      case 'Jadwal Acara':
        _openCreatorService('wo_jadwal');
        break;

      // ── Layanan Fotografi ──
      case 'Galeri Portofolio':
      case 'Upload Foto':
        _openCreatorService('foto_galeri');
        break;
      case 'Booking & Jadwal':
      case 'Booking Sesi':
      case 'Booking Sesi Foto':
        if (sub == 'videographer' || sub == 'video' || sub == 'videografer') {
          _openCreatorService('video_booking');
        } else if (sub == 'mua' || sub == 'makeup' || sub == 'makeup_artist') {
          _openCreatorService('mua_booking');
        } else if (sub == 'drone' || sub == 'drone_pilot' || sub == 'pilot_drone') {
          _openCreatorService('drone_booking');
        } else if (sub == 'mc') {
          _openCreatorService('mc_booking');
        } else if (sub == 'talent' || sub == 'model') {
          _openCreatorService('talent_jadwal');
        } else {
          _openCreatorService('foto_booking');
        }
        break;
      case 'Paket Harga':
      case 'Paket Foto':
      case 'Paket Harga Aktif':
        if (sub == 'videographer' || sub == 'video' || sub == 'videografer') {
          _openCreatorService('video_paket');
        } else if (sub == 'mua' || sub == 'makeup' || sub == 'makeup_artist') {
          _openCreatorService('mua_paket');
        } else if (sub == 'drone' || sub == 'drone_pilot' || sub == 'pilot_drone') {
          _openCreatorService('drone_paket');
        } else {
          _openCreatorService('foto_paket');
        }
        break;
      case 'Cakupan Area':
        _openCreatorService('foto_area');
        break;

      // ── Layanan Video ──
      case 'Galeri Video':
      case 'Upload Showreel':
      case 'Showreel':
        _openCreatorService('video_galeri');
        break;
      case 'Jadwal Syuting':
        _openCreatorService('video_booking');
        break;
      case 'Paket Video':
        _openCreatorService('video_paket');
        break;
      case 'Equipment':
      case 'Equipment Siap':
        if (sub == 'drone' || sub == 'drone_pilot' || sub == 'pilot_drone') {
          _openCreatorService('drone_equipment');
        } else {
          _openCreatorService('video_equipment');
        }
        break;

      // ── Layanan Editor ──
      case 'Portofolio Edit':
        _openCreatorService('edit_portofolio');
        break;
      case 'Antrian Kerja':
      case 'Antrean Editing':
        _openCreatorService('edit_antrian');
        break;
      case 'Daftar Harga':
      case 'Paket Edit':
        _openCreatorService('edit_harga');
        break;
      case 'Spesialisasi':
        if (sub == 'desainer' || sub == 'designer') {
          _openCreatorService('desain_spesialisasi');
        } else if (sub == 'mua' || sub == 'makeup') {
          _openCreatorService('mua_spesialisasi');
        } else {
          _openCreatorService('edit_spesialisasi');
        }
        break;

      // ── Layanan Desainer ──
      case 'Portofolio Desain':
        _openCreatorService('desain_portofolio');
        break;
      case 'Proyek & Brief':
      case 'Proyek Desain':
      case 'Brief & Revisi Aktif':
        _openCreatorService('desain_proyek');
        break;
      case 'Paket Desain':
      case 'Paket Desain Aktif':
        _openCreatorService('desain_paket');
        break;

      // ── Layanan Animator ──
      case 'Showreel & Portofolio':
        if (sub == 'animator' || sub == '3d_animator' || sub == 'motion_designer') {
          _openCreatorService('animator_showreel');
        } else {
          _openCreatorService(sub == 'mc' ? 'mc_profil' : 'talent_profil');
        }
        break;
      case 'Upload Aset 3D':
        _openCreatorService('animator_showreel');
        break;
      case 'Antrian Render & Animasi':
      case 'Antrian Render':
        _openCreatorService('animator_antrian');
        break;
      case 'Paket Karakter & Model':
      case 'Paket Animasi':
        _openCreatorService('animator_paket');
        break;
      case 'Software & Spesialisasi':
      case 'Software & Render':
        _openCreatorService('animator_software');
        break;

      // ── Layanan MUA ──
      case 'Portofolio MUA':
      case 'Upload Look':
      case 'Galeri Look MUA':
        _openCreatorService('mua_portofolio');
        break;
      case 'Jadwal Booking':
      case 'Booking Rias':
        _openCreatorService('mua_booking');
        break;
      case 'Paket MUA':
      case 'Paket Rias Aktif':
        _openCreatorService('mua_paket');
        break;

      // ── Layanan Drone ──
      case 'Galeri Hasil Drone':
      case 'Upload Footage':
      case 'Footage 4K Siap':
        _openCreatorService('drone_galeri');
        break;
      case 'Booking Terbang':
      case 'Jadwal Terbang':
        _openCreatorService('drone_booking');
        break;
      case 'Paket Drone':
        _openCreatorService('drone_paket');
        break;
      case 'Peralatan Drone':
      case 'Unit Drone Siap':
        _openCreatorService('drone_equipment');
        break;

      // ── Layanan Talent & Performer ──
      case 'Profil Talent':
      case 'Profil MC':
      case 'Profil Talent / MC':
      case 'Upload Comp Card':
      case 'Comp Card & Portofolio':
      case 'Unggah Showreel':
      case 'Showreel & Comp Card':
        _openCreatorService(sub == 'mc' ? 'mc_profil' : 'talent_profil');
        break;
      case 'Jadwal Tampil':
      case 'Jadwal Panggung / Tampil':
      case 'Jadwal Panggung':
      case 'Jadwal & Booking':
        _openCreatorService(sub == 'mc' ? 'mc_booking' : 'talent_jadwal');
        break;
      case 'Kategori Pekerjaan':
      case 'Kategori Acara':
      case 'Casting & Peluang':
      case 'Casting & Kategori':
      case 'Casting & MC':
        _openCreatorService(sub == 'mc' ? 'mc_kategori' : 'talent_kategori');
        break;
      case 'Tarif & Rate Card':
      case 'Tarif':
      case 'Rate Card':
      case 'Rate Card Aktif':
      case 'Paket MC & Talent':
      case 'Tarif & Kontrak':
        _openCreatorService(sub == 'mc' ? 'mc_tarif' : 'talent_tarif');
        break;
      case 'Cari Casting & Job':
      case 'Cari Casting':
        context.go(AppRoutes.peluangProyek);
        break;
      case 'Kolaborasi Kreator':
        context.go(AppRoutes.kolaborasi);
        break;
      case 'Mitra Vendor & MUA':
      case 'Eksplor Vendor & MUA':
      case 'Cari Mitra MUA/Studio':
        context.go(AppRoutes.explore);
        break;
      case 'Rating & Ulasan':
        context.go(AppRoutes.reputasi);
        break;

      // ── Layanan Konten Kreator ──
      case 'Portofolio Konten':
      case 'Upload Konten':
        _openCreatorService('konten_portofolio');
        break;
      case 'Jadwal Posting & Deadline':
      case 'Jadwal Posting':
        _openCreatorService('konten_jadwal');
        break;
      case 'Paket Endorsement':
      case 'Paket Konten':
        _openCreatorService('konten_paket');
        break;
      case 'Media Kit & Rate Card':
      case 'Media Kit':
        _openCreatorService('konten_ratecard');
        break;

      // ── Layanan Komunitas ──
      case 'Anggota Komunitas':
      case 'Anggota':
        _openCreatorService('komunitas_anggota');
        break;
      case 'Kegiatan Komunitas':
      case 'Kegiatan':
        _openCreatorService('komunitas_kegiatan');
        break;
      case 'Pengumuman Komunitas':
      case 'Pengumuman':
        _openCreatorService('komunitas_pengumuman');
        break;
      case 'Kolaborasi Komunitas':
        _openCreatorService('komunitas_kolaborasi');
        break;

      // ── Layanan Sekolah ──
      case 'Workspace Sekolah':
      case 'Portofolio Siswa':
      case 'Kurasi Siswa & Magang':
      case 'Kolaborasi Sekolah':
      case 'Pengaturan Siswa':
      case 'Karya Siswa Terkurasi':
      case 'Mitra Magang Industri':
      case 'Review Karya':
      case 'Review Karya Siswa':
      case 'Direktori Talenta':
      case 'Karya & Portofolio Siswa':
        if (widget.user.isSchool || widget.user.isInstitution) {
          context.go(AppRoutes.karyaSiswa);
        } else {
          _openInstitutionWorkspace();
        }
        break;
      case 'Buka Magang':
      case 'Buka Program Magang':
      case 'Buka Lowongan Magang':
        if (sub == 'school' || sub == 'institution' || sub == 'institusi' || sub == 'sekolah' || sub == 'kampus') {
          AppSweetAlert.error(
            context,
            'Fitur Buka Program Magang khusus untuk akun Corporate / Mitra Industri. Institusi Pendidikan tidak dapat membuka lowongan magang.',
            title: 'Akses Ditolak (403)',
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BuatKebutuhanScreen(
                user: widget.user,
                initialKategori: 'magang',
              ),
            ),
          );
        }
        break;

      // ── Layanan Pemerintah ──
      case 'Tender & Pengadaan':
      case 'Pengadaan Kreatif':
      case 'Monitoring Proyek':
        context.go(AppRoutes.proyek);
        break;
      case 'Laporan Realisasi':
      case 'Laporan':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LaporanScreen(
              user: widget.user,
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
        );
        break;
      case 'Daftar Mitra Kreatif':
      case 'Cari Mitra Industri':
      case 'Kurasi Talenta':
      case 'Kurasi Talenta Daerah':
        if (widget.user.isSchool || widget.user.isInstitution) {
          context.go(AppRoutes.mitraIndustri);
        } else {
          context.go(AppRoutes.explore);
        }
        break;
      case 'Alokasi Anggaran':
      case 'Anggaran Dikelola':
      case 'Estimasi Anggaran':
      case 'Bayar DP':
      case 'Tarik Dana':
      case 'Tarik Saldo':
      case 'Dompet':
        context.go(AppRoutes.wallet);
        break;

      // ── Buat Kebutuhan ──
      case 'Buat Kebutuhan':
      case 'Buat Kebutuhan Baru':
      case 'Buat Event':
      case 'Buat Event Baru':
      case 'Buat Brief Kampanye':
      case 'Buka Proyek Korporat':
      case 'Buat Kampanye Wisata':
      case 'Buat Agenda Komunitas':
        if (widget.user.isGuest) {
          AuthGuardDialog.show(context, actionName: 'membuat kebutuhan proyek');
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BuatKebutuhanScreen(user: widget.user),
          ),
        );
        break;

      // ── Tab Peluang Proyek ──
      case 'Cari Peluang':
      case 'Cari Peluang Proyek':
      case 'Peluang Proyek':
      case 'Peluang Proyek Cocok':
      case 'Lihat Detail':
        context.go(AppRoutes.peluangProyek);
        break;

      // ── Tab Proyek Saya ──
      case 'Lihat Semua':
      case 'Lihat Semua Proyek':
      case 'Semua Proyek':
      case 'Proyek Saya':
      case 'Semua Kebutuhan & Proyek':
      case 'Proyek Berjalan':
      case 'Kontrak Berjalan':
      case 'Lihat Semua Proyek Berjalan':
      case 'Proposal Masuk':
      case 'Lihat Semua Proposal':
      case 'Bandingkan':
      case 'Setujui Proyek':
      case 'Total Event':
      case 'Event Berjalan':
      case 'Total Wedding':
      case 'Kampanye Aktif':
      case 'Program Magang':
      case 'Program & Magang':
      case 'Program dan Magang':
      case 'program & magang':
      case 'program magang':
        if (widget.user.isGuest) {
          AuthGuardDialog.show(context, actionName: 'mengakses manajemen proyek');
          return;
        }
        context.go(AppRoutes.proyek);
        break;

      // ── Tab Explore / Cari Vendor / Kreator ──
      case 'Cari Kreator':
      case 'Cari Kreator & Vendor':
      case 'Cari Campaign':
      case 'Cari Vendor':
      case 'Cari Vendor Mitra':
      case 'Cari Vendor Wedding':
      case 'Cari Talenta':
      case 'Cari Talenta Kreatif':
      case 'Cari Kreator Promosi':
      case 'Cari Kreator Konten':
      case 'Eksplor Kolaborasi':
      case 'Kirim Proposal':
      case 'Lihat Semua Rekomendasi':
      case 'Lihat Semua Top Kreator':
      case 'Komunitas':
      case 'Kelola Kampanye Brand':
      case 'Kurasi & Seleksi Vendor':
      case 'Cari Klien':
      case 'Cari Audisi':
        if (widget.user.isGuest) {
          AuthGuardDialog.show(context, actionName: 'mencari kreator');
          return;
        }
        context.go(AppRoutes.explore);
        break;

      // ── Tab Agenda ──
      case 'Lihat Semua Agenda':
      case 'Lihat Kalender':
      case 'Atur Jadwal':
      case 'Jadwal & Agenda':
      case 'Agenda':
      case 'Agenda Daerah':
        context.go(AppRoutes.agenda);
        break;

      // ── Tab Marketplace Karya ──
      case 'Lihat Semua Karya':
      case 'Buka Semua Aset':
      case 'Tambah Karya':
      case 'Portofolio':
      case 'Kelola Portofolio':
      case 'Marketplace':
        context.go(AppRoutes.marketplaceKarya);
        break;

      // ── Tab Grafik Performa ──
      case 'Grafik':
      case 'Grafik Performa':
      case 'Halaman Grafik':
      case 'Page Grafik':
      case 'Grafik Analitik':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GrafikScreen(user: widget.user),
          ),
        );
        break;

      // ── Tab Reputasi / Ulasan ──
      case 'Reputasi':
      case 'Ulasan':
      case 'Rating & Win Rate':
      case 'Rating & Reputasi':
        context.go(AppRoutes.reputasi);
        break;

      // ── Tab Kolaborasi ──
      case 'Kolaborasi':
        context.go(AppRoutes.kolaborasi);
        break;

      // ── Notifikasi & Pesan ──
      case 'Notifikasi':
        context.go(AppRoutes.notifikasi);
        break;
      case 'Pesan':
      case 'Direct Message':
        context.go(AppRoutes.pesan);
        break;

      // ── Profil ──
      case 'Lihat Profil':
      case 'Lengkapi Profil':
      case 'Profil':
      case 'Profil Saya':
        context.go(AppRoutes.profil);
        break;

      // ── Pengaturan ──
      case 'Pengaturan':
        context.go(AppRoutes.pengaturan);
        break;

      default:
        _showDummyActionMessage(feature);
    }
  }

  List<String> _getRoleHeroImages() {
    if (_isVendorOrMitra) {
      return const [
        'https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=1200&q=80',
      ];
    }
    if (_isTalentAndPerformer) {
      return const [
        'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=1200&q=80',
      ];
    }
    final sub = CreatorSidebarMenus.normalizeSubRole(widget.user.subRole);
    if (sub == 'event_organizer' || sub == 'eo') {
      return const [
        'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1511578314322-379afb476865?auto=format&fit=crop&w=1600&q=80',
      ];
    }
    if (sub == 'wedding_organizer' || sub == 'wo') {
      return const [
        'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1465495976277-4387d4b0b4c6?auto=format&fit=crop&w=1600&q=80',
      ];
    }
    if (sub == 'school' || sub == 'education' || sub == 'campus' || sub == 'sekolah' || sub == 'kampus') {
      return const [
        'https://images.unsplash.com/photo-1523240795612-9a054b0db644?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1541339907198-e08756dedf3f?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?auto=format&fit=crop&w=1600&q=80',
      ];
    }
    if (sub == 'government' || sub == 'pemerintah' || sub == 'instansi') {
      return const [
        'https://images.unsplash.com/photo-1541872703-74c5e44368f9?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1517048676732-d65bc937f952?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=1600&q=80',
      ];
    }
    if (sub == 'company' || sub == 'business' || sub == 'corporate' || sub == 'perusahaan') {
      return const [
        'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1522071820081-009f0129c71c?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1497215728101-856f4ea42174?auto=format&fit=crop&w=1600&q=80',
      ];
    }
    if (sub == 'umkm') {
      return const [
        'https://images.unsplash.com/photo-1472851294608-062f824d29cc?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1441986300917-64674bd600d8?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1556742049-0a67c5574f73?auto=format&fit=crop&w=1600&q=80',
      ];
    }
    if (sub == 'fotografer' || sub == 'fotografi') {
      return const [
        'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1452587925148-ce544e77e70d?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1502982720700-bfff97f2ecac?auto=format&fit=crop&w=1600&q=80',
      ];
    }
    if (sub == 'videografer' || sub == 'videografi') {
      return const [
        'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1485846234645-a62644f84728?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1478760329108-5c3ed9d495a0?auto=format&fit=crop&w=1600&q=80',
      ];
    }
    if (sub == 'editor' || sub == 'video_editor') {
      return const [
        'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1531403009284-440f080d1e12?auto=format&fit=crop&w=1600&q=80',
      ];
    }
    if (sub == 'desainer' || sub == 'graphic_designer' || sub == 'designer') {
      return const [
        'https://images.unsplash.com/photo-1581291518857-4e27b48ff24e?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1507238691740-187a5b1d37b8?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1542744094-3a31f272c490?auto=format&fit=crop&w=1600&q=80',
      ];
    }
    if (sub == 'animator' || sub == 'animasi') {
      return const [
        'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1634017839464-5c339ebe3cb4?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=1600&q=80',
      ];
    }
    if (sub == 'musisi' || sub == 'musik' || sub == 'penyanyi') {
      return const [
        'https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1514320291840-2e0a9bf2a9ae?auto=format&fit=crop&w=1600&q=80',
      ];
    }
    if (sub == 'mc' || sub == 'presenter') {
      return const [
        'https://images.unsplash.com/photo-1475721027785-f74eccf877e2?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1505373877841-8d25f7d46678?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1515187029135-18ee286d815b?auto=format&fit=crop&w=1600&q=80',
      ];
    }
    if (sub == 'mua' || sub == 'makeup_artist') {
      return const [
        'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1512496015851-a90fb38ba796?auto=format&fit=crop&w=1600&q=80',
      ];
    }
    if (sub == 'drone' || sub == 'drone_pilot') {
      return const [
        'https://images.unsplash.com/photo-1508614589041-895b88991e3e?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1473968512647-3e447244af8f?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1527977966376-1c8408f9f108?auto=format&fit=crop&w=1600&q=80',
      ];
    }
    if (sub == 'konten' || sub == 'content_creator') {
      return const [
        'https://images.unsplash.com/photo-1611162617213-7d7a39e9b1d7?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1590602847861-f357a9332bbc?auto=format&fit=crop&w=1600&q=80',
      ];
    }
    if (sub == 'komunitas' || sub == 'community') {
      return const [
        'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?auto=format&fit=crop&w=1600&q=80',
        'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?auto=format&fit=crop&w=1600&q=80',
      ];
    }
    return const [
      'https://images.unsplash.com/photo-1522071820081-009f0129c71c?auto=format&fit=crop&w=1600&q=80',
      'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?auto=format&fit=crop&w=1600&q=80',
      'https://images.unsplash.com/photo-1542744173-8e7e53415bb0?auto=format&fit=crop&w=1600&q=80',
    ];
  }

  // ── Hero Banner ──────────────────────────────────────────────────────────────
  Widget _buildHeroBanner(bool isDark) {
    final config = _getRoleConfig();
    final heroBgImages = _getRoleHeroImages();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.20),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppTheme.primaryPurple.withValues(alpha: isDark ? 0.20 : 0.12),
            blurRadius: 36,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _HeroBannerBackgroundCarousel(
        images: heroBgImages,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Role badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppTheme.pinkPurpleGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPurple.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        config.badge,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            config.greeting,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black87,
                                  offset: Offset(0, 2),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        AnimatedBuilder(
                          animation: _handWaveAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _handWaveAnimation.value,
                              alignment: Alignment.bottomCenter,
                              child: child,
                            );
                          },
                          child: const Text('👋', style: TextStyle(fontSize: 24)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      config.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFE2E8F0),
                        height: 1.5,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            offset: Offset(0, 1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _HeroButton(
                          label: config.primaryButtonLabel,
                          icon: config.primaryButtonIcon,
                          onTap: () => _navigateTo(config.primaryButtonLabel),
                          gradient: AppTheme.primaryGradient,
                        ),
                        _HeroButton(
                          label: config.secondaryButtonLabel,
                          icon: config.secondaryButtonIcon,
                          onTap: () => _navigateTo(config.secondaryButtonLabel),
                          outlined: true,
                          isDark: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Decorative illustration with frosted glass effect
              SizedBox(
                width: 100,
                height: 120,
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        width: 80,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          _getHeroIllustrationIcon(),
                          color: Colors.white.withValues(alpha: 0.85),
                          size: 28,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 56,
                        height: 70,
                        decoration: BoxDecoration(
                          color: AppTheme.accentPink.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.30),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentPink.withValues(alpha: 0.25),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.person_outline,
                          color: Colors.white.withValues(alpha: 0.90),
                          size: 32,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: AppTheme.primaryPurple,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // ── Animated Metric Cards ────────────────────────────────────────────────────
  Widget _buildMetricCards(bool isDark) {
    final config = _getRoleConfig();
    final metrics = config.metrics;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        if (isMobile) {
          // 2x2 grid on mobile
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildAnimatedMetricCard(metrics[0], 0, isDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildAnimatedMetricCard(metrics[1], 1, isDark),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildAnimatedMetricCard(metrics[2], 2, isDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildAnimatedMetricCard(metrics[3], 3, isDark),
                  ),
                ],
              ),
            ],
          );
        }
        // Desktop: single row
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(metrics.length, (i) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: i == 0 ? 0 : 6,
                  right: i == metrics.length - 1 ? 0 : 6,
                ),
                child: _buildAnimatedMetricCard(metrics[i], i, isDark),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildAnimatedMetricCard(Map<String, dynamic> m, int i, bool isDark) {
    return FadeTransition(
      opacity: _statsAnims[i],
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(_statsAnims[i]),
        child: _MetricCard(
          label: m['label'] as String,
          value: m['value'] as String,
          icon: (m['icon'] as IconData?) ?? Icons.image_outlined,
          color: m['color'] as Color,
          trend: m['trend'] as String,
          isDark: isDark,
          onTap: () => _showMetricDetailDialog(m, isDark),
        ),
      ),
    );
  }

  void _showMetricDetailDialog(Map<String, dynamic> metric, bool isDark) {
    final title = metric['label'] as String? ?? 'Detail Metrik';
    final value = metric['value'] as String? ?? '-';
    final trend = metric['trend'] as String? ?? '';
    final color = (metric['color'] as Color?) ?? AppTheme.primaryPurple;
    final icon = (metric['icon'] as IconData?) ?? Icons.insights_rounded;
    final breakdown = metric['breakdown'] as String? ??
        'Data metrik dihitung secara real-time berdasarkan aktivitas terbaru akun Anda.';
    final actionLabel = metric['action'] as String?;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nilai Saat Ini',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: color,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        trend,
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Keterangan & Rincian:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                breakdown,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.teal.shade300.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.insights_rounded, size: 16, color: Colors.teal),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Anda dapat memantau pergerakan grafik historis lengkap di Halaman Grafik Performa.',
                        style: TextStyle(
                            fontSize: 11, color: Colors.teal, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _roleAccentColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (actionLabel != null) {
                _navigateTo(actionLabel);
              } else {
                _navigateTo('Grafik Performa');
              }
            },
            icon: const Icon(Icons.arrow_forward_rounded,
                size: 16, color: Colors.white),
            label: Text(
              actionLabel ?? 'Buka Grafik',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── Default curated data for high quality recommendation fallback ───────────
  static const List<Map<String, dynamic>> _defaultOpportunities = [
    {
      'id': 'demo_opp_1',
      'title': 'Dokumentasi & Live Broadcast Festival Musik Kreavana',
      'badge': 'Event Organizer',
      'badge_color': Color(0xFF6366F1),
      'location': 'Jakarta Selatan',
      'price': 'Rp 25.000.000',
      'action_label': 'Lihat Detail',
      'cover_url': 'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?auto=format&fit=crop&w=800&q=80',
    },
    {
      'id': 'demo_opp_2',
      'title': 'Fotografer & Videografer Kampanye Produk Fashion Lokal',
      'badge': 'Fotografi & Video',
      'badge_color': Color(0xFFEC4899),
      'location': 'Bandung',
      'price': 'Rp 8.500.000',
      'action_label': 'Lihat Detail',
      'cover_url': 'https://images.unsplash.com/photo-1542038784456-1ea8e935640e?auto=format&fit=crop&w=800&q=80',
    },
    {
      'id': 'demo_opp_3',
      'title': 'Video Editor & Colorist Web Series Brand FMCG',
      'badge': 'Video Editor',
      'badge_color': Color(0xFF10B981),
      'location': 'Yogyakarta',
      'price': 'Rp 12.000.000',
      'action_label': 'Lihat Detail',
      'cover_url': 'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?auto=format&fit=crop&w=800&q=80',
    },
    {
      'id': 'demo_opp_4',
      'title': 'MC & Host Resepsi Pernikahan Adat Modern',
      'badge': 'Talent & MC',
      'badge_color': Color(0xFFF59E0B),
      'location': 'Surabaya',
      'price': 'Rp 5.000.000',
      'action_label': 'Lihat Detail',
      'cover_url': 'https://images.unsplash.com/photo-1475721027785-f74eccf877e2?auto=format&fit=crop&w=800&q=80',
    },
  ];

  static const List<Map<String, dynamic>> _defaultVendors = [
    {
      'id': 'demo_ven_1',
      'name': 'Studio Lensa Kreatif',
      'category': 'Fotografer & Video',
      'location': 'Jakarta Selatan',
      'starting_price': 'Mulai Rp 3.500.000',
      'cover_url': 'https://images.unsplash.com/photo-1542038784456-1ea8e935640e?auto=format&fit=crop&w=800&q=80',
      'avatar_url': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=400&q=80',
    },
    {
      'id': 'demo_ven_2',
      'name': 'Grand Mahligai Organizer',
      'category': 'Wedding Organizer',
      'location': 'Bandung',
      'starting_price': 'Mulai Rp 15.000.000',
      'cover_url': 'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=800&q=80',
      'avatar_url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
    },
    {
      'id': 'demo_ven_3',
      'name': 'SkyMotion Aerial Drone',
      'category': 'Pilot Drone 4K',
      'location': 'Surabaya',
      'starting_price': 'Mulai Rp 4.000.000',
      'cover_url': 'https://images.unsplash.com/photo-1508614589041-895b88991e3e?auto=format&fit=crop&w=800&q=80',
      'avatar_url': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
    },
    {
      'id': 'demo_ven_4',
      'name': 'PixelWave Motion Studio',
      'category': 'Desain & Animasi',
      'location': 'Yogyakarta',
      'starting_price': 'Mulai Rp 6.000.000',
      'cover_url': 'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?auto=format&fit=crop&w=800&q=80',
      'avatar_url': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
    },
  ];

  // ── Recommendation Section ───────────────────────────────────────────────────
  Widget _buildRecommendationSection(bool isDark) {
    final config = _getRoleConfig();
    final isLookingForOpps = config.recommendationRole == 'creator';

    final List<Map<String, dynamic>> recommendations;
    if (isLookingForOpps) {
      if (_recommendedOpportunities.isNotEmpty) {
        recommendations = _recommendedOpportunities;
      } else if (_vendorRecommendations.isNotEmpty) {
        recommendations = _vendorRecommendations;
      } else {
        recommendations = _defaultOpportunities;
      }
    } else {
      if (_vendorRecommendations.isNotEmpty) {
        recommendations = _vendorRecommendations;
      } else {
        recommendations = _defaultVendors;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: config.recommendationTitle,
          onViewAll: () => _navigateTo('Lihat Semua Rekomendasi'),
        ),
        const SizedBox(height: 12),
        AiRecommendationCard(
          user: widget.user,
          role: config.recommendationRole,
          niche: config.recommendationNiche,
        ),
        if (recommendations.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 270,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.hardEdge,
              itemCount: recommendations.length,
              itemBuilder: (context, index) => isLookingForOpps
                  ? _buildOpportunityCard(recommendations[index], isDark)
                  : _buildCreatorCard(recommendations[index], isDark),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOpportunityCard(Map<String, dynamic> item, bool isDark) {
    final gradientColors =
        item['gradient_colors'] as List<Color>? ??
        [AppTheme.primaryPurple, AppTheme.deepPurple];
    final badgeColor = item['badge_color'] as Color? ?? AppTheme.primaryPurple;

    final rawTitle = item['title']?.toString() ??
        item['name']?.toString() ??
        item['business_name']?.toString() ??
        '';
    final title = rawTitle.trim().isNotEmpty
        ? rawTitle.trim()
        : 'Peluang Proyek & Kolaborasi Kreatif';

    final rawBadge = item['badge']?.toString() ??
        item['category']?.toString() ??
        item['sub_role']?.toString() ??
        '';
    final badgeText = rawBadge.trim().isNotEmpty
        ? rawBadge.trim()
        : 'Peluang';

    final rawLocation = item['location']?.toString() ?? '';
    final location = rawLocation.trim().isNotEmpty ? rawLocation.trim() : 'Indonesia';

    final rawPrice = item['price']?.toString() ??
        item['budget_range']?.toString() ??
        item['starting_price']?.toString() ??
        '';
    final price = rawPrice.trim().isNotEmpty ? rawPrice.trim() : 'Budget Kompetitif';

    final rawCoverUrl = item['cover_url']?.toString() ??
        item['image_url']?.toString() ??
        item['thumbnail_url']?.toString() ??
        item['portfolio_sample_url']?.toString();
    final displayCoverUrl = (rawCoverUrl != null && rawCoverUrl.isNotEmpty)
        ? rawCoverUrl
        : _getCategoryCoverFallback('$badgeText $title');

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
        ),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Real HD Cover Image with gradient overlay and badge
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusMD),
            ),
            child: SizedBox(
              height: 105,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: ApiService.resolveAssetUrl(displayCoverUrl),
                    fit: BoxFit.cover,
                    memCacheWidth: 440,
                    memCacheHeight: 220,
                    fadeInDuration: const Duration(milliseconds: 150),
                    placeholder: (context, url) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          (item['icon'] as IconData?) ?? Icons.photo_library_outlined,
                          color: Colors.white70,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.25),
                          Colors.black.withValues(alpha: 0.65),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.bookmark_border,
                        color: AppTheme.primaryPurple,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 11,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppTheme.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryPurple,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: ElevatedButton(
                      onPressed: () {
                        final opp = OpportunityModel(
                          id: item['id']?.toString() ?? '1',
                          title: title,
                          description:
                              'Peluang proyek $title dengan alokasi budget $price yang direkomendasikan langsung oleh Kreavana AI.',
                          subRoleSlug: badgeText.toLowerCase(),
                          type: 'project',
                          location: location,
                          budgetRange: price,
                          status: 'open',
                          postedBy: 'admin',
                          poster: OpportunityPoster(
                            id: 'admin',
                            name: 'Kreavana Verified Client',
                            username: 'client_official',
                          ),
                        );
                        OpportunityDetailSheet.show(
                          context,
                          opportunity: opp,
                          currentUserId: widget.user.id,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: badgeColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        item['action_label']?.toString() ?? 'Lihat Detail',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
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

  String _getCategoryCoverFallback(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('wedding')) {
      return 'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=800&q=80';
    } else if (lower.contains('edit')) {
      return 'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?auto=format&fit=crop&w=800&q=80';
    } else if (lower.contains('photo') || lower.contains('foto')) {
      return 'https://images.unsplash.com/photo-1542038784456-1ea8e935640e?auto=format&fit=crop&w=800&q=80';
    } else if (lower.contains('video') || lower.contains('cinema')) {
      return 'https://images.unsplash.com/photo-1518133910546-b6c2fb7d79e3?auto=format&fit=crop&w=800&q=80';
    } else if (lower.contains('event') || lower.contains('eo')) {
      return 'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?auto=format&fit=crop&w=800&q=80';
    } else if (lower.contains('music') || lower.contains('singer') || lower.contains('musik')) {
      return 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=800&q=80';
    } else if (lower.contains('mc')) {
      return 'https://images.unsplash.com/photo-1475721027785-f74eccf877e2?auto=format&fit=crop&w=800&q=80';
    } else if (lower.contains('makeup') || lower.contains('mua') || lower.contains('beauty')) {
      return 'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?auto=format&fit=crop&w=800&q=80';
    }
    return 'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?auto=format&fit=crop&w=800&q=80';
  }

  String _getCategoryAvatarFallback(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('wedding')) {
      return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80';
    } else if (lower.contains('edit')) {
      return 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80';
    } else if (lower.contains('photo') || lower.contains('foto')) {
      return 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=400&q=80';
    } else if (lower.contains('video') || lower.contains('cinema')) {
      return 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80';
    } else if (lower.contains('event') || lower.contains('eo')) {
      return 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=400&q=80';
    }
    return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=400&q=80';
  }

  Widget _buildCreatorCard(Map<String, dynamic> vendor, bool isDark) {
    final gradientColors =
        vendor['gradient_colors'] as List<Color>? ??
        [AppTheme.primaryPurple, AppTheme.deepPurple];
    final categoryRaw = vendor['category']?.toString() ?? 'Creator';
    final category = categoryRaw.toLowerCase() == 'eo_event_package'
        ? 'Event'
        : categoryRaw
            .split('_')
            .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
            .join(' ');
    final vendorId = vendor['id']?.toString() ?? '';
    final vendorName = vendor['name']?.toString() ?? '';
    final rawAvatarUrl = vendor['avatar_url']?.toString();
    final rawCoverUrl = vendor['cover_url']?.toString() ??
        vendor['thumbnail_url']?.toString() ??
        ((vendor['portfolio_images'] is List && (vendor['portfolio_images'] as List).isNotEmpty)
            ? (vendor['portfolio_images'] as List).first.toString()
            : null);

    final displayCoverUrl = (rawCoverUrl != null && rawCoverUrl.isNotEmpty)
        ? rawCoverUrl
        : _getCategoryCoverFallback(category);

    final displayAvatarUrl = (rawAvatarUrl != null && rawAvatarUrl.isNotEmpty)
        ? rawAvatarUrl
        : _getCategoryAvatarFallback(category);

    void openProfile() async {
      if (vendorId.isEmpty) return;
      final isAllowed = await AuthGuardDialog.check(
        context,
        actionName: 'melihat profil kreator $vendorName',
      );
      if (isAllowed && mounted) {
        UserProfileModal.show(
          context,
          userId: vendorId,
          initialName: vendorName,
          initialAvatarUrl: displayAvatarUrl,
          initialRole: 'creator',
          currentUser: widget.user,
        );
      }
    }

    return InkWell(
      onTap: openProfile,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
          ),
          boxShadow: isDark ? null : AppTheme.cardShadowLight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusMD),
              ),
              child: SizedBox(
                height: 90,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: ApiService.resolveAssetUrl(displayCoverUrl),
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      memCacheHeight: 200,
                      fadeInDuration: const Duration(milliseconds: 150),
                      placeholder: (context, url) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.28),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor['name']?.toString() ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 10,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            vendor['location']?.toString() ?? '',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 11, color: Colors.amber.shade600),
                        const SizedBox(width: 2),
                        Text(
                          '${vendor['rating'] ?? '4.8'} (${vendor['review_count'] ?? '0'})',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      vendor['starting_price']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: OutlinedButton(
                        onPressed: openProfile,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: BorderSide(
                            color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          foregroundColor: AppTheme.primaryPurple,
                        ),
                        child: const Text(
                          'Lihat Profil',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Curated Role-Specific Live & Fallback Data ──────────────────────────────
  List<Map<String, dynamic>> _getEffectiveProjectNeeds() {
    if (widget.user.isGuest) return const [];
    if (_projectNeeds.isNotEmpty) return _projectNeeds;
    if (_isVendorOrMitra) {
      return [
        {
          'id': 'vnd_need_1',
          'title': 'Sewa Studio Foto & Rig Lighting 2 Hari',
          'description': 'Shooting TVC Komersial Fashion Brand — butuh cyclorama putih & 4 head flash',
          'status': 'Permintaan Baru',
          'status_color': '#D97706',
          'budget': 'Rp 8.000.000',
          'deadline': '26 Okt 2026',
          'image_url': 'https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?auto=format&fit=crop&w=200&q=80',
        },
        {
          'id': 'vnd_need_2',
          'title': 'Paket Sound System & Lighting Panggung Festival',
          'description': 'Event Komunitas Seni Musik 10.000 watt line array & moving head',
          'status': 'Terkonfirmasi',
          'status_color': '#10B981',
          'budget': 'Rp 16.500.000',
          'deadline': '03 Nov 2026',
          'image_url': 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=200&q=80',
        },
        {
          'id': 'vnd_need_3',
          'title': 'Sewa 2 Unit HiAce & Logistik Crew Produksi Film',
          'description': 'Transportasi kru film & peralatan syuting lokasi outdoor 3 hari',
          'status': 'Dalam Proses',
          'status_color': '#2563EB',
          'budget': 'Rp 6.000.000',
          'deadline': '08 Nov 2026',
          'image_url': 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=200&q=80',
        },
      ];
    }
    if (_isTalentAndPerformer) {
      return [
        {
          'id': 'talent_need_1',
          'title': 'Casting Talent Iklan Komersial Brand FMCG',
          'description': 'Pemeran utama video digital 60 detik (karakter energik, ekspresif & fotogenik)',
          'status': 'Aktif',
          'status_color': '#EA580C',
          'budget': 'Rp 7.500.000',
          'deadline': '25 Okt 2026',
          'image_url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
        },
        {
          'id': 'talent_need_2',
          'title': 'MC Formal & Gala Dinner Perusahaan BUMN',
          'description': 'Pemandu acara bilingual (ID/EN) untuk malam apresiasi tahunan',
          'status': 'Panggilan',
          'status_color': '#8B5CF6',
          'budget': 'Rp 6.000.000',
          'deadline': '02 Nov 2026',
          'image_url': 'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?auto=format&fit=crop&w=200&q=80',
        },
        {
          'id': 'talent_need_3',
          'title': 'Penyanyi & Band Pengisi Acara Festival Seni Komunitas',
          'description': 'Penampilan live akustik 2 set lagu pop & indie di panggung kreatif',
          'status': 'Konfirmasi',
          'status_color': '#10B981',
          'budget': 'Rp 5.000.000',
          'deadline': '10 Nov 2026',
          'image_url': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=200&q=80',
        },
      ];
    }
    final sub = CreatorSidebarMenus.normalizeSubRole(widget.user.subRole);
    if (sub == 'event_organizer' || sub == 'eo') {
      return [
        {
          'id': 'eo_need_1',
          'title': 'Dokumentasi Video & Foto Gala Dinner Expo',
          'description': 'Kebutuhan 2 Fotografer + 1 Videografer Sony A7IV untuk event B2B',
          'status': 'Aktif',
          'status_color': '#6366F1',
          'budget': 'Rp 8.500.000',
          'deadline': '28 Okt 2026',
          'image_url': 'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?auto=format&fit=crop&w=200&q=80',
        },
        {
          'id': 'eo_need_2',
          'title': 'Sound System 10.000W & Lighting Stage Outdoor',
          'description': 'Panggung festival musik kampus outdoor 2 hari penuh',
          'status': 'Review',
          'status_color': '#F59E0B',
          'budget': 'Rp 14.000.000',
          'deadline': '05 Nov 2026',
          'image_url': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=200&q=80',
        },
        {
          'id': 'eo_need_3',
          'title': 'Master of Ceremony (MC) Bilingual & Akustik',
          'description': 'Acara resepsi korporasi & award ceremony malam apresiasi',
          'status': 'Baru',
          'status_color': '#10B981',
          'budget': 'Rp 6.000.000',
          'deadline': '10 Nov 2026',
          'image_url': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
        },
      ];
    }
    if (sub == 'wedding_organizer' || sub == 'wo') {
      return [
        {
          'id': 'wo_need_1',
          'title': 'Paket Wedding Cinematic & Drone 4K',
          'description': 'Liputan akad & resepsi adat Sunda Modern di Ballroom',
          'status': 'Aktif',
          'status_color': '#EC4899',
          'budget': 'Rp 12.000.000',
          'deadline': '01 Nov 2026',
          'image_url': 'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=200&q=80',
        },
        {
          'id': 'wo_need_2',
          'title': 'MUA Pengantin & 4 Ibu Pendamping',
          'description': 'Makeup flawless modern dengan busana adat terkoordinasi',
          'status': 'Review',
          'status_color': '#8B5CF6',
          'budget': 'Rp 9.500.000',
          'deadline': '08 Nov 2026',
          'image_url': 'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?auto=format&fit=crop&w=200&q=80',
        },
      ];
    }
    if (sub == 'school' || sub == 'education' || sub == 'campus' || sub == 'sekolah' || sub == 'kampus') {
      return [
        {
          'id': 'sch_need_1',
          'title': 'Perekrutan Magang Siswa: 3D Modeler & Animator',
          'description': 'Program magang industri 6 bulan bersama mitra studio kreatif',
          'status': 'Aktif',
          'status_color': '#06B6D4',
          'budget': 'Uang Saku & Sertifikat',
          'deadline': '15 Nov 2026',
          'image_url': 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=200&q=80',
        },
        {
          'id': 'sch_need_2',
          'title': 'Proyek Produksi Video Profil Sekolah Kejuruan',
          'description': 'Kolaborasi karya siswa multimedia dengan supervisi industri',
          'status': 'Berjalan',
          'status_color': '#10B981',
          'budget': 'Dana BOS & Industri',
          'deadline': '20 Nov 2026',
          'image_url': 'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?auto=format&fit=crop&w=200&q=80',
        },
      ];
    }
    return [
      {
        'id': 'gen_need_1',
        'title': _isCreator ? 'Shooting Video Promosi Brand Fashion' : 'Pengadaan Konten Video UGC & Reels',
        'description': _isCreator ? 'Brief konten 3 video Reels durasi 60 detik' : 'Membutuhkan 3 video creator lifestyle',
        'status': 'Aktif',
        'status_color': '#7C3AED',
        'budget': 'Rp 4.500.000',
        'deadline': '30 Okt 2026',
        'image_url': 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=200&q=80',
      },
      {
        'id': 'gen_need_2',
        'title': _isCreator ? 'Desain Identitas Visual Brand Kafe & Resto' : 'Desain Kemasan Produk & Feed Instagram',
        'description': 'Paket logo, color palette, dan 9 template posting feed',
        'status': 'Review',
        'status_color': '#3B82F6',
        'budget': 'Rp 3.000.000',
        'deadline': '04 Nov 2026',
        'image_url': 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=200&q=80',
      },
      {
        'id': 'gen_need_3',
        'title': _isCreator ? 'Editing Episode Podcast Multi-Cam' : 'Voice Over & Dubbing Iklan Layanan Masyarakat',
        'description': 'Audio mastering, subtitle, dan cutting teaser 1 menit',
        'status': 'Baru',
        'status_color': '#10B981',
        'budget': 'Rp 2.500.000',
        'deadline': '12 Nov 2026',
        'image_url': 'https://images.unsplash.com/photo-1590602847861-f357a9332bbc?auto=format&fit=crop&w=200&q=80',
      },
    ];
  }

  List<Map<String, dynamic>> _getEffectiveIncomingProposals() {
    if (widget.user.isGuest) return const [];
    if (_incomingProposals.isNotEmpty) return _incomingProposals;
    final sub = CreatorSidebarMenus.normalizeSubRole(widget.user.subRole);
    if (sub == 'event_organizer' || sub == 'eo' || sub == 'wedding_organizer' || sub == 'wo') {
      return [
        {
          'id': 'prop_demo_1',
          'opportunity_id': 'eo_need_1',
          'opportunity_title': 'Dokumentasi Video & Foto Gala Dinner Expo',
          'creator_id': 'creator_demo_1',
          'creator_name': 'Studio Lensa Kreatif',
          'bid_price': 'Rp 8.000.000',
          'status': 'submitted',
          'creator_avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
          'created_at': '15 menit lalu',
          'pitch_message': 'Halo! Tim Studio Lensa Kreatif berpengalaman 6+ tahun meliput Gala Dinner & Expo korporat. Dilengkapi 2 kamera Sony FX3 full-frame dan gimbal stabilizer.',
        },
        {
          'id': 'prop_demo_2',
          'opportunity_id': 'eo_need_2',
          'opportunity_title': 'Highlight Reels & Live Social Media',
          'creator_id': 'creator_demo_2',
          'creator_name': 'Andi Editor Pro',
          'bid_price': 'Rp 3.500.000',
          'status': 'approved',
          'creator_avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
          'created_at': '1 jam lalu',
          'pitch_message': 'Siap memproduksi 5 Reels vertikal dengan tempo cepat, dynamic captions, dan color grading cinematic langsung di hari yang sama.',
        },
        {
          'id': 'prop_demo_3',
          'opportunity_id': 'eo_need_1',
          'opportunity_title': 'Fotografer VIP & Stage Area',
          'creator_id': 'creator_demo_3',
          'creator_name': 'Rina Photography',
          'bid_price': 'Rp 4.000.000',
          'status': 'submitted',
          'creator_avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=200&q=80',
          'created_at': '3 jam lalu',
          'pitch_message': 'Fokus portrait VIP, red carpet session, dan stage ceremony dengan lighting godox flash wireless tanpa mengganggu jalannya acara.',
        },
      ];
    }
    return [
      {
        'id': 'prop_gen_1',
        'opportunity_id': 'gen_need_1',
        'opportunity_title': 'Liputan Dokumentasi & Livestreaming Event',
        'creator_id': 'creator_demo_4',
        'creator_name': _isCreator ? 'Lamaran Anda ke: PT Kreasi Nusantara' : 'Maya Wedding Organizer',
        'bid_price': 'Rp 7.500.000',
        'status': 'submitted',
        'creator_avatar': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=200&q=80',
        'created_at': '20 menit lalu',
        'pitch_message': 'Kami siap menyediakan tim multi-cam livestreaming 1080p 60fps dengan backup koneksi bonding router.',
      },
      {
        'id': 'prop_gen_2',
        'opportunity_id': 'gen_need_2',
        'opportunity_title': 'Video Promosi Produk & Reels Content',
        'creator_id': 'creator_demo_5',
        'creator_name': _isCreator ? 'Lamaran Anda ke: Brand FMCG Jakarta' : 'Dwi Videography Motion',
        'bid_price': 'Rp 4.200.000',
        'status': 'approved',
        'creator_avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=200&q=80',
        'created_at': '2 jam lalu',
        'pitch_message': 'Portfolio video produk viral kami telah mencapai 2M+ views di TikTok. Siap eksekusi sesuai storyboard.',
      },
    ];
  }

  List<Map<String, dynamic>> _getEffectiveRunningContracts() {
    if (widget.user.isGuest) return const [];
    if (_runningContracts.isNotEmpty) return _runningContracts;
    final sub = CreatorSidebarMenus.normalizeSubRole(widget.user.subRole);
    if (sub == 'event_organizer' || sub == 'eo' || sub == 'wedding_organizer' || sub == 'wo') {
      return [
        {
          'id': 'cnt_demo_1',
          'title': 'Gathering Korporasi BUMN 2026',
          'creator_id': 'creator_demo_1',
          'creator_name': 'Studio Lensa Kreatif',
          'agreed_price': 'Rp 14.500.000',
          'deadline': '25 Okt 2026',
          'work_status': 'in_progress',
          'description': 'Dokumentasi lengkap foto video dan aftermovie gathering korporasi BUMN.',
          'image_url': 'https://images.unsplash.com/photo-1511578314322-379afb476865?auto=format&fit=crop&w=200&q=80',
        },
        {
          'id': 'cnt_demo_2',
          'title': 'Teaser & Dokumentasi Expo Tech',
          'creator_id': 'creator_demo_2',
          'creator_name': 'Andi Editor Pro',
          'agreed_price': 'Rp 6.000.000',
          'deadline': '28 Okt 2026',
          'work_status': 'review',
          'description': 'Teaser video dan konten reels liputan pameran teknologi.',
          'image_url': 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&w=200&q=80',
        },
        {
          'id': 'cnt_demo_3',
          'title': 'Live Sound & Stage Festival Musik',
          'creator_id': 'creator_demo_3',
          'creator_name': 'SkySound Audio Engineering',
          'agreed_price': 'Rp 12.000.000',
          'deadline': '05 Nov 2026',
          'work_status': 'in_progress',
          'description': 'Penyediaan tata suara panggung konser dan sound engineering profesional.',
          'image_url': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=200&q=80',
        },
      ];
    }
    return [
      {
        'id': 'cnt_gen_1',
        'title': 'Kampanye Digital Marketing Q4',
        'creator_id': 'creator_demo_4',
        'creator_name': _isCreator ? 'PT Solusi Brand Indonesia' : 'Rina Photography Studio',
        'agreed_price': 'Rp 8.500.000',
        'deadline': '27 Okt 2026',
        'work_status': 'in_progress',
        'description': 'Produksi aset visual dan foto promosi kampanye akhir tahun.',
        'image_url': 'https://images.unsplash.com/photo-1460925895917-afdab827c52f?auto=format&fit=crop&w=200&q=80',
      },
      {
        'id': 'cnt_gen_2',
        'title': 'Desain Identitas & Kemasan Produk',
        'creator_id': 'creator_demo_5',
        'creator_name': _isCreator ? 'Kopi Senja Nusantara' : 'PixelWave Graphic House',
        'agreed_price': 'Rp 4.000.000',
        'deadline': '02 Nov 2026',
        'work_status': 'review',
        'description': 'Redesain packaging dan branding visual identitas kemasan.',
        'image_url': 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=200&q=80',
      },
    ];
  }

  List<Map<String, dynamic>> _getEffectiveAgenda() {
    if (widget.user.isGuest) return const [];
    if (_agenda.isNotEmpty) return _agenda;
    if (_isVendorOrMitra) {
      return [
        {
          'id': 'vnd_ag_1',
          'title': 'Handover Unit Sony FX3 Cinema Kit + GM Lens',
          'date': '24',
          'month': 'Okt',
          'time': '09:00 - 10:30 WIB',
          'type': 'Handover',
          'type_color': '#D97706',
        },
        {
          'id': 'vnd_ag_2',
          'title': 'Setup Sound & Stage Lighting Festival Seni Kreavana',
          'date': '28',
          'month': 'Okt',
          'time': '13:00 - 18:00 WIB',
          'type': 'Setup Teknis',
          'type_color': '#EA580C',
        },
        {
          'id': 'vnd_ag_3',
          'title': 'Pengembalian & QC Unit Studio Ruang Cyclorama',
          'date': '31',
          'month': 'Okt',
          'time': '17:00 - 19:00 WIB',
          'type': 'Return QC',
          'type_color': '#10B981',
        },
      ];
    }
    if (_isTalentAndPerformer) {
      return [
        {
          'id': 'talent_ag_1',
          'title': 'Gladi Resik & Soundcheck Gala Dinner BUMN',
          'date': '24',
          'month': 'Okt',
          'time': '16:00 - 18:30 WIB',
          'type': 'Gladi Resik',
          'type_color': '#EA580C',
        },
        {
          'id': 'talent_ag_2',
          'title': 'Shooting TVC & Photoshoot Kampanye Brand Fashion',
          'date': '27',
          'month': 'Okt',
          'time': '08:00 - 15:00 WIB',
          'type': 'Shooting',
          'type_color': '#EC4899',
        },
        {
          'id': 'talent_ag_3',
          'title': 'Fitting Kostum & Briefing Tim Wardrobe / MUA',
          'date': '30',
          'month': 'Okt',
          'time': '13:00 - 15:00 WIB',
          'type': 'Fitting MUA',
          'type_color': '#8B5CF6',
        },
      ];
    }
    return [
      {
        'id': 'ag_1',
        'title': 'Gladi Resik & Technical Meeting Expo',
        'date': '24',
        'month': 'Okt',
        'time': '14:00 - 17:00 WIB',
        'type': 'Offline',
        'type_color': '#F97316',
      },
      {
        'id': 'ag_2',
        'title': 'Review Final Edit Video Dokumentasi',
        'date': '27',
        'month': 'Okt',
        'time': '10:00 - 11:30 WIB',
        'type': 'Online',
        'type_color': '#3B82F6',
      },
      {
        'id': 'ag_3',
        'title': 'Evaluasi Anggaran & Serah Terima Aset',
        'date': '31',
        'month': 'Okt',
        'time': '15:00 - 16:30 WIB',
        'type': 'Online',
        'type_color': '#10B981',
      },
    ];
  }

  List<Map<String, dynamic>> _getEffectiveProjectAssets() {
    if (widget.user.isGuest) return const [];
    if (_projectAssets.isNotEmpty) return _projectAssets;
    if (_isTalentAndPerformer) {
      return [
        {
          'id': 'ast_t1',
          'title': 'Showreel Performa 2026 (4K).mp4',
          'type': 'video',
          'gradient': [const Color(0xFFEA580C), const Color(0xFFF97316)],
        },
        {
          'id': 'ast_t2',
          'title': 'Comp Card & Sedcard Resmi.pdf',
          'type': 'doc',
          'icon': Icons.badge_outlined,
          'gradient': [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
        },
        {
          'id': 'ast_t3',
          'title': 'Headshot & Full Body Photoshoot.zip',
          'type': 'photo',
          'gradient': [const Color(0xFFEC4899), const Color(0xFFF43F5E)],
        },
        {
          'id': 'ast_t4',
          'title': 'Voice Over Sample (Commercial).wav',
          'type': 'audio',
          'icon': Icons.mic_external_on_outlined,
          'gradient': [const Color(0xFF10B981), const Color(0xFF059669)],
        },
      ];
    }
    return [
      {
        'id': 'ast_1',
        'title': 'Foto Teaser Gathering.jpg',
        'type': 'photo',
        'gradient': [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      },
      {
        'id': 'ast_2',
        'title': 'Highlight Reel Expo.mp4',
        'type': 'video',
        'gradient': [const Color(0xFFEC4899), const Color(0xFFF43F5E)],
      },
      {
        'id': 'ast_3',
        'title': 'Raw Master Audio.wav',
        'type': 'audio',
        'icon': Icons.audiotrack_rounded,
        'gradient': [const Color(0xFF10B981), const Color(0xFF059669)],
      },
      {
        'id': 'ast_4',
        'title': 'Brand Assets & Guideline.zip',
        'type': 'doc',
        'icon': Icons.folder_zip_outlined,
        'gradient': [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      },
    ];
  }

  // ── Three-column section ─────────────────────────────────────────────────────
  Widget _buildThreeColumnSection(bool isDark) {
    final w = MediaQuery.of(context).size.width;
    final sub = CreatorSidebarMenus.normalizeSubRole(widget.user.subRole);
    final showClientWorkflow = widget.user.isGuest ||
        !_isCreator ||
        sub == 'event_organizer' ||
        sub == 'eo' ||
        sub == 'wedding_organizer' ||
        sub == 'wo' ||
        sub == 'school' ||
        sub == 'education' ||
        sub == 'institution' ||
        sub == 'government';

    final columns = showClientWorkflow
        ? [
            Expanded(child: _buildProjectNeedsSection(isDark)),
            const SizedBox(width: 14),
            Expanded(child: _buildClientProposalsSection(isDark)),
            const SizedBox(width: 14),
            Expanded(child: _buildClientActiveProjectsSection(isDark)),
          ]
        : [
            Expanded(child: _buildProjectNeedsSection(isDark)),
            const SizedBox(width: 14),
            Expanded(child: _buildAgendaSection(isDark)),
            const SizedBox(width: 14),
            Expanded(child: _buildProjectAssetsSection(isDark)),
          ];

    if (w > 760) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: columns,
        ),
      );
    }
    return Column(
      children: showClientWorkflow
          ? [
              _buildProjectNeedsSection(isDark),
              const SizedBox(height: 14),
              _buildClientProposalsSection(isDark),
              const SizedBox(height: 14),
              _buildClientActiveProjectsSection(isDark),
            ]
          : [
              _buildProjectNeedsSection(isDark),
              const SizedBox(height: 14),
              _buildAgendaSection(isDark),
              const SizedBox(height: 14),
              _buildProjectAssetsSection(isDark),
            ],
    );
  }

  Widget _buildProjectNeedsSection(bool isDark) {
    final needs = _getEffectiveProjectNeeds();
    return _SectionCard(
      title: _isCreator ? 'Proyek & Aktivitas' : 'Kebutuhan & Proyek',
      onViewAll: () => _navigateTo('Lihat Semua Proyek'),
      isDark: isDark,
      child: needs.isEmpty
          ? _DashboardCardEmptyState(
              icon: Icons.folder_open_rounded,
              badgeLabel: _isCreator ? '✦ PROYEK AKTIF' : '✦ KEBUTUHAN PROYEK',
              title: _isCreator ? 'Belum Ada Proyek' : 'Belum Ada Kebutuhan',
              subtitle: _isCreator
                  ? 'Aktivitas proyek dan order klien akan tampil di sini'
                  : 'Kebutuhan proyek Anda akan muncul di sini',
              actionLabel: _isCreator ? 'Cari Peluang' : 'Buat Kebutuhan',
              onAction: () => _navigateTo(_isCreator ? 'Cari Peluang' : 'Buat Kebutuhan'),
              isDark: isDark,
            )
          : Column(
              children: needs
                  .take(3)
                  .map((need) => _buildNeedItem(need, isDark))
                  .toList(),
            ),
    );
  }

  String _resolveNeedImageUrl(Map<String, dynamic> need) {
    final rawUrl = need['poster_url'] ??
        need['image_url'] ??
        need['cover_url'] ??
        need['thumbnail_url'] ??
        need['logo_url'] ??
        need['banner_url'] ??
        need['image'] ??
        need['photo_url'];
    if (rawUrl != null && rawUrl.toString().trim().isNotEmpty) {
      return ApiService.resolveAssetUrl(rawUrl.toString().trim());
    }

    final title = (need['title'] ?? '').toString().toLowerCase();
    final desc = (need['description'] ?? '').toString().toLowerCase();
    final combined = '$title $desc';

    if (combined.contains('tech') || combined.contains('startup') || combined.contains('pitch')) {
      return 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&w=200&q=80';
    } else if (combined.contains('music') || combined.contains('musik') || combined.contains('indie') || combined.contains('fest') || combined.contains('konser')) {
      return 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=200&q=80';
    } else if (combined.contains('gala') || combined.contains('dinner') || combined.contains('anniversary') || combined.contains('award') || combined.contains('resepsi')) {
      return 'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?auto=format&fit=crop&w=200&q=80';
    } else if (combined.contains('fashion') || combined.contains('model') || combined.contains('clothing')) {
      return 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=200&q=80';
    } else if (combined.contains('desain') || combined.contains('brand') || combined.contains('kemasan') || combined.contains('logo') || combined.contains('packaging')) {
      return 'https://images.unsplash.com/photo-1542744094-3a31f272c490?auto=format&fit=crop&w=200&q=80';
    } else if (combined.contains('video') || combined.contains('film') || combined.contains('shooting') || combined.contains('cinema') || combined.contains('tvc')) {
      return 'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?auto=format&fit=crop&w=200&q=80';
    } else if (combined.contains('sound') || combined.contains('audio') || combined.contains('podcast') || combined.contains('voice') || combined.contains('dubbing')) {
      return 'https://images.unsplash.com/photo-1590602847861-f357a9332bbc?auto=format&fit=crop&w=200&q=80';
    } else if (combined.contains('wedding') || combined.contains('nikah') || combined.contains('pengantin') || combined.contains('mua')) {
      return 'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=200&q=80';
    } else if (combined.contains('magang') || combined.contains('sekolah') || combined.contains('siswa') || combined.contains('animasi') || combined.contains('3d')) {
      return 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=200&q=80';
    } else if (combined.contains('lighting') || combined.contains('panggung') || combined.contains('stage')) {
      return 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=200&q=80';
    } else if (combined.contains('studio') || combined.contains('rig') || combined.contains('cyclorama')) {
      return 'https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?auto=format&fit=crop&w=200&q=80';
    }

    return 'https://images.unsplash.com/photo-1498050108023-c5249f4df085?auto=format&fit=crop&w=200&q=80';
  }

  Widget _buildNeedItem(Map<String, dynamic> need, bool isDark) {
    Color statusColor;
    try {
      final hex =
          (need['status_color'] as String?)?.replaceFirst('#', '') ?? '7C3AED';
      statusColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      statusColor = AppTheme.primaryPurple;
    }

    final budget = need['budget']?.toString() ??
        need['budget_range']?.toString() ??
        need['price']?.toString();
    final title = need['title']?.toString() ?? '-';

    return _InteractiveDashboardItemCard(
      isDark: isDark,
      tooltip: 'Buka detail proyek $title',
      onTap: () => _handleNeedItemClick(need),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF2D2A42) : const Color(0xFFE2E8F0),
                ),
              ),
              child: CachedNetworkImage(
                imageUrl: _resolveNeedImageUrl(need),
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  color: statusColor.withValues(alpha: 0.12),
                  child: Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
                errorWidget: (_, _, _) => Container(
                  color: statusColor.withValues(alpha: 0.12),
                  child: Icon(Icons.folder_outlined, color: statusColor, size: 16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  need['description']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? AppTheme.textMuted
                        : AppTheme.textMutedLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (budget != null && budget.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    budget,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryPurple,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              need['status']?.toString() ?? '',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
          ),
        ],
      ),
    );
  }

  void _handleNeedItemClick(Map<String, dynamic> need) {
    final id = need['id']?.toString() ?? '';
    final title = need['title']?.toString() ?? 'Kebutuhan Proyek';
    final desc = need['description']?.toString() ?? '';
    final budget = need['budget']?.toString() ??
        need['budget_range']?.toString() ??
        need['price']?.toString();
    final deadline = need['deadline']?.toString();
    final status = need['status']?.toString() ?? 'open';
    final isClosed = status.toLowerCase() == 'selesai' || status.toLowerCase() == 'closed';
    final subRole = widget.user.subRole ?? 'event_organizer';

    final opp = OpportunityModel(
      id: id.isNotEmpty ? id : 'opp_demo_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: desc.isNotEmpty ? desc : 'Detail kebutuhan proyek $title.',
      budgetRange: budget,
      deadline: deadline,
      status: isClosed ? 'closed' : 'open',
      subRoleSlug: subRole.isNotEmpty ? subRole : 'event_organizer',
      type: 'project',
      postedBy: widget.user.id,
      poster: OpportunityPoster(
        id: widget.user.id,
        name: widget.user.name,
        username: widget.user.username,
        avatarUrl: widget.user.avatarUrl,
        role: widget.user.role,
        isVerified: widget.user.isVerified,
      ),
      requirements: [
        OpportunityRequirementModel(
          id: 'req_1',
          subRoleSlug: 'fotografer',
          quantity: 2,
          notes: 'Dokumentasi foto profesional & liputan panggung',
        ),
        OpportunityRequirementModel(
          id: 'req_2',
          subRoleSlug: 'videografer',
          quantity: 1,
          notes: 'Aftermovie 4K sinematik & reels liputan',
        ),
      ],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailKebutuhanScreen(
          opportunity: opp,
          user: widget.user,
        ),
      ),
    ).then((_) => _loadDashboardData());
  }

  Widget _buildAgendaSection(bool isDark) {
    final agenda = _getEffectiveAgenda();
    return _SectionCard(
      title: _isCreator ? 'Agenda / Kalender' : 'Agenda & Jadwal',
      onViewAll: () => _navigateTo('Lihat Kalender'),
      viewAllLabel: 'Kalender',
      isDark: isDark,
      child: agenda.isEmpty
          ? _DashboardCardEmptyState(
              icon: Icons.calendar_today_rounded,
              badgeLabel: '✦ JADWAL & AGENDA',
              title: 'Belum Ada Agenda',
              subtitle: 'Jadwal Anda masih kosong',
              actionLabel: 'Atur Jadwal',
              onAction: () => _navigateTo('Atur Jadwal'),
              isDark: isDark,
            )
          : Column(
              children: agenda
                  .take(3)
                  .map((item) => _buildAgendaItem(item, isDark))
                  .toList(),
            ),
    );
  }

  Widget _buildAgendaItem(Map<String, dynamic> item, bool isDark) {
    Color typeColor;
    try {
      final hex =
          (item['type_color'] as String?)?.replaceFirst('#', '') ?? '3B82F6';
      typeColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      typeColor = Colors.blue;
    }

    final title = item['title']?.toString() ?? 'Agenda';

    return _InteractiveDashboardItemCard(
      isDark: isDark,
      tooltip: 'Buka agenda: $title',
      onTap: () => _handleAgendaItemClick(item),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item['date']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryPurple,
                  ),
                ),
                Text(
                  item['month']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 8,
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item['time']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? AppTheme.textMuted
                        : AppTheme.textMutedLight,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item['type']?.toString() ?? '',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: typeColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
          ),
        ],
      ),
    );
  }

  void _handleAgendaItemClick(Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = item['title']?.toString() ?? 'Agenda';
    final date = '${item['date']} ${item['month']}';
    final time = item['time']?.toString() ?? '';
    final type = item['type']?.toString() ?? 'Event';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
        title: Row(
          children: [
            Icon(Icons.event_note_rounded, color: _roleAccentColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Jadwal: $date • $time', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Kategori: $type', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
            const SizedBox(height: 12),
            Text(
              'Aktivitas teragendakan pada kalender proyek Kreavana. Anda dapat mengelola waktu dan sinkronisasi jadwal di halaman Kalender.',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey.shade700, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateTo('Lihat Kalender');
            },
            icon: const Icon(Icons.calendar_month_rounded, size: 16, color: Colors.white),
            label: const Text('Buka Kalender', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectAssetsSection(bool isDark) {
    final assets = _getEffectiveProjectAssets();
    return _SectionCard(
      title: _isCreator ? 'Portofolio & Karya' : 'Aset & Hasil Proyek',
      onViewAll: () => _navigateTo('Lihat Semua Karya'),
      isDark: isDark,
      child: assets.isEmpty
          ? _DashboardCardEmptyState(
              icon: Icons.collections_bookmark_rounded,
              badgeLabel: '✦ PORTOFOLIO KREATOR',
              title: 'Belum Ada Karya',
              subtitle: 'Belum ada karya atau aset proyek.',
              actionLabel: 'Tambah Karya',
              onAction: () => _navigateTo('Tambah Karya'),
              isDark: isDark,
            )
          : Column(
              children: [
                Row(
                  children: [
                    if (assets.isNotEmpty) Expanded(child: _buildAssetThumbnail(assets[0], isDark)),
                    const SizedBox(width: 8),
                    if (assets.length > 1) Expanded(child: _buildAssetThumbnail(assets[1], isDark)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (assets.length > 2) Expanded(child: _buildAssetThumbnail(assets[2], isDark)),
                    const SizedBox(width: 8),
                    if (assets.length > 3) Expanded(child: _buildAssetThumbnail(assets[3], isDark)),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildAssetThumbnail(Map<String, dynamic> asset, bool isDark) {
    final gradientColors =
        asset['gradient'] as List<Color>? ??
        [AppTheme.primaryPurple, AppTheme.deepPurple];
    final type = asset['type']?.toString() ?? 'photo';
    final iconData =
        (asset['icon'] as IconData?) ??
        (type == 'video' ? Icons.play_circle_outline : Icons.photo_outlined);
    final title = asset['title']?.toString() ?? 'Karya';

    return _InteractiveDashboardItemCard(
      isDark: isDark,
      tooltip: 'Buka karya: $title',
      onTap: () => _handleAssetClick(asset),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                iconData,
                color: Colors.white.withValues(alpha: 0.4),
                size: 24,
              ),
            ),
            Positioned(
              bottom: 5,
              left: 6,
              right: 6,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAssetClick(Map<String, dynamic> asset) {
    final title = asset['title']?.toString() ?? 'Karya';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aset karya portofolio kreatif yang telah dipublikasikan di profil Kreavana.',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey.shade700, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateTo('Lihat Semua Karya');
            },
            icon: const Icon(Icons.collections_rounded, size: 16, color: Colors.white),
            label: const Text('Buka Portofolio', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _roleAccentColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Client Sections: Proposal Masuk & Proyek Berjalan ─────────────────────────
  Widget _buildClientProposalsSection(bool isDark) {
    final proposals = _getEffectiveIncomingProposals();
    return _SectionCard(
      title: 'Proposal Masuk',
      viewAllLabel: 'Lihat Semua',
      onViewAll: () {
        if (widget.user.isGuest) {
          AuthGuardDialog.show(context, actionName: 'melihat proposal masuk');
          return;
        }
        _navigateTo('Lihat Semua Proposal');
      },
      isDark: isDark,
      child: proposals.isEmpty
          ? _DashboardCardEmptyState(
              icon: Icons.mark_email_unread_rounded,
              badgeLabel: '✦ PENAWARAN KREATOR',
              title: 'Belum Ada Proposal',
              subtitle: 'Penawaran dari kreator akan muncul di sini',
              actionLabel: 'Cari Kreator',
              onAction: () {
                if (widget.user.isGuest) {
                  AuthGuardDialog.show(context, actionName: 'mencari kreator');
                  return;
                }
                _navigateTo('Cari Kreator');
              },
              isDark: isDark,
            )
          : Column(
              children: proposals
                  .take(3)
                  .map((prop) => _buildProposalItem(prop, isDark))
                  .toList(),
            ),
    );
  }

  Widget _buildProposalItem(Map<String, dynamic> prop, bool isDark) {
    final creatorName = prop['creator_name']?.toString() ?? 'Kreator';
    final opportunityTitle =
        prop['opportunity_title']?.toString() ?? 'Kebutuhan Proyek';
    final bidPrice = prop['bid_price']?.toString() ?? 'Sesuai Budget';
    final status = prop['status']?.toString() ?? 'submitted';
    final avatarUrl = prop['creator_avatar']?.toString();

    final isApproved = status == 'approved';
    final statusColor =
        isApproved ? const Color(0xFF10B981) : _roleAccentColor;
    final statusText = isApproved ? 'Disetujui' : 'Menunggu Review';

    return _InteractiveDashboardItemCard(
      isDark: isDark,
      tooltip: 'Review proposal dari $creatorName',
      onTap: () => _handleProposalItemClick(prop),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: _roleAccentColor.withValues(alpha: 0.12),
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? CachedNetworkImageProvider(ApiService.resolveAssetUrl(avatarUrl))
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? Text(
                    creatorName.isNotEmpty ? creatorName[0].toUpperCase() : 'K',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.primaryPurple,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creatorName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  opportunityTitle,
                  style: TextStyle(
                    fontSize: 10,
                    color:
                        isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  bidPrice,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _roleAccentColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
          ),
        ],
      ),
    );
  }

  void _handleProposalItemClick(Map<String, dynamic> prop) {
    _showProposalDetailModal(prop);
  }

  void _showProposalDetailModal(Map<String, dynamic> prop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final creatorName = prop['creator_name']?.toString() ?? 'Kreator';
    final opportunityTitle =
        prop['opportunity_title']?.toString() ?? 'Kebutuhan Proyek';
    final bidPrice = prop['bid_price']?.toString() ?? 'Sesuai Budget';
    final status = prop['status']?.toString() ?? 'submitted';
    final avatarUrl = prop['creator_avatar']?.toString();
    final creatorId = prop['creator_id']?.toString() ?? '';
    final pitch = prop['pitch_message']?.toString() ??
        'Proposal penawaran profesional untuk proyek $opportunityTitle.';
    final oppId = prop['opportunity_id']?.toString() ?? '';

    final isApproved = status == 'approved';
    final statusColor =
        isApproved ? const Color(0xFF10B981) : _roleAccentColor;
    final statusText = isApproved ? 'Disetujui' : 'Menunggu Review';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _roleAccentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.mark_email_read_rounded, color: _roleAccentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pengajuan Proposal Masuk',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          opportunityTitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    splashRadius: 18,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Creator Profile Snippet
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.inputDark : AppTheme.inputLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: _roleAccentColor.withValues(alpha: 0.12),
                      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? CachedNetworkImageProvider(ApiService.resolveAssetUrl(avatarUrl))
                          : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? Text(
                              creatorName.isNotEmpty ? creatorName[0].toUpperCase() : 'K',
                              style: TextStyle(fontWeight: FontWeight.bold, color: _roleAccentColor),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  creatorName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.verified_rounded, size: 14, color: _roleAccentColor),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ajuan Biaya: $bidPrice',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _roleAccentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Pitch cover letter
              const Text(
                'Catatan Penawaran & Portofolio:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF13111E) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
                child: Text(
                  pitch,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: isDark ? Colors.white70 : Colors.grey.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openChatWithPartner(creatorId, creatorName);
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: const Text('Chat Kreator', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        // Navigate directly to the opportunity page
                        _handleNeedItemClick({
                          'id': oppId,
                          'title': opportunityTitle,
                          'description': 'Kebutuhan proyek $opportunityTitle',
                          'budget': bidPrice,
                        });
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                      label: const Text('Buka Halaman Proyek', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _roleAccentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              if (creatorId.isNotEmpty && !creatorId.startsWith('creator_demo')) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      UserProfileModal.show(context, userId: creatorId);
                    },
                    icon: const Icon(Icons.person_search_rounded, size: 16),
                    label: const Text('Lihat Profil Lengkap & Rating Kreator', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientActiveProjectsSection(bool isDark) {
    final contracts = _getEffectiveRunningContracts();
    return _SectionCard(
      title: 'Proyek Berjalan',
      viewAllLabel: 'Lihat Semua',
      onViewAll: () {
        if (widget.user.isGuest) {
          AuthGuardDialog.show(context, actionName: 'melihat proyek berjalan');
          return;
        }
        _navigateTo('Lihat Semua Proyek Berjalan');
      },
      isDark: isDark,
      child: contracts.isEmpty
          ? _DashboardCardEmptyState(
              icon: Icons.handshake_rounded,
              badgeLabel: '✦ KONTRAK AKTIF',
              title: 'Belum Ada Proyek Aktif',
              subtitle: 'Proyek berjalan bersama kreator akan tampil di sini',
              actionLabel: 'Cari Kreator',
              onAction: () {
                if (widget.user.isGuest) {
                  AuthGuardDialog.show(context, actionName: 'mencari kreator');
                  return;
                }
                _navigateTo('Cari Kreator');
              },
              isDark: isDark,
            )
          : Column(
              children: contracts
                  .take(3)
                  .map((contract) => _buildRunningContractItem(contract, isDark))
                  .toList(),
            ),
    );
  }

  String _resolveContractImageUrl(Map<String, dynamic> contract) {
    final rawUrl = contract['image_url'] ??
        contract['poster_url'] ??
        contract['cover_url'] ??
        contract['thumbnail_url'] ??
        contract['creator_avatar'] ??
        contract['client_avatar'] ??
        contract['logo_url'] ??
        contract['banner_url'];
    if (rawUrl != null && rawUrl.toString().trim().isNotEmpty) {
      return ApiService.resolveAssetUrl(rawUrl.toString().trim());
    }

    final title = (contract['title'] ?? '').toString().toLowerCase();
    final creator = (contract['creator_name'] ?? '').toString().toLowerCase();
    final desc = (contract['description'] ?? '').toString().toLowerCase();
    final combined = '$title $creator $desc';

    if (combined.contains('kampanye') || combined.contains('digital') || combined.contains('marketing') || combined.contains('solusi brand')) {
      return 'https://images.unsplash.com/photo-1460925895917-afdab827c52f?auto=format&fit=crop&w=200&q=80';
    } else if (combined.contains('kopi') || combined.contains('senja') || combined.contains('kemasan') || combined.contains('identitas')) {
      return 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=200&q=80';
    } else if (combined.contains('audio') || combined.contains('sound') || combined.contains('skysound') || combined.contains('jingle')) {
      return 'https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?auto=format&fit=crop&w=200&q=80';
    } else if (combined.contains('backdrop') || combined.contains('merchandise') || combined.contains('lanyard')) {
      return 'https://images.unsplash.com/photo-1542744094-3a31f272c490?auto=format&fit=crop&w=200&q=80';
    } else if (combined.contains('video') || combined.contains('film') || combined.contains('aftermovie') || combined.contains('cinematic') || combined.contains('andi')) {
      return 'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?auto=format&fit=crop&w=200&q=80';
    } else if (combined.contains('photo') || combined.contains('foto') || combined.contains('lensa') || combined.contains('rina')) {
      return 'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?auto=format&fit=crop&w=200&q=80';
    } else if (combined.contains('event') || combined.contains('expo') || combined.contains('gala') || combined.contains('dinner') || combined.contains('bumn') || combined.contains('gathering')) {
      return 'https://images.unsplash.com/photo-1511578314322-379afb476865?auto=format&fit=crop&w=200&q=80';
    }

    return 'https://images.unsplash.com/photo-1522071820081-009f0129c71c?auto=format&fit=crop&w=200&q=80';
  }

  Widget _buildRunningContractItem(Map<String, dynamic> c, bool isDark) {
    final title = c['title']?.toString() ?? 'Proyek Kontrak';
    final creatorName = c['creator_name']?.toString() ?? 'Kreator';
    final agreedPrice = c['agreed_price']?.toString() ?? 'Rp0';
    final deadline = c['deadline']?.toString() ?? '-';
    final workStatus =
        c['work_status']?.toString().toLowerCase() ?? 'in_progress';

    String statusLabel = 'Dikerjakan';
    Color statusColor = const Color(0xFF3B82F6);
    if (workStatus == 'submitted' || workStatus == 'review') {
      statusLabel = 'Perlu Review';
      statusColor = const Color(0xFFF59E0B);
    } else if (workStatus == 'revision') {
      statusLabel = 'Revisi';
      statusColor = const Color(0xFFEF4444);
    } else if (workStatus == 'completed') {
      statusLabel = 'Selesai';
      statusColor = const Color(0xFF10B981);
    }

    final contractId = c['id']?.toString() ?? '';

    return _InteractiveDashboardItemCard(
      isDark: isDark,
      tooltip: 'Buka kontrak proyek $title',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProyekSayaScreen(
              user: widget.user,
              initialContractId: contractId,
              initialTitle: title,
            ),
          ),
        );
      },
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF2D2A42) : const Color(0xFFE2E8F0),
                ),
              ),
              child: CachedNetworkImage(
                imageUrl: _resolveContractImageUrl(c),
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  color: statusColor.withValues(alpha: 0.12),
                  child: Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
                errorWidget: (_, _, _) => Container(
                  color: statusColor.withValues(alpha: 0.12),
                  child: Icon(Icons.handshake_outlined, color: statusColor, size: 16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Kreator: $creatorName • DL: $deadline',
                  style: TextStyle(
                    fontSize: 10,
                    color:
                        isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  agreedPrice,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryPurple,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
          ),
        ],
      ),
    );
  }

  Future<void> _openChatWithPartner(String targetUserId, String? targetUserName) async {
    final cleanId = targetUserId.trim();
    if (cleanId.isEmpty || cleanId.startsWith('creator_demo') || cleanId.startsWith('client_demo')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DirectMessageScreen(
            currentUser: widget.user,
            targetUserId: cleanId.isNotEmpty ? cleanId : 'demo_partner',
            initialChat: {
              'name': targetUserName ?? 'Partner',
              'id': cleanId.isNotEmpty ? cleanId : 'demo_partner',
            },
          ),
        ),
      );
      return;
    }

    try {
      final res = await ChatService.startPersonalChat(cleanId);
      final chatData = res['data'];
      final chatId = chatData != null ? chatData['id']?.toString() : null;
      final chatMap = chatData != null ? Map<String, dynamic>.from(chatData) : null;

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DirectMessageScreen(
              currentUser: widget.user,
              targetUserId: cleanId,
              chatId: chatId,
              initialChat: chatMap,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
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

  // ── Ekosistem 5 Pilar Talent & Performer ─────────────────────────────────────
  Widget _buildTalentEcosystemSection(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: const Color(0xFFEA580C).withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          if (!isDark) ...AppTheme.cardShadowLight,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Ekosistem Kolaborasi Talent & Performer',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEA580C), Color(0xFFC026D3)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '#KolaborasiMembawaDampak',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Kreavana menghubungkan talent dan performer dengan klien, kreator, vendor, komunitas serta berbagai peluang industri kreatif untuk berkembang lebih jauh.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Profession / Scope Chips
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFFEA580C).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFEA580C).withValues(alpha: 0.15),
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      size: 14,
                      color: Color(0xFFEA580C),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Cakupan Talenta:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
                ...[
                  'Model',
                  'Aktor',
                  'MC & Host',
                  'Penyanyi',
                  'Musisi',
                  'Penari',
                  'Voice Over',
                  'Influencer / KOL',
                ].map(
                  (role) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark
                            ? Colors.white24
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      role,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // The 4 Pillar Cards (Responsive 2-column or 1-column)
          LayoutBuilder(
            builder: (context, constraints) {
              final isTwoCol = constraints.maxWidth > 650;
              final cards = [
                _buildEcosystemPillarCard(
                  title: 'Klien / Corporate',
                  subtitle: 'Brand, Perusahaan, Instansi, BUMN, Swasta, dll',
                  icon: Icons.corporate_fare_rounded,
                  color: const Color(0xFF2563EB),
                  isDark: isDark,
                  benefits: const [
                    'Peluang tampil di berbagai kampanye & proyek',
                    'Job dan kontrak profesional terjamin',
                    'Eksposur ke audiens yang lebih luas',
                    'Penghasilan yang lebih stabil & terarah',
                  ],
                  contributions: const [
                    'Penampilan & konten berkualitas sesuai brief',
                    'Profesionalisme tinggi & disiplin waktu',
                    'Representasi positif reputasi brand klien',
                    'Partisipasi aktif dalam kegiatan promosi',
                  ],
                  actionLabel: 'Cari Proyek Klien',
                  onAction: () => _navigateTo('Cari Casting & Job'),
                ),
                _buildEcosystemPillarCard(
                  title: 'Kreator / Profesional Kreatif',
                  subtitle: 'Fotografer, Videografer, Desainer, Content Creator',
                  icon: Icons.camera_alt_rounded,
                  color: const Color(0xFFEC4899),
                  isDark: isDark,
                  benefits: const [
                    'Kolaborasi dalam berbagai proyek kreatif',
                    'Portofolio & materi konten visual berkualitas',
                    'Kesempatan membangun karya masterpiece bersama',
                    'Jaringan luas dengan sesama insan kreatif',
                  ],
                  contributions: const [
                    'Menjadi model, talent utama atau narasumber',
                    'Memberikan performa panggung & visual terbaik',
                    'Membantu proses produksi & pembuatan konten',
                    'Merekomendasikan rekan kreator satu sama lain',
                  ],
                  actionLabel: 'Kolaborasi Kreator',
                  onAction: () => _navigateTo('Kolaborasi Kreator'),
                ),
                _buildEcosystemPillarCard(
                  title: 'Mitra / Vendor / Penyedia Jasa',
                  subtitle: 'Studio, EO, MUA, Wardrobe, Rental Alat, Produksi',
                  icon: Icons.handshake_rounded,
                  color: const Color(0xFFF97316),
                  isDark: isDark,
                  benefits: const [
                    'Layanan pendukung produksi berkualitas prima',
                    'Penampilan visual lebih maksimal di set',
                    'Paket kerja sama & penawaran harga khusus',
                    'Jaringan kemitraan vendor terpercaya',
                  ],
                  contributions: const [
                    'Menggunakan jasa layanan vendor terverifikasi',
                    'Memberikan ulasan positif & testimoni nyata',
                    'Memberi rekomendasi kepada sesama talent',
                    'Kolaborasi harmonis dalam eksekusi produksi',
                  ],
                  actionLabel: 'Eksplor Vendor & MUA',
                  onAction: () => _navigateTo('Mitra Vendor & MUA'),
                ),
                _buildEcosystemPillarCard(
                  title: 'Komunitas & Event',
                  subtitle: 'Komunitas Seni, Musik, Teater, Budaya, Wisata',
                  icon: Icons.groups_rounded,
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                  benefits: const [
                    'Kesempatan tampil di panggung festival & event',
                    'Eksposur publik & jam terbang panggung baru',
                    'Jaringan komunitas dengan sesama performer',
                    'Dukungan moral & apresiasi tinggi dari audiens',
                  ],
                  contributions: const [
                    'Berpartisipasi aktif dalam event dan kegiatan',
                    'Berbagi pengalaman, wawasan & inspirasi',
                    'Membantu promosi kegiatan komunitas',
                    'Membangun ekosistem kreatif bersama-sama',
                  ],
                  actionLabel: 'Jelajahi Komunitas',
                  onAction: () => context.go(AppRoutes.explore),
                ),
              ];

              if (isTwoCol) {
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 14),
                        Expanded(child: cards[1]),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cards[2]),
                        const SizedBox(width: 14),
                        Expanded(child: cards[3]),
                      ],
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  cards[0],
                  const SizedBox(height: 14),
                  cards[1],
                  const SizedBox(height: 14),
                  cards[2],
                  const SizedBox(height: 14),
                  cards[3],
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // 5th Pillar: Tim Kreavana Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        const Color(0xFF4C1D95).withValues(alpha: 0.6),
                        const Color(0xFF1E1B4B).withValues(alpha: 0.7),
                      ]
                    : [
                        const Color(0xFF7C3AED).withValues(alpha: 0.08),
                        const Color(0xFFC026D3).withValues(alpha: 0.05),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.4 : 0.25),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPurple.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tim Kreavana — Platform & Ekosistem Kolaborasi',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Operasional, Marketing, IT, Talent Partnership, & Edukasi',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
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
                    final isWide = constraints.maxWidth > 650;
                    final leftCol = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 14, color: AppTheme.primaryPurple),
                            const SizedBox(width: 6),
                            const Text(
                              'Manfaat untuk Talent:',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...[
                          'Pencocokan peluang cerdas (AI Matching) yang relevan',
                          'Akses informasi casting, event, & proyek terbaru',
                          'Dukungan penggunaan platform & negosiasi proyek aman',
                          'Edukasi, pelatihan, workshop, & sertifikasi talenta',
                          'Jaminan pembayaran escrow & bantuan kontrak hukum',
                        ].map((m) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('✓ ',
                                      style: TextStyle(
                                          color: Color(0xFF10B981),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: Text(m,
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            height: 1.35,
                                            color: isDark
                                                ? Colors.white70
                                                : const Color(0xFF334155))),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    );

                    final rightCol = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.favorite_rounded,
                                size: 14, color: const Color(0xFFEC4899)),
                            const SizedBox(width: 6),
                            const Text(
                              'Kontribusi Talent:',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...[
                          'Melengkapi data profil, portofolio & showreel resmi',
                          'Aktif mencari, merespons, dan melamar peluang terbuka',
                          'Memberikan feedback untuk penyempurnaan platform',
                          'Menjaga reputasi positif, etika kerja, & profesionalisme',
                          'Mendukung pertumbuhan ekosistem kreatif Kreavana',
                        ].map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('✓ ',
                                      style: TextStyle(
                                          color: Color(0xFF10B981),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: Text(c,
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            height: 1.35,
                                            color: isDark
                                                ? Colors.white70
                                                : const Color(0xFF334155))),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: leftCol),
                          const SizedBox(width: 18),
                          Expanded(child: rightCol),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        leftCol,
                        const SizedBox(height: 12),
                        rightCol,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Kreavana — Lebih dari Sekadar Platform, Ini Adalah Ekosistem.',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    HoverLiftButton(
                      glowColor: AppTheme.primaryPurple,
                      scale: 1.03,
                      translateY: -2.0,
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => context.go(AppRoutes.pesan),
                      child: ElevatedButton.icon(
                        onPressed: () => context.go(AppRoutes.pesan),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.chat_outlined, size: 14),
                        label: const Text(
                          'Hubungi Tim',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEcosystemPillarCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required List<String> benefits,
    required List<String> contributions,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.08)
            : color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.22),
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Manfaat untuk Talent:',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          ...benefits.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 2.5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('✓ ',
                        style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        b,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          Text(
            'Kontribusi Talent:',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 4),
          ...contributions.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 2.5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('✓ ',
                        style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        c,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: HoverLiftButton(
              glowColor: color,
              scale: 1.02,
              translateY: -1.5,
              borderRadius: BorderRadius.circular(8),
              onTap: onAction,
              child: OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  foregroundColor: color,
                  padding: EdgeInsets.zero,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      actionLabel,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 13),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Ekosistem Role 3: Vendor & Penyedia Jasa Pendukung ────────────────────────
  Widget _buildVendorEcosystemSection(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          if (!isDark) ...AppTheme.cardShadowLight,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD97706), Color(0xFFEA580C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD97706).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Role 3',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Text(
                          'Vendor & Penyedia Jasa Pendukung',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD97706), Color(0xFFEA580C)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '#KolaborasiMembangunDampak',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Studio, rental alat, MUA, wardrobe, dekorasi, katering, printing, lighting, sound, transportasi, dan jasa pendukung lainnya.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Two Value Panels: Manfaat yang Didapat & Manfaat yang Diberikan ke Kreavana
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;

              final getPanel = Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF10B981).withValues(alpha: 0.08)
                      : const Color(0xFF10B981).withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.35 : 0.22),
                    width: 1.1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manfaat yang Didapat',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              Text(
                                'Nilai yang Anda peroleh dengan bergabung di Kreavana',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...[
                      'Pesanan dan penyewaan dari kreator, klien, dan EO',
                      'Pelanggan baru dari berbagai industri dan daerah',
                      'Portofolio layanan yang lebih luas dan terstruktur',
                      'Jaringan dengan kreator, talent, klien, dan mitra lainnya',
                      'Pertumbuhan pendapatan dan peluang kerja sama jangka panjang',
                    ].map(
                      (point) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: Color(0xFF10B981),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                point,
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.35,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
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

              final givePanel = Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2563EB).withValues(alpha: 0.08)
                      : const Color(0xFF2563EB).withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.35 : 0.22),
                    width: 1.1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_downward_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manfaat yang Diberikan ke Kreavana',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              Text(
                                'Kontribusi Anda untuk membangun ekosistem yang lebih kuat',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...[
                      'Produk, peralatan, dan fasilitas yang tersedia untuk proyek dan penyewaan',
                      'Jasa dan layanan pendukung dengan kualitas terbaik',
                      'Kualitas dan keandalan layanan untuk menjaga kepuasan pengguna',
                      'Ketersediaan untuk proyek, event, dan kolaborasi',
                      'Ulasan, testimoni, dan dokumentasi hasil kerja',
                    ].map(
                      (point) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                point,
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.35,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
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

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: getPanel),
                    const SizedBox(width: 14),
                    Expanded(child: givePanel),
                  ],
                );
              }
              return Column(
                children: [
                  getPanel,
                  const SizedBox(height: 14),
                  givePanel,
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // 7-Stakeholder Ecosystem Connector (Kreavana in Center)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : const Color(0xFFD97706).withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFD97706).withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.hub_outlined,
                      size: 18,
                      color: Color(0xFFD97706),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Pusat Ekosistem Kolaborasi Kreatif Kreavana',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Sebagai Vendor & Penyedia Jasa, Anda terhubung langsung dengan 7 pilar pemangku kepentingan industri kreatif:',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildVendorEcosystemNode(
                      title: 'Perusahaan / Corporate',
                      desc: 'Klien & Brand',
                      icon: Icons.business_rounded,
                      color: const Color(0xFF0284C7),
                      isDark: isDark,
                    ),
                    _buildVendorEcosystemNode(
                      title: 'EO, WO, Agency',
                      desc: 'Event & Produksi',
                      icon: Icons.event_available_rounded,
                      color: const Color(0xFFDB2777),
                      isDark: isDark,
                    ),
                    _buildVendorEcosystemNode(
                      title: 'Venue & Lokasi',
                      desc: 'Studio, Gedung, Destinasi',
                      icon: Icons.location_on_rounded,
                      color: const Color(0xFFEA580C),
                      isDark: isDark,
                    ),
                    _buildVendorEcosystemNode(
                      title: 'Tim Kreavana',
                      desc: 'Operasional, Marketing, IT',
                      icon: Icons.verified_user_rounded,
                      color: const Color(0xFF7C3AED),
                      isDark: isDark,
                    ),
                    _buildVendorEcosystemNode(
                      title: 'Komunitas',
                      desc: 'Seni, Hobi, Profesi',
                      icon: Icons.groups_rounded,
                      color: const Color(0xFF059669),
                      isDark: isDark,
                    ),
                    _buildVendorEcosystemNode(
                      title: 'Talent / Performer',
                      desc: 'Model, MC, Aktor, dsb',
                      icon: Icons.theater_comedy_rounded,
                      color: const Color(0xFF6366F1),
                      isDark: isDark,
                    ),
                    _buildVendorEcosystemNode(
                      title: 'Kreator / Freelancer',
                      desc: 'Foto, Video, Desain',
                      icon: Icons.camera_alt_rounded,
                      color: const Color(0xFFDC2626),
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 9 Layanan & Peralatan Utama (Visual Category Cards Grid)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '9 Kategori Layanan & Fasilitas Utama',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Klik kategori untuk mengelola unit inventaris dan penawaran sewa',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                    ),
                  ),
                ],
              ),
              HoverLiftButton(
                glowColor: const Color(0xFFD97706),
                scale: 1.03,
                translateY: -1.5,
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openCreatorService('vendor_katalog'),
                child: TextButton.icon(
                  onPressed: () => _openCreatorService('vendor_katalog'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  label: const Text(
                    'Katalog Lengkap',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width > 900 ? 3 : (width > 550 ? 2 : 1);

              final categories = [
                {
                  'title': 'Studio & Ruang Produksi',
                  'desc': 'Cyclorama, podcast room, green screen, soundproofing studio',
                  'icon': Icons.videocam_outlined,
                  'color': const Color(0xFF2563EB),
                },
                {
                  'title': 'Rental Alat Foto & Video',
                  'desc': 'Cinema cameras, Sony/Canon lenses, gimbals, drones & monitors',
                  'icon': Icons.camera_alt_outlined,
                  'color': const Color(0xFFD97706),
                },
                {
                  'title': 'MUA & Beauty Service',
                  'desc': 'Pro makeup artist, hair do, bridal beauty & special FX makeup',
                  'icon': Icons.face_retouching_natural_outlined,
                  'color': const Color(0xFFEC4899),
                },
                {
                  'title': 'Wardrobe & Kostum',
                  'desc': 'Baju adat daerah, kostum cosplay, gaun pesta & setelan jas',
                  'icon': Icons.checkroom_outlined,
                  'color': const Color(0xFF8B5CF6),
                },
                {
                  'title': 'Dekorasi & Properti',
                  'desc': 'Backdrop panggung, lighting booth, dekorasi tematik & bunga',
                  'icon': Icons.deck_outlined,
                  'color': const Color(0xFF10B981),
                },
                {
                  'title': 'Katering & Food Service',
                  'desc': 'Buffet catering kru produksi, meal box event & coffee station',
                  'icon': Icons.restaurant_outlined,
                  'color': const Color(0xFFEA580C),
                },
                {
                  'title': 'Printing & Merchandise',
                  'desc': 'Cetak banner spanduk, flyer, kartu nama, totebag & sablon kaos',
                  'icon': Icons.print_outlined,
                  'color': const Color(0xFF0284C7),
                },
                {
                  'title': 'Lighting & Sound System',
                  'desc': 'Line array speakers, wireless mics, moving head & smoke machine',
                  'icon': Icons.speaker_group_outlined,
                  'color': const Color(0xFFF59E0B),
                },
                {
                  'title': 'Transportasi & Logistik',
                  'desc': 'Mobil van kru, armada truk box towing & logistik antar jemput',
                  'icon': Icons.local_shipping_outlined,
                  'color': const Color(0xFF475569),
                },
              ];

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: categories.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: crossAxisCount == 1 ? 3.8 : 2.5,
                ),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final catColor = cat['color'] as Color;
                  return InkWell(
                    onTap: () => _openCreatorService('vendor_katalog'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? catColor.withValues(alpha: 0.08)
                            : catColor.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: catColor.withValues(alpha: isDark ? 0.35 : 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              cat['icon'] as IconData,
                              color: catColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  cat['title'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  cat['desc'] as String,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: catColor.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Footer bar
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Kreavana — Lebih dari Sekadar Platform, Ini Adalah Ekosistem.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD97706),
                  ),
                ),
              ),
              HoverLiftButton(
                glowColor: const Color(0xFFD97706),
                scale: 1.03,
                translateY: -2.0,
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openCreatorService('vendor_katalog'),
                child: ElevatedButton.icon(
                  onPressed: () => _openCreatorService('vendor_katalog'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.inventory_2_outlined, size: 14),
                  label: const Text(
                    'Kelola Katalog',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVendorEcosystemNode({
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.12)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.4 : 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 9,
                  color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Workflow steps ───────────────────────────────────────────────────────────
  Widget _buildWorkflowSection(bool isDark) {
    final steps = _isVendorOrMitra
        ? [
            {
              'n': '1',
              'title': 'Daftar & Profil',
              'sub': 'Bisnis, kontak, lokasi',
              'icon': Icons.app_registration_rounded,
              'color': const Color(0xFF2563EB),
              'image_url': 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=200&q=80',
            },
            {
              'n': '2',
              'title': 'Katalog & Harga',
              'sub': 'Produk, alat, & tarif',
              'icon': Icons.inventory_2_outlined,
              'color': const Color(0xFFD97706),
              'image_url': 'https://images.unsplash.com/photo-1581291518857-4e27b48ff24e?auto=format&fit=crop&w=200&q=80',
            },
            {
              'n': '3',
              'title': 'Atur Ketersediaan',
              'sub': 'Jadwal sewa & slot event',
              'icon': Icons.calendar_month_outlined,
              'color': const Color(0xFF8B5CF6),
              'image_url': 'https://images.unsplash.com/photo-1506784983877-45594efa4cbe?auto=format&fit=crop&w=200&q=80',
            },
            {
              'n': '4',
              'title': 'Terima Permintaan',
              'sub': 'Pesanan klien/kreator/EO',
              'icon': Icons.chat_bubble_outline_rounded,
              'color': const Color(0xFFEA580C),
              'image_url': 'https://images.unsplash.com/photo-1577563908411-5077b6dc7624?auto=format&fit=crop&w=200&q=80',
            },
            {
              'n': '5',
              'title': 'Laksanakan Layanan',
              'sub': 'Siapkan alat & tim',
              'icon': Icons.build_circle_outlined,
              'color': const Color(0xFF10B981),
              'image_url': 'https://images.unsplash.com/photo-1511578314322-379afb476865?auto=format&fit=crop&w=200&q=80',
            },
            {
              'n': '6',
              'title': 'Bangun Reputasi',
              'sub': 'Ulasan & testimoni',
              'icon': Icons.star_rounded,
              'color': const Color(0xFF0EA5E9),
              'image_url': 'https://images.unsplash.com/photo-1557804506-669a67965ba0?auto=format&fit=crop&w=200&q=80',
            },
          ]
        : _isTalentAndPerformer
            ? [
            {
              'n': '1',
              'title': 'Daftar & Profil',
              'sub': 'Isi data diri & jadwal',
              'icon': Icons.badge_outlined,
              'color': const Color(0xFF2563EB),
              'image_url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
            },
            {
              'n': '2',
              'title': 'Unggah Showreel',
              'sub': 'Foto, video & audio',
              'icon': Icons.smart_display_outlined,
              'color': const Color(0xFF8B5CF6),
              'image_url': 'https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?auto=format&fit=crop&w=200&q=80',
            },
            {
              'n': '3',
              'title': 'Ajukan Peluang',
              'sub': 'Job, event, casting',
              'icon': Icons.search_rounded,
              'color': const Color(0xFFEC4899),
              'image_url': 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=200&q=80',
            },
            {
              'n': '4',
              'title': 'Hubungi Klien/Tim',
              'sub': 'Chat & negosiasi aman',
              'icon': Icons.chat_bubble_outline_rounded,
              'color': const Color(0xFFEA580C),
              'image_url': 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=200&q=80',
            },
            {
              'n': '5',
              'title': 'Tampil & Eksekusi',
              'sub': 'Realisasi proyek',
              'icon': Icons.theater_comedy_rounded,
              'color': const Color(0xFF10B981),
              'image_url': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=200&q=80',
            },
            {
              'n': '6',
              'title': 'Bangun Reputasi',
              'sub': 'Rating & ulasan klien',
              'icon': Icons.star_rounded,
              'color': const Color(0xFF0EA5E9),
              'image_url': 'https://images.unsplash.com/photo-1551288049-bebda4e38f71?auto=format&fit=crop&w=200&q=80',
            },
          ]
        : _isCreator
            ? [
                {
                  'n': '1',
                  'title': 'Profil Lengkap',
                  'sub': 'Isi data & niche',
                  'icon': Icons.person_outline,
                  'color': const Color(0xFF7C3AED),
                  'image_url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
                },
                {
                  'n': '2',
                  'title': 'Dapat Rekomendasi',
                  'sub': 'Peluang sesuai niche',
                  'icon': Icons.auto_awesome,
                  'color': const Color(0xFFEAB308),
                  'image_url': 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=200&q=80',
                },
                {
                  'n': '3',
                  'title': 'Ajukan Proposal',
                  'sub': 'Kirim penawaran terbaik',
                  'icon': Icons.description_outlined,
                  'color': const Color(0xFF3B82F6),
                  'image_url': 'https://images.unsplash.com/photo-1455390582262-044cdead277a?auto=format&fit=crop&w=200&q=80',
                },
                {
                  'n': '4',
                  'title': 'Jalankan Campaign',
                  'sub': 'Produksi & publikasi',
                  'icon': Icons.event_note_outlined,
                  'color': const Color(0xFF7C3AED),
                  'image_url': 'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?auto=format&fit=crop&w=200&q=80',
                },
                {
                  'n': '5',
                  'title': 'Dapat Review',
                  'sub': 'Ulasan & rating klien',
                  'icon': Icons.star_outline,
                  'color': const Color(0xFF10B981),
                  'image_url': 'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?auto=format&fit=crop&w=200&q=80',
                },
                {
                  'n': '6',
                  'title': 'Reputasi Naik',
                  'sub': 'Peluang meningkat',
                  'icon': Icons.trending_up,
                  'color': const Color(0xFF14B8A6),
                  'image_url': 'https://images.unsplash.com/photo-1551288049-bebda4e38f71?auto=format&fit=crop&w=200&q=80',
                },
              ]
            : [
                {
                  'n': '1',
                  'title': 'Buat Kebutuhan',
                  'sub': 'Tulis brief',
                  'icon': Icons.edit_note,
                  'color': const Color(0xFF3B82F6),
                  'image_url': 'https://images.unsplash.com/photo-1455390582262-044cdead277a?auto=format&fit=crop&w=200&q=80',
                },
                {
                  'n': '2',
                  'title': 'Cocokkan Kreator',
                  'sub': 'AI matching otomatis',
                  'icon': Icons.auto_awesome,
                  'color': const Color(0xFF7C3AED),
                  'image_url': 'https://images.unsplash.com/photo-1522071820081-009f0129c71c?auto=format&fit=crop&w=200&q=80',
                },
                {
                  'n': '3',
                  'title': 'Terima Proposal',
                  'sub': 'Bandingkan tawaran',
                  'icon': Icons.mail_outline,
                  'color': const Color(0xFF10B981),
                  'image_url': 'https://images.unsplash.com/photo-1460925895917-afdab827c52f?auto=format&fit=crop&w=200&q=80',
                },
                {
                  'n': '4',
                  'title': 'Pilih Kreator',
                  'sub': 'Setujui kolaborator',
                  'icon': Icons.person_add_outlined,
                  'color': const Color(0xFFF97316),
                  'image_url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
                },
                {
                  'n': '5',
                  'title': 'Pantau Proyek',
                  'sub': 'Review progres',
                  'icon': Icons.analytics_outlined,
                  'color': const Color(0xFF14B8A6),
                  'image_url': 'https://images.unsplash.com/photo-1551288049-bebda4e38f71?auto=format&fit=crop&w=200&q=80',
                },
                {
                  'n': '6',
                  'title': 'Beri Ulasan',
                  'sub': 'Bangun ekosistem',
                  'icon': Icons.star_outline,
                  'color': const Color(0xFFEAB308),
                  'image_url': 'https://images.unsplash.com/photo-1557804506-669a67965ba0?auto=format&fit=crop&w=200&q=80',
                },
              ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
        ),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isVendorOrMitra
                ? 'Alur Kerja Vendor & Penyedia Jasa di Kreavana'
                : (_isTalentAndPerformer
                    ? 'Alur Aktivitas Talent & Performer di Kreavana'
                    : (_isCreator ? 'Alur Pertumbuhan Kreator' : 'Alur Kerja Klien')),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _isVendorOrMitra
                ? 'Dari pendaftaran hingga membangun reputasi jangka panjang (#KolaborasiMembangunDampak)'
                : (_isTalentAndPerformer
                    ? 'Mudah, Terarah, dan Penuh Peluang (#KolaborasiMembawaDampak)'
                    : '6 langkah menuju kolaborasi sukses di Kreavana'),
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
            ),
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: steps.asMap().entries.map((e) {
                final step = e.value;
                final isLast = e.key == steps.length - 1;
                final color = step['color'] as Color;
                return Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Column(
                        children: [
                          HoverLiftButton(
                            glowColor: color,
                            scale: 1.08,
                            translateY: -2.5,
                            borderRadius: BorderRadius.circular(44),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: color.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.18),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: (step['image_url'] ?? '').toString(),
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => Container(
                                    color: color.withValues(alpha: 0.15),
                                    child: Center(
                                      child: SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, _, _) => Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          color.withValues(alpha: 0.2),
                                          color.withValues(alpha: 0.05),
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        (step['icon'] as IconData?) ??
                                            Icons.image_outlined,
                                        color: color,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${step['n']}. ${step['title']}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            step['sub'].toString(),
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark
                                  ? AppTheme.textMuted
                                  : AppTheme.textMutedLight,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                        size: 20,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Right sidebar ────────────────────────────────────────────────────────────
  Widget _buildRightSidebar(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProfileCard(isDark),
        const SizedBox(height: 14),
        _buildQuickActionsCard(isDark),
        const SizedBox(height: 14),
        _buildAiTipsCard(isDark),
        const SizedBox(height: 14),
        _buildEscrowTrustCard(isDark),
        const SizedBox(height: 14),
        _buildSavedCreatorsCard(isDark),
        const SizedBox(height: 14),
        _buildRecentProjectActivityCard(isDark),
        const SizedBox(height: 14),
        _buildClientHelpHubCard(isDark),
      ],
    );
  }

  Widget _buildProfileCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
        ),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
                backgroundImage: widget.user.avatarUrl?.isNotEmpty == true
                    ? CachedNetworkImageProvider(
                        ApiService.resolveAssetUrl(widget.user.avatarUrl!),
                      )
                    : null,
                child: widget.user.avatarUrl?.isNotEmpty != true
                    ? Icon(
                        Icons.person,
                        color: AppTheme.primaryPurple,
                        size: 26,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.user.isGuest
                          ? 'Mode Tamu'
                          : (widget.user.subRole ??
                              (_isCreator ? 'Content Creator' : 'Klien')),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.textMuted
                            : AppTheme.textMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  if (widget.user.isGuest) {
                    AuthGuardDialog.show(
                      context,
                      actionName: 'mengakses profil akun',
                    );
                    return;
                  }
                  _navigateTo('Lihat Profil');
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  widget.user.isGuest ? 'Masuk' : 'Profil',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          if (widget.user.isGuest) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 15,
                        color: AppTheme.primaryPurple,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Akses Tamu Terbatas',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Masuk atau daftar akun untuk membuka profil lengkap, verifikasi identitas, dan transaksi proyek.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go(AppRoutes.login),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Masuk Sekarang',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go(AppRoutes.register),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  side: BorderSide(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                  ),
                  foregroundColor: AppTheme.primaryPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Daftar Baru',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Builder(
              builder: (context) {
                final completeness = ProfileCompleteness.calculate(widget.user);
                final accentColor = SubRoleThemeEngine.getAccentColorForUser(widget.user);
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () => ProfileCompleteness.showChecklistModal(
                        context,
                        widget.user,
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: completeness.percentage / 100.0,
                              minHeight: 6,
                              backgroundColor: isDark
                                  ? AppTheme.inputBorder
                                  : AppTheme.dividerLight,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Kelengkapan profil',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? AppTheme.textMuted
                                      : AppTheme.textMutedLight,
                                ),
                              ),
                              Text(
                                '${completeness.percentage}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: HoverLiftButton(
                        glowColor: accentColor,
                        scale: 1.025,
                        translateY: -2.0,
                        onTap: () => ProfileCompleteness.showChecklistModal(
                          context,
                          widget.user,
                        ),
                        child: OutlinedButton(
                          onPressed: () => ProfileCompleteness.showChecklistModal(
                            context,
                            widget.user,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            side: BorderSide(
                              color: accentColor.withValues(alpha: 0.4),
                            ),
                            foregroundColor: accentColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Lengkapi Profil',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(bool isDark) {
    final config = _getRoleConfig();
    final actions = config.quickActions;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
        ),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aksi Cepat',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return _QuickActionItemCard(
                action: action,
                isDark: isDark,
                onTap: () => _navigateTo(action['label'] as String),
                accentColor: AppTheme.primaryPurple,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAiTipsCard(bool isDark) {
    final config = _getRoleConfig();
    final tips = config.aiTips;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B38), const Color(0xFF13111F)]
              : [const Color(0xFFF5F3FF), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/brandlogo.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              const Text(
                'Tips dari AI',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryPurple,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: isDark
                            ? AppTheme.textMuted
                            : AppTheme.textMutedLight,
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

  Widget _buildEscrowTrustCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
        ),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: Color(0xFF10B981),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Proteksi Transaksi & Escrow',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF132B22) : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.shield_rounded,
                  color: Color(0xFF10B981),
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dana Anda 100% aman dalam escrow bersama Kreavana.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF059669),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildTrustPoint(
            icon: Icons.check_circle_outline,
            text: 'Pembayaran hanya dicairkan setelah Anda menyetujui hasil karya',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildTrustPoint(
            icon: Icons.refresh_rounded,
            text: 'Garansi revisi terjamin sesuai kesepakatan brief',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildTrustPoint(
            icon: Icons.copyright_outlined,
            text: 'Hak cipta karya 100% menjadi milik klien setelah lunas',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTrustPoint({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF10B981)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedCreatorsCard(bool isDark) {
    final isUpgraded = widget.user.subscriptionTier.toLowerCase() != 'free';
    if (!isUpgraded) {
      return _buildUpgradeForRecommendationsCard(isDark);
    }

    final topCreators = [
      {
        'name': 'Dimas Arya',
        'role': 'Videographer & FPV',
        'rating': '5.0 (24)',
        'avatar': 'videocam',
      },
      {
        'name': 'Kevin Jonathan',
        'role': 'Photographer & Editor',
        'rating': '5.0 (18)',
        'avatar': 'camera',
      },
      {
        'name': 'Andi Editor Pro',
        'role': 'Motion & 3D Editor',
        'rating': '4.9 (31)',
        'avatar': 'palette',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
        ),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
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
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: AppTheme.primaryPurple,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Kreator Rekomendasi',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _navigateTo('Lihat Semua Top Kreator'),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Lihat Semua',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...topCreators.map((c) {
            IconData icon = Icons.person;
            if (c['avatar'] == 'videocam') icon = Icons.videocam_rounded;
            if (c['avatar'] == 'camera') icon = Icons.camera_alt_rounded;
            if (c['avatar'] == 'palette') icon = Icons.palette_rounded;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.inputDark : AppTheme.inputLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.15),
                    child: Icon(icon, color: AppTheme.primaryPurple, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['name']!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          c['role']!,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 12),
                            const SizedBox(width: 3),
                            Text(
                              c['rating']!,
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => _navigateTo('Pesan'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Chat',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
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

  Widget _buildUpgradeForRecommendationsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF261845), const Color(0xFF19122B)]
              : [const Color(0xFFF3E8FF), const Color(0xFFFAF5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: AppTheme.primaryPurple.withValues(alpha: 0.35),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/brandlogo.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Rekomendasi Kreator AI',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'UPGRADE PLAN',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Dapatkan akses rekomendasi kreator terkurasi berbasis AI, kuota proyek lebih tinggi, dan prioritas penawaran dengan meng-upgrade paket Anda.',
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => UpgradePlanModal.show(context, user: widget.user),
              icon: const Icon(Icons.workspace_premium_outlined, size: 15),
              label: const Text(
                'Upgrade Plan Sekarang',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentProjectActivityCard(bool isDark) {
    final activities = _activityFeed.isNotEmpty
        ? _activityFeed.map((e) {
            IconData iconData = Icons.notifications_none;
            Color iconColor = const Color(0xFF3B82F6);
            if (e['type'] == 'contract') {
              iconData = Icons.assignment_turned_in_outlined;
              iconColor = const Color(0xFF10B981);
            } else if (e['type'] == 'payment') {
              iconData = Icons.account_balance_wallet_outlined;
              iconColor = const Color(0xFF8B5CF6);
            } else if (e['type'] == 'opportunity') {
              iconData = Icons.mail_outline_rounded;
            }

            return {
              'title': e['title']?.toString() ?? 'Pemberitahuan Baru',
              'desc': e['message']?.toString() ?? e['desc']?.toString() ?? '',
              'time': e['time']?.toString() ?? 'Baru saja',
              'icon': iconData,
              'color': iconColor,
            };
          }).toList()
        : [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
        ),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Color(0xFF3B82F6),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Aktivitas Proyek Terbaru',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (activities.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Belum ada aktivitas proyek.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                  ),
                ),
              ),
            )
          else
            ...activities.map((a) {
            final color = a['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(a['icon'] as IconData, size: 12, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a['title'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a['desc'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a['time'] as String,
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark ? AppTheme.textMuted.withValues(alpha: 0.7) : AppTheme.textMutedLight,
                          ),
                        ),
                      ],
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

  Widget _buildClientHelpHubCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1C2B), const Color(0xFF171523)]
              : [const Color(0xFFF8FAFC), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
        ),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Pusat Bantuan & Panduan',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Butuh bantuan menentukan kreator atau membuat brief proyek yang detail?',
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.aiAssistant),
              icon: const Icon(Icons.auto_awesome, size: 14),
              label: const Text('Konsultasi AI Kreavana', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      toolbarHeight: 70,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // Search bar interaktif dengan hover glow & scale
          Expanded(
            child: InteractiveDashboardSearchBar(
              user: widget.user,
              isDark: isDark,
              accentColor: AppTheme.primaryPurple,
              placeholder: _getSearchHint(),
            ),
          ),
          const SizedBox(width: 12),
          if (!widget.user.isGuest) ...[
            AppBarBadgeWidget(
              icon: Icons.notifications_none_outlined,
              isDark: isDark,
              accentColor: AppTheme.primaryPurple,
              onTap: () => _navigateTo('Notifikasi'),
              tooltipMessage: 'Notifikasi',
            ),
            const SizedBox(width: 6),
            AppBarBadgeWidget(
              icon: Icons.chat_bubble_outline,
              isDark: isDark,
              accentColor: AppTheme.primaryPurple,
              onTap: () => _navigateTo('Pesan'),
              tooltipMessage: 'Pesan & Diskusi',
            ),
            const SizedBox(width: 8),
          ],
          // Theme toggle interaktif dengan rotasi & glow
          AppBarThemeToggle(
            isDark: isDark,
            btnKey: _themeBtnKey,
            accentColor: AppTheme.primaryPurple,
          ),
          if (widget.user.isGuest) ...[
            const SizedBox(width: 10),
            AppBarGuestActions(
              isDark: isDark,
              accentColor: AppTheme.primaryPurple,
              onLogin: () => context.go(AppRoutes.login),
              onRegister: () => context.go(AppRoutes.register),
            ),
          ] else ...[
            const SizedBox(width: 8),
            // Profile Badge interaktif dengan capsule glow & chevron animation
            AppBarProfileBadge(
              user: widget.user,
              isDark: isDark,
              accentColor: AppTheme.primaryPurple,
              customSubRole: widget.user.subRole ?? (_isCreator ? 'Creator' : 'Klien'),
              onTap: () => _navigateTo('Lihat Profil'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 1100;
    final sidebarWidth = screenWidth > 1400 ? 330.0 : (screenWidth > 1200 ? 310.0 : 290.0);

    return Scaffold(
      appBar: _buildAppBar(isDark),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RepaintBoundary(child: _buildHeroBanner(isDark)),
                          const SizedBox(height: 20),
                          RepaintBoundary(child: _buildMetricCards(isDark)),
                          const SizedBox(height: 24),
                          RepaintBoundary(child: _buildRecommendationSection(isDark)),
                          const SizedBox(height: 24),
                          RepaintBoundary(child: _buildThreeColumnSection(isDark)),
                          const SizedBox(height: 24),
                          if (_isTalentAndPerformer) ...[
                            RepaintBoundary(child: _buildTalentEcosystemSection(isDark)),
                            const SizedBox(height: 24),
                          ],
                          if (_isVendorOrMitra) ...[
                            RepaintBoundary(child: _buildVendorEcosystemSection(isDark)),
                            const SizedBox(height: 24),
                          ],
                          RepaintBoundary(child: _buildWorkflowSection(isDark)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(width: sidebarWidth, child: RepaintBoundary(child: _buildRightSidebar(isDark))),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RepaintBoundary(child: _buildHeroBanner(isDark)),
                    const SizedBox(height: 20),
                    RepaintBoundary(child: _buildMetricCards(isDark)),
                    const SizedBox(height: 24),
                    RepaintBoundary(child: _buildRecommendationSection(isDark)),
                    const SizedBox(height: 24),
                    RepaintBoundary(child: _buildThreeColumnSection(isDark)),
                    const SizedBox(height: 24),
                    if (_isTalentAndPerformer) ...[
                      RepaintBoundary(child: _buildTalentEcosystemSection(isDark)),
                      const SizedBox(height: 24),
                    ],
                    if (_isVendorOrMitra) ...[
                      RepaintBoundary(child: _buildVendorEcosystemSection(isDark)),
                      const SizedBox(height: 24),
                    ],
                    RepaintBoundary(child: _buildWorkflowSection(isDark)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HeroBannerBackgroundCarousel extends StatefulWidget {
  final List<String> images;
  final Widget child;

  static const Duration switchDuration = Duration(seconds: 5);
  static const Duration fadeDuration = Duration(milliseconds: 1200);

  const _HeroBannerBackgroundCarousel({
    required this.images,
    required this.child,
  });

  @override
  State<_HeroBannerBackgroundCarousel> createState() =>
      _HeroBannerBackgroundCarouselState();
}

class _HeroBannerBackgroundCarouselState
    extends State<_HeroBannerBackgroundCarousel> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.images.length > 1) {
      _timer = Timer.periodic(_HeroBannerBackgroundCarousel.switchDuration, (timer) {
        if (!mounted) return;
        setState(() {
          _currentIndex = (_currentIndex + 1) % widget.images.length;
        });
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final url in widget.images) {
      precacheImage(NetworkImage(url), context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUrl = widget.images[_currentIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 650;
        final imageWidth = isCompact ? constraints.maxWidth * 0.72 : (constraints.maxWidth * 0.58).clamp(380.0, 750.0);

        return Stack(
          children: [
            // ── Layer 1: Smooth Cross-fade Image Background (Anchored Right) ──
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: imageWidth,
              child: AnimatedSwitcher(
                duration: _HeroBannerBackgroundCarousel.fadeDuration,
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ...previousChildren,
                      ?currentChild,
                    ],
                  );
                },
                child: Image.network(
                  currentUrl,
                  key: ValueKey<String>(currentUrl),
                  fit: BoxFit.cover,
                  alignment: const Alignment(0.15, -0.22),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(color: const Color(0xFF07060D));
                  },
                  errorBuilder: (_, _, _) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF07060D), Color(0xFF1E1B38)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Layer 2: Seamless Horizontal Dark Gradient (Black Left, Photo Clear Right) ──
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFF07060E),
                      const Color(0xFF07060E),
                      const Color(0xFF07060E).withValues(alpha: 0.94),
                      const Color(0xFF07060E).withValues(alpha: 0.55),
                      const Color(0xFF07060E).withValues(alpha: 0.12),
                      Colors.transparent,
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.35, 0.48, 0.62, 0.74, 0.84, 1.0],
                  ),
                ),
              ),
            ),

            // ── Layer 3: Kreavana Ambient Purple/Pink Brand Glow ──
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.85, -0.5),
                    radius: 1.15,
                    colors: [
                      AppTheme.primaryPurple.withValues(alpha: 0.28),
                      AppTheme.accentPink.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // ── Layer 4: Foreground Content ──
            widget.child,

        // ── Layer 5: Subtle Slide Indicator Dots ──
        if (widget.images.length > 1)
          Positioned(
            bottom: 14,
            right: 20,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.images.length, (idx) {
                final isActive = idx == _currentIndex;
                return GestureDetector(
                  onTap: () {
                    setState(() => _currentIndex = idx);
                    _startTimer();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 20 : 6,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
      },
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────
class _HeroButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final LinearGradient? gradient;
  final bool outlined;
  final bool isDark;

  const _HeroButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.gradient,
    this.outlined = false,
    this.isDark = false,
  });

  @override
  State<_HeroButton> createState() => _HeroButtonState();
}

class _HeroButtonState extends State<_HeroButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.outlined) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() {
          _isHovered = false;
          _isPressed = false;
        }),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isPressed ? 0.96 : (_isHovered ? 1.03 : 1.0),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(
                0,
                _isPressed ? 0.5 : (_isHovered ? -2.0 : 0.0),
                0,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? (_isHovered
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.12))
                    : (_isHovered
                        ? AppTheme.primaryPurple.withValues(alpha: 0.10)
                        : Colors.white.withValues(alpha: 0.85)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isHovered
                      ? (widget.isDark
                          ? Colors.white.withValues(alpha: 0.70)
                          : AppTheme.primaryPurple)
                      : (widget.isDark
                          ? Colors.white.withValues(alpha: 0.35)
                          : AppTheme.inputBorderLight),
                  width: _isHovered ? 1.5 : 1.0,
                ),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: (widget.isDark
                                  ? Colors.white
                                  : AppTheme.primaryPurple)
                              .withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: 16,
                    color: widget.isDark
                        ? Colors.white
                        : (_isHovered
                            ? AppTheme.primaryPurple
                            : AppTheme.textDark),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark
                              ? Colors.white
                              : (_isHovered
                                  ? AppTheme.primaryPurple
                                  : AppTheme.textDark),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : (_isHovered ? 1.03 : 1.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              0,
              _isPressed ? 0.5 : (_isHovered ? -2.0 : 0.0),
              0,
            ),
            decoration: BoxDecoration(
              gradient: widget.gradient ?? AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPurple.withValues(
                    alpha: _isHovered ? 0.55 : 0.35,
                  ),
                  blurRadius: _isHovered ? 20 : 12,
                  spreadRadius: _isHovered ? 1 : 0,
                  offset: Offset(0, _isHovered ? 6 : 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatefulWidget {
  final String label, value, trend;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
    required this.isDark,
    this.onTap,
  });

  @override
  State<_MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<_MetricCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              0,
              _isHovered ? -3.0 : 0.0,
              0,
            ),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? (_isHovered ? const Color(0xFF1B172E) : AppTheme.cardDark)
                  : (_isHovered ? const Color(0xFFFCFCFF) : Colors.white),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(
                color: _isHovered
                    ? widget.color.withValues(alpha: widget.isDark ? 0.65 : 0.45)
                    : (widget.isDark
                        ? AppTheme.inputBorder
                        : AppTheme.inputBorderLight),
                width: _isHovered ? 1.4 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? widget.color.withValues(alpha: widget.isDark ? 0.30 : 0.16)
                      : (widget.isDark
                          ? Colors.black.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.04)),
                  blurRadius: _isHovered ? 20 : 8,
                  spreadRadius: _isHovered ? 1 : 0,
                  offset: Offset(0, _isHovered ? 8 : 2),
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
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.isDark
                              ? AppTheme.textMuted
                              : AppTheme.textMutedLight,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: _isHovered ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _isHovered
                            ? [
                                BoxShadow(
                                  color: widget.color.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(widget.icon, color: widget.color, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.trend,
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.color,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: _isHovered
                          ? widget.color
                          : (widget.isDark ? Colors.white30 : Colors.grey.shade400),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionItemCard extends StatefulWidget {
  final Map<String, dynamic> action;
  final bool isDark;
  final VoidCallback onTap;
  final Color? accentColor;

  const _QuickActionItemCard({
    required this.action,
    required this.isDark,
    required this.onTap,
    this.accentColor,
  });

  @override
  State<_QuickActionItemCard> createState() => _QuickActionItemCardState();
}

class _QuickActionItemCardState extends State<_QuickActionItemCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppTheme.primaryPurple;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : (_isHovered ? 1.04 : 1.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              0,
              _isPressed ? 0.5 : (_isHovered ? -2.5 : 0.0),
              0,
            ),
            decoration: BoxDecoration(
              color: accent.withValues(
                alpha: widget.isDark
                    ? (_isHovered ? 0.22 : 0.10)
                    : (_isHovered ? 0.14 : 0.06),
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accent.withValues(
                  alpha: widget.isDark
                      ? (_isHovered ? 0.60 : 0.20)
                      : (_isHovered ? 0.45 : 0.10),
                ),
                width: _isHovered ? 1.4 : 1.0,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: widget.isDark ? 0.35 : 0.20),
                        blurRadius: 12,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: _isHovered ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    (widget.action['icon'] as IconData?) ?? Icons.image_outlined,
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    widget.action['label'] as String,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: _isHovered ? FontWeight.bold : FontWeight.w600,
                      color: widget.isDark ? Colors.white : AppTheme.textDark,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;
  final String viewAllLabel;

  const _SectionHeader({
    required this.title,
    this.onViewAll,
    this.viewAllLabel = 'Lihat Semua',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                viewAllLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryPurple,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;
  final String viewAllLabel;
  final bool isDark;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.onViewAll,
    this.viewAllLabel = 'Lihat Semua',
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
        ),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: title,
            onViewAll: onViewAll,
            viewAllLabel: viewAllLabel,
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DashboardCardEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badgeLabel;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isDark;

  const _DashboardCardEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badgeLabel,
    this.actionLabel,
    this.onAction,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const accent = AppTheme.primaryPurple;
    return SizedBox(
      height: 270,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Cool Illustrated Graphic with Kreavana Logo & Themed Emblem ──
              SizedBox(
                width: 86,
                height: 86,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Ambient colored glow
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: isDark ? 0.35 : 0.20),
                            blurRadius: 26,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: AppTheme.accentPink.withValues(alpha: isDark ? 0.25 : 0.15),
                            blurRadius: 20,
                            offset: const Offset(6, -4),
                          ),
                        ],
                      ),
                    ),
                    // Outer concentric glass ring
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: isDark ? 0.28 : 0.20),
                          width: 1.2,
                        ),
                        gradient: RadialGradient(
                          colors: [
                            accent.withValues(alpha: isDark ? 0.15 : 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    // Main glassmorphic circle with Kreavana Brand Logo
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF1E1B38) : Colors.white,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: isDark ? 0.22 : 0.8),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(11),
                      child: Image.asset(
                        'assets/brandlogo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    // Floating category icon badge in the corner
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accent, AppTheme.accentPink],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E1B38) : Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.45),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            icon,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Floating mini sparkle on top-left
                    Positioned(
                      left: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentPink.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 11,
                          color: AppTheme.accentPink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Category Tag Pill ──
              if (badgeLabel != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.16 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accent.withValues(alpha: isDark ? 0.30 : 0.20),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    badgeLabel!,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: isDark ? AppTheme.accentPink : AppTheme.primaryPurple,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],

              // ── Title ──
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),

              // ── Subtitle (Fixed height for 100% horizontal alignment) ──
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: SizedBox(
                  height: 34,
                  child: Center(
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.40,
                        color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Action CTA Button (Makes it feel interactive and not sepi) ──
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onAction,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: isDark ? 0.24 : 0.12),
                          AppTheme.accentPink.withValues(alpha: isDark ? 0.18 : 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accent.withValues(alpha: isDark ? 0.45 : 0.28),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_circle_outline_rounded,
                          size: 13,
                          color: isDark ? Colors.white : AppTheme.primaryPurple,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          actionLabel!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppTheme.primaryPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  }
}

class _InteractiveDashboardItemCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isDark;
  final String? tooltip;

  const _InteractiveDashboardItemCard({
    required this.child,
    required this.onTap,
    required this.isDark,
    this.tooltip,
  });

  @override
  State<_InteractiveDashboardItemCard> createState() => _InteractiveDashboardItemCardState();
}

class _InteractiveDashboardItemCardState extends State<_InteractiveDashboardItemCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? AppTheme.inputDark : AppTheme.inputLight;
    final hoverBgColor = widget.isDark
        ? const Color(0xFF231F36)
        : const Color(0xFFF3F0FA);
    final borderColor = _isHovered
        ? AppTheme.primaryPurple.withValues(alpha: 0.45)
        : Colors.transparent;

    Widget card = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _isHovered ? hoverBgColor : bgColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        child: card,
      );
    }
    return card;
  }
}

