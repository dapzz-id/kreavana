import '../models/opportunity_model.dart';
import 'api_service.dart';

class OpportunityService {
  static Future<List<OpportunityModel>> getOpportunities({
    String pihak = 'all',
    String? type,
    int limit = 50,
  }) async {
    final result = await ApiService.get('opportunities', queryParams: {
      'pihak_slug': pihak,
      if (type != null) 'type': type,
      'limit': limit.toString(),
    });

    if (result['success'] == true && result['data'] != null) {
      return (result['data'] as List)
          .map((item) => OpportunityModel.fromJson(item))
          .toList();
    }

    return _getFallback(pihak, type);
  }

  static Future<List<OpportunityModel>> getMapLocations({
    String pihak = 'all',
  }) async {
    final result = await ApiService.get('opportunities/map', queryParams: {
      'pihak_slug': pihak,
    });

    if (result['success'] == true && result['data'] != null) {
      return (result['data'] as List)
          .map((item) => OpportunityModel.fromJson(item))
          .toList();
    }

    return _getFallback(pihak, 'location');
  }

  static Future<OpportunityModel?> getDetail(int id) async {
    final result = await ApiService.get('opportunities/$id');

    if (result['success'] == true && result['data'] != null) {
      return OpportunityModel.fromJson(result['data']);
    }
    return null;
  }

  static Future<Map<String, dynamic>> submitReport({
    required String targetType,
    required int targetId,
    required String reason,
    String? description,
  }) async {
    final response = await ApiService.post('opportunities/report', {
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      if (description != null) 'description': description,
    });

    return {
      'success': response['success'] == true,
      'message': response['message'] ?? 'Gagal mengirim laporan.',
    };
  }

  static Future<Map<String, dynamic>> createOpportunity({
    required String title,
    required String pihakSlug,
    required String type,
    String? description,
    String? location,
    double? latitude,
    double? longitude,
    String? locationCategory,
    String? address,
    String? deadline,
    String? budgetRange,
  }) async {
    final response = await ApiService.post('opportunities', {
      'title': title,
      'pihak_slug': pihakSlug,
      'type': type,
      if (description != null) 'description': description,
      if (location != null) 'location': location,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationCategory != null) 'location_category': locationCategory,
      if (address != null) 'address': address,
      if (deadline != null) 'deadline': deadline,
      if (budgetRange != null) 'budget_range': budgetRange,
    });

    return {
      'success': response['success'] == true,
      'message': response['message'],
      'data': response['data'],
    };
  }

  static List<OpportunityModel> _getFallback(String pihak, String? type) {
    final all = [
      OpportunityModel(
        id: 101,
        title: 'Sunrise Point Bromo',
        description: 'Spot hunting sunrise terbaik di Penanjakan Bromo.',
        pihakSlug: 'kreator',
        type: 'location',
        location: 'Probolinggo',
        latitude: -7.9425,
        longitude: 112.9530,
        locationCategory: 'nature',
        address: 'Penanjakan Viewpoint, Bromo',
        status: 'open',
        postedBy: 1,
        poster: OpportunityPoster(
          id: 1,
          name: 'Admin Kreavana',
          username: 'admin',
          phone: '081234567890',
        ),
      ),
      OpportunityModel(
        id: 102,
        title: 'Kota Tua Jakarta',
        description: 'Lokasi heritage urban untuk street photography.',
        pihakSlug: 'kreator',
        type: 'location',
        location: 'Jakarta',
        latitude: -6.1352,
        longitude: 106.8133,
        locationCategory: 'urban',
        address: 'Kota Tua, Jakarta',
        status: 'open',
        postedBy: 1,
        poster: OpportunityPoster(
          id: 1,
          name: 'Admin Kreavana',
          username: 'admin',
          phone: '081234567890',
        ),
      ),
      OpportunityModel(
        id: 201,
        title: 'Fotografer Event Jakarta',
        description: 'Dibutuhkan fotografer profesional untuk corporate event.',
        pihakSlug: 'kreator',
        type: 'project',
        location: 'Jakarta',
        deadline: '2026-07-15',
        budgetRange: 'Rp 3-5 Juta',
        status: 'open',
        postedBy: 1,
        poster: OpportunityPoster(
          id: 1,
          name: 'Admin Kreavana',
          username: 'admin',
          phone: '081234567890',
        ),
      ),
      OpportunityModel(
        id: 202,
        title: 'Videografer Wedding Bandung',
        description: 'Wedding videography untuk intimate wedding.',
        pihakSlug: 'kreator',
        type: 'project',
        location: 'Bandung',
        deadline: '2026-07-20',
        budgetRange: 'Rp 5-8 Juta',
        status: 'open',
        postedBy: 1,
        poster: OpportunityPoster(
          id: 1,
          name: 'Admin Kreavana',
          username: 'admin',
          phone: '081234567890',
        ),
      ),
    ];

    var filtered = all;
    if (type != null) {
      filtered = filtered.where((o) => o.type == type).toList();
    }
    if (pihak != 'all') {
      filtered = filtered.where((o) => o.pihakSlug == pihak).toList();
    }
    return filtered;
  }
}
