import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../models/opportunity_model.dart';
import '../services/opportunity_service.dart';
import '../widgets/opportunity_detail_sheet.dart';

class PeluangLokasiScreen extends StatefulWidget {
  final UserModel user;
  final String pihakSlug;

  const PeluangLokasiScreen({
    super.key,
    required this.user,
    this.pihakSlug = 'all',
  });

  @override
  State<PeluangLokasiScreen> createState() => _PeluangLokasiScreenState();
}

class _PeluangLokasiScreenState extends State<PeluangLokasiScreen> {
  final MapController _mapController = MapController();
  bool _isLoading = true;
  List<OpportunityModel> _locations = [];
  String _selectedCategory = 'all';

  static const _categories = [
    {'slug': 'all', 'name': 'Semua', 'color': Colors.indigo},
    {'slug': 'nature', 'name': 'Alam', 'color': Colors.green},
    {'slug': 'tourism', 'name': 'Wisata', 'color': Colors.blue},
    {'slug': 'culture', 'name': 'Budaya', 'color': Colors.brown},
    {'slug': 'urban', 'name': 'Urban', 'color': Colors.grey},
    {'slug': 'hidden_gems', 'name': 'Hidden Gems', 'color': Colors.purple},
    {'slug': 'seasonal', 'name': 'Seasonal', 'color': Colors.orange},
  ];

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoading = true);
    final list = await OpportunityService.getMapLocations(
      pihak: widget.pihakSlug,
    );
    if (mounted) {
      setState(() {
        _locations = list;
        _isLoading = false;
      });
    }
  }

  List<OpportunityModel> get _filtered {
    if (_selectedCategory == 'all') return _locations;
    return _locations
        .where((l) => l.locationCategory == _selectedCategory)
        .toList();
  }

  Color _markerColor(String? category) {
    switch (category) {
      case 'nature':
        return Colors.green;
      case 'tourism':
        return Colors.blue;
      case 'culture':
        return Colors.brown;
      case 'urban':
        return Colors.grey.shade700;
      case 'hidden_gems':
        return Colors.purple;
      case 'seasonal':
        return Colors.orange;
      default:
        return Colors.teal;
    }
  }

  Future<void> _onMarkerTap(OpportunityModel opp) async {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Peluang Lokasi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Content Opportunity Map',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLocations,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat['slug'];
                final color = cat['color'] as Color;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat['name'] as String),
                    selected: isSelected,
                    selectedColor: color.withValues(alpha: 0.2),
                    checkmarkColor: color,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? color
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    onSelected: (_) {
                      setState(() => _selectedCategory = cat['slug'] as String);
                    },
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: const LatLng(-2.5, 118.0),
                          initialZoom: 5.0,
                          minZoom: 4,
                          maxZoom: 18,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.kreavana.app',
                          ),
                          MarkerLayer(
                            markers: filtered
                                .where((l) =>
                                    l.latitude != null && l.longitude != null)
                                .map((loc) {
                              final color = _markerColor(loc.locationCategory);
                              return Marker(
                                point: LatLng(loc.latitude!, loc.longitude!),
                                width: 120,
                                height: 65,
                                child: GestureDetector(
                                  onTap: () => _onMarkerTap(loc),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: color.withValues(alpha: 0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        constraints: const BoxConstraints(
                                          maxWidth: 110,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? AppTheme.cardBg
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isDark
                                                ? AppTheme.inputBorder
                                                : Colors.grey.shade300,
                                            width: 0.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.1),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          loc.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
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
                      if (filtered.isEmpty)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            margin: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.cardBg
                                  : Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.map_outlined,
                                    size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                const Text(
                                  'Belum ada lokasi di kategori ini',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.cardBg
                                : Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.touch_app,
                                  size: 20, color: Colors.teal.shade600),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Ketuk marker untuk lihat kontak pembuat & laporkan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppTheme.textMuted
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${filtered.length} lokasi',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
