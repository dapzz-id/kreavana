import 'package:flutter/material.dart';
import '../utils/debouncer.dart';
import '../app/theme.dart';
import '../app/subrole_theme_engine.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import 'direct_message_screen.dart';
import 'buat_kebutuhan_screen.dart';

import '../widgets/skeleton/skeleton_list.dart';

class ProyekSayaScreen extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const ProyekSayaScreen({super.key, this.user, this.onUserUpdated});

  @override
  State<ProyekSayaScreen> createState() => _ProyekSayaScreenState();
}

class _ProyekSayaScreenState extends State<ProyekSayaScreen> {
  bool _isLoading = false;
  String _selectedStatus = 'Semua';
  String _searchQuery = '';
  final _debouncer = Debouncer(milliseconds: 500);

  List<Map<String, dynamic>> _projects = [
    {
      'id': '1',
      'title': 'Foto Katalog Produk Summer Collection 2026',
      'status': 'Berjalan',
      'statusColor': const Color(0xFF10B981),
      'creator': 'Aruna Studio',
      'progress': 0.65,
      'deadline': '28 Mei 2026',
      'budget': 'Rp 8.500.000',
    },
    {
      'id': '2',
      'title': 'Video Promosi Instagram & TikTok Commercial',
      'status': 'Menunggu',
      'statusColor': const Color(0xFFF59E0B),
      'creator': 'Frame Story',
      'progress': 0.0,
      'deadline': '5 Juni 2026',
      'budget': 'Rp 14.000.000',
    },
    {
      'id': '3',
      'title': 'Desain Poster Campaign Digital',
      'status': 'Selesai',
      'statusColor': const Color(0xFF3B82F6),
      'creator': 'Graphix Studio',
      'progress': 1.0,
      'deadline': '15 Mei 2026',
      'budget': 'Rp 4.500.000',
    },
    {
      'id': '4',
      'title': 'Dokumentasi Event Komunitas Pemuda 2026',
      'status': 'Berjalan',
      'statusColor': const Color(0xFF10B981),
      'creator': 'Kreasi Konten ID',
      'progress': 0.35,
      'deadline': '1 Juni 2026',
      'budget': 'Rp 12.000.000',
    },
  ];

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchRealtimeProjects();
  }

  Future<void> _fetchRealtimeProjects() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('projects');
      if (res['success'] == true && res['data'] != null) {
        final list = List<Map<String, dynamic>>.from(res['data']);
        if (list.isNotEmpty && mounted) {
          setState(() {
            _projects = list;
          });
        }
      }
    } catch (_) {
      // Keep rich fallback mock data if backend not active
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

    final filtered = _projects.where((p) {
      final st = p['status'] as String;
      if (_selectedStatus != 'Semua' && st != _selectedStatus) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = (p['title'] as String).toLowerCase();
        final creator = (p['creator'] as String).toLowerCase();
        return title.contains(q) || creator.contains(q);
      }
      return true;
    }).toList();

    final activeCount = _projects.where((p) => p['status'] == 'Berjalan').length;
    final pendingCount = _projects.where((p) => p['status'] == 'Menunggu').length;
    final doneCount = _projects.where((p) => p['status'] == 'Selesai').length;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text('Proyek Saya', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        leading: widget.user != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRealtimeProjects,
            tooltip: 'Refresh Data Realtime',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRealtimeProjects,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Summary Cards ──
              _buildSummaryHeader(accentColor, activeCount, pendingCount, doneCount, isDark),
              const SizedBox(height: 20),

              // ── Search & Filters ──
              TextField(
                onChanged: (v) {
                  _debouncer.run(() {
                    setState(() => _searchQuery = v);
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Cari nama proyek atau partner...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1A1830) : Colors.grey.shade100,
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
                  children: ['Semua', 'Berjalan', 'Menunggu', 'Selesai'].map((st) {
                    final isSel = _selectedStatus == st;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(st),
                        selected: isSel,
                        selectedColor: accentColor,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade800),
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
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

              // ── Projects List ──
              if (_isLoading)
                const SkeletonList()
              else if (filtered.isEmpty)
                _buildEmptyState(isDark)
              else
                ...filtered.map((p) => _buildProjectCard(p, accentColor, isDark)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BuatKebutuhanScreen()),
          );
        },
        backgroundColor: accentColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Buat Proyek Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSummaryHeader(Color accentColor, int active, int pending, int done, bool isDark) {
    final items = [
      {'label': 'Total Proyek', 'val': '${_projects.length}', 'color': accentColor, 'icon': Icons.folder_outlined},
      {'label': 'Berjalan', 'val': '$active', 'color': const Color(0xFF10B981), 'icon': Icons.play_circle_outline},
      {'label': 'Menunggu', 'val': '$pending', 'color': const Color(0xFFF59E0B), 'icon': Icons.hourglass_top_outlined},
      {'label': 'Selesai', 'val': '$done', 'color': const Color(0xFF3B82F6), 'icon': Icons.check_circle_outline},
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
              border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon((it['icon'] as IconData?) ?? Icons.image_outlined, color: it['color'] as Color, size: 20),
                const SizedBox(height: 6),
                Text(it['val'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(it['label'] as String, style: TextStyle(fontSize: 10, color: isDark ? AppTheme.textMuted : Colors.grey.shade600)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> p, Color accentColor, bool isDark) {
    final statusColor = p['statusColor'] as Color;
    final progressPct = ((p['progress'] as double) * 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  p['title'] as String,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(p['status'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: isDark ? AppTheme.textMuted : Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(p['creator'] as String, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : Colors.grey.shade600)),
              const Spacer(),
              Icon(Icons.calendar_today_outlined, size: 14, color: isDark ? AppTheme.textMuted : Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(p['deadline'] as String, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progres Pekerjaan', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : Colors.grey.shade500)),
              Text('$progressPct%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: p['progress'] as double,
              minHeight: 8,
              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                p['budget'] as String? ?? 'Rp 0',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: accentColor),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DirectMessageScreen()));
                    },
                    tooltip: 'Chat Partner',
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Detail Brief', style: TextStyle(fontSize: 11)),
                  ),
                ],
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
      child: Center(
        child: Column(
          children: [
            Icon(Icons.folder_open_outlined, size: 48, color: isDark ? AppTheme.textMuted : Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('Belum ada proyek pada status ini', style: TextStyle(fontSize: 14, color: isDark ? AppTheme.textMuted : Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
