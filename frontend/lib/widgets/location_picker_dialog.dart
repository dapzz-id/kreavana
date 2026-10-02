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

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  late LatLng _currentPoint;
  String _addressText = '';
  bool _isSearching = false;
  bool _isGeocoding = false;
  bool _isLocatingGps = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _searchDebounce;

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
      // Fallback: keep previous or use coordinates
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => _searchResults = []);
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearching = true);
      try {
        final fullQuery = widget.cityName != null && !query.toLowerCase().contains(widget.cityName!.toLowerCase())
            ? '$query, ${widget.cityName}'
            : query;

        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(fullQuery)}&format=json&countrycodes=id&limit=5',
        );
        final response = await http.get(url, headers: {
          'User-Agent': 'Kreavana-App/1.0 (contact@kreavana.id)',
        }).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200 && mounted) {
          final list = List<Map<String, dynamic>>.from(json.decode(response.body));
          setState(() {
            _searchResults = list;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _searchResults = []);
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  void _selectSearchResult(Map<String, dynamic> item) {
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lon = double.tryParse(item['lon']?.toString() ?? '');
    final name = item['display_name'] as String?;

    if (lat != null && lon != null) {
      final point = LatLng(lat, lon);
      setState(() {
        _currentPoint = point;
        _addressText = name ?? '';
        _searchResults = [];
        _searchController.clear();
      });
      _mapController.move(point, 16.0);
    }
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
          });
          _mapController.move(point, 16.0);
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
    });
    _reverseGeocode(point);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width > 700 ? 680.0 : size.width * 0.94;
    final dialogHeight = size.height > 800 ? 620.0 : size.height * 0.85;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF14121F) : Colors.white,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pin_drop_rounded, color: Color(0xFF0891B2), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tandai Titik Lokasi Tempat Acara',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          'Ketuk peta atau cari lokasi gedung/jalan tempat acara akan berlangsung',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Batal',
                  ),
                ],
              ),
            ),

            // ── Search & Map Stack ──
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
                                      color: Colors.black38,
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

                  // Floating Search Box
                  Positioned(
                    top: 12,
                    left: 14,
                    right: 14,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: 'Cari gedung, tempat, hotel, atau nama jalan...',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white38 : Colors.grey.shade400,
                              ),
                              prefixIcon: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : const Icon(Icons.search_rounded, size: 20),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchResults = []);
                                      },
                                    )
                                  : null,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: InputBorder.none,
                            ),
                          ),
                        ),

                        // Search Results Dropdown List
                        if (_searchResults.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final item = _searchResults[idx];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.place_outlined, size: 18, color: Color(0xFF06B6D4)),
                                  title: Text(
                                    item['display_name'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onTap: () => _selectSearchResult(item),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Floating Map Action Buttons
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
                          tooltip: 'Lokasi Saya',
                          child: _isLocatingGps
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
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
                      const Icon(Icons.location_on, color: Color(0xFFE11D48), size: 20),
                      const SizedBox(width: 8),
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
                              'Lat: ${_currentPoint.latitude.toStringAsFixed(6)} • Lng: ${_currentPoint.longitude.toStringAsFixed(6)} ${_isGeocoding ? "(Mengambil alamat...)" : ""}',
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
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
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
                        icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
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
