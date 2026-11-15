import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../models/opportunity_model.dart';
import '../services/api_service.dart';
import '../services/opportunity_service.dart';
import '../services/user_store.dart';
import '../widgets/app_breadcrumbs.dart';
import '../widgets/app_pagination_bar.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../widgets/program_magang_card.dart';
import 'program_magang_detail_screen.dart';

enum SchoolMagangTab {
  myApplications,
  partnerVacancies,
  allVacancies,
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
  List<OpportunityModel> _schoolPartnerItems = [];
  List<OpportunityModel> _schoolAllItems = [];
  List<Map<String, dynamic>> _partnerCorporates = [];
  int _currentPage = 1;
  static const int _pageSize = 6;

  UserModel? get _currentUser => widget.user ?? currentUserNotifier.value;

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
    final isExplicitMagang = opp.isMagang;
    final isCorporatePoster = opp.poster?.selectedSubRole?.toLowerCase() == 'corporate' ||
        opp.poster?.role.toLowerCase() == 'corporate' ||
        opp.poster?.verificationType?.toLowerCase() == 'corporate';

    return isExplicitMagang || isCorporatePoster;
  }

  bool _isPartnerCorporateOpportunity(
    OpportunityModel opp,
    List<Map<String, dynamic>> partners,
  ) {
    if (partners.isEmpty) return false;
    final posterId = (opp.postedBy ?? opp.poster?.id ?? '').trim();
    final posterUsername = (opp.poster?.username ?? '').trim().toLowerCase();
    final posterName = (opp.poster?.name ?? '').trim().toLowerCase();

    for (final partner in partners) {
      final status = (partner['status'] ?? '').toString().toLowerCase();
      if (status == 'rejected' || status == 'inactive' || status == 'closed') {
        continue;
      }
      final meta = partner['metadata'] is Map
          ? Map<String, dynamic>.from(partner['metadata'] as Map)
          : <String, dynamic>{};
      final corpUserId = (meta['corporate_user_id'] ?? '').toString().trim();
      final corpUsername =
          (meta['corporate_username'] ?? '').toString().trim().toLowerCase();
      final partnerTitle = (partner['title'] ?? '').toString().trim().toLowerCase();

      if (corpUserId.isNotEmpty && posterId.isNotEmpty && corpUserId == posterId) {
        return true;
      }
      if (corpUsername.isNotEmpty &&
          posterUsername.isNotEmpty &&
          corpUsername == posterUsername) {
        return true;
      }
      if (partnerTitle.isNotEmpty &&
          posterName.isNotEmpty &&
          (posterName == partnerTitle ||
              posterName.contains(partnerTitle) ||
              partnerTitle.contains(posterName))) {
        return true;
      }
    }
    return false;
  }

  int _compareByCreatedDesc(OpportunityModel a, OpportunityModel b) {
    final aDate = a.createdAt != null ? DateTime.tryParse(a.createdAt!) : null;
    final bDate = b.createdAt != null ? DateTime.tryParse(b.createdAt!) : null;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  }

  Future<void> _fetchRealtimeData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        OpportunityService.getMyOpportunities(forceRefresh: forceRefresh)
            .catchError((e) {
          debugPrint('Error fetching my opportunities: $e');
          return <OpportunityModel>[];
        }),
        OpportunityService.getOpportunities(limit: 100, forceRefresh: forceRefresh)
            .catchError((e) {
          debugPrint('Error fetching all opportunities: $e');
          return <OpportunityModel>[];
        }),
        ApiService.get(
          'institution/resources',
          queryParams: {'type': 'partners'},
        ).catchError((_) => <String, dynamic>{}),
      ]);

      final myOpportunities = List<OpportunityModel>.from(results[0] as List);
      final allOpportunities = List<OpportunityModel>.from(results[1] as List);
      final partnersRes = results[2] as Map<String, dynamic>;
      final loadedPartners = partnersRes['status'] == true &&
              partnersRes['data'] is List
          ? (partnersRes['data'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      final currentUserId = _currentUser?.id ?? '';

      // 1. Lamaran Magang Saya (strictly internships applied by this institution from DB)
      final Map<String, OpportunityModel> myMap = {};
      for (final opp in myOpportunities) {
        final key = opp.id ?? opp.title;
        if (_isMagangOpportunity(opp) && opp.postedBy != currentUserId) {
          myMap[key] = opp;
        }
      }
      for (final opp in allOpportunities) {
        final key = opp.id ?? opp.title;
        if (opp.hasApplied &&
            _isMagangOpportunity(opp) &&
            opp.postedBy != currentUserId) {
          myMap.putIfAbsent(key, () => opp);
        }
      }
      final myItems = myMap.values.toList()..sort(_compareByCreatedDesc);

      // 2. Semua Lowongan Magang Corporate (strictly from DB)
      final allItems = allOpportunities
          .where((opp) => _isMagangOpportunity(opp) && opp.postedBy != currentUserId)
          .toList()
        ..sort(_compareByCreatedDesc);

      // 3. Magang Corporate Mitra (lowongan magang milik Corporate mitra terdaftar di DB)
      final partnerItems = allItems
          .where((opp) => _isPartnerCorporateOpportunity(opp, loadedPartners))
          .toList()
        ..sort(_compareByCreatedDesc);

      if (mounted) {
        setState(() {
          _partnerCorporates = loadedPartners;
          _schoolMyItems = myItems;
          _schoolPartnerItems = partnerItems;
          _schoolAllItems = allItems;
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

  List<OpportunityModel> get _activeItems {
    switch (_schoolTab) {
      case SchoolMagangTab.myApplications:
        return _schoolMyItems;
      case SchoolMagangTab.partnerVacancies:
        return _schoolPartnerItems;
      case SchoolMagangTab.allVacancies:
        return _schoolAllItems;
    }
  }

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

  Future<void> _openOpportunityDetail(OpportunityModel opp) async {
    final isApplied = opp.hasApplied ||
        _schoolTab == SchoolMagangTab.myApplications ||
        _schoolMyItems.any((item) => item.id != null && item.id == opp.id);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProgramMagangDetailScreen(
          opportunity: opp,
          user: _currentUser,
          onUserUpdated: widget.onUserUpdated,
          isAppliedPartnership: isApplied,
        ),
      ),
    );
    if (mounted) {
      _fetchRealtimeData(forceRefresh: true);
    }
  }

  void _onPageSelected(int page) {
    setState(() => _currentPage = page);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFF6366F1); // Indigo / School color
    final effectiveUser = _currentUser ?? UserModel.guest();

    final filtered = _filteredItems;
    final validPage = AppPaginationBar.safePage(
      _currentPage,
      filtered.length,
      pageSize: _pageSize,
    );
    final pagedItems = AppPaginationBar.slicePage(
      filtered,
      validPage,
      pageSize: _pageSize,
    );

    final content = Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _fetchRealtimeData(forceRefresh: true),
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 24.0 : 16.0,
              20.0,
              isDesktop ? 24.0 : 16.0,
              isDesktop ? 40.0 : 156.0,
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
                  AppPaginationBar(
                    totalItems: filtered.length,
                    currentPage: validPage,
                    pageSize: _pageSize,
                    accentColor: accentColor,
                    itemLabel: 'program',
                    onPageChanged: _onPageSelected,
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
                  _schoolTab = _schoolTab == SchoolMagangTab.allVacancies
                      ? SchoolMagangTab.myApplications
                      : SchoolMagangTab.allVacancies;
                  _currentPage = 1;
                });
              },
              backgroundColor: accentColor,
              icon: Icon(
                _schoolTab == SchoolMagangTab.allVacancies
                    ? Icons.assignment_turned_in_rounded
                    : Icons.search_rounded,
                color: Colors.white,
              ),
              label: Text(
                _schoolTab == SchoolMagangTab.allVacancies
                    ? 'Lamaran Magang Saya'
                    : 'Semua Lowongan Magang',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );

    return DesktopSidebarLayout(
      user: effectiveUser,
      activeRoute: 'program_magang',
      onUserUpdated: widget.onUserUpdated,
      child: content,
    );
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
                _schoolTab = _schoolTab == SchoolMagangTab.allVacancies
                    ? SchoolMagangTab.myApplications
                    : SchoolMagangTab.allVacancies;
                _currentPage = 1;
              });
            },
            icon: Icon(
              _schoolTab == SchoolMagangTab.allVacancies
                  ? Icons.assignment_turned_in_rounded
                  : Icons.search_rounded,
              size: 18,
              color: Colors.white,
            ),
            label: Text(
              _schoolTab == SchoolMagangTab.allVacancies
                  ? 'Lamaran Magang Saya'
                  : 'Semua Lowongan Magang',
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE0E7FF),
        ),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _buildTabChip(
            label: 'Lamaran Magang Saya',
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
          _buildTabChip(
            label: 'Magang Corporate Mitra',
            count: _schoolPartnerItems.length,
            isSelected: _schoolTab == SchoolMagangTab.partnerVacancies,
            isDark: isDark,
            accentColor: accentColor,
            onTap: () {
              if (_schoolTab != SchoolMagangTab.partnerVacancies) {
                setState(() {
                  _schoolTab = SchoolMagangTab.partnerVacancies;
                  _currentPage = 1;
                });
              }
            },
          ),
          _buildTabChip(
            label: 'Semua Lowongan Magang',
            count: _schoolAllItems.length,
            isSelected: _schoolTab == SchoolMagangTab.allVacancies,
            isDark: isDark,
            accentColor: accentColor,
            onTap: () {
              if (_schoolTab != SchoolMagangTab.allVacancies) {
                setState(() {
                  _schoolTab = SchoolMagangTab.allVacancies;
                  _currentPage = 1;
                });
              }
            },
          ),
        ],
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
    final isExplore = _schoolTab == SchoolMagangTab.allVacancies ||
        _schoolTab == SchoolMagangTab.partnerVacancies;

    String getOpportunityButtonLabel(OpportunityModel opp) {
      if (isExplore) {
        return opp.isMagang ? 'Detail & Lamar Magang →' : 'Detail & Lamar Lowongan →';
      } else {
        return opp.isMagang ? 'Lihat Detail Program →' : 'Lihat Detail Lowongan →';
      }
    }

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
                          buttonLabel: getOpportunityButtonLabel(first),
                          onTap: () => _openOpportunityDetail(first),
                          onDetailPressed: () => _openOpportunityDetail(first),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: second != null
                            ? ProgramMagangCard.fromOpportunity(
                                second,
                                buttonLabel: getOpportunityButtonLabel(second),
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
                buttonLabel: getOpportunityButtonLabel(opp),
                onTap: () => _openOpportunityDetail(opp),
                onDetailPressed: () => _openOpportunityDetail(opp),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ── Pagination uses shared AppPaginationBar widget ──────────────────────

  // ── Empty & Error States ───────────────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) {
    final String title;
    final String subtitle;
    switch (_schoolTab) {
      case SchoolMagangTab.myApplications:
        title = 'Belum Ada Lamaran Magang';
        subtitle =
            'Institusi Anda belum mengajukan lamaran magang ke Corporate mana pun. Buka tab Magang Corporate Mitra atau Semua Lowongan Magang untuk mendaftarkan siswa.';
        break;
      case SchoolMagangTab.partnerVacancies:
        title = _partnerCorporates.isEmpty
            ? 'Belum Ada Corporate Mitra Terdaftar'
            : 'Belum Ada Lowongan dari Corporate Mitra';
        subtitle = _partnerCorporates.isEmpty
            ? 'Tambahkan mitra Corporate terlebih dahulu di menu Mitra Industri & Sanggar, atau lihat Semua Lowongan Magang yang tersedia.'
            : 'Mitra Corporate Anda saat ini belum membuka lowongan magang baru yang sesuai filter.';
        break;
      case SchoolMagangTab.allVacancies:
        title = 'Belum Ada Lowongan Magang Tersedia';
        subtitle =
            'Saat ini belum ada lowongan magang corporate di database yang sesuai kriteria pencarian.';
        break;
    }

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
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            ),
          ),
          if (_schoolTab != SchoolMagangTab.allVacancies) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _schoolTab = SchoolMagangTab.allVacancies;
                  _currentPage = 1;
                });
              },
              icon: const Icon(Icons.search_rounded, size: 18, color: Colors.white),
              label: const Text(
                'Lihat Semua Lowongan Magang',
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
