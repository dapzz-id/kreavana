import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/subrole_theme_engine.dart';
import '../models/user_model.dart';
import '../services/job_contract_service.dart';
import '../services/opportunity_service.dart';
import '../models/job_contract.dart';
import '../models/opportunity_model.dart';

import '../widgets/skeleton/skeleton_list.dart';
import '../widgets/app_breadcrumbs.dart';
import '../widgets/app_sweet_alert.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../widgets/app_pagination_bar.dart';
import '../services/user_store.dart';
import '../services/api_service.dart';
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
  int _currentPage = 1;
  static const int _pageSize = 6;

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

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  String _formatDateRange(DateTime start, [DateTime? end]) {
    if (end == null || (start.year == end.year && start.month == end.month && start.day == end.day)) {
      return '${start.day.toString().padLeft(2, '0')} ${_months[start.month - 1]} ${start.year}';
    }

    if (start.year == end.year && start.month == end.month) {
      return '${start.day.toString().padLeft(2, '0')} - ${end.day.toString().padLeft(2, '0')} ${_months[start.month - 1]} ${start.year}';
    }

    if (start.year == end.year) {
      return '${start.day.toString().padLeft(2, '0')} ${_months[start.month - 1]} - ${end.day.toString().padLeft(2, '0')} ${_months[end.month - 1]} ${start.year}';
    }

    return '${start.day.toString().padLeft(2, '0')} ${_months[start.month - 1]} ${start.year} - ${end.day.toString().padLeft(2, '0')} ${_months[end.month - 1]} ${end.year}';
  }

  Future<void> _fetchRealtimeAgenda() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        JobContractService.getUserContracts().catchError((_) => <JobContract>[]),
        OpportunityService.getMyOpportunities().catchError((_) => <OpportunityModel>[]),
        ApiService.get('institution/resources').catchError((_) => <String, dynamic>{'status': false}),
      ]);

      final contracts = results[0] as List<JobContract>;
      final opportunities = results[1] as List<OpportunityModel>;
      final resResources = results[2] as Map<String, dynamic>;
      final List<Map<String, dynamic>> list = [];

      // 1. Process Institution Events (Kegiatan, Event & Lomba dari Sekolah)
      if (resResources['status'] == true && resResources['data'] is List) {
        for (final item in resResources['data']) {
          if (item is Map && item['resource_type'] == 'events') {
            final meta = item['metadata'] as Map<String, dynamic>? ?? {};
            final dateStr = meta['event_date']?.toString();
            final DateTime dt = dateStr != null ? (DateTime.tryParse(dateStr) ?? DateTime.now()) : DateTime.now();
            final isComp = meta['is_competition'] == true ||
                (item['title']?.toString().toLowerCase().contains('lomba') ?? false) ||
                (item['title']?.toString().toLowerCase().contains('hackathon') ?? false);

            list.add({
              'id': 'res_${item['id'] ?? item['title']}',
              'title': item['title'] ?? 'Event Kampus',
              'startDate': dt,
              'endDate': dt,
              'date': dt.day.toString().padLeft(2, '0'),
              'month': _months[dt.month - 1],
              'year': '${dt.year}',
              'endDateStr': dt.day.toString().padLeft(2, '0'),
              'endMonthStr': _months[dt.month - 1],
              'endYearStr': '${dt.year}',
              'dateRange': _formatDateRange(dt, dt),
              'time': '09:00 - 16:00 WIB',
              'type': isComp ? 'Event' : 'Offline',
              'typeColor': isComp ? const Color(0xFFEF4444) : const Color(0xFF4338CA),
              'icon': isComp ? Icons.emoji_events_outlined : Icons.festival_outlined,
              'location': meta['location']?.toString() ?? (widget.user?.location ?? 'Kampus Institusi'),
              'organizer': widget.user?.name ?? 'Institusi Penyelenggara',
            });
          }
        }
      }

      // 2. Process Opportunities (Kegiatan & Event Sekolah)
      for (final opp in opportunities) {
        final startStr = opp.eventStartDate ?? opp.eventDate ?? opp.deadline ?? opp.createdAt;
        final DateTime start = startStr != null ? (DateTime.tryParse(startStr) ?? DateTime.now()) : DateTime.now();

        final endStr = opp.eventEndDate ?? opp.eventDate;
        final DateTime end = endStr != null ? (DateTime.tryParse(endStr) ?? start) : start;

        list.add({
          'id': 'opp_${opp.id}',
          'title': opp.title,
          'startDate': start,
          'endDate': end,
          'date': start.day.toString().padLeft(2, '0'),
          'month': _months[start.month - 1],
          'year': '${start.year}',
          'endDateStr': end.day.toString().padLeft(2, '0'),
          'endMonthStr': _months[end.month - 1],
          'endYearStr': '${end.year}',
          'dateRange': _formatDateRange(start, end),
          'time': '08:00 - 16:00 WIB',
          'type': _isSchool ? 'Event' : 'Offline',
          'typeColor': const Color(0xFFF97316),
          'icon': Icons.festival_outlined,
          'location': (opp.location != null && opp.location!.isNotEmpty)
              ? opp.location!
              : (opp.address != null && opp.address!.isNotEmpty
                  ? opp.address!
                  : 'Institusi Pendidikan'),
          'organizer': opp.poster?.name ?? widget.user?.name ?? 'Institusi',
        });
      }

      // 3. Process Contracts
      for (final c in contracts) {
        final start = c.scheduledStartDate ?? c.deadline ?? DateTime.now();
        final end = c.scheduledEndDate ?? c.deadline ?? start;
        final isDeadline = c.deadline != null && c.scheduledStartDate == null;

        list.add({
          'id': 'contract_${c.id}',
          'title': c.title,
          'startDate': start,
          'endDate': end,
          'date': start.day.toString().padLeft(2, '0'),
          'month': _months[start.month - 1],
          'year': '${start.year}',
          'endDateStr': end.day.toString().padLeft(2, '0'),
          'endMonthStr': _months[end.month - 1],
          'endYearStr': '${end.year}',
          'dateRange': _formatDateRange(start, end),
          'time': isDeadline ? 'Tenggat: 23:59 WIB' : '09:00 - 17:00 WIB',
          'type': isDeadline ? 'Deadline' : (_isSchool ? 'Workshop' : 'Client'),
          'typeColor': isDeadline ? const Color(0xFFEF4444) : const Color(0xFF10B981),
          'icon': isDeadline ? Icons.alarm_outlined : Icons.school_outlined,
          'location': 'Kreavana Workspace',
          'organizer': c.creatorName,
        });
      }

      // Sort by startDate ascending (kegiatan terdekat lebih dulu)
      list.sort((a, b) {
        final dtA = a['startDate'] as DateTime? ?? DateTime.now();
        final dtB = b['startDate'] as DateTime? ?? DateTime.now();
        return dtA.compareTo(dtB);
      });

      if (mounted) {
        setState(() {
          _agendaList = list;
          _currentPage = 1;
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

    final totalItems = filtered.length;
    final totalPages = totalItems > 0 ? (totalItems / _pageSize).ceil() : 1;
    final safePage = _currentPage.clamp(1, totalPages);
    final startIndex = (safePage - 1) * _pageSize;
    final endIndex = math.min(startIndex + _pageSize, totalItems);
    final pagedAgendas = totalItems > 0 && startIndex < totalItems
        ? filtered.sublist(startIndex, endIndex)
        : <Map<String, dynamic>>[];

    final isDesktop = MediaQuery.of(context).size.width > 900;

    final scaffold = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !isDesktop && Navigator.canPop(context),
        toolbarHeight: 80,
        titleSpacing: isDesktop ? 32 : 16,
        elevation: 0,
        title: Text(
          _isSchool ? 'Kegiatan & Event Institusi' : 'Agenda Kegiatan',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isDesktop) ...[
            ElevatedButton.icon(
              onPressed: () => _showAddAgendaModal(context, accentColor),
              icon: const Icon(Icons.add, size: 16),
              label: Text(_isSchool ? 'Buat Event / Lomba' : 'Tambah Agenda'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
          ],
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
                onChanged: (v) => setState(() {
                  _searchQuery = v;
                  _currentPage = 1;
                }),
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
                          if (val) {
                            setState(() {
                              _selectedFilter = f;
                              _currentPage = 1;
                            });
                          }
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
              else ...[
                ...pagedAgendas.map(
                  (item) => _buildAgendaCard(item, accentColor, isDark),
                ),
                AppPaginationBar(
                  currentPage: safePage,
                  totalItems: totalItems,
                  pageSize: _pageSize,
                  itemLabel: _isSchool ? 'kegiatan' : 'agenda',
                  primaryColor: accentColor,
                  onPageChanged: (newPage) {
                    setState(() => _currentPage = newPage);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: isDesktop
          ? null
          : Padding(
              padding: EdgeInsets.only(
                bottom: 0,
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

    final effectiveUser = widget.user ?? currentUserNotifier.value;
    if (effectiveUser != null) {
      return DesktopSidebarLayout(
        user: effectiveUser,
        activeRoute: 'agenda',
        onUserUpdated: widget.onUserUpdated,
        child: scaffold,
      );
    }

    return scaffold;
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
                  _isSchool ? 'Jadwal & Agenda Institusi' : 'Jadwal & Agenda Terdekat',
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
    final title = item['title']?.toString() ?? 'Kegiatan Agenda';
    final location = item['location']?.toString() ?? 'Lokasi Ditentukan';
    final isOnline = location.toLowerCase().contains('meet') ||
        location.toLowerCase().contains('zoom') ||
        location.toLowerCase().contains('virtual') ||
        (item['type']?.toString().toLowerCase().contains('online') ?? false);

    final start = item['startDate'] as DateTime?;
    final end = item['endDate'] as DateTime?;
    final durationDays = (start != null && end != null) ? (end.difference(start).inDays + 1).clamp(1, 365) : 1;

    // Resolve Category, Badge Label, and Type Color
    final String categoryBadge;
    final Color typeColor;
    final titleLower = title.toLowerCase();

    if (titleLower.contains('dies natalis') || titleLower.contains('seni')) {
      categoryBadge = '🎬 Produksi Video 4K';
      typeColor = const Color(0xFF2563EB); // Royal Blue
    } else if (titleLower.contains('coffee') || titleLower.contains('expo')) {
      categoryBadge = '☕ Expo Industri Kreatif';
      typeColor = const Color(0xFFD97706); // Amber
    } else if (titleLower.contains('hackathon') || titleLower.contains('jam') || titleLower.contains('lomba')) {
      categoryBadge = '💻 Hackathon & Game Jam';
      typeColor = const Color(0xFF7C3AED); // Purple
    } else if (titleLower.contains('workshop') || titleLower.contains('masterclass')) {
      categoryBadge = '🎨 Workshop & Pelatihan';
      typeColor = const Color(0xFF059669); // Emerald
    } else {
      categoryBadge = item['type']?.toString() ?? 'Agenda Resmi';
      typeColor = item['typeColor'] as Color? ?? accentColor;
    }

    final dateDisplay = item['endDateStr'] != null && item['endDateStr'] != item['date']
        ? '${item['date']}-${item['endDateStr']}'
        : (item['date'] as String? ?? '01');

    final isReminded = _remindedAgendas.contains(item['id']);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. LEFT ACCENT STRIPE (Color-coded indicator)
              Container(
                width: 4,
                color: typeColor,
              ),

              // 2. MAIN INNER CARD CONTENT
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // CALENDAR BLOCK (74px width, unified date anchor)
                      Container(
                        width: 74,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1B33) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2D2A4A) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Month Header Strip
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: typeColor,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(11),
                                  topRight: Radius.circular(11),
                                ),
                              ),
                              child: Text(
                                (item['month'] as String? ?? 'JAN').toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            // Date & Duration
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              child: Column(
                                children: [
                                  Text(
                                    dateDisplay,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: dateDisplay.length > 4 ? 13.5 : 17.5,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '${item['year'] ?? DateTime.now().year}',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                  if (durationDays > 1) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: typeColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$durationDays Hari',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                          color: typeColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 16),

                      // RIGHT COLUMN: METADATA & ACTIONS
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: Category tag + Format tag + Spacer + Reminder Button
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      // Category Tag
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: typeColor.withValues(alpha: 0.10),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: typeColor.withValues(alpha: 0.25)),
                                        ),
                                        child: Text(
                                          categoryBadge,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: typeColor,
                                          ),
                                        ),
                                      ),
                                      // Mode Badge (Online / Offline)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isOnline ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isOnline ? const Color(0xFFBFDBFE) : const Color(0xFFBBF7D0),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isOnline ? Icons.videocam_rounded : Icons.location_on_rounded,
                                              size: 11,
                                              color: isOnline ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isOnline ? 'Daring' : 'Luring',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: isOnline ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Reminder Action Button (Top-right aligned)
                                InkWell(
                                  onTap: () {
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
                                        'Pengingat untuk "$title" telah dinonaktifkan.',
                                        title: 'Pengingat Dibatalkan',
                                      );
                                    } else {
                                      AppSweetAlert.success(
                                        context,
                                        'Alarm & pengingat kalender berhasil disetel untuk "$title"!',
                                        title: 'Pengingat Disetel',
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isReminded
                                          ? const Color(0xFF16A34A)
                                          : (isDark ? const Color(0xFF201D35) : const Color(0xFFF8FAFC)),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isReminded
                                            ? const Color(0xFF16A34A)
                                            : (isDark ? const Color(0xFF383457) : const Color(0xFFCBD5E1)),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isReminded ? Icons.check_circle_rounded : Icons.notifications_none_rounded,
                                          size: 13,
                                          color: isReminded ? Colors.white : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569)),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          isReminded ? 'Pengingat Aktif' : 'Ingatkan Saya',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isReminded ? Colors.white : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Event Title
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            const SizedBox(height: 4),

                            // Organizer Subtitle
                            Text(
                              'Penyelenggara: ${item['organizer'] ?? (widget.user?.name ?? 'Institusi Penyelenggara')}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Inline Metadata Strip (Unified without bloated gray bar)
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.schedule_rounded,
                                      size: 14,
                                      color: Color(0xFFD97706),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      item['time'] as String? ?? '09:00 - 16:00 WIB',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.place_rounded,
                                      size: 14,
                                      color: Color(0xFFEF4444),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      location,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
                    ? 'Buat jadwal kegiatan institusi, rapat kemitraan industri, monitoring magang peserta, atau workshop kreatif di sini.'
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
    final timeCtrl = TextEditingController(text: '09:00 - 16:00 WIB');
    final locCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 2));
    String typeSel = _isSchool ? 'Event' : 'Online';
    bool isOnlineMode = typeSel == 'Online';

    final schoolTypes = [
      {'val': 'Event', 'label': 'Event / Pameran Seni', 'icon': Icons.festival_rounded},
      {'val': 'Workshop', 'label': 'Workshop & Pelatihan', 'icon': Icons.school_rounded},
      {'val': 'Monitoring', 'label': 'Monitoring & PKL', 'icon': Icons.monitor_heart_rounded},
      {'val': 'Online', 'label': 'Online Meeting DUDI', 'icon': Icons.videocam_rounded},
      {'val': 'Deadline', 'label': 'Deadline Laporan', 'icon': Icons.alarm_rounded},
      {'val': 'Lainnya', 'label': 'Lainnya', 'icon': Icons.event_note_rounded},
    ];

    final standardTypes = [
      {'val': 'Online', 'label': 'Online Meeting', 'icon': Icons.videocam_rounded},
      {'val': 'Offline', 'label': 'Offline / Shooting Day', 'icon': Icons.camera_alt_rounded},
      {'val': 'Deadline', 'label': 'Deadline Penyerahan', 'icon': Icons.alarm_rounded},
      {'val': 'Review', 'label': 'Review Project', 'icon': Icons.rate_review_rounded},
      {'val': 'Client', 'label': 'Client Briefing', 'icon': Icons.business_center_rounded},
      {'val': 'Lainnya', 'label': 'Lainnya', 'icon': Icons.event_note_rounded},
    ];

    final typeOptions = _isSchool ? schoolTypes : standardTypes;

    final timePresets = [
      '08:00 - 12:00 WIB',
      '09:00 - 16:00 WIB',
      '13:00 - 17:00 WIB',
      'Sepanjang Hari',
    ];

    Widget buildSectionCard({
      required String title,
      required IconData icon,
      required List<Widget> children,
    }) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
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
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: accentColor),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
    }

    Widget buildFormContent(StateSetter setModalState, BuildContext ctx) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final durationDays = (endDate.difference(startDate).inDays + 1).clamp(1, 365);

      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── TOP HEADER ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor, HSLColor.fromColor(accentColor).withLightness(0.35).toColor()],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.event_available_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _isSchool ? 'Tambah Kegiatan & Event Institusi' : 'Tambah Agenda Baru',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Jadwal Resmi',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accentColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _isSchool
                            ? 'Jadwalkan kegiatan akademik, meeting DUDI, pameran karya, atau workshop talenta.'
                            : 'Kelola jadwal meeting klien, pra-produksi, dan batas penyerahan karya.',
                        style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── PANDUAN PENJADWALAN AGENDA (GUIDANCE BANNER) ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFEFF6FF),
                    const Color(0xFFF0FDF4),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lightbulb_rounded, size: 18, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Panduan Penjadwalan & Sinkronisasi Agenda:',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '• Kegiatan yang disimpan otomatis tersinkronisasi ke kalender instansi, pembimbing akademik, dan mitra industri.\n'
                          '• Tentukan rentang tanggal dan format acara (luring di lokasi institusi atau daring via link virtual).\n'
                          '• Sistem secara otomatis mengaktifkan alarm pengingat H-1 dan H-3 jam bagi seluruh partisipan.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: const Color(0xFF1E293B).withValues(alpha: 0.85),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── GROUP 1: INFORMASI POKOK AGENDA ──
            buildSectionCard(
              title: 'Informasi Pokok Kegiatan & Kategori',
              icon: Icons.title_rounded,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: _isSchool ? 'Nama Kegiatan / Event Resmi *' : 'Judul Agenda / Meeting *',
                    hintText: _isSchool ? 'Contoh: Dies Natalis, Expo Seni & Pameran Karya DUDI' : 'Contoh: Client Briefing & Review',
                    prefixIcon: Icon(Icons.edit_note_rounded, size: 20, color: accentColor),
                    filled: true,
                    fillColor: isDark ? AppTheme.cardBg : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Pilih Kategori Kegiatan:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: typeOptions.map((opt) {
                    final val = opt['val'] as String;
                    final label = opt['label'] as String;
                    final icon = opt['icon'] as IconData;
                    final isSelected = typeSel == val;

                    return InkWell(
                      onTap: () {
                        setModalState(() {
                          typeSel = val;
                          isOnlineMode = val == 'Online';
                          if (isOnlineMode && locCtrl.text.trim().isEmpty) {
                            locCtrl.text = 'Google Meet / Virtual';
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accentColor.withValues(alpha: 0.15)
                              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? accentColor : const Color(0xFFCBD5E1),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 14, color: isSelected ? accentColor : Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? accentColor : (isDark ? Colors.white70 : const Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── GROUP 2: PERIODE JADWAL & WAKTU PELAKSANAAN ──
            buildSectionCard(
              title: 'Periode Tanggal & Waktu Pelaksanaan',
              icon: Icons.calendar_month_rounded,
              children: [
                // 2 Date cards
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: startDate,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                            helpText: 'Pilih Tanggal Mulai (Awal Kegiatan)',
                          );
                          if (picked != null) {
                            setModalState(() {
                              startDate = picked;
                              if (endDate.isBefore(startDate)) {
                                endDate = startDate;
                              }
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.cardBg : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.event_outlined, size: 14, color: accentColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Mulai Pelaksanaan',
                                    style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${startDate.day.toString().padLeft(2, '0')} ${_months[startDate.month - 1]} ${startDate.year}',
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: accentColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF94A3B8)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$durationDays Hari',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: accentColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: endDate.isBefore(startDate) ? startDate : endDate,
                            firstDate: startDate,
                            lastDate: DateTime(2030),
                            helpText: 'Pilih Tanggal Selesai (Akhir Kegiatan)',
                          );
                          if (picked != null) {
                            setModalState(() {
                              endDate = picked;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.cardBg : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.event_available_outlined, size: 14, color: accentColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Selesai Pelaksanaan',
                                    style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${endDate.day.toString().padLeft(2, '0')} ${_months[endDate.month - 1]} ${endDate.year}',
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: accentColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Waktu / Jam
                TextField(
                  controller: timeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Waktu / Jam Pelaksanaan *',
                    hintText: 'Contoh: 09:00 - 16:00 WIB',
                    prefixIcon: const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFFD97706)),
                    filled: true,
                    fillColor: isDark ? AppTheme.cardBg : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: timePresets.map((preset) {
                    return ActionChip(
                      label: Text(preset, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setModalState(() {
                          timeCtrl.text = preset;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // Format Penyelenggaraan: Offline vs Online Mode
                Text(
                  'Format Penyelenggaraan:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setModalState(() {
                            isOnlineMode = false;
                            if (locCtrl.text == 'Google Meet / Virtual') locCtrl.clear();
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: !isOnlineMode ? const Color(0xFFF0FDF4) : (isDark ? AppTheme.cardBg : Colors.white),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: !isOnlineMode ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                              width: !isOnlineMode ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_on_rounded, size: 15, color: !isOnlineMode ? const Color(0xFF16A34A) : Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                'Luring / Offline (On-Site)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: !isOnlineMode ? const Color(0xFF16A34A) : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setModalState(() {
                            isOnlineMode = true;
                            if (locCtrl.text.isEmpty) locCtrl.text = 'Google Meet / Virtual';
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isOnlineMode ? const Color(0xFFEFF6FF) : (isDark ? AppTheme.cardBg : Colors.white),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isOnlineMode ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                              width: isOnlineMode ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam_rounded, size: 15, color: isOnlineMode ? const Color(0xFF2563EB) : Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                'Daring / Online (Virtual)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isOnlineMode ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── GROUP 3: LOKASI & TARGET PESERTA ──
            buildSectionCard(
              title: isOnlineMode ? 'Tautan & Akses Virtual' : 'Lokasi & Ruangan Pelaksanaan',
              icon: isOnlineMode ? Icons.link_rounded : Icons.place_rounded,
              children: [
                TextField(
                  controller: locCtrl,
                  decoration: InputDecoration(
                    labelText: isOnlineMode ? 'Tautan Meeting Online (Google Meet / Zoom)' : 'Nama Tempat / Gedung / Ruangan *',
                    hintText: isOnlineMode
                        ? 'Contoh: https://meet.google.com/xyz-abcd-efg'
                        : (_isSchool ? 'Contoh: Lab Animasi Lt. 2 / Ruang Sidang Utama' : 'Contoh: Studio Jakarta / Venue JCC'),
                    prefixIcon: Icon(
                      isOnlineMode ? Icons.video_call_rounded : Icons.location_city_rounded,
                      size: 18,
                      color: isOnlineMode ? const Color(0xFF2563EB) : const Color(0xFFEF4444),
                    ),
                    filled: true,
                    fillColor: isDark ? AppTheme.cardBg : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(
                    labelText: 'Target Peserta & Catatan Tambahan (Opsional)',
                    hintText: 'Contoh: Seluruh peserta bidang DKV & pembimbing magang industri.',
                    prefixIcon: const Icon(Icons.groups_rounded, size: 18, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: isDark ? AppTheme.cardBg : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── FOOTER ACTIONS ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      'Tersinkron ke Kalender Cloud Kreavana',
                      style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      style: FilledButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

                          final dateRangeText = _formatDateRange(startDate, endDate);

                          _agendaList.insert(0, {
                            'id': '${DateTime.now().millisecondsSinceEpoch}',
                            'title': titleCtrl.text.trim(),
                            'startDate': startDate,
                            'endDate': endDate,
                            'date': '${startDate.day}'.padLeft(2, '0'),
                            'month': _months[startDate.month - 1],
                            'year': '${startDate.year}',
                            'endDateStr': '${endDate.day}'.padLeft(2, '0'),
                            'endMonthStr': _months[endDate.month - 1],
                            'endYearStr': '${endDate.year}',
                            'dateRange': dateRangeText,
                            'time': timeCtrl.text.trim().isEmpty ? '09:00 - 16:00 WIB' : timeCtrl.text.trim(),
                            'type': typeSel,
                            'typeColor': getTypeColor(typeSel),
                            'icon': getTypeIcon(typeSel),
                            'location': locCtrl.text.trim().isNotEmpty
                                ? locCtrl.text.trim()
                                : (isOnlineMode ? 'Google Meet / Virtual' : 'Institusi Pendidikan'),
                            'organizer': widget.user?.name ?? 'Institusi',
                          });
                        });

                        if (_isSchool) {
                          ApiService.post('institution/resources', {
                            'resource_type': 'events',
                            'title': titleCtrl.text.trim(),
                            'description': notesCtrl.text.trim().isNotEmpty
                                ? notesCtrl.text.trim()
                                : 'Kegiatan resmi institusi & industri.',
                            'status': 'open',
                            'metadata': {
                              'category': typeSel,
                              'event_date': '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
                              'event_end_date': '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
                              'location': locCtrl.text.trim().isNotEmpty ? locCtrl.text.trim() : (widget.user?.location ?? 'Lingkungan Institusi'),
                              'registered_participants': 0,
                              'is_competition': typeSel.toLowerCase().contains('lomba') || titleCtrl.text.toLowerCase().contains('lomba'),
                            },
                          }).catchError((_) => <String, dynamic>{});
                        }

                        Navigator.pop(ctx);
                        AppSweetAlert.success(
                          context,
                          _isSchool
                              ? 'Kegiatan institusi berhasil ditambahkan ke kalender agenda!'
                              : 'Agenda kegiatan berhasil dijadwalkan!',
                          title: 'Jadwal Tersimpan',
                        );
                      },
                      label: Text(
                        _isSchool ? 'Simpan Kegiatan' : 'Simpan Agenda',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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

    final isDesktop = MediaQuery.of(context).size.width > 700;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 850),
            child: StatefulBuilder(
              builder: (ctx, setModalState) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
