import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../models/opportunity_model.dart';
import '../services/opportunity_service.dart';
import '../services/user_store.dart';
import '../widgets/app_breadcrumbs.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../widgets/program_magang_card.dart';
import 'program_magang_detail_screen.dart';

enum SchoolMagangTab {
  myApplications,
  exploreVacancies,
}

class ProgramMagangScreen extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const ProgramMagangScreen({
    super.key,
    this.user,
    this.onUserUpdated,
  });

  @override
  State<ProgramMagangScreen> createState() => _ProgramMagangScreenState();
}

class _ProgramMagangScreenState extends State<ProgramMagangScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedStatus = 'Semua';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  SchoolMagangTab _schoolTab = SchoolMagangTab.myApplications;
  List<OpportunityModel> _schoolMyItems = [];
  List<OpportunityModel> _schoolExploreItems = [];
  int _currentPage = 1;
  static const int _pageSize = 6;

  UserModel? get _currentUser => widget.user ?? currentUserNotifier.value;

  List<OpportunityModel> _getSampleMagangOpportunities() {
    return [
      OpportunityModel(
        id: 'sch_opp_magang_1',
        title: 'Program Magang MBKM 3D Modeler Batch I 2026',
        description:
            'Kerja sama penempatan 10 siswa vokasi magang pada produksi serial animasi nusantara berstandar industri internasional.',
        subRoleSlug: 'animator',
        type: 'project',
        status: 'open',
        eventStartDate: '2027-01-14',
        eventEndDate: '2027-02-14',
        budgetRange: 'Rp 3.500.000 / bulan',
        deadline: '14 Jan 2027',
        requirements: [
          OpportunityRequirementModel(
            subRoleSlug: 'animator',
            quantity: 10,
            notes:
                'Siswa SMK jurusan terkait, Menguasai dasar 3D Modeling, Memiliki portofolio karya',
          ),
        ],
      ),
      OpportunityModel(
        id: 'sch_opp_magang_2',
        title: 'Program Magang MBKM UI/UX & Digital Product Design',
        description:
            'Kerja sama penempatan 8 siswa vokasi magang pada perancangan produk digital kreatif aplikasi mobile.',
        subRoleSlug: 'desainer',
        type: 'project',
        status: 'open',
        eventStartDate: '2027-02-01',
        eventEndDate: '2027-03-01',
        budgetRange: 'Rp 3.000.000 / bulan',
        deadline: '01 Feb 2027',
        requirements: [
          OpportunityRequirementModel(
            subRoleSlug: 'desainer',
            quantity: 8,
            notes:
                'Siswa SMK / Mahasiswa DKV & RPL, Menguasai Figma & Design System, Memiliki portofolio studi kasus',
          ),
        ],
      ),
      OpportunityModel(
        id: 'sch_opp_magang_3',
        title: 'Program Magang Post-Production & Motion Graphics',
        description:
            'Kerja sama penempatan 6 siswa magang post-production video komersial dan animasi nusantara.',
        subRoleSlug: 'editor',
        type: 'project',
        status: 'open',
        eventStartDate: '2027-02-15',
        eventEndDate: '2027-03-15',
        budgetRange: 'Rp 3.200.000 / bulan',
        deadline: '15 Feb 2027',
        requirements: [
          OpportunityRequirementModel(
            subRoleSlug: 'editor',
            quantity: 6,
            notes:
                'Siswa SMK Multimedia / Animasi, Mahir Premiere Pro & After Effects, Menyertakan showreel karya video',
          ),
        ],
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _fetchRealtimeData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isMagangOpportunity(OpportunityModel opp) {
    final sub = opp.subRoleSlug.toLowerCase();
    final title = opp.title.toLowerCase();
    final desc = (opp.description ?? '').toLowerCase();

    final isExplicitMagang = sub.contains('magang') ||
        sub.contains('intern') ||
        title.contains('magang') ||
        title.contains('intern') ||
        title.contains('pkl') ||
        title.contains('mbkm') ||
        desc.contains('magang') ||
        desc.contains('intern') ||
        desc.contains('siswa vokasi') ||
        opp.requirements.any((r) =>
            r.subRoleSlug.toLowerCase().contains('magang') ||
            (r.notes != null &&
                (r.notes!.toLowerCase().contains('magang') ||
                    r.notes!.toLowerCase().contains('kuota') ||
                    r.notes!.toLowerCase().contains('siswa smk'))));

    final isCorporatePoster = opp.poster?.selectedSubRole?.toLowerCase() == 'corporate' ||
        opp.poster?.role.toLowerCase() == 'corporate' ||
        opp.poster?.verificationType?.toLowerCase() == 'corporate';

    return isExplicitMagang || isCorporatePoster;
  }

  Future<void> _fetchRealtimeData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        OpportunityService.getMyOpportunities(forceRefresh: forceRefresh).catchError((e) {
          debugPrint('Error fetching my opportunities: $e');
          return <OpportunityModel>[];
        }),
        OpportunityService.getOpportunities(limit: 50, forceRefresh: forceRefresh).catchError((e) {
          debugPrint('Error fetching explore opportunities: $e');
          return <OpportunityModel>[];
        }),
      ]);

      final myOpportunities = List<OpportunityModel>.from(results[0]);
      final exploreOpportunities = List<OpportunityModel>.from(results[1]);

      // 1. Data lamaran/kemitraan magang sekolah (exclude non-magang events/projects)
      final myItems = myOpportunities.where(_isMagangOpportunity).toList();
      if (myItems.isEmpty) {
        myItems.addAll(_getSampleMagangOpportunities());
      }
      myItems.sort((a, b) {
        final aDate = a.createdAt != null ? DateTime.tryParse(a.createdAt!) : null;
        final bDate = b.createdAt != null ? DateTime.tryParse(b.createdAt!) : null;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      // 2. Data cari lowongan magang corporate
      final filteredExplore = exploreOpportunities.where(_isMagangOpportunity).toList();

      final exploreItems = <OpportunityModel>[];
      for (final opp in filteredExplore) {
        exploreItems.add(opp);
      }
      if (exploreItems.isEmpty) {
        exploreItems.addAll(_getSampleMagangOpportunities());
      }
      exploreItems.sort((a, b) {
        final aDate = a.createdAt != null ? DateTime.tryParse(a.createdAt!) : null;
        final bDate = b.createdAt != null ? DateTime.tryParse(b.createdAt!) : null;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      if (mounted) {
        setState(() {
          _schoolMyItems = myItems;
          _schoolExploreItems = exploreItems;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading program magang: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data program magang. Silakan coba lagi.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<OpportunityModel> get _activeItems =>
      _schoolTab == SchoolMagangTab.myApplications ? _schoolMyItems : _schoolExploreItems;

  List<OpportunityModel> get _filteredItems {
    var items = List<OpportunityModel>.from(_activeItems);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((i) {
        final title = i.title.toLowerCase();
        final desc = (i.description ?? '').toLowerCase();
        final req = i.requirements.any((r) => (r.notes ?? '').toLowerCase().contains(q));
        return title.contains(q) || desc.contains(q) || req;
      }).toList();
    }

    if (_selectedStatus != 'Semua') {
      items = items.where((i) {
        final s = i.status.toLowerCase();
        if (_selectedStatus == 'Buka Pendaftaran') {
          return !i.isClosed && !i.isOngoing && (s == 'open' || s == 'published');
        } else if (_selectedStatus == 'Magang Berjalan') {
          return i.isOngoing || s == 'in_progress' || s == 'active';
        } else if (_selectedStatus == 'Menunggu') {
          return s == 'pending' || s == 'draft';
        } else if (_selectedStatus == 'Selesai') {
          return i.isClosed || s == 'closed' || s == 'completed';
        }
        return true;
      }).toList();
    }

    return items;
  }

  void _openOpportunityDetail(OpportunityModel opp) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProgramMagangDetailScreen(
          opportunity: opp,
          user: _currentUser,
          onUserUpdated: widget.onUserUpdated,
          isAppliedPartnership: _schoolTab == SchoolMagangTab.myApplications,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFF6366F1); // Indigo / School color
    final effectiveUser = _currentUser ?? UserModel.guest();

    final filtered = _filteredItems;
    final totalPages = (filtered.length / _pageSize).ceil();
    final effectiveTotalPages = totalPages > 0 ? totalPages : 1;
    final validPage = _currentPage.clamp(1, effectiveTotalPages);
    final startIndex = (validPage - 1) * _pageSize;
    final pagedItems = filtered.skip(startIndex).take(_pageSize).toList();

    final content = Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _fetchRealtimeData(forceRefresh: true),
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24.0 : 16.0,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Breadcrumbs
                const AppBreadcrumbs(
                  items: [
                    BreadcrumbItem(label: 'Beranda', icon: Icons.home_outlined),
                    BreadcrumbItem(label: 'Pengelolaan Sekolah', icon: Icons.school_outlined),
                    BreadcrumbItem(
                      label: 'Program & Magang',
                      icon: Icons.work_outline_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Header
                _buildHeader(isDark, isDesktop, accentColor),
                const SizedBox(height: 16),

                // 3. Tab Selector
                _buildSchoolTabSelector(isDark, accentColor),
                const SizedBox(height: 20),

                // 4. Metric Strip
                _buildMetricStrip(isDark, isDesktop, accentColor),
                const SizedBox(height: 24),

                // 5. Search & Filter Bar
                _buildSearchAndFilters(isDark, isDesktop, accentColor),
                const SizedBox(height: 20),

                // 6. Content Section
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_errorMessage != null)
                  _buildErrorState(isDark)
                else if (filtered.isEmpty)
                  _buildEmptyState(isDark)
                else ...[
                  _buildOpportunityGrid(pagedItems, isDesktop, isDark, accentColor),
                  const SizedBox(height: 24),
                  _buildPaginationBar(
                    totalItems: filtered.length,
                    currentPage: validPage,
                    totalPages: effectiveTotalPages,
                    startIndex: startIndex,
                    endIndex: (startIndex + pagedItems.length),
                    isDark: isDark,
                    accentColor: accentColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: (!isDesktop)
          ? FloatingActionButton.extended(
              heroTag: 'program_magang_fab_mobile',
              onPressed: () {
                setState(() {
                  _schoolTab = _schoolTab == SchoolMagangTab.myApplications
                      ? SchoolMagangTab.exploreVacancies
                      : SchoolMagangTab.myApplications;
                  _currentPage = 1;
                });
              },
              backgroundColor: accentColor,
              icon: Icon(
                _schoolTab == SchoolMagangTab.myApplications
                    ? Icons.search_rounded
                    : Icons.assignment_turned_in_rounded,
                color: Colors.white,
              ),
              label: Text(
                _schoolTab == SchoolMagangTab.myApplications
                    ? 'Cari Lowongan Magang'
                    : 'Lamaran Magang Saya',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );

    if (isDesktop) {
      return DesktopSidebarLayout(
        user: effectiveUser,
        activeRoute: 'program_magang',
        onUserUpdated: widget.onUserUpdated,
        child: content,
      );
    }

    return content;
  }

  // ── Header Widget ──────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark, bool isDesktop, Color accentColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Program & Magang',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pantau program kemitraan magang siswa dan jelajahi lowongan magang industri mitra.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh Data',
          onPressed: () => _fetchRealtimeData(forceRefresh: true),
          icon: const Icon(Icons.refresh_rounded, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (isDesktop) ...[
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _schoolTab = _schoolTab == SchoolMagangTab.myApplications
                    ? SchoolMagangTab.exploreVacancies
                    : SchoolMagangTab.myApplications;
                _currentPage = 1;
              });
            },
            icon: Icon(
              _schoolTab == SchoolMagangTab.myApplications
                  ? Icons.search_rounded
                  : Icons.assignment_turned_in_rounded,
              size: 18,
              color: Colors.white,
            ),
            label: Text(
              _schoolTab == SchoolMagangTab.myApplications
                  ? 'Cari Lowongan Magang'
                  : 'Lihat Lamaran Magang Saya',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ],
    );
  }

  // ── Tab Selector ───────────────────────────────────────────────────────────
  Widget _buildSchoolTabSelector(bool isDark, Color accentColor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE0E7FF),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTabChip(
              label: 'Lamaran & Kemitraan Magang',
              count: _schoolMyItems.length,
              isSelected: _schoolTab == SchoolMagangTab.myApplications,
              isDark: isDark,
              accentColor: accentColor,
              onTap: () {
                if (_schoolTab != SchoolMagangTab.myApplications) {
                  setState(() {
                    _schoolTab = SchoolMagangTab.myApplications;
                    _currentPage = 1;
                  });
                }
              },
            ),
            const SizedBox(width: 4),
            _buildTabChip(
              label: 'Cari Lowongan Magang',
              count: _schoolExploreItems.length,
              isSelected: _schoolTab == SchoolMagangTab.exploreVacancies,
              isDark: isDark,
              accentColor: accentColor,
              onTap: () {
                if (_schoolTab != SchoolMagangTab.exploreVacancies) {
                  setState(() {
                    _schoolTab = SchoolMagangTab.exploreVacancies;
                    _currentPage = 1;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip({
    required String label,
    required int count,
    required bool isSelected,
    required bool isDark,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF4338CA)),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.25)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE0E7FF)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF4338CA)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Metrics Strip ──────────────────────────────────────────────────────────
  Widget _buildMetricStrip(bool isDark, bool isDesktop, Color accentColor) {
    final items = _activeItems;
    final totalCount = items.length;
    final openCount = items.where((i) => !i.isClosed && !i.isOngoing).length;
    final runningCount = items.where((i) => i.isOngoing).length;
    final waitingCount = items.where((i) => i.status.toLowerCase() == 'pending').length;
    final completedCount = items.where((i) => i.isClosed).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final crossAxisCount = w > 1050 ? 5 : (w > 650 ? 3 : 2);
        final ratio = w > 1050 ? 1.85 : (w > 650 ? 2.1 : 1.75);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: ratio,
          children: [
            _buildMetricCard(
              title: 'Total Program',
              count: totalCount,
              icon: Icons.work_outline_rounded,
              color: accentColor,
              isDark: isDark,
              isSelected: _selectedStatus == 'Semua',
              onTap: () => setState(() {
                _selectedStatus = 'Semua';
                _currentPage = 1;
              }),
            ),
            _buildMetricCard(
              title: 'Buka Pendaftaran',
              count: openCount,
              icon: Icons.campaign_outlined,
              color: const Color(0xFF8B5CF6),
              isDark: isDark,
              isSelected: _selectedStatus == 'Buka Pendaftaran',
              onTap: () => setState(() {
                _selectedStatus = 'Buka Pendaftaran';
                _currentPage = 1;
              }),
            ),
            _buildMetricCard(
              title: 'Magang Berjalan',
              count: runningCount,
              icon: Icons.trending_up_rounded,
              color: const Color(0xFF10B981),
              isDark: isDark,
              isSelected: _selectedStatus == 'Magang Berjalan',
              onTap: () => setState(() {
                _selectedStatus = 'Magang Berjalan';
                _currentPage = 1;
              }),
            ),
            _buildMetricCard(
              title: 'Menunggu Konfirmasi',
              count: waitingCount,
              icon: Icons.hourglass_top_rounded,
              color: const Color(0xFFF59E0B),
              isDark: isDark,
              isSelected: _selectedStatus == 'Menunggu',
              onTap: () => setState(() {
                _selectedStatus = 'Menunggu';
                _currentPage = 1;
              }),
            ),
            _buildMetricCard(
              title: 'Selesai',
              count: completedCount,
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF3B82F6),
              isDark: isDark,
              isSelected: _selectedStatus == 'Selesai',
              onTap: () => setState(() {
                _selectedStatus = 'Selesai';
                _currentPage = 1;
              }),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required bool isDark,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search & Filter Bar ────────────────────────────────────────────────────
  Widget _buildSearchAndFilters(bool isDark, bool isDesktop, Color accentColor) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                      _currentPage = 1;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Cari program, lowongan magang, atau nama industri mitra...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: isDark ? Colors.white54 : Colors.grey.shade500,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _currentPage = 1;
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('Semua', isDark, accentColor),
              const SizedBox(width: 8),
              _buildFilterChip('Buka Pendaftaran', isDark, accentColor),
              const SizedBox(width: 8),
              _buildFilterChip('Magang Berjalan', isDark, accentColor),
              const SizedBox(width: 8),
              _buildFilterChip('Menunggu', isDark, accentColor),
              const SizedBox(width: 8),
              _buildFilterChip('Selesai', isDark, accentColor),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isDark, Color accentColor) {
    final isSelected = _selectedStatus == label;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          _selectedStatus = label;
          _currentPage = 1;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  // ── Grid of Cards ──────────────────────────────────────────────────────────
  Widget _buildOpportunityGrid(
    List<OpportunityModel> items,
    bool isDesktop,
    bool isDark,
    Color accentColor,
  ) {
    final isExplore = _schoolTab == SchoolMagangTab.exploreVacancies;
    final buttonText =
        isExplore ? 'Detail & Lamar Magang →' : 'Lihat Detail Program →';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTwoColumn = constraints.maxWidth > 820;
        if (isTwoColumn) {
          final rows = <Widget>[];
          for (int i = 0; i < items.length; i += 2) {
            final first = items[i];
            final second = i + 1 < items.length ? items[i + 1] : null;
            rows.add(
              Padding(
                padding: EdgeInsets.only(bottom: i + 2 < items.length ? 16 : 0),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ProgramMagangCard.fromOpportunity(
                          first,
                          buttonLabel: buttonText,
                          onTap: () => _openOpportunityDetail(first),
                          onDetailPressed: () => _openOpportunityDetail(first),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: second != null
                            ? ProgramMagangCard.fromOpportunity(
                                second,
                                buttonLabel: buttonText,
                                onTap: () => _openOpportunityDetail(second),
                                onDetailPressed: () => _openOpportunityDetail(second),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return Column(children: rows);
        }

        return Column(
          children: items.map((opp) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ProgramMagangCard.fromOpportunity(
                opp,
                buttonLabel: buttonText,
                onTap: () => _openOpportunityDetail(opp),
                onDetailPressed: () => _openOpportunityDetail(opp),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ── Pagination Bar ─────────────────────────────────────────────────────────
  Widget _buildPaginationBar({
    required int totalItems,
    required int currentPage,
    required int totalPages,
    required int startIndex,
    required int endIndex,
    required bool isDark,
    required Color accentColor,
  }) {
    final displayStart = totalItems == 0 ? 0 : startIndex + 1;
    final displayEnd = endIndex > totalItems ? totalItems : endIndex;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Text(
            'Menampilkan $displayStart – $displayEnd dari $totalItems program',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Halaman Sebelumnya',
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                onPressed: currentPage > 1
                    ? () {
                        setState(() => _currentPage = currentPage - 1);
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    : null,
              ),
              const SizedBox(width: 4),
              ..._buildPageNumbers(currentPage, totalPages, isDark, accentColor),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Halaman Berikutnya',
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                onPressed: currentPage < totalPages
                    ? () {
                        setState(() => _currentPage = currentPage + 1);
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers(
    int currentPage,
    int totalPages,
    bool isDark,
    Color accentColor,
  ) {
    final List<Widget> widgets = [];
    final List<int> pages = [];

    if (totalPages <= 5) {
      for (int i = 1; i <= totalPages; i++) {
        pages.add(i);
      }
    } else {
      pages.add(1);
      if (currentPage > 3) pages.add(-1);
      final start = (currentPage - 1).clamp(2, totalPages - 1);
      final end = (currentPage + 1).clamp(2, totalPages - 1);
      for (int i = start; i <= end; i++) {
        if (!pages.contains(i)) pages.add(i);
      }
      if (currentPage < totalPages - 2) pages.add(-2);
      if (!pages.contains(totalPages)) pages.add(totalPages);
    }

    for (final p in pages) {
      if (p < 0) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '...',
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ),
        );
      } else {
        widgets.add(_buildPageNumberButton(p, currentPage == p, isDark, accentColor));
      }
    }

    return widgets;
  }

  Widget _buildPageNumberButton(
    int page,
    bool isSelected,
    bool isDark,
    Color accentColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() => _currentPage = page);
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        },
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Text(
            '$page',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : const Color(0xFF0F172A)),
            ),
          ),
        ),
      ),
    );
  }

  // ── Empty & Error States ───────────────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) {
    final isExplore = _schoolTab == SchoolMagangTab.exploreVacancies;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.work_off_outlined,
              size: 40,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isExplore
                ? 'Belum Ada Lowongan Magang Tersedia'
                : 'Belum Ada Data Lamaran Magang',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isExplore
                ? 'Saat ini belum ada lowongan magang corporate yang sesuai kriteria pencarian.'
                : 'Belum ada data lamaran magang aktif ke mitra industri. Anda dapat mengeksplorasi dan melamar lowongan magang corporate yang sedang buka.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            ),
          ),
          if (!isExplore) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _schoolTab = SchoolMagangTab.exploreVacancies;
                  _currentPage = 1;
                });
              },
              icon: const Icon(Icons.search_rounded, size: 18, color: Colors.white),
              label: const Text(
                'Cari Lowongan Magang Industri',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'Terjadi kesalahan.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _fetchRealtimeData(forceRefresh: true),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}
