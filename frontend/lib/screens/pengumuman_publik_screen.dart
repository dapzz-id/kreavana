import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../widgets/desktop_sidebar_layout.dart';
import 'institution_workspace_screen.dart';

class PengumumanPublikScreen extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const PengumumanPublikScreen({super.key, this.user, this.onUserUpdated});

  @override
  State<PengumumanPublikScreen> createState() => _PengumumanPublikScreenState();
}

class _PengumumanPublikScreenState extends State<PengumumanPublikScreen> {
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'Semua';
  List<Map<String, dynamic>> _announcements = [];

  bool get _canCreateAnnouncement {
    final sub = widget.user?.subRole?.toLowerCase() ?? '';
    return [
      'government',
      'pemerintah',
      'instansi',
      'dinas',
      'bumn',
      'kementerian',
      'corporate',
      'company',
      'business',
      'perusahaan',
      'institution',
      'school',
      'sekolah',
    ].contains(sub);
  }

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
    setState(() => _isLoading = true);
    try {
      List<dynamic> rawList = [];

      // Try fetching institution resources first if authenticated
      if (widget.user != null) {
        final res = await ApiService.get(
          'institution/resources',
          queryParams: {'type': 'announcements'},
        ).catchError((_) => <String, dynamic>{});

        if (res['data'] is List) {
          rawList = res['data'] as List<dynamic>;
        }
      }

      // If empty, fetch public announcements endpoint
      if (rawList.isEmpty) {
        final publicRes = await ApiService.get(
          'institution/announcements',
        ).catchError((_) => <String, dynamic>{});

        final pData = publicRes['data'];
        if (pData is Map && pData['data'] is List) {
          rawList = pData['data'] as List<dynamic>;
        } else if (pData is List) {
          rawList = pData;
        }
      }

      final mapped = <Map<String, dynamic>>[];
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          final meta = item['metadata'] is Map<String, dynamic>
              ? item['metadata'] as Map<String, dynamic>
              : <String, dynamic>{};

          final category = meta['category']?.toString() ??
              meta['tipe']?.toString() ??
              'Pengumuman';

          Color typeColor = const Color(0xFF1D4ED8);
          IconData icon = Icons.campaign_rounded;

          final catLower = category.toLowerCase();
          if (catLower.contains('sayembara') || catLower.contains('lomba')) {
            typeColor = const Color(0xFFD97706);
            icon = Icons.emoji_events_outlined;
          } else if (catLower.contains('siaran') || catLower.contains('pers') || catLower.contains('berita')) {
            typeColor = const Color(0xFF0F766E);
            icon = Icons.newspaper_outlined;
          } else if (catLower.contains('layanan') || catLower.contains('maklumat')) {
            typeColor = const Color(0xFF7C3AED);
            icon = Icons.verified_user_outlined;
          } else if (catLower.contains('lpse') || catLower.contains('pengadaan')) {
            typeColor = const Color(0xFF2563EB);
            icon = Icons.gavel_rounded;
          }

          final dateStr = meta['valid_until']?.toString() ??
              meta['tanggal']?.toString() ??
              item['created_at']?.toString().split('T').first ??
              '16 Okt 2026';

          mapped.add({
            'id': item['id'],
            'title': item['title'] ?? 'Pengumuman Resmi',
            'description': item['description'] ?? 'Tidak ada rincian keterangan.',
            'category': category,
            'status': item['status'] ?? 'published',
            'date': dateStr,
            'type_color': typeColor,
            'icon': icon,
            'metadata': meta,
          });
        }
      }

      if (mounted) {
        setState(() {
          _announcements = mapped;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredAnnouncements {
    return _announcements.where((a) {
      final matchesQuery = _searchQuery.isEmpty ||
          (a['title']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (a['description']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      final matchesCat = _selectedCategory == 'Semua' ||
          (a['category']?.toString().toLowerCase().contains(_selectedCategory.toLowerCase()) ?? false);

      return matchesQuery && matchesCat;
    }).toList();
  }

  void _showDetailModal(Map<String, dynamic> item, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (item['type_color'] as Color).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: item['type_color'] as Color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (item['type_color'] as Color).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            item['category'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: item['type_color'] as Color,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['date'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                item['title'] as String,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141224) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
                child: Text(
                  item['description'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Tutup Informasi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    final categories = ['Semua', 'Sayembara', 'Siaran Pers', 'Pelayanan', 'Pengumuman'];

    final content = Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        automaticallyImplyLeading: !isDesktop,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pengumuman Publik & Warta Resmi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Informasi kedinasan, sayembara, siaran pers, dan maklumat resmi instansi',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          if (_canCreateAnnouncement && widget.user != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InstitutionWorkspaceScreen(
                        user: widget.user!,
                        resourceType: 'announcements',
                        onUserUpdated: widget.onUserUpdated,
                      ),
                    ),
                  ).then((_) => _fetchAnnouncements());
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Buat Pengumuman'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAnnouncements,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 24 : 16,
            16,
            isDesktop ? 24 : 16,
            80,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search & filter row
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
                  children: [
                    TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Cari judul sayembara, siaran pers, atau maklumat kedinasan...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF151326) : Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categories.map((cat) {
                          final isSelected = _selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(cat),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _selectedCategory = cat),
                              selectedColor: const Color(0xFF1D4ED8),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                              ),
                              backgroundColor: isDark ? const Color(0xFF221F38) : Colors.grey.shade100,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Content Area
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_filteredAnnouncements.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.campaign_outlined,
                          size: 64,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum Ada Pengumuman Ditemukan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Silakan coba gunakan kata kunci pencarian atau kategori lain.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredAnnouncements.length,
                  itemBuilder: (context, index) {
                    final p = _filteredAnnouncements[index];
                    final typeColor = p['type_color'] as Color;
                    final icon = p['icon'] as IconData;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.cardBg : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
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
                                  color: typeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(icon, color: typeColor, size: 22),
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
                                            color: typeColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            p['category'] as String,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: typeColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 11,
                                          color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          p['date'] as String,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      p['title'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            p['description'] as String,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _showDetailModal(p, isDark),
                                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                label: const Text('Baca Selengkapnya'),
                                style: TextButton.styleFrom(
                                  foregroundColor: typeColor,
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
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
          ),
        ),
      ),
    );

    if (widget.user != null) {
      return DesktopSidebarLayout(
        user: widget.user!,
        activeRoute: 'pengumuman_publik',
        onUserUpdated: widget.onUserUpdated,
        child: content,
      );
    }

    return content;
  }
}
