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
      final encodedList = _userCreatedLocations.map((item) => item.toJson()).toList();
      await prefs.setString('user_created_map_locations', jsonEncode(encodedList));
    } catch (_) {}
  }

  static Future<List<OpportunityModel>> getOpportunities({
    String subRole = 'all',
    String? type,
    int limit = 50,
  }) async {
    final queryParams = <String, String>{
      'sub_role_slug': subRole,
      'limit': limit.toString(),
    };
    if (type != null && type.isNotEmpty) {
      queryParams['type'] = type;
    }

    final result = await ApiService.get('opportunities', queryParams: queryParams);

    if (result['status'] == true && result['data'] != null) {
      final list = (result['data'] as List)
          .map((item) => OpportunityModel.fromJson(item))
          .toList();
      if (list.isNotEmpty) return list;
    }

    return _getFallback(subRole, type);
  }

  static Future<List<OpportunityModel>> getMapLocations({
    String subRole = 'all',
  }) async {
    // Always reload from disk to pick up locations created by other sessions
    await _loadLocalLocations();

    List<OpportunityModel> remoteList = [];
    try {
      final result = await ApiService.get('opportunities/map', queryParams: {
        'sub_role_slug': subRole,
      });

      if (result['status'] == true && result['data'] != null && (result['data'] as List).isNotEmpty) {
        remoteList = (result['data'] as List)
            .map((item) => OpportunityModel.fromJson(item))
            .toList();
      }
    } catch (_) {}

    // Always include fallback dummy data
    final fallbackList = _getFallback('all', 'location');

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
      // If filtering by subRole yields no results, show all
      return filtered.isNotEmpty ? filtered : combined;
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
      poster: poster ?? OpportunityPoster(
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

  static List<OpportunityModel> _getFallback(String subRole, String? type) {
    final all = [
      OpportunityModel(
        id: '101',
        title: 'Andra - MC & Host Event Formal/Informal',
        description: 'Siap memandu acara pernikahan, launching brand, gala dinner, dan seminar. Memiliki jam terbang tinggi 5+ tahun.',
        subRoleSlug: 'mc',
        type: 'location',
        location: 'Jakarta Selatan',
        latitude: -6.2088,
        longitude: 106.8456,
        locationCategory: 'urban',
        address: 'Kuningan, Jakarta Selatan',
        status: 'open',
        postedBy: '101',
        poster: OpportunityPoster(
          id: '101',
          name: 'Andra Pratama (MC)',
          username: 'andra_mc',
          phone: '081234567890',
        ),
      ),
      OpportunityModel(
        id: '102',
        title: 'Budi Studio - Videografer Cinematic & Drone',
        description: 'Penyedia jasa shooting iklan, video klip, dokumenter alam & aerial drone 4K.',
        subRoleSlug: 'videografer',
        type: 'location',
        location: 'Denpasar Bali',
        latitude: -8.6705,
        longitude: 115.2126,
        locationCategory: 'nature',
        address: 'Sanur, Denpasar, Bali',
        status: 'open',
        postedBy: '102',
        poster: OpportunityPoster(
          id: '102',
          name: 'Budi Cinematic (Videografer)',
          username: 'budi_video',
          phone: '081987654321',
        ),
      ),
      OpportunityModel(
        id: '103',
        title: 'Chika Photography - Studio Portrait & Fashion',
        description: 'Fotografer profesional untuklookbook produk, fashion studio, dan prewedding outdoor Lembang.',
        subRoleSlug: 'fotografer',
        type: 'location',
        location: 'Bandung Barat',
        latitude: -6.8168,
        longitude: 107.6151,
        locationCategory: 'tourism',
        address: 'Jl. Raya Lembang No. 88, Bandung',
        status: 'open',
        postedBy: '103',
        poster: OpportunityPoster(
          id: '103',
          name: 'Chika Larasati (Fotografer)',
          username: 'chika_photo',
          phone: '085711223344',
        ),
      ),
      OpportunityModel(
        id: '104',
        title: 'Dian Travel & Food Content Creator',
        description: 'Menerima kolaborasi review tempat wisata, culinary review, dan endorsement sosial media.',
        subRoleSlug: 'content_creator',
        type: 'location',
        location: 'Yogyakarta',
        latitude: -7.7956,
        longitude: 110.3695,
        locationCategory: 'culture',
        address: 'Malioboro, Yogyakarta',
        status: 'open',
        postedBy: '104',
        poster: OpportunityPoster(
          id: '104',
          name: 'Dian Ayu (Content Creator)',
          username: 'dian_creator',
          phone: '081399887766',
        ),
      ),
      OpportunityModel(
        id: '105',
        title: 'Eko 3D Animation & Motion Graphic Studio',
        description: 'Jasa pembuatan animasi 2D/3D, karakter 3D, bumper video, dan efek VFX visual.',
        subRoleSlug: 'animator',
        type: 'location',
        location: 'Surabaya',
        latitude: -7.2575,
        longitude: 112.7521,
        locationCategory: 'urban',
        address: 'Gubeng, Surabaya, Jawa Timur',
        status: 'open',
        postedBy: '105',
        poster: OpportunityPoster(
          id: '105',
          name: 'Eko Wijaya (Animator)',
          username: 'eko_anim',
          phone: '082144556677',
        ),
      ),
      OpportunityModel(
        id: '106',
        title: 'Fiona Model & Talent Event Medan',
        description: 'Model runway, photoshoot brand baju, commercial talent, dan presenter booth pameran.',
        subRoleSlug: 'talent',
        type: 'location',
        location: 'Medan',
        latitude: 3.5952,
        longitude: 98.6722,
        locationCategory: 'hidden_gems',
        address: 'Medan Baru, Kota Medan',
        status: 'open',
        postedBy: '106',
        poster: OpportunityPoster(
          id: '106',
          name: 'Fiona Ristanti (Model/Talent)',
          username: 'fiona_talent',
          phone: '081122334455',
        ),
      ),
      OpportunityModel(
        id: '107',
        title: 'Gitaris & Audio Music Producer Makassar',
        description: 'Composer jingle iklan, sound designer, mixing & mastering audio serta live session musician.',
        subRoleSlug: 'musisi',
        type: 'location',
        location: 'Makassar',
        latitude: -5.1477,
        longitude: 119.4327,
        locationCategory: 'seasonal',
        address: 'Losari, Makassar, Sulawesi Selatan',
        status: 'open',
        postedBy: '107',
        poster: OpportunityPoster(
          id: '107',
          name: 'Gilang Sound (Musisi)',
          username: 'gilang_audio',
          phone: '087855443322',
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
