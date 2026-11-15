import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../models/opportunity_model.dart';
import '../services/opportunity_service.dart';
import '../services/user_store.dart';
import '../services/app_router.dart';
import '../widgets/app_breadcrumbs.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../widgets/program_magang_card.dart';
import '../widgets/app_sweet_alert.dart';
import '../utils/currency_formatter.dart';
import 'corporate_vacancy_detail_screen.dart';

class CorporateApplicant {
  final String name;
  final String institution;
  final String role;
  final String appliedDate;
  final String status; // 'Menunggu Review', 'Interview', 'Diterima', 'Ditolak'
  final String portfolioUrl;
  final String note;
  final bool isReplacement;
  final String? replacedApplicantName;

  const CorporateApplicant({
    required this.name,
    required this.institution,
    required this.role,
    required this.appliedDate,
    required this.status,
    this.portfolioUrl = 'https://kreavana.id/portfolio',
    this.note = '',
    this.isReplacement = false,
    this.replacedApplicantName,
  });

  CorporateApplicant copyWith({
    String? name,
    String? institution,
    String? role,
    String? appliedDate,
    String? status,
    String? portfolioUrl,
    String? note,
    bool? isReplacement,
    String? replacedApplicantName,
  }) {
    return CorporateApplicant(
      name: name ?? this.name,
      institution: institution ?? this.institution,
      role: role ?? this.role,
      appliedDate: appliedDate ?? this.appliedDate,
      status: status ?? this.status,
      portfolioUrl: portfolioUrl ?? this.portfolioUrl,
      note: note ?? this.note,
      isReplacement: isReplacement ?? this.isReplacement,
      replacedApplicantName: replacedApplicantName ?? this.replacedApplicantName,
    );
  }
}

class CorporateVacancyItem {
  final String id;
  final String title;
  final String description;
  final String category; // 'magang' or 'job'
  final String categoryLabel; // 'Magang' or 'Lowongan Kerja'
  final Color? categoryBadgeColor;
  final Color? categoryBadgeBg;
  final String status; // 'open', 'in_progress', 'closed'
  final String statusLabel; // 'Pendaftaran Dibuka', 'Sedang Berjalan', 'Ditutup'
  final Color statusBadgeColor;
  final Color statusBadgeBg;
  final String registrationPeriod;
  final String quotaText;
  final String allowance;
  final List<String> requirements;
  final int applicantsCount;
  final List<CorporateApplicant> applicants;
  final OpportunityModel? opportunity;

  CorporateVacancyItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.categoryLabel,
    this.categoryBadgeColor,
    this.categoryBadgeBg,
    required this.status,
    required this.statusLabel,
    required this.statusBadgeColor,
    required this.statusBadgeBg,
    required this.registrationPeriod,
    required this.quotaText,
    required this.allowance,
    required this.requirements,
    required this.applicantsCount,
    this.applicants = const [],
    this.opportunity,
  });

  factory CorporateVacancyItem.fromOpportunity(OpportunityModel opp) {
    final statusLower = opp.status.toLowerCase();
    final isOpen = statusLower == 'open';
    final isOngoing = statusLower == 'in_progress' || statusLower == 'active';
    final isClosed = statusLower == 'closed' || statusLower == 'completed';

    final isMagang = opp.isMagang;

    final statusText = isOpen
        ? 'Pendaftaran Dibuka'
        : (isOngoing
            ? 'Sedang Berjalan'
            : (isClosed ? 'Pendaftaran Ditutup' : 'Dalam Seleksi'));

    final statusColor = isOpen
        ? const Color(0xFF16A34A)
        : (isOngoing
            ? const Color(0xFF2563EB)
            : const Color(0xFF64748B));

    final statusBg = isOpen
        ? const Color(0xFFDCFCE7)
        : (isOngoing
            ? const Color(0xFFDBEAFE)
            : const Color(0xFFF1F5F9));

    final categoryColor = isMagang ? const Color(0xFF0284C7) : const Color(0xFF7E22CE);
    final categoryBg = isMagang ? const Color(0xFFE0F2FE) : const Color(0xFFF3E8FF);

    final regPeriod = ProgramMagangCard.formatDateDisplay(
      opp.deadline ?? opp.createdAt,
      defaultFallback: '21 Sep 2026',
    );

    // Calculate quota and specifications from requirements (strictly position specializations)
    int totalQuota = 0;
    final specBreakdowns = <String>[];
    final reqList = <String>[];

    for (final r in opp.requirements) {
      final sub = r.subRoleSlug.trim().toLowerCase();
      final notes = (r.notes ?? '').trim();

      if (sub == 'kualifikasi' || sub == 'qualification' || sub == 'syarat') {
        if (notes.isNotEmpty) {
          reqList.add(notes);
        }
        continue;
      }

      if (notes.isNotEmpty &&
          !notes.toLowerCase().startsWith('spesialisasi') &&
          (notes.startsWith('Memiliki') ||
           notes.startsWith('Mampu') ||
           notes.startsWith('Siswa') ||
           notes.startsWith('Mahasiswa') ||
           notes.startsWith('Disiplin') ||
           notes.startsWith('Menguasai') ||
           notes.startsWith('Siap'))) {
        reqList.add(notes);
        continue;
      }

      int q = r.quantity;
      if (q <= 0 && notes.isNotEmpty) {
        final match = RegExp(r'\((\d+)\s+kuota\)').firstMatch(notes);
        if (match != null) {
          q = int.tryParse(match.group(1) ?? '0') ?? 0;
        }
      }

      if (q > 0) {
        totalQuota += q;
        final roleName = notes.isNotEmpty
            ? notes.split('(').first.replaceFirst('Spesialisasi ', '').trim()
            : r.subRoleSlug.replaceAll('_', ' ');
        specBreakdowns.add('$roleName: $q');
      }
    }

    if (totalQuota <= 0) {
      for (final r in opp.requirements) {
        final notes = r.notes ?? '';
        final match = RegExp(r'\((\d+)\s+kuota\)').firstMatch(notes);
        if (match != null) {
          totalQuota += int.tryParse(match.group(1) ?? '0') ?? 0;
        }
      }
    }
    final String calculatedQuotaText;
    if (totalQuota > 0) {
      final int filled = opp.approvedCreators.length;
      final int remaining = (totalQuota - filled).clamp(0, totalQuota);
      calculatedQuotaText = '$remaining dari $totalQuota posisi';
    } else {
      calculatedQuotaText = 'Terbuka';
    }

    return CorporateVacancyItem(
      id: opp.id ?? 'opp_${DateTime.now().millisecondsSinceEpoch}',
      title: opp.title,
      description: opp.description ?? 'Lowongan kebutuhan terbuka oleh perusahaan mitra industri.',
      category: isMagang ? 'magang' : 'job',
      categoryLabel: isMagang ? 'Magang' : 'Lowongan Kerja',
      categoryBadgeColor: categoryColor,
      categoryBadgeBg: categoryBg,
      status: opp.status,
      statusLabel: statusText,
      statusBadgeColor: statusColor,
      statusBadgeBg: statusBg,
      registrationPeriod: regPeriod,
      quotaText: calculatedQuotaText,
      allowance: opp.budgetRange ?? (isMagang ? 'Rp 3.500.000 / bulan' : 'Budget Fleksibel'),
      requirements: reqList,
      applicantsCount: opp.applicationsCount,
      opportunity: opp,
      applicants: const [],
    );
  }
}

class CorporateLowonganScreen extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const CorporateLowonganScreen({
    super.key,
    this.user,
    this.onUserUpdated,
  });

  @override
  State<CorporateLowonganScreen> createState() => _CorporateLowonganScreenState();
}

class _CorporateLowonganScreenState extends State<CorporateLowonganScreen> {
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedFilter = 'Semua';
  final TextEditingController _searchController = TextEditingController();

  List<CorporateVacancyItem> _fetchedItems = [];

  UserModel? get _currentUser => widget.user ?? currentUserNotifier.value;

  // Preset Corporate Vacancies
  List<CorporateVacancyItem> get _presetVacancies => [
        CorporateVacancyItem(
          id: 'corp_magang_1',
          title: 'Program Magang MBKM 3D Modeler Batch I 2026',
          description:
              'Kerja sama penempatan 10 siswa vokasi magang pada produksi serial animasi nusantara berstandar industri internasional.',
          category: 'magang',
          categoryLabel: 'Magang',
          status: 'open',
          statusLabel: 'Pendaftaran Dibuka',
          statusBadgeColor: const Color(0xFF16A34A),
          statusBadgeBg: const Color(0xFFDCFCE7),
          registrationPeriod: '21 Sep 2026',
          quotaText: '4 dari 10 posisi',
          allowance: 'Rp 3.500.000 / bulan',
          requirements: const [
            'Siswa SMK jurusan terkait',
            'Menguasai dasar 3D Modeling',
            'Memiliki portofolio karya',
          ],
          applicantsCount: 6,
          applicants: const [
            CorporateApplicant(
              name: 'Dimas Aditya',
              institution: 'SMKN 4 Bandung - Animasi',
              role: 'Junior 3D Modeler',
              appliedDate: '10 Feb 2026',
              status: 'Interview',
              note: 'Showreel modeling hard-surface sangat rapi.',
            ),
            CorporateApplicant(
              name: 'Siti Nurhaliza',
              institution: 'Politeknik Negeri Media Kreatif',
              role: '3D Texture & Lookdev',
              appliedDate: '11 Feb 2026',
              status: 'Menunggu Review',
              note: 'Mahir Substance Painter & Blender.',
            ),
            CorporateApplicant(
              name: 'Reza Pratama',
              institution: 'SMKN 1 Surabaya - Multimedia',
              role: '3D Environment Artist',
              appliedDate: '12 Feb 2026',
              status: 'Diterima',
              note: 'Telah menandatangani MoU penempatan magang.',
            ),
          ],
        ),
        CorporateVacancyItem(
          id: 'corp_magang_2',
          title: 'UI/UX & Design System Enterprise Intern',
          description:
              'Peluang magang intensif perancangan komponen modular desain sistem B2B enterprise, user journey research, dan prototipe aplikasi.',
          category: 'magang',
          categoryLabel: 'Magang',
          status: 'open',
          statusLabel: 'Pendaftaran Dibuka',
          statusBadgeColor: const Color(0xFF16A34A),
          statusBadgeBg: const Color(0xFFDCFCE7),
          registrationPeriod: '15 Okt 2026',
          quotaText: '2 dari 5 posisi',
          allowance: 'Rp 2.800.000 / bulan',
          requirements: const [
            'Mahasiswa D3/S1 DKV atau Sistem Informasi',
            'Menguasai Figma & Auto-layout modern',
            'Memahami dasar Human Interface Guidelines',
          ],
          applicantsCount: 9,
          applicants: const [
            CorporateApplicant(
              name: 'Fauzan Hakim',
              institution: 'Institut Teknologi Bandung - DKV',
              role: 'UI Designer Intern',
              appliedDate: '01 Mar 2026',
              status: 'Interview',
            ),
            CorporateApplicant(
              name: 'Alya Putri',
              institution: 'Universitas Indonesia - Fasilkom',
              role: 'UX Researcher Intern',
              appliedDate: '03 Mar 2026',
              status: 'Menunggu Review',
            ),
          ],
        ),
        CorporateVacancyItem(
          id: 'corp_magang_3',
          title: '2D Animator & Motion Graphic Production Intern',
          description:
              'Magang kerja sama vokasi industri kreatif untuk pembuatan aset visual grafis gerak, storyboard TVC, dan promosi digital.',
          category: 'magang',
          categoryLabel: 'Magang',
          status: 'in_progress',
          statusLabel: 'Sedang Berjalan',
          statusBadgeColor: const Color(0xFF2563EB),
          statusBadgeBg: const Color(0xFFDBEAFE),
          registrationPeriod: '10 Ags 2026',
          quotaText: '5 dari 5 posisi',
          allowance: 'Rp 3.000.000 / bulan',
          requirements: const [
            'Siswa/Mahasiswa SMK/Vokasi Animasi',
            'Mahir Adobe After Effects & Illustrator',
            'Disiplin deadline dan komunikasi tim yang baik',
          ],
          applicantsCount: 5,
        ),
        CorporateVacancyItem(
          id: 'corp_job_1',
          title: 'Senior Creative Director & Brand Strategist',
          description:
              'Memimpin perancangan kampanye visual korporat enterprise, pengawasan standar branding B2B, dan supervisi tim kreatif internal.',
          category: 'job',
          categoryLabel: 'Lowongan Kerja',
          categoryBadgeColor: const Color(0xFF7E22CE),
          categoryBadgeBg: const Color(0xFFF3E8FF),
          status: 'open',
          statusLabel: 'Pendaftaran Dibuka',
          statusBadgeColor: const Color(0xFF16A34A),
          statusBadgeBg: const Color(0xFFDCFCE7),
          registrationPeriod: '30 Nov 2026',
          quotaText: '1 dari 1 posisi',
          allowance: 'Rp 18.000.000 - 25.000.000 / bulan',
          requirements: const [
            'Minimal 4 tahun pengalaman di Creative Agency / Corporate',
            'Portofolio kampanye brand terbukti di industri',
            'Kepemimpinan tim kreatif & komunikasi B2B',
          ],
          applicantsCount: 4,
          applicants: const [
            CorporateApplicant(
              name: 'Baskara Mahendra',
              institution: 'Senior Art Director Ex-Ogilvy',
              role: 'Creative Director',
              appliedDate: '15 Feb 2026',
              status: 'Interview',
            ),
          ],
        ),
        CorporateVacancyItem(
          id: 'corp_job_2',
          title: 'Lead Commercial Audio Producer & Sound Designer',
          description:
              'Pengadaan komposer in-house untuk sonic branding perusahaan, scoring video korporasi, sound FX, dan jingle promosi produk.',
          category: 'job',
          categoryLabel: 'Lowongan Kerja',
          categoryBadgeColor: const Color(0xFF7E22CE),
          categoryBadgeBg: const Color(0xFFF3E8FF),
          status: 'in_progress',
          statusLabel: 'Sedang Berjalan',
          statusBadgeColor: const Color(0xFF2563EB),
          statusBadgeBg: const Color(0xFFDBEAFE),
          registrationPeriod: '01 Jul 2026',
          quotaText: '1 dari 1 posisi',
          allowance: 'Rp 12.000.000 - 16.000.000 / bulan',
          requirements: const [
            'Pengalaman komposisi musik komersial & mixing/mastering',
            'Koleksi sample library berlisensi resmi',
            'Siap bekerja hybrid di studio rekaman korporat',
          ],
          applicantsCount: 8,
        ),
      ];

  @override
  void initState() {
    super.initState();
    _fetchVacancies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchVacancies({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final opps = await OpportunityService.getMyOpportunities(forceRefresh: forceRefresh);
      if (mounted) {
        final parsed = <CorporateVacancyItem>[];
        for (final o in opps) {
          try {
            parsed.add(CorporateVacancyItem.fromOpportunity(o));
          } catch (e) {
            debugPrint('Error mapping opportunity ${o.id} to CorporateVacancyItem: $e');
          }
        }
        setState(() {
          _fetchedItems = parsed;
        });
      }
    } catch (e) {
      debugPrint('Error fetching vacancies in CorporateLowonganScreen: $e');
      // Fallback to presets if network is unavailable
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<CorporateVacancyItem> get _allVacancies {
    final Map<String, CorporateVacancyItem> map = {};
    // Add real items created or fetched from server FIRST so user vacancies appear at the top
    for (final item in _fetchedItems) {
      map[item.id] = item;
    }
    // Add preset vacancies if not already overridden
    for (final item in _presetVacancies) {
      map.putIfAbsent(item.id, () => item);
    }
    return map.values.toList();
  }

  List<CorporateVacancyItem> get _filteredVacancies {
    return _allVacancies.where((item) {
      // 1. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = item.title.toLowerCase().contains(q);
        final matchDesc = item.description.toLowerCase().contains(q);
        final matchReq = item.requirements.any((r) => r.toLowerCase().contains(q));
        if (!matchTitle && !matchDesc && !matchReq) return false;
      }

      // 2. Tab Filter
      switch (_selectedFilter) {
        case 'Magang':
        case 'Magang Industri':
          return item.category == 'magang';
        case 'Lowongan Kerja':
        case 'Pekerjaan':
        case 'Pekerjaan Kreatif':
          return item.category == 'job';
        case 'Pendaftaran Dibuka':
          return item.status.toLowerCase() == 'open' || item.statusLabel.contains('Dibuka');
        case 'Sedang Berjalan':
          return item.status.toLowerCase() == 'in_progress' ||
              item.status.toLowerCase() == 'active' ||
              item.statusLabel.contains('Berjalan');
        case 'Semua':
        default:
          return true;
      }
    }).toList();
  }

  // ── Actions ─────────────────────────────────────────────────────────────
  Future<void> _openBuatLowongan() async {
    final newVacancy = await showDialog<CorporateVacancyItem>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CorporateVacancyFormDialog(
        user: _currentUser,
      ),
    );

    if (newVacancy != null && mounted) {
      setState(() {
        _fetchedItems.removeWhere((it) => it.id == newVacancy.id);
        _fetchedItems.insert(0, newVacancy);
      });
      AppSweetAlert.success(
        context,
        'Lowongan "${newVacancy.title}" dengan kuota ${newVacancy.quotaText} berhasil dipublikasikan dan tersimpan di database!',
        title: 'Lowongan Berhasil Dibuka',
      );
      // Synchronize with server to ensure persistent state
      _fetchVacancies(forceRefresh: true);
    }
  }

  void _openDetailLowongan(CorporateVacancyItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(
          name: '${AppRoutes.detailLowonganCorporate}?id=${item.id}',
        ),
        builder: (_) => CorporateVacancyDetailScreen(
          item: item,
          vacancyId: item.id,
          user: _currentUser,
          onUserUpdated: (u) {
            currentUserNotifier.value = u;
            widget.onUserUpdated?.call(u);
            if (mounted) setState(() {});
          },
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  // ── Build Method ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFF2563EB); // Corporate Blue

    final content = Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchVacancies,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24.0 : 16.0,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Breadcrumbs
                const AppBreadcrumbs(
                  items: [
                    BreadcrumbItem(label: 'Beranda', icon: Icons.home_outlined),
                    BreadcrumbItem(label: 'Pengelolaan Perusahaan', icon: Icons.domain_rounded),
                    BreadcrumbItem(
                      label: 'Lowongan Kerja & Magang',
                      icon: Icons.work_outline_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Header
                _buildHeader(isDark, isDesktop, accentColor),
                const SizedBox(height: 20),

                // 3. Stats Row
                _buildStatsRow(isDark, isDesktop),
                const SizedBox(height: 24),

                // 4. Search and Filter Bar
                _buildSearchAndFilter(isDark, isDesktop, accentColor),
                const SizedBox(height: 20),

                // 5. Vacancy Listings
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_filteredVacancies.isEmpty)
                  _buildEmptyState(isDark)
                else
                  _buildVacanciesGrid(_filteredVacancies, isDesktop, isDark),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: (!isDesktop)
          ? FloatingActionButton.extended(
              heroTag: 'corporate_buka_lowongan_fab',
              onPressed: _openBuatLowongan,
              backgroundColor: accentColor,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Buka Lowongan',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );

    final effectiveUser = _currentUser;
    if (isDesktop && effectiveUser != null) {
      return DesktopSidebarLayout(
        user: effectiveUser,
        activeRoute: 'lowongan_magang',
        onUserUpdated: widget.onUserUpdated,
        child: content,
      );
    }

    return content;
  }

  // ── Header Widget ────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark, bool isDesktop, Color accentColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.work_outline_rounded, color: accentColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Lowongan Kerja & Magang',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Kelola program magang industri (PKL/MBKM) dan lowongan pekerjaan kreatif korporat Anda.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        if (isDesktop) ...[
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _openBuatLowongan,
            icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            label: const Text(
              'Buka Lowongan Baru',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ],
    );
  }

  // ── Stats Row ────────────────────────────────────────────────────────────
  Widget _buildStatsRow(bool isDark, bool isDesktop) {
    final all = _allVacancies;
    final total = all.length;
    final openCount = all.where((i) => i.status.toLowerCase() == 'open' || i.statusLabel.contains('Dibuka')).length;
    final totalApplicants = all.fold<int>(0, (sum, i) => sum + i.applicantsCount);
    final runningCount = all.where((i) => i.status.toLowerCase() == 'in_progress' || i.statusLabel.contains('Berjalan')).length;

    final stats = [
      {
        'title': 'Total Lowongan',
        'value': '$total',
        'desc': 'Program & posisi aktif',
        'icon': Icons.work_outline_rounded,
        'color': const Color(0xFF2563EB),
      },
      {
        'title': 'Pendaftaran Dibuka',
        'value': '$openCount',
        'desc': 'Menerima pelamar baru',
        'icon': Icons.campaign_outlined,
        'color': const Color(0xFF16A34A),
      },
      {
        'title': 'Pelamar Terdaftar',
        'value': '$totalApplicants',
        'desc': 'Talenta & siswa vokasi',
        'icon': Icons.people_outline_rounded,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'title': 'Sedang Berjalan',
        'value': '$runningCount',
        'desc': 'Magang & kontrak aktif',
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFFF59E0B),
      },
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 800;
      if (isWide) {
        return Row(
          children: stats.map((s) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildStatCard(s, isDark),
              ),
            );
          }).toList(),
        );
      } else {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: stats.map((s) {
            return SizedBox(
              width: (constraints.maxWidth - 12) / 2,
              child: _buildStatCard(s, isDark),
            );
          }).toList(),
        );
      }
    });
  }

  Widget _buildStatCard(Map<String, dynamic> s, bool isDark) {
    final color = s['color'] as Color;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(s['icon'] as IconData, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s['value'] as String,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s['title'] as String,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  s['desc'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.grey.shade500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Search & Filter ──────────────────────────────────────────────────────
  Widget _buildSearchAndFilter(bool isDark, bool isDesktop, Color accentColor) {
    const filters = [
      'Semua',
      'Magang Industri',
      'Lowongan Kerja',
      'Pendaftaran Dibuka',
      'Sedang Berjalan',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: 'Cari lowongan, posisi magang, atau syarat keahlian...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedFilter = filter),
                  selectedColor: accentColor,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700),
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  side: BorderSide(
                    color: isSelected
                        ? accentColor
                        : (isDark ? Colors.white12 : Colors.grey.shade200),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Vacancies Grid ───────────────────────────────────────────────────────
  Widget _buildVacanciesGrid(
    List<CorporateVacancyItem> items,
    bool isDesktop,
    bool isDark,
  ) {
    return LayoutBuilder(builder: (context, constraints) {
      final isTwoColumn = constraints.maxWidth > 850;
      if (isTwoColumn) {
        final halfWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: items.map((item) {
            return SizedBox(
              width: halfWidth,
              child: _buildVacancyCard(item, isDark),
            );
          }).toList(),
        );
      } else {
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (_, index) => _buildVacancyCard(items[index], isDark),
        );
      }
    });
  }

  Widget _buildVacancyCard(CorporateVacancyItem item, bool isDark) {
    return ProgramMagangCard(
      title: item.title,
      description: item.description,
      categoryBadge: item.categoryLabel,
      categoryBadgeColor: item.categoryBadgeColor,
      categoryBadgeBg: item.categoryBadgeBg,
      statusBadge: item.statusLabel,
      statusBadgeColor: item.statusBadgeColor,
      statusBadgeBg: item.statusBadgeBg,
      registrationPeriod: item.registrationPeriod,
      quotaText: item.quotaText,
      requirements: item.requirements,
      requirementsCountLabel: '${item.requirements.length} Persyaratan',
      buttonLabel: 'Lihat Detail & Pelamar (${item.applicantsCount}) →',
      opportunity: item.opportunity,
      onTap: () => _openDetailLowongan(item),
      onDetailPressed: () => _openDetailLowongan(item),
    );
  }

  // ── Empty State ──────────────────────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.work_off_outlined,
                size: 40,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Tidak Ada Lowongan yang Cocok',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Cobalah mengubah filter pencarian atau buat lowongan baru.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openBuatLowongan,
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text('Buka Lowongan Sekarang', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Corporate Vacancy Form Dialog (Matching Institution Workspace Editor Style)
// ─────────────────────────────────────────────────────────────────────────────

class SpecializationQuotaEntry {
  String roleSlug;
  String roleLabel;
  final TextEditingController quotaController;

  SpecializationQuotaEntry({
    required this.roleSlug,
    required this.roleLabel,
    int initialQuota = 10,
  }) : quotaController = TextEditingController(text: initialQuota.toString());

  int get quota => int.tryParse(quotaController.text.trim()) ?? 0;

  void dispose() {
    quotaController.dispose();
  }
}

const List<Map<String, String>> kCorporateSpecializationOptions = [
  {'slug': 'photographer', 'label': 'Photographer'},
  {'slug': 'videographer', 'label': 'Videographer'},
  {'slug': '3d_modeler', 'label': '3D Modeler & Texture Artist'},
  {'slug': '2d_animator', 'label': '2D Animator & Motion Designer'},
  {'slug': 'ui_ux_designer', 'label': 'UI/UX Designer & Prototyper'},
  {'slug': 'graphic_designer', 'label': 'Graphic Designer & Illustrator'},
  {'slug': 'programmer', 'label': 'Programmer / Software Developer'},
  {'slug': 'audio_producer', 'label': 'Audio Producer & Sound Engineer'},
  {'slug': 'copywriter', 'label': 'Content Writer & Copywriter'},
  {'slug': 'social_media_specialist', 'label': 'Social Media & Digital Marketing'},
  {'slug': 'game_developer', 'label': 'Game Developer & Technical Artist'},
  {'slug': 'vfx_artist', 'label': 'VFX & Compositing Artist'},
  {'slug': 'video_editor', 'label': 'Video Editor & Colorist'},
];

/// Registry that manages specialization dropdown options with persistent storage (SharedPreferences)
/// so that custom options added by corporate users are never lost when closing modals or restarting the app.
class CorporateSpecializationRegistry {
  static const String _prefKey = 'corporate_custom_specializations_list';

  static final List<Map<String, String>> _options =
      List<Map<String, String>>.from(kCorporateSpecializationOptions);
  static bool _initialized = false;

  static List<Map<String, String>> get options {
    return List<Map<String, String>>.from(_options);
  }

  static Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final slug = item['slug']?.toString() ?? '';
              final label = item['label']?.toString() ?? '';
              if (slug.isNotEmpty && label.isNotEmpty) {
                final exists = _options.any((o) =>
                    o['slug'] == slug ||
                    o['label']!.toLowerCase() == label.toLowerCase());
                if (!exists) {
                  _options.add({'slug': slug, 'label': label});
                }
              }
            }
          }
        }
      }
    } catch (_) {}
    _initialized = true;
  }

  static Map<String, String> addOption(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return _options.first;

    final existing = _options.cast<Map<String, String>?>().firstWhere(
      (opt) => opt!['label']!.toLowerCase() == trimmed.toLowerCase(),
      orElse: () => null,
    );
    if (existing != null) {
      return existing;
    }

    final generatedSlug = slugify(trimmed);
    final slug = generatedSlug.isEmpty
        ? 'role_${DateTime.now().millisecondsSinceEpoch}'
        : generatedSlug;
    final newOpt = {'slug': slug, 'label': trimmed};
    _options.add(newOpt);

    _persistOptions();

    return newOpt;
  }

  static Future<void> _persistOptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customList = _options
          .where((o) =>
              !kCorporateSpecializationOptions.any((def) => def['slug'] == o['slug']))
          .toList();
      await prefs.setString(_prefKey, jsonEncode(customList));
    } catch (_) {}
  }

  static String slugify(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  @visibleForTesting
  static void resetForTest() {
    _options.clear();
    _options.addAll(kCorporateSpecializationOptions);
    _initialized = false;
  }
}

class CorporateVacancyFormDialog extends StatefulWidget {
  final UserModel? user;

  const CorporateVacancyFormDialog({super.key, this.user});

  @override
  State<CorporateVacancyFormDialog> createState() => _CorporateVacancyFormDialogState();
}

class _CorporateVacancyFormDialogState extends State<CorporateVacancyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _minSalaryController;
  late final TextEditingController _maxSalaryController;
  late final TextEditingController _newRequirementController;

  bool _isSalaryRange = true;
  bool _isSalaryNegotiable = false;
  String _category = 'magang'; // 'magang' or 'job'
  DateTime _selectedDeadline = DateTime(2026, 9, 21);
  bool _isSaving = false;

  late final List<SpecializationQuotaEntry> _specializations;
  late final List<String> _requirements;
  late List<Map<String, String>> _availableSpecializationOptions;

  @override
  void initState() {
    super.initState();
    _availableSpecializationOptions = CorporateSpecializationRegistry.options;
    CorporateSpecializationRegistry.init().then((_) {
      if (mounted) {
        setState(() {
          _availableSpecializationOptions = CorporateSpecializationRegistry.options;
        });
      }
    });
    _titleController = TextEditingController(text: 'Program Magang MBKM 3D Modeler Batch I 2026');
    _descriptionController = TextEditingController(
      text: 'Kerja sama penempatan talenta vokasi dan mahasiswa magang pada lini produksi kreatif berstandar industri internasional.',
    );
    _minSalaryController = TextEditingController(text: '2.500.000');
    _maxSalaryController = TextEditingController(text: '3.500.000');
    _newRequirementController = TextEditingController();

    // Default 2 specializations demonstrating multi-specialization quota calculation:
    // e.g. Photographer: 10 + Videographer: 10 = Total 20 Positions
    _specializations = [
      SpecializationQuotaEntry(
        roleSlug: 'photographer',
        roleLabel: 'Photographer',
        initialQuota: 10,
      ),
      SpecializationQuotaEntry(
        roleSlug: 'videographer',
        roleLabel: 'Videographer',
        initialQuota: 10,
      ),
    ];

    for (final s in _specializations) {
      s.quotaController.addListener(_onQuotaChanged);
    }

    _requirements = [
      'Siswa SMK vokasi atau Mahasiswa aktif jurusan terkait',
      'Memiliki portofolio karya yang relevan',
      'Mampu bekerja sama dalam tim dan komunikatif',
    ];
  }

  void _onQuotaChanged() {
    if (mounted) setState(() {});
  }

  Map<String, String> _addNewSpecializationOption(String label) {
    final newOpt = CorporateSpecializationRegistry.addOption(label);
    if (mounted) {
      setState(() {
        _availableSpecializationOptions = CorporateSpecializationRegistry.options;
      });
    }
    return newOpt;
  }

  Future<void> _openSpecializationSearchPicker(int specIndex) async {
    final currentSlug = _specializations[specIndex].roleSlug;
    final selected = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _SearchableSpecializationDialog(
        currentSlug: currentSlug,
        options: _availableSpecializationOptions,
        onAddNewOption: (newLabel) => _addNewSpecializationOption(newLabel),
      ),
    );
    if (selected != null) {
      setState(() {
        _specializations[specIndex].roleSlug = selected['slug']!;
        _specializations[specIndex].roleLabel = selected['label']!;
        _availableSpecializationOptions = CorporateSpecializationRegistry.options;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _minSalaryController.dispose();
    _maxSalaryController.dispose();
    _newRequirementController.dispose();
    for (final s in _specializations) {
      s.quotaController.removeListener(_onQuotaChanged);
      s.dispose();
    }
    super.dispose();
  }

  String get currentAllowanceText {
    if (_isSalaryNegotiable) {
      return 'Kompetitif / Sesuai Kesepakatan';
    }
    final min = _minSalaryController.text.trim();
    final max = _maxSalaryController.text.trim();
    if (_isSalaryRange) {
      if (min.isNotEmpty && max.isNotEmpty) {
        return 'Rp $min - Rp $max / bulan';
      } else if (min.isNotEmpty) {
        return 'Mulai dari Rp $min / bulan';
      } else if (max.isNotEmpty) {
        return 'Hingga Rp $max / bulan';
      }
      return 'Kompetitif / Sesuai Kesepakatan';
    } else {
      if (min.isNotEmpty) {
        return 'Rp $min / bulan';
      }
      return 'Kompetitif / Sesuai Kesepakatan';
    }
  }

  int get totalQuota {
    int sum = 0;
    for (final s in _specializations) {
      sum += s.quota;
    }
    return sum;
  }

  String get _formattedDeadline => ProgramMagangCard.formatDateDisplay(
        _selectedDeadline.toIso8601String(),
        defaultFallback: '21 Sep 2026',
      );

  void _addSpecialization() {
    final usedSlugs = _specializations.map((s) => s.roleSlug).toSet();
    final available = _availableSpecializationOptions.firstWhere(
      (e) => !usedSlugs.contains(e['slug']),
      orElse: () => _availableSpecializationOptions.first,
    );

    final newEntry = SpecializationQuotaEntry(
      roleSlug: available['slug']!,
      roleLabel: available['label']!,
      initialQuota: 5,
    );
    newEntry.quotaController.addListener(_onQuotaChanged);

    setState(() {
      _specializations.add(newEntry);
    });
  }

  void _removeSpecialization(int index) {
    if (_specializations.length <= 1) return;
    final removed = _specializations.removeAt(index);
    removed.quotaController.removeListener(_onQuotaChanged);
    removed.dispose();
    setState(() {});
  }

  void _addRequirement() {
    final text = _newRequirementController.text.trim();
    if (text.isEmpty) return;
    if (!_requirements.contains(text)) {
      setState(() {
        _requirements.add(text);
        _newRequirementController.clear();
      });
    }
  }

  void _removeRequirement(int index) {
    setState(() {
      _requirements.removeAt(index);
    });
  }

  void _addQuickRequirement(String text) {
    final clean = text.replaceFirst('+ ', '').trim();
    if (!_requirements.contains(clean)) {
      setState(() {
        _requirements.add(clean);
      });
    }
  }

  Future<void> _pickDeadlineDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2035, 12, 31),
      helpText: 'Pilih Batas Periode Pendaftaran',
      confirmText: 'PILIH',
      cancelText: 'BATAL',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDeadline = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    if (_requirements.isEmpty) {
      AppSweetAlert.warning(
        context,
        'Harap tambahkan minimal 1 syarat & kualifikasi untuk lowongan ini.',
        title: 'Syarat & Kualifikasi Kosong',
      );
      return;
    }

    if (totalQuota <= 0) {
      AppSweetAlert.warning(
        context,
        'Harap tentukan kuota posisi lebih dari 0 pada spesialisasi yang dibutuhkan.',
        title: 'Kuota Posisi Belum Ditentukan',
      );
      return;
    }

    setState(() => _isSaving = true);

    final isMagang = _category == 'magang';
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final allowance = currentAllowanceText;
    final deadlineDate = _selectedDeadline;
    final deadlineFormatted =
        '${deadlineDate.year}-${deadlineDate.month.toString().padLeft(2, '0')}-${deadlineDate.day.toString().padLeft(2, '0')}';

    // Requirement payload for API
    final reqPayload = <Map<String, dynamic>>[];
    for (final spec in _specializations) {
      reqPayload.add({
        'sub_role_slug': spec.roleSlug,
        'quantity': spec.quota,
        'notes': 'Spesialisasi ${spec.roleLabel} (${spec.quota} kuota)',
      });
    }
    for (final req in _requirements) {
      reqPayload.add({
        'sub_role_slug': 'kualifikasi',
        'quantity': 0,
        'notes': req,
      });
    }

    OpportunityModel? createdModel;
    try {
      final res = await OpportunityService.createOpportunity(
        title: title,
        subRoleSlug: isMagang ? 'magang' : _specializations.first.roleSlug,
        type: 'project',
        locationCategory: isMagang ? 'magang' : 'job',
        description: description,
        budgetRange: allowance,
        deadline: deadlineFormatted,
        requirements: reqPayload,
      );
      if (res['status'] == true && res['data'] is OpportunityModel) {
        createdModel = res['data'] as OpportunityModel;
      } else {
        final errMsg = res['message']?.toString() ?? 'Gagal menyimpan data ke database server.';
        if (mounted) {
          setState(() => _isSaving = false);
          AppSweetAlert.error(context, errMsg, title: 'Gagal Mempublikasikan');
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppSweetAlert.error(context, 'Terjadi kesalahan saat menghubungi server: $e', title: 'Koneksi Gagal');
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    final newVacancy = CorporateVacancyItem.fromOpportunity(createdModel);
    Navigator.of(context).pop(newVacancy);
  }

  InputDecoration _inputDecoration({
    required String hint,
    IconData? prefixIcon,
    String? prefixText,
    String? suffixText,
    Widget? suffixIcon,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      suffixText: suffixText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: const Color(0xFF2563EB)) : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
    );
  }

  Widget _buildFieldCardContainer({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFieldWithHeader({
    required String label,
    required String caption,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          caption,
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.grey.shade600,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildSalaryField() {
    return _buildFieldWithHeader(
      label: 'Estimasi Gaji / Uang Saku (Opsional)',
      caption: 'Opsional: Tentukan rentang nominal, nominal tetap per bulan, atau pilih opsi Kompetitif / Negosiasi.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode Selector: Rentang vs Tetap vs Kompetitif / Negosiasi
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _isSalaryNegotiable = false;
                    _isSalaryRange = true;
                    if (_maxSalaryController.text.isEmpty) {
                      _maxSalaryController.text = _category == 'magang' ? '3.500.000' : '18.000.000';
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (!_isSalaryNegotiable && _isSalaryRange)
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (!_isSalaryNegotiable && _isSalaryRange)
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.linear_scale_rounded,
                        size: 14,
                        color: (!_isSalaryNegotiable && _isSalaryRange)
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Rentang Gaji',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: (!_isSalaryNegotiable && _isSalaryRange)
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _isSalaryNegotiable = false;
                    _isSalaryRange = false;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (!_isSalaryNegotiable && !_isSalaryRange)
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (!_isSalaryNegotiable && !_isSalaryRange)
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.attach_money_rounded,
                        size: 14,
                        color: (!_isSalaryNegotiable && !_isSalaryRange)
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Nominal Tetap',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: (!_isSalaryNegotiable && !_isSalaryRange)
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _isSalaryNegotiable = true;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isSalaryNegotiable ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isSalaryNegotiable ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.handshake_rounded,
                        size: 14,
                        color: _isSalaryNegotiable ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Kompetitif / Negosiasi',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _isSalaryNegotiable ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Input Controls
          if (_isSalaryNegotiable)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Nominal gaji/uang saku bersifat fleksibel dan akan disepakati saat tahap seleksi / wawancara.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
                    ),
                  ),
                ],
              ),
            )
          else if (_isSalaryRange)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minSalaryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [const IndonesianCurrencyInputFormatter()],
                    onChanged: (_) => setState(() {}),
                    decoration: _inputDecoration(
                      hint: 'Min (Opsional)',
                      prefixText: 'Rp ',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    's/d',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _maxSalaryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [const IndonesianCurrencyInputFormatter()],
                    onChanged: (_) => setState(() {}),
                    decoration: _inputDecoration(
                      hint: 'Maks (Opsional)',
                      prefixText: 'Rp ',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                  ),
                ),
              ],
            )
          else
            TextFormField(
              controller: _minSalaryController,
              keyboardType: TextInputType.number,
              inputFormatters: [const IndonesianCurrencyInputFormatter()],
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration(
                hint: 'Contoh: 3.500.000 (Opsional)',
                prefixText: 'Rp ',
                prefixIcon: Icons.payments_outlined,
              ),
            ),
          const SizedBox(height: 6),

          // Live Preview Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.remove_red_eye_outlined, size: 12, color: Color(0xFF2563EB)),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Pratinjau: $currentAllowanceText',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E40AF),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlineField() {
    return _buildFieldWithHeader(
      label: 'Batas Periode Pendaftaran *',
      caption: 'Batas akhir pengajuan berkas pelamar (format: 21 Sep 2026).',
      child: InkWell(
        onTap: _pickDeadlineDate,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 20, color: Color(0xFF2563EB)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _formattedDeadline,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Pilih Tanggal',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 680;
    final dialogWidth = isSmall ? screenWidth * 0.95 : 760.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmall ? 12 : 24,
        vertical: 24,
      ),
      child: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top accent gradient bar
            Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                ),
              ),
            ),

            // Modal Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_business_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Flexible(
                              child: Text(
                                'Buka Lowongan Kerja & Magang',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: const Text(
                                'B2B Corporate',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Lengkapi formulir pembukaan lowongan kerja atau program magang industri resmi.',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    tooltip: 'Tutup Dialog',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

            // Scrollable Content Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Guidance Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Panduan Buka Lowongan: Lengkapi rincian program, deskripsi, estimasi gaji, batas pendaftaran, syarat kualifikasi, dan spesialisasi keahlian. Kuota masing-masing posisi akan otomatis terakumulasi.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // SECTION 1: Informasi Lowongan & Program
                      _buildFieldCardContainer(
                        title: 'Informasi Lowongan & Program',
                        subtitle: 'Pilih jenis program, nama lowongan, deskripsi, estimasi gaji, dan periode pendaftaran',
                        icon: Icons.business_center_rounded,
                        children: [
                          // Jenis Program Selector (Magang vs Kerja)
                          _buildFieldWithHeader(
                            label: 'Jenis Program Lowongan *',
                            caption: 'Pilih kategori program magang vokasi atau lowongan pekerjaan kreatif.',
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _category = 'magang';
                                        if (_titleController.text.contains('Senior') ||
                                            _titleController.text.isEmpty) {
                                          _titleController.text =
                                              'Program Magang MBKM 3D Modeler Batch I 2026';
                                        }
                                        _minSalaryController.text = '2.500.000';
                                        _maxSalaryController.text = '3.500.000';
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _category == 'magang'
                                            ? const Color(0xFFEFF6FF)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _category == 'magang'
                                              ? const Color(0xFF2563EB)
                                              : const Color(0xFFCBD5E1),
                                          width: _category == 'magang' ? 1.8 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.school_rounded,
                                            size: 20,
                                            color: _category == 'magang'
                                                ? const Color(0xFF2563EB)
                                                : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Program Magang Industri',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: _category == 'magang'
                                                        ? const Color(0xFF1E3A8A)
                                                        : const Color(0xFF334155),
                                                  ),
                                                ),
                                                Text(
                                                  'PKL SMK Vokasi & MBKM',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _category = 'job';
                                        if (_titleController.text.contains('Magang') ||
                                            _titleController.text.isEmpty) {
                                          _titleController.text =
                                              'Senior Creative Director & Brand Strategist';
                                        }
                                        _minSalaryController.text = '12.000.000';
                                        _maxSalaryController.text = '18.000.000';
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _category == 'job'
                                            ? const Color(0xFFF5F3FF)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _category == 'job'
                                              ? const Color(0xFF7C3AED)
                                              : const Color(0xFFCBD5E1),
                                          width: _category == 'job' ? 1.8 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.work_rounded,
                                            size: 20,
                                            color: _category == 'job'
                                                ? const Color(0xFF7C3AED)
                                                : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Lowongan Pekerjaan Kreatif',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: _category == 'job'
                                                        ? const Color(0xFF5B21B6)
                                                        : const Color(0xFF334155),
                                                  ),
                                                ),
                                                Text(
                                                  'Rekrutmen Talenta & Kontrak',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Nama Program Magang / Kerja
                          _buildFieldWithHeader(
                            label: 'Nama Program Magang / Kerja *',
                            caption: 'Tuliskan judul program magang atau lowongan posisi pekerjaan yang jelas dan menarik.',
                            child: TextFormField(
                              controller: _titleController,
                              decoration: _inputDecoration(
                                hint: 'Contoh: Program Magang MBKM 3D Modeler Batch I 2026',
                                prefixIcon: Icons.badge_outlined,
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Nama program wajib diisi' : null,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Deskripsi & Ruang Lingkup
                          _buildFieldWithHeader(
                            label: 'Deskripsi & Ruang Lingkup *',
                            caption: 'Jelaskan ringkasan kebutuhan, proyek yang dikerjakan, tanggung jawab, dan lingkungan kerja.',
                            child: TextFormField(
                              controller: _descriptionController,
                              minLines: 3,
                              maxLines: 4,
                              decoration: _inputDecoration(
                                hint: 'Contoh: Kerja sama penempatan 10 siswa vokasi magang pada produksi serial animasi nusantara...',
                                prefixIcon: Icons.notes_rounded,
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Deskripsi program wajib diisi' : null,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2 Kolom: Estimasi Gaji & Periode Pendaftaran
                          if (!isSmall)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildSalaryField()),
                                const SizedBox(width: 16),
                                Expanded(child: _buildDeadlineField()),
                              ],
                            )
                          else ...[
                            _buildSalaryField(),
                            const SizedBox(height: 16),
                            _buildDeadlineField(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 18),

                      // SECTION 2: Spesifikasi Keahlian & Alokasi Kuota
                      _buildFieldCardContainer(
                        title: 'Spesifikasi Keahlian & Alokasi Kuota',
                        subtitle: 'Pilih spesialisasi keahlian yang dibutuhkan dan tentukan alokasi kuota per posisi',
                        icon: Icons.engineering_rounded,
                        children: [
                          Text(
                            'Daftar Posisi & Kuota Yang Dibutuhkan *',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Anda dapat menambahkan beberapa spesialisasi sekaligus (multiple). Kuota otomatis dijumlahkan.',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, height: 1.3),
                          ),
                          const SizedBox(height: 12),

                          // Dynamic Specialization Rows
                          for (int i = 0; i < _specializations.length; i++) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                // Specialization Dropdown Field (Searchable with Add Option)
                                  Expanded(
                                    flex: 3,
                                    child: InkWell(
                                      key: ValueKey('spec_dropdown_$i'),
                                      onTap: () => _openSpecializationSearchPicker(i),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.work_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _specializations[i].roleLabel,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF0F172A),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Quota Field
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: _specializations[i].quotaController,
                                      keyboardType: TextInputType.number,
                                      decoration: _inputDecoration(
                                        hint: '10',
                                        prefixIcon: Icons.people_outline_rounded,
                                        suffixText: 'Posisi',
                                      ),
                                      validator: (v) {
                                        final num = int.tryParse(v?.trim() ?? '');
                                        if (num == null || num <= 0) {
                                          return 'Min 1';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Remove Button
                                  IconButton(
                                    onPressed: _specializations.length > 1
                                        ? () => _removeSpecialization(i)
                                        : null,
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: _specializations.length > 1
                                          ? Colors.red.shade400
                                          : Colors.grey.shade300,
                                      size: 22,
                                    ),
                                    tooltip: 'Hapus Posisi Ini',
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Action buttons for specializations
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _addSpecialization,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Tambah Spesialisasi Lain'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2563EB),
                                  side: const BorderSide(color: Color(0xFF93C5FD)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              OutlinedButton.icon(
                                key: const ValueKey('btn_add_new_option_global'),
                                onPressed: () async {
                                  final newOpt = await showDialog<Map<String, String>>(
                                    context: context,
                                    builder: (ctx) => _SearchableSpecializationDialog(
                                      currentSlug: '',
                                      options: _availableSpecializationOptions,
                                      onAddNewOption: (label) => _addNewSpecializationOption(label),
                                    ),
                                  );
                                  if (newOpt != null && mounted && context.mounted) {
                                    setState(() {
                                      _availableSpecializationOptions = CorporateSpecializationRegistry.options;
                                    });
                                    AppSweetAlert.success(
                                      context,
                                      'Spesialisasi "${newOpt['label']}" berhasil disimpan secara permanen ke pilihan dropdown.',
                                      title: 'Opsi Tersimpan',
                                    );
                                  }
                                },
                                icon: const Icon(Icons.playlist_add_rounded, size: 18),
                                label: const Text('Kelola / Tambah Opsi Dropdown'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF475569),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Real-time Total Kuota Summary Banner
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF93C5FD), width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.people_alt_rounded,
                                      color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            'Total Kuota Terakumulasi: $totalQuota Posisi',
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1E3A8A),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Otomatis Dihitung',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF16A34A),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_specializations.map((s) => '${s.roleLabel} (${s.quota})').join(' + ')} = $totalQuota Total Posisi Dibuka',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF3B82F6),
                                          fontWeight: FontWeight.w600,
                                        ),
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

                      // SECTION 3: Syarat & Kualifikasi
                      _buildFieldCardContainer(
                        title: 'Syarat & Kualifikasi Pelamar',
                        subtitle: 'Daftar kriteria, persyaratan pendidikan, portofolio, dan keahlian yang dicari',
                        icon: Icons.assignment_turned_in_outlined,
                        children: [
                          Text(
                            'Kualifikasi Yang Ditetapkan *',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Kualifikasi ini akan tampil pada kartu lowongan agar pelamar mengetahui prasyarat pendaftaran.',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, height: 1.3),
                          ),
                          const SizedBox(height: 12),

                          // Active Requirements List
                          for (int i = 0; i < _requirements.length; i++) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      size: 18, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _requirements[i],
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _removeRequirement(i),
                                    icon: const Icon(Icons.close_rounded,
                                        size: 18, color: Color(0xFF94A3B8)),
                                    tooltip: 'Hapus Syarat',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),

                          // Add Requirement Input
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _newRequirementController,
                                  onFieldSubmitted: (_) => _addRequirement(),
                                  decoration: _inputDecoration(
                                    hint: 'Tuliskan syarat & kualifikasi baru...',
                                    prefixIcon: Icons.add_task_rounded,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.icon(
                                onPressed: _addRequirement,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Tambah'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Quick Recommendation Chips
                          Text(
                            'Rekomendasi Cepat:',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              '+ Siswa SMK / Vokasi',
                              '+ Mahasiswa D3 / S1',
                              '+ Portofolio Karya Aktif',
                              '+ Menguasai Software Terkait',
                              '+ Siap Magang 3-6 Bulan',
                              '+ Pengalaman Kerja 1-2 Tahun',
                              '+ Disiplin & Komunikatif',
                            ].map((chip) {
                              return ActionChip(
                                label: Text(chip),
                                labelStyle: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                                backgroundColor: const Color(0xFFEFF6FF),
                                side: const BorderSide(color: Color(0xFFBFDBFE)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                onPressed: () => _addQuickRequirement(chip),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Modal Footer (Actions)
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        'Tervalidasi Sistem Instansi Kreavana',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline_rounded, size: 18),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isSaving ? null : _submit,
                        label: Text(
                          _isSaving ? 'Menyimpan...' : 'Publikasikan Lowongan',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
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
}

class _SearchableSpecializationDialog extends StatefulWidget {
  final String currentSlug;
  final List<Map<String, String>> options;
  final Map<String, String> Function(String newLabel) onAddNewOption;

  const _SearchableSpecializationDialog({
    required this.currentSlug,
    required this.options,
    required this.onAddNewOption,
  });

  @override
  State<_SearchableSpecializationDialog> createState() => _SearchableSpecializationDialogState();
}

class _SearchableSpecializationDialogState extends State<_SearchableSpecializationDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _customRoleCtrl = TextEditingController();
  bool _isCreatingCustom = false;
  late List<Map<String, String>> _dialogOptions;

  @override
  void initState() {
    super.initState();
    _dialogOptions = List<Map<String, String>>.from(widget.options);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _customRoleCtrl.dispose();
    super.dispose();
  }

  void _submitNewCustomRole(String roleName) {
    final clean = roleName.trim();
    if (clean.isEmpty) return;
    final created = widget.onAddNewOption(clean);
    if (!_dialogOptions.any((o) => o['slug'] == created['slug'])) {
      _dialogOptions.add(created);
    }
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _dialogOptions.where((opt) {
      if (query.isEmpty) return true;
      final labelMatch = opt['label']!.toLowerCase().contains(query);
      final slugMatch = opt['slug']!.toLowerCase().contains(query);
      return labelMatch || slugMatch;
    }).toList();

    final hasExactMatch = _dialogOptions.any(
      (opt) => opt['label']!.trim().toLowerCase() == query,
    );

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.search_rounded, color: Color(0xFF2563EB), size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pilih Spesialisasi Keahlian',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 2),
                Text(
                  'Cari atau buat opsi spesialisasi baru',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input Field
            TextFormField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (val) {
                if (val.trim().isNotEmpty && !hasExactMatch) {
                  _submitNewCustomRole(val);
                }
              },
              decoration: InputDecoration(
                hintText: 'Cari spesialisasi atau ketik opsi baru...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF2563EB)),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (query.isNotEmpty && !hasExactMatch)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ElevatedButton.icon(
                          key: const ValueKey('btn_quick_use_typed_role'),
                          onPressed: () => _submitNewCustomRole(_searchCtrl.text),
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text('Gunakan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ),
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      ),
                  ],
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // If user typed something that doesn't exist, show quick add banner
            if (query.isNotEmpty && !hasExactMatch) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF93C5FD)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey('btn_add_typed_spec_option'),
                    onTap: () => _submitNewCustomRole(_searchCtrl.text),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 14),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tambahkan "${_searchCtrl.text.trim()}"',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1D4ED8),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                const Text(
                                  'Klik untuk menambahkan opsi baru ini ke dropdown',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF2563EB)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // If creating custom via input form
            if (_isCreatingCustom) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nama Spesialisasi Baru',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _customRoleCtrl,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Misal: AI Prompt Engineer',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onFieldSubmitted: (v) => _submitNewCustomRole(v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => _submitNewCustomRole(_customRoleCtrl.text),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Simpan'),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => setState(() => _isCreatingCustom = false),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Options List
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: filtered.isEmpty && (query.isEmpty || hasExactMatch)
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Tidak ada spesialisasi yang cocok.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (ctx, idx) {
                        final opt = filtered[idx];
                        final isSelected = opt['slug'] == widget.currentSlug;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(color: const Color(0xFFBFDBFE))
                                : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            leading: Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.work_outline_rounded,
                              size: 18,
                              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            ),
                            title: Text(
                              opt['label']!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                              ),
                            ),
                            trailing: isSelected
                                ? const Text(
                                    'Terpilih',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2563EB),
                                    ),
                                  )
                                : null,
                            onTap: () {
                              Navigator.of(context).pop(opt);
                            },
                          ),
                        ),
                      );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        if (!_isCreatingCustom && query.isNotEmpty && !hasExactMatch)
          FilledButton.icon(
            key: const ValueKey('btn_dialog_action_use_typed'),
            onPressed: () => _submitNewCustomRole(_searchCtrl.text),
            icon: const Icon(Icons.check_circle_rounded, size: 16),
            label: Text('Gunakan & Simpan "${_searchCtrl.text.trim()}"'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        if (!_isCreatingCustom)
          TextButton.icon(
            key: const ValueKey('btn_open_custom_role_form'),
            onPressed: () {
              setState(() {
                _isCreatingCustom = true;
                _customRoleCtrl.text = _searchCtrl.text.trim();
              });
            },
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Tambah Opsi Kustom Baru'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
          ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
      ],
    );
  }
}

