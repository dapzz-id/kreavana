import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../models/opportunity_model.dart';
import '../services/opportunity_service.dart';
import '../widgets/opportunity_detail_sheet.dart';
import '../widgets/skeleton_box.dart';

class PeluangLokasiScreen extends StatefulWidget {
  final UserModel user;
  final String subRoleSlug;

  const PeluangLokasiScreen({
    super.key,
    required this.user,
    this.subRoleSlug = 'all',
  });

  @override
  State<PeluangLokasiScreen> createState() => _PeluangLokasiScreenState();
}

class _PeluangLokasiScreenState extends State<PeluangLokasiScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _isLoading = true;
  List<OpportunityModel> _locations = [];
  String _selectedCategory = 'all';

  static const _categories = [
    {'slug': 'all', 'name': 'Semua', 'color': Colors.indigo},
    {'slug': 'mc', 'name': 'MC', 'color': Color(0xFFF59E0B)},
    {'slug': 'videographer', 'name': 'Videografer', 'color': Color(0xFF0EA5E9)},
    {'slug': 'photographer', 'name': 'Fotografer', 'color': Color(0xFF3B82F6)},
    {'slug': 'editor', 'name': 'Editor', 'color': Color(0xFF14B8A6)},
    {'slug': 'makeup_artist', 'name': 'MUA', 'color': Color(0xFFD946EF)},
    {'slug': 'singer', 'name': 'Penyanyi', 'color': Color(0xFF8B5CF6)},
    {'slug': 'event_organizer', 'name': 'EO', 'color': Color(0xFFF97316)},
    {'slug': 'wedding_organizer', 'name': 'WO', 'color': Color(0xFFE11D48)},
    {'slug': 'community', 'name': 'Komunitas', 'color': Color(0xFFEC4899)},
  ];

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  void _zoomIn() {
    final targetZoom = (_mapController.camera.zoom + 1.0).clamp(3.0, 18.0);
    _mapController.move(_mapController.camera.center, targetZoom);
    if (mounted) setState(() {});
  }

  void _zoomOut() {
    final targetZoom = (_mapController.camera.zoom - 1.0).clamp(3.0, 18.0);
    _mapController.move(_mapController.camera.center, targetZoom);
    if (mounted) setState(() {});
  }

  void _resetCenter(bool isMobile) {
    _mapController.move(const LatLng(-2.5, 118.0), isMobile ? 4.5 : 5.0);
    if (mounted) setState(() {});
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoading = true);
    final list = await OpportunityService.getMapLocations(
      subRole: widget.subRoleSlug,
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
    return _locations.where((l) => l.subRoleSlug == _selectedCategory).toList();
  }

  Color _markerColor(String? subRole) {
    switch (subRole) {
      case 'mc':
        return const Color(0xFFF59E0B);
      case 'videographer':
        return const Color(0xFF0EA5E9);
      case 'photographer':
        return const Color(0xFF3B82F6);
      case 'editor':
        return const Color(0xFF14B8A6);
      case 'makeup_artist':
        return const Color(0xFFD946EF);
      case 'singer':
        return const Color(0xFF8B5CF6);
      case 'event_organizer':
        return const Color(0xFFF97316);
      case 'wedding_organizer':
        return const Color(0xFFE11D48);
      case 'community':
        return const Color(0xFFEC4899);
      default:
        return Colors.teal;
    }
  }

  Future<void> _onMarkerTap(OpportunityModel opp) async {
    // Show detail sheet immediately — don't wait for API
    if (mounted) {
      OpportunityDetailSheet.show(
        context,
        opportunity: opp,
        currentUserId: widget.user.id,
      );
    }
  }

  // ── Zoom button widget ────────────────────────────────────────────────────
  Widget _zoomButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    required bool isMobile,
    Color? iconColor,
  }) {
    final size = isMobile ? 44.0 : 48.0;
    final iconSize = isMobile ? 22.0 : 24.0;
    return Material(
      color: isDark ? AppTheme.cardBg : Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: iconColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _filtered;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isMobile ? 60 : 75,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Peluang Lokasi',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 16 : 18,
              ),
            ),
            Text(
              'Content Opportunity Map',
              style: TextStyle(
                fontSize: isMobile ? 10 : 11,
                fontWeight: FontWeight.normal,
              ),
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
          // ── Category filter chips ────────────────────────────────────────
          SizedBox(
            height: isMobile ? 40 : 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat['slug'];
                final color = cat['color'] as Color;
                return Padding(
                  padding: EdgeInsets.only(right: isMobile ? 6 : 8),
                  child: FilterChip(
                    label: Text(
                      cat['name'] as String,
                      style: TextStyle(fontSize: isMobile ? 11 : 12),
                    ),
                    selected: isSelected,
                    selectedColor: color.withValues(alpha: 0.2),
                    checkmarkColor: color,
                    labelStyle: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
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

          // ── Map area ────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? Stack(
                    children: [
                      FlutterMap(
                        options: const MapOptions(
                          initialCenter: LatLng(-2.5, 118.0),
                          initialZoom: 5.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.kreavana.app',
                          ),
                        ],
                      ),
                      Center(
                        child: Container(
                          margin: const EdgeInsets.all(24),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1E2C)
                                : Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SkeletonBox(
                                width: 48,
                                height: 48,
                                shape: BoxShape.circle,
                              ),
                              SizedBox(height: 12),
                              SkeletonBox(
                                width: 140,
                                height: 18,
                                borderRadius: 6,
                              ),
                              SizedBox(height: 8),
                              SkeletonBox(
                                width: 100,
                                height: 14,
                                borderRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      // ── Map ─────────────────────────────────────────────
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: const LatLng(-2.5, 118.0),
                          initialZoom: isMobile ? 4.5 : 5.0,
                          minZoom: 3,
                          maxZoom: 18,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                          onPositionChanged: (camera, hasGesture) {
                            if (mounted && hasGesture) {
                              setState(() {});
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.kreavana.app',
                          ),
                          MarkerLayer(
                            markers: filtered
                                .where(
                                  (l) =>
                                      l.latitude != null && l.longitude != null,
                                )
                                .map((loc) {
                                  final color = _markerColor(loc.subRoleSlug);
                                  final markerWidth = isMobile ? 90.0 : 120.0;
                                  final markerHeight = isMobile ? 50.0 : 65.0;
                                  return Marker(
                                    point: LatLng(
                                      loc.latitude!,
                                      loc.longitude!,
                                    ),
                                    width: markerWidth,
                                    height: markerHeight,
                                    child: GestureDetector(
                                      onTap: () => _onMarkerTap(loc),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(
                                              isMobile ? 4 : 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: color.withValues(
                                                    alpha: 0.4,
                                                  ),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.location_on,
                                              color: Colors.white,
                                              size: isMobile ? 16.0 : 20.0,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isMobile ? 4 : 6,
                                              vertical: isMobile ? 2 : 3,
                                            ),
                                            constraints: BoxConstraints(
                                              maxWidth: isMobile ? 80 : 110,
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
                                                fontSize: isMobile ? 8 : 9,
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
                                })
                                .toList(),
                          ),
                        ],
                      ),

                      // ── Empty state ──────────────────────────────────────
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
                                Icon(
                                  Icons.map_outlined,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Belum ada lokasi di kategori ini',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ── Bottom info bar ──────────────────────────────────
                      Positioned(
                        bottom: isMobile ? 8 : 16,
                        left: isMobile ? 12 : 16,
                        right: isMobile ? 12 : 16,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 16,
                            vertical: isMobile ? 10 : 12,
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
                              Icon(
                                Icons.touch_app,
                                size: isMobile ? 18 : 20,
                                color: Colors.teal.shade600,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isMobile
                                      ? 'Ketuk marker untuk detail'
                                      : 'Ketuk marker untuk lihat kontak pembuat & laporkan',
                                  style: TextStyle(
                                    fontSize: isMobile ? 10 : 12,
                                    color: isDark
                                        ? AppTheme.textMuted
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 8 : 10,
                                  vertical: isMobile ? 3 : 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${filtered.length} lokasi',
                                  style: TextStyle(
                                    fontSize: isMobile ? 10 : 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Zoom controls (top-right) ────────────────────────
                      Positioned(
                        right: isMobile ? 12 : 16,
                        top: isMobile ? 12 : 16,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Zoom In
                            _zoomButton(
                              icon: Icons.add,
                              isDark: isDark,
                              isMobile: isMobile,
                              onTap: _zoomIn,
                            ),
                            const SizedBox(height: 8),
                            // Zoom Out
                            _zoomButton(
                              icon: Icons.remove,
                              isDark: isDark,
                              isMobile: isMobile,
                              onTap: _zoomOut,
                            ),
                            const SizedBox(height: 8),
                            // Reset to Indonesia center
                            _zoomButton(
                              icon: Icons.my_location,
                              isDark: isDark,
                              isMobile: isMobile,
                              iconColor: Colors.teal.shade600,
                              onTap: () => _resetCenter(isMobile),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton:
          (widget.user.role == 'creator' || widget.user.isCreator)
          ? FloatingActionButton.extended(
              onPressed: () => _showAddLocationDialog(context),
              backgroundColor: Colors.teal.shade600,
              icon: const Icon(Icons.add_location_alt, color: Colors.white),
              label: const Text(
                'Tambah Lokasi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  // ── Dialog tambah lokasi creator ───────────────────────────────────────────
  void _showAddLocationDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController(
      text: widget.user.phone ?? '',
    );
    final latController = TextEditingController();
    final lngController = TextEditingController();
    String selectedSubRole = 'mc';
    String selectedCategory = 'mc';

    final subRoles = [
      {'slug': 'mc', 'label': '🎤 MC & Host Event'},
      {'slug': 'videografer', 'label': '🎥 Videografer'},
      {'slug': 'fotografer', 'label': '📸 Fotografer'},
      {'slug': 'content_creator', 'label': '🎬 Content Creator'},
      {'slug': 'animator', 'label': '🎨 Animator'},
      {'slug': 'editor', 'label': '✂️ Editor Video'},
      {'slug': 'desainer', 'label': '🖌️ Desainer Grafis'},
      {'slug': 'musisi', 'label': '🎵 Musisi & Audio'},
      {'slug': 'talent', 'label': '💃 Model & Talent'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) => Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '📍 Tambah Lokasi Kolaborasi',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Isi data di bawah agar klien / creator lain dapat menemukan Anda di peta.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                // Sub-role
                const Text(
                  'Posisi / Sub-Role Anda',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: subRoles.map((sr) {
                    final isSelected = selectedSubRole == sr['slug'];
                    return ChoiceChip(
                      label: Text(sr['label']!),
                      selected: isSelected,
                      selectedColor: Colors.teal.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? Colors.teal.shade700 : null,
                      ),
                      onSelected: (_) =>
                          setModalState(() => selectedSubRole = sr['slug']!),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Title
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Judul / Nama Layanan',
                    hintText: 'Contoh: Andi - MC Wedding & Corporate',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Description
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Deskripsi Layanan',
                    hintText:
                        'Jelaskan keahlian, pengalaman, dan jasa yang Anda tawarkan...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 12),
                // Phone
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Nomor Telepon / WhatsApp Kontak',
                    hintText: 'Contoh: 081234567890',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Address
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(
                    labelText: 'Alamat / Lokasi',
                    hintText: 'Contoh: Kuningan, Jakarta Selatan',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Lat/Lng
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Latitude',
                          hintText: '-6.2088',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: lngController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Longitude',
                          hintText: '106.8456',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Category
                const Text(
                  'Kategori Kreator',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.where((c) => c['slug'] != 'all').map((
                    cat,
                  ) {
                    final isSelected = selectedCategory == cat['slug'];
                    final color = cat['color'] as Color;
                    return ChoiceChip(
                      label: Text(cat['name'] as String),
                      selected: isSelected,
                      selectedColor: color.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? color : null,
                      ),
                      onSelected: (_) => setModalState(
                        () => selectedCategory = cat['slug'] as String,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Judul wajib diisi!'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    final lat = double.tryParse(latController.text.trim());
                    final lng = double.tryParse(lngController.text.trim());
                    final phoneInput = phoneController.text.trim();

                    final result = await OpportunityService.createOpportunity(
                      title: title,
                      subRoleSlug: selectedSubRole,
                      type: 'location',
                      description: descController.text.trim().isEmpty
                          ? null
                          : descController.text.trim(),
                      location: addressController.text.trim().isEmpty
                          ? 'Indonesia'
                          : addressController.text.trim(),
                      latitude: lat,
                      longitude: lng,
                      locationCategory: selectedCategory,
                      address: addressController.text.trim().isEmpty
                          ? null
                          : addressController.text.trim(),
                      poster: OpportunityPoster(
                        id: widget.user.id,
                        name: widget.user.name,
                        username: widget.user.username,
                        phone: phoneInput.isNotEmpty
                            ? phoneInput
                            : widget.user.phone,
                      ),
                    );

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result['message'] ?? 'Lokasi berhasil ditambahkan!',
                          ),
                          backgroundColor: Colors.teal.shade700,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      _loadLocations();
                    }
                  },
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text(
                    'Simpan & Tampilkan di Peta',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
