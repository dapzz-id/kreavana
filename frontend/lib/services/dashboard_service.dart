import '../models/opportunity_model.dart';
import 'api_service.dart';

class DashboardService {
  /// Ambil stats dashboard berdasarkan subRole dan role
  static Future<List<Map<String, String>>> getStats({
    required String subRole,
    required String roleType,
  }) async {
    final result = await ApiService.get(
      'dashboard/stats',
      queryParams: {'sub_role_slug': subRole, 'role_type': roleType},
    );

    if (result['status'] == true && result['data'] != null) {
      final List<dynamic> data = result['data'];
      return data
          .map(
            (item) => {
              'label': (item['label'] ?? item['stat_label'] ?? '').toString(),
              'value': (item['value'] ?? item['stat_value'] ?? '').toString(),
              'icon': (item['icon'] ?? item['stat_icon'] ?? '').toString(),
            },
          )
          .toList();
    }

    // Fallback data jika API gagal
    return _getFallbackStats(subRole, roleType);
  }

  static Future<Map<String, dynamic>> getClientDashboardOverview({
    required String roleType,
  }) async {
    final result = await ApiService.get(
      'client-dashboard/overview',
      queryParams: {'role_type': roleType},
    );

    if (result['status'] == true && result['data'] != null) {
      return result['data'] as Map<String, dynamic>;
    }

    return {
      'summary': {
        'active_needs': 0,
        'proposals_count': 0,
        'running_projects': 0,
        'estimated_expenses': 'Rp 0',
        'total_projects': 0,
        'active_projects': 0,
        'total_payments': 'Rp 0',
        'pending_payments': 'Rp 0',
        'favorites': 0,
      },
      'client_types': [],
      'activity_feed': [],
      'vendor_recommendations': [],
      'project_needs': [],
      'agenda': [],
      'project_assets': [],
    };
  }

  /// Ambil statistik untuk semua kategori subRole sekaligus
  static Future<Map<String, List<Map<String, String>>>> getAllSubRoleStats({
    required List<String> subRoleSlugs,
    required String roleType,
  }) async {
    final results = await Future.wait(
      subRoleSlugs.map((slug) => getStats(subRole: slug, roleType: roleType)),
    );

    return {
      for (var i = 0; i < subRoleSlugs.length; i++) subRoleSlugs[i]: results[i],
    };
  }

  /// Parse nilai statistik ke angka untuk grafik
  static double parseStatNumeric(String raw) {
    var s = raw.replaceAll('%', '').trim();
    if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
      s = s.replaceAll('.', '');
    }
    return double.tryParse(s.replaceAll(',', '.')) ?? 0;
  }

  /// Ambil peluang/opportunities berdasarkan subRole
  static Future<List<OpportunityModel>> getOpportunities({
    required String subRole,
    int limit = 5,
  }) async {
    print('DEBUG: Fetching opportunities for subRole: $subRole');
    final result = await ApiService.get(
      'dashboard/opportunities',
      queryParams: {'sub_role_slug': subRole, 'limit': limit.toString()},
    );

    print('DEBUG: API result status: ${result['status']}');
    print('DEBUG: API result data: ${result['data']}');

    if (result['status'] == true && result['data'] != null) {
      final List<dynamic> data = result['data'];
      print('DEBUG: Parsed ${data.length} opportunities from API');
      if (data.isNotEmpty) {
        return data.map((item) => OpportunityModel.fromJson(item)).toList();
      }
    }

    print('DEBUG: Using fallback data for opportunities');
    // Fallback data
    return _getFallbackOpportunities(subRole);
  }

  // ============= FALLBACK DATA =============
  // Digunakan saat API belum tersedia / offline

  static List<Map<String, String>> _getFallbackStats(
    String subRole,
    String roleType,
  ) {
    final statsMap = {
      'photographer': {
        'user': [
          {'label': 'Peluang Tersedia', 'value': '24', 'icon': 'work'},
          {'label': 'Kreator Aktif', 'value': '150', 'icon': 'people'},
          {'label': 'Rating Rata-rata', 'value': '4.7', 'icon': 'star'},
          {'label': 'Proyek Selesai', 'value': '89', 'icon': 'check'},
        ],
        'creator': [
          {'label': 'Peluang Diterima', 'value': '12', 'icon': 'inbox'},
          {'label': 'Proyek Berjalan', 'value': '3', 'icon': 'pending'},
          {'label': 'Selesai', 'value': '18', 'icon': 'done_all'},
          {'label': 'Rating Kamu', 'value': '4.8', 'icon': 'star'},
        ],
      },
      'event_organizer': {
        'user': [
          {'label': 'Event Mendatang', 'value': '6', 'icon': 'event'},
          {'label': 'Vendor Tersedia', 'value': '120', 'icon': 'store'},
          {'label': 'Booking', 'value': '8', 'icon': 'book_online'},
          {'label': 'Rating Vendor', 'value': '4.6', 'icon': 'star'},
        ],
        'creator': [
          {'label': 'Proyek Event', 'value': '15', 'icon': 'event_note'},
          {'label': 'Vendor Terpilih', 'value': '4', 'icon': 'check_circle'},
          {'label': 'Selesai', 'value': '23', 'icon': 'done_all'},
          {'label': 'Rating', 'value': '4.9', 'icon': 'star'},
        ],
      },
      'wedding_organizer': {
        'user': [
          {'label': 'Paket Aktif', 'value': '8', 'icon': 'card_giftcard'},
          {'label': 'Vendor Favorit', 'value': '14', 'icon': 'favorite'},
          {'label': 'Booking', 'value': '5', 'icon': 'book_online'},
          {'label': 'Selesai', 'value': '32', 'icon': 'done_all'},
        ],
        'creator': [
          {'label': 'Wedding Aktif', 'value': '5', 'icon': 'favorite'},
          {'label': 'Vendor Terpilih', 'value': '12', 'icon': 'check_circle'},
          {'label': 'Selesai', 'value': '28', 'icon': 'done_all'},
          {'label': 'Rating', 'value': '4.9', 'icon': 'star'},
        ],
      },
      'institution': {
        'user': [
          {'label': 'Alumni Terdaftar', 'value': '1.240', 'icon': 'school'},
          {'label': 'Lulusan Terserap', 'value': '68%', 'icon': 'trending_up'},
          {'label': 'Magang & PKL', 'value': '45', 'icon': 'work'},
          {'label': 'Kegiatan Aktif', 'value': '8', 'icon': 'event'},
        ],
        'creator': [
          {'label': 'Peluang Magang', 'value': '12', 'icon': 'work'},
          {'label': 'Proyek Kampus', 'value': '5', 'icon': 'assignment'},
          {'label': 'Selesai', 'value': '15', 'icon': 'done_all'},
          {'label': 'Rating', 'value': '4.6', 'icon': 'star'},
        ],
      },
      'editor': {
        'user': [
          {'label': 'Proyek Aktif', 'value': '5', 'icon': 'business'},
          {'label': 'Konten Dibuat', 'value': '12', 'icon': 'photo_library'},
          {'label': 'Brand Campaign', 'value': '3', 'icon': 'campaign'},
          {'label': 'Selesai', 'value': '18', 'icon': 'done_all'},
        ],
        'creator': [
          {'label': 'Proyek Bisnis', 'value': '8', 'icon': 'business'},
          {'label': 'Klien Aktif', 'value': '4', 'icon': 'people'},
          {'label': 'Selesai', 'value': '22', 'icon': 'done_all'},
          {'label': 'Rating', 'value': '4.7', 'icon': 'star'},
        ],
      },
      'government': {
        'user': [
          {'label': 'Kegiatan Aktif', 'value': '12', 'icon': 'event'},
          {'label': 'Relawan', 'value': '320', 'icon': 'volunteer_activism'},
          {'label': 'Vendor Lokal', 'value': '85', 'icon': 'store'},
          {'label': 'Laporan', 'value': '18', 'icon': 'assessment'},
        ],
        'creator': [
          {'label': 'Program Aktif', 'value': '6', 'icon': 'gavel'},
          {'label': 'Dokumentasi', 'value': '15', 'icon': 'photo_camera'},
          {'label': 'Selesai', 'value': '30', 'icon': 'done_all'},
          {'label': 'Rating', 'value': '4.5', 'icon': 'star'},
        ],
      },
      'community': {
        'user': [
          {'label': 'Anggota', 'value': '580', 'icon': 'groups'},
          {'label': 'Event Aktif', 'value': '6', 'icon': 'event'},
          {'label': 'Kolaborasi', 'value': '320', 'icon': 'handshake'},
          {'label': 'Sponsor', 'value': '8', 'icon': 'monetization_on'},
        ],
        'creator': [
          {'label': 'Event Diikuti', 'value': '10', 'icon': 'event'},
          {'label': 'Kolaborasi', 'value': '5', 'icon': 'handshake'},
          {'label': 'Selesai', 'value': '18', 'icon': 'done_all'},
          {'label': 'Rating', 'value': '4.7', 'icon': 'star'},
        ],
      },
      'organisasi': {
        'user': [
          {'label': 'Anggota', 'value': '1.100', 'icon': 'corporate_fare'},
          {'label': 'Event', 'value': '10', 'icon': 'event'},
          {'label': 'Peluang', 'value': '25', 'icon': 'work'},
          {'label': 'Kolaborasi', 'value': '15', 'icon': 'handshake'},
        ],
        'creator': [
          {'label': 'Peluang Diambil', 'value': '8', 'icon': 'work'},
          {'label': 'Proyek Aktif', 'value': '3', 'icon': 'pending'},
          {'label': 'Selesai', 'value': '20', 'icon': 'done_all'},
          {'label': 'Rating', 'value': '4.6', 'icon': 'star'},
        ],
      },
    };

    return statsMap[subRole]?[roleType] ??
        statsMap['photographer']?['user'] ??
        [];
  }

  static List<OpportunityModel> _getFallbackOpportunities(String subRole) {
    final Map<String, List<Map<String, dynamic>>> opportunitiesMap = {
      'photographer': [
        {
          'id': 1,
          'title': 'Fotografer Event Jakarta',
          'description':
              'Dibutuhkan fotografer profesional untuk corporate event',
          'sub_role_slug': 'photographer',
          'location': 'Jakarta',
          'deadline': '2026-07-20',
          'budget_range': 'Rp 3-5 Juta',
          'status': 'open',
          'posted_by': 1,
        },
        {
          'id': 2,
          'title': 'Videografer Wedding Bandung',
          'description': 'Wedding videography untuk intimate wedding',
          'sub_role_slug': 'videographer',
          'location': 'Bandung',
          'deadline': '2026-07-25',
          'budget_range': 'Rp 5-8 Juta',
          'status': 'open',
          'posted_by': 1,
        },
      ],
      'event_organizer': [
        {
          'id': 3,
          'title': 'Konser Musik Akhir Tahun',
          'description': 'Butuh EO untuk konser musik 1000 orang',
          'sub_role_slug': 'event_organizer',
          'location': 'Surabaya',
          'deadline': '2026-12-15',
          'budget_range': 'Rp 50-100 Juta',
          'status': 'open',
          'posted_by': 1,
        },
      ],
      'wedding_organizer': [
        {
          'id': 4,
          'title': 'Paket Wedding Premium',
          'description': 'Paket lengkap all-in wedding',
          'sub_role_slug': 'wedding_organizer',
          'location': 'Bali',
          'deadline': '2026-08-10',
          'budget_range': 'Rp 80-150 Juta',
          'status': 'open',
          'posted_by': 1,
        },
      ],
      'institution': [
        {
          'id': 5,
          'title': 'Lomba Desain Poster',
          'description': 'Lomba desain poster nasional',
          'sub_role_slug': 'institution',
          'location': 'Online',
          'deadline': '2026-07-18',
          'budget_range': 'Gratis',
          'status': 'open',
          'posted_by': 1,
        },
      ],
      'editor': [
        {
          'id': 6,
          'title': 'Fotografi Produk UMKM',
          'description': 'Photo produk untuk katalog online',
          'sub_role_slug': 'editor',
          'location': 'Yogyakarta',
          'deadline': '2026-07-30',
          'budget_range': 'Rp 1-3 Juta',
          'status': 'open',
          'posted_by': 1,
        },
      ],
      'government': [
        {
          'id': 7,
          'title': 'Festival Budaya Daerah',
          'description': 'Dokumentasi festival budaya',
          'sub_role_slug': 'government',
          'location': 'Semarang',
          'deadline': '2026-08-20',
          'budget_range': 'Rp 10-20 Juta',
          'status': 'open',
          'posted_by': 1,
        },
      ],
      'community': [
        {
          'id': 8,
          'title': 'Workshop Photography',
          'description': 'Workshop fotografi untuk pemula',
          'sub_role_slug': 'community',
          'location': 'Jakarta',
          'deadline': '2026-07-18',
          'budget_range': 'Rp 150.000',
          'status': 'open',
          'posted_by': 1,
        },
      ],
      'organisasi': [
        {
          'id': 9,
          'title': 'Pelatihan Digital Marketing',
          'description': 'Pelatihan untuk anggota organisasi',
          'sub_role_slug': 'organisasi',
          'location': 'Online',
          'deadline': '2026-07-29',
          'budget_range': 'Gratis',
          'status': 'open',
          'posted_by': 1,
        },
      ],
    };

    final data = opportunitiesMap[subRole] ?? opportunitiesMap['photographer']!;
    return data.map((item) => OpportunityModel.fromJson(item)).toList();
  }
}
