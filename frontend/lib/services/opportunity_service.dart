import '../models/opportunity_model.dart';
import 'api_service.dart';

class OpportunityService {
  static Future<List<OpportunityModel>> getOpportunities({
    String subRole = 'all',
    String? type,
    int limit = 50,
  }) async {
    final result = await ApiService.get('opportunities', queryParams: {
      'sub_role_slug': subRole,
      'type': ?type,
      'limit': limit.toString(),
    });

    if (result['status'] == true && result['data'] != null) {
      return (result['data'] as List)
          .map((item) => OpportunityModel.fromJson(item))
          .toList();
    }

    return _getFallback(subRole, type);
  }

  static Future<List<OpportunityModel>> getMapLocations({
    String subRole = 'all',
  }) async {
    final result = await ApiService.get('opportunities/map', queryParams: {
      'sub_role_slug': subRole,
    });

    if (result['status'] == true && result['data'] != null) {
      return (result['data'] as List)
          .map((item) => OpportunityModel.fromJson(item))
          .toList();
    }

    return _getFallback(subRole, 'location');
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
      'description': ?description,
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
  }) async {
    final response = await ApiService.post('opportunities', {
      'title': title,
      'sub_role_slug': subRoleSlug,
      'type': type,
      'description': ?description,
      'location': ?location,
      'latitude': ?latitude,
      'longitude': ?longitude,
      'location_category': ?locationCategory,
      'address': ?address,
      'deadline': ?deadline,
      'budget_range': ?budgetRange,
    });

    return {
      'status': response['status'] == true,
      'message': response['message'],
      'data': response['data'],
    };
  }

  static List<OpportunityModel> _getFallback(String subRole, String? type) {
    final all = [
      OpportunityModel(
        id: '101',
        title: 'Sunrise Point Bromo',
        description: 'Spot hunting sunrise terbaik di Penanjakan Bromo. Cocok untuk fotografer landscape dan drone pilot.',
        subRoleSlug: 'kreator',
        type: 'location',
        location: 'Probolinggo',
        latitude: -7.9425,
        longitude: 112.9530,
        locationCategory: 'nature',
        address: 'Penanjakan Viewpoint, Bromo Tengger Semeru',
        status: 'open',
        postedBy: '1',
        poster: OpportunityPoster(
          id: '1',
          name: 'Admin Kreavana',
          username: 'admin',
          phone: '081234567890',
        ),
      ),
      OpportunityModel(
        id: '102',
        title: 'Kota Tua Jakarta',
        description: 'Lokasi heritage urban untuk street photography, pre-wedding, dan content creator.',
        subRoleSlug: 'kreator',
        type: 'location',
        location: 'Jakarta',
        latitude: -6.1352,
        longitude: 106.8133,
        locationCategory: 'urban',
        address: 'Jl. Pintu Besar Utara No.27, Pinangsia, Taman Sari',
        status: 'open',
        postedBy: '1',
        poster: OpportunityPoster(
          id: '1',
          name: 'Admin Kreavana',
          username: 'admin',
          phone: '081234567890',
        ),
      ),
      OpportunityModel(
        id: '103',
        title: 'Candi Borobudur',
        description: 'Peluang lokasi budaya untuk dokumentasi wisata dan event komunitas kreatif.',
        subRoleSlug: 'community',
        type: 'location',
        location: 'Magelang',
        latitude: -7.6079,
        longitude: 110.2038,
        locationCategory: 'culture',
        address: 'Borobudur, Magelang, Jawa Tengah',
        status: 'open',
        postedBy: '1',
        poster: OpportunityPoster(
          id: '1',
          name: 'Admin Kreavana',
          username: 'admin',
          phone: '081234567890',
        ),
      ),
      OpportunityModel(
        id: '104',
        title: 'Pantai Parangtritis',
        description: 'Hidden gem sunset di selatan Yogyakarta. Ideal untuk videografi dan travel content.',
        subRoleSlug: 'kreator',
        type: 'location',
        location: 'Yogyakarta',
        latitude: -8.0255,
        longitude: 110.3295,
        locationCategory: 'hidden_gems',
        address: 'Parangtritis, Kretek, Bantul, DIY',
        status: 'open',
        postedBy: '1',
        poster: OpportunityPoster(
          id: '1',
          name: 'Admin Kreavana',
          username: 'admin',
          phone: '081234567890',
        ),
      ),
      OpportunityModel(
        id: '105',
        title: 'Danau Toba Viewpoint',
        description: 'Spot wisata alam untuk konten pariwisata dan dokumentasi event musim liburan.',
        subRoleSlug: 'government',
        type: 'location',
        location: 'Samosir',
        latitude: 2.6845,
        longitude: 98.8759,
        locationCategory: 'tourism',
        address: 'Taman Simalem Resort, Samosir, Sumatera Utara',
        status: 'open',
        postedBy: '1',
        poster: OpportunityPoster(
          id: '1',
          name: 'Admin Kreavana',
          username: 'admin',
          phone: '081234567890',
        ),
      ),
      OpportunityModel(
        id: '106',
        title: 'Lavender Lembang',
        description: 'Lokasi seasonal spot untuk foto musiman, brand campaign, dan kolaborasi kreator.',
        subRoleSlug: 'umkm',
        type: 'location',
        location: 'Bandung',
        latitude: -6.8345,
        longitude: 107.6590,
        locationCategory: 'seasonal',
        address: 'Lembang, Bandung Barat, Jawa Barat',
        status: 'open',
        postedBy: '1',
        poster: OpportunityPoster(
          id: '1',
          name: 'Admin Kreavana',
          username: 'admin',
          phone: '081234567890',
        ),
      ),
      OpportunityModel(
        id: '201',
        title: 'Fotografer Event Jakarta',
        description: 'Dibutuhkan fotografer profesional untuk corporate event.',
        subRoleSlug: 'kreator',
        type: 'project',
        location: 'Jakarta',
        deadline: '2026-07-15',
        budgetRange: 'Rp 3-5 Juta',
        status: 'open',
        postedBy: '1',
        poster: OpportunityPoster(
          id: '1',
          name: 'Admin Kreavana',
          username: 'admin',
          phone: '081234567890',
        ),
      ),
      OpportunityModel(
        id: '202',
        title: 'Videografer Wedding Bandung',
        description: 'Wedding videography untuk intimate wedding.',
        subRoleSlug: 'kreator',
        type: 'project',
        location: 'Bandung',
        deadline: '2026-07-20',
        budgetRange: 'Rp 5-8 Juta',
        status: 'open',
        postedBy: '1',
        poster: OpportunityPoster(
          id: '1',
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
    if (subRole != 'all') {
      filtered = filtered.where((o) => o.subRoleSlug == subRole).toList();
    }
    return filtered;
  }
}
