import 'package:flutter/foundation.dart';
import '../../../services/badge_service.dart';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../services/theme_transition_service.dart';
import '../../../screens/global_search_screen.dart';
import '../../../screens/notifications_screen.dart';
import '../../../screens/direct_message_screen.dart';
import '../../../screens/profile_screen.dart';
import '../../../models/user_model.dart';
import '../../../screens/explore_screen.dart';
import '../../../screens/peluang_proyek_screen.dart';
import '../../../screens/mitra_komunitas_screen.dart';
import '../../../screens/proyek_saya_screen.dart';
import '../../../screens/ulasan_reputasi_screen.dart';
import '../../../screens/creator_calendar_screen.dart';
import '../../../services/portfolio_service.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeleton/skeleton_grid.dart';

import '../../../models/opportunity_model.dart';
import '../../../models/job_contract.dart';
import '../../../services/job_contract_service.dart';
import '../services/dashboard_service.dart';

class CreatorGeneralDashboardScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel> onUserUpdated;

  const CreatorGeneralDashboardScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<CreatorGeneralDashboardScreen> createState() =>
      _CreatorGeneralDashboardScreenState();
}

class _CreatorGeneralDashboardScreenState
    extends State<CreatorGeneralDashboardScreen> {
  final GlobalKey _themeBtnKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _ecosystemKey = GlobalKey();

  static const Color _creatorPurple = Color(0xFF6366F1);
  static const Color _primaryColor = _creatorPurple;

  String _selectedEntityId = 'creator';

  List<PortfolioItemModel> _portfolioItems = [];
  bool _isLoadingPortfolio = true;

  List<Map<String, dynamic>> _realtimeMetrics = [];
  List<Map<String, dynamic>> _realtimeRecs = [];
  List<Map<String, dynamic>> _realtimeProjects = [];
  List<Map<String, dynamic>> _realtimeAgendas = [];

  static final List<Map<String, dynamic>> _ecosystemEntities = [
    {
      'id': 'creator',
      'name': 'Kreator & Profesional Kreatif',
      'subtitle':
          '(Fotografer, Videografer, Desainer, Editor, Content Creator, Programmer Kreatif, Seniman, dll)',
      'badge': 'Role 1 • Fokus Utama',
      'color': const Color(0xFFE11D48),
      'icon': Icons.palette_outlined,
      'benefits_received': [
        'Akses peluang proyek & job',
        'Portofolio digital terstruktur',
        'Jaringan klien dan kolaborasi',
        'Reputasi dan rating',
        'Ruang promosi karya',
        'Tools komunikasi dan manajemen proyek',
      ],
      'benefits_given': [
        'Karya dan portofolio',
        'Jasa/keahlian kreatif',
        'Ide dan konsep',
        'Profesionalisme dan ketepatan waktu',
        'Partisipasi komunitas',
        'Rekomendasi dan ulasan',
      ],
    },
    {
      'id': 'client',
      'name': 'Klien / Corporate',
      'subtitle': '(Perusahaan, UMKM, Brand, Instansi, dll)',
      'badge': 'Mitra Proyek & Job',
      'color': const Color(0xFF2563EB),
      'icon': Icons.business_outlined,
      'benefits_received': [
        'Akses ke kreator profesional sesuai kebutuhan',
        'Hasil karya berkualitas',
        'Solusi kreatif untuk komunikasi, pemasaran dan event',
        'Proses kerja yang mudah dan transparan',
      ],
      'benefits_given': [
        'Peluang proyek dan job',
        'Kebutuhan kreatif yang jelas',
        'Anggaran dan transaksi',
        'Ulasan dan testimoni',
        'Kemitraan jangka panjang',
      ],
    },
    {
      'id': 'partner',
      'name': 'Mitra / Vendor / Penyedia Jasa',
      'subtitle':
          '(Studio, Rental Alat, MUA, Dekorasi, Katering, Printing, Property, dll)',
      'badge': 'Penyedia Fasilitas & Servis',
      'color': const Color(0xFFF97316),
      'icon': Icons.storefront_outlined,
      'benefits_received': [
        'Pesanan dan penyewaan',
        'Peluang kerja sama baru',
        'Eksposur layanan dan produk',
        'Jaringan dengan kreator dan klien',
        'Pertumbuhan bisnis',
      ],
      'benefits_given': [
        'Produk, layanan dan fasilitas',
        'Harga dan ketersediaan yang jelas',
        'Kualitas layanan yang profesional',
        'Dukungan untuk event dan proyek',
        'Rekomendasi dan ulasan',
      ],
    },
    {
      'id': 'team',
      'name': 'Tim Kreavana',
      'subtitle': '(Operasional, Marketing, IT, Partnership, dll)',
      'badge': 'Platform Enabler & Keamanan',
      'color': const Color(0xFF6366F1),
      'icon': Icons.hub_outlined,
      'benefits_received': [
        'Pertumbuhan platform dan ekosistem',
        'Masukan dari pengguna',
        'Peluang inovasi dan pengembangan',
        'Kolaborasi dengan berbagai pihak',
        'Dampak positif bagi industri kreatif',
      ],
      'benefits_given': [
        'Pengelolaan platform yang andal dan aman',
        'Layanan dan dukungan pengguna',
        'Promosi dan pengembangan fitur',
        'Kemitraan dan kolaborasi',
        'Menjaga kualitas ekosistem',
      ],
    },
    {
      'id': 'community',
      'name': 'Komunitas',
      'subtitle':
          '(Komunitas Foto, Video, Desain, Seni, Musik, Hobi, Budaya, Wisata, dll)',
      'badge': 'Hub Berbagi & Sinergi',
      'color': const Color(0xFF10B981),
      'icon': Icons.groups_outlined,
      'benefits_received': [
        'Ruang berbagi ilmu dan pengalaman',
        'Kesempatan kolaborasi',
        'Informasi event dan peluang',
        'Peningkatan eksposur komunitas',
        'Anggota baru dan jaringan lebih luas',
      ],
      'benefits_given': [
        'Anggota dan aktivitas komunitas',
        'Konten, event dan program',
        'Partisipasi dalam kampanye',
        'Dukungan promosi platform',
        'Ulasan dan masukan',
      ],
    },
  ];

  static final List<Map<String, dynamic>> _creatorWorkflowSteps = [
    {
      'step': 1,
      'title': 'Daftar & Lengkapi Profil',
      'desc': 'Buat akun, lengkapi data, pilih kategori keahlian.',
      'icon': Icons.assignment_outlined,
      'btn': 'Edit Profil',
    },
    {
      'step': 2,
      'title': 'Unggah Portofolio',
      'desc': 'Tampilkan karya terbaik untuk menarik peluang.',
      'icon': Icons.photo_library_outlined,
      'btn': 'Kelola Portofolio',
    },
    {
      'step': 3,
      'title': 'Cari & Ajukan Peluang',
      'desc': 'Temukan proyek yang sesuai dan ajukan penawaran.',
      'icon': Icons.search_rounded,
      'btn': 'Cari Peluang',
    },
    {
      'step': 4,
      'title': 'Hubungi Klien/Mitra',
      'desc': 'Diskusikan kebutuhan, negosiasi, dan sepakati detail proyek.',
      'icon': Icons.forum_outlined,
      'btn': 'Buka Chat',
    },
    {
      'step': 5,
      'title': 'Kerjakan Proyek',
      'desc': 'Realisasikan proyek dengan profesional dan tepat waktu.',
      'icon': Icons.assignment_turned_in_outlined,
      'btn': 'Pantau Proyek',
    },
    {
      'step': 6,
      'title': 'Bangun Reputasi',
      'desc': 'Dapatkan ulasan dan rating untuk membuka peluang lebih besar.',
      'icon': Icons.trending_up_rounded,
      'btn': 'Cek Reputasi',
    },
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final results = await Future.wait([
        PortfolioService.getPortfolio().catchError((_) => <PortfolioItemModel>[]),
        DashboardService.getStats(subRole: 'general', roleType: 'creator').catchError((_) => <Map<String, String>>[]),
        DashboardService.getOpportunities(subRole: 'all').catchError((_) => <OpportunityModel>[]),
        JobContractService.getUserContracts().catchError((_) => <JobContract>[]),
      ]);

      final portfolio = results[0] as List<PortfolioItemModel>;
      final stats = results[1] as List<Map<String, String>>;
      final opps = results[2] as List<OpportunityModel>;
      final contracts = results[3] as List<JobContract>;

      final metrics = stats.isNotEmpty
          ? stats.map((s) => {
                'label': s['label'] ?? '',
                'value': s['value'] ?? '0',
                'sub': 'Statistik terkini',
                'icon': Icons.brush_outlined,
                'color': _primaryColor,
              }).toList()
          : <Map<String, dynamic>>[];

      final recs = opps.take(4).map((o) => {
            'title': o.title,
            'type': o.subRoleSlug.toUpperCase(),
            'price': o.budgetRange ?? 'Fleksibel',
            'color': _primaryColor,
          }).toList();

      final projects = contracts.take(5).map((c) => {
            'title': c.title,
            'client': c.clientName.isNotEmpty ? c.clientName : 'Klien Kreavana',
            'status': c.workStatus,
          }).toList();

      final agendas = contracts
          .where((c) => c.scheduledStartDate != null)
          .take(5)
          .map((c) => {
                'title': c.title,
                'date':
                    '${c.scheduledStartDate!.day}/${c.scheduledStartDate!.month}',
                'time':
                    '${c.scheduledStartDate!.day}/${c.scheduledStartDate!.month}/${c.scheduledStartDate!.year}',
                'tag': c.workStatus,
              })
          .toList();

      if (mounted) {
        setState(() {
          _portfolioItems = portfolio;
          _isLoadingPortfolio = false;
          _realtimeMetrics = metrics;
          _realtimeRecs = recs;
          _realtimeProjects = projects;
          _realtimeAgendas = agendas;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPortfolio = false);
      }
    }
  }

  Future<void> _addPortfolioItem() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    Uint8List? bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) {
      try {
        bytes = await picked.readAsBytes();
      } catch (_) {}
    }
    final path = picked.path;
    final fileName = picked.name;
    final nameController = TextEditingController();

    if (!mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nama Portofolio'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Contoh: Color Grading Sinematik',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final item = await PortfolioService.addPortfolio(
      title: name,
      imageBytes: bytes,
      fileName: fileName,
      imageFile: (!kIsWeb && path != null) ? File(path) : null,
    );

    if (mounted) {
      if (item != null) {
        setState(() => _portfolioItems.add(item));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Portofolio berhasil ditambahkan!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menambahkan portofolio. Pastikan ukuran file < 20MB.'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadDashboardData();
        },
        child: SingleChildScrollView(
          controller: _scrollController,
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
              RepaintBoundary(
                key: _ecosystemKey,
                child: _buildEcosystemSection(isDark),
              ),
              const SizedBox(height: 24),
              RepaintBoundary(child: _buildCreatorWorkflowSection(isDark)),
              const SizedBox(height: 24),
              RepaintBoundary(child: _buildMetricCards(isDark)),
              const SizedBox(height: 24),
              RepaintBoundary(child: _buildRecommendationsSection(isDark)),
              const SizedBox(height: 24),
              RepaintBoundary(child: _buildMiddleThreeColumns(isDark)),
              const SizedBox(height: 28),
              RepaintBoundary(child: _buildFooterEcosystem(isDark)),
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
                        'Cari peluang, proyek, komunitas, atau kreator...',
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
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(
                  user: widget.user,
                  onUserUpdated: widget.onUserUpdated,
                  onLogout: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _primaryColor.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.brush_outlined,
                    color: _primaryColor,
                    size: 20,
                  ),
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
                      'Kreator',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
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

  Widget _buildHeroBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF2E1065)]
              : [const Color(0xFFFDF2F8), const Color(0xFFEFF6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF4C1D95) : const Color(0xFFFBCFE8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFFE11D48))
                .withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Logo Kreavana + Separator + Role 1 Badge + Tagline
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE11D48), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'K',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Kreavana',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Platform & Ekosistem Kolaborasi Kreatif',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                width: 1.5,
                height: 24,
                color: isDark ? Colors.white24 : Colors.grey.shade300,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE11D48), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.palette_rounded, size: 13, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Role 1 : Kreator & Profesional Kreatif',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFE11D48),
                      Color(0xFFF97316),
                      Color(0xFF6366F1),
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'Kreativitas Menghubungkan Peluang',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Main Headline from the infographic
          Text(
            'Berkarya, Berkolaborasi, Bertumbuh Bersama di Ekosistem Kreavana',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Selamat datang, ${widget.user.name}. Dari profil hingga proyek berdampak, semua terintegrasi dalam satu ekosistem kolaborasi kreatif untuk menghubungkan potensi dengan peluang nyata.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 20),
          // Action Buttons
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      user: widget.user,
                      onUserUpdated: widget.onUserUpdated,
                      onLogout: () =>
                          Navigator.of(context).popUntil((r) => r.isFirst),
                    ),
                  ),
                ),
                icon: const Icon(Icons.person_outline, size: 16),
                label: const Text('Lengkapi Profil & Portofolio'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExploreScreen(user: widget.user),
                  ),
                ),
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text('Cari & Ajukan Peluang'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isDark ? Colors.white : const Color(0xFF0F172A),
                  side: BorderSide(
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _scrollToEcosystem,
                icon: const Icon(Icons.hub_rounded, size: 16),
                label: const Text('Peta Ekosistem & Alur Kerja'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF312E81)
                      : const Color(0xFFEEF2FF),
                  foregroundColor: isDark
                      ? const Color(0xFFA5B4FC)
                      : const Color(0xFF4338CA),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCards(bool isDark) {
    final metrics = _realtimeMetrics;

    if (metrics.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardBg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
          ),
        ),
        child: Center(
          child: Text(
            'Statistik belum tersedia.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        Widget buildCard(Map<String, dynamic> m) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        m['label'] as String,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (m['color'] as Color).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        (m['icon'] as IconData?) ?? Icons.brush_outlined,
                        color: m['color'] as Color,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    m['value'] as String,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (m['sub'] as String?) ?? '',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }

        if (isMobile) {
          final rows = <Widget>[];
          for (var i = 0; i < metrics.length; i += 2) {
            final rc = <Widget>[Expanded(child: buildCard(metrics[i]))];
            if (i + 1 < metrics.length) {
              rc.add(const SizedBox(width: 10));
              rc.add(Expanded(child: buildCard(metrics[i + 1])));
            }
            if (i > 0) rows.add(const SizedBox(height: 10));
            rows.add(Row(children: rc));
          }
          return Column(children: rows);
        }
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
      },
    );
  }

  Widget _buildRecommendationsSection(bool isDark) {
    final recs = _realtimeRecs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rekomendasi Untuk Anda',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (recs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
              ),
            ),
            child: Center(
              child: Text(
                'Belum ada rekomendasi peluang untuk saat ini.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                ),
              ),
            ),
          )
        else
          Row(
            children: recs.map((r) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardBg : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: (r['color'] as Color).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          r['type'] as String,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: r['color'] as Color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        r['title'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        r['price'] as String,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () {
                          if (r['type'] == 'KOMUNITAS') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MitraKomunitasScreen(user: widget.user),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PeluangProyekScreen(user: widget.user),
                              ),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 32),
                        ),
                        child: const Text(
                          'Lihat Detail',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildMiddleThreeColumns(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 700) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildProjectsAndActivity(isDark)),
          const SizedBox(width: 16),
          Expanded(child: _buildAgendaCalendar(isDark)),
          const SizedBox(width: 16),
          Expanded(child: _buildPortfolioGrid(isDark)),
        ],
      );
    }
    return Column(
      children: [
        _buildProjectsAndActivity(isDark),
        const SizedBox(height: 16),
        _buildAgendaCalendar(isDark),
        const SizedBox(height: 16),
        _buildPortfolioGrid(isDark),
      ],
    );
  }

  Widget _buildProjectsAndActivity(bool isDark) {
    final items = _realtimeProjects;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Proyek & Aktivitas',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _creatorPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${items.length} Aktif',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _creatorPurple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Belum ada proyek atau pekerjaan aktif.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                  ),
                ),
              ),
            )
          else
            ...items.take(4).map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: _creatorPurple.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.work_outline,
                        color: _creatorPurple,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (i['title'] as String?) ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            (i['client'] as String?) ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _creatorPurple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (i['status'] as String?) ?? '',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _creatorPurple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProyekSayaScreen(user: widget.user)),
            ),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Kelola Semua Proyek',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF6366F1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaCalendar(bool isDark) {
    final agendas = _realtimeAgendas;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Agenda / Kalender',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Bulan Ini',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (agendas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Belum ada agenda jadwal pekerjaan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                  ),
                ),
              ),
            )
          else
            ...agendas.take(4).map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        (a['date'] as String?) ?? '',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (a['title'] as String?) ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreatorCalendarScreen(
                  user: widget.user,
                  onUserUpdated: widget.onUserUpdated,
                ),
              ),
            ),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Buka Kalender Kerja',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioGrid(bool isDark) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Portofolio & Karya',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: _addPortfolioItem,
                child: Icon(
                  Icons.add_circle_outline,
                  color: _creatorPurple,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingPortfolio)
            const SkeletonGrid(itemCount: 6)
          else if (_portfolioItems.isEmpty)
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: List.generate(
                6,
                (index) => GestureDetector(
                  onTap: _addPortfolioItem,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _creatorPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: _creatorPurple,
                      size: 20,
                    ),
                  ),
                ),
              ),
            )
          else
            Builder(
              builder: (context) {
                final totalItems = _portfolioItems.length;
                final displayCount = totalItems + 1; // items + add button
                // Symmetrical complete rows of 3
                final totalSlots = (displayCount <= 3) ? 3 : ((displayCount + 2) ~/ 3) * 3;

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: totalSlots,
                  itemBuilder: (context, index) {
                    if (index == totalItems) {
                      return GestureDetector(
                        onTap: _addPortfolioItem,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _creatorPurple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _creatorPurple.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            color: _creatorPurple,
                            size: 20,
                          ),
                        ),
                      );
                    }
                    if (index > totalItems) {
                      return Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.grey.shade200,
                            width: 0.8,
                          ),
                        ),
                      );
                    }
                    final item = _portfolioItems[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          item.imageUrl != null && item.imageUrl!.isNotEmpty
                              ? Image.network(
                                  ApiService.resolveAssetUrl(item.imageUrl!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: _creatorPurple.withValues(alpha: 0.1),
                                    child: Icon(
                                      Icons.broken_image,
                                      color: _creatorPurple,
                                      size: 20,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: _creatorPurple.withValues(alpha: 0.1),
                                  child: Icon(
                                    Icons.image,
                                    color: _creatorPurple,
                                    size: 20,
                                  ),
                                ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () async {
                                await PortfolioService.deletePortfolio(item.id);
                                if (mounted) {
                                  setState(() => _portfolioItems.removeAt(index));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
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

  void _scrollToEcosystem() {
    if (_ecosystemKey.currentContext != null) {
      Scrollable.ensureVisible(
        _ecosystemKey.currentContext!,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  // ── 1. EKOSISTEM KOLABORATIF KREAVANA (5 ENTITAS + CIRCULAR HUB) ────────────
  Widget _buildEcosystemSection(bool isDark) {
    final activeEntity = _ecosystemEntities.firstWhere(
      (e) => e['id'] == _selectedEntityId,
      orElse: () => _ecosystemEntities.first,
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE11D48), Color(0xFF6366F1)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.hub_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Flexible(
                                child: Text(
                                  'Ekosistem Kolaborasi Kreatif',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE11D48)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Hub Terpadu',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE11D48),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kreavana menghubungkan 5 entitas kunci dengan timbal balik manfaat yang jelas dan berkesinambungan.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.textMuted
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showAllEcosystemModal(isDark),
                icon: const Icon(Icons.fullscreen_rounded, size: 16),
                label: const Text('Seluruh Manfaat'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Circular Hub Visualizer
          _buildCircularHubDiagram(isDark),
          const SizedBox(height: 20),

          // Entity Selection Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _ecosystemEntities.map((ent) {
                final isSelected = ent['id'] == _selectedEntityId;
                final color = ent['color'] as Color;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(
                      ent['icon'] as IconData,
                      size: 15,
                      color: isSelected ? Colors.white : color,
                    ),
                    label: Text(
                      ent['name'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: color,
                    backgroundColor: isDark
                        ? const Color(0xFF1E1B2E)
                        : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? color : Colors.transparent,
                      ),
                    ),
                    onSelected: (_) =>
                        setState(() => _selectedEntityId = ent['id'] as String),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Active Entity Detail Card (2 Columns: Manfaat yang Didapat vs Manfaat yang Diberikan)
          _buildEntityDetailCard(activeEntity, isDark),
        ],
      ),
    );
  }

  // Visual Circular Ecosystem Hub
  Widget _buildCircularHubDiagram(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF141221), const Color(0xFF1F1B38)]
              : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              // Center Logo Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE11D48), Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hub_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'KREAVANA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'Platform & Ekosistem Kolaborasi Kreatif',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Surrounding Connected Nodes
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  _buildNodeChip('client', 'Klien / Corporate', Icons.business_outlined, const Color(0xFF2563EB), isDark),
                  _buildNodeChip('creator', 'Kreator & Profesional Kreatif', Icons.palette_outlined, const Color(0xFFE11D48), isDark, isHighlight: true),
                  _buildNodeChip('community', 'Komunitas', Icons.groups_outlined, const Color(0xFF10B981), isDark),
                  _buildNodeChip('team', 'Tim Kreavana', Icons.hub_outlined, const Color(0xFF6366F1), isDark),
                  _buildNodeChip('partner', 'Mitra / Vendor', Icons.storefront_outlined, const Color(0xFFF97316), isDark),
                  _buildNodeChip('institution', 'Institusi', Icons.account_balance_outlined, const Color(0xFF64748B), isDark),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNodeChip(
    String id,
    String label,
    IconData icon,
    Color color,
    bool isDark, {
    bool isHighlight = false,
  }) {
    final isSelected = _selectedEntityId == id;
    return GestureDetector(
      onTap: () {
        if (_ecosystemEntities.any((e) => e['id'] == id)) {
          setState(() => _selectedEntityId = id);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.16)
              : (isDark ? const Color(0xFF1E1B2E) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : (isHighlight
                    ? const Color(0xFFE11D48).withValues(alpha: 0.6)
                    : (isDark ? Colors.white12 : Colors.grey.shade300)),
            width: isSelected || isHighlight ? 1.6 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? color
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntityDetailCard(Map<String, dynamic> ent, bool isDark) {
    final name = ent['name'] as String;
    final subtitle = ent['subtitle'] as String;
    final badge = ent['badge'] as String;
    final color = ent['color'] as Color;
    final benefitsReceived = (ent['benefits_received'] as List<String>);
    final benefitsGiven = (ent['benefits_given'] as List<String>);
    final isCreator = ent['id'] == 'creator';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B2E), const Color(0xFF1A1828)]
              : (isCreator
                  ? [const Color(0xFFFFF1F2), const Color(0xFFFFFFFF)]
                  : [const Color(0xFFF8FAFC), const Color(0xFFFFFFFF)]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCreator
              ? const Color(0xFFE11D48).withValues(alpha: 0.5)
              : (isDark ? AppTheme.inputBorder : Colors.grey.shade300),
          width: isCreator ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(ent['icon'] as IconData, size: 18, color: color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Two Columns Layout
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;

              Widget leftCol = Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF064E3B).withValues(alpha: 0.15)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 16, color: Color(0xFF10B981)),
                        SizedBox(width: 8),
                        Text(
                          'Manfaat yang Didapat',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...benefitsReceived.map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 13,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  b,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.4,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              );

              Widget rightCol = Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E3A8A).withValues(alpha: 0.15)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.handshake_rounded,
                            size: 16, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Text(
                          'Manfaat yang Diberikan ke Kreavana',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...benefitsGiven.map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.arrow_right_rounded,
                                  size: 16,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  b,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.4,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: leftCol),
                    const SizedBox(width: 14),
                    Expanded(child: rightCol),
                  ],
                );
              }
              return Column(
                children: [
                  leftCol,
                  const SizedBox(height: 12),
                  rightCol,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── 2. ALUR KERJA KREATOR DI KREAVANA (6 TAHAPAN SISTEMATIS) ─────────────
  Widget _buildCreatorWorkflowSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
              : [const Color(0xFFEFF6FF), const Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF312E81) : const Color(0xFFBFDBFE),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.settings_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alur Kerja Kreator di Kreavana',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Dari profil hingga proyek berdampak, semuanya dalam satu ekosistem.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '6 Langkah Terpadu',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 6 Steps Grid Layout
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 950;
              final isTablet = constraints.maxWidth > 600 && !isDesktop;

              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _creatorWorkflowSteps.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final step = entry.value;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: idx < _creatorWorkflowSteps.length - 1 ? 8 : 0,
                        ),
                        child: _buildWorkflowStepCard(step, isDark),
                      ),
                    );
                  }).toList(),
                );
              } else if (isTablet) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _creatorWorkflowSteps.map((step) {
                    return SizedBox(
                      width: (constraints.maxWidth - 24) / 3,
                      child: _buildWorkflowStepCard(step, isDark),
                    );
                  }).toList(),
                );
              } else {
                return Column(
                  children: _creatorWorkflowSteps.map((step) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildWorkflowStepCard(step, isDark),
                    );
                  }).toList(),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowStepCard(Map<String, dynamic> step, bool isDark) {
    final stepNum = step['step'] as int;
    final title = step['title'] as String;
    final desc = step['desc'] as String;
    final icon = step['icon'] as IconData;
    final btn = step['btn'] as String;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step Number & Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$stepNum',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Icon(icon, size: 20, color: const Color(0xFF2563EB)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(
              fontSize: 10,
              height: 1.4,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _handleWorkflowAction(stepNum),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFF2563EB).withValues(alpha: 0.25)
                    : const Color(0xFFEFF6FF),
                foregroundColor: const Color(0xFF2563EB),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 0.8,
                  ),
                ),
              ),
              child: Text(
                btn,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleWorkflowAction(int stepNum) {
    switch (stepNum) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(
              user: widget.user,
              onUserUpdated: widget.onUserUpdated,
              onLogout: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
          ),
        );
        break;
      case 2:
        _addPortfolioItem();
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ExploreScreen(user: widget.user)),
        );
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DirectMessageScreen()),
        );
        break;
      case 5:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProyekSayaScreen(user: widget.user),
          ),
        );
        break;
      case 6:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UlasanReputasiScreen(user: widget.user),
          ),
        );
        break;
    }
  }

  // ── 3. MODAL FULLSCREEN / DIALOG SELURUH MANFAAT ─────────────────────────
  void _showAllEcosystemModal(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF141221) : Colors.white,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: 1000,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            padding: const EdgeInsets.all(24),
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
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE11D48), Color(0xFF6366F1)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.hub_rounded,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Peta Ekosistem & Timbal Balik Manfaat Kreavana',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Rincian lengkap manfaat yang didapat vs yang diberikan oleh seluruh entitas',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
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
                const Divider(height: 24),
                Expanded(
                  child: ListView.separated(
                    itemCount: _ecosystemEntities.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, idx) {
                      final ent = _ecosystemEntities[idx];
                      return _buildEntityDetailCard(ent, isDark);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 4. FOOTER EKOSISTEM ──────────────────────────────────────────────────
  Widget _buildFooterEcosystem(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 1.5,
                width: 40,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xFFE11D48)],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Kreavana — Lebih dari Sekadar Platform, Ini Adalah Ekosistem',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Container(
                height: 1.5,
                width: 40,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6366F1), Colors.transparent],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Kreativitas Menghubungkan Peluang • Ekosistem Kolaborasi Kreatif Terpadu',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
