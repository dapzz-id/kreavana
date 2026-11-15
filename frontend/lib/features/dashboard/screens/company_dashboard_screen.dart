import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme.dart';
import '../../../app/app_animations.dart';
import '../../../app/subrole_theme_engine.dart';
import '../../../services/job_contract_service.dart';
import '../../../models/job_contract.dart';
import '../../../services/api_service.dart';
import '../../../widgets/subrole_right_sidebar.dart';
import '../../../models/user_model.dart';
import '../../../screens/buat_kebutuhan_screen.dart';
import '../../../screens/proyek_saya_screen.dart';
import '../../../screens/direct_message_screen.dart';
import '../../../screens/profile_screen.dart';
import '../../../screens/explore_screen.dart';
import '../../../screens/ulasan_reputasi_screen.dart';
import '../../../screens/institution_workspace_screen.dart';
import '../../../widgets/app_bar_badge.dart';
import '../../../widgets/app_sweet_alert.dart';

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

  bool get _isInstitution {
    final sub = (widget.user.subRole ?? '').toLowerCase();
    return sub == 'institution' ||
        sub == 'institusi' ||
        sub == 'lembaga' ||
        sub == 'yayasan' ||
        widget.user.username == 'institution_demo' ||
        widget.user.email.startsWith('institution@');
  }

  Color get _brandBlue => SubRoleThemeEngine.getAccentColorForUser(widget.user);

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

      final loadedMetrics = _isInstitution
          ? <Map<String, dynamic>>[
              {
                'label': 'Total Kolaborasi & Magang',
                'value': totalProjects.toString(),
                'sub': '$activeProjects program berjalan',
                'color': _brandBlue,
                'icon': Icons.hub_outlined,
              },
              {
                'label': 'Mitra IDUKA & Vendor',
                'value': partnerData.length.toString(),
                'sub': 'Rekanan industri terhubung',
                'color': const Color(0xFF10B981),
                'icon': Icons.corporate_fare_rounded,
              },
              {
                'label': 'Tender & Pengadaan RFP',
                'value': tenderData.length.toString(),
                'sub': 'Proyek kampus & riset',
                'color': const Color(0xFFF59E0B),
                'icon': Icons.assignment_outlined,
              },
              {
                'label': 'Pagu Anggaran & Hibah',
                'value': totalExpenses.toString(),
                'sub': 'Realisasi belanja program',
                'color': const Color(0xFF2563EB),
                'icon': Icons.account_balance_wallet_outlined,
              },
            ]
          : <Map<String, dynamic>>[
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
                'color': const Color(0xFF2563EB),
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
          final title = p['title']?.toString() ?? 'Mitra B2B';
          String phone = meta['phone']?.toString() ?? '';
          if (phone.isEmpty && meta['contact'] != null && !meta['contact'].toString().contains('@')) {
            phone = meta['contact'].toString();
          }
          if (phone.isEmpty) {
            if (title.contains('Visual Kreasi')) {
              phone = '081289123401';
            } else if (title.contains('Grafika Mandiri')) {
              phone = '081378234502';
            } else if (title.contains('Nusantara Audio')) {
              phone = '081567345603';
            } else if (title.contains('Cipta Event')) {
              phone = '081856456704';
            } else if (title.contains('Pixel Craft')) {
              phone = '081945567805';
            } else {
              phone = '081234567890';
            }
          }
          loadedCreators.add({
            'name': title,
            'cat': meta['category'] ?? 'Creative Partner',
            'rating': '4.9',
            'verified': true,
            'phone': phone,
            'email': meta['email'] ?? (meta['contact']?.toString().contains('@') == true ? meta['contact'] : ''),
            'website': meta['website'] ?? '',
          });
        }
      }
      if (loadedCreators.isEmpty) {
        final vendorList = overview['vendor_recommendations'] as List<dynamic>? ?? [];
        for (final v in vendorList) {
          if (v is Map<String, dynamic>) {
            final vName = (v['name'] ?? v['user_name'] ?? 'Mitra B2B').toString();
            final vPhone = (v['phone'] ?? v['contact'] ?? '081234567890').toString();
            loadedCreators.add({
              'name': vName,
              'cat': (v['category'] ?? v['sub_role'] ?? 'Creative Partner').toString(),
              'rating': (v['rating'] ?? '4.9').toString(),
              'verified': true,
              'phone': vPhone,
              'email': (v['email'] ?? '').toString(),
              'website': (v['website'] ?? '').toString(),
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

      if (_isInstitution) {
        if (loadedProjects.isEmpty) {
          loadedProjects.addAll([
            {
              'title': 'Program Magang Industri Animasi 3D Studio',
              'creator': 'Studio Animasi Nusantara • 12 Mahasiswa',
              'progress': 0.75,
              'status': 'in_progress',
            },
            {
              'title': 'Hilirisasi Riset Rebranding Kemasan UMKM Binaan LPPM',
              'creator': 'Dinas Koperasi & UMKM • Lab Desain Kreatif',
              'progress': 0.50,
              'status': 'in_progress',
            },
            {
              'title': 'Penyusunan Kurikulum DKV Berbasis Standar IDUKA',
              'creator': 'PT Kreatif Visual Nusantara • Dosen Praktisi',
              'progress': 0.90,
              'status': 'review',
            },
            {
              'title': 'Sayembara Desain Maskot Kreatif Kota Pelajar',
              'creator': 'Biro Kemahasiswaan & Alumni • 24 Peserta',
              'progress': 1.0,
              'status': 'completed',
            },
          ]);
        }
        if (loadedActivities.isEmpty) {
          loadedActivities.addAll([
            {
              'title': 'Nota Kesepahaman (MoU) dengan PT Kreatif Visual Nusantara telah aktif',
              'time': '10 menit lalu',
            },
            {
              'title': '12 Mahasiswa DKV terverifikasi masuk kuota magang industri Batch 2',
              'time': '1 jam lalu',
            },
            {
              'title': 'Tender Terbuka: Pengadaan Perangkat Multimedia telah dipublikasikan',
              'time': '3 jam lalu',
            },
            {
              'title': 'Laporan evaluasi kemitraan riset semester berjalan telah diarsipkan',
              'time': '1 hari lalu',
            },
          ]);
        }
        if (loadedTenders.isEmpty) {
          loadedTenders.addAll([
            {
              'title': 'Program Magang Industri Animasi & Visual FX (Batch 2026)',
              'desc': 'Program penempatan kerja praktik 6 bulan untuk mahasiswa DKV & Animasi di studio terakreditasi.',
              'category': 'Magang Industri IDUKA',
              'budget': 'Rp 45.000.000',
              'status': 'open',
              'deadline': '2026-11-15',
            },
            {
              'title': 'Riset Terapan LPPM: Rebranding & Packaging 20 UMKM Daerah',
              'desc': 'Hibah penelitian kolaboratif terapan dosen dan mahasiswa bersama instansi dinas koperasi.',
              'category': 'Hibah Riset LPPM',
              'budget': 'Rp 80.000.000',
              'status': 'open',
              'deadline': '2026-12-01',
            },
            {
              'title': 'Pengadaan Fasilitas Studio Broadcasting & Film Digital',
              'desc': 'Penyediaan kamera cinema, lightning set, dan audio workstation untuk laboratorium perfilman.',
              'category': 'Pengadaan Sarpras',
              'budget': 'Rp 120.000.000',
              'status': 'open',
              'deadline': '2026-11-20',
            },
          ]);
        }
        if (loadedCreators.isEmpty) {
          loadedCreators.addAll([
            {
              'name': 'PT Kreatif Visual Nusantara',
              'cat': 'Mitra Industri IDUKA • Studio Animasi',
              'rating': '5.0',
              'verified': true,
              'phone': '081289123401',
              'email': 'partner@kreatifvisual.co.id',
              'website': 'https://kreatifvisual.co.id',
            },
            {
              'name': 'Lab Inovasi Digital & Multimedia',
              'cat': 'Sentra Riset Terapan • Kampus Utama',
              'rating': '4.9',
              'verified': true,
              'phone': '081378234502',
              'email': 'lab-inovasi@kampus.ac.id',
              'website': '',
            },
            {
              'name': 'Dinas Koperasi & UMKM Provinsi',
              'cat': 'Instansi Pemerintah Rekanan Pengabdian',
              'rating': '4.8',
              'verified': true,
              'phone': '081567345603',
              'email': 'kerjasama@diskopumkm.go.id',
              'website': '',
            },
          ]);
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
            child: InteractiveDashboardSearchBar(
              user: widget.user,
              isDark: isDark,
              accentColor: _brandBlue,
              placeholder: _isInstitution
                  ? 'Cari talenta mahasiswa, prodi, mitra IDUKA, atau tender...'
                  : 'Cari kreator, vendor mitra, atau paket proyek korporat...',
            ),
          ),
          const SizedBox(width: 14),
          AppBarBadgeWidget(
            icon: Icons.notifications_none_outlined,
            isDark: isDark,
            accentColor: _brandBlue,
          ),
          const SizedBox(width: 6),
          AppBarBadgeWidget(
            icon: Icons.chat_bubble_outline,
            isDark: isDark,
            accentColor: _brandBlue,
          ),
          const SizedBox(width: 10),
          AppBarThemeToggle(
            isDark: isDark,
            btnKey: _themeBtnKey,
            accentColor: _brandBlue,
          ),
          const SizedBox(width: 8),
          AppBarProfileBadge(
            user: widget.user,
            isDark: isDark,
            accentColor: _brandBlue,
            customSubRole: _isInstitution ? 'Institusi / Lembaga' : 'Corporate / Perusahaan',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(
                  user: widget.user,
                  onUserUpdated: widget.onUserUpdated,
                  onLogout: () {},
                ),
              ),
            ),
          ),
        ],
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                _isInstitution ? '#KolaborasiHariIniGenerasiMasaDepan' : '#KolaborasiMembawaDampak',
                                style: const TextStyle(
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
                          _isInstitution
                              ? 'Sekolah • Perguruan Tinggi • Vokasi • Riset • IDUKA'
                              : 'Brand • Portofolio • Instansi • BUMN • Swasta',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isInstitution ? 'Role Sekolah / Perguruan Tinggi' : 'Role Corporate / Perusahaan',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isInstitution
                          ? 'Menghubungkan Talenta, Ilmu Pengetahuan dan Peluang untuk Masa Depan yang Lebih Baik'
                          : 'Temukan Talenta, Bangun Kolaborasi, Wujudkan Proyek',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isInstitution
                          ? 'Kreavana membantu sekolah dan perguruan tinggi membangun jejaring, menemukan peluang kolaborasi, serta mengembangkan potensi mahasiswa, pendidik, dan institusi.'
                          : 'Kreavana membantu perusahaan menemukan kreator, talenta, dan mitra terbaik untuk mendukung kebutuhan komunikasi, pemasaran, event, dan proyek kreatif lainnya.',
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
                child: Icon(
                  _isInstitution ? Icons.school_rounded : Icons.apartment_rounded,
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
              HoverLiftButton(
                borderRadius: BorderRadius.circular(12),
                glowColor: Colors.white,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => BuatKebutuhanScreen(user: widget.user)),
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: Text(_isInstitution ? 'Buka Tender / Riset / Magang' : 'Buka Tender / RFP Proyek'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E3A8A),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              HoverLiftButton(
                borderRadius: BorderRadius.circular(12),
                glowColor: Colors.white,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ExploreScreen(user: widget.user)),
                  ),
                  icon: const Icon(Icons.search_rounded, size: 18, color: Colors.white),
                  label: Text(_isInstitution ? 'Cari Talenta Mahasiswa & IDUKA' : 'Cari & Pilih Kreator/Mitra', style: const TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
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
      {'title': _isInstitution ? 'Ikhtisar & Tata Kelola' : 'Ikhtisar & Alur Kerja', 'icon': Icons.dashboard_customize_rounded},
      {'title': _isInstitution ? 'Ekosistem Kolaborasi' : 'Ekosistem 5 Pilar', 'icon': Icons.hub_rounded},
      {'title': _isInstitution ? 'Cari Talenta & Mahasiswa' : 'Cari Talenta & Vendor', 'icon': Icons.people_alt_rounded},
      {'title': _isInstitution ? 'Tender, Magang & Riset' : 'Tender & Pengadaan (RFP)', 'icon': Icons.assignment_rounded},
    ];

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
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
    final corporateSteps = [
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

    final institutionSteps = [
      {
        'num': '1',
        'title': '1. Registrasi Institusi',
        'sub': 'Data institusi, prodi, kontak resmi',
        'desc': 'Pendaftaran identitas resmi sekolah/kampus, NPSN/PDDikti, daftar fakultas/jurusan, staf penanggung jawab (BKK/LPPM), dan verifikasi admin.',
        'icon': Icons.domain_verification_rounded,
        'actionLabel': 'Kelola Profil Institusi',
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
        'title': '2. Verifikasi & Aktivasi',
        'sub': 'Validasi data & akreditasi resmi',
        'desc': 'Validasi keabsahan data lembaga, status akreditasi BAN-PT/LAM, legalitas kemitraan, dan aktivasi lencana resmi Institusi Pendidikan Kreavana.',
        'icon': Icons.verified_user_rounded,
        'actionLabel': 'Cek Status Verifikasi',
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
        'num': '3',
        'title': '3. Lengkapi Profil',
        'sub': 'Program studi, keunggulan, riset',
        'desc': 'Input jurusan keunggulan, profil laboratorium, fokus riset terapan kampus, sarana prasarana, serta inventarisasi kebutuhan kerja sama IDUKA.',
        'icon': Icons.school_rounded,
        'actionLabel': 'Lengkapi Program Studi & Riset',
        'action': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InstitutionWorkspaceScreen(
                  user: widget.user,
                  resourceType: 'study_programs',
                  onUserUpdated: widget.onUserUpdated,
                ),
              ),
            ),
      },
      {
        'num': '4',
        'title': '4. Akses Peluang',
        'sub': 'Magang, proyek, event, kolaborasi',
        'desc': 'Akses peluang penempatan magang industri IDUKA, proyek riset komersial, agenda perlombaan/expo, serta publikasi tender pengadaan kampus.',
        'icon': Icons.explore_rounded,
        'actionLabel': 'Jelajahi Peluang & Magang',
        'action': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ExploreScreen(user: widget.user)),
            ),
      },
      {
        'num': '5',
        'title': '5. Kolaborasi & Implementasi',
        'sub': 'Terhubung industri, mitra, komunitas',
        'desc': 'Terhubung langsung dengan mitra IDUKA, penandatanganan nota kesepahaman (MoU), penerbitan SPK digital terproteksi escrow, dan monitoring magang.',
        'icon': Icons.handshake_rounded,
        'actionLabel': 'Mulai Kolaborasi IDUKA',
        'action': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BuatKebutuhanScreen(user: widget.user)),
            ),
      },
      {
        'num': '6',
        'title': '6. Evaluasi & Pengembangan',
        'sub': 'Laporan, portofolio, reputasi',
        'desc': 'Pelaporan berkala penyerapan magang, showcase karya siswa, evaluasi kinerja timbal balik, rating bintang, dan peningkatan akreditasi institusi.',
        'icon': Icons.insights_rounded,
        'actionLabel': 'Buka Laporan & Evaluasi',
        'action': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InstitutionWorkspaceScreen(
                  user: widget.user,
                  resourceType: 'reports',
                  onUserUpdated: widget.onUserUpdated,
                ),
              ),
            ),
      },
    ];

    final steps = _isInstitution ? institutionSteps : corporateSteps;

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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isInstitution ? 'Alur Kerja Role Sekolah / Perguruan Tinggi' : 'Alur Kerja Corporate / Perusahaan',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isInstitution
                                ? '6 Tahapan sistematis untuk membangun kemitraan, penyaluran magang, dan hilirisasi karya.'
                                : '6 Tahapan terstandarisasi untuk kolaborasi proyek yang aman, transparan, dan terukur.',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
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
    final corporatePillars = [
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
        'color': const Color(0xFF2563EB),
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

    final institutionPillars = [
      {
        'name': 'Sekolah / Perguruan Tinggi',
        'desc': 'Hubungan Kemitraan Strategis Kampus dengan Kreavana',
        'color': _brandBlue,
        'icon': Icons.school_rounded,
        'got': [
          'Akses ke proyek riil dan kebutuhan industri',
          'Penyaluran magang dan kerja untuk siswa/mahasiswa',
          'Peluang kolaborasi riset, event, dan kompetisi',
          'Visibilitas dan reputasi institusi meningkat',
          'Kemudahan dalam mencari mitra kolaborasi',
        ],
        'give': [
          'Talenta muda potensial dan siap berkembang',
          'Keterlibatan dalam program dan inisiatif Kreavana',
          'Kolaborasi dalam riset, inovasi, dan kegiatan edukatif',
          'Data dan wawasan terkait dunia pendidikan',
        ],
      },
      {
        'name': 'Mahasiswa / Siswa',
        'desc': 'Talenta Muda, Praktikan Magang, & Kreator Kampus',
        'color': const Color(0xFF0284C7),
        'icon': Icons.person_outline_rounded,
        'got': [
          'Portofolio riil dari proyek nyata',
          'Pengalaman kerja dan magang di industri',
          'Akses ke mentor dan profesional industri',
          'Peluang kerja sama lintas bidang',
        ],
        'give': [
          'Kreativitas dan ide-ide segar lintas bidang',
          'Keterlibatan aktif dalam proyek dan kompetisi',
          'Kontribusi pada ekosistem kreatif Kreavana',
        ],
      },
      {
        'name': 'Dosen / Pendidik',
        'desc': 'Akademisi, Peneliti Terapan, & Dosen Pembimbing',
        'color': const Color(0xFF7C3AED),
        'icon': Icons.psychology_rounded,
        'got': [
          'Kolaborasi riset terapan dengan industri',
          'Studi kasus nyata untuk bahan ajar perkuliahan',
          'Jaringan profesional yang lebih luas',
          'Peluang sebagai mentor atau konsultan industri',
        ],
        'give': [
          'Bimbingan akademik dan transfer ilmu pengetahuan',
          'Rekomendasi talenta terbaik kampus',
          'Kontribusi pemikiran dalam riset dan kurikulum industri',
        ],
      },
      {
        'name': 'Industri / Mitra (IDUKA)',
        'desc': 'Perusahaan, Dunia Usaha, Startup, & BUMN Rekanan',
        'color': const Color(0xFFEA580C),
        'icon': Icons.business_center_rounded,
        'got': [
          'Akses langsung ke talenta muda terbaik siap kerja',
          'Solusi inovatif dari riset akademis kampus',
          'Biaya rekrutmen dan riset lebih efisien',
          'Citra positif melalui dukungan terhadap dunia pendidikan',
        ],
        'give': [
          'Proyek riil, studi kasus, dan tantangan industri',
          'Peluang kuota magang dan rekrutmen kerja',
          'Pendanaan riset, sponsorship, dan fasilitas',
          'Masukan untuk kurikulum berbasis industri',
        ],
      },
      {
        'name': 'Mitra Vendor & Sarpras',
        'desc': 'Penyedia Alat Lab, Studio Produksi, & Sarana Kampus',
        'color': const Color(0xFF059669),
        'icon': Icons.handshake_rounded,
        'got': [
          'Peluang pengadaan sarana laboratorium & alat studio',
          'Kerja sama produksi karya bersama kampus',
          'Akses talenta asisten produksi & magang terampil',
        ],
        'give': [
          'Penyediaan teknologi produksi & alat standar industri',
          'Layanan pengerjaan & pemeliharaan sarpras bergaransi',
        ],
      },
    ];

    final pillars = _isInstitution ? institutionPillars : corporatePillars;

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isInstitution
                          ? 'Ekosistem Kolaborasi Sekolah & Perguruan Tinggi'
                          : 'Ekosistem & Sinergi Multi-Pilar Kreavana',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isInstitution
                          ? 'Menghubungkan potensi & peluang antara institusi pendidikan, mahasiswa/dosen, IDUKA, vendor, dan komunitas.'
                          : 'Pusat sinergi yang mempertemukan perusahaan dengan kreator, vendor, sponsor, dan ekosistem.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              },
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
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
                              _isInstitution ? 'Manfaat yang Diberikan ke Kreavana & Ekosistem' : 'Manfaat yang Diberikan ke Kreavana',
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
    final corporateValues = [
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
        'color': _brandBlue,
      },
    ];

    final institutionValues = [
      {
        'title': 'Peningkatan Kualitas Lulusan',
        'desc': 'Lulusan lebih siap kerja dengan pengalaman proyek dan portofolio nyata.',
        'icon': Icons.school_rounded,
        'color': _brandBlue,
      },
      {
        'title': 'Jejaring Lebih Luas',
        'desc': 'Terhubung langsung dengan industri, kreator profesional, dan mitra IDUKA.',
        'icon': Icons.hub_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'Inovasi & Riset',
        'desc': 'Hasil riset terapan kampus dapat dimanfaatkan langsung oleh dunia industri.',
        'icon': Icons.lightbulb_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'title': 'Reputasi Institusi',
        'desc': 'Daya saing, akreditasi, dan pengakuan publik sekolah/perguruan tinggi meningkat.',
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFF7C3AED),
      },
    ];

    final values = _isInstitution ? institutionValues : corporateValues;

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isInstitution
                          ? 'Dampak yang Dirasakan Sekolah & Perguruan Tinggi'
                          : 'Kenapa Bergabung dengan Kreavana?',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isInstitution
                          ? '"Bersama Kreavana, Pendidikan Lebih Bermakna • Lebih dari Sekadar Platform, Ini Adalah Ekosistem"'
                          : '"Karena di sini, kebutuhan bertemu dengan potensi, dan setiap kolaborasi menciptakan nilai."',
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
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
              final itemWidth = (width - (crossAxisCount - 1) * 12) / crossAxisCount;
              final targetHeight = width > 850 ? 124.0 : (width > 480 ? 116.0 : 96.0);
              final childAspectRatio = (itemWidth / targetHeight).clamp(0.8, 3.8);

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
                      mainAxisSize: MainAxisSize.min,
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
                              height: 1.3,
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
        final isWide = constraints.maxWidth > 800;
        final count = isWide ? 4 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isWide ? 1.35 : 1.45,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          m['label'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
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
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      m['value'] as String,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m['sub'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
              Text(_isInstitution ? 'Program Kolaborasi & Magang Aktif' : 'Proyek Aktif & Berjalan', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _isInstitution
                        ? InstitutionWorkspaceScreen(
                            user: widget.user,
                            resourceType: 'study_programs',
                            onUserUpdated: widget.onUserUpdated,
                          )
                        : ProyekSayaScreen(user: widget.user),
                  ),
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
                  Text(_isInstitution ? 'Penelusuran Talenta Mahasiswa & Mitra IDUKA' : 'Rekomendasi Kreator & Vendor Terverifikasi', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ExploreScreen(user: widget.user)),
                    ),
                    icon: const Icon(Icons.explore_rounded, size: 16),
                    label: Text(_isInstitution ? 'Buka Direktori Talenta' : 'Buka Direktori Lengkap'),
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
                        onPressed: () => _contactPartner(c),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          side: BorderSide(color: _brandBlue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text(
                          'Hubungi',
                          style: TextStyle(
                            fontSize: 11,
                            color: _brandBlue,
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
                  Text(_isInstitution ? 'Daftar Pengadaan, Magang & Riset Terapan (RFP)' : 'Daftar Pengadaan & Tender Proyek (RFP)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BuatKebutuhanScreen(user: widget.user)),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(_isInstitution ? 'Buka Program / Tender Baru' : 'Buka Tender Baru'),
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
                    _isInstitution ? 'Kreavana — Kolaborasi Hari Ini, Generasi Masa Depan' : 'Kreavana — Lebih dari Sekadar Platform, Ini Adalah Ekosistem',
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

  // ── HUBUNGI MITRA LANGSUNG KE NOMOR ───────────────────────────────────────
  Future<void> _contactPartner(Map<String, dynamic> c) async {
    final phone = (c['phone'] ?? '').toString().trim();
    if (phone.isEmpty) {
      if (mounted) {
        AppSweetAlert.warning(
          context,
          'Nomor kontak tidak tersedia.',
          title: 'Kontak Tidak Tersedia',
        );
      }
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final telUri = Uri.parse('tel:$cleanPhone');

    // On mobile devices (Android / iOS), directly launch native dialer
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        if (await canLaunchUrl(telUri)) {
          final launched = await launchUrl(telUri, mode: LaunchMode.externalApplication);
          if (launched) return;
        }
      } catch (_) {}
    }

    // On Desktop / Web or if dialer couldn't open directly, show direct number modal
    if (!mounted) return;
    _showDirectPhoneDialog(c, cleanPhone);
  }

  void _showDirectPhoneDialog(Map<String, dynamic> c, String cleanPhone) {
    final name = c['name']?.toString() ?? 'Mitra B2B';
    final cat = c['cat']?.toString() ?? 'Mitra Terverifikasi';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String waNumber = cleanPhone.replaceAll(RegExp(r'\D'), '');
    if (waNumber.startsWith('0')) {
      waNumber = '62${waNumber.substring(1)}';
    } else if (!waNumber.startsWith('62')) {
      waNumber = '62$waNumber';
    }

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.cardBg : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _brandBlue.withValues(alpha: 0.15),
                child: Icon(Icons.phone_in_talk_rounded, size: 20, color: _brandBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      cat,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.perm_phone_msg_rounded, size: 22, color: _brandBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nomor Telepon Langsung', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 2),
                          SelectableText(
                            cleanPhone,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Salin Nomor',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: cleanPhone));
                        Navigator.pop(dialogCtx);
                        AppSweetAlert.success(
                          context,
                          'Nomor $cleanPhone berhasil disalin ke clipboard',
                          title: 'Nomor Disalin',
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(dialogCtx);
                        final uri = Uri.parse('tel:$cleanPhone');
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (_) {
                          Clipboard.setData(ClipboardData(text: cleanPhone));
                          if (mounted) {
                            AppSweetAlert.info(
                              context,
                              'Nomor $cleanPhone telah disalin ke clipboard.',
                              title: 'Nomor Disalin',
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.call_rounded, size: 16),
                      label: const Text('Panggil', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: _brandBlue),
                        foregroundColor: _brandBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(dialogCtx);
                        final waUri = Uri.parse('https://wa.me/$waNumber');
                        try {
                          await launchUrl(waUri, mode: LaunchMode.externalApplication);
                        } catch (_) {
                          Clipboard.setData(ClipboardData(text: cleanPhone));
                          if (mounted) {
                            AppSweetAlert.warning(
                              context,
                              'Membuka WhatsApp gagal. Nomor $cleanPhone disalin ke clipboard.',
                              title: 'Gagal Buka WhatsApp',
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
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
}
