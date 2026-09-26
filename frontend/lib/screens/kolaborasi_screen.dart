import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/subrole_theme_engine.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import 'direct_message_screen.dart';
import '../widgets/skeleton/skeleton_list.dart';
import '../widgets/app_breadcrumbs.dart';
import 'main_navigation.dart';

class KolaborasiScreen extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const KolaborasiScreen({super.key, this.user, this.onUserUpdated});

  @override
  State<KolaborasiScreen> createState() => _KolaborasiScreenState();
}

class _KolaborasiScreenState extends State<KolaborasiScreen> {
  bool _isLoading = false;
  String _selectedStatus = 'Semua';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _defaultCollabs = [
    {
      'id': 'collab-1',
      'name': 'Dimas Arya',
      'role': 'Director & Produser',
      'avatar': Icons.videocam_rounded,
      'project': 'Produksi Video Iklan Pariwisata Wonderful Indonesia 2026',
      'desc':
          'Membutuhkan drone pilot bersertifikat FPV dan colorist DaVinci untuk shooting di Labuan Bajo & Bali selama 4 hari penuh.',
      'neededRoles': ['Drone Pilot FPV', 'Colorist DaVinci', 'Audio Recordist'],
      'budget': 'Rp 18.500.000',
      'compensationType': 'Bagi Hasil & Fee Tetap',
      'status': 'Aktif',
      'statusColor': const Color(0xFF10B981),
      'membersCount': 4,
      'maxMembers': 6,
      'date': '25 Sep - 10 Okt 2026',
      'location': 'Bali & Labuan Bajo',
      'tags': ['Cinematic', 'Travel', 'Commercial'],
    },
    {
      'id': 'collab-2',
      'name': 'Sarah Putri',
      'role': 'Brand Strategist',
      'avatar': Icons.palette_rounded,
      'project': 'Rebranding & Desain Kemasan UMKM Kopi Kintamani',
      'desc':
          'Mencari packaging illustrator dan 3D visualizer mockup produk untuk persiapan ekspor pasar Jepang & Australia.',
      'neededRoles': ['Packaging Designer', '3D Artist', 'Copywriter'],
      'budget': 'Rp 8.500.000',
      'compensationType': 'Escrow Kreavana',
      'status': 'Menunggu',
      'statusColor': const Color(0xFFF59E0B),
      'membersCount': 2,
      'maxMembers': 3,
      'date': '30 Sep 2026',
      'location': 'Remote / Bali',
      'tags': ['Branding', 'Packaging', 'Export'],
    },
    {
      'id': 'collab-3',
      'name': 'Kevin Jonathan',
      'role': 'Fashion Photographer',
      'avatar': Icons.camera_alt_rounded,
      'project': 'Photoshoot Editorial Fashion Raya Collection 2026',
      'desc':
          'Kolaborasi photoshoot lookbook busana muslim modern bersama brand lokal terkemuka di studio profesional.',
      'neededRoles': ['MUA Editorial', 'Fashion Stylist', 'Lighting Assistant'],
      'budget': 'Rp 14.000.000',
      'compensationType': 'Kontrak Terproteksi',
      'status': 'Aktif',
      'statusColor': const Color(0xFF10B981),
      'membersCount': 5,
      'maxMembers': 5,
      'date': '05 Okt 2026',
      'location': 'Studio Kreavana Jakarta',
      'tags': ['Fashion', 'Editorial', 'Lookbook'],
    },
    {
      'id': 'collab-4',
      'name': 'Aditya Pratama',
      'role': 'Sound Designer & Composer',
      'avatar': Icons.music_note_rounded,
      'project': 'Original Score & Sound Design Film Pendek "Suara Pesisir"',
      'desc':
          'Proyek film pendek festival internasional. Membutuhkan pengisi instrumen tradisional dan mixing surround 5.1.',
      'neededRoles': ['Mixing Engineer', 'Foley Artist'],
      'budget': 'Rp 7.500.000',
      'compensationType': 'Royalti & Fee',
      'status': 'Menunggu',
      'statusColor': const Color(0xFFF59E0B),
      'membersCount': 2,
      'maxMembers': 4,
      'date': '15 Okt 2026',
      'location': 'Remote / Yogyakarta',
      'tags': ['FilmScore', 'Festival', 'Audio'],
    },
    {
      'id': 'collab-5',
      'name': 'Nabila Zahra',
      'role': 'Social Media Specialist',
      'avatar': Icons.campaign_rounded,
      'project': 'Campaign Konten Tiktok & Reels Kuliner Nusantara',
      'desc':
          'Produksi 30 video konten pendek review kuliner khas nusantara untuk sponsor e-commerce terkemuka.',
      'neededRoles': ['Content Creator', 'Video Editor CapCut'],
      'budget': 'Rp 12.000.000',
      'compensationType': 'Selesai Dibayarkan',
      'status': 'Selesai',
      'statusColor': const Color(0xFF6B7280),
      'membersCount': 4,
      'maxMembers': 4,
      'date': 'Selesai 10 Sep 2026',
      'location': 'Jakarta & Bandung',
      'tags': ['TikTok', 'Culinary', 'ViralContent'],
    },
  ];

  List<Map<String, dynamic>> _collabs = [];

  @override
  void initState() {
    super.initState();
    _collabs = List.from(_defaultCollabs);
    _fetchRealtimeCollabs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRealtimeCollabs() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('/collaborations');
      if (res['status'] == true &&
          res['data'] != null &&
          (res['data'] as List).isNotEmpty) {
        final list = List<Map<String, dynamic>>.from(res['data']);
        if (mounted) {
          setState(() {
            _collabs = list;
          });
        }
        return;
      }
    } catch (_) {
      // Fallback to default realistic collaborations
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (mounted && _collabs.isEmpty) {
      setState(() {
        _collabs = List.from(_defaultCollabs);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final role = widget.user?.role ?? 'user';
    final subRole = widget.user?.subRole ?? 'general';
    final accentColor = SubRoleThemeEngine.getAccentColor(role, subRole);

    final filtered = _collabs.where((c) {
      final status = (c['status'] as String?) ?? 'Aktif';
      if (_selectedStatus != 'Semua' && status != _selectedStatus) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = ((c['name'] as String?) ?? '').toLowerCase();
        final proj = ((c['project'] as String?) ?? '').toLowerCase();
        final r = ((c['role'] as String?) ?? '').toLowerCase();
        final desc = ((c['desc'] as String?) ?? '').toLowerCase();
        final tags = (c['tags'] as List?)?.join(' ').toLowerCase() ?? '';
        return name.contains(q) ||
            proj.contains(q) ||
            r.contains(q) ||
            desc.contains(q) ||
            tags.contains(q);
      }
      return true;
    }).toList();

    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: Navigator.canPop(context),
        toolbarHeight: 80,
        titleSpacing: isDesktop ? 32 : 18,
        elevation: 0,
        title: const Text(
          'Kolaborasi',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchRealtimeCollabs,
            tooltip: 'Perbarui Data',
          ),
          SizedBox(width: isDesktop ? 24 : 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRealtimeCollabs,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 18,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppBreadcrumbs(
                      items: [
                        BreadcrumbItem(
                          label: 'Beranda',
                          icon: Icons.home_rounded,
                          onTap: () {
                            if (widget.user != null) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MainNavigation(
                                    initialUser: widget.user!,
                                    initialIndex: 0,
                                  ),
                                ),
                                (r) => false,
                              );
                            }
                          },
                        ),
                        const BreadcrumbItem(
                          label: 'Kolaborasi',
                          icon: Icons.handshake_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
              // ── Search Bar ──
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Cari mitra, tim, atau proyek kolaborasi...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor:
                      isDark ? const Color(0xFF181528) : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Filter Chips ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Semua', 'Aktif', 'Menunggu', 'Selesai'].map((st) {
                    final isSel = _selectedStatus == st;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(st),
                        selected: isSel,
                        selectedColor: accentColor,
                        backgroundColor: isDark
                            ? const Color(0xFF1E1A33)
                            : Colors.grey.shade100,
                        side: BorderSide(
                          color: isSel
                              ? accentColor
                              : (isDark
                                  ? AppTheme.inputBorder
                                  : Colors.grey.shade300),
                        ),
                        labelStyle: TextStyle(
                          color: isSel
                              ? Colors.white
                              : (isDark
                                  ? Colors.white70
                                  : Colors.grey.shade800),
                          fontWeight:
                              isSel ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedStatus = st);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),

              // ── Main Content / Centered Empty State ──
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: SkeletonList(),
                )
              else if (filtered.isEmpty)
                _buildCenteredEmptyState(accentColor, isDark)
              else if (isDesktop)
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: filtered.map((c) {
                    final cardWidth = (MediaQuery.of(context).size.width > 1240
                            ? 1240
                            : MediaQuery.of(context).size.width) /
                        2 -
                        48;
                    return SizedBox(
                      width: cardWidth > 420 ? cardWidth : double.infinity,
                      child: _buildCollabCard(c, accentColor, isDark),
                    );
                  }).toList(),
                )
              else
                ...filtered.map(
                  (c) => _buildCollabCard(c, accentColor, isDark),
                ),
              const SizedBox(height: 70),
            ],
          ),
        ),
      ),
    ),
  ),
),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.width < 900 ? 76 : 0,
        ),
        child: FloatingActionButton.extended(
          heroTag: 'kolaborasi_fab',
          onPressed: () => _showNewCollabDialog(context, accentColor),
          backgroundColor: accentColor,
          elevation: 5,
          icon: const Icon(Icons.group_add_rounded, color: Colors.white),
          label: const Text(
            'Ajukan Kolaborasi',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }

  // ── Perfectly Centered Empty State ─────────────────────────────────────────
  Widget _buildCenteredEmptyState(Color accentColor, bool isDark) {
    // Dynamic height calculation so it centers vertically in available screen space
    final screenHeight = MediaQuery.of(context).size.height;
    final minEmptyHeight = (screenHeight - 270).clamp(320.0, 650.0);

    return SizedBox(
      height: minEmptyHeight,
      width: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.groups_rounded,
                  size: 42,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Belum ada data kolaborasi ditemukan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  _searchQuery.isNotEmpty
                      ? 'Tidak ada proyek yang sesuai dengan kata kunci "$_searchQuery". Coba kata kunci lain atau bersihkan filter.'
                      : 'Belum ada proyek kolaborasi pada kategori "$_selectedStatus". Mulai ajukan kolaborasi baru untuk mengajak kreator lain.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  if (_searchQuery.isNotEmpty || _selectedStatus != 'Semua')
                    OutlinedButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _selectedStatus = 'Semua';
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reset Filter'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: isDark
                              ? AppTheme.inputBorder
                              : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: () => _showNewCollabDialog(context, accentColor),
                    icon: const Icon(Icons.group_add_rounded,
                        size: 16, color: Colors.white),
                    label: const Text(
                      'Ajukan Kolaborasi Sekarang',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  // ── Collaboration Card ─────────────────────────────────────────────────────
  Widget _buildCollabCard(
    Map<String, dynamic> c,
    Color accentColor,
    bool isDark,
  ) {
    final status = (c['status'] as String?) ?? 'Aktif';
    final statusColor = (c['statusColor'] as Color?) ??
        (status == 'Aktif'
            ? const Color(0xFF10B981)
            : (status == 'Menunggu'
                ? const Color(0xFFF59E0B)
                : const Color(0xFF6B7280)));

    final membersCount = (c['membersCount'] as int?) ?? 1;
    final maxMembers = (c['maxMembers'] as int?) ?? 4;
    final progress = (membersCount / maxMembers).clamp(0.0, 1.0);
    final neededRoles = (c['neededRoles'] as List?)?.cast<String>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Avatar, Lead, Status Pill
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: accentColor.withValues(alpha: 0.15),
                child: Icon(
                  (c['avatar'] as IconData?) ?? Icons.person_rounded,
                  color: accentColor,
                  size: 24,
                ),
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
                            c['name'] as String? ?? 'Kreator Partner',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.verified_rounded,
                            size: 15, color: accentColor),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${c['role'] ?? 'Kreator'} • ${c['location'] ?? 'Indonesia'}',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: statusColor.withValues(alpha: 0.3)),
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
                    const SizedBox(width: 5),
                    Text(
                      status,
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
          const SizedBox(height: 14),

          // Project Title
          Text(
            c['project'] as String? ?? 'Proyek Kolaborasi',
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          if (c['desc'] != null) ...[
            const SizedBox(height: 6),
            Text(
              c['desc'] as String,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),

          // Needed Roles Badges
          if (neededRoles.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: neededRoles.map((r) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_alt_1_rounded,
                          size: 12, color: accentColor),
                      const SizedBox(width: 4),
                      Text(
                        r,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Team Member Progress Bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kebutuhan Tim: $membersCount / $maxMembers Talenta',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppTheme.textMuted
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Info Row: Budget & Timeline
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF181528)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 15, color: Colors.green.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${c['budget'] ?? 'TBA'} • ${c['compensationType'] ?? 'Kesepakatan'}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.calendar_today_rounded,
                    size: 13,
                    color:
                        isDark ? AppTheme.textMuted : Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  c['date'] as String? ?? '2026',
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        isDark ? AppTheme.textMuted : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Bottom Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showCollabDetailModal(context, c, accentColor),
                icon: const Icon(Icons.info_outline_rounded, size: 15),
                label: const Text('Detail Tim',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: BorderSide(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DirectMessageScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded,
                    size: 15, color: Colors.white),
                label: const Text('Chat Tim',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  // ── Detail Project Modal ───────────────────────────────────────────────────
  void _showCollabDetailModal(
    BuildContext context,
    Map<String, dynamic> c,
    Color accentColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    final neededRoles = (c['neededRoles'] as List?)?.cast<String>() ?? [];

    Widget buildModalContent(BuildContext ctx, {bool inDialog = false}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!inDialog) ...[
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
            const SizedBox(height: 18),
          ],
          if (inDialog)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Detail Proyek Kolaborasi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                  tooltip: 'Tutup',
                ),
              ],
            ),
              const SizedBox(height: 18),
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: accentColor.withValues(alpha: 0.15),
                    child: Icon(
                      (c['avatar'] as IconData?) ?? Icons.person_rounded,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['name'] as String? ?? 'Kreator Partner',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${c['role']} • ${c['location']}',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.textMuted
                                  : Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                c['project'] as String? ?? '',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                c['desc'] as String? ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.grey.shade800,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Peran yang Masih Dibutuhkan:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: neededRoles.map((r) {
                  return Chip(
                    label: Text(r),
                    backgroundColor: accentColor.withValues(alpha: 0.1),
                    labelStyle: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Pengajuan bergabung ke "${c['project']}" berhasil dikirim ke ${c['name']}!',
                        ),
                        backgroundColor: Colors.green.shade700,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded,
                      color: Colors.white),
                  label: const Text(
                    'Ajukan Diri untuk Bergabung',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          );
    }

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181528) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: buildModalContent(ctx, inDialog: true),
              ),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181528) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: buildModalContent(ctx, inDialog: false),
          );
        },
      );
    }
  }

  // ── New Collaboration Dialog ───────────────────────────────────────────────
  void _showNewCollabDialog(BuildContext context, Color accentColor) {
    final titleCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildFormContent(BuildContext ctx, {bool inDialog = false}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!inDialog) ...[
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
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ajukan Kolaborasi Baru',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (inDialog)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                  tooltip: 'Tutup',
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Publikasikan proyek tim Anda agar kreator lain dapat mengajukan diri.',
            style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama Proyek / Campaign *',
              hintText: 'Contoh: Shooting Video Klip Musik Indie',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: roleCtrl,
            decoration: const InputDecoration(
              labelText: 'Peran yang Dibutuhkan (Pisahkan koma) *',
              hintText: 'Contoh: Videografer, MUA, Sound Engineer',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: budgetCtrl,
            decoration: const InputDecoration(
              labelText: 'Estimasi Budget / Pembagian Fee',
              hintText: 'Contoh: Rp 10.000.000 (Bagi Hasil)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: locCtrl,
            decoration: const InputDecoration(
              labelText: 'Lokasi Eksekusi',
              hintText: 'Contoh: Jakarta / Remote',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Deskripsi & Tujuan Proyek',
              hintText: 'Ceritakan detail proyek dan kualifikasi yang dicari...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;

                final roles = roleCtrl.text.isNotEmpty
                    ? roleCtrl.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList()
                    : ['Partner Kreatif'];

                setState(() {
                  _collabs.insert(0, {
                    'id': 'collab-',
                    'name': widget.user?.name ?? 'Kreator Mandiri',
                    'role': widget.user?.subRole != null
                        ? widget.user!.subRole!.toUpperCase()
                        : 'Kreator',
                    'project': titleCtrl.text.trim(),
                    'desc': descCtrl.text.trim().isNotEmpty
                        ? descCtrl.text.trim()
                        : 'Proyek kolaborasi baru yang siap dieksekusi bersama tim terpercaya.',
                    'neededRoles': roles,
                    'budget': budgetCtrl.text.trim().isNotEmpty
                        ? budgetCtrl.text.trim()
                        : 'Sesuai Kesepakatan',
                    'compensationType': 'Escrow Aman',
                    'status': 'Menunggu',
                    'statusColor': const Color(0xFFF59E0B),
                    'avatar': Icons.person_pin_rounded,
                    'membersCount': 1,
                    'maxMembers': roles.length + 1,
                    'date': 'September 2026',
                    'location': locCtrl.text.trim().isNotEmpty
                        ? locCtrl.text.trim()
                        : 'Indonesia',
                    'tags': ['New', 'Collaboration'],
                  });
                });

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Proyek kolaborasi berhasil diajukan dan dipublikasikan!',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text(
                'Publikasikan Kolaborasi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181528) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: buildFormContent(ctx, inDialog: true),
              ),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Container(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181528) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: buildFormContent(ctx, inDialog: false),
            ),
          );
        },
      );
    }
  }
}
