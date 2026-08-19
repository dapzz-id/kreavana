import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/opportunity_model.dart';
import 'api_service.dart';

class OpportunityService {
  static final List<OpportunityModel> _userCreatedLocations = [];

  /// Load user-created locations from SharedPreferences (localStorage on web).
  /// This data is shared across ALL users on the same browser/origin.
  static Future<void> _loadLocalLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user_created_map_locations');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List && decoded.isNotEmpty) {
          _userCreatedLocations.clear();
          for (final item in decoded) {
            try {
              _userCreatedLocations.add(OpportunityModel.fromJson(item));
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      // ignore but don't lose existing in-memory data
    }
  }

  static Future<void> _saveLocalLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedList = _userCreatedLocations
          .map((item) => item.toJson())
          .toList();
      await prefs.setString(
        'user_created_map_locations',
        jsonEncode(encodedList),
      );
    } catch (_) {}
  }

  static DateTime? _lastFetchTime;
  static List<OpportunityModel>? _cachedOpportunities;
  static String _lastSubRole = '';
  static String? _lastType;

  static Future<List<OpportunityModel>> getOpportunities({
    String subRole = 'all',
    String? type,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    // 2-minute TTL cache
    if (!forceRefresh && _cachedOpportunities != null && _lastFetchTime != null) {
      if (subRole == _lastSubRole && type == _lastType) {
        if (DateTime.now().difference(_lastFetchTime!).inMinutes < 2) {
          return _cachedOpportunities!;
        }
      }
    }

    final queryParams = <String, String>{
      'sub_role_slug': subRole,
      'limit': limit.toString(),
    };
    if (type != null && type.isNotEmpty) {
      queryParams['type'] = type;
    }

    final result = await ApiService.get(
      'opportunities',
      queryParams: queryParams,
    );

    if (result['status'] == true && result['data'] != null) {
      final list = (result['data'] as List)
          .map((item) => OpportunityModel.fromJson(item))
          .toList();
      if (list.isNotEmpty) {
        _cachedOpportunities = list;
        _lastFetchTime = DateTime.now();
        _lastSubRole = subRole;
        _lastType = type;
        return list;
      }
    }

    return [];
  }

  static Future<List<OpportunityModel>> getMapLocations({
    String subRole = 'all',
  }) async {
    // Always reload from disk to pick up locations created by other sessions
    await _loadLocalLocations();

    List<OpportunityModel> remoteList = [];
    try {
      final result = await ApiService.get(
        'opportunities/map',
        queryParams: {'sub_role_slug': subRole},
      );

      if (result['status'] == true &&
          result['data'] != null &&
          (result['data'] as List).isNotEmpty) {
        remoteList = (result['data'] as List)
            .map((item) => OpportunityModel.fromJson(item))
            .toList();
      }
    } catch (_) {}

    // Always include fallback dummy data
    final List<OpportunityModel> fallbackList = [];

    // Merge: user-created first, then remote, then fallback (deduplicate by id)
    final seenIds = <String>{};
    final combined = <OpportunityModel>[];

    for (final loc in _userCreatedLocations) {
      if (loc.id != null && seenIds.add(loc.id!)) {
        combined.add(loc);
      }
    }
    for (final loc in remoteList) {
      if (loc.id != null && seenIds.add(loc.id!)) {
        combined.add(loc);
      }
    }
    for (final loc in fallbackList) {
      if (loc.id != null && seenIds.add(loc.id!)) {
        combined.add(loc);
      }
    }

    if (subRole != 'all') {
      final filtered = combined.where((o) => o.subRoleSlug == subRole).toList();
      return filtered;
    }
    return combined;
  }

  static Future<OpportunityModel?> getDetail(String id) async {
    final result = await ApiService.get('opportunities/$id');

    if (result['status'] == true && result['data'] != null) {
      return OpportunityModel.fromJson(result['data']);
    }
    return null;
  }

  static Future<Map<String, dynamic>> submitReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? description,
  }) async {
    final response = await ApiService.post('opportunities/report', {
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      'description': description,
    });

    return {
      'status': response['status'] == true,
      'message': response['message'] ?? 'Gagal mengirim laporan.',
    };
  }

  static Future<Map<String, dynamic>> createOpportunity({
    required String title,
    required String subRoleSlug,
    required String type,
    String? description,
    String? location,
    double? latitude,
    double? longitude,
    String? locationCategory,
    String? address,
    String? deadline,
    String? budgetRange,
    OpportunityPoster? poster,
  }) async {
    try {
      await ApiService.post('opportunities', {
        'title': title,
        'sub_role_slug': subRoleSlug,
        'type': type,
        'description': description,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'location_category': locationCategory,
        'address': address,
        'deadline': deadline,
        'budget_range': budgetRange,
      });
    } catch (_) {}

    final newModel = OpportunityModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      subRoleSlug: subRoleSlug,
      type: type,
      location: location ?? 'Indonesia',
      latitude: latitude ?? -6.2088,
      longitude: longitude ?? 106.8456,
      locationCategory: locationCategory ?? 'urban',
      address: address,
      deadline: deadline,
      budgetRange: budgetRange,
      status: 'open',
      poster:
          poster ??
          OpportunityPoster(
            id: '2',
            name: 'Kreator Kreavana',
            username: 'kreator_demo',
            phone: '081299998888',
          ),
    );

    await _loadLocalLocations();
    _userCreatedLocations.insert(0, newModel);
    await _saveLocalLocations();

    return {
      'status': true,
      'message': 'Lokasi kolaborasi berhasil ditambahkan!',
      'data': newModel,
    };
  }
}
