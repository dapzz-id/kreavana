import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
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
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
                    (op.location?.toLowerCase().contains(query) ?? false),
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

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text(
          'Jelajahi Kolaborasi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.map_outlined, size: 18),
              text: 'Peluang Lokasi',
            ),
            Tab(
              icon: Icon(Icons.work_outline, size: 18),
              text: 'Peluang Proyek',
            ),
            Tab(icon: Icon(Icons.grid_view, size: 18), text: 'Semua'),
            Tab(icon: Icon(Icons.person_search, size: 18), text: 'Kreator'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          PeluangLokasiScreen(user: widget.user, subRoleSlug: _selectedSubRole),
          PeluangProyekScreen(user: widget.user, subRoleSlug: _selectedSubRole),
          Column(
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
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filterOptions.length,
                  itemBuilder: (context, index) {
                    final opt = _filterOptions[index];
                    final isSelected = _selectedSubRole == opt['slug'];
                    final itemColor = _getSubRoleColor(opt['slug']!);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8, top: 8),
                      child: FilterChip(
                        label: Text(opt['name']!),
                        selected: isSelected,
                        selectedColor: itemColor.withValues(alpha: 0.2),
                        checkmarkColor: itemColor,
                        onSelected: (_) {
                          setState(() => _selectedSubRole = opt['slug']!);
                          _loadOpportunities();
                        },
                      ),
                    );
                  },
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
          const RecommendedCreatorsSection(),
        ],
      ),
    );
  }
}
