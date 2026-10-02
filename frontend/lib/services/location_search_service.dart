import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dio_client.dart';

class LocationSearchResult {
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;
  final String source; // 'google_places', 'photon', 'nominatim', etc.

  LocationSearchResult({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    required this.source,
  });

  bool get isGoogle => source == 'google_places' || source == 'google_geocoding';
}

class LocationSearchService {
  static final LocationSearchService instance = LocationSearchService._();
  LocationSearchService._();

  /// Search locations via Backend (Google Places API with OSM/Photon fallback)
  Future<List<LocationSearchResult>> search(String query, {String? city}) async {
    final clean = query.trim();
    if (clean.length < 2) return [];

    // 1. Try backend endpoint first (Google Places or Server OSM)
    try {
      final res = await DioClient.instance.dio.get(
        '/locations/search',
        queryParameters: {
          'q': clean,
          if (city != null && city.isNotEmpty) 'city': city,
        },
      );

      if (res.statusCode == 200 && res.data is Map) {
        final list = res.data['data'] as List?;
        final defaultSource = res.data['source'] as String? ?? 'unknown';

        if (list != null && list.isNotEmpty) {
          return list.map((item) {
            return LocationSearchResult(
              title: item['title']?.toString() ?? clean,
              subtitle: item['subtitle']?.toString() ?? '',
              latitude: double.tryParse(item['latitude']?.toString() ?? '') ?? 0.0,
              longitude: double.tryParse(item['longitude']?.toString() ?? '') ?? 0.0,
              source: item['source']?.toString() ?? defaultSource,
            );
          }).where((r) => r.latitude != 0.0 && r.longitude != 0.0).toList();
        }
      }
    } catch (_) {
      // Backend unreachable or network error, proceed to direct client fallback
    }

    // 2. Direct client fallback (Photon Komoot API)
    final fallbackList = <LocationSearchResult>[];
    final seen = <String>{};

    try {
      final photonQuery = city != null && !clean.toLowerCase().contains(city.toLowerCase())
          ? '$clean, $city'
          : clean;

      final photonUri = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(photonQuery)}&limit=8',
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
            final name = (props['name'] ?? props['street'] ?? clean) as String;

            final parts = <String>[];
            if (props['street'] != null && props['street'] != name) parts.add(props['street'].toString());
            if (props['district'] != null) parts.add(props['district'].toString());
            if (props['city'] != null) parts.add(props['city'].toString());
            if (props['state'] != null) parts.add(props['state'].toString());
            if (props['country'] != null) parts.add(props['country'].toString());
            final subtitle = parts.join(', ');

            final key = '${lat.toStringAsFixed(4)}_${lon.toStringAsFixed(4)}';
            if (!seen.contains(key)) {
              seen.add(key);
              fallbackList.add(LocationSearchResult(
                title: name,
                subtitle: subtitle.isNotEmpty ? subtitle : name,
                latitude: lat,
                longitude: lon,
                source: 'photon',
              ));
            }
          }
        }
      }
    } catch (_) {
      // Ignore
    }

    return fallbackList;
  }

  /// Reverse geocode coordinates to readable address text
  Future<String?> reverseGeocode(double lat, double lng) async {
    // 1. Try backend (Google Geocoding or OSM)
    try {
      final res = await DioClient.instance.dio.get(
        '/locations/reverse',
        queryParameters: {
          'lat': lat,
          'lng': lng,
        },
      );

      if (res.statusCode == 200 && res.data is Map) {
        final address = res.data['address'] as String?;
        if (address != null && address.isNotEmpty) {
          return address;
        }
      }
    } catch (_) {
      // Backend unreachable, fallback to direct Nominatim
    }

    // 2. Direct Nominatim fallback
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'Kreavana-App/1.0 (contact@kreavana.com)',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] as String?;
      }
    } catch (_) {
      // Ignore
    }

    return null;
  }
}
