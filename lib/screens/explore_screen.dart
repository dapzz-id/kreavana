import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../models/opportunity_model.dart';
import '../services/dashboard_service.dart';
import '../widgets/feature_card.dart';

class ExploreScreen extends StatefulWidget {
  final UserModel user;

  const ExploreScreen({super.key, required this.user});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
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
    _loadOpportunities();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOpportunities() async {
    setState(() => _isLoading = true);
    try {
      final list = await DashboardService.getOpportunities(
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
            .where((op) =>
                op.title.toLowerCase().contains(query) ||
                (op.description?.toLowerCase().contains(query) ?? false) ||
                (op.location?.toLowerCase().contains(query) ?? false))
            .toList();
      }
    });
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
        title: const Text(
          'Jelajahi Kolaborasi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'Cari peluang, lokasi, atau deskripsi...',
                  leading: const Icon(Icons.search, color: Colors.grey),
                  trailing: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                  ],
                  elevation: WidgetStateProperty.all(0),
                  backgroundColor: WidgetStateProperty.all(
                    isDark ? AppTheme.cardBg : Colors.grey.shade100,
                  ),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Filter Horizontal Bar
              Container(
                height: 50,
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filterOptions.length,
                  itemBuilder: (context, index) {
                    final opt = _filterOptions[index];
                    final isSelected = _selectedPihak == opt['slug'];
                    final itemColor = _getPihakColor(opt['slug']!);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(opt['name']!),
                        selected: isSelected,
                        selectedColor: itemColor.withOpacity(0.2),
                        checkmarkColor: itemColor,
                        labelStyle: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? itemColor : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        onSelected: (val) {
                          setState(() {
                            _selectedPihak = opt['slug']!;
                          });
                          _loadOpportunities();
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? itemColor
                              : (isDark ? AppTheme.inputBorder : Colors.grey.shade300),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Opportunities list or grid
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadOpportunities,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredOpportunities.isEmpty
                          ? ListView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(48.0),
                                  child: Column(
                                    children: [
                                      Icon(Icons.search_off_outlined,
                                          size: 60, color: Colors.grey.shade400),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Peluang tidak ditemukan',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Coba gunakan filter lain atau ubah kata pencarian Anda.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : isDesktop
                              ? GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                                      onTap: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Membuka detail "${op.title}"...'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _filteredOpportunities.length,
                                  itemBuilder: (context, index) {
                                    final op = _filteredOpportunities[index];
                                    return FeatureCard(
                                      opportunity: op,
                                      accentColor: _getPihakColor(op.pihakSlug),
                                      onTap: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Membuka detail "${op.title}"...'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
