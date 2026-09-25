import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../models/opportunity_model.dart';
import '../services/opportunity_service.dart';
import '../widgets/feature_card.dart';
import '../widgets/opportunity_detail_sheet.dart';
import '../widgets/skeleton_box.dart';

class PeluangProyekScreen extends StatefulWidget {
  final UserModel user;
  final String subRoleSlug;

  const PeluangProyekScreen({
    super.key,
    required this.user,
    this.subRoleSlug = 'all',
  });

  @override
  State<PeluangProyekScreen> createState() => _PeluangProyekScreenState();
}

class _PeluangProyekScreenState extends State<PeluangProyekScreen> {
  bool _isLoading = true;
  List<OpportunityModel> _projects = [];
  final TextEditingController _searchController = TextEditingController();
  List<OpportunityModel> _filtered = [];

  String _selectedRole = 'all';
  String _selectedCity = 'all';
  String? _selectedTag;

  static const List<Map<String, String>> _roleFilters = [
    {'slug': 'all', 'label': 'Semua Peran'},
    {'slug': 'fotografi', 'label': '📸 Fotografer'},
    {'slug': 'videografi', 'label': '🎥 Videografer'},
    {'slug': 'mc', 'label': '🎤 MC / Host'},
    {'slug': 'event_organizer', 'label': '🎪 Event Organizer'},
    {'slug': 'wedding_organizer', 'label': '💍 Wedding Organizer'},
    {'slug': 'makeup_artist', 'label': '💄 MUA'},
    {'slug': 'editor', 'label': '✂️ Editor Video'},
    {'slug': 'animator', 'label': '🎨 Animator'},
    {'slug': 'desain-grafis', 'label': '🖌️ Desain Grafis'},
    {'slug': 'drone', 'label': '🚁 Pilot Drone'},
    {'slug': 'singer', 'label': '🎵 Penyanyi'},
    {'slug': 'model', 'label': '💃 Model / Talent'},
    {'slug': 'copywriter', 'label': '✍️ Copywriter'},
    {'slug': 'community', 'label': '👥 Komunitas'},
    {'slug': 'institution', 'label': '🏛️ Lembaga'},
    {'slug': 'government', 'label': '🏢 Instansi'},
  ];

  static const List<String> _cityFilters = [
    'all',
    'Jakarta',
    'Bandung',
    'Surabaya',
    'Yogyakarta',
    'Bali',
    'Semarang',
    'Medan',
    'Makassar',
    'Solo',
    'Malang',
    'Remote',
  ];

  static const List<String> _popularTags = [
    'Portrait',
    'Landscape',
    'Wedding',
    'Katalog Produk',
    'Cinematic',
    'Reels',
    'Corporate',
    'Aftermovie',
    'Studio',
    'Drone',
    'Prewedding',
    'Fashion',
  ];

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.subRoleSlug.isNotEmpty ? widget.subRoleSlug : 'all';
    _loadProjects();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    final list = await OpportunityService.getOpportunities(
      subRole: _selectedRole,
    );
    if (mounted) {
      setState(() {
        _projects = list;
        _isLoading = false;
      });
      _filter();
    }
  }

  void _filter() {
    final q = _searchController.text.toLowerCase().trim();

    setState(() {
      _filtered = _projects.where((p) {
        // 1. Text Search matching across title, desc, address, location, tags, roles
        if (q.isNotEmpty) {
          final matchesTitle = p.title.toLowerCase().contains(q);
          final matchesDesc = p.description?.toLowerCase().contains(q) ?? false;
          final matchesLoc = p.location?.toLowerCase().contains(q) ?? false;
          final matchesAddr = p.address?.toLowerCase().contains(q) ?? false;
          final matchesRole = p.subRoleSlug.toLowerCase().contains(q);
          final matchesReqRole = p.requirements.any((r) =>
              r.subRoleSlug.toLowerCase().contains(q) ||
              r.subRoleTitle.toLowerCase().contains(q) ||
              (r.notes?.toLowerCase().contains(q) ?? false));
          final matchesTags = p.allTags.any((t) => t.toLowerCase().contains(q));

          if (!matchesTitle &&
              !matchesDesc &&
              !matchesLoc &&
              !matchesAddr &&
              !matchesRole &&
              !matchesReqRole &&
              !matchesTags) {
            return false;
          }
        }

        // 2. Role filter
        if (_selectedRole != 'all') {
          final roleSlugNorm = _selectedRole.toLowerCase().replaceAll('-', '_');
          final matchesPrimary = p.subRoleSlug.toLowerCase().replaceAll('-', '_') == roleSlugNorm;
          final matchesReq = p.requirements.any((r) =>
              r.subRoleSlug.toLowerCase().replaceAll('-', '_') == roleSlugNorm);
          if (!matchesPrimary && !matchesReq) return false;
        }

        // 3. City / Wilayah filter
        if (_selectedCity != 'all') {
          final targetCity = _selectedCity.toLowerCase();
          final loc = (p.location ?? '').toLowerCase();
          final addr = (p.address ?? '').toLowerCase();

          if (targetCity == 'remote') {
            if (!loc.contains('remote') && !loc.contains('online') && !addr.contains('remote')) {
              return false;
            }
          } else {
            if (!loc.contains(targetCity) && !addr.contains(targetCity)) {
              return false;
            }
          }
        }

        // 4. Tag filter
        if (_selectedTag != null && _selectedTag!.isNotEmpty) {
          final targetTag = _selectedTag!.toLowerCase();
          final matchesTag = p.allTags.any((t) => t.toLowerCase() == targetTag) ||
              p.requirements.any((r) => r.notes?.toLowerCase().contains(targetTag) ?? false) ||
              p.title.toLowerCase().contains(targetTag) ||
              (p.description?.toLowerCase().contains(targetTag) ?? false);
          if (!matchesTag) return false;
        }

        return true;
      }).toList();
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
      case 'fotografi':
        return const Color(0xFF3B82F6);
      case 'editor':
        return const Color(0xFF14B8A6);
      case 'videographer':
      case 'videografi':
        return const Color(0xFF0EA5E9);
      default:
        return Colors.indigo;
    }
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedRole = 'all';
      _selectedCity = 'all';
      _selectedTag = null;
    });
    _loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    final hasActiveFilter = _searchController.text.isNotEmpty ||
        _selectedRole != 'all' ||
        _selectedCity != 'all' ||
        _selectedTag != null;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0D15) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: Navigator.canPop(context),
        toolbarHeight: 76,
        titleSpacing: isDesktop ? 32 : 16,
        elevation: 0,
        backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Peluang Proyek',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            const SizedBox(height: 2),
            Text(
              'Cari kebutuhan proyek berdasarkan keahlian, tag spesifik, dan wilayah',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Filter & Search Header Card ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 32 : 16,
              12,
              isDesktop ? 32 : 16,
              14,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Search Bar
                Row(
                  children: [
                    Expanded(
                      child: SearchBar(
                        controller: _searchController,
                        hintText: 'Cari proyek, tag (misal: portrait, wedding, reels), atau kota...',
                        leading: const Icon(Icons.search, color: Colors.grey),
                        trailing: _searchController.text.isNotEmpty
                            ? [
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => _searchController.clear(),
                                ),
                              ]
                            : null,
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
                    if (hasActiveFilter) ...[
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Reset', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Role Selector Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _roleFilters.map((rf) {
                      final isSelected = _selectedRole == rf['slug'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(rf['label']!),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryPurple.withValues(alpha: 0.18),
                          checkmarkColor: AppTheme.primaryPurple,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppTheme.primaryPurple : null,
                          ),
                          onSelected: (val) {
                            setState(() {
                              _selectedRole = val ? rf['slug']! : 'all';
                            });
                            _loadProjects();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // 3. Wilayah Selector Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.place_rounded, size: 14, color: isDark ? Colors.white60 : Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Wilayah:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                      ..._cityFilters.map((city) {
                        final isSelected = _selectedCity == city;
                        final label = city == 'all' ? 'Semua Wilayah' : city;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            visualDensity: VisualDensity.compact,
                            label: Text(label),
                            selected: isSelected,
                            selectedColor: const Color(0xFF06B6D4).withValues(alpha: 0.18),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFF0891B2) : null,
                            ),
                            onSelected: (val) {
                              setState(() {
                                _selectedCity = val ? city : 'all';
                              });
                              _filter();
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 4. Popular Skill Tags Quick Filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sell_outlined, size: 13, color: isDark ? Colors.white60 : Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Tag Populer:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                      ..._popularTags.map((tag) {
                        final isSelected = _selectedTag?.toLowerCase() == tag.toLowerCase();
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: isSelected
                                ? AppTheme.primaryPurple.withValues(alpha: 0.2)
                                : (isDark ? const Color(0xFF201D33) : const Color(0xFFF1F3F9)),
                            side: BorderSide(
                              color: isSelected ? AppTheme.primaryPurple : Colors.transparent,
                            ),
                            label: Text(
                              '#$tag',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? AppTheme.primaryPurple : (isDark ? Colors.white70 : Colors.grey.shade800),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedTag = null;
                                } else {
                                  _selectedTag = tag;
                                }
                              });
                              _filter();
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Results Status Header ──
          Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 32 : 16,
              12,
              isDesktop ? 32 : 16,
              4,
            ),
            child: Row(
              children: [
                Text(
                  'Ditemukan ${_filtered.length} Peluang Proyek',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
                if (_selectedTag != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('#$_selectedTag', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            setState(() => _selectedTag = null);
                            _filter();
                          },
                          child: const Icon(Icons.close, size: 13, color: AppTheme.primaryPurple),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Opportunities List / Grid ──
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadProjects,
              child: _isLoading
                  ? (isDesktop
                      ? GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                            isDesktop ? 32 : 16,
                            16,
                            isDesktop ? 32 : 16,
                            110,
                          ),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 2.2,
                          ),
                          itemCount: 6,
                          itemBuilder: (context, index) => const FeatureCardSkeleton(),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                          itemCount: 4,
                          itemBuilder: (context, index) => const FeatureCardSkeleton(),
                        ))
                  : _filtered.isEmpty
                      ? ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Tidak ada peluang proyek yang cocok',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Coba gunakan kata kunci pencarian lain, pilih peran berbeda, atau reset filter.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    onPressed: _clearFilters,
                                    icon: const Icon(Icons.refresh_rounded, size: 18),
                                    label: const Text('Reset Semua Filter'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryPurple,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : (isDesktop
                          ? GridView.builder(
                              padding: EdgeInsets.fromLTRB(
                                isDesktop ? 32 : 16,
                                12,
                                isDesktop ? 32 : 16,
                                110,
                              ),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 2.1,
                              ),
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) {
                                final op = _filtered[index];
                                return FeatureCard(
                                  opportunity: op,
                                  accentColor: _getSubRoleColor(op.subRoleSlug),
                                  onTap: () => _openDetail(op),
                                );
                              },
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) {
                                final op = _filtered[index];
                                return FeatureCard(
                                  opportunity: op,
                                  accentColor: _getSubRoleColor(op.subRoleSlug),
                                  onTap: () => _openDetail(op),
                                );
                              },
                            )),
            ),
          ),
        ],
      ),
    );
  }
}
