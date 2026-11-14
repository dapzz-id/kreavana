import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../models/opportunity_model.dart';
import '../services/opportunity_service.dart';
import '../services/user_store.dart';
import '../widgets/app_breadcrumbs.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../widgets/program_magang_card.dart';
import 'buat_kebutuhan_screen.dart';
import 'detail_kebutuhan_screen.dart';

class CorporateApplicant {
  final String name;
  final String institution;
  final String role;
  final String appliedDate;
  final String status; // 'Menunggu Review', 'Interview', 'Diterima', 'Ditolak'
  final String portfolioUrl;
  final String note;

  const CorporateApplicant({
    required this.name,
    required this.institution,
    required this.role,
    required this.appliedDate,
    required this.status,
    this.portfolioUrl = 'https://kreavana.id/portfolio',
    this.note = '',
  });
}

class CorporateVacancyItem {
  final String id;
  final String title;
  final String description;
  final String category; // 'magang' or 'job'
  final String categoryLabel; // 'Magang' or 'Pekerjaan'
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

    final isMagang = opp.subRoleSlug.toLowerCase().contains('magang') ||
        opp.title.toLowerCase().contains('magang') ||
        opp.title.toLowerCase().contains('intern') ||
        (opp.description != null && opp.description!.toLowerCase().contains('magang'));

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

    final regPeriod = ProgramMagangCard.formatDateDisplay(
      opp.deadline ?? opp.createdAt,
      defaultFallback: '21 Sep 2026',
    );

    final reqList = opp.requirements
        .map((r) => r.notes?.isNotEmpty == true ? r.notes! : r.subRoleSlug.replaceAll('_', ' '))
        .toList();
    if (reqList.isEmpty) {
      reqList.addAll([
        'Talenta kreatif terverifikasi',
        'Memiliki portofolio karya relevan',
        'Siap bekerja sesuai timeline & briefing',
      ]);
    }

    return CorporateVacancyItem(
      id: opp.id ?? 'opp_${DateTime.now().millisecondsSinceEpoch}',
      title: opp.title,
      description: opp.description ?? 'Lowongan kebutuhan terbuka oleh perusahaan mitra industri.',
      category: isMagang ? 'magang' : 'job',
      categoryLabel: isMagang ? 'Magang' : 'Pekerjaan',
      status: opp.status,
      statusLabel: statusText,
      statusBadgeColor: statusColor,
      statusBadgeBg: statusBg,
      registrationPeriod: regPeriod,
      quotaText: isMagang ? '${opp.applicationsCount} dari 10 posisi' : 'Tersedia 1-2 posisi',
      allowance: opp.budgetRange ?? (isMagang ? 'Rp 3.500.000 / bulan' : 'Budget Fleksibel'),
      requirements: reqList,
      applicantsCount: opp.applicationsCount,
      opportunity: opp,
      applicants: [
        CorporateApplicant(
          name: 'Ahmad Rizki Fauzan',
          institution: isMagang ? 'SMK Negeri 1 Surabaya' : 'Universitas Telkom',
          role: opp.subRoleSlug.replaceAll('_', ' ').toUpperCase(),
          appliedDate: '02 Mar 2026',
          status: 'Menunggu Review',
          note: 'Portofolio lengkap dan surat rekomendasi industri.',
        ),
      ],
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
          categoryLabel: 'Pekerjaan Kreatif',
          status: 'open',
          statusLabel: 'Pendaftaran Dibuka',
          statusBadgeColor: const Color(0xFF16A34A),
          statusBadgeBg: const Color(0xFFDCFCE7),
          registrationPeriod: '30 Nov 2026',
          quotaText: '1 posisi tersedia',
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
          categoryLabel: 'Pekerjaan Kreatif',
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

  Future<void> _fetchVacancies() async {
    setState(() => _isLoading = true);
    try {
      final opps = await OpportunityService.getMyOpportunities();
      if (mounted) {
        setState(() {
          _fetchedItems = opps.map((o) => CorporateVacancyItem.fromOpportunity(o)).toList();
        });
      }
    } catch (_) {
      // Fallback to presets if network is unavailable
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<CorporateVacancyItem> get _allVacancies {
    final Map<String, CorporateVacancyItem> map = {};
    // Add presets first
    for (final item in _presetVacancies) {
      map[item.id] = item;
    }
    // Add/overwrite with fetched items from server
    for (final item in _fetchedItems) {
      map[item.id] = item;
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
        case 'Magang Industri':
          return item.category == 'magang';
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
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_business_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text(
              'Pilih Jenis Lowongan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildChoiceTile(
              icon: Icons.school_rounded,
              title: 'Program Magang Industri (PKL / MBKM)',
              subtitle:
                  'Buka lowongan magang resmi untuk siswa SMK vokasi & mahasiswa. Terhubung dengan sistem monitoring institusi pendidikan.',
              color: const Color(0xFF2563EB),
              onTap: () => Navigator.pop(ctx, 'magang'),
            ),
            const SizedBox(height: 12),
            _buildChoiceTile(
              icon: Icons.work_rounded,
              title: 'Lowongan Pekerjaan / Proyek Kreatif',
              subtitle:
                  'Rekrut kreator profesional untuk proyek jangka pendek, kontrak kerja sama, atau posisi full-time perusahaan.',
              color: const Color(0xFF8B5CF6),
              onTap: () => Navigator.pop(ctx, 'job'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuatKebutuhanScreen(
          user: _currentUser,
          initialKategori: choice == 'magang' ? 'magang' : null,
        ),
      ),
    );

    if (result == true) {
      _fetchVacancies();
    }
  }

  Widget _buildChoiceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
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
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _openDetailLowongan(CorporateVacancyItem item) {
    if (item.opportunity != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailKebutuhanScreen(
            opportunity: item.opportunity!,
            user: _currentUser,
          ),
        ),
      );
      return;
    }

    // Modal dialog with applicants review
    showDialog(
      context: context,
      builder: (ctx) => _VacancyDetailDialog(item: item),
    );
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
      'Pekerjaan Kreatif',
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
    if (item.category == 'magang') {
      // Use the verified ProgramMagangCard design
      return ProgramMagangCard(
        title: item.title,
        description: item.description,
        categoryBadge: item.categoryLabel,
        statusBadge: item.statusLabel,
        statusBadgeColor: item.statusBadgeColor,
        statusBadgeBg: item.statusBadgeBg,
        registrationPeriod: item.registrationPeriod,
        quotaText: item.quotaText,
        requirements: item.requirements,
        requirementsCountLabel: '${item.requirements.length} Persyaratan',
        buttonLabel: 'Lihat Detail & Pelamar (${item.applicantsCount}) →',
        onTap: () => _openDetailLowongan(item),
        onDetailPressed: () => _openDetailLowongan(item),
      );
    }

    // Custom Job Vacancy Card matching the exact styling
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badges row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Pekerjaan Kreatif',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7E22CE),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.statusBadgeBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: item.statusBadgeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.statusLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: item.statusBadgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),

            // Description
            Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),

            // Metadata: Deadline & Allowance
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Batas Pendaftaran',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(
                            item.registrationPeriod,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kompensasi / Gaji',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.payments_outlined, size: 14, color: Color(0xFF16A34A)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              item.allowance,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF16A34A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Requirements & Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.people_alt_outlined, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      '${item.applicantsCount} Pelamar Terdaftar',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _openDetailLowongan(item),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lihat Detail & Pelamar',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

// ── Vacancy Detail Dialog ──────────────────────────────────────────────────
class _VacancyDetailDialog extends StatelessWidget {
  final CorporateVacancyItem item;

  const _VacancyDetailDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.categoryLabel,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.statusBadgeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.statusLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: item.statusBadgeColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Modal Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Info boxes
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Periode Pendaftaran',
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.registrationPeriod,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Alokasi / Kuota',
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.quotaText,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Uang Saku / Gaji',
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.allowance,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Requirements
                    const Text(
                      'Syarat & Kualifikasi',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...item.requirements.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                r,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : Colors.grey.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Applicants section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daftar Pelamar (${item.applicants.length})',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        if (item.applicants.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Kemitraan Terverifikasi',
                              style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (item.applicants.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Belum ada pelamar baru pada lowongan ini.',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                        ),
                      )
                    else
                      ...item.applicants.map((app) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.grey.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                child: Text(
                                  app.name.isNotEmpty ? app.name[0] : 'U',
                                  style: const TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      app.name,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      app.institution,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                                      ),
                                    ),
                                    if (app.note.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        app.note,
                                        style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: app.status == 'Diterima'
                                      ? const Color(0xFFDCFCE7)
                                      : (app.status == 'Interview'
                                          ? const Color(0xFFDBEAFE)
                                          : const Color(0xFFFEF3C7)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  app.status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: app.status == 'Diterima'
                                        ? const Color(0xFF16A34A)
                                        : (app.status == 'Interview'
                                            ? const Color(0xFF2563EB)
                                            : const Color(0xFFD97706)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup'),
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
