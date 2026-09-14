import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/opportunity_model.dart';
import '../models/opportunity_application_model.dart';
import 'api_service.dart';

class OpportunityService {
  static final List<OpportunityModel> _userCreatedLocations = [];

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
    } catch (_) {}
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

  static Future<List<OpportunityModel>> getOpportunities({
    String subRole = 'all',
    List<String>? subRoles,
    String? type,
    int limit = 50,
    String? search,
    bool forceRefresh = false,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
    };

    if (subRoles != null && subRoles.isNotEmpty) {
      for (var i = 0; i < subRoles.length; i++) {
        queryParams['sub_roles[$i]'] = subRoles[i];
      }
    } else if (subRole != 'all') {
      queryParams['sub_role_slug'] = subRole;
    }

    if (type != null && type.isNotEmpty) {
      queryParams['type'] = type;
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    try {
      final result = await ApiService.get(
        'opportunities',
        queryParams: queryParams,
      );

      if (result['status'] == true && result['data'] != null) {
        final list = (result['data'] as List)
            .map((item) => OpportunityModel.fromJson(item))
            .toList();
        return list;
      }
    } catch (_) {}

    return [];
  }

  static Future<List<OpportunityModel>> getMapLocations({
    String subRole = 'all',
    double? lat,
    double? lng,
    double? radiusKm,
  }) async {
    await _loadLocalLocations();

    final queryParams = <String, String>{};
    if (subRole != 'all') {
      queryParams['sub_role_slug'] = subRole;
    }
    if (lat != null && lng != null) {
      queryParams['lat'] = lat.toString();
      queryParams['lng'] = lng.toString();
      if (radiusKm != null && radiusKm > 0) {
        queryParams['radius_km'] = radiusKm.toString();
      }
    }

    List<OpportunityModel> remoteList = [];
    try {
      final result = await ApiService.get(
        'opportunities/map',
        queryParams: queryParams,
      );

      if (result['status'] == true &&
          result['data'] != null &&
          (result['data'] as List).isNotEmpty) {
        remoteList = (result['data'] as List)
            .map((item) => OpportunityModel.fromJson(item))
            .toList();
      }
    } catch (_) {}

    final seenIds = <String>{};
    final combined = <OpportunityModel>[];

    for (final loc in remoteList) {
      if (loc.id != null && seenIds.add(loc.id!)) {
        combined.add(loc);
      }
    }
    for (final loc in _userCreatedLocations) {
      if (loc.id != null && seenIds.add(loc.id!)) {
        combined.add(loc);
      }
    }

    if (subRole != 'all') {
      return combined.where((o) => o.subRoleSlug == subRole).toList();
    }
    return combined;
  }

  static Future<OpportunityModel?> getDetail(String id) async {
    try {
      final result = await ApiService.get('opportunities/$id');
      if (result['status'] == true && result['data'] != null) {
        return OpportunityModel.fromJson(result['data']);
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>> applyToOpportunity({
    required String opportunityId,
    required String subRoleSlug,
    required String pitchMessage,
    String? questionsNotes,
    double? bidPrice,
  }) async {
    try {
      final payload = <String, dynamic>{
        'sub_role_slug': subRoleSlug,
        'pitch_message': pitchMessage,
      };
      if (questionsNotes != null && questionsNotes.isNotEmpty) {
        payload['questions_notes'] = questionsNotes;
      }
      if (bidPrice != null) {
        payload['bid_price'] = bidPrice;
      }

      final response = await ApiService.post(
        'opportunities/$opportunityId/applications',
        payload,
      );

      return {
        'status': response['status'] == true,
        'message': response['message'] ?? 'Lamaran berhasil dikirim.',
        'data': response['data'],
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<List<OpportunityApplicationModel>> getOpportunityApplications(
    String opportunityId,
  ) async {
    try {
      final response = await ApiService.get(
        'opportunities/$opportunityId/applications',
      );

      if (response['status'] == true && response['data'] is List) {
        return (response['data'] as List)
            .map((item) => OpportunityApplicationModel.fromJson(item))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> reviewApplication({
    required String applicationId,
    required String decision, // 'approve' or 'reject'
    String? reason,
  }) async {
    try {
      final endpoint = decision == 'approve'
          ? 'opportunities/applications/$applicationId/approve'
          : 'opportunities/applications/$applicationId/reject';

      final response = await ApiService.post(endpoint, {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

      return {
        'status': response['status'] == true,
        'message': response['message'] ?? 'Status lamaran berhasil diperbarui.',
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
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
    String? posterUrl,
    String? location,
    double? latitude,
    double? longitude,
    String? locationCategory,
    String? address,
    String? deadline,
    String? eventDate,
    String? eventStartTime,
    String? eventEndTime,
    String? budgetRange,
    List<Map<String, dynamic>>? requirements,
    OpportunityPoster? poster,
  }) async {
    try {
      final res = await ApiService.post('opportunities', {
        'title': title,
        'sub_role_slug': subRoleSlug,
        'type': type,
        'description': description,
        'poster_url': posterUrl,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'location_category': locationCategory,
        'address': address,
        'deadline': deadline,
        'event_date': eventDate,
        'event_start_time': eventStartTime,
        'event_end_time': eventEndTime,
        'budget_range': budgetRange,
        if (requirements != null) 'requirements': requirements,
      });

      if (res['status'] == true && res['data'] != null) {
        return {
          'status': true,
          'message': 'Peluang proyek berhasil dipublikasikan!',
          'data': OpportunityModel.fromJson(res['data']),
        };
      }
    } catch (_) {}

    final newModel = OpportunityModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      posterUrl: posterUrl,
      subRoleSlug: subRoleSlug,
      type: type,
      location: location ?? 'Indonesia',
      latitude: latitude ?? -6.2088,
      longitude: longitude ?? 106.8456,
      locationCategory: locationCategory ?? 'urban',
      address: address,
      deadline: deadline,
      eventDate: eventDate,
      eventStartTime: eventStartTime,
      eventEndTime: eventEndTime,
      budgetRange: budgetRange,
      status: 'open',
      poster: poster,
    );

    await _loadLocalLocations();
    _userCreatedLocations.insert(0, newModel);
    await _saveLocalLocations();

    return {
      'status': true,
      'message': 'Peluang proyek berhasil disimpan!',
      'data': newModel,
    };
  }
}
