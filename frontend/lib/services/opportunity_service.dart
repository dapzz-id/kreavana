import 'package:flutter/foundation.dart';
import '../models/opportunity_model.dart';
import '../models/opportunity_application_model.dart';
import '../models/job_contract.dart';
import 'api_service.dart';

class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  _CacheEntry(this.data) : timestamp = DateTime.now();

  bool isFresh(Duration maxAge) => DateTime.now().difference(timestamp) < maxAge;
}

class OpportunityService {
  // ── In-Memory Read Cache ────────────────────────────────────────────────────
  // Cache HANYA digunakan setelah data berhasil diterima dari database server,
  // untuk mengurangi beban server pada pemanggilan GET berulang.
  // Tidak ada data palsu atau mutasi lokal yang disimpan di sini.
  static final Map<String, _CacheEntry<List<OpportunityModel>>> _opportunitiesCache = {};
  static _CacheEntry<List<OpportunityModel>>? _myOpportunitiesCache;
  static final Map<String, _CacheEntry<List<OpportunityModel>>> _mapLocationsCache = {};
  static final Map<String, _CacheEntry<OpportunityModel>> _detailCache = {};

  static const Duration _cacheDuration = Duration(seconds: 45);

  /// Menghapus seluruh cache memori saat terjadi mutasi data (create, update, delete)
  /// agar pembacaan berikutnya langsung mengambil data terbaru dari database server.
  static void clearCache() {
    _opportunitiesCache.clear();
    _myOpportunitiesCache = null;
    _mapLocationsCache.clear();
    _detailCache.clear();
  }

  static Future<List<OpportunityModel>> getOpportunities({
    String subRole = 'all',
    List<String>? subRoles,
    String? type,
    int limit = 50,
    String? search,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'opps_${subRole}_${subRoles?.join(",")}_${type}_${limit}_${search}';
    if (!forceRefresh && _opportunitiesCache.containsKey(cacheKey)) {
      final entry = _opportunitiesCache[cacheKey]!;
      if (entry.isFresh(_cacheDuration)) {
        return entry.data;
      }
    }

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
        // Simpan ke cache hanya setelah menerima respons valid dari database
        _opportunitiesCache[cacheKey] = _CacheEntry(list);
        return list;
      }
    } catch (_) {}

    return [];
  }

  static Future<List<OpportunityModel>> getMyOpportunities({bool forceRefresh = false}) async {
    if (!forceRefresh && _myOpportunitiesCache != null && _myOpportunitiesCache!.isFresh(_cacheDuration)) {
      return _myOpportunitiesCache!.data;
    }

    try {
      final result = await ApiService.get('opportunities/my');
      if (result['status'] == true && result['data'] != null) {
        final list = <OpportunityModel>[];
        for (final item in (result['data'] as List)) {
          try {
            if (item is Map<String, dynamic>) {
              list.add(OpportunityModel.fromJson(item));
            } else if (item is Map) {
              list.add(OpportunityModel.fromJson(Map<String, dynamic>.from(item)));
            }
          } catch (e) {
            debugPrint('Error parsing OpportunityModel item: $e');
          }
        }
        _myOpportunitiesCache = _CacheEntry(list);
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
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'map_${subRole}_${lat}_${lng}_${radiusKm}';
    if (!forceRefresh && _mapLocationsCache.containsKey(cacheKey)) {
      final entry = _mapLocationsCache[cacheKey]!;
      if (entry.isFresh(_cacheDuration)) {
        return entry.data;
      }
    }

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

    try {
      final result = await ApiService.get(
        'opportunities/map',
        queryParams: queryParams,
      );

      if (result['status'] == true &&
          result['data'] != null &&
          (result['data'] as List).isNotEmpty) {
        final list = (result['data'] as List)
            .map((item) => OpportunityModel.fromJson(item))
            .toList();
        _mapLocationsCache[cacheKey] = _CacheEntry(list);
        return list;
      }
    } catch (_) {}

    return [];
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
    } catch (e) {
      debugPrint('Error getOpportunityApplications: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>> reviewApplication({
    required String applicationId,
    required String decision, // 'approve', 'reject', or 'consider'
    String? reason,
    double? counterOfferPrice,
    String? counterOfferNotes,
  }) async {
    try {
      String endpoint;
      Map<String, dynamic> body = {};

      if (decision == 'approve') {
        endpoint = 'opportunities/applications/$applicationId/approve';
      } else if (decision == 'reject') {
        endpoint = 'opportunities/applications/$applicationId/reject';
        if (reason != null && reason.isNotEmpty) body['reason'] = reason;
      } else {
        endpoint = 'opportunities/applications/$applicationId/consider';
        if (counterOfferPrice != null) body['counter_offer_price'] = counterOfferPrice;
        if (counterOfferNotes != null && counterOfferNotes.isNotEmpty) {
          body['notes'] = counterOfferNotes;
        } else if (reason != null && reason.isNotEmpty) {
          body['notes'] = reason;
        }
      }

      final response = await ApiService.post(endpoint, body);

      if (response['status'] == true) {
        clearCache();
      }

      return {
        'status': response['status'] == true,
        'message': response['message'] ?? 'Status lamaran berhasil diperbarui.',
        'data': response['data'],
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> respondCounterOffer({
    required String applicationId,
    required String action, // 'accept', 'decline', or 'counter'
    double? counterOfferPrice,
    String? counterOfferNotes,
  }) async {
    try {
      final Map<String, dynamic> body = {'action': action};
      if (counterOfferPrice != null && counterOfferPrice > 0) {
        body['counter_offer_price'] = counterOfferPrice;
      }
      if (counterOfferNotes != null && counterOfferNotes.isNotEmpty) {
        body['counter_offer_notes'] = counterOfferNotes;
      }

      final response = await ApiService.post(
        'opportunities/applications/$applicationId/respond-counter-offer',
        body,
      );
      return {
        'status': response['status'] == true,
        'message': response['message'] ?? 'Tanggapan tawaran berhasil dikirim.',
        'data': response['data'],
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
    double? externalRating,
    String? externalRatingSource,
    String? externalProofUrl,
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
        if (externalRating != null) 'external_rating': externalRating,
        if (externalRatingSource != null) 'external_rating_source': externalRatingSource,
        if (externalProofUrl != null) 'external_proof_url': externalProofUrl,
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

    // Jika gagal ke database server: DILARANG menyimpan ke memori / cache lokal!
    if (apiResult == null) {
      return {
        'status': false,
        'message': errorMessage ?? 'Gagal menyimpan data ke database server. Pastikan server aktif dan coba lagi.',
        'data': null,
      };
    }

    // Berhasil masuk database: bersihkan cache baca agar view berikutnya langsung membaca data riil terbaru
    clearCache();

    return {
      'status': true,
      'message': 'Peluang proyek berhasil dipublikasikan dan tersimpan di database!',
      'data': apiResult,
    };
  }

  static Future<Map<String, dynamic>> updateOpportunity({
    required String id,
    String? title,
    String? description,
    String? subRoleSlug,
    String? location,
    String? address,
    String? deadline,
    String? budgetRange,
    String? status,
    List<Map<String, dynamic>>? requirements,
  }) async {
    try {
      final res = await ApiService.put('opportunities/$id', {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (subRoleSlug != null) 'sub_role_slug': subRoleSlug,
        if (location != null) 'location': location,
        if (address != null) 'address': address,
        if (deadline != null) 'deadline': deadline,
        if (budgetRange != null) 'budget_range': budgetRange,
        if (status != null) 'status': status,
        if (requirements != null) 'requirements': requirements,
      });

      if (res['status'] == true && res['data'] != null) {
        clearCache();
        return {
          'status': true,
          'message': res['message'] ?? 'Lowongan berhasil diperbarui di database.',
          'data': OpportunityModel.fromJson(res['data']),
        };
      }
      return {
        'status': false,
        'message': res['message']?.toString() ?? 'Gagal memperbarui lowongan di database.',
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> updateStatus(String id, String status) async {
    try {
      final res = await ApiService.post('opportunities/$id/status', {
        'status': status,
      });

      if (res['status'] == true && res['data'] != null) {
        clearCache();
        return {
          'status': true,
          'message': res['message'] ?? 'Status lowongan berhasil diperbarui di database.',
          'data': OpportunityModel.fromJson(res['data']),
        };
      }
      return {
        'status': false,
        'message': res['message']?.toString() ?? 'Gagal memperbarui status di database.',
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> deleteOpportunity(String id) async {
    try {
      final res = await ApiService.delete('opportunities/$id');
      if (res['status'] == true) {
        clearCache();
        return {
          'status': true,
          'message': res['message'] ?? 'Lowongan berhasil dihapus dari database.',
        };
      }
      return {
        'status': false,
        'message': res['message']?.toString() ?? 'Gagal menghapus lowongan dari database.',
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> startEvent(
    String opportunityId, {
    String? signature,
    String? signatureType,
    String? documentUrl,
    List<String>? dynamicTerms,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (signature != null && signature.isNotEmpty) body['signature'] = signature;
      if (signatureType != null && signatureType.isNotEmpty) body['signature_type'] = signatureType;
      if (documentUrl != null && documentUrl.isNotEmpty) body['document_url'] = documentUrl;
      if (dynamicTerms != null && dynamicTerms.isNotEmpty) body['dynamic_terms'] = dynamicTerms;

      final res = await ApiService.post('opportunities/$opportunityId/start-event', body);
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

  static Future<List<JobContract>> getOpportunityContracts(String opportunityId) async {
    try {
      final res = await ApiService.get('opportunities/$opportunityId/contracts');
      if (res['status'] == true && res['data'] is List) {
        return (res['data'] as List)
            .map((item) => JobContract.fromJson(item))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> signContract({
    required String opportunityId,
    String? applicationId,
    bool signAll = false,
    String? signature,
    String? signatureType,
    String? documentUrl,
    List<String>? dynamicTerms,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (applicationId != null && applicationId.isNotEmpty) {
        body['application_id'] = applicationId;
      }
      if (signAll) body['sign_all'] = true;
      if (signature != null && signature.isNotEmpty) body['signature'] = signature;
      if (signatureType != null && signatureType.isNotEmpty) body['signature_type'] = signatureType;
      if (documentUrl != null && documentUrl.isNotEmpty) body['document_url'] = documentUrl;
      if (dynamicTerms != null && dynamicTerms.isNotEmpty) body['dynamic_terms'] = dynamicTerms;

      final res = await ApiService.post('opportunities/$opportunityId/sign-contract', body);
      return {
        'status': res['status'] == true,
        'message': res['message'] ?? 'Kontrak berhasil ditandatangani.',
        'data': res['data'] != null ? OpportunityModel.fromJson(res['data']) : null,
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> updateDynamicTerms({
    required String opportunityId,
    String? applicationId,
    required List<String> dynamicTerms,
  }) async {
    try {
      final body = <String, dynamic>{
        'dynamic_terms': dynamicTerms,
      };
      if (applicationId != null && applicationId.isNotEmpty) {
        body['application_id'] = applicationId;
      }
      final res = await ApiService.post('opportunities/$opportunityId/dynamic-terms', body);
      return {
        'status': res['status'] == true,
        'message': res['message'] ?? 'Ketentuan khusus kontrak berhasil diperbarui.',
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
        'message': res['message'] ?? 'Jadwal pertemuan fisik tanda tangan basah berhasil diajukan.',
        'data': res['data'] != null ? OpportunityModel.fromJson(res['data']) : null,
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> reviewMeeting({
    required String opportunityId,
    required String decision, // 'approve' | 'counter' | 'reject'
    String? notes,
    String? counterDate,
    String? counterTime,
    String? counterLocation,
    double? counterLat,
    double? counterLng,
    String? counterNotes,
  }) async {
    try {
      final res = await ApiService.post('opportunities/$opportunityId/review-meeting', {
        'decision': decision,
        if (notes != null) 'notes': notes,
        if (counterDate != null) 'counter_date': counterDate,
        if (counterTime != null) 'counter_time': counterTime,
        if (counterLocation != null) 'counter_location': counterLocation,
        if (counterLat != null) 'counter_lat': counterLat,
        if (counterLng != null) 'counter_lng': counterLng,
        if (counterNotes != null) 'counter_notes': counterNotes,
      });
      return {
        'status': res['status'] == true,
        'message': res['message'] ?? 'Status jadwal pertemuan berhasil diperbarui.',
        'data': res['data'] != null ? OpportunityModel.fromJson(res['data']) : null,
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> respondMeetingCounter({
    required String opportunityId,
    required String action, // 'accept' | 'counter' | 'decline'
    String? date,
    String? time,
    String? location,
    double? lat,
    double? lng,
    String? notes,
  }) async {
    try {
      final res = await ApiService.post('opportunities/$opportunityId/respond-meeting-counter', {
        'action': action,
        if (date != null) 'meeting_date': date,
        if (time != null) 'meeting_time': time,
        if (location != null) 'meeting_location': location,
        if (lat != null) 'meeting_lat': lat,
        if (lng != null) 'meeting_lng': lng,
        if (notes != null) 'meeting_notes': notes,
      });
      return {
        'status': res['status'] == true,
        'message': res['message'] ?? 'Respon tawaran jadwal berhasil dikirim.',
        'data': res['data'] != null ? OpportunityModel.fromJson(res['data']) : null,
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> adminStartEvent({
    required String opportunityId,
    String? documentMouUrl,
    String? notes,
  }) async {
    try {
      final res = await ApiService.post('opportunities/$opportunityId/admin-start-event', {
        if (documentMouUrl != null) 'document_mou_url': documentMouUrl,
        if (notes != null) 'notes': notes,
      });
      return {
        'status': res['status'] == true,
        'message': res['message'] ?? 'Acara resmi dimulai oleh Admin setelah verifikasi tanda tangan basah fisik!',
        'data': res['data'] != null ? OpportunityModel.fromJson(res['data']) : null,
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> updateWorkerProgress({
    required String applicationId,
    required int progress,
    String? notes,
    String? workerStatus,
  }) async {
    try {
      final res = await ApiService.post('opportunities/applications/$applicationId/progress', {
        'progress': progress,
        if (notes != null) 'notes': notes,
        if (workerStatus != null) 'worker_status': workerStatus,
      });
      return {
        'status': res['status'] == true,
        'message': res['message'] ?? 'Progress pekerja berhasil diperbarui.',
        'data': res['data'],
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> uploadDeliverable({
    required String applicationId,
    required String type, // 'link' | 'image' | 'video' | 'document'
    required String title,
    String? url,
    String? notes,
  }) async {
    try {
      final res = await ApiService.post('opportunities/applications/$applicationId/deliverables', {
        'type': type,
        'title': title,
        if (url != null) 'url': url,
        if (notes != null) 'notes': notes,
      });
      return {
        'status': res['status'] == true,
        'message': res['message'] ?? 'Hasil kerja (deliverable) berhasil diunggah.',
        'data': res['data'],
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> payWorker({
    required String applicationId,
    int? milestoneIndex,
    double? amount,
  }) async {
    try {
      final res = await ApiService.post('opportunities/applications/$applicationId/pay', {
        if (milestoneIndex != null) 'milestone_index': milestoneIndex,
        if (amount != null) 'amount': amount,
      });
      return {
        'status': res['status'] == true,
        'message': res['message'] ?? 'Pembayaran honor berhasil dicairkan ke pekerja.',
        'data': res['data'],
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> autoReleaseEscrow(String opportunityId) async {
    try {
      final res = await ApiService.post('opportunities/$opportunityId/auto-release-escrow', {});
      return {
        'status': res['status'] == true,
        'message': res['message'] ?? 'Pengecekan auto-release selesai.',
        'data': res['data'],
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

  /// Ambil ulasan yang sudah diberikan untuk suatu proyek/opportunity
  static Future<List<Map<String, dynamic>>> getOpportunityReviews(String opportunityId) async {
    try {
      final res = await ApiService.get('opportunities/$opportunityId/reviews');
      if (res['status'] == true && res['data'] is List) {
        return List<Map<String, dynamic>>.from(res['data']);
      }
    } catch (_) {}
    return [];
  }

  /// Kirim ulasan dan rating untuk proyek/opportunity yang telah selesai
  static Future<Map<String, dynamic>> submitOpportunityReview({
    required String opportunityId,
    required String creatorId,
    required double rating,
    String? comment,
    bool? isOnTime,
    int? deliveryDays,
  }) async {
    try {
      final payload = <String, dynamic>{
        'creator_id': creatorId,
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        if (isOnTime != null) 'is_on_time': isOnTime,
        if (deliveryDays != null) 'delivery_days': deliveryDays,
      };

      final res = await ApiService.post('opportunities/$opportunityId/reviews', payload);
      return {
        'status': res['status'] == true,
        'message': res['message'] ?? 'Ulasan berhasil dikirim.',
        'data': res['data'],
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  /// Mengajukan siswa magang dari akun institusi dengan metadata siswa terstruktur di database.
  static Future<Map<String, dynamic>> applyInstitutionStudent({
    required String opportunityId,
    required String subRoleSlug,
    required String pitchMessage,
    required Map<String, dynamic> studentDocument,
  }) async {
    try {
      final res = await ApiService.post('opportunities/$opportunityId/applications', {
        'sub_role_slug': subRoleSlug,
        'pitch_message': pitchMessage,
        'bid_price': 0,
        'submitted_documents': [studentDocument],
      });

      final ok = res['status'] == true;
      if (ok) {
        clearCache();
      }
      return {
        'status': ok,
        'message': res['message']?.toString() ??
            (ok ? 'Pengajuan siswa berhasil disimpan.' : 'Gagal mengajukan siswa.'),
        'data': res['data'],
      };
    } catch (e) {
      return {
        'status': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }
}
