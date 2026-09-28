import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/subrole_theme_engine.dart';
import '../models/user_model.dart';
import '../services/job_contract_service.dart';

import '../widgets/skeleton/skeleton_list.dart';
import '../widgets/app_breadcrumbs.dart';
import '../widgets/app_sweet_alert.dart';
import 'main_navigation.dart';

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

  bool get _isSchool {
    final sub = (widget.user?.subRole ?? '').toLowerCase();
    return sub == 'institution' ||
        sub == 'institusi' ||
        sub == 'sekolah' ||
        sub == 'kampus' ||
        sub == 'school';
  }

  List<String> get _filterOptions => _isSchool
      ? ['Semua', 'Event', 'Workshop', 'Monitoring', 'Deadline']
      : ['Semua', 'Online', 'Offline', 'Deadline'];

  List<Map<String, dynamic>> _agendaList = [];

  @override
  void initState() {
    super.initState();
    _fetchRealtimeAgenda();
  }

  Future<void> _fetchRealtimeAgenda() async {
    setState(() => _isLoading = true);
    try {
      final contracts = await JobContractService.getUserContracts();
      final List<Map<String, dynamic>> list = [];
      for (final c in contracts) {
        if (c.deadline != null) {
          final dt = c.deadline!;
          final months = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'Mei',
            'Jun',
            'Jul',
            'Agu',
            'Sep',
            'Okt',
            'Nov',
            'Des',
          ];
          final monthStr = months[dt.month - 1];
          list.add({
            'id': c.id,
            'title': c.title,
            'date': dt.day.toString().padLeft(2, '0'),
            'month': monthStr,
            'time': '23:59 WIB', // Placeholder
            'type': 'Deadline',
            'typeColor': const Color(0xFFEF4444),
            'icon': Icons.alarm_outlined,
            'location': 'Kreavana Workspace',
            'organizer': c.creatorName,
          });
        }
      }
      if (mounted) {
        setState(() {
          _agendaList = list;
        });
      }
    } catch (_) {
      // API error
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

    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: Navigator.canPop(context),
        toolbarHeight: 80,
        titleSpacing: isDesktop ? 32 : 16,
        elevation: 0,
        title: Text(
          _isSchool ? 'Kegiatan & Event Sekolah' : 'Agenda Kegiatan',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRealtimeAgenda,
            tooltip: 'Refresh Realtime',
          ),
          SizedBox(width: isDesktop ? 24 : 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRealtimeAgenda,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 32 : 16,
            16,
            isDesktop ? 32 : 16,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  BreadcrumbItem(
                    label: _isSchool ? 'Kegiatan & Event' : 'Agenda',
                    icon: Icons.calendar_today_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // ── Top Summary Header Card ──
              _buildAgendaHeader(accentColor, isDark),
              const SizedBox(height: 20),

              // ── Search & Filter Row ──
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: _isSchool
                      ? 'Cari event, workshop, ujian magang, atau rapat mitra...'
                      : 'Cari agenda, meeting, atau deadline...',
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
                  children: _filterOptions.map((f) {
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
                _buildEmptyState(accentColor, isDark)
              else
                ...filtered.map(
                  (item) => _buildAgendaCard(item, accentColor, isDark),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: isDesktop
          ? null
          : Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.width < 900 ? 76 : 0,
              ),
              child: FloatingActionButton.extended(
                heroTag: 'agenda_fab',
                onPressed: () => _showAddAgendaModal(context, accentColor),
                backgroundColor: accentColor,
                icon: const Icon(Icons.event, color: Colors.white),
                label: Text(
                  _isSchool ? 'Tambah Kegiatan' : 'Tambah Agenda',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
    );
  }

  Widget _buildAgendaHeader(Color accentColor, bool isDark) {
    final upcomingCount = _agendaList.length;
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 24 : 18),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSchool ? 'Jadwal & Agenda Sekolah' : 'Jadwal & Agenda Terdekat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isDesktop ? 18 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isSchool
                      ? 'Terdapat $upcomingCount agenda kegiatan atau event terjadwal'
                      : 'Anda memiliki $upcomingCount agenda terjadwal',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isDesktop)
            ElevatedButton.icon(
              onPressed: () => _showAddAgendaModal(context, accentColor),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(_isSchool ? 'Tambah Kegiatan / Event' : 'Tambah Agenda'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: accentColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: Colors.white,
                size: 26,
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
                    if (isReminded) {
                      AppSweetAlert.info(
                        context,
                        'Pengingat dibatalkan untuk agenda ini.',
                        title: 'Pengingat Dinonaktifkan',
                      );
                    } else {
                      AppSweetAlert.success(
                        context,
                        'Pengingat (Alarm) berhasil diaktifkan!',
                        title: 'Pengingat Disetel',
                      );
                    }
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

  Widget _buildEmptyState(Color accentColor, bool isDark) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.event_available_rounded,
                  size: 36,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _selectedFilter == 'Semua'
                    ? (_isSchool
                        ? 'Belum Ada Kegiatan & Event Terjadwal'
                        : 'Belum Ada Agenda Terjadwal')
                    : 'Tidak Ada Agenda pada Kategori "$_selectedFilter"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isSchool
                    ? 'Buat jadwal kegiatan sekolah, rapat kemitraan industri, monitoring magang siswa, atau workshop kreatif di sini.'
                    : 'Tambahkan agenda meeting online, jadwal shooting, atau batas deadline proyek Anda agar terpantau rapi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: () => _showAddAgendaModal(context, accentColor),
                icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                label: Text(
                  _isSchool ? 'Tambah Kegiatan / Event Baru' : 'Tambah Agenda Baru',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddAgendaModal(BuildContext context, Color accentColor) {
    final titleCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    String typeSel = _isSchool ? 'Event' : 'Online';

    final schoolTypes = [
      {'val': 'Event', 'label': 'Event / Pameran Sekolah'},
      {'val': 'Workshop', 'label': 'Workshop & Pelatihan Siswa'},
      {'val': 'Monitoring', 'label': 'Monitoring & Evaluasi PKL'},
      {'val': 'Online', 'label': 'Online Meeting Mitra'},
      {'val': 'Deadline', 'label': 'Deadline Laporan Siswa'},
      {'val': 'Lainnya', 'label': 'Lainnya'},
    ];

    final standardTypes = [
      {'val': 'Online', 'label': 'Online Meeting'},
      {'val': 'Offline', 'label': 'Offline / Shooting Day'},
      {'val': 'Deadline', 'label': 'Deadline Penyerahan'},
      {'val': 'Review', 'label': 'Review Project'},
      {'val': 'Client', 'label': 'Client Briefing'},
      {'val': 'Lainnya', 'label': 'Lainnya'},
    ];

    final typeOptions = _isSchool ? schoolTypes : standardTypes;

    Widget buildFormContent(StateSetter setModalState, BuildContext ctx) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isSchool ? 'Tambah Kegiatan / Event' : 'Tambah Agenda Baru',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: titleCtrl,
            decoration: InputDecoration(
              labelText: _isSchool ? 'Nama Kegiatan / Event' : 'Judul Agenda / Meeting',
              hintText: _isSchool ? 'Misal: Kunjungan Industri Studio Animasi' : 'Misal: Briefing Pra-Produksi',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: timeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Waktu / Jam',
                    hintText: '09:00 - 12:00 WIB',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: typeSel,
                  isExpanded: true,
                  items: typeOptions.map((opt) {
                    return DropdownMenuItem(
                      value: opt['val'],
                      child: Text(opt['label']!, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) => setModalState(() => typeSel = v!),
                  decoration: InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: locCtrl,
            decoration: InputDecoration(
              labelText: 'Tempat / Lokasi (Opsional)',
              hintText: _isSchool ? 'Misal: Lab Animasi Lt. 2 / Studio Mitra' : 'Misal: Google Meet / Studio Jakarta',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) {
                  AppSweetAlert.warning(
                    ctx,
                    'Judul kegiatan wajib diisi terlebih dahulu.',
                    title: 'Form Belum Lengkap',
                  );
                  return;
                }
                setState(() {
                  final now = DateTime.now();
                  Color getTypeColor(String type) {
                    if (type == 'Online' || type == 'Client') return const Color(0xFF3B82F6);
                    if (type == 'Offline' || type == 'Event') return const Color(0xFFF97316);
                    if (type == 'Deadline' || type == 'Review') return const Color(0xFFEF4444);
                    if (type == 'Workshop' || type == 'Monitoring') return const Color(0xFF10B981);
                    return Colors.grey.shade600;
                  }

                  IconData getTypeIcon(String type) {
                    if (type == 'Online' || type == 'Client') return Icons.videocam_outlined;
                    if (type == 'Offline' || type == 'Event') return Icons.festival_outlined;
                    if (type == 'Deadline') return Icons.alarm_outlined;
                    if (type == 'Review') return Icons.rate_review_outlined;
                    if (type == 'Workshop') return Icons.school_outlined;
                    if (type == 'Monitoring') return Icons.monitor_heart_outlined;
                    return Icons.event_note_outlined;
                  }

                  final months = [
                    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
                    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
                  ];

                  _agendaList.insert(0, {
                    'id': '${now.millisecondsSinceEpoch}',
                    'title': titleCtrl.text.trim(),
                    'date': '${now.day}'.padLeft(2, '0'),
                    'month': months[now.month - 1],
                    'time': timeCtrl.text.trim().isEmpty ? '09:00 WIB' : timeCtrl.text.trim(),
                    'type': typeSel,
                    'typeColor': getTypeColor(typeSel),
                    'icon': getTypeIcon(typeSel),
                    'location': locCtrl.text.trim().isNotEmpty
                        ? locCtrl.text.trim()
                        : (typeSel == 'Online' ? 'Google Meet / Virtual' : 'Kampus / Sekolah'),
                    'organizer': widget.user?.name ?? 'Sekolah',
                  });
                });
                Navigator.pop(ctx);
                AppSweetAlert.success(
                  context,
                  _isSchool
                      ? 'Kegiatan sekolah berhasil ditambahkan ke jadwal!'
                      : 'Agenda berhasil ditambahkan ke jadwal!',
                  title: 'Berhasil',
                );
              },
              child: const Text(
                'Simpan Kegiatan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 700;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: StatefulBuilder(
              builder: (ctx, setModalState) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: buildFormContent(setModalState, ctx),
                );
              },
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setModalState) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: buildFormContent(setModalState, ctx),
              );
            },
          );
        },
      );
    }
  }
}
