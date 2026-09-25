import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../models/opportunity_model.dart';
import '../services/opportunity_service.dart';
import '../widgets/opportunity_detail_sheet.dart';
import '../widgets/responsive_modal.dart';

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
  AnimationController? _mapAnimationController;
  bool _isLoading = true;
  bool _isLocating = false;
  List<OpportunityModel> _locations = [];
  String _selectedCategory = 'all';
  LatLng? _userLocation;
  double? _selectedRadiusKm;

  static const _categories = [
    {'slug': 'all', 'name': 'Semua', 'color': Colors.indigo},
    {'slug': 'tukang_kendang', 'name': '🥁 Kendang', 'color': Color(0xFFD97706)},
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

  static const _radiusOptions = [
    {'label': 'Semua Jarak', 'value': null},
    {'label': '5 km', 'value': 5.0},
    {'label': '10 km', 'value': 10.0},
    {'label': '25 km', 'value': 25.0},
    {'label': '50 km', 'value': 50.0},
  ];

  String? _selectedCityName;

  static const _majorCities = [
    {'name': 'Jakarta', 'lat': -6.2088, 'lng': 106.8456, 'province': 'DKI Jakarta'},
    {'name': 'Bandung', 'lat': -6.9175, 'lng': 107.6191, 'province': 'Jawa Barat'},
    {'name': 'Yogyakarta', 'lat': -7.7956, 'lng': 110.3695, 'province': 'D.I. Yogyakarta'},
    {'name': 'Surabaya', 'lat': -7.2575, 'lng': 112.7521, 'province': 'Jawa Timur'},
    {'name': 'Denpasar / Bali', 'lat': -8.6705, 'lng': 115.2126, 'province': 'Bali'},
    {'name': 'Semarang', 'lat': -6.9667, 'lng': 110.4167, 'province': 'Jawa Tengah'},
    {'name': 'Solo / Surakarta', 'lat': -7.5755, 'lng': 110.8243, 'province': 'Jawa Tengah'},
    {'name': 'Malang', 'lat': -7.9666, 'lng': 112.6326, 'province': 'Jawa Timur'},
    {'name': 'Medan', 'lat': 3.5952, 'lng': 98.6722, 'province': 'Sumatera Utara'},
    {'name': 'Makassar', 'lat': -5.1477, 'lng': 119.4327, 'province': 'Sulawesi Selatan'},
  ];

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _detectUserLocation(autoCenter: true);
  }

  @override
  void dispose() {
    _mapAnimationController?.stop();
    _mapAnimationController?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _selectCity(Map<String, dynamic>? city) {
    if (city == null) {
      setState(() {
        _selectedCityName = null;
        _userLocation = null;
      });
      _animatedMapMove(const LatLng(-2.5, 118.0), 5.0);
      _loadLocations();
      return;
    }

    final lat = city['lat'] as double;
    final lng = city['lng'] as double;
    final loc = LatLng(lat, lng);
    setState(() {
      _selectedCityName = city['name'] as String;
      _userLocation = loc;
    });
    if (_selectedRadiusKm != null) {
      _fitMapToRadius(_selectedRadiusKm!, loc);
    } else {
      _animatedMapMove(loc, 13.0);
    }
    _loadLocations();
  }

  void _showManualCityPicker(BuildContext context) {
    ResponsiveModal.show(
      context: context,
      title: 'Pilih Wilayah / Kota',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.public, color: AppTheme.primaryPurple),
            title: const Text('Seluruh Indonesia (Peta Nasional)'),
            subtitle: const Text('Tampilkan peluang di seluruh nusantara'),
            onTap: () {
              Navigator.pop(context);
              _selectCity(null);
            },
          ),
          const Divider(),
          ..._majorCities.map((city) {
            final isSelected = _selectedCityName == city['name'];
            return ListTile(
              leading: Icon(
                Icons.location_on_outlined,
                color: isSelected ? Colors.teal : Colors.grey,
              ),
              title: Text(
                city['name'] as String,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.teal : null,
                ),
              ),
              subtitle: Text(city['province'] as String),
              trailing: isSelected ? const Icon(Icons.check, color: Colors.teal) : null,
              onTap: () {
                Navigator.pop(context);
                _selectCity(city);
              },
            );
          }),
        ],
      ),
    );
  }

  Future<void> _detectUserLocation({bool autoCenter = false}) async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted && !autoCenter) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Layanan lokasi (GPS) tidak aktif di perangkat.'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Pilih Kota',
                textColor: Colors.tealAccent,
                onPressed: () => _showManualCityPicker(context),
              ),
            ),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted && !autoCenter) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Izin akses lokasi tidak diberikan.'),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'Pilih Kota',
                  textColor: Colors.tealAccent,
                  onPressed: () => _showManualCityPicker(context),
                ),
              ),
            );
          }
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted && !autoCenter) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Izin lokasi ditolak permanen. Pilih kota secara manual:'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Pilih Kota',
                textColor: Colors.tealAccent,
                onPressed: () => _showManualCityPicker(context),
              ),
            ),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            timeLimit: Duration(seconds: 3),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position != null && mounted) {
        final loc = LatLng(position.latitude, position.longitude);
        setState(() {
          _userLocation = loc;
          _selectedCityName = null;
          _isLocating = false;
        });

        if (autoCenter) {
          if (_selectedRadiusKm != null) {
            _fitMapToRadius(_selectedRadiusKm!, loc);
          } else {
            _animatedMapMove(loc, 13.0);
          }
        }

        // Re-load locations if radius filter is active
        if (_selectedRadiusKm != null) {
          _loadLocations();
        }
      } else {
        if (mounted) setState(() => _isLocating = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    try {
      _mapAnimationController?.stop();
      _mapAnimationController?.dispose();

      final camera = _mapController.camera;
      final latTween = Tween<double>(
        begin: camera.center.latitude,
        end: destLocation.latitude,
      );
      final lngTween = Tween<double>(
        begin: camera.center.longitude,
        end: destLocation.longitude,
      );
      final zoomTween = Tween<double>(
        begin: camera.zoom,
        end: destZoom,
      );

      final controller = AnimationController(
        duration: const Duration(milliseconds: 350),
        vsync: this,
      );
      _mapAnimationController = controller;

      final Animation<double> animation = CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOutCubic,
      );

      controller.addListener(() {
        _mapController.move(
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation),
        );
      });

      animation.addStatusListener((status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          controller.dispose();
          if (_mapAnimationController == controller) {
            _mapAnimationController = null;
          }
        }
      });

      controller.forward();
    } catch (_) {
      _mapController.move(destLocation, destZoom);
    }
  }

  double _calculateZoomForRadius(double radiusKm, LatLng center) {
    try {
      final camera = _mapController.camera;
      final size = camera.nonRotatedSize;
      if (size.width > 100 && size.height > 100) {
        const distance = Distance();
        final north = distance.offset(center, radiusKm * 1000, 0);
        final south = distance.offset(center, radiusKm * 1000, 180);
        final east = distance.offset(center, radiusKm * 1000, 90);
        final west = distance.offset(center, radiusKm * 1000, 270);
        final bounds = LatLngBounds(
          LatLng(south.latitude, west.longitude),
          LatLng(north.latitude, east.longitude),
        );

        final fitted = CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 72),
          minZoom: 3.0,
          maxZoom: 18.0,
        ).fit(camera);

        if (!fitted.zoom.isNaN && !fitted.zoom.isInfinite && fitted.zoom > 0) {
          return fitted.zoom.clamp(3.0, 18.0);
        }
      }
    } catch (_) {}

    // Fallback based on standard Web Mercator projection
    final latRad = center.latitude * math.pi / 180.0;
    final cosLat = math.cos(latRad).abs().clamp(0.1, 1.0);
    final paddedDiameterMeters = radiusKm * 2000.0 * 1.45;
    const assumedViewportHeight = 500.0;
    final targetZoom = math.log((assumedViewportHeight * 40075016.686 * cosLat) /
            (256.0 * paddedDiameterMeters)) /
        math.ln2;
    return targetZoom.clamp(3.0, 18.0);
  }

  void _fitMapToRadius(double radiusKm, LatLng center) {
    final targetZoom = _calculateZoomForRadius(radiusKm, center);
    _animatedMapMove(center, targetZoom);
  }

  void _zoomIn() {
    final targetZoom = (_mapController.camera.zoom + 1.0).clamp(3.0, 18.0);
    _animatedMapMove(_mapController.camera.center, targetZoom);
  }

  void _zoomOut() {
    final targetZoom = (_mapController.camera.zoom - 1.0).clamp(3.0, 18.0);
    _animatedMapMove(_mapController.camera.center, targetZoom);
  }

  void _resetCenter(bool isMobile) {
    if (_userLocation != null) {
      if (_selectedRadiusKm != null) {
        _fitMapToRadius(_selectedRadiusKm!, _userLocation!);
      } else {
        _animatedMapMove(_userLocation!, 13.0);
      }
    } else {
      _animatedMapMove(const LatLng(-2.5, 118.0), isMobile ? 4.5 : 5.0);
    }
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoading = true);
    final list = await OpportunityService.getMapLocations(
      subRole: widget.subRoleSlug,
      lat: _selectedRadiusKm != null ? _userLocation?.latitude : null,
      lng: _selectedRadiusKm != null ? _userLocation?.longitude : null,
      radiusKm: _selectedRadiusKm,
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
      case 'tukang_kendang':
        return const Color(0xFFD97706);
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
        automaticallyImplyLeading: Navigator.canPop(context),
        toolbarHeight: isMobile ? 65 : 80,
        titleSpacing: isMobile ? 16 : 32,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Peluang Lokasi',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 18 : 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Content Opportunity Map',
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                fontWeight: FontWeight.normal,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLocations,
          ),
          SizedBox(width: isMobile ? 8 : 24),
        ],
      ),
      body: Column(
        children: [
          // ── Category filter chips ────────────────────────────────────────
          SizedBox(
            height: isMobile ? 40 : 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
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

          // ── Radius & Location Toolbar ──────────────────────────────────
          Container(
            height: isMobile ? 42 : 46,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 12,
              vertical: 4,
            ),
            child: Row(
              children: [
                // "Lokasi Saya" button
                InkWell(
                  onTap: _isLocating ? null : () => _detectUserLocation(autoCenter: true),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _userLocation != null
                          ? Colors.teal.withValues(alpha: 0.15)
                          : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _userLocation != null
                            ? Colors.teal
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _isLocating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                _userLocation != null
                                    ? Icons.my_location
                                    : Icons.location_searching,
                                size: 14,
                                color: _userLocation != null
                                    ? Colors.teal
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                        const SizedBox(width: 6),
                        Text(
                          _userLocation != null ? 'Lokasi Aktif' : 'Cari Sekitar Saya',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _userLocation != null
                                ? Colors.teal
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // "Pilih Kota" manual selector button
                InkWell(
                  onTap: () => _showManualCityPicker(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedCityName != null
                          ? Colors.teal.withValues(alpha: 0.15)
                          : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedCityName != null
                            ? Colors.teal
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_city,
                          size: 14,
                          color: _selectedCityName != null
                              ? Colors.teal
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedCityName ?? 'Pilih Kota',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _selectedCityName != null
                                ? Colors.teal
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const VerticalDivider(width: 1, thickness: 1),
                const SizedBox(width: 8),

                // Radius filter options
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _radiusOptions.length,
                    itemBuilder: (context, index) {
                      final opt = _radiusOptions[index];
                      final isSelected = _selectedRadiusKm == opt['value'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            opt['label'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? Colors.teal.shade900
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: Colors.teal.shade100,
                          onSelected: (_) {
                            final radius = opt['value'] as double?;
                            setState(() {
                              _selectedRadiusKm = radius;
                            });
                            if (_userLocation == null && radius != null) {
                              _detectUserLocation(autoCenter: true);
                            } else {
                              if (radius != null && _userLocation != null) {
                                _fitMapToRadius(radius, _userLocation!);
                              } else if (radius == null && _userLocation != null) {
                                _animatedMapMove(_userLocation!, 13.0);
                              }
                              _loadLocations();
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Map area ────────────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                // ── Persistent Single Map ────────────────────────────────
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _userLocation ?? const LatLng(-2.5, 118.0),
                    initialZoom: _userLocation != null ? 13.0 : (isMobile ? 4.5 : 5.0),
                    minZoom: 3,
                    maxZoom: 18,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.kreavana.app',
                      maxNativeZoom: 19,
                      maxZoom: 18,
                      minZoom: 3,
                      keepBuffer: 3,
                      panBuffer: 1,
                    ),

                          // Radius circle layer if active
                          if (_userLocation != null && _selectedRadiusKm != null)
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: _userLocation!,
                                  radius: _selectedRadiusKm! * 1000,
                                  useRadiusInMeter: true,
                                  color: Colors.teal.withValues(alpha: 0.1),
                                  borderColor: Colors.teal.shade400,
                                  borderStrokeWidth: 1.5,
                                ),
                              ],
                            ),

                          MarkerLayer(
                            markers: [
                              // User Location Marker
                              if (_userLocation != null)
                                Marker(
                                  point: _userLocation!,
                                  width: 80,
                                  height: 80,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade600,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.blue.withValues(alpha: 0.5),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.my_location,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade700,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Lokasi Anda',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Opportunity Markers
                              ...filtered
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
                                }),
                            ],
                          ),
                        ],
                      ),

                      // ── Non-blocking floating loading indicator ─────────
                      if (_isLoading)
                        Positioned(
                          top: 14,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E1E2C)
                                    : Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.teal),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Memuat peluang...',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // ── Empty state ──────────────────────────────────────
                      if (!_isLoading && filtered.isEmpty)
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
      {'slug': 'tukang_kendang', 'label': '🥁 Tukang Kendang'},
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

    final isDesktop = MediaQuery.of(context).size.width >= 600;

    Widget buildLocationForm(
      BuildContext ctx,
      StateSetter setModalState,
      ScrollController? scrollController, {
      bool inDialog = false,
    }) {
      return ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(20, inDialog ? 20 : 12, 20, 32),
        children: [
          if (!inDialog) ...[
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
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📍 Tambah Lokasi Kolaborasi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (inDialog)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                  tooltip: 'Tutup',
                ),
            ],
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
      );
    }

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => Dialog(
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 620,
                maxHeight: MediaQuery.of(ctx).size.height * 0.88,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardBg : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: buildLocationForm(ctx, setModalState, null, inDialog: true),
              ),
            ),
          ),
        ),
      );
    } else {
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
              child: buildLocationForm(ctx, setModalState, scrollController, inDialog: false),
            ),
          ),
        ),
      );
    }
  }
}
