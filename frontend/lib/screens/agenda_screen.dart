import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/subrole_theme_engine.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

import '../widgets/skeleton/skeleton_list.dart';

class AgendaScreen extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const AgendaScreen({super.key, this.user, this.onUserUpdated});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  bool _isLoading = false;
  final Set<String> _remindedAgendas = {};
  String _selectedFilter = 'Semua';
  String _searchQuery = '';

  List<Map<String, dynamic>> _agendaList = [
    {
      'id': '1',
      'title': 'Meeting Briefing Proyek Foto Katalog',
      'date': '24',
      'month': 'Mei',
      'time': '09:00 - 10:00 WIB',
      'type': 'Online',
      'typeColor': const Color(0xFF3B82F6),
      'icon': Icons.videocam_outlined,
      'location': 'Google Meet / Room Kreavana',
      'organizer': 'Aruna Studio',
    },
    {
      'id': '2',
      'title': 'Review Draft Desain Poster Campaign',
      'date': '25',
      'month': 'Mei',
      'time': '14:00 - 15:00 WIB',
      'type': 'Online',
      'typeColor': const Color(0xFF3B82F6),
      'icon': Icons.videocam_outlined,
      'location': 'Virtual Room',
      'organizer': 'Graphix Studio',
    },
    {
      'id': '3',
      'title': 'Shooting Day - Video Promosi Instagram',
      'date': '27',
      'month': 'Mei',
      'time': '08:00 - 17:00 WIB',
      'type': 'Offline',
      'typeColor': const Color(0xFFF97316),
      'icon': Icons.location_on_outlined,
      'location': 'Studio 8, Jakarta Selatan',
      'organizer': 'Frame Story',
    },
    {
      'id': '4',
      'title': 'Deadline Penyerahan Hasil Akhir Video',
      'date': '29',
      'month': 'Mei',
      'time': '23:59 WIB',
      'type': 'Deadline',
      'typeColor': const Color(0xFFEF4444),
      'icon': Icons.alarm_outlined,
      'location': 'Upload via Kreavana Workspace',
      'organizer': 'Internal System',
    },
    {
      'id': '5',
      'title': 'Konsultasi Desain Banner & Marketing',
      'date': '02',
      'month': 'Jun',
      'time': '10:00 - 11:00 WIB',
      'type': 'Online',
      'typeColor': const Color(0xFF3B82F6),
      'icon': Icons.videocam_outlined,
      'location': 'Call Room',
      'organizer': 'Dinas Kominfo Partner',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchRealtimeAgenda();
  }

  Future<void> _fetchRealtimeAgenda() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('/agenda');
      if (res['status'] == true && res['data'] != null) {
        final list = List<Map<String, dynamic>>.from(res['data']);
        if (mounted) {
          setState(() {
            _agendaList = list;
          });
        }
      }
    } catch (_) {
      // Keep rich fallback data
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

    final filtered = _agendaList.where((item) {
      final type = item['type'] as String;
      if (_selectedFilter != 'Semua' && type != _selectedFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = (item['title'] as String).toLowerCase();
        final loc = (item['location'] as String).toLowerCase();
        return title.contains(q) || loc.contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text(
          'Agenda Kegiatan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRealtimeAgenda,
            tooltip: 'Refresh Realtime',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRealtimeAgenda,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Summary Header Card ──
              _buildAgendaHeader(accentColor, isDark),
              const SizedBox(height: 20),

              // ── Search & Filter Row ──
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Cari agenda, meeting, atau deadline...',
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
                  children: ['Semua', 'Online', 'Offline', 'Deadline'].map((f) {
                    final isSel = _selectedFilter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f),
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
                          if (val) setState(() => _selectedFilter = f);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // ── Agenda List ──
              if (_isLoading)
                const SkeletonList()
              else if (filtered.isEmpty)
                _buildEmptyState(isDark)
              else
                ...filtered.map(
                  (item) => _buildAgendaCard(item, accentColor, isDark),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAgendaModal(context, accentColor),
        backgroundColor: accentColor,
        icon: const Icon(Icons.event, color: Colors.white),
        label: const Text(
          'Tambah Agenda',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildAgendaHeader(Color accentColor, bool isDark) {
    final upcomingCount = _agendaList.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor,
            HSLColor.fromColor(accentColor).withLightness(0.25).toColor(),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Jadwal & Agenda Terdekat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Anda memiliki $upcomingCount agenda terjadwal',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaCard(
    Map<String, dynamic> item,
    Color accentColor,
    bool isDark,
  ) {
    final typeColor = item['typeColor'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Square Badge
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item['date'] as String,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                Text(
                  item['month'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['title'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item['type'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      (item['icon'] as IconData?) ?? Icons.image_outlined,
                      size: 13,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item['time'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 13,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item['location'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.textMuted
                              : Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    final isReminded = _remindedAgendas.contains(item['id']);
                    setState(() {
                      if (isReminded) {
                        _remindedAgendas.remove(item['id']);
                      } else {
                        _remindedAgendas.add(item['id']);
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isReminded
                              ? 'Pengingat dibatalkan untuk agenda ini.'
                              : 'Pengingat (Alarm) berhasil disetel!',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: Icon(
                    _remindedAgendas.contains(item['id'])
                        ? Icons.notifications_off
                        : Icons.notifications_active,
                    size: 16,
                  ),
                  label: Text(
                    _remindedAgendas.contains(item['id'])
                        ? 'Batal Ingatkan'
                        : 'Ingatkan Saya',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _remindedAgendas.contains(item['id'])
                        ? Colors.grey.shade600
                        : accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
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
            Icons.event_busy_outlined,
            size: 48,
            color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'Tidak ada agenda pada kategori ini',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddAgendaModal(BuildContext context, Color accentColor) {
    final titleCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    String typeSel = 'Online';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                    'Tambah Agenda Baru',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Judul Agenda / Meeting',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: timeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Waktu (misal: 10:00 - 11:00 WIB)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: typeSel,
                    items: const [
                      DropdownMenuItem(
                        value: 'Online',
                        child: Text('Online Meeting'),
                      ),
                      DropdownMenuItem(
                        value: 'Offline',
                        child: Text('Offline / Shooting Day'),
                      ),
                      DropdownMenuItem(
                        value: 'Deadline',
                        child: Text('Deadline Penyerahan'),
                      ),
                      DropdownMenuItem(
                        value: 'Review',
                        child: Text('Review Project'),
                      ),
                      DropdownMenuItem(
                        value: 'Client',
                        child: Text('Client Briefing'),
                      ),
                      DropdownMenuItem(
                        value: 'Lainnya',
                        child: Text('Lainnya'),
                      ),
                    ],
                    onChanged: (v) => setModalState(() => typeSel = v!),
                    decoration: const InputDecoration(
                      labelText: 'Tipe Agenda',
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
                            final now = DateTime.now();
                            Color getTypeColor(String type) {
                              if (type == 'Online' || type == 'Client')
                                return const Color(0xFF3B82F6);
                              if (type == 'Offline')
                                return const Color(0xFFF97316);
                              if (type == 'Deadline' || type == 'Review')
                                return const Color(0xFFEF4444);
                              return Colors.grey.shade600; // Lainnya
                            }

                            IconData getTypeIcon(String type) {
                              if (type == 'Online' || type == 'Client')
                                return Icons.videocam_outlined;
                              if (type == 'Offline')
                                return Icons.location_on_outlined;
                              if (type == 'Deadline')
                                return Icons.alarm_outlined;
                              if (type == 'Review')
                                return Icons.rate_review_outlined;
                              return Icons.event_note_outlined; // Lainnya
                            }

                            _agendaList.insert(0, {
                              'id': '${now.millisecondsSinceEpoch}',
                              'title': titleCtrl.text,
                              'date': '${now.day}',
                              'month': 'Agu',
                              'time': timeCtrl.text.isEmpty
                                  ? '10:00 WIB'
                                  : timeCtrl.text,
                              'type': typeSel,
                              'typeColor': getTypeColor(typeSel),
                              'icon': getTypeIcon(typeSel),
                              'location':
                                  (typeSel == 'Online' || typeSel == 'Client')
                                  ? 'Virtual Call Room'
                                  : (typeSel == 'Offline'
                                        ? 'Venue / Studio'
                                        : '-'),
                              'organizer': widget.user?.name ?? 'Saya',
                            });
                          });
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text(
                        'Simpan Agenda',
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
      },
    );
  }
}
