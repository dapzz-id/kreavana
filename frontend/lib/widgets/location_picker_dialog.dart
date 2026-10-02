import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../app/theme.dart';

class LocationPickResult {
  final double latitude;
  final double longitude;
  final String? address;
  final String? displayName;

  const LocationPickResult({
    required this.latitude,
    required this.longitude,
    this.address,
    this.displayName,
  });
}

class LocationPickerDialog extends StatefulWidget {
  final LatLng? initialLocation;
  final String? initialAddress;
  final String? cityName;

  const LocationPickerDialog({
    super.key,
    this.initialLocation,
    this.initialAddress,
    this.cityName,
  });

  static Future<LocationPickResult?> show(
    BuildContext context, {
    LatLng? initialLocation,
    String? initialAddress,
    String? cityName,
  }) {
    return showDialog<LocationPickResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LocationPickerDialog(
        initialLocation: initialLocation,
        initialAddress: initialAddress,
        cityName: cityName,
      ),
    );
  }

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationSearchResult {
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;

  _LocationSearchResult({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  late LatLng _currentPoint;
  String _addressText = '';
  bool _isSearching = false;
  bool _isGeocoding = false;
  bool _isLocatingGps = false;
  bool _searchNotFound = false;
  String _lastSearchedText = '';
  List<_LocationSearchResult> _searchResults = [];
  Timer? _searchDebounce;

  static const Map<String, List<Map<String, dynamic>>> _cityHotspots = {
    'Jakarta': [
      {'name': 'Senayan / GBK', 'lat': -6.2185, 'lng': 106.8026},
      {'name': 'SCBD Sudirman', 'lat': -6.2244, 'lng': 106.8094},
      {'name': 'Monas / Gambir', 'lat': -6.1754, 'lng': 106.8272},
      {'name': 'Kemang', 'lat': -6.2625, 'lng': 106.8156},
      {'name': 'Kelapa Gading', 'lat': -6.1583, 'lng': 106.9083},
      {'name': 'PIK (Pantai Indah Kapuk)', 'lat': -6.1089, 'lng': 106.7417},
      {'name': 'Kuningan / Mega Kuningan', 'lat': -6.2289, 'lng': 106.8294},
    ],
    'Bandung': [
      {'name': 'Gedung Sate', 'lat': -6.9025, 'lng': 107.6186},
      {'name': 'Braga / Asia Afrika', 'lat': -6.9189, 'lng': 107.6097},
      {'name': 'Dago', 'lat': -6.8856, 'lng': 107.6133},
      {'name': 'Buah Batu', 'lat': -6.9536, 'lng': 107.6364},
    ],
    'Surabaya': [
      {'name': 'Tunjungan Plaza', 'lat': -7.2625, 'lng': 112.7389},
      {'name': 'Gubeng', 'lat': -7.2658, 'lng': 112.7533},
      {'name': 'Pakuwon Mall', 'lat': -7.2908, 'lng': 112.6756},
    ],
    'Yogyakarta': [
      {'name': 'Malioboro', 'lat': -7.7928, 'lng': 110.3658},
      {'name': 'Tugu Jogja', 'lat': -7.7828, 'lng': 110.3672},
      {'name': 'UGM / Sleman', 'lat': -7.7708, 'lng': 110.3778},
    ],
    'Bali / Denpasar': [
      {'name': 'Kuta', 'lat': -8.7185, 'lng': 115.1689},
      {'name': 'Seminyak', 'lat': -8.6894, 'lng': 115.1558},
      {'name': 'Sanur', 'lat': -8.6833, 'lng': 115.2625},
      {'name': 'Denpasar Kota', 'lat': -8.6705, 'lng': 115.2126},
    ],
  };

  @override
  void initState() {
    super.initState();
    _currentPoint = widget.initialLocation ?? const LatLng(-6.2088, 106.8456); // Default Jakarta
    _addressText = widget.initialAddress ?? '';

    if (_addressText.isEmpty) {
      _reverseGeocode(_currentPoint);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isGeocoding = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'Kreavana-App/1.0 (contact@kreavana.id)',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] as String?;
        if (displayName != null && mounted) {
          setState(() {
            _addressText = displayName;
          });
        }
      }
    } catch (_) {
      // Fallback
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    final clean = query.trim();
    if (clean.length < 3) {
      setState(() {
        _searchResults = [];
        _searchNotFound = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 600), () {
      _executeSearch(clean);
    });
  }

  Future<void> _executeSearch(String query) async {
    _searchDebounce?.cancel();
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    FocusScope.of(context).unfocus();

    // 1. Check if user typed coordinates like "-6.2088, 106.8456"
    final coordRegex = RegExp(r'^(-?\d+(?:\.\d+)?)[,\s]+(-?\d+(?:\.\d+)?)$');
    final match = coordRegex.firstMatch(cleanQuery);
    if (match != null) {
      final lat = double.tryParse(match.group(1)!);
      final lon = double.tryParse(match.group(2)!);
      if (lat != null && lon != null) {
        final point = LatLng(lat, lon);
        setState(() {
          _currentPoint = point;
          _searchResults = [];
          _searchNotFound = false;
        });
        _mapController.move(point, 16.0);
        _reverseGeocode(point);
        return;
      }
    }

    setState(() {
      _isSearching = true;
      _searchNotFound = false;
      _lastSearchedText = cleanQuery;
    });

    final List<_LocationSearchResult> combinedResults = [];
    final seenKeys = <String>{};

    try {
      // Step A: Search with Photon API (Fast OSM-based search by Komoot)
      final photonQuery = widget.cityName != null && !cleanQuery.toLowerCase().contains(widget.cityName!.toLowerCase())
          ? '$cleanQuery, ${widget.cityName}'
          : cleanQuery;

      final photonUri = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(photonQuery)}&limit=6',
      );
      final photonRes = await http.get(photonUri).timeout(const Duration(seconds: 4));

      if (photonRes.statusCode == 200) {
        final data = json.decode(utf8.decode(photonRes.bodyBytes));
        final features = (data['features'] as List?) ?? [];
        for (final f in features) {
          final props = f['properties'] as Map<String, dynamic>? ?? {};
          final geom = f['geometry'] as Map<String, dynamic>? ?? {};
          final coords = (geom['coordinates'] as List?) ?? [];
          if (coords.length >= 2) {
            final lon = (coords[0] as num).toDouble();
            final lat = (coords[1] as num).toDouble();
            final name = (props['name'] ?? props['street'] ?? cleanQuery) as String;
            final parts = <String>[];
            if (props['street'] != null && props['street'] != name) parts.add(props['street'].toString());
            if (props['district'] != null) parts.add(props['district'].toString());
            if (props['city'] != null) parts.add(props['city'].toString());
            if (props['state'] != null) parts.add(props['state'].toString());
            if (props['country'] != null) parts.add(props['country'].toString());
            final subtitle = parts.join(', ');

            final key = '${lat.toStringAsFixed(4)}_${lon.toStringAsFixed(4)}';
            if (!seenKeys.contains(key)) {
              seenKeys.add(key);
              combinedResults.add(_LocationSearchResult(
                title: name,
                subtitle: subtitle.isNotEmpty ? subtitle : name,
                latitude: lat,
                longitude: lon,
              ));
            }
          }
        }
      }

      // Step B: Search with Nominatim if Photon yielded few results
      if (combinedResults.length < 3) {
        final nominatimUri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cleanQuery)}&format=json&countrycodes=id&limit=6',
        );
        final nomRes = await http.get(nominatimUri, headers: {
          'User-Agent': 'Kreavana-App/1.0 (contact@kreavana.id)',
        }).timeout(const Duration(seconds: 4));

        if (nomRes.statusCode == 200) {
          final list = List<Map<String, dynamic>>.from(json.decode(nomRes.body));
          for (final item in list) {
            final lat = double.tryParse(item['lat']?.toString() ?? '');
            final lon = double.tryParse(item['lon']?.toString() ?? '');
            final displayName = (item['display_name'] ?? '') as String;
            if (lat != null && lon != null && displayName.isNotEmpty) {
              final key = '${lat.toStringAsFixed(4)}_${lon.toStringAsFixed(4)}';
              if (!seenKeys.contains(key)) {
                seenKeys.add(key);
                final commaIdx = displayName.indexOf(',');
                final title = commaIdx != -1 ? displayName.substring(0, commaIdx) : displayName;
                final subtitle = commaIdx != -1 ? displayName.substring(commaIdx + 1).trim() : displayName;
                combinedResults.add(_LocationSearchResult(
                  title: title,
                  subtitle: subtitle,
                  latitude: lat,
                  longitude: lon,
                ));
              }
            }
          }
        }
      }
    } catch (_) {
      // Network or timeout error
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = combinedResults;
          _searchNotFound = combinedResults.isEmpty;
        });
      }
    }
  }

  void _selectSearchResult(_LocationSearchResult result) {
    final point = LatLng(result.latitude, result.longitude);
    setState(() {
      _currentPoint = point;
      _addressText = '${result.title}, ${result.subtitle}';
      _searchResults = [];
      _searchNotFound = false;
      _searchController.text = result.title;
    });
    _mapController.move(point, 16.5);
  }

  void _jumpToHotspot(double lat, double lng, String name) {
    final point = LatLng(lat, lng);
    setState(() {
      _currentPoint = point;
      _searchResults = [];
      _searchNotFound = false;
    });
    _mapController.move(point, 15.5);
    _reverseGeocode(point);
  }

  Future<void> _detectCurrentGpsLocation() async {
    setState(() => _isLocatingGps = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(timeLimit: Duration(seconds: 5)),
        );
        final point = LatLng(pos.latitude, pos.longitude);
        if (mounted) {
          setState(() {
            _currentPoint = point;
            _searchResults = [];
            _searchNotFound = false;
          });
          _mapController.move(point, 16.5);
          _reverseGeocode(point);
        }
      }
    } catch (_) {
      // Ignored
    } finally {
      if (mounted) setState(() => _isLocatingGps = false);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _currentPoint = point;
      _searchResults = [];
      _searchNotFound = false;
    });
    _reverseGeocode(point);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width > 760 ? 720.0 : size.width * 0.95;
    final dialogHeight = size.height > 850 ? 680.0 : size.height * 0.88;

    final currentCityHotspots = _cityHotspots[widget.cityName] ?? _cityHotspots['Jakarta'] ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF14121F) : Colors.white,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B192A) : const Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0891B2).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pin_drop_rounded, color: Color(0xFF0891B2), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Pilih & Tandai Titik Lokasi Acara',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                            ),
                            if (widget.cityName != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0891B2).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.cityName!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF0891B2),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ketik nama tempat/gedung lalu klik "Cari", atau ketuk langsung di peta.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 22),
                    tooltip: 'Tutup',
                  ),
                ],
              ),
            ),

            // ── Search Bar & Map Stack ──
            Expanded(
              child: Stack(
                children: [
                  // Map View
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentPoint,
                      initialZoom: 15.0,
                      minZoom: 4,
                      maxZoom: 18,
                      onTap: _onMapTap,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.kreavana.app',
                        maxNativeZoom: 19,
                        maxZoom: 18,
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentPoint,
                            width: 60,
                            height: 60,
                            alignment: Alignment.topCenter,
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  color: Color(0xFFE11D48),
                                  size: 42,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black45,
                                      blurRadius: 10,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Floating Search Box & Results Container
                  Positioned(
                    top: 12,
                    left: 14,
                    right: 14,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Search Input Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: isDark ? const Color(0xFF2D2A45) : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 10, right: 8),
                                child: _isSearching
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF0891B2)),
                                      )
                                    : const Icon(Icons.search_rounded, size: 22, color: Color(0xFF0891B2)),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: _onSearchChanged,
                                  onSubmitted: _executeSearch,
                                  textInputAction: TextInputAction.search,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Cari gedung, mall, hotel, nama jalan, atau koordinat...',
                                    hintStyle: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchResults = [];
                                      _searchNotFound = false;
                                    });
                                  },
                                  tooltip: 'Hapus Teks',
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  padding: EdgeInsets.zero,
                                ),
                              const SizedBox(width: 4),
                              // Dedicated Prominent "Cari" Button
                              ElevatedButton(
                                onPressed: _isSearching
                                    ? null
                                    : () => _executeSearch(_searchController.text),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0891B2),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.search_rounded, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Cari',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Search Results Dropdown List
                        if (_searchResults.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            constraints: const BoxConstraints(maxHeight: 220),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.22),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              border: Border.all(
                                color: isDark ? const Color(0xFF2D2A45) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                              ),
                              itemBuilder: (context, idx) {
                                final item = _searchResults[idx];
                                return ListTile(
                                  dense: true,
                                  leading: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0891B2).withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.place_rounded, size: 18, color: Color(0xFF0891B2)),
                                  ),
                                  title: Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    item.subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                                    ),
                                  ),
                                  onTap: () => _selectSearchResult(item),
                                );
                              },
                            ),
                          ),

                        // Search Not Found Feedback Banner
                        if (_searchNotFound && _searchResults.isEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2D1820) : const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFF43F5E).withValues(alpha: 0.4),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.search_off_rounded, color: Color(0xFFF43F5E), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tidak ditemukan hasil untuk "$_lastSearchedText"',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                          color: Color(0xFFE11D48),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Coba cari nama jalan, distrik, atau gedung terdekat. Anda juga bisa langsung mengetuk titik pada peta.',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                  onPressed: () => setState(() => _searchNotFound = false),
                                ),
                              ],
                            ),
                          ),

                        // Quick Hotspots / Area Suggestions (Visible when not actively searching)
                        if (_searchResults.isEmpty && !_searchNotFound && currentCityHotspots.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            height: 32,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: currentCityHotspots.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 6),
                              itemBuilder: (context, idx) {
                                final spot = currentCityHotspots[idx];
                                return InkWell(
                                  onTap: () => _jumpToHotspot(
                                    spot['lat'] as double,
                                    spot['lng'] as double,
                                    spot['name'] as String,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E1B2E).withValues(alpha: 0.9)
                                          : Colors.white.withValues(alpha: 0.95),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF2D2A45) : const Color(0xFFCBD5E1),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.near_me_rounded, size: 12, color: Color(0xFF0891B2)),
                                        const SizedBox(width: 4),
                                        Text(
                                          spot['name'] as String,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white70 : Colors.grey.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Floating Map Action Buttons (Right Bottom)
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // GPS Button
                        FloatingActionButton.small(
                          heroTag: 'gps_btn_picker',
                          backgroundColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                          foregroundColor: const Color(0xFF0891B2),
                          onPressed: _isLocatingGps ? null : _detectCurrentGpsLocation,
                          tooltip: 'Lokasi Saya Saat Ini',
                          child: _isLocatingGps
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0891B2)),
                                )
                              : const Icon(Icons.my_location_rounded, size: 20),
                        ),
                        const SizedBox(height: 8),
                        // Zoom in
                        FloatingActionButton.small(
                          heroTag: 'zoom_in_picker',
                          backgroundColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                          foregroundColor: isDark ? Colors.white : Colors.black87,
                          onPressed: () {
                            _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
                          },
                          tooltip: 'Perbesar',
                          child: const Icon(Icons.add, size: 20),
                        ),
                        const SizedBox(height: 6),
                        // Zoom out
                        FloatingActionButton.small(
                          heroTag: 'zoom_out_picker',
                          backgroundColor: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                          foregroundColor: isDark ? Colors.white : Colors.black87,
                          onPressed: () {
                            _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
                          },
                          tooltip: 'Perkecil',
                          child: const Icon(Icons.remove, size: 20),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Footer Selected Point Info & Actions ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B192A) : const Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on_rounded, color: Color(0xFFE11D48), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _addressText.isNotEmpty
                                  ? _addressText
                                  : 'Koordinat: ${_currentPoint.latitude.toStringAsFixed(5)}, ${_currentPoint.longitude.toStringAsFixed(5)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Koordinat: ${_currentPoint.latitude.toStringAsFixed(6)}, ${_currentPoint.longitude.toStringAsFixed(6)} ${_isGeocoding ? "• (Mengambil nama alamat...)" : ""}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Batal'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0891B2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(
                            LocationPickResult(
                              latitude: _currentPoint.latitude,
                              longitude: _currentPoint.longitude,
                              address: _addressText,
                              displayName: _addressText,
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                        label: const Text(
                          'Gunakan Titik Lokasi Ini',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
