import '../../../services/badge_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../services/api_service.dart';
import '../../../services/job_contract_service.dart';
import '../../../services/theme_transition_service.dart';
import '../../../screens/global_search_screen.dart';
import '../../../models/user_model.dart';
import '../../../screens/buat_kebutuhan_screen.dart';
import '../../../screens/explore_screen.dart';
import '../../../screens/notifications_screen.dart';
import '../../../screens/direct_message_screen.dart';
import '../../../screens/institution_workspace_screen.dart';
import '../../../screens/tim_hak_akses_screen.dart';
import '../../../screens/agenda_screen.dart';
import '../../../screens/proyek_saya_screen.dart';
import '../../../screens/peluang_proyek_screen.dart';
import '../../../widgets/waving_hand_emoji.dart';

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

class _SchoolDashboardScreenState extends State<SchoolDashboardScreen> {
  final GlobalKey _themeBtnKey = GlobalKey();

  static const Color _schoolBlue = Color(0xFF4F46E5);
  static const Color _schoolGreen = Color(0xFF10B981);

  bool _isLoading = true;
  int _selectedQuadrantIndex = 0;
  List<Map<String, dynamic>> _resources = [];
  List<Map<String, dynamic>> _recentProjects = [];
  List<Map<String, dynamic>> _recommendedVendors = [];
  List<Map<String, dynamic>> _activityFeed = [];
  List<Map<String, dynamic>> _upcomingAgenda = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        ApiService.get('institution/resources'),
        ApiService.get('client-dashboard/overview?role_type=creator'),
        JobContractService.getUserContracts(),
      ]);

      if (!mounted) return;

      final resResources = results[0] as Map<String, dynamic>;
      final resOverview = results[1] as Map<String, dynamic>;
      final contracts = results[2] as List;

      // 1. Process Institution Resources
      final List<Map<String, dynamic>> loadedResources = [];
      if (resResources['status'] == true && resResources['data'] is List) {
        for (final item in resResources['data']) {
          if (item is Map) {
            loadedResources.add(Map<String, dynamic>.from(item));
          }
        }
      }

      // 2. Process Recent Projects (Tenders / Contracts)
      final List<Map<String, dynamic>> loadedProjects = [];
      final tenders = loadedResources.where((r) => r['resource_type'] == 'tenders').toList();
      for (final t in tenders.take(4)) {
        loadedProjects.add({
          'id': t['id']?.toString() ?? '',
          'title': t['title']?.toString() ?? 'Program Magang',
          'type': t['description']?.toString() ?? 'Program Kolaborasi Industri',
          'status': (t['status'] == 'open' || t['status'] == 'published') ? 'Aktif' : 'Selesai',
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

      // 3. Process Overview (Vendors & Activity)
      final List<Map<String, dynamic>> loadedVendors = [];
      final List<Map<String, dynamic>> loadedActivities = [];
      if (resOverview['status'] == true && resOverview['data'] is Map) {
        final data = resOverview['data'] as Map;
        final rawVendors = data['vendor_recommendations'];
        if (rawVendors is List) {
          for (final v in rawVendors.take(5)) {
            if (v is Map) {
              loadedVendors.add(Map<String, dynamic>.from(v));
            }
          }
        }

        final rawActivities = data['activity_feed'];
        if (rawActivities is List) {
          for (final a in rawActivities.take(5)) {
            if (a is Map) {
              loadedActivities.add(Map<String, dynamic>.from(a));
            }
          }
        }
      }

      // 4. Process Agenda / Deadlines (Rentang Mulai s/d Akhir Lengkap)
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
        _recommendedVendors = loadedVendors;
        _activityFeed = loadedActivities;
        _upcomingAgenda = loadedAgenda;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _tendersCount => _resources.where((r) => r['resource_type'] == 'tenders').length;
  int get _partnersCount => _resources.where((r) => r['resource_type'] == 'partners').length;
  int get _studyProgramsCount => _resources.where((r) => r['resource_type'] == 'study_programs').length;
  int get _talentsCount => _resources.where((r) => r['resource_type'] == 'talents').length;
  int get _showcasesCount => _resources.where((r) => r['resource_type'] == 'showcases').length;
  int get _membersCount => _resources.where((r) => r['resource_type'] == 'members').length + 1; // +1 Owner

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      appBar: _buildAppBar(isDark),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _schoolBlue),
            )
          : RefreshIndicator(
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
              RepaintBoundary(child: _buildHeroBanner(isDark)),
              const SizedBox(height: 24),
              RepaintBoundary(child: _buildMetricCards(isDark)),
              const SizedBox(height: 24),
              RepaintBoundary(child: _buildEcosystemAndWorkflowSection(isDark)),
              const SizedBox(height: 24),
              RepaintBoundary(child: _buildTopThreeColumns(isDark)),
              const SizedBox(height: 24),
              RepaintBoundary(child: _buildBottomThreeColumns(isDark)),
            ],
          ),
        ),
      ),
    );
  }

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
                  color: isDark
                      ? const Color(0xFF1A1830)
                      : Colors.grey.shade100,
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
                        'Cari program, mitra industri, atau portofolio siswa...',
                        style: TextStyle(
                          fontSize: 13,
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
                backgroundColor: _schoolBlue.withValues(alpha: 0.1),
                child: const Icon(Icons.school, color: _schoolBlue, size: 20),
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
                    'Sekolah / Lembaga Pendidikan',
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

  Widget _buildHeroBanner(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 640;

        final textBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Selamat datang, ${widget.user.name}!',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const WavingHandEmoji(fontSize: 24),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Kelola peluang, program magang PKL, kemitraan industri, dan portofolio karya siswa secara langsung di Kreavana.',
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              ),
            ),
          ],
        );

        final actionBtn = ElevatedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BuatKebutuhanScreen(user: widget.user),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Buka Program / Magang'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _schoolBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              textBlock,
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: actionBtn),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: textBlock),
            const SizedBox(width: 24),
            actionBtn,
          ],
        );
      },
    );
  }

  Widget _buildMetricCards(bool isDark) {
    final metrics = [
      {
        'label': 'Program & Magang',
        'value': '$_tendersCount Program',
        'sub': _tendersCount > 0 ? 'Tersedia di pengadaan' : 'Belum ada program',
        'icon': Icons.work_outline_rounded,
        'color': _schoolBlue,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstitutionWorkspaceScreen(
              user: widget.user,
              resourceType: 'tenders',
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
        ),
      },
      {
        'label': 'Mitra Industri Aktif',
        'value': '$_partnersCount Mitra',
        'sub': _partnersCount > 0 ? 'Kerjasama aktif' : 'Belum ada mitra',
        'icon': Icons.diversity_3_rounded,
        'color': _schoolGreen,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstitutionWorkspaceScreen(
              user: widget.user,
              resourceType: 'partners',
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
        ),
      },
      {
        'label': 'Program Studi & Riset',
        'value': '$_studyProgramsCount Prodi',
        'sub': _studyProgramsCount > 0 ? 'Prodi terdaftar' : 'Belum ditambahkan',
        'icon': Icons.school_rounded,
        'color': const Color(0xFF6366F1),
        'onTap': () => Navigator.push(
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
        'label': 'Talenta Mahasiswa',
        'value': '$_talentsCount Talenta',
        'sub': _talentsCount > 0 ? 'Siap magang & kerja' : 'Belum ada siswa',
        'icon': Icons.badge_rounded,
        'color': const Color(0xFFEC4899),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstitutionWorkspaceScreen(
              user: widget.user,
              resourceType: 'talents',
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
        ),
      },
      {
        'label': 'Portofolio Siswa',
        'value': '$_showcasesCount Karya',
        'sub': _showcasesCount > 0 ? 'Karya siap industri' : 'Belum diunggah',
        'icon': Icons.palette_rounded,
        'color': const Color(0xFF8B5CF6),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstitutionWorkspaceScreen(
              user: widget.user,
              resourceType: 'showcases',
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
        ),
      },
      {
        'label': 'Tim & Hak Akses',
        'value': '$_membersCount Staf',
        'sub': 'Kelola pengelola sekolah',
        'icon': Icons.group_rounded,
        'color': const Color(0xFFF59E0B),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TimHakAksesScreen(
              user: widget.user,
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
        ),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1050;
        final isMedium = constraints.maxWidth > 650 && !isWide;

        Widget buildCard(Map<String, dynamic> m) {
          return InkWell(
            onTap: m['onTap'] as VoidCallback?,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardBg : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                ),
                boxShadow: isDark
                    ? null
                    : [
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
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (m['color'] as Color).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      (m['icon'] as IconData?) ?? Icons.image_outlined,
                      color: m['color'] as Color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    m['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    m['value'] as String,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
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
            ),
          );
        }

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: metrics.map((m) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: buildCard(m),
                ),
              );
            }).toList(),
          );
        }

        final cardWidth = isMedium
            ? (constraints.maxWidth - 24) / 3
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: metrics.map((m) {
            return SizedBox(
              width: cardWidth,
              child: buildCard(m),
            );
          }).toList(),
        );
      },
    );
  }

  // ── SEKSI EKOSISTEM & ALUR KERJA ROLE SEKOLAH / PERGURUAN TINGGI ───────────
  Widget _buildEcosystemAndWorkflowSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? AppTheme.inputBorder
              : const Color(0xFF4F46E5).withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEcosystemHeaderBanner(isDark),
          const SizedBox(height: 24),
          _buildWorkflowPipelineCards(isDark),
          const SizedBox(height: 24),
          _buildHubAndQuadrantsMatrix(isDark),
          const SizedBox(height: 24),
          _buildImpactMetricsRow(isDark),
        ],
      ),
    );
  }

  Widget _buildEcosystemHeaderBanner(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 750;

        final badgeTagline = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 14),
              SizedBox(width: 6),
              Text(
                'Kolaborasi Hari Ini, Generasi Masa Depan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.hub_outlined,
                    color: Color(0xFF4F46E5),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Role Sekolah / Perguruan Tinggi',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Menghubungkan Talenta, Ilmu Pengetahuan dan Peluang untuk Masa Depan yang Lebih Baik',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Kreavana membantu sekolah dan perguruan tinggi membangun jejaring, menemukan peluang kolaborasi, serta mengembangkan potensi mahasiswa, pendidik, dan institusi.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
              ),
            ),
          ],
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 12),
              badgeTagline,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 20),
            badgeTagline,
          ],
        );
      },
    );
  }

  Widget _buildWorkflowPipelineCards(bool isDark) {
    final steps = [
      {
        'num': '1',
        'title': 'Registrasi Institusi',
        'desc': 'Data institusi, program studi, kontak, dan verifikasi admin',
        'icon': Icons.how_to_reg_outlined,
        'status': 'Terdaftar',
        'color': const Color(0xFF2563EB),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstitutionWorkspaceScreen(
              user: widget.user,
              resourceType: 'documents',
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
        ),
      },
      {
        'num': '2',
        'title': 'Verifikasi & Aktivasi',
        'desc': 'Validasi data resmi dan akreditasi lembaga',
        'icon': Icons.verified_outlined,
        'status': 'Terverifikasi',
        'color': const Color(0xFF10B981),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TimHakAksesScreen(
              user: widget.user,
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
        ),
      },
      {
        'num': '3',
        'title': 'Lengkapi Profil',
        'desc': 'Program studi, keunggulan riset, dan kebutuhan aktif',
        'icon': Icons.edit_note_rounded,
        'status': '$_studyProgramsCount Prodi',
        'color': const Color(0xFF6366F1),
        'onTap': () => Navigator.push(
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
        'title': 'Akses Peluang',
        'desc': 'Magang, proyek, event kolaborasi, dan program khusus',
        'icon': Icons.travel_explore_rounded,
        'status': '$_tendersCount Peluang',
        'color': const Color(0xFFF59E0B),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BuatKebutuhanScreen(user: widget.user),
          ),
        ),
      },
      {
        'num': '5',
        'title': 'Kolaborasi & Implementasi',
        'desc': 'Terhubung dengan industri, mitra IDUKA, dan komunitas',
        'icon': Icons.handshake_outlined,
        'status': '$_partnersCount Mitra',
        'color': const Color(0xFFEA580C),
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstitutionWorkspaceScreen(
              user: widget.user,
              resourceType: 'partners',
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
        ),
      },
      {
        'num': '6',
        'title': 'Evaluasi & Pengembangan',
        'desc': 'Laporan berkala, portofolio karya, reputasi & akreditasi',
        'icon': Icons.assessment_outlined,
        'status': 'Akuntabel',
        'color': const Color(0xFF8B5CF6),
        'onTap': () => Navigator.push(
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.alt_route_rounded,
                color: Color(0xFF0284C7),
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Alur Kerja Role Sekolah / Perguruan Tinggi',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 950;
            final isTablet = constraints.maxWidth > 580 && !isDesktop;

            Widget buildStepCard(Map<String, dynamic> step) {
              final col = step['color'] as Color;
              return InkWell(
                onTap: step['onTap'] as VoidCallback?,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark2 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.inputBorder
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: col,
                            child: Text(
                              step['num'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              step['title'] as String,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            (step['icon'] as IconData?) ?? Icons.chevron_right,
                            size: 16,
                            color: col,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        step['desc'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: isDark
                              ? AppTheme.textMuted
                              : Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          step['status'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            color: col,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (isDesktop) {
              return Row(
                children: steps.map((s) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: buildStepCard(s),
                    ),
                  );
                }).toList(),
              );
            }

            final itemWidth = isTablet
                ? (constraints.maxWidth - 20) / 3
                : (constraints.maxWidth - 10) / 2;

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: steps.map((s) {
                return SizedBox(width: itemWidth, child: buildStepCard(s));
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHubAndQuadrantsMatrix(bool isDark) {
    final quadrants = [
      {
        'title': 'Sekolah / Perguruan Tinggi',
        'subtitle': '(Instansi Pendidikan)',
        'color': const Color(0xFF6D28D9),
        'icon': Icons.school_outlined,
        'gets': [
          'Akses ke peluang magang, proyek penelitian, dan kolaborasi industri',
          'Penguatan jejaring dengan dunia usaha dan komunitas kreatif',
          'Peningkatan reputasi dan daya saing institusi (akreditasi)',
          'Sarana promosi kegiatan dan prestasi mahasiswa/dosen',
        ],
        'gives': [
          'Data profil institusi, program studi, dan keunggulan',
          'Informasi kebutuhan riset, SDM, dan proyek kolaborasi',
          'Rekomendasi program, event, dan talenta unggulan',
          'Kontribusi dalam ekosistem pendidikan dan kreatif',
        ],
        'primaryAction': 'Kelola Program Studi',
        'onPrimary': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstitutionWorkspaceScreen(
              user: widget.user,
              resourceType: 'study_programs',
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
        ),
        'secondaryAction': 'Tender Kampus',
        'onSecondary': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstitutionWorkspaceScreen(
              user: widget.user,
              resourceType: 'tenders',
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
        ),
      },
      {
        'title': 'Mahasiswa & Dosen',
        'subtitle': '(Civitas Academica & Talenta)',
        'color': const Color(0xFFBE123C),
        'icon': Icons.groups_outlined,
        'gets': [
          'Akses ke peluang magang, proyek, dan perlombaan',
          'Pengembangan keterampilan dan portofolio terverifikasi',
          'Jaringan profesional dan bimbingan mentor industri',
          'Pengalaman nyata di dunia kerja profesional',
        ],
        'gives': [
          'Profil, minat, keahlian, dan karya portofolio digital',
          'Partisipasi aktif dalam kegiatan, expo, dan event',
          'Umpan balik evaluasi dan ide kreatif inovatif',
          'Kontribusi regenerasi talenta muda dalam ekosistem',
        ],
        'primaryAction': 'Penelusuran Talenta',
        'onPrimary': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstitutionWorkspaceScreen(
              user: widget.user,
              resourceType: 'talents',
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
        ),
        'secondaryAction': 'Portofolio Siswa',
        'onSecondary': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstitutionWorkspaceScreen(
              user: widget.user,
              resourceType: 'showcases',
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
        ),
      },
      {
        'title': 'Mitra / Vendor',
        'subtitle': '(Perusahaan, EO/WO, Jasa Kreatif)',
        'color': const Color(0xFFEA580C),
        'icon': Icons.handshake_outlined,
        'gets': [
          'Akses ke proyek dan tender resmi dari sekolah/kampus',
          'Promosi katalog layanan, peralatan, dan produk kreatif',
          'Kesempatan membangun kemitraan jangka panjang (MoU)',
          'Ekspansi pasar di kalangan instansi pendidikan',
        ],
        'gives': [
          'Informasi layanan, portofolio karya, dan kapasitas tim',
          'Penawaran khusus institusi dan skema kemitraan',
          'Dukungan sumber daya & alat untuk program pendidikan',
          'Testimoni dan hasil kerja sama terverifikasi',
        ],
        'primaryAction': 'Direktori Mitra & MoU',
        'onPrimary': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstitutionWorkspaceScreen(
              user: widget.user,
              resourceType: 'partners',
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
        ),
        'secondaryAction': 'Dokumen Resmi',
        'onSecondary': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstitutionWorkspaceScreen(
              user: widget.user,
              resourceType: 'documents',
              onUserUpdated: widget.onUserUpdated,
            ),
          ),
        ),
      },
      {
        'title': 'Industri & Dunia Usaha',
        'subtitle': '(Mitra IDUKA & Corporate)',
        'color': const Color(0xFF0F766E),
        'icon': Icons.business_outlined,
        'gets': [
          'Akses ke talenta muda berkualitas dan siap kerja',
          'Kesempatan riset terapan dan inovasi produk bersama',
          'Kegiatan rekrutmen efisien dan employer branding',
          'Kolaborasi program CSR dan pengembangan SDM unggul',
        ],
        'gives': [
          'Informasi kebutuhan talenta, riset, dan proyek industri',
          'Dukungan program magang PKL, sponsor, dan fasilitas',
          'Praktisi mengajar (Guest Lecture) dan mentor industri',
          'Testimoni, studi kasus industri nyata, dan sertifikasi',
        ],
        'primaryAction': 'Buka Program Magang',
        'onPrimary': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BuatKebutuhanScreen(user: widget.user),
          ),
        ),
        'secondaryAction': 'Jelajahi Proyek',
        'onSecondary': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PeluangProyekScreen(user: widget.user),
          ),
        ),
      },
    ];

    final currentQ = quadrants[_selectedQuadrantIndex];
    final activeColor = currentQ['color'] as Color;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark2 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.compare_arrows_rounded,
                  color: activeColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Matriks Nilai Timbal Balik Ekosistem Kolaborasi',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Quadrant Selector Tabs
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final tabWidgets = List.generate(quadrants.length, (idx) {
                final q = quadrants[idx];
                final isSelected = _selectedQuadrantIndex == idx;
                final col = q['color'] as Color;

                return InkWell(
                  onTap: () => setState(() => _selectedQuadrantIndex = idx),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? col
                          : (isDark ? AppTheme.cardBg : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? col
                            : (isDark
                                ? AppTheme.inputBorder
                                : Colors.grey.shade300),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: col.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          q['icon'] as IconData,
                          size: 16,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? AppTheme.textMuted
                                  : Colors.grey.shade700),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          q['title'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                    ? Colors.white
                                    : Colors.grey.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              });

              if (isNarrow) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tabWidgets,
                );
              }

              return Row(
                children: tabWidgets
                    .map((w) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: w,
                          ),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 18),
          // Dual Benefit Panels
          LayoutBuilder(
            builder: (context, constraints) {
              final isTwoCol = constraints.maxWidth > 700;

              Widget buildBenefitList(
                String header,
                IconData headerIcon,
                List<String> items,
                Color accent,
              ) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardBg : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(headerIcon, size: 18, color: accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              header,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 18),
                      ...items.map(
                        (txt) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: accent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  txt,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: isDark
                                        ? AppTheme.textMuted
                                        : Colors.grey.shade700,
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

              final panelGets = buildBenefitList(
                'Manfaat yang Didapat',
                Icons.card_giftcard_rounded,
                currentQ['gets'] as List<String>,
                const Color(0xFF10B981),
              );

              final panelGives = buildBenefitList(
                'Manfaat yang Diberikan ke Kreavana',
                Icons.volunteer_activism_rounded,
                currentQ['gives'] as List<String>,
                activeColor,
              );

              if (isTwoCol) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: panelGets),
                    const SizedBox(width: 14),
                    Expanded(child: panelGives),
                  ],
                );
              }

              return Column(
                children: [
                  panelGets,
                  const SizedBox(height: 12),
                  panelGives,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // Action Buttons Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: currentQ['onSecondary'] as VoidCallback?,
                icon: const Icon(Icons.arrow_outward_rounded, size: 16),
                label: Text(currentQ['secondaryAction'] as String),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: currentQ['onPrimary'] as VoidCallback?,
                icon: const Icon(Icons.navigate_next_rounded, size: 18),
                label: Text(currentQ['primaryAction'] as String),
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImpactMetricsRow(bool isDark) {
    final impacts = [
      {
        'title': 'Peningkatan Kualitas Lulusan',
        'desc': 'Portofolio proyek nyata & kompetensi industri',
        'icon': Icons.school_rounded,
        'color': const Color(0xFF6D28D9),
      },
      {
        'title': 'Jejaring Lebih Luas',
        'desc': 'Koneksi dunia usaha, industri, vendor & asosiasi',
        'icon': Icons.public_rounded,
        'color': const Color(0xFF2563EB),
      },
      {
        'title': 'Inovasi & Riset Berkelanjutan',
        'desc': 'Hilirisasi karya terapan mahasiswa & dosen',
        'icon': Icons.lightbulb_rounded,
        'color': const Color(0xFFEA580C),
      },
      {
        'title': 'Reputasi Institusi Meningkat',
        'desc': 'Peningkatan nilai akreditasi & rekognisi publik',
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFF10B981),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark2 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.track_changes_rounded,
                  color: Color(0xFFE11D48),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Dampak yang Dirasakan',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;

              Widget buildImpactCard(Map<String, dynamic> imp) {
                final col = imp['color'] as Color;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardBg : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.inputBorder
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(imp['icon'] as IconData, size: 20, color: col),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              imp['title'] as String,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              imp['desc'] as String,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark
                                    ? AppTheme.textMuted
                                    : Colors.grey.shade600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (isWide) {
                return Row(
                  children: impacts
                      .map((im) => Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: buildImpactCard(im),
                            ),
                          ))
                      .toList(),
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: impacts
                    .map((im) => SizedBox(
                          width: (constraints.maxWidth - 8) / 2,
                          child: buildImpactCard(im),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Bersama Kreavana, Pendidikan Lebih Bermakna',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFFBE123C),
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopThreeColumns(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 700) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _buildLineChartCard(isDark)),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: _buildDonutChartCard(isDark)),
          const SizedBox(width: 16),
          Expanded(flex: 3, child: _buildRecentProjectsCard(isDark)),
        ],
      );
    }
    return Column(
      children: [
        _buildLineChartCard(isDark),
        const SizedBox(height: 16),
        _buildDonutChartCard(isDark),
        const SizedBox(height: 16),
        _buildRecentProjectsCard(isDark),
      ],
    );
  }

  Widget _buildLineChartCard(bool isDark) {
    final tenders = _tendersCount.toDouble();
    final partners = _partnersCount.toDouble();
    final showcases = _showcasesCount.toDouble();
    final members = _membersCount.toDouble();

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Aktivitas Sumber Daya',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _schoolBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Data Realtime',
                  style: TextStyle(
                    fontSize: 10,
                    color: _schoolBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
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
                        final labels = ['Magang', 'Mitra', 'Karya', 'Tim'];
                        final idx = v.toInt();
                        if (idx >= 0 && idx < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
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
                    spots: [
                      FlSpot(0, tenders),
                      FlSpot(1, partners),
                      FlSpot(2, showcases),
                      FlSpot(3, members),
                    ],
                    isCurved: true,
                    color: _schoolBlue,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: _schoolBlue.withValues(alpha: 0.1),
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
    final total = (_tendersCount + _partnersCount + _showcasesCount + _membersCount);
    final hasData = total > 0;

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
          const Text(
            'Distribusi Program Sekolah',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: hasData
                    ? [
                        PieChartSectionData(
                          value: _tendersCount > 0 ? _tendersCount.toDouble() : 1,
                          color: _schoolBlue,
                          radius: 18,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: _partnersCount > 0 ? _partnersCount.toDouble() : 1,
                          color: _schoolGreen,
                          radius: 18,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: _showcasesCount > 0 ? _showcasesCount.toDouble() : 1,
                          color: const Color(0xFF8B5CF6),
                          radius: 18,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: _membersCount.toDouble(),
                          color: const Color(0xFFF59E0B),
                          radius: 18,
                          showTitle: false,
                        ),
                      ]
                    : [
                        PieChartSectionData(
                          value: 1,
                          color: Colors.grey.shade300,
                          radius: 18,
                          showTitle: false,
                        ),
                      ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildCatRow('Program & Magang', '$_tendersCount data', _schoolBlue),
          _buildCatRow('Mitra Industri', '$_partnersCount mitra', _schoolGreen),
          _buildCatRow('Karya Siswa', '$_showcasesCount portofolio', const Color(0xFF8B5CF6)),
          _buildCatRow('Tim Pengelola', '$_membersCount staf', const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _buildCatRow(String name, String val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 11))),
          Text(
            val,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentProjectsCard(bool isDark) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Program Terbaru',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                  );
                },
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_recentProjects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.work_history_outlined,
                      size: 32,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada program magang/proyek',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._recentProjects.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _schoolBlue.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.school_outlined,
                        color: _schoolBlue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['title']!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            p['type']!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _schoolGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        p['status']!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: _schoolGreen,
                          fontWeight: FontWeight.bold,
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

  Widget _buildBottomThreeColumns(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 700) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildActivityCard(isDark)),
          const SizedBox(width: 16),
          Expanded(child: _buildFavoriteVendorsCard(isDark)),
          const SizedBox(width: 16),
          Expanded(child: _buildCalendarAndRecs(isDark)),
        ],
      );
    }
    return Column(
      children: [
        _buildActivityCard(isDark),
        const SizedBox(height: 16),
        _buildFavoriteVendorsCard(isDark),
        const SizedBox(height: 16),
        _buildCalendarAndRecs(isDark),
      ],
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aktivitas Terbaru',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_activityFeed.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Belum ada aktivitas terbaru',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
              ),
            )
          else
            ..._activityFeed.map((act) {
              final title = act['title']?.toString() ?? 'Aktivitas sistem';
              final time = act['time']?.toString() ?? 'Baru saja';
              return _buildActItem(title, time);
            }),
        ],
      ),
    );
  }

  Widget _buildActItem(String title, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: _schoolBlue.withValues(alpha: 0.1),
            child: const Icon(Icons.school, color: _schoolBlue, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFavoriteVendorsCard(bool isDark) {
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
          const Text(
            'Kreator & Vendor Rekomendasi',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_recommendedVendors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Belum ada rekomendasi vendor',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
              ),
            )
          else
            ..._recommendedVendors.map(
              (v) {
                final name = v['name']?.toString() ?? 'Kreator';
                final cat = v['sub_role_label']?.toString() ?? v['category']?.toString() ?? 'Kreator';
                final rating = v['rating']?.toString() ?? '5.0';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _schoolBlue.withValues(alpha: 0.1),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'K',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _schoolBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              cat,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                      Text(
                        rating,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCalendarAndRecs(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
                'Kalender & Tenggat Mendatang',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              if (_upcomingAgenda.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Tidak ada tenggat mendatang',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ),
                )
              else
                ..._upcomingAgenda.map(
                  (cal) => _buildCalItem(
                    cal['date']!,
                    cal['title']!,
                    cal['time']!,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _schoolBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _schoolBlue.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tingkatkan Kolaborasi & Kemitraan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              const Text(
                'Temukan lebih banyak mitra industri dan studio magang terverifikasi di Kreavana.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExploreScreen(user: widget.user),
                  ),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: _schoolBlue),
                child: const Text(
                  'Jelajahi Mitra Industri',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalItem(String date, String title, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _schoolBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              date,
              style: const TextStyle(
                color: _schoolBlue,
                fontWeight: FontWeight.bold,
                fontSize: 11,
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
                ),
                Text(
                  time,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
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
