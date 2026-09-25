import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/debouncer.dart';
import '../app/theme.dart';
import '../app/subrole_theme_engine.dart';
import '../models/user_model.dart';
import '../services/job_contract_service.dart';
import '../services/opportunity_service.dart';
import '../models/job_contract.dart';
import '../models/opportunity_model.dart';
import 'direct_message_screen.dart';
import 'buat_kebutuhan_screen.dart';
import 'detail_kebutuhan_screen.dart';
import '../widgets/app_breadcrumbs.dart';
import '../widgets/skeleton/skeleton_list.dart';

enum ProjectItemType {
  opportunity,
  contract,
}

class UnifiedProjectItem {
  final String id;
  final String title;
  final String? description;
  final String category;
  final String statusCategory; // 'Mencari Kreator', 'Berjalan', 'Menunggu', 'Selesai'
  final String statusLabel;
  final Color statusColor;
  final String priceOrBudget;
  final String? deadline;
  final String? partnerOrApplicants;
  final int applicationsCount;
  final double progress;
  final ProjectItemType type;
  final JobContract? contract;
  final OpportunityModel? opportunity;
  final DateTime? createdAt;

  UnifiedProjectItem({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.statusCategory,
    required this.statusLabel,
    required this.statusColor,
    required this.priceOrBudget,
    this.deadline,
    this.partnerOrApplicants,
    this.applicationsCount = 0,
    this.progress = 0.0,
    required this.type,
    this.contract,
    this.opportunity,
    this.createdAt,
  });

  factory UnifiedProjectItem.fromOpportunity(OpportunityModel opp) {
    final isOpen = opp.status.toLowerCase() == 'open';
    final isClosed = opp.status.toLowerCase() == 'closed';

    final statusCategory = isOpen
        ? 'Mencari Kreator'
        : (isClosed ? 'Selesai' : 'Menunggu');

    final statusLabel = isOpen
        ? 'Mencari Kreator'
        : (isClosed ? 'Kebutuhan Selesai' : opp.status.toUpperCase());

    final statusColor = isOpen
        ? const Color(0xFF8B5CF6)
        : (isClosed ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

    final count = opp.applicationsCount;
    final partnerText = count > 0
        ? '$count Pelamar Terdaftar'
        : 'Menunggu Pelamar';

    DateTime? created;
    if (opp.createdAt != null) {
      created = DateTime.tryParse(opp.createdAt!);
    }

    String categoryFormatted = opp.subRoleSlug.replaceAll('_', ' ');
    if (categoryFormatted.isNotEmpty) {
      categoryFormatted = categoryFormatted[0].toUpperCase() +
          categoryFormatted.substring(1);
    } else {
      categoryFormatted = 'Kreatif';
    }

    return UnifiedProjectItem(
      id: opp.id ?? '',
      title: opp.title,
      description: opp.description,
      category: categoryFormatted,
      statusCategory: statusCategory,
      statusLabel: statusLabel,
      statusColor: statusColor,
      priceOrBudget: opp.budgetRange != null && opp.budgetRange!.isNotEmpty
          ? opp.budgetRange!
          : 'Budget Fleksibel',
      deadline: opp.deadline,
      partnerOrApplicants: partnerText,
      applicationsCount: count,
      progress: isClosed ? 1.0 : (count > 0 ? 0.35 : 0.1),
      type: ProjectItemType.opportunity,
      opportunity: opp,
      createdAt: created,
    );
  }

  factory UnifiedProjectItem.fromContract(JobContract c) {
    final cs = c.contractStatus.toLowerCase();
    String statusCategory;
    Color statusColor;
    String statusLabel;

    if (cs == 'active' || cs == 'approved' || cs == 'escrow_paid') {
      statusCategory = 'Berjalan';
      statusColor = const Color(0xFF10B981);
      statusLabel = 'Kontrak Aktif';
    } else if (cs == 'completed') {
      statusCategory = 'Selesai';
      statusColor = const Color(0xFF3B82F6);
      statusLabel = 'Pekerjaan Selesai';
    } else if (cs == 'cancelled' || cs == 'disputed' || cs == 'cancel_requested') {
      statusCategory = 'Menunggu';
      statusColor = const Color(0xFFEF4444);
      statusLabel = cs == 'disputed' ? 'Sengketa' : 'Dibatalkan';
    } else {
      statusCategory = 'Menunggu';
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Menunggu Persetujuan';
    }

    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    int progressPct = 0;
    switch (c.workStatus.toLowerCase()) {
      case 'completed':
      case 'done':
        progressPct = 100;
        break;
      case 'submitted':
        progressPct = 85;
        break;
      case 'review':
        progressPct = 75;
        break;
      case 'revision':
        progressPct = 50;
        break;
      case 'in_progress':
        progressPct = 40;
        break;
      case 'scheduled':
        progressPct = 15;
        break;
      default:
        progressPct = 5;
    }

    String formattedDeadline = '-';
    if (c.deadline != null) {
      formattedDeadline = DateFormat('dd MMM yyyy').format(c.deadline!);
    } else if (c.scheduledEndDate != null) {
      formattedDeadline = DateFormat('dd MMM yyyy').format(c.scheduledEndDate!);
    }

    return UnifiedProjectItem(
      id: c.id,
      title: c.title,
      description: c.description,
      category: c.creatorServiceId != null ? 'Layanan Kreator' : 'Kontrak Proyek',
      statusCategory: statusCategory,
      statusLabel: statusLabel,
      statusColor: statusColor,
      priceOrBudget: currencyFormat.format(c.agreedPrice),
      deadline: formattedDeadline,
      partnerOrApplicants: 'Kreator: ${c.creatorName}',
      applicationsCount: 0,
      progress: progressPct / 100.0,
      type: ProjectItemType.contract,
      contract: c,
      createdAt: c.createdAt,
    );
  }
}

class ProyekSayaScreen extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel>? onUserUpdated;

  const ProyekSayaScreen({super.key, this.user, this.onUserUpdated});

  @override
  State<ProyekSayaScreen> createState() => _ProyekSayaScreenState();
}

class _ProyekSayaScreenState extends State<ProyekSayaScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedStatus = 'Semua';
  String _searchQuery = '';
  final _debouncer = Debouncer(milliseconds: 300);
  final TextEditingController _searchController = TextEditingController();

  List<UnifiedProjectItem> _allItems = [];

  @override
  void dispose() {
    _debouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchRealtimeProjects();
  }

  Future<void> _fetchRealtimeProjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        JobContractService.getUserContracts().catchError((e) {
          debugPrint('Error fetching contracts: $e');
          return <JobContract>[];
        }),
        OpportunityService.getMyOpportunities().catchError((e) {
          debugPrint('Error fetching my opportunities: $e');
          return <OpportunityModel>[];
        }),
      ]);

      final contracts = results[0] as List<JobContract>;
      final opportunities = results[1] as List<OpportunityModel>;

      final unified = <UnifiedProjectItem>[];

      for (final opp in opportunities) {
        unified.add(UnifiedProjectItem.fromOpportunity(opp));
      }

      for (final contract in contracts) {
        unified.add(UnifiedProjectItem.fromContract(contract));
      }

      // Sort by creation date descending
      unified.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      if (mounted) {
        setState(() {
          _allItems = unified;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching projects: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat proyek. Periksa koneksi internet Anda.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openBuatKebutuhan() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BuatKebutuhanScreen(user: widget.user)),
    );

    if (result == true) {
      _fetchRealtimeProjects();
    }
  }

  void _openOpportunityDetail(OpportunityModel opp) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailKebutuhanScreen(
          opportunity: opp,
          user: widget.user,
        ),
      ),
    ).then((_) => _fetchRealtimeProjects());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final role = widget.user?.role ?? 'user';
    final subRole = widget.user?.subRole ?? 'general';
    final accentColor = SubRoleThemeEngine.getAccentColor(role, subRole);

    final isDesktop = MediaQuery.of(context).size.width > 900;
    final screenWidth = MediaQuery.of(context).size.width;

    // Filter by status category
    final filtered = _allItems.where((item) {
      if (_selectedStatus != 'Semua' && item.statusCategory != _selectedStatus) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = item.title.toLowerCase().contains(q);
        final matchCat = item.category.toLowerCase().contains(q);
        final matchPartner = (item.partnerOrApplicants ?? '').toLowerCase().contains(q);
        final matchDesc = (item.description ?? '').toLowerCase().contains(q);
        return matchTitle || matchCat || matchPartner || matchDesc;
      }
      return true;
    }).toList();

    // Counts
    final totalCount = _allItems.length;
    final mencariKreatorCount = _allItems.where((i) => i.statusCategory == 'Mencari Kreator').length;
    final berjalanCount = _allItems.where((i) => i.statusCategory == 'Berjalan').length;
    final menungguCount = _allItems.where((i) => i.statusCategory == 'Menunggu').length;
    final selesaiCount = _allItems.where((i) => i.statusCategory == 'Selesai').length;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF7F8FC),
      body: RefreshIndicator(
        onRefresh: _fetchRealtimeProjects,
        color: AppTheme.primaryPurple,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1260),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 32 : 16,
                  isDesktop ? 32 : 16,
                  isDesktop ? 32 : 16,
                  isDesktop ? 60 : 100,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Breadcrumbs ──
                    const AppBreadcrumbs(
                      items: [
                        BreadcrumbItem(
                          label: 'Proyek Saya',
                          icon: Icons.folder_rounded,
                        ),
                      ],
                    ),

                    // ── Header Desktop & Mobile ──
                    _buildHeader(isDark, isDesktop, accentColor),
                    const SizedBox(height: 24),

                    // ── KPI Summary Cards ──
                    _buildSummaryMetrics(
                      total: totalCount,
                      mencariKreator: mencariKreatorCount,
                      berjalan: berjalanCount,
                      menunggu: menungguCount,
                      selesai: selesaiCount,
                      isDark: isDark,
                      isDesktop: isDesktop,
                    ),
                    const SizedBox(height: 24),

                    // ── Search & Filter Controls ──
                    _buildSearchAndFilters(
                      isDark: isDark,
                      isDesktop: isDesktop,
                      accentColor: accentColor,
                      total: totalCount,
                      mencariKreator: mencariKreatorCount,
                      berjalan: berjalanCount,
                      menunggu: menungguCount,
                      selesai: selesaiCount,
                    ),
                    const SizedBox(height: 20),

                    // ── Projects Content ──
                    if (_isLoading)
                      const SkeletonList()
                    else if (_errorMessage != null)
                      _buildErrorState(accentColor, isDark)
                    else if (filtered.isEmpty)
                      _buildEmptyState(isDark)
                    else
                      _buildProjectsGrid(filtered, isDark, isDesktop, screenWidth, accentColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: (!isDesktop)
          ? FloatingActionButton.extended(
              heroTag: 'proyek_saya_fab_mobile',
              onPressed: _openBuatKebutuhan,
              backgroundColor: AppTheme.primaryPurple,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Buat Kebutuhan',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark, bool isDesktop, Color accentColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (Navigator.canPop(context))
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardBg : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Proyek Saya',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pantau kebutuhan terbuka, proposal kreator, dan progres kontrak kerja Anda.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _fetchRealtimeProjects,
          tooltip: 'Segarkan data realtime',
          style: IconButton.styleFrom(
            backgroundColor: isDark ? AppTheme.cardBg : Colors.white,
            side: BorderSide(
              color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (isDesktop) ...[
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _openBuatKebutuhan,
            icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            label: const Text(
              'Buat Proyek Baru',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── KPI Summary Metrics ────────────────────────────────────────────────────
  Widget _buildSummaryMetrics({
    required int total,
    required int mencariKreator,
    required int berjalan,
    required int menunggu,
    required int selesai,
    required bool isDark,
    required bool isDesktop,
  }) {
    final List<Map<String, dynamic>> metricData = [
      {
        'status': 'Semua',
        'label': 'Total Proyek',
        'value': total.toString(),
        'icon': Icons.folder_special_rounded,
        'color': const Color(0xFF6366F1),
      },
      {
        'status': 'Mencari Kreator',
        'label': 'Mencari Kreator',
        'value': mencariKreator.toString(),
        'icon': Icons.campaign_rounded,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'status': 'Berjalan',
        'label': 'Kontrak Berjalan',
        'value': berjalan.toString(),
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'status': 'Menunggu',
        'label': 'Menunggu Konfirmasi',
        'value': menunggu.toString(),
        'icon': Icons.hourglass_top_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'status': 'Selesai',
        'label': 'Selesai',
        'value': selesai.toString(),
        'icon': Icons.check_circle_rounded,
        'color': const Color(0xFF3B82F6),
      },
    ];

    if (isDesktop) {
      return Row(
        children: metricData.map((m) {
          final isSelected = _selectedStatus == m['status'];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _buildMetricCard(m, isSelected, isDark),
            ),
          );
        }).toList(),
      );
    }

    // Mobile: 2 rows or scrollable
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: metricData.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 10),
        itemBuilder: (context, idx) {
          final m = metricData[idx];
          final isSelected = _selectedStatus == m['status'];
          return SizedBox(
            width: 150,
            child: _buildMetricCard(m, isSelected, isDark),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(Map<String, dynamic> m, bool isSelected, bool isDark) {
    final color = m['color'] as Color;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() => _selectedStatus = m['status'] as String);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardBg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(m['icon'] as IconData, size: 18, color: color),
                ),
                Text(
                  m['value'] as String,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              m['label'] as String,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? color
                    : (isDark ? AppTheme.textMuted : Colors.grey.shade600),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Search & Filter Bar ────────────────────────────────────────────────────
  Widget _buildSearchAndFilters({
    required bool isDark,
    required bool isDesktop,
    required Color accentColor,
    required int total,
    required int mencariKreator,
    required int berjalan,
    required int menunggu,
    required int selesai,
  }) {
    final statusOptions = [
      {'key': 'Semua', 'label': 'Semua', 'count': total},
      {'key': 'Mencari Kreator', 'label': 'Mencari Kreator', 'count': mencariKreator},
      {'key': 'Berjalan', 'label': 'Berjalan', 'count': berjalan},
      {'key': 'Menunggu', 'label': 'Menunggu', 'count': menunggu},
      {'key': 'Selesai', 'label': 'Selesai', 'count': selesai},
    ];

    final searchField = TextField(
      controller: _searchController,
      onChanged: (v) {
        _debouncer.run(() {
          setState(() => _searchQuery = v);
        });
      },
      decoration: InputDecoration(
        hintText: 'Cari proyek, kebutuhan, atau nama kreator...',
        hintStyle: TextStyle(
          fontSize: 13,
          color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
        ),
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: isDark ? AppTheme.cardBg : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 1.6),
        ),
      ),
    );

    final filterChips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statusOptions.map((opt) {
          final key = opt['key'] as String;
          final label = opt['label'] as String;
          final count = opt['count'] as int;
          final isSel = _selectedStatus == key;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSel
                          ? Colors.white.withValues(alpha: 0.25)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
              selected: isSel,
              selectedColor: AppTheme.primaryPurple,
              backgroundColor: isDark ? AppTheme.cardBg : Colors.white,
              side: BorderSide(
                color: isSel
                    ? AppTheme.primaryPurple
                    : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
              ),
              labelStyle: TextStyle(
                color: isSel
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey.shade800),
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
              onSelected: (val) {
                if (val) setState(() => _selectedStatus = key);
              },
            ),
          );
        }).toList(),
      ),
    );

    if (isDesktop) {
      return Row(
        children: [
          Expanded(flex: 3, child: searchField),
          const SizedBox(width: 16),
          Expanded(flex: 4, child: filterChips),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        searchField,
        const SizedBox(height: 12),
        filterChips,
      ],
    );
  }

  // ── Projects Grid Layout ───────────────────────────────────────────────────
  Widget _buildProjectsGrid(
    List<UnifiedProjectItem> items,
    bool isDark,
    bool isDesktop,
    double screenWidth,
    Color accentColor,
  ) {
    if (isDesktop) {
      // 2-column responsive layout for clean desktop readability
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: items.map((item) {
          final cardWidth = (screenWidth > 1260 ? 1260 : screenWidth) / 2 - 40;
          return SizedBox(
            width: cardWidth > 450 ? cardWidth : double.infinity,
            child: _buildUnifiedCard(item, isDark, accentColor),
          );
        }).toList(),
      );
    }

    // Mobile: vertical column
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _buildUnifiedCard(item, isDark, accentColor),
        );
      }).toList(),
    );
  }

  // ── Unified Project Card ───────────────────────────────────────────────────
  Widget _buildUnifiedCard(
    UnifiedProjectItem item,
    bool isDark,
    Color accentColor,
  ) {
    final isOpportunity = item.type == ProjectItemType.opportunity;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          // ── Top Type Pill & Status Badge ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOpportunity
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                      : const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOpportunity
                          ? Icons.campaign_rounded
                          : Icons.handshake_rounded,
                      size: 14,
                      color: isOpportunity
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOpportunity ? 'Kebutuhan Proyek' : 'Kontrak Kerja',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isOpportunity
                            ? const Color(0xFF8B5CF6)
                            : const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: item.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: item.statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: item.statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Title ──
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.description!,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),

          // ── Metadata Pills (Category, Budget, Deadline) ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetaChip(
                Icons.category_rounded,
                item.category,
                isDark,
              ),
              _buildMetaChip(
                Icons.payments_rounded,
                item.priceOrBudget,
                isDark,
                highlight: true,
              ),
              if (item.deadline != null && item.deadline != '-')
                _buildMetaChip(
                  Icons.event_rounded,
                  item.deadline!,
                  isDark,
                ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Partner / Pelamar Info & Progress ──
          if (isOpportunity) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : const Color(0xFFF9FAFD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    item.applicationsCount > 0
                        ? Icons.people_alt_rounded
                        : Icons.person_search_rounded,
                    size: 16,
                    color: item.applicationsCount > 0
                        ? AppTheme.primaryPurple
                        : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.partnerOrApplicants ?? 'Menunggu Pelamar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: item.applicationsCount > 0
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark ? AppTheme.textMuted : Colors.grey.shade600),
                      ),
                    ),
                  ),
                  if (item.applicationsCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Ada Proposal Masuk',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ] else ...[
            // Contract Progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 15,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.partnerOrApplicants ?? '-',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${(item.progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: item.statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: item.progress,
                minHeight: 6,
                backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(item.statusColor),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // ── Action Buttons ──
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isOpportunity) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    if (item.opportunity != null) {
                      _openOpportunityDetail(item.opportunity!);
                    }
                  },
                  icon: const Icon(Icons.how_to_reg_rounded, size: 15),
                  label: Text(
                    item.applicationsCount > 0
                        ? 'Kelola Pelamar (${item.applicationsCount})'
                        : 'Lihat Detail Kebutuhan',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryPurple,
                    side: BorderSide(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  tooltip: 'Chat Partner',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DirectMessageScreen(),
                      ),
                    );
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    _showContractDetailDialog(item);
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: const Text(
                    'Detail Kontrak',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(
    IconData icon,
    String text,
    bool isDark, {
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.primaryPurple.withValues(alpha: 0.08)
            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? AppTheme.primaryPurple.withValues(alpha: 0.2)
              : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: highlight
                ? AppTheme.primaryPurple
                : (isDark ? AppTheme.textMuted : Colors.grey.shade600),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              color: highlight
                  ? AppTheme.primaryPurple
                  : (isDark ? Colors.white70 : Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  void _showContractDetailDialog(UnifiedProjectItem item) {
    final c = item.contract;
    if (c == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.handshake_rounded, color: AppTheme.primaryPurple),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Detail Kontrak Proyek',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text('Partner: ${c.creatorName}'),
            Text('Nilai Kontrak: ${item.priceOrBudget}'),
            Text('Status Kontrak: ${item.statusLabel}'),
            Text('Status Kerja: ${c.workStatus}'),
            if (c.deadline != null)
              Text('Batas Waktu: ${DateFormat('dd MMM yyyy').format(c.deadline!)}'),
            if (c.description != null && c.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Catatan/Deskripsi:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(c.description!, style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DirectMessageScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Kirim Pesan'),
          ),
        ],
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                size: 48,
                color: AppTheme.primaryPurple,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _selectedStatus == 'Semua'
                  ? 'Belum Ada Proyek yang Dibuat'
                  : 'Tidak Ada Proyek pada Status "$_selectedStatus"',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Publikasikan kebutuhan proyek Anda sekarang untuk menerima proposal dari kreator terverifikasi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openBuatKebutuhan,
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
              label: const Text(
                'Buat Kebutuhan Baru',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error State ────────────────────────────────────────────────────────────
  Widget _buildErrorState(Color accentColor, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppTheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Terjadi kesalahan saat memuat data',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchRealtimeProjects,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
