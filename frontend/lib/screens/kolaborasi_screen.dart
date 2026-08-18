import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/subrole_theme_engine.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import 'direct_message_screen.dart';

import '../widgets/skeleton/skeleton_list.dart';

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

  List<Map<String, dynamic>> _collabs = [
    {
      'id': '1',
      'name': 'Aruna Studio',
      'role': 'Fotografer',
      'project': 'Foto Katalog Produk Summer Collection 2026',
      'status': 'Aktif',
      'statusColor': const Color(0xFF10B981),
      'avatar': Icons.camera_alt_outlined,
      'date': 'Mei 2026 - Juni 2026',
      'membersCount': 4,
    },
    {
      'id': '2',
      'name': 'Frame Story',
      'role': 'Videografer',
      'project': 'Video Commercial Launching Brand',
      'status': 'Menunggu',
      'statusColor': const Color(0xFFF59E0B),
      'avatar': Icons.videocam_outlined,
      'date': 'Juni 2026',
      'membersCount': 2,
    },
    {
      'id': '3',
      'name': 'Graphix Studio',
      'role': 'Desainer Grafis',
      'project': 'Desain Poster & Identity Brand Campaign',
      'status': 'Selesai',
      'statusColor': const Color(0xFF3B82F6),
      'avatar': Icons.palette_outlined,
      'date': 'April 2026',
      'membersCount': 3,
    },
    {
      'id': '4',
      'name': 'MediaKreatif ID',
      'role': 'Content Strategist',
      'project': 'Manajemen Konten Media Sosial Bulanan',
      'status': 'Aktif',
      'statusColor': const Color(0xFF10B981),
      'avatar': Icons.movie_creation_outlined,
      'date': 'Mei 2026 - Des 2026',
      'membersCount': 5,
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchRealtimeCollabs();
  }

  Future<void> _fetchRealtimeCollabs() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('/collaborations');
      if (res['status'] == true && res['data'] != null) {
        final list = List<Map<String, dynamic>>.from(res['data']);
        if (mounted) {
          setState(() {
            _collabs = list;
          });
        }
      }
    } catch (_) {
      // Fallback to rich mock data if backend not active
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      final status = c['status'] as String;
      if (_selectedStatus != 'Semua' && status != _selectedStatus) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (c['name'] as String).toLowerCase();
        final proj = (c['project'] as String).toLowerCase();
        final r = (c['role'] as String).toLowerCase();
        return name.contains(q) || proj.contains(q) || r.contains(q);
      }
      return true;
    }).toList();

    final activeCount = _collabs.where((c) => c['status'] == 'Aktif').length;
    final pendingCount = _collabs
        .where((c) => c['status'] == 'Menunggu')
        .length;
    final doneCount = _collabs.where((c) => c['status'] == 'Selesai').length;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text(
          'Kolaborasi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRealtimeCollabs,
            tooltip: 'Refresh Data Realtime',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRealtimeCollabs,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Summary ──
              _buildSummaryCards(
                accentColor,
                activeCount,
                pendingCount,
                doneCount,
                isDark,
              ),
              const SizedBox(height: 20),

              // ── Search Bar & Filter Chips ──
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Cari mitra, tim, atau proyek kolaborasi...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1A1830)
                      : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
                  children: ['Semua', 'Aktif', 'Menunggu', 'Selesai'].map((st) {
                    final isSel = _selectedStatus == st;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(st),
                        selected: isSel,
                        selectedColor: accentColor,
                        labelStyle: TextStyle(
                          color: isSel
                              ? Colors.white
                              : (isDark
                                    ? Colors.white70
                                    : Colors.grey.shade800),
                          fontWeight: isSel
                              ? FontWeight.bold
                              : FontWeight.normal,
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
              const SizedBox(height: 16),

              // ── List Items ──
              if (_isLoading)
                const SkeletonList()
              else if (filtered.isEmpty)
                _buildEmptyState(isDark)
              else
                ...filtered.map(
                  (c) => _buildCollabCard(c, accentColor, isDark),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewCollabDialog(context, accentColor),
        backgroundColor: accentColor,
        icon: const Icon(Icons.group_add, color: Colors.white),
        label: const Text(
          'Ajukan Kolaborasi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(
    Color accentColor,
    int active,
    int pending,
    int done,
    bool isDark,
  ) {
    final items = [
      {
        'label': 'Total Tim',
        'val': '${_collabs.length}',
        'color': accentColor,
        'icon': Icons.groups_outlined,
      },
      {
        'label': 'Aktif',
        'val': '$active',
        'color': const Color(0xFF10B981),
        'icon': Icons.play_circle_outline,
      },
      {
        'label': 'Menunggu',
        'val': '$pending',
        'color': const Color(0xFFF59E0B),
        'icon': Icons.pending_actions_outlined,
      },
      {
        'label': 'Selesai',
        'val': '$done',
        'color': const Color(0xFF3B82F6),
        'icon': Icons.task_alt_outlined,
      },
    ];

    return Row(
      children: items.map((it) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  (it['icon'] as IconData?) ?? Icons.image_outlined,
                  color: it['color'] as Color,
                  size: 20,
                ),
                const SizedBox(height: 6),
                Text(
                  it['val'] as String,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  it['label'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCollabCard(
    Map<String, dynamic> c,
    Color accentColor,
    bool isDark,
  ) {
    final statusColor = c['statusColor'] as Color;

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
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: accentColor.withValues(alpha: 0.12),
                child: Icon(
                  (c['avatar'] as IconData?) ?? Icons.person,
                  color: accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c['name'] as String,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${c['role']} • ${c['membersCount']} Anggota Tim',
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  c['status'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            c['project'] as String,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 12,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    c['date'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DirectMessageScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline, size: 14),
                label: const Text('Chat Tim', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
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

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.groups_outlined,
            size: 48,
            color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada data kolaborasi ditemukan',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showNewCollabDialog(BuildContext context, Color accentColor) {
    final titleCtrl = TextEditingController();
    final roleCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ajukan Kolaborasi Baru',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Proyek / Campaign',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Peran Tim yang Dibutuhkan',
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
                  ),
                  onPressed: () {
                    if (titleCtrl.text.isNotEmpty) {
                      setState(() {
                        _collabs.insert(0, {
                          'id': '${DateTime.now().millisecondsSinceEpoch}',
                          'name': widget.user?.name ?? 'Kreator Partner',
                          'role': roleCtrl.text.isEmpty
                              ? 'Kreator'
                              : roleCtrl.text,
                          'project': titleCtrl.text,
                          'status': 'Menunggu',
                          'statusColor': const Color(0xFFF59E0B),
                          'avatar': Icons.person_outline,
                          'date': 'Agustus 2026',
                          'membersCount': 1,
                        });
                      });
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text(
                    'Kirim Pengajuan',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
