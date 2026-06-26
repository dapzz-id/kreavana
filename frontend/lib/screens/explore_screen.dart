import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../models/opportunity_model.dart';
import '../services/opportunity_service.dart';
import '../widgets/feature_card.dart';
import '../widgets/opportunity_detail_sheet.dart';
import 'peluang_lokasi_screen.dart';
import 'peluang_proyek_screen.dart';

class ExploreScreen extends StatefulWidget {
  final UserModel user;

  const ExploreScreen({super.key, required this.user});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPihak = 'all';
  bool _isLoading = false;
  List<OpportunityModel> _opportunities = [];
  final TextEditingController _searchController = TextEditingController();
  List<OpportunityModel> _filteredOpportunities = [];

  final List<Map<String, String>> _filterOptions = [
    {'slug': 'all', 'name': 'Semua'},
    {'slug': 'kreator', 'name': 'Kreator'},
    {'slug': 'eo', 'name': 'Event Organizer'},
    {'slug': 'wo', 'name': 'Wedding Organizer'},
    {'slug': 'sekolah', 'name': 'Pendidikan'},
    {'slug': 'umkm', 'name': 'UMKM/Bisnis'},
    {'slug': 'pemerintah', 'name': 'Pemerintah'},
    {'slug': 'komunitas', 'name': 'Komunitas'},
    {'slug': 'organisasi', 'name': 'Organisasi'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOpportunities();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOpportunities() async {
    setState(() => _isLoading = true);
    try {
      final list = await OpportunityService.getOpportunities(
        pihak: _selectedPihak,
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
  }

  Future<void> _openDetail(OpportunityModel opp) async {
    var detail = opp;
    if (opp.poster == null) {
      final fetched = await OpportunityService.getDetail(opp.id);
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

  Color _getPihakColor(String slug) {
    switch (slug) {
      case 'kreator':
        return const Color(0xFFF97316);
      case 'eo':
        return const Color(0xFF3B82F6);
      case 'wo':
        return const Color(0xFF8B5CF6);
      case 'sekolah':
        return const Color(0xFF10B981);
      case 'umkm':
        return const Color(0xFF06B6D4);
      case 'pemerintah':
        return const Color(0xFF1E3A8A);
      case 'komunitas':
        return const Color(0xFFEC4899);
      case 'organisasi':
        return const Color(0xFF3F51B5);
      default:
        return Colors.indigo;
    }
  }

  @override
  Widget build(BuildContext context) {
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
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.map_outlined, size: 18), text: 'Peluang Lokasi'),
            Tab(icon: Icon(Icons.work_outline, size: 18), text: 'Peluang Proyek'),
            Tab(icon: Icon(Icons.grid_view, size: 18), text: 'Semua'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          PeluangLokasiScreen(
            user: widget.user,
            pihakSlug: _selectedPihak,
          ),
          PeluangProyekScreen(
            user: widget.user,
            pihakSlug: _selectedPihak,
          ),
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
                    final isSelected = _selectedPihak == opt['slug'];
                    final itemColor = _getPihakColor(opt['slug']!);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8, top: 8),
                      child: FilterChip(
                        label: Text(opt['name']!),
                        selected: isSelected,
                        selectedColor: itemColor.withValues(alpha: 0.2),
                        checkmarkColor: itemColor,
                        onSelected: (_) {
                          setState(() => _selectedPihak = opt['slug']!);
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
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredOpportunities.isEmpty
                          ? ListView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(48),
                                  child: Column(
                                    children: [
                                      Icon(Icons.search_off_outlined,
                                          size: 60,
                                          color: Colors.grey.shade400),
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
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 16, 16, 110),
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
                                      accentColor: _getPihakColor(op.pihakSlug),
                                      onTap: () => _openDetail(op),
                                    );
                                  },
                                )
                              : ListView.builder(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 16, 16, 110),
                                  itemCount: _filteredOpportunities.length,
                                  itemBuilder: (context, index) {
                                    final op = _filteredOpportunities[index];
                                    return FeatureCard(
                                      opportunity: op,
                                      accentColor: _getPihakColor(op.pihakSlug),
                                      onTap: () => _openDetail(op),
                                    );
                                  },
                                ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
