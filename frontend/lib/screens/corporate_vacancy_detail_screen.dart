import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/user_model.dart';
import '../services/app_router.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../widgets/app_breadcrumbs.dart';
import '../widgets/app_sweet_alert.dart';
import 'corporate_lowongan_screen.dart';

class CorporateVacancyDetailScreen extends StatefulWidget {
  final CorporateVacancyItem? item;
  final String? vacancyId;
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const CorporateVacancyDetailScreen({
    super.key,
    this.item,
    this.vacancyId,
    this.user,
    this.onUserUpdated,
  });

  @override
  State<CorporateVacancyDetailScreen> createState() => _CorporateVacancyDetailScreenState();
}

class _CorporateVacancyDetailScreenState extends State<CorporateVacancyDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CorporateVacancyItem _currentVacancy;
  String _selectedApplicantFilter = 'Semua';
  final TextEditingController _applicantSearchController = TextEditingController();
  late List<CorporateApplicant> _applicants;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initVacancy();
  }

  void _initVacancy() {
    if (widget.item != null) {
      _currentVacancy = widget.item!;
    } else {
      // Fallback default vacancy if opened directly by route
      _currentVacancy = CorporateVacancyItem(
        id: widget.vacancyId ?? 'corp_vac_detail',
        title: 'Program Magang MBKM 3D Modeler Batch I 2026',
        description:
            'Kerja sama penempatan talenta vokasi dan mahasiswa magang pada lini produksi serial animasi nusantara berstandar industri internasional.',
        category: 'magang',
        categoryLabel: 'Magang',
        status: 'open',
        statusLabel: 'Pendaftaran Dibuka',
        statusBadgeColor: const Color(0xFF16A34A),
        statusBadgeBg: const Color(0xFFDCFCE7),
        registrationPeriod: '21 Sep 2026',
        quotaText: '4 dari 10 posisi',
        allowance: 'Rp 2.500.000 - Rp 3.500.000 / bulan',
        requirements: const [
          'Siswa SMK vokasi atau Mahasiswa jurusan Animasi / DKV',
          'Menguasai dasar 3D Modeling (Blender / Maya)',
          'Memiliki portofolio karya modeling atau tekstur aset 3D',
          'Disiplin waktu dan komunikatif dalam koordinasi tim',
        ],
        applicantsCount: 6,
        applicants: const [
          CorporateApplicant(
            name: 'Dimas Aditya',
            institution: 'SMKN 4 Bandung - Animasi',
            role: 'Junior 3D Modeler',
            appliedDate: '10 Feb 2026',
            status: 'Interview',
            note: 'Showreel modeling hard-surface sangat rapi dan proporsional.',
          ),
          CorporateApplicant(
            name: 'Siti Nurhaliza',
            institution: 'Politeknik Negeri Media Kreatif',
            role: '3D Texture & Lookdev',
            appliedDate: '11 Feb 2026',
            status: 'Menunggu Review',
            note: 'Mahir Substance Painter dan render engine Blender Cycles.',
          ),
          CorporateApplicant(
            name: 'Reza Pratama',
            institution: 'SMKN 1 Surabaya - Multimedia',
            role: '3D Environment Artist',
            appliedDate: '12 Feb 2026',
            status: 'Diterima',
            note: 'Telah menandatangani MoU penempatan magang resmi sekolah.',
          ),
          CorporateApplicant(
            name: 'Fauzan Hakim',
            institution: 'Institut Teknologi Bandung - DKV',
            role: 'Junior 3D Modeler',
            appliedDate: '14 Feb 2026',
            status: 'Menunggu Review',
            note: 'Fokus pada modeling karakter kartun nusantara.',
          ),
        ],
      );
    }
    _applicants = List<CorporateApplicant>.from(_currentVacancy.applicants);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _applicantSearchController.dispose();
    super.dispose();
  }

  void _updateApplicantStatus(int index, String newStatus) {
    setState(() {
      final old = _applicants[index];
      _applicants[index] = CorporateApplicant(
        name: old.name,
        institution: old.institution,
        role: old.role,
        appliedDate: old.appliedDate,
        status: newStatus,
        portfolioUrl: old.portfolioUrl,
        note: old.note,
      );
    });
    AppSweetAlert.success(
      context,
      'Status pelamar ${_applicants[index].name} diperbarui menjadi "$newStatus".',
      title: 'Status Pelamar Diperbarui',
    );
  }

  void _toggleVacancyStatus() {
    final isCurrentlyOpen = _currentVacancy.status.toLowerCase() == 'open';
    setState(() {
      _currentVacancy = CorporateVacancyItem(
        id: _currentVacancy.id,
        title: _currentVacancy.title,
        description: _currentVacancy.description,
        category: _currentVacancy.category,
        categoryLabel: _currentVacancy.categoryLabel,
        status: isCurrentlyOpen ? 'closed' : 'open',
        statusLabel: isCurrentlyOpen ? 'Pendaftaran Ditutup' : 'Pendaftaran Dibuka',
        statusBadgeColor: isCurrentlyOpen ? const Color(0xFF64748B) : const Color(0xFF16A34A),
        statusBadgeBg: isCurrentlyOpen ? const Color(0xFFF1F5F9) : const Color(0xFFDCFCE7),
        registrationPeriod: _currentVacancy.registrationPeriod,
        quotaText: _currentVacancy.quotaText,
        allowance: _currentVacancy.allowance,
        requirements: _currentVacancy.requirements,
        applicantsCount: _currentVacancy.applicantsCount,
        applicants: _applicants,
        opportunity: _currentVacancy.opportunity,
      );
    });
    AppSweetAlert.info(
      context,
      'Status lowongan diubah menjadi "${_currentVacancy.statusLabel}".',
      title: 'Status Lowongan Diperbarui',
    );
  }

  List<CorporateApplicant> get _filteredApplicants {
    final query = _applicantSearchController.text.trim().toLowerCase();
    return _applicants.where((app) {
      if (_selectedApplicantFilter != 'Semua' && app.status != _selectedApplicantFilter) {
        return false;
      }
      if (query.isNotEmpty) {
        final matchName = app.name.toLowerCase().contains(query);
        final matchInst = app.institution.toLowerCase().contains(query);
        final matchRole = app.role.toLowerCase().contains(query);
        return matchName || matchInst || matchRole;
      }
      return true;
    }).toList();
  }

  void _navigateBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(AppRoutes.lowonganCorporate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 960;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: !isDesktop
          ? AppBar(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              elevation: 0,
              title: Text(
                _currentVacancy.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => _navigateBack(context),
              ),
            )
          : null,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 16,
          vertical: isDesktop ? 24 : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Breadcrumbs
            AppBreadcrumbs(
              items: [
                BreadcrumbItem(
                  label: 'Beranda',
                  onTap: () => context.go(AppRoutes.beranda),
                ),
                BreadcrumbItem(
                  label: 'Program & Magang Corporate',
                  onTap: () => _navigateBack(context),
                ),
                BreadcrumbItem(
                  label: _currentVacancy.title,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Back button & Actions Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _navigateBack(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Kembali ke Daftar Lowongan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Wrap(
                  spacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        AppSweetAlert.info(
                          context,
                          'Tautan lowongan telah disalin ke papan klip.',
                          title: 'Bagikan Lowongan',
                        );
                      },
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text('Bagikan'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _toggleVacancyStatus,
                      icon: Icon(
                        _currentVacancy.status.toLowerCase() == 'open'
                            ? Icons.pause_circle_outline_rounded
                            : Icons.play_circle_outline_rounded,
                        size: 16,
                      ),
                      label: Text(
                        _currentVacancy.status.toLowerCase() == 'open'
                            ? 'Tutup Pendaftaran'
                            : 'Buka Pendaftaran',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _currentVacancy.status.toLowerCase() == 'open'
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Hero Detail Card
            _buildHeroDetailCard(isDark),
            const SizedBox(height: 20),

            // 4 Key Stats Cards
            _buildKeyStatsGrid(isDesktop, isDark),
            const SizedBox(height: 24),

            // Tab Bar Navigation
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF2563EB),
                indicatorWeight: 3,
                labelColor: const Color(0xFF2563EB),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                tabs: [
                  const Tab(
                    icon: Icon(Icons.description_outlined, size: 18),
                    text: 'Rincian & Kualifikasi Program',
                  ),
                  Tab(
                    icon: const Icon(Icons.people_alt_outlined, size: 18),
                    text: 'Daftar Pelamar (${_applicants.length})',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Tab View Body (Fixed height container for tabs)
            AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                return _tabController.index == 0
                    ? _buildProgramDetailsTab(isDesktop, isDark)
                    : _buildApplicantsManagementTab(isDesktop, isDark);
              },
            ),
          ],
        ),
      ),
    );

    if (isDesktop) {
      return DesktopSidebarLayout(
        user: widget.user ?? UserModel.guest(),
        activeRoute: 'lowongan_magang',
        onUserUpdated: widget.onUserUpdated,
        child: content,
      );
    }

    return content;
  }

  // ── Hero Detail Card ────────────────────────────────────────────────────────
  Widget _buildHeroDetailCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          // Badges Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _currentVacancy.category == 'magang'
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _currentVacancy.category == 'magang'
                        ? const Color(0xFFBFDBFE)
                        : const Color(0xFFDDD6FE),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _currentVacancy.category == 'magang'
                          ? Icons.school_rounded
                          : Icons.work_rounded,
                      size: 14,
                      color: _currentVacancy.category == 'magang'
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _currentVacancy.categoryLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _currentVacancy.category == 'magang'
                            ? const Color(0xFF1E40AF)
                            : const Color(0xFF5B21B6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _currentVacancy.statusBadgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentVacancy.statusBadgeColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _currentVacancy.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _currentVacancy.statusBadgeColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: Color(0xFF64748B)),
                    SizedBox(width: 5),
                    Text(
                      'Tervalidasi Corporate B2B',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Title
          Text(
            _currentVacancy.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),

          // Corporate Entity info
          Row(
            children: [
              const Icon(Icons.business_rounded, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 6),
              const Text(
                'PT Kreavana Industri Kreatif Nusantara',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                '• Terverifikasi Resmi',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Description
          Text(
            _currentVacancy.description,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  // ── Key Stats Grid ──────────────────────────────────────────────────────────
  Widget _buildKeyStatsGrid(bool isDesktop, bool isDark) {
    final stats = [
      _StatItem(
        icon: Icons.calendar_today_rounded,
        iconColor: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
        label: 'Periode Pendaftaran',
        value: _currentVacancy.registrationPeriod,
        subtitle: 'Batas akhir penerimaan',
      ),
      _StatItem(
        icon: Icons.groups_rounded,
        iconColor: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFF5F3FF),
        label: 'Alokasi / Sisa Kuota',
        value: _currentVacancy.quotaText,
        subtitle: 'Kapasitas talenta dibuka',
      ),
      _StatItem(
        icon: Icons.payments_rounded,
        iconColor: const Color(0xFF16A34A),
        bgColor: const Color(0xFFDCFCE7),
        label: 'Estimasi Gaji / Uang Saku',
        value: _currentVacancy.allowance.trim().isNotEmpty
            ? _currentVacancy.allowance
            : 'Kompetitif / Sesuai Kesepakatan',
        subtitle: _currentVacancy.allowance.trim().isNotEmpty &&
                !_currentVacancy.allowance.toLowerCase().contains('kompetitif')
            ? 'Standar kompetitif'
            : 'Dapat dinegosiasikan',
      ),
      _StatItem(
        icon: Icons.assignment_ind_rounded,
        iconColor: const Color(0xFFD97706),
        bgColor: const Color(0xFFFEF3C7),
        label: 'Pelamar Terdaftar',
        value: '${_applicants.length} Orang',
        subtitle: 'Berkas masuk sistem',
      ),
    ];

    if (isDesktop) {
      return Row(
        children: stats.map((stat) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: stat.bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(stat.icon, size: 20, color: stat.iconColor),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    stat.label,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stat.value,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stat.subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    return Column(
      children: stats.map((stat) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: stat.bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(stat.icon, size: 20, color: stat.iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stat.label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    Text(
                      stat.value,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Tab 1: Program Details Tab ──────────────────────────────────────────────
  Widget _buildProgramDetailsTab(bool isDesktop, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section: Syarat & Kualifikasi
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                    ),
                    child: const Icon(Icons.assignment_turned_in_rounded, size: 20, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Syarat & Kualifikasi Pelamar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),
              ..._currentVacancy.requirements.map((req) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF16A34A)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          req,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                            height: 1.4,
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
        const SizedBox(height: 18),

        // Section: Tata Kelola Kemitraan & B2B Governance
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                    ),
                    child: const Icon(Icons.handshake_rounded, size: 20, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Tata Kelola & Kemitraan Industri Resmi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildGovernanceItem(
                      icon: Icons.description_outlined,
                      title: 'MoU & Perjanjian Penempatan',
                      desc: 'Terintegrasi otomatis dengan pangkalan data sekolah vokasi mitra Kreavana.',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildGovernanceItem(
                      icon: Icons.fact_check_outlined,
                      title: 'Monitoring & Logbook Vokasi',
                      desc: 'Penilaian capaian kinerja magang dapat dipantau langsung oleh guru pembimbing.',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGovernanceItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                const SizedBox(height: 3),
                Text(desc, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Applicants Management Tab ─────────────────────────────────────────
  Widget _buildApplicantsManagementTab(bool isDesktop, bool isDark) {
    final filtered = _filteredApplicants;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter and Search Header Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Field
              TextFormField(
                controller: _applicantSearchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Cari nama pelamar, asal sekolah/kampus, atau posisi...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF2563EB)),
                  suffixIcon: _applicantSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _applicantSearchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Filter Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Semua', 'Menunggu Review', 'Interview', 'Diterima', 'Ditolak'].map((status) {
                  final isSelected = _selectedApplicantFilter == status;
                  return ChoiceChip(
                    label: Text(status),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _selectedApplicantFilter = status;
                      });
                    },
                    selectedColor: const Color(0xFF2563EB),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // List of applicants
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.people_outline_rounded, size: 48, color: Color(0xFF94A3B8)),
                const SizedBox(height: 12),
                const Text(
                  'Tidak ada pelamar ditemukan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Coba ubah kata kunci pencarian atau filter status pelamar.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final app = filtered[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          child: Text(
                            app.name.isNotEmpty ? app.name[0] : 'U',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                app.institution,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: Text(
                                      app.role,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Melamar: ${app.appliedDate}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _buildApplicantStatusBadge(app.status),
                      ],
                    ),
                    if (app.note.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notes_rounded, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                app.note,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),

                    // Actions Bar for Applicant
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            AppSweetAlert.info(
                              context,
                              'Tautan Portofolio: ${app.portfolioUrl}',
                              title: 'Portofolio Pelamar',
                            );
                          },
                          icon: const Icon(Icons.launch_rounded, size: 14),
                          label: const Text('Portofolio'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            side: const BorderSide(color: Color(0xFF93C5FD)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (val) {
                            final rawIdx = _applicants.indexOf(app);
                            if (rawIdx != -1) {
                              _updateApplicantStatus(rawIdx, val);
                            }
                          },
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'Menunggu Review', child: Text('Menunggu Review')),
                            const PopupMenuItem(value: 'Interview', child: Text('Jadwalkan Interview')),
                            const PopupMenuItem(value: 'Diterima', child: Text('Terima Magang / Kerja')),
                            const PopupMenuItem(value: 'Ditolak', child: Text('Tolak Berkas')),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_note_rounded, size: 15, color: Color(0xFF475569)),
                                SizedBox(width: 6),
                                Text(
                                  'Ubah Status',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF475569)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildApplicantStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'Diterima':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
      case 'Interview':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF2563EB);
        break;
      case 'Ditolak':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      case 'Menunggu Review':
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _StatItem {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String label;
  final String value;
  final String subtitle;

  _StatItem({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.label,
    required this.value,
    required this.subtitle,
  });
}
