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

  static Future<List<OpportunityModel>> getMyOpportunities() async {
    try {
      final result = await ApiService.get('opportunities/my');
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
    String? bannerUrl,
    String? location,
    double? latitude,
    double? longitude,
    String? locationCategory,
    String? address,
    String? deadline,
    String? eventDate,
    String? eventStartDate,
    String? eventEndDate,
    String? eventStartTime,
    String? eventEndTime,
    String? budgetRange,
    String? meetingDate,
    String? meetingTime,
    String? meetingLocation,
    double? meetingLat,
    double? meetingLng,
    String? meetingNotes,
    List<Map<String, dynamic>>? requirements,
    OpportunityPoster? poster,
  }) async {
    OpportunityModel? apiResult;
    String? errorMessage;

    try {
      final res = await ApiService.post('opportunities', {
        'title': title,
        'sub_role_slug': subRoleSlug,
        'type': type,
        'description': description,
        'poster_url': posterUrl,
        'banner_url': bannerUrl,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'location_category': locationCategory,
        'address': address,
        'deadline': deadline,
        'event_date': eventDate,
        'event_start_date': eventStartDate,
        'event_end_date': eventEndDate,
        'event_start_time': eventStartTime,
        'event_end_time': eventEndTime,
        'budget_range': budgetRange,
        if (meetingDate != null) 'meeting_date': meetingDate,
        if (meetingTime != null) 'meeting_time': meetingTime,
        if (meetingLocation != null) 'meeting_location': meetingLocation,
        if (meetingLat != null) 'meeting_lat': meetingLat,
        if (meetingLng != null) 'meeting_lng': meetingLng,
        if (meetingNotes != null) 'meeting_notes': meetingNotes,
        if (requirements != null) 'requirements': requirements,
      });

      if (res['status'] == true && res['data'] != null) {
        try {
          apiResult = OpportunityModel.fromJson(res['data']);
        } catch (_) {}
      } else if (res['message'] != null) {
        errorMessage = res['message'] as String;
      }
    } catch (e) {
      errorMessage =
          e is Map && e['message'] != null ? e['message'] as String : e.toString();
    }

    final newModel = apiResult ??
        OpportunityModel(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          description: description,
          posterUrl: posterUrl,
          bannerUrl: bannerUrl,
          subRoleSlug: subRoleSlug,
          type: type,
          location: location ?? 'Indonesia',
          latitude: latitude ?? -6.2088,
          longitude: longitude ?? 106.8456,
          locationCategory: locationCategory ?? 'urban',
          address: address,
          deadline: deadline,
          eventDate: eventDate,
          eventStartDate: eventStartDate,
          eventEndDate: eventEndDate,
          eventStartTime: eventStartTime,
          eventEndTime: eventEndTime,
          budgetRange: budgetRange,
          meetingDate: meetingDate,
          meetingTime: meetingTime,
          meetingLocation: meetingLocation,
          meetingLat: meetingLat,
          meetingLng: meetingLng,
          meetingNotes: meetingNotes,
          meetingStatus: (budgetRange != null && (budgetRange.contains('20.000.000') || budgetRange.contains('MoU')))
              ? 'pending_marketing_review'
              : 'not_required',
          escrowStatus: (budgetRange != null && (budgetRange.contains('20.000.000') || budgetRange.contains('MoU')))
              ? 'none'
              : 'pending_deposit',
          status: 'open',
          poster: poster,
        );

    if (apiResult == null) {
      await _loadLocalLocations();
      _userCreatedLocations.insert(0, newModel);
      await _saveLocalLocations();
    }

    return {
      'status': apiResult != null,
      'message': apiResult != null
          ? 'Peluang proyek berhasil dipublikasikan!'
          : (errorMessage ?? 'Gagal menyimpan ke server. Data tersimpan lokal sementara.'),
      'data': newModel,
      'is_local': apiResult == null,
    };
  }

  static Future<Map<String, dynamic>> startEvent(String opportunityId) async {
    try {
      final res = await ApiService.post('opportunities/$opportunityId/start-event', {});
      return {
        'status': res['status'] == true,
        'message': res['message'] ?? 'Acara resmi dimulai!',
        'data': res['data'] != null ? OpportunityModel.fromJson(res['data']) : null,
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> updateProgress(String opportunityId, int progress) async {
    try {
      final res = await ApiService.post('opportunities/$opportunityId/update-progress', {
        'progress': progress,
      });
      return {
        'status': res['status'] == true,
        'message': res['message'] ?? 'Progress acara berhasil diperbarui.',
        'data': res['data'] != null ? OpportunityModel.fromJson(res['data']) : null,
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> submitDocuments({
    required String applicationId,
    required List<Map<String, dynamic>> documents,
  }) async {
    try {
      final res = await ApiService.post('opportunities/applications/$applicationId/submit-documents', {
        'documents': documents,
      });
      return {
        'status': res['status'] == true,
        'message': res['message'] ?? 'Dokumen / link berhasil dikirimkan.',
        'data': res['data'],
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> scheduleMeeting({
    required String opportunityId,
    required String meetingDate,
    required String meetingTime,
    required String meetingLocation,
    double? meetingLat,
    double? meetingLng,
    String? meetingNotes,
  }) async {
    try {
      final res = await ApiService.post('opportunities/$opportunityId/schedule-meeting', {
        'meeting_date': meetingDate,
        'meeting_time': meetingTime,
        'meeting_location': meetingLocation,
        if (meetingLat != null) 'meeting_lat': meetingLat,
        if (meetingLng != null) 'meeting_lng': meetingLng,
        if (meetingNotes != null) 'meeting_notes': meetingNotes,
      });
      return {
        'status': res['status'] == true,
        'message': res['message'] ?? 'Jadwal pertemuan diajukan ke tim Marketing.',
        'data': res['data'] != null ? OpportunityModel.fromJson(res['data']) : null,
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> confirmOpportunityPayment({
    required String opportunityId,
    String? notes,
  }) async {
    try {
      final res = await ApiService.post('marketing/opportunities/$opportunityId/confirm-payment', {
        if (notes != null) 'notes': notes,
      });
      return {
        'status': res['status'] == true,
        'message': res['message'] ?? 'Dana dan MoU berhasil dikonfirmasi oleh Marketing.',
        'data': res['data'],
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<OpportunityModel?> getOpportunityById(String opportunityId) async {
    try {
      final res = await ApiService.get('opportunities/$opportunityId');
      if (res['data'] != null) {
        return OpportunityModel.fromJson(res['data']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
