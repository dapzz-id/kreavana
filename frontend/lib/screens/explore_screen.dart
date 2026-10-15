import 'package:flutter/material.dart';
import '../widgets/creator_sidebar_menus.dart';
import '../app/theme.dart';
import '../app/subrole_theme_engine.dart';
import '../models/user_model.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../models/opportunity_model.dart';
import '../services/opportunity_service.dart';
import '../widgets/feature_card.dart';
import '../widgets/opportunity_detail_sheet.dart';
import 'peluang_lokasi_screen.dart';
import 'peluang_proyek_screen.dart';
import '../widgets/skeleton_box.dart';
import '../utils/debouncer.dart';
import '../widgets/recommended_creators_section.dart';

class ExploreScreen extends StatefulWidget {
  final UserModel user;

  const ExploreScreen({super.key, required this.user});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  String _selectedSubRole = 'all';
  final _debouncer = Debouncer(milliseconds: 500);
  bool _isLoading = false;
  List<OpportunityModel> _opportunities = [];
  final TextEditingController _searchController = TextEditingController();
  List<OpportunityModel> _filteredOpportunities = [];

  final List<Map<String, String>> _filterOptions = [
    {'slug': 'all', 'name': 'Semua'},
    {'slug': 'tukang_kendang', 'name': 'Tukang Kendang'},
    {'slug': 'institution', 'name': 'Institusi'},
    {'slug': 'government', 'name': 'Pemerintah'},
    {'slug': 'mc', 'name': 'MC'},
    {'slug': 'singer', 'name': 'Penyanyi'},
    {'slug': 'wedding_organizer', 'name': 'Wedding Organizer'},
    {'slug': 'event_organizer', 'name': 'Event Organizer'},
    {'slug': 'community', 'name': 'Komunitas'},
    {'slug': 'makeup_artist', 'name': 'Makeup Artist'},
    {'slug': 'photographer', 'name': 'Fotografer'},
    {'slug': 'editor', 'name': 'Editor'},
    {'slug': 'videographer', 'name': 'Videografer'},
    {'slug': 'content_creator', 'name': 'Content Creator'},
    {'slug': 'animator', 'name': 'Animator'},
    {'slug': 'designer', 'name': 'Desainer'},
    {'slug': 'musician', 'name': 'Musisi'},
    {'slug': 'talent', 'name': 'Talent'},
    {'slug': 'drone_pilot', 'name': 'Drone Pilot'},
  ];

  bool get _isCreator => CreatorSidebarMenus.isCreatorUser(widget.user);

  int get _tabCount => _isCreator ? 4 : 3;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _loadOpportunities();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _loadOpportunities() async {
    setState(() => _isLoading = true);
    try {
      final list = await OpportunityService.getOpportunities(
        subRole: _selectedSubRole,
        limit: 30,
      );
      if (mounted) {
        setState(() {
          _opportunities = list;
          _filteredOpportunities = list;
          _isLoading = false;
        });
        _onSearchChanged();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged() {
    _debouncer.run(() {
      final query = _searchController.text.toLowerCase().trim();
      setState(() {
        if (query.isEmpty) {
          _filteredOpportunities = _opportunities;
        } else {
          _filteredOpportunities = _opportunities
              .where(
                (op) =>
                    op.title.toLowerCase().contains(query) ||
                    (op.description?.toLowerCase().contains(query) ?? false) ||
                    (op.location?.toLowerCase().contains(query) ?? false) ||
                    (op.address?.toLowerCase().contains(query) ?? false) ||
                    op.subRoleSlug.toLowerCase().contains(query) ||
                    op.allTags.any((t) => t.toLowerCase().contains(query)) ||
                    op.requirements.any((r) =>
                        r.subRoleSlug.toLowerCase().contains(query) ||
                        r.subRoleTitle.toLowerCase().contains(query) ||
                        (r.notes?.toLowerCase().contains(query) ?? false)),
              )
              .toList();
        }
      });
    });
  }

  Future<void> _openDetail(OpportunityModel opp) async {
    var detail = opp;
    if (opp.poster == null) {
      final fetched = await OpportunityService.getDetail(opp.id ?? '');
      if (fetched != null) detail = fetched;
    }
    if (mounted) {
      OpportunityDetailSheet.show(
        context,
        opportunity: detail,
        currentUserId: widget.user.id,
      );
    }
  }

  Color _getSubRoleColor(String slug) {
    switch (slug) {
      case 'tukang_kendang':
        return const Color(0xFFD97706);
      case 'institution':
        return const Color(0xFF10B981);
      case 'government':
        return const Color(0xFF1E3A8A);
      case 'mc':
        return const Color(0xFFF59E0B);
      case 'singer':
        return const Color(0xFF8B5CF6);
      case 'wedding_organizer':
        return const Color(0xFFE11D48);
      case 'event_organizer':
        return const Color(0xFFF97316);
      case 'community':
        return const Color(0xFFEC4899);
      case 'makeup_artist':
        return const Color(0xFFD946EF);
      case 'photographer':
        return const Color(0xFF3B82F6);
      case 'editor':
        return const Color(0xFF14B8A6);
      case 'videographer':
        return const Color(0xFF0EA5E9);
      default:
        return Colors.indigo;
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final accentColor = SubRoleThemeEngine.getAccentColor(
      widget.user.role,
      widget.user.subRole,
    );

    final scaffold = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: Navigator.canPop(context),
        toolbarHeight: 64,
        titleSpacing: isDesktop ? 32 : 16,
        elevation: 0,
        title: const Text(
          'Jelajahi Kolaborasi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? AppTheme.dividerDark
                      : AppTheme.dividerLight,
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              indicatorColor: accentColor,
              indicatorWeight: 3,
              labelColor: accentColor,
              unselectedLabelColor:
                  isDark ? Colors.white60 : Colors.grey.shade600,
              indicatorSize: TabBarIndicatorSize.tab,
              labelPadding:
                  EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 4),
              labelStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isDesktop ? 13.5 : 12,
              ),
              unselectedLabelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isDesktop ? 13.5 : 12,
              ),
              tabs: [
                const Tab(
                  icon: Icon(Icons.map_outlined, size: 18),
                  text: 'Peluang Lokasi',
                ),
                if (_isCreator)
                  const Tab(
                    icon: Icon(Icons.work_outline, size: 18),
                    text: 'Peluang Proyek',
                  ),
                const Tab(icon: Icon(Icons.grid_view, size: 18), text: 'Semua'),
                const Tab(
                  icon: Icon(Icons.person_search, size: 18),
                  text: 'Kreator',
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          PeluangLokasiScreen(user: widget.user, subRoleSlug: _selectedSubRole),
          if (_isCreator)
            PeluangProyekScreen(user: widget.user, subRoleSlug: _selectedSubRole),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(
                children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'Cari peluang, lokasi, atau deskripsi...',
                  leading: const Icon(Icons.search, color: Colors.grey),
                  elevation: WidgetStateProperty.all(0),
                  backgroundColor: WidgetStateProperty.all(
                    isDark ? AppTheme.cardBg : Colors.grey.shade100,
                  ),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDark
                            ? AppTheme.inputBorder
                            : Colors.grey.shade200,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardBg : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.inputBorder
                          : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedSubRole,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isDark ? Colors.white70 : Colors.black54,
                        size: 22,
                      ),
                      dropdownColor: isDark
                          ? const Color(0xFF1E1E2D)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 4,
                      menuMaxHeight: 380,
                      onChanged: (newSlug) {
                        if (newSlug != null) {
                          setState(() => _selectedSubRole = newSlug);
                          _loadOpportunities();
                        }
                      },
                      items: _filterOptions.map((opt) {
                        final slug = opt['slug']!;
                        final name = opt['name']!;
                        final isSelected = _selectedSubRole == slug;
                        final color = _getSubRoleColor(slug);
                        return DropdownMenuItem<String>(
                          value: slug,
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? (isDark
                                            ? Colors.white
                                            : AppTheme.primaryPurple)
                                        : (isDark
                                            ? Colors.white70
                                            : Colors.black87),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: AppTheme.primaryPurple,
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadOpportunities,
                  child: _isLoading
                      ? isDesktop
                            ? GridView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  110,
                                ),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 2.5,
                                    ),
                                itemCount: 6,
                                itemBuilder: (context, index) =>
                                    const FeatureCardSkeleton(),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  110,
                                ),
                                itemCount: 4,
                                itemBuilder: (context, index) =>
                                    const FeatureCardSkeleton(),
                              )
                      : _filteredOpportunities.isEmpty
                      ? ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(48),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.search_off_outlined,
                                    size: 60,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Peluang tidak ditemukan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : isDesktop
                      ? GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 2.5,
                              ),
                          itemCount: _filteredOpportunities.length,
                          itemBuilder: (context, index) {
                            final op = _filteredOpportunities[index];
                            return FeatureCard(
                              opportunity: op,
                              accentColor: _getSubRoleColor(op.subRoleSlug),
                              onTap: () => _openDetail(op),
                            );
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                          itemCount: _filteredOpportunities.length,
                          itemBuilder: (context, index) {
                            final op = _filteredOpportunities[index];
                            return FeatureCard(
                              opportunity: op,
                              accentColor: _getSubRoleColor(op.subRoleSlug),
                              onTap: () => _openDetail(op),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      const RecommendedCreatorsSection(),
    ],
  ),
);

    if (isDesktop) {
      return DesktopSidebarLayout(
        user: widget.user,
        activeRoute: 'explore',
        child: scaffold,
      );
    }

    return scaffold;
  }
}
