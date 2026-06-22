import '../models/opportunity_model.dart';
import 'api_service.dart';

class DashboardService {
  /// Ambil stats dashboard berdasarkan pihak dan role
  static Future<List<Map<String, String>>> getStats({
    required String pihak,
    required String roleType,
  }) async {
    final result = await ApiService.get('dashboard/stats', queryParams: {
      'pihak_slug': pihak,
      'role_type': roleType,
    });

    if (result['success'] == true && result['data'] != null) {
      final List<dynamic> data = result['data'];
      return data
          .map((item) => {
                'label': (item['label'] ?? item['stat_label'] ?? '').toString(),
                'value': (item['value'] ?? item['stat_value'] ?? '').toString(),
                'icon': (item['icon'] ?? item['stat_icon'] ?? '').toString(),
              })
          .toList();
    }

    // Fallback data jika API gagal
    return _getFallbackStats(pihak, roleType);
  }

  /// Ambil peluang/opportunities berdasarkan pihak
  static Future<List<OpportunityModel>> getOpportunities({
    required String pihak,
    int limit = 5,
  }) async {
    final result =
        await ApiService.get('dashboard/opportunities', queryParams: {
      'pihak_slug': pihak,
      'limit': limit.toString(),
    });

    if (result['success'] == true && result['data'] != null) {
      final List<dynamic> data = result['data'];
      return data.map((item) => OpportunityModel.fromJson(item)).toList();
    }

    // Fallback data
    return _getFallbackOpportunities(pihak);
  }

  // ============= FALLBACK DATA =============
  // Digunakan saat API belum tersedia / offline

  static List<Map<String, String>> _getFallbackStats(
      String pihak, String roleType) {
    final statsMap = {
      'kreator': {
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
      'eo': {
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
      'wo': {
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
      'sekolah': {
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
      'umkm': {
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
      'pemerintah': {
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
      'komunitas': {
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

    return statsMap[pihak]?[roleType] ??
        statsMap['kreator']?['user'] ??
        [];
  }

  static List<OpportunityModel> _getFallbackOpportunities(String pihak) {
    final Map<String, List<Map<String, dynamic>>> opportunitiesMap = {
      'kreator': [
        {
          'id': 1,
          'title': 'Fotografer Event Jakarta',
          'description': 'Dibutuhkan fotografer profesional untuk corporate event',
          'pihak_slug': 'kreator',
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
          'pihak_slug': 'kreator',
          'location': 'Bandung',
          'deadline': '2026-07-25',
          'budget_range': 'Rp 5-8 Juta',
          'status': 'open',
          'posted_by': 1,
        },
      ],
      'eo': [
        {
          'id': 3,
          'title': 'Konser Musik Akhir Tahun',
          'description': 'Butuh EO untuk konser musik 1000 orang',
          'pihak_slug': 'eo',
          'location': 'Surabaya',
          'deadline': '2026-12-15',
          'budget_range': 'Rp 50-100 Juta',
          'status': 'open',
          'posted_by': 1,
        },
      ],
      'wo': [
        {
          'id': 4,
          'title': 'Paket Wedding Premium',
          'description': 'Paket lengkap all-in wedding',
          'pihak_slug': 'wo',
          'location': 'Bali',
          'deadline': '2026-08-10',
          'budget_range': 'Rp 80-150 Juta',
          'status': 'open',
          'posted_by': 1,
        },
      ],
      'sekolah': [
        {
          'id': 5,
          'title': 'Lomba Desain Poster',
          'description': 'Lomba desain poster nasional',
          'pihak_slug': 'sekolah',
          'location': 'Online',
          'deadline': '2026-07-18',
          'budget_range': 'Gratis',
          'status': 'open',
          'posted_by': 1,
        },
      ],
      'umkm': [
        {
          'id': 6,
          'title': 'Fotografi Produk UMKM',
          'description': 'Photo produk untuk katalog online',
          'pihak_slug': 'umkm',
          'location': 'Yogyakarta',
          'deadline': '2026-07-30',
          'budget_range': 'Rp 1-3 Juta',
          'status': 'open',
          'posted_by': 1,
        },
      ],
      'pemerintah': [
        {
          'id': 7,
          'title': 'Festival Budaya Daerah',
          'description': 'Dokumentasi festival budaya',
          'pihak_slug': 'pemerintah',
          'location': 'Semarang',
          'deadline': '2026-08-20',
          'budget_range': 'Rp 10-20 Juta',
          'status': 'open',
          'posted_by': 1,
        },
      ],
      'komunitas': [
        {
          'id': 8,
          'title': 'Workshop Photography',
          'description': 'Workshop fotografi untuk pemula',
          'pihak_slug': 'komunitas',
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
          'pihak_slug': 'organisasi',
          'location': 'Online',
          'deadline': '2026-07-29',
          'budget_range': 'Gratis',
          'status': 'open',
          'posted_by': 1,
        },
      ],
    };

    final data = opportunitiesMap[pihak] ?? opportunitiesMap['kreator']!;
    return data.map((item) => OpportunityModel.fromJson(item)).toList();
  }
}
