import 'dart:math' as math;
import 'dart:ui' as ui;
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
  OpportunityModel? _selectedOpportunity;

  static const _categories = [
    {'slug': 'all', 'name': 'Semua', 'color': Color(0xFF6366F1), 'icon': Icons.map_rounded},
    {'slug': 'tukang_kendang', 'name': 'Kendang', 'color': Color(0xFFD97706), 'icon': Icons.music_note_rounded},
    {'slug': 'institution', 'name': 'Institusi', 'color': Color(0xFF3730A3), 'icon': Icons.account_balance_rounded},
    {'slug': 'government', 'name': 'Pemerintah', 'color': Color(0xFF475569), 'icon': Icons.assured_workload_rounded},
    {'slug': 'mc', 'name': 'MC', 'color': Color(0xFFF59E0B), 'icon': Icons.mic_rounded},
    {'slug': 'videographer', 'name': 'Videografer', 'color': Color(0xFF0EA5E9), 'icon': Icons.videocam_rounded},
    {'slug': 'photographer', 'name': 'Fotografer', 'color': Color(0xFF3B82F6), 'icon': Icons.photo_camera_rounded},
    {'slug': 'editor', 'name': 'Editor', 'color': Color(0xFF14B8A6), 'icon': Icons.movie_filter_rounded},
    {'slug': 'makeup_artist', 'name': 'MUA', 'color': Color(0xFFD946EF), 'icon': Icons.face_retouching_natural_rounded},
    {'slug': 'singer', 'name': 'Penyanyi', 'color': Color(0xFF8B5CF6), 'icon': Icons.mic_external_on_rounded},
    {'slug': 'event_organizer', 'name': 'EO', 'color': Color(0xFFF97316), 'icon': Icons.event_available_rounded},
    {'slug': 'wedding_organizer', 'name': 'WO', 'color': Color(0xFFE11D48), 'icon': Icons.favorite_rounded},
    {'slug': 'community', 'name': 'Komunitas', 'color': Color(0xFFEC4899), 'icon': Icons.groups_rounded},
    {'slug': 'content_creator', 'name': 'Content Creator', 'color': Color(0xFFEF4444), 'icon': Icons.video_collection_rounded},
    {'slug': 'animator', 'name': 'Animator', 'color': Color(0xFF22C55E), 'icon': Icons.animation_rounded},
    {'slug': 'designer', 'name': 'Desainer', 'color': Color(0xFF06B6D4), 'icon': Icons.palette_rounded},
    {'slug': 'musician', 'name': 'Musisi', 'color': Color(0xFFA855F7), 'icon': Icons.album_rounded},
    {'slug': 'talent', 'name': 'Talent', 'color': Color(0xFFEAB308), 'icon': Icons.star_rounded},
    {'slug': 'drone_pilot', 'name': 'Drone Pilot', 'color': Color(0xFF64748B), 'icon': Icons.flight_takeoff_rounded},
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

  int _categoryCount(String slug) {
    if (slug == 'all') return _locations.length;
    return _locations.where((l) {
      if (l.subRoleSlug == slug) return true;
      return l.requirements.any((r) => r.subRoleSlug == slug);
    }).length;
  }

  List<OpportunityModel> get _filtered {
    if (_selectedCategory == 'all') return _locations;
    return _locations.where((l) {
      if (l.subRoleSlug == _selectedCategory) return true;
      return l.requirements.any((r) => r.subRoleSlug == _selectedCategory);
    }).toList();
  }

  IconData _markerIcon(String? subRole) {
    switch (subRole) {
      case 'tukang_kendang':
        return Icons.music_note_rounded;
      case 'institution':
        return Icons.account_balance_rounded;
      case 'government':
        return Icons.assured_workload_rounded;
      case 'mc':
        return Icons.mic_rounded;
      case 'videographer':
        return Icons.videocam_rounded;
      case 'photographer':
        return Icons.photo_camera_rounded;
      case 'editor':
        return Icons.movie_filter_rounded;
      case 'makeup_artist':
        return Icons.face_retouching_natural_rounded;
      case 'singer':
        return Icons.mic_external_on_rounded;
      case 'event_organizer':
        return Icons.event_available_rounded;
      case 'wedding_organizer':
        return Icons.favorite_rounded;
      case 'community':
        return Icons.groups_rounded;
      case 'content_creator':
        return Icons.video_collection_rounded;
      case 'animator':
        return Icons.animation_rounded;
      case 'designer':
        return Icons.palette_rounded;
      case 'musician':
        return Icons.album_rounded;
      case 'talent':
        return Icons.star_rounded;
      case 'drone_pilot':
        return Icons.flight_takeoff_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  Color _markerColor(String? subRole) {
    switch (subRole) {
      case 'tukang_kendang':
        return const Color(0xFFD97706);
      case 'institution':
        return const Color(0xFF3730A3);
      case 'government':
        return const Color(0xFF475569);
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
      case 'content_creator':
        return const Color(0xFFEF4444);
      case 'animator':
        return const Color(0xFF22C55E);
      case 'designer':
        return const Color(0xFF06B6D4);
      case 'musician':
        return const Color(0xFFA855F7);
      case 'talent':
        return const Color(0xFFEAB308);
      case 'drone_pilot':
        return const Color(0xFF64748B);
      default:
        return Colors.teal;
    }
  }

  void _onMarkerTap(OpportunityModel opp) {
    setState(() {
      _selectedOpportunity = opp;
    });
    if (opp.latitude != null && opp.longitude != null) {
      _animatedMapMove(LatLng(opp.latitude!, opp.longitude!), 15.0);
    }
  }

  Widget _buildFloatingOpportunityCard(OpportunityModel opp, bool isDark, bool isMobile) {
    String distanceStr = '';
    if (_userLocation != null && opp.latitude != null && opp.longitude != null) {
      final dKm = Geolocator.distanceBetween(
            _userLocation!.latitude,
            _userLocation!.longitude,
            opp.latitude!,
            opp.longitude!,
          ) / 1000.0;
      distanceStr = dKm < 1.0 ? '${(dKm * 1000).toInt()} m dari Anda' : '${dKm.toStringAsFixed(1)} km dari Anda';
    }

    final reqs = opp.requirements;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 280),
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B192A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category Chip + Distance + Close Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0891B2).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_available_rounded, size: 13, color: Color(0xFF0891B2)),
                      SizedBox(width: 4),
                      Text(
                        'EVENT / PROYEK TERBUKA',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF0891B2)),
                      ),
                    ],
                  ),
                ),
                if (distanceStr.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '•  $distanceStr',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.tealAccent : const Color(0xFF0D9488),
                    ),
                  ),
                ],
                const Spacer(),
                InkWell(
                  onTap: () => setState(() => _selectedOpportunity = null),
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              opp.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isMobile ? 15 : 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),

            // Location & Date
            Row(
              children: [
                const Icon(Icons.place_rounded, size: 14, color: Color(0xFFE11D48)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    opp.address ?? opp.location ?? 'Lokasi Fisik Terpilih',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            if (opp.eventDate != null || opp.budgetRange != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (opp.eventDate != null) ...[
                    const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text(
                      opp.eventDate!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (opp.budgetRange != null) ...[
                    const Icon(Icons.payments_rounded, size: 13, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      opp.budgetRange!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 10),

            // Requirements Section ("Butuh Apa Aja")
            Text(
              'Posisi & Kebutuhan Acara:',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            if (reqs.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: reqs.map((r) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      '${r.subRoleTitle} (${r.quantity} org)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                  );
                }).toList(),
              )
            else
              Text(
                opp.subRoleLabel,
                style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryPurple, fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 12),

            // Actions: Detail & Apply
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      OpportunityDetailSheet.show(
                        context,
                        opportunity: opp,
                        currentUserId: widget.user.id,
                      );
                    },
                    icon: const Icon(Icons.touch_app_rounded, size: 16),
                    label: const Text(
                      'Lihat Detail & Ajukan Lamaran',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
    final isDesktop = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !isDesktop && Navigator.canPop(context),
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
          // ── Category filter row & dropdown ─────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 12 : 24,
              6,
              isMobile ? 12 : 24,
              4,
            ),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardBg : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? AppTheme.inputBorder
                      : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedCategory,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.white70 : Colors.black54,
                    size: 22,
                  ),
                  dropdownColor: isDark
                      ? const Color(0xFF1E1E2D)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 6,
                  menuMaxHeight: 420,
                  onChanged: (newCat) {
                    if (newCat != null) {
                      setState(() => _selectedCategory = newCat);
                      final matches = _filtered;
                      if (matches.isNotEmpty &&
                          matches.first.latitude != null &&
                          matches.first.longitude != null) {
                        _animatedMapMove(
                          LatLng(matches.first.latitude!, matches.first.longitude!),
                          13.0,
                        );
                      }
                    }
                  },
                  items: _categories.map((cat) {
                    final slug = cat['slug'] as String;
                    final name = cat['name'] as String;
                    final color = cat['color'] as Color;
                    final icon = cat['icon'] as IconData? ?? Icons.place_rounded;
                    final count = _categoryCount(slug);
                    final isSelected = _selectedCategory == slug;

                    return DropdownMenuItem<String>(
                      value: slug,
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: isSelected ? 1.0 : 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              icon,
                              size: 14,
                              color: isSelected ? Colors.white : color,
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
                                    ? (isDark ? Colors.white : color)
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.18)
                                  : (isDark ? Colors.white10 : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count Lokasi',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? color
                                    : (isDark ? Colors.white54 : Colors.grey.shade600),
                              ),
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: color,
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
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

                // Radius filter dropdown
                Expanded(
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: _selectedRadiusKm != null
                          ? Colors.teal.withValues(alpha: 0.12)
                          : (isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedRadiusKm != null
                            ? Colors.teal
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<double?>(
                        isExpanded: true,
                        value: _selectedRadiusKm,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: _selectedRadiusKm != null
                              ? Colors.teal
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        dropdownColor: isDark
                            ? const Color(0xFF1E1E2D)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        elevation: 4,
                        onChanged: (radius) {
                          setState(() {
                            _selectedRadiusKm = radius;
                          });
                          if (_userLocation == null && radius != null) {
                            _detectUserLocation(autoCenter: true);
                          } else {
                            if (radius != null && _userLocation != null) {
                              _fitMapToRadius(radius, _userLocation!);
                            } else if (radius == null &&
                                _userLocation != null) {
                              _animatedMapMove(_userLocation!, 13.0);
                            }
                            _loadLocations();
                          }
                        },
                        items: _radiusOptions.map((opt) {
                          final radius = opt['value'] as double?;
                          final label = opt['label'] as String;
                          final isSelected = _selectedRadiusKm == radius;
                          return DropdownMenuItem<double?>(
                            value: radius,
                            child: Row(
                              children: [
                                Icon(
                                  radius == null
                                      ? Icons.all_inclusive_rounded
                                      : Icons.radar_rounded,
                                  size: 14,
                                  color: isSelected
                                      ? Colors.teal
                                      : (isDark
                                          ? Colors.white60
                                          : Colors.grey.shade600),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.teal
                                          : (isDark
                                              ? Colors.white70
                                              : Colors.black87),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Colors.teal,
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
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
                                  final isSelected = loc.id == _selectedOpportunity?.id;
                                  final color = _markerColor(loc.subRoleSlug);
                                  final icon = _markerIcon(loc.subRoleSlug);
                                  final markerWidth = isMobile ? (isSelected ? 125.0 : 110.0) : (isSelected ? 150.0 : 135.0);
                                  final markerHeight = isMobile ? (isSelected ? 76.0 : 70.0) : (isSelected ? 86.0 : 78.0);

                                  return Marker(
                                    point: LatLng(
                                      loc.latitude!,
                                      loc.longitude!,
                                    ),
                                    width: markerWidth,
                                    height: markerHeight,
                                    alignment: Alignment.topCenter,
                                    child: _PeluangMapMarker(
                                      key: ValueKey(loc.id ?? '${loc.latitude}_${loc.longitude}'),
                                      loc: loc,
                                      isSelected: isSelected,
                                      isDark: isDark,
                                      isMobile: isMobile,
                                      color: color,
                                      icon: icon,
                                      onTap: () => _onMarkerTap(loc),
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

                      // ── Bottom Floating Card or Info Bar ───────────────────
                      Positioned(
                        bottom: isMobile ? 8 : 16,
                        left: isMobile ? 12 : 16,
                        right: isMobile ? 12 : 16,
                        child: _selectedOpportunity != null
                            ? _buildFloatingOpportunityCard(_selectedOpportunity!, isDark, isMobile)
                            : Container(
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
                                            ? 'Ketuk marker untuk lihat event & kebutuhannya'
                                            : 'Ketuk marker event untuk lihat detail peran & ajukan lamaran',
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
      {'slug': 'tukang_kendang', 'label': 'Tukang Kendang'},
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

class _PeluangMapMarker extends StatefulWidget {
  final OpportunityModel loc;
  final bool isSelected;
  final bool isDark;
  final bool isMobile;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _PeluangMapMarker({
    super.key,
    required this.loc,
    required this.isSelected,
    required this.isDark,
    required this.isMobile,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_PeluangMapMarker> createState() => _PeluangMapMarkerState();
}

class _PeluangMapMarkerState extends State<_PeluangMapMarker> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSel = widget.isSelected;
    final isHov = _isHovered;
    final pinColor = isSel ? const Color(0xFFF59E0B) : widget.color;
    final reqCount = widget.loc.requirements.length;

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (!_isHovered && mounted) setState(() => _isHovered = true);
        },
        onExit: (_) {
          if (_isHovered && mounted) setState(() => _isHovered = false);
        },
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            scale: isSel ? 1.15 : (isHov ? 1.08 : 1.0),
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Pin with gradient & custom icon
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Outer glow halo if selected
                    if (isSel)
                      Container(
                        width: widget.isMobile ? 38 : 44,
                        height: widget.isMobile ? 38 : 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: pinColor.withValues(alpha: 0.25),
                          boxShadow: [
                            BoxShadow(
                              color: pinColor.withValues(alpha: 0.6),
                              blurRadius: 16,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),

                    // Pin Head (circular with gradient)
                    Container(
                      width: widget.isMobile ? (isSel ? 34 : 30) : (isSel ? 38 : 34),
                      height: widget.isMobile ? (isSel ? 34 : 30) : (isSel ? 38 : 34),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            pinColor.withValues(alpha: 0.95),
                            pinColor,
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white,
                          width: isSel ? 2.5 : 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: pinColor.withValues(alpha: isSel ? 0.6 : 0.4),
                            blurRadius: isSel ? 12 : 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          widget.icon,
                          color: Colors.white,
                          size: widget.isMobile ? 15 : 17,
                        ),
                      ),
                    ),
                  ],
                ),

                // Pointer tip caret
                CustomPaint(
                  size: const Size(10, 5),
                  painter: _TrianglePainter(color: pinColor),
                ),
                const SizedBox(height: 1),

                // Bottom title capsule
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.isMobile ? 6 : 8,
                    vertical: widget.isMobile ? 2.5 : 3.5,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: widget.isMobile ? 105 : 135,
                  ),
                  decoration: BoxDecoration(
                    color: isSel
                        ? (widget.isDark ? const Color(0xFF2D1457) : const Color(0xFFEDE9FE))
                        : (widget.isDark
                            ? const Color(0xFF1E1E2E).withValues(alpha: 0.96)
                            : Colors.white.withValues(alpha: 0.96)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel
                          ? const Color(0xFF8B5CF6)
                          : (isHov
                              ? widget.color.withValues(alpha: 0.6)
                              : (widget.isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0))),
                      width: isSel ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isSel ? 0.25 : 0.12),
                        blurRadius: isSel ? 8 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.loc.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: widget.isMobile ? 8.5 : 9.5,
                          fontWeight: FontWeight.bold,
                          color: isSel
                              ? const Color(0xFF8B5CF6)
                              : (widget.isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      if (reqCount > 0 || widget.loc.location != null)
                        Text(
                          reqCount > 1
                              ? '$reqCount Posisi • ${widget.loc.location ?? ""}'
                              : (widget.loc.location ?? widget.loc.subRoleLabel),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: widget.isMobile ? 7 : 8,
                            fontWeight: FontWeight.w600,
                            color: isSel
                                ? const Color(0xFF8B5CF6)
                                : widget.color,
                          ),
                        ),
                    ],
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

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}
