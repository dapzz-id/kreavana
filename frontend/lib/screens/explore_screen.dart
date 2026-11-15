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
    {'slug': 'all', 'name': 'Semua Kategori'},
    {'slug': 'videographer', 'name': 'Videografer & Sinema'},
    {'slug': 'photographer', 'name': 'Fotografer & Visual'},
    {'slug': 'designer', 'name': 'Desain Grafis & UI/UX'},
    {'slug': 'animator', 'name': 'Animasi 2D & 3D'},
    {'slug': 'editor', 'name': 'Editor Video & VFX'},
    {'slug': 'drone_pilot', 'name': 'Pilot Drone & FPV'},
    {'slug': 'content_creator', 'name': 'Content Creator'},
    {'slug': 'makeup_artist', 'name': 'Makeup Artist (MUA)'},
    {'slug': 'mc', 'name': 'MC & Public Speaker'},
    {'slug': 'musician', 'name': 'Musisi & Audio'},
    {'slug': 'talent', 'name': 'Talenta & Model'},
    {'slug': 'event_organizer', 'name': 'Event Organizer'},
    {'slug': 'wedding_organizer', 'name': 'Wedding Organizer'},
    {'slug': 'community', 'name': 'Komunitas Kreatif'},
    {'slug': 'institution', 'name': 'Institusi Pendidikan'},
    {'slug': 'government', 'name': 'Instansi Pemerintah'},
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

  Widget _buildSearchField(bool isDark) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          fontSize: 13.5,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: 'Cari peluang, lokasi, atau deskripsi...',
          hintStyle: TextStyle(
            fontSize: 13.5,
            color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: Colors.grey,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(bool isDark) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedSubRole != 'all'
              ? AppTheme.primaryPurple.withValues(alpha: 0.7)
              : (isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0)),
          width: _selectedSubRole != 'all' ? 1.4 : 1.2,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedSubRole,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? Colors.white70 : Colors.black54,
            size: 20,
          ),
          dropdownColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          elevation: 8,
          menuMaxHeight: 420,
          selectedItemBuilder: (BuildContext context) {
            return _filterOptions.map((opt) {
              final slug = opt['slug']!;
              final name = opt['name']!;
              final icon = _getCategoryIcon(slug);
              final color = _getSubRoleColor(slug);

              return Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 14, color: color),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            }).toList();
          },
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
            final icon = _getCategoryIcon(slug);

            return DropdownMenuItem<String>(
              value: slug,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryPurple.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 16, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.primaryPurple
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildResetFilterButton(bool isDark) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedSubRole = 'all';
          _searchController.clear();
        });
        _loadOpportunities();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262338) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.refresh_rounded,
              size: 16,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            const SizedBox(width: 6),
            Text(
              'Reset',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getSubRoleColor(String slug) {
    switch (slug.toLowerCase().replaceAll('-', '_')) {
      case 'institution':
        return const Color(0xFF10B981);
      case 'government':
        return const Color(0xFF1E3A8A);
      case 'mc':
        return const Color(0xFFF59E0B);
      case 'singer':
      case 'musician':
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
      case 'animator':
        return const Color(0xFF6366F1);
      case 'designer':
        return const Color(0xFF8B5CF6);
      case 'drone_pilot':
      case 'drone':
        return const Color(0xFF06B6D4);
      case 'content_creator':
      case 'content':
        return const Color(0xFFF43F5E);
      case 'talent':
        return const Color(0xFFA855F7);
      case 'tukang_kendang':
        return const Color(0xFFD97706);
      default:
        return AppTheme.primaryPurple;
    }
  }

  IconData _getCategoryIcon(String slug) {
    switch (slug.toLowerCase().replaceAll('-', '_')) {
      case 'all':
        return Icons.grid_view_rounded;
      case 'videographer':
        return Icons.videocam_rounded;
      case 'photographer':
        return Icons.camera_alt_rounded;
      case 'designer':
        return Icons.palette_rounded;
      case 'animator':
        return Icons.animation_rounded;
      case 'editor':
        return Icons.movie_filter_rounded;
      case 'drone_pilot':
      case 'drone':
        return Icons.flight_rounded;
      case 'content_creator':
      case 'content':
        return Icons.auto_awesome_rounded;
      case 'makeup_artist':
        return Icons.face_retouching_natural_rounded;
      case 'mc':
        return Icons.mic_none_rounded;
      case 'singer':
      case 'musician':
        return Icons.music_note_rounded;
      case 'talent':
        return Icons.star_outline_rounded;
      case 'event_organizer':
        return Icons.event_available_rounded;
      case 'wedding_organizer':
        return Icons.favorite_outline_rounded;
      case 'community':
        return Icons.groups_rounded;
      case 'institution':
        return Icons.school_rounded;
      case 'government':
        return Icons.account_balance_rounded;
      default:
        return Icons.work_outline_rounded;
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
          Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 32 : 16,
                  14,
                  isDesktop ? 32 : 16,
                  10,
                ),
                child: isDesktop
                    ? Row(
                        children: [
                          Expanded(
                            child: _buildSearchField(isDark),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 260,
                            child: _buildCategoryDropdown(isDark),
                          ),
                          if (_selectedSubRole != 'all' || _searchController.text.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            _buildResetFilterButton(isDark),
                          ],
                        ],
                      )
                    : Column(
                        children: [
                          _buildSearchField(isDark),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildCategoryDropdown(isDark),
                              ),
                              if (_selectedSubRole != 'all' || _searchController.text.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                _buildResetFilterButton(isDark),
                              ],
                            ],
                          ),
                        ],
                      ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadOpportunities,
                  child: _isLoading
                      ? isDesktop
                            ? GridView.builder(
                                padding: EdgeInsets.fromLTRB(
                                  isDesktop ? 32 : 16,
                                  16,
                                  isDesktop ? 32 : 16,
                                  110,
                                ),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 1.65,
                                    ),
                                itemCount: 6,
                                itemBuilder: (context, index) =>
                                    const FeatureCardSkeleton(),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.fromLTRB(
                                  isDesktop ? 32 : 16,
                                  16,
                                  isDesktop ? 32 : 16,
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
                          padding: EdgeInsets.fromLTRB(
                            isDesktop ? 32 : 16,
                            16,
                            isDesktop ? 32 : 16,
                            110,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.65,
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
                          padding: EdgeInsets.fromLTRB(
                            isDesktop ? 32 : 16,
                            16,
                            isDesktop ? 32 : 16,
                            110,
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
                        ),
                ),
              ),
            ],
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
