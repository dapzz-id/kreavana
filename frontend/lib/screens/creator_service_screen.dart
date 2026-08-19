import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../widgets/creator_availability_widget.dart';
import '../widgets/desktop_sidebar_layout.dart';

class CreatorServiceItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? tag;
  final String? value;
  final bool active;
  final List<Color>? gradient;
  final String? id;

  const CreatorServiceItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.tag,
    this.value,
    this.active = true,
    this.gradient,
    this.id,
  });

  Map<String, dynamic> toJson() => {
    'id': id ?? title,
    'title': title,
    'subtitle': subtitle,
    'iconCodepoint': icon.codePoint,
    'iconFontFamily': icon.fontFamily,
    'iconFontPackage': icon.fontPackage,
    'tag': tag,
    'value': value,
    'active': active,
    'gradientColorsHex': gradient
        ?.map((c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}')
        .toList(),
  };

  static CreatorServiceItem fromJson(Map<String, dynamic> j) {
    final List<Color>? grad = j['gradientColorsHex'] != null
        ? (j['gradientColorsHex'] as List<dynamic>)
              .map(
                (e) => Color(
                  int.parse((e as String).replaceAll('#', ''), radix: 16),
                ),
              )
              .toList()
        : null;
    return CreatorServiceItem(
      id: j['id']?.toString() ?? j['title']?.toString() ?? '',
      title: (j['title'] ?? '').toString(),
      subtitle: (j['subtitle'] ?? '').toString(),
      icon: Icons.edit_outlined,
      tag: j['tag']?.toString(),
      value: j['value']?.toString(),
      active: (j['active'] as bool?) ?? true,
      gradient: grad,
    );
  }
}

class CreatorLocalStorage {
  static const _prefix = 'kreavana_creator_';
  static const _kExtra = '${_prefix}extra_items_v1_';
  static const _kSaved = '${_prefix}saved_items_v1';
  static const _kSubmitted = '${_prefix}submitted_items_v1';
  static const _kReviews = '${_prefix}reviews_v1_';

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  static Future<List<CreatorServiceItem>> getExtraItems(String menuKey) async {
    try {
      final sp = await _prefs;
      final raw = sp.getString('$_kExtra$menuKey');
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => CreatorServiceItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> setExtraItems(
    String menuKey,
    List<CreatorServiceItem> items,
  ) async {
    try {
      final sp = await _prefs;
      await sp.setString(
        '$_kExtra$menuKey',
        jsonEncode(items.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  static Future<Set<String>> _loadStringSet(String key) async {
    try {
      final sp = await _prefs;
      return sp.getStringList(key)?.toSet() ?? <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  static Future<void> _saveStringSet(String key, Set<String> values) async {
    try {
      final sp = await _prefs;
      await sp.setStringList(key, values.toList(growable: false));
    } catch (_) {}
  }

  static Future<Set<String>> getSavedItems() => _loadStringSet(_kSaved);
  static Future<void> setSavedItems(Set<String> ids) =>
      _saveStringSet(_kSaved, ids);

  static Future<Set<String>> getSubmittedItems() => _loadStringSet(_kSubmitted);
  static Future<void> setSubmittedItems(Set<String> ids) =>
      _saveStringSet(_kSubmitted, ids);

  static Future<
    List<
      ({
        String name,
        String city,
        String text,
        int stars,
        String date,
        bool verified,
        int likes,
      })
    >
  >
  getReviews(String itemId) async {
    try {
      final sp = await _prefs;
      final raw = sp.getString('$_kReviews$itemId');
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return (
          name: (m['name'] ?? '').toString(),
          city: (m['city'] ?? '').toString(),
          text: (m['text'] ?? '').toString(),
          stars: (m['stars'] as int?) ?? 5,
          date: (m['date'] ?? 'Baru saja').toString(),
          verified: (m['verified'] as bool?) ?? true,
          likes: (m['likes'] as int?) ?? 0,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> setReviews(
    String itemId,
    List<
      ({
        String name,
        String city,
        String text,
        int stars,
        String date,
        bool verified,
        int likes,
      })
    >
    list,
  ) async {
    try {
      final sp = await _prefs;
      final encoded = list
          .map(
            (r) => {
              'name': r.name,
              'city': r.city,
              'text': r.text,
              'stars': r.stars,
              'date': r.date,
              'verified': r.verified,
              'likes': r.likes,
            },
          )
          .toList();
      await sp.setString('$_kReviews$itemId', jsonEncode(encoded));
    } catch (_) {}
  }
}

class CreatorServiceData {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final List<(String, String, IconData)> stats;
  final List<CreatorServiceItem> items;
  final bool isGrid;
  final String actionLabel;

  const CreatorServiceData({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.stats,
    required this.items,
    this.isGrid = false,
    this.actionLabel = 'Ajukan Sekarang',
  });

  static const Map<String, CreatorServiceData> registry = {
    // ─── Fotografer ────────────────────────────────────────────────
    'foto_galeri': CreatorServiceData(
      key: 'foto_galeri',
      title: 'Galeri Portofolio',
      subtitle: 'Koleksi karya fotografi terbaik',
      icon: Icons.photo_library_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('48', 'Proyek', Icons.photo_library_outlined),
        ('4.9', 'Rating', Icons.star_rounded),
        ('120+', 'Klien', Icons.people_outline),
      ],
      isGrid: true,
      items: [
        CreatorServiceItem(
          title: 'Wedding & Prewedding',
          subtitle: 'Dokumentasi pernikahan premium',
          icon: Icons.favorite_outline,
          tag: 'Fotografi',
          value: '24 Proyek',
        ),
        CreatorServiceItem(
          title: 'Katalog Produk',
          subtitle: 'Foto produk untuk e-commerce',
          icon: Icons.shopping_bag_outlined,
          tag: 'Produk',
          value: '15 Proyek',
        ),
        CreatorServiceItem(
          title: 'Event & Dokumentasi',
          subtitle: 'Liputan acara perusahaan & komunitas',
          icon: Icons.event_outlined,
          tag: 'Event',
          value: '12 Proyek',
        ),
        CreatorServiceItem(
          title: 'Portrait & Personal Branding',
          subtitle: 'Foto profil profesional & personal',
          icon: Icons.face_outlined,
          tag: 'Portrait',
          value: '18 Proyek',
        ),
        CreatorServiceItem(
          title: 'Arsitektur & Interior',
          subtitle: 'Foto properti & bangunan',
          icon: Icons.apartment_outlined,
          tag: 'Properti',
          value: '9 Proyek',
        ),
      ],
    ),
    'foto_booking': CreatorServiceData(
      key: 'foto_booking',
      title: 'Booking & Jadwal',
      subtitle: 'Kelola jadwal pemotretan Anda',
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('2', 'Hari Ini', Icons.today_outlined),
        ('5', 'Minggu Ini', Icons.date_range_outlined),
        ('3', 'Pending', Icons.pending_actions_outlined),
      ],
      actionLabel: 'Konfirmasi Booking',
      items: [
        CreatorServiceItem(
          title: 'Katalog Produk - Kopi Nusantara',
          subtitle: '12 Agu 2026 • 09:00 - 13:00 WIB',
          icon: Icons.photo_camera_outlined,
          tag: 'Terkonfirmasi',
          value: 'Studio Senayan',
        ),
        CreatorServiceItem(
          title: 'Prewedding - Rina & Budi',
          subtitle: '18 Agu 2026 • 15:00 - 18:00 WIB',
          icon: Icons.favorite_outline,
          tag: 'Menunggu',
          value: 'Ancol',
        ),
        CreatorServiceItem(
          title: 'Launching Toko Sinar Jaya',
          subtitle: '25 Agu 2026 • 10:00 - 14:00 WIB',
          icon: Icons.storefront_outlined,
          tag: 'Terkonfirmasi',
          value: 'Kelapa Gading',
        ),
        CreatorServiceItem(
          title: 'Portrait - Pak Adi',
          subtitle: '02 Sep 2026 • 09:00 - 10:30 WIB',
          icon: Icons.person_outline,
          tag: 'Terkonfirmasi',
          value: 'Studio Senayan',
        ),
      ],
    ),
    'foto_paket': CreatorServiceData(
      key: 'foto_paket',
      title: 'Paket Harga',
      subtitle: 'Layanan fotografi dengan harga transparan',
      icon: Icons.payments_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('3', 'Paket Aktif', Icons.card_membership_outlined),
        ('Rp 750K', 'Mulai Dari', Icons.price_change_outlined),
        ('±2 Hari', 'Estimasi Proses', Icons.schedule_outlined),
      ],
      actionLabel: 'Pilih Paket',
      items: [
        CreatorServiceItem(
          title: 'Paket Basic',
          subtitle: '1 jam sesi • 30 foto edit • 1 lokasi',
          icon: Icons.photo_outlined,
          tag: 'Populer',
          value: 'Rp 750.000',
        ),
        CreatorServiceItem(
          title: 'Paket Premium',
          subtitle: '3 jam sesi • 100 foto edit • 2 lokasi',
          icon: Icons.photo_camera_outlined,
          tag: 'Best Value',
          value: 'Rp 1.500.000',
        ),
        CreatorServiceItem(
          title: 'Paket Eksklusif',
          subtitle: '6 jam sesi • 250 foto edit • unlimited lokasi',
          icon: Icons.workspace_premium_outlined,
          tag: 'Premium',
          value: 'Rp 2.750.000',
        ),
      ],
    ),
    'foto_area': CreatorServiceData(
      key: 'foto_area',
      title: 'Cakupan Area',
      subtitle: 'Wilayah layanan & biaya transportasi',
      icon: Icons.location_on_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('12', 'Kota Dilayani', Icons.location_city_outlined),
        ('0-150 km', 'Jangkauan', Icons.social_distance_outlined),
        ('Gratis', 'Dari 0 km', Icons.celebration_outlined),
      ],
      items: [
        CreatorServiceItem(
          title: 'Jakarta & Sekitarnya',
          subtitle: 'Jangkauan 0 - 30 km',
          icon: Icons.location_city_outlined,
          tag: 'Aktif',
          value: 'Gratis',
        ),
        CreatorServiceItem(
          title: 'Bodetabek',
          subtitle: 'Jangkauan 30 - 60 km',
          icon: Icons.directions_car_outlined,
          tag: 'Aktif',
          value: 'Rp 150.000',
        ),
        CreatorServiceItem(
          title: 'Bandung & Jawa Barat',
          subtitle: 'Jangkauan 60 - 150 km',
          icon: Icons.landscape_outlined,
          tag: 'Aktif',
          value: 'Rp 350.000',
        ),
        CreatorServiceItem(
          title: 'Luar Pulau Jawa',
          subtitle: 'Perlu koordinasi khusus',
          icon: Icons.flight_takeoff_outlined,
          tag: 'Custom',
          value: 'Negosiasi',
        ),
      ],
    ),

    // ─── Videografer ───────────────────────────────────────────────
    'video_galeri': CreatorServiceData(
      key: 'video_galeri',
      title: 'Galeri Video',
      subtitle: 'Karya video & film terbaik',
      icon: Icons.videocam_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('36', 'Video', Icons.videocam_outlined),
        ('4.8', 'Rating', Icons.star_rounded),
        ('85+', 'Klien', Icons.people_outline),
      ],
      isGrid: true,
      items: [
        CreatorServiceItem(
          title: 'Video Company Profile',
          subtitle: 'Profil perusahaan berdurasi 2-3 menit',
          icon: Icons.business_outlined,
          tag: 'Korporat',
          value: '12 Proyek',
        ),
        CreatorServiceItem(
          title: 'Iklan & Promosi',
          subtitle: 'Video iklan untuk sosial media',
          icon: Icons.campaign_outlined,
          tag: 'Iklan',
          value: '18 Proyek',
        ),
        CreatorServiceItem(
          title: 'Dokumentasi Event',
          subtitle: 'Liputan video acara & konser',
          icon: Icons.mic_external_on_outlined,
          tag: 'Event',
          value: '10 Proyek',
        ),
        CreatorServiceItem(
          title: 'Video Musik',
          subtitle: 'MV & konten kreatif',
          icon: Icons.music_video_outlined,
          tag: 'Musik',
          value: '6 Proyek',
        ),
      ],
    ),
    'video_booking': CreatorServiceData(
      key: 'video_booking',
      title: 'Booking & Jadwal',
      subtitle: 'Kelola jadwal produksi video',
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('1', 'Hari Ini', Icons.today_outlined),
        ('4', 'Minggu Ini', Icons.date_range_outlined),
        ('2', 'Pending', Icons.pending_actions_outlined),
      ],
      actionLabel: 'Konfirmasi Booking',
      items: [
        CreatorServiceItem(
          title: 'Company Profile - PT Maju Bersama',
          subtitle: '13 Agu 2026 • 08:00 - 16:00 WIB',
          icon: Icons.business_outlined,
          tag: 'Terkonfirmasi',
          value: 'Kantor Klien',
        ),
        CreatorServiceItem(
          title: 'Iklan Produk - Kopi Senja',
          subtitle: '19 Agu 2026 • 09:00 - 15:00 WIB',
          icon: Icons.campaign_outlined,
          tag: 'Menunggu',
          value: 'Studio',
        ),
        CreatorServiceItem(
          title: 'Dokumentasi Festival Budaya',
          subtitle: '30 Agu 2026 • 07:00 - 22:00 WIB',
          icon: Icons.festival_outlined,
          tag: 'Terkonfirmasi',
          value: 'TMII',
        ),
      ],
    ),
    'video_paket': CreatorServiceData(
      key: 'video_paket',
      title: 'Paket Harga',
      subtitle: 'Produksi video sesuai kebutuhan',
      icon: Icons.payments_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('3', 'Paket Aktif', Icons.card_membership_outlined),
        ('Rp 1.5JT', 'Mulai Dari', Icons.price_change_outlined),
        ('3-7 Hari', 'Estimasi Produksi', Icons.schedule_outlined),
      ],
      actionLabel: 'Pilih Paket',
      items: [
        CreatorServiceItem(
          title: 'Paket Starter',
          subtitle: '1 video 60 detik • 1 lokasi • 1x revisi',
          icon: Icons.videocam_outlined,
          tag: 'Starter',
          value: 'Rp 1.500.000',
        ),
        CreatorServiceItem(
          title: 'Paket Profesional',
          subtitle: '2 video • 2 lokasi • unlimited revisi',
          icon: Icons.videocam_outlined,
          tag: 'Best Value',
          value: 'Rp 3.500.000',
        ),
        CreatorServiceItem(
          title: 'Paket Premium',
          subtitle: 'Full produksi • 3+ video • drone • tim lengkap',
          icon: Icons.workspace_premium_outlined,
          tag: 'Premium',
          value: 'Rp 7.500.000',
        ),
      ],
    ),
    'video_equipment': CreatorServiceData(
      key: 'video_equipment',
      title: 'Equipment',
      subtitle: 'Peralatan produksi yang dimiliki',
      icon: Icons.videocam_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('12', 'Unit Peralatan', Icons.cases_outlined),
        ('4K', 'Resolusi Maks', Icons.high_quality_outlined),
        ('2', 'Kamera', Icons.photo_camera_outlined),
      ],
      items: [
        CreatorServiceItem(
          title: 'Sony FX3 Full Frame',
          subtitle: 'Kamera sinema 4K 120fps',
          icon: Icons.camera_outlined,
          tag: 'Tersedia',
          value: '2 Unit',
        ),
        CreatorServiceItem(
          title: 'DJI Mavic 3 Pro',
          subtitle: 'Drone 4K dengan 3 lensa',
          icon: Icons.flight_outlined,
          tag: 'Tersedia',
          value: '1 Unit',
        ),
        CreatorServiceItem(
          title: 'Gimbal DJI RS 3 Pro',
          subtitle: 'Stabilizer profesional',
          icon: Icons.settings_remote_outlined,
          tag: 'Tersedia',
          value: '1 Unit',
        ),
        CreatorServiceItem(
          title: 'Lighting Set Profesional',
          subtitle: 'Aputure 600d + softbox',
          icon: Icons.light_mode_outlined,
          tag: 'Tersedia',
          value: '3 Set',
        ),
      ],
    ),

    // ─── Editor ────────────────────────────────────────────────────
    'edit_portofolio': CreatorServiceData(
      key: 'edit_portofolio',
      title: 'Portofolio Edit',
      subtitle: 'Hasil edit foto & video terbaik',
      icon: Icons.collections_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('250+', 'Project', Icons.folder_copy_outlined),
        ('4.9', 'Rating', Icons.star_rounded),
        ('48 jam', 'Rata-rata Turnaround', Icons.flash_on_rounded),
      ],
      isGrid: true,
      items: [
        CreatorServiceItem(
          title: 'Color Grading Sinematik',
          subtitle: 'Video 4K dengan tone sinematik',
          icon: Icons.movie_outlined,
          tag: 'Video',
          value: '80+ Proyek',
        ),
        CreatorServiceItem(
          title: 'Retouching Portrait',
          subtitle: 'Skin retouch natural & beauty',
          icon: Icons.face_retouching_natural_outlined,
          tag: 'Foto',
          value: '120+ Proyek',
        ),
        CreatorServiceItem(
          title: 'Motion Graphics',
          subtitle: 'Animasi logo & teks kreatif',
          icon: Icons.animation_outlined,
          tag: 'Video',
          value: '40+ Proyek',
        ),
        CreatorServiceItem(
          title: 'Manipulasi Foto',
          subtitle: 'Composite & manipulasi kreatif',
          icon: Icons.layers_outlined,
          tag: 'Foto',
          value: '35+ Proyek',
        ),
      ],
    ),
    'edit_antrian': CreatorServiceData(
      key: 'edit_antrian',
      title: 'Antrian Kerja',
      subtitle: 'Status pengerjaan proyek Anda',
      icon: Icons.list_alt_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('5', 'Dalam Antrian', Icons.query_builder_outlined),
        ('2', 'Sedang Dikerjakan', Icons.auto_awesome_motion_outlined),
        ('3', 'Menunggu Review', Icons.mark_email_unread_outlined),
      ],
      actionLabel: 'Perbarui Status',
      items: [
        CreatorServiceItem(
          title: 'Color Grading - Iklan Kopi Senja',
          subtitle: 'Dikirim 05 Agu • Deadlines 10 Agu',
          icon: Icons.movie_outlined,
          tag: 'Sedang Dikerjakan',
          value: '60%',
        ),
        CreatorServiceItem(
          title: 'Retouch - Wedding Rina & Budi',
          subtitle: 'Dikirim 06 Agu • Deadlines 12 Agu',
          icon: Icons.face_retouching_natural_outlined,
          tag: 'Dalam Antrian',
          value: 'Antrian #2',
        ),
        CreatorServiceItem(
          title: 'Motion - Company Profile PT Maju',
          subtitle: 'Dikirim 03 Agu • Menunggu review',
          icon: Icons.animation_outlined,
          tag: 'Menunggu Review',
          value: '100%',
        ),
        CreatorServiceItem(
          title: 'Manipulasi - Poster Launching',
          subtitle: 'Dikirim 04 Agu • Deadlines 09 Agu',
          icon: Icons.layers_outlined,
          tag: 'Selesai',
          value: 'Terunduh',
        ),
      ],
    ),
    'edit_harga': CreatorServiceData(
      key: 'edit_harga',
      title: 'Daftar Harga',
      subtitle: 'Tarif editing transparan',
      icon: Icons.payments_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('6', 'Layanan', Icons.miscellaneous_services_outlined),
        ('Rp 50K', 'Mulai Dari', Icons.price_change_outlined),
        ('24 jam', 'Express', Icons.flash_on_rounded),
      ],
      actionLabel: 'Pilih Layanan',
      items: [
        CreatorServiceItem(
          title: 'Retouching Foto Dasar',
          subtitle: 'Per foto • koreksi warna & clean up',
          icon: Icons.photo_outlined,
          tag: 'Per Foto',
          value: 'Rp 50.000',
        ),
        CreatorServiceItem(
          title: 'Color Grading Video',
          subtitle: 'Per menit video • tone & adjustment',
          icon: Icons.movie_outlined,
          tag: 'Per Menit',
          value: 'Rp 100.000',
        ),
        CreatorServiceItem(
          title: 'Editing Video Lengkap',
          subtitle: 'Per menit • cut, transisi, teks, musik',
          icon: Icons.videocam_outlined,
          tag: 'Per Menit',
          value: 'Rp 250.000',
        ),
        CreatorServiceItem(
          title: 'Motion Graphics',
          subtitle: 'Per proyek • animasi logo & teks',
          icon: Icons.animation_outlined,
          tag: 'Per Proyek',
          value: 'Rp 500.000',
        ),
      ],
    ),
    'edit_spesialisasi': CreatorServiceData(
      key: 'edit_spesialisasi',
      title: 'Spesialisasi',
      subtitle: 'Bidang keahlian editing',
      icon: Icons.tune_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('5', 'Bidang Ahli', Icons.workspace_premium_outlined),
        ('4.9', 'Rating Keahlian', Icons.star_rounded),
        ('3', 'Tools Utama', Icons.handyman_outlined),
      ],
      items: [
        CreatorServiceItem(
          title: 'Color Grading Sinematik',
          subtitle: 'DaVinci Resolve & Premiere Pro',
          icon: Icons.palette_outlined,
          tag: 'Expert',
          value: '92%',
        ),
        CreatorServiceItem(
          title: 'Retouching & Beauty',
          subtitle: 'Photoshop & Lightroom',
          icon: Icons.face_retouching_natural_outlined,
          tag: 'Advanced',
          value: '88%',
        ),
        CreatorServiceItem(
          title: 'Motion Graphics & VFX',
          subtitle: 'After Effects',
          icon: Icons.animation_outlined,
          tag: 'Advanced',
          value: '85%',
        ),
        CreatorServiceItem(
          title: 'Audio Mixing',
          subtitle: 'Audition & editing suara',
          icon: Icons.graphic_eq_outlined,
          tag: 'Intermediate',
          value: '75%',
        ),
      ],
    ),

    // ─── MC ────────────────────────────────────────────────────────
    'mc_profil': CreatorServiceData(
      key: 'mc_profil',
      title: 'Profil MC',
      subtitle: 'Profil profesional Master of Ceremony',
      icon: Icons.mic_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('7+', 'Tahun Pengalaman', Icons.work_history_outlined),
        ('150+', 'Acara', Icons.event_available_outlined),
        ('4.9', 'Rating', Icons.star_rounded),
      ],
      items: [
        CreatorServiceItem(
          title: 'Bahasa Pengantar',
          subtitle: 'Indonesia & Inggris (bilingual)',
          icon: Icons.translate_outlined,
          tag: 'Bilingual',
          value: 'Fluent',
        ),
        CreatorServiceItem(
          title: 'Gaya Membawakan Acara',
          subtitle: 'Formal, semi-formal, casual, hingga entertainer',
          icon: Icons.record_voice_over_outlined,
          tag: 'Fleksibel',
          value: '4 Gaya',
        ),
        CreatorServiceItem(
          title: 'Pelatihan & Sertifikasi',
          subtitle: 'Public speaking & MC profesional',
          icon: Icons.school_outlined,
          tag: 'Bersertifikat',
          value: '3 Sertifikat',
        ),
        CreatorServiceItem(
          title: 'Akomodasi Tambahan',
          subtitle: 'Sound system, konten, dan skenario acara',
          icon: Icons.volume_up_outlined,
          tag: 'Lengkap',
          value: 'Tersedia',
        ),
      ],
    ),
    'mc_booking': CreatorServiceData(
      key: 'mc_booking',
      title: 'Jadwal & Booking',
      subtitle: 'Jadwal tampil sebagai MC',
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('1', 'Hari Ini', Icons.today_outlined),
        ('3', 'Bulan Ini', Icons.date_range_outlined),
        ('2', 'Pending', Icons.pending_actions_outlined),
      ],
      actionLabel: 'Konfirmasi Booking',
      items: [
        CreatorServiceItem(
          title: 'MC Seminar Nasional Digital 2026',
          subtitle: '15 Agu 2026 • 08:00 - 16:00 WIB',
          icon: Icons.school_outlined,
          tag: 'Terkonfirmasi',
          value: 'Jakarta Convention Hall',
        ),
        CreatorServiceItem(
          title: 'MC Pernikahan Rina & Budi',
          subtitle: '22 Agu 2026 • 10:00 - 15:00 WIB',
          icon: Icons.favorite_outline,
          tag: 'Menunggu',
          value: 'Hotel Borobudur',
        ),
        CreatorServiceItem(
          title: 'MC Company Anniversary PT Maju',
          subtitle: '05 Sep 2026 • 18:00 - 22:00 WIB',
          icon: Icons.celebration_outlined,
          tag: 'Terkonfirmasi',
          value: 'Ballroom Ritz',
        ),
        CreatorServiceItem(
          title: 'MC Konser Amal Komunitas',
          subtitle: '20 Sep 2026 • 19:00 - 22:00 WIB',
          icon: Icons.music_note_outlined,
          tag: 'Menunggu',
          value: 'Gelora Bung Karno',
        ),
      ],
    ),
    'mc_kategori': CreatorServiceData(
      key: 'mc_kategori',
      title: 'Kategori Acara',
      subtitle: 'Jenis acara yang dilayani',
      icon: Icons.theater_comedy_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('8', 'Kategori', Icons.category_outlined),
        ('150+', 'Acara Ditangani', Icons.event_available_outlined),
        ('98%', 'Kepuasan', Icons.verified_outlined),
      ],
      items: [
        CreatorServiceItem(
          title: 'Seminar & Konferensi',
          subtitle: 'MC formal untuk acara korporat',
          icon: Icons.mic_external_on_outlined,
          tag: 'Sangat Mahir',
          value: '60+ Acara',
        ),
        CreatorServiceItem(
          title: 'Pernikahan & Resepsi',
          subtitle: 'MC wedding dengan konsep elegan',
          icon: Icons.favorite_outline,
          tag: 'Sangat Mahir',
          value: '45+ Acara',
        ),
        CreatorServiceItem(
          title: 'Konser & Hiburan',
          subtitle: 'MC entertainer dengan energi tinggi',
          icon: Icons.music_note_outlined,
          tag: 'Mahir',
          value: '25+ Acara',
        ),
        CreatorServiceItem(
          title: 'Launching Produk',
          subtitle: 'MC promosi & peluncuran produk',
          icon: Icons.rocket_launch_outlined,
          tag: 'Mahir',
          value: '20+ Acara',
        ),
      ],
    ),
    'mc_tarif': CreatorServiceData(
      key: 'mc_tarif',
      title: 'Tarif',
      subtitle: 'Tarif layanan MC profesional',
      icon: Icons.payments_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('3', 'Kategori Tarif', Icons.receipt_long_outlined),
        ('Rp 2JT', 'Mulai Dari', Icons.price_change_outlined),
        ('Termasuk', 'Sound System', Icons.volume_up_outlined),
      ],
      actionLabel: 'Pilih Paket',
      items: [
        CreatorServiceItem(
          title: 'Paket 3 Jam',
          subtitle: 'Acara lokal • ≤ 200 tamu',
          icon: Icons.schedule_outlined,
          tag: 'Populer',
          value: 'Rp 2.000.000',
        ),
        CreatorServiceItem(
          title: 'Paket 6 Jam',
          subtitle: 'Acara besar • ≤ 500 tamu',
          icon: Icons.av_timer_outlined,
          tag: 'Best Value',
          value: 'Rp 3.500.000',
        ),
        CreatorServiceItem(
          title: 'Full Day / Event Spesial',
          subtitle: 'Lebih dari 6 jam • custom kebutuhan',
          icon: Icons.workspace_premium_outlined,
          tag: 'Premium',
          value: 'Rp 5.000.000',
        ),
      ],
    ),

    // ─── Penyanyi ──────────────────────────────────────────────────
    'singer_portofolio': CreatorServiceData(
      key: 'singer_portofolio',
      title: 'Portofolio Musik',
      subtitle: 'Penampilan & karya musik',
      icon: Icons.music_note_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('80+', 'Penampilan', Icons.music_note_outlined),
        ('4.8', 'Rating', Icons.star_rounded),
        ('5', 'Single Rilis', Icons.album_outlined),
      ],
      isGrid: true,
      items: [
        CreatorServiceItem(
          title: 'Live Performance Acoustic',
          subtitle: 'Set akustik untuk cafe & restoran',
          icon: Icons.music_note_outlined,
          tag: 'Live',
          value: '50+ Tampil',
        ),
        CreatorServiceItem(
          title: 'Wedding Performance',
          subtitle: 'Solo & band untuk pernikahan',
          icon: Icons.favorite_outline,
          tag: 'Wedding',
          value: '20+ Tampil',
        ),
        CreatorServiceItem(
          title: 'Konser & Festival',
          subtitle: 'Panggung utama festival musik',
          icon: Icons.festival_outlined,
          tag: 'Festival',
          value: '10+ Tampil',
        ),
        CreatorServiceItem(
          title: 'Single Original',
          subtitle: 'Karya original di platform musik',
          icon: Icons.album_outlined,
          tag: 'Original',
          value: '5 Single',
        ),
      ],
    ),
    'singer_booking': CreatorServiceData(
      key: 'singer_booking',
      title: 'Jadwal & Booking',
      subtitle: 'Jadwal penampilan Anda',
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('1', 'Hari Ini', Icons.today_outlined),
        ('4', 'Bulan Ini', Icons.date_range_outlined),
        ('1', 'Pending', Icons.pending_actions_outlined),
      ],
      actionLabel: 'Konfirmasi Booking',
      items: [
        CreatorServiceItem(
          title: 'Acoustic Night - Kopi Senja',
          subtitle: '14 Agu 2026 • 19:00 - 21:00 WIB',
          icon: Icons.coffee_outlined,
          tag: 'Terkonfirmasi',
          value: 'Kemang',
        ),
        CreatorServiceItem(
          title: 'Wedding Reception - Maya & Rio',
          subtitle: '23 Agu 2026 • 18:00 - 21:00 WIB',
          icon: Icons.favorite_outline,
          tag: 'Menunggu',
          value: 'Ritz Ballroom',
        ),
        CreatorServiceItem(
          title: 'Festival Musik Nusantara',
          subtitle: '07 Sep 2026 • 15:00 - 16:00 WIB',
          icon: Icons.festival_outlined,
          tag: 'Terkonfirmasi',
          value: 'GBK',
        ),
      ],
    ),
    'singer_genre': CreatorServiceData(
      key: 'singer_genre',
      title: 'Genre & Repertoar',
      subtitle: 'Genre musik & daftar lagu',
      icon: Icons.library_music_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('6', 'Genre', Icons.category_outlined),
        ('120+', 'Lagu Siap Bawakan', Icons.queue_music_outlined),
        ('EN/ID', 'Bahasa Lagu', Icons.translate_outlined),
      ],
      items: [
        CreatorServiceItem(
          title: 'Pop & Ballad',
          subtitle: 'Lagu pop Indonesia & internasional',
          icon: Icons.music_note_outlined,
          tag: 'Andalan',
          value: '40+ Lagu',
        ),
        CreatorServiceItem(
          title: 'Acoustic & Jazz',
          subtitle: 'Aransemen akustik & jazz',
          icon: Icons.piano_outlined,
          tag: 'Specialty',
          value: '30+ Lagu',
        ),
        CreatorServiceItem(
          title: 'Dangdut & Koplo',
          subtitle: 'Untuk acara hiburan & panggung',
          icon: Icons.music_note_outlined,
          tag: 'Populer',
          value: '25+ Lagu',
        ),
        CreatorServiceItem(
          title: 'Religi & Klasik',
          subtitle: 'Untuk acara formal & rohani',
          icon: Icons.church_outlined,
          tag: 'Tersedia',
          value: '20+ Lagu',
        ),
      ],
    ),
    'singer_tarif': CreatorServiceData(
      key: 'singer_tarif',
      title: 'Tarif',
      subtitle: 'Tarif penampilan profesional',
      icon: Icons.payments_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('3', 'Kategori Tarif', Icons.receipt_long_outlined),
        ('Rp 1.5JT', 'Mulai Dari', Icons.price_change_outlined),
        ('Bawaan', 'Backing Track', Icons.music_video_outlined),
      ],
      actionLabel: 'Pilih Paket',
      items: [
        CreatorServiceItem(
          title: 'Acoustic Set 2 Jam',
          subtitle: 'Solo performance + instrument',
          icon: Icons.music_note_outlined,
          tag: 'Solo',
          value: 'Rp 1.500.000',
        ),
        CreatorServiceItem(
          title: 'Full Band 3 Jam',
          subtitle: 'Vocal + band 4 orang',
          icon: Icons.album_outlined,
          tag: 'Best Value',
          value: 'Rp 3.000.000',
        ),
        CreatorServiceItem(
          title: 'Event Spesial & Konser',
          subtitle: 'Custom kebutuhan & durasi',
          icon: Icons.festival_outlined,
          tag: 'Premium',
          value: 'Rp 5.000.000+',
        ),
      ],
    ),

    // ─── MUA ───────────────────────────────────────────────────────
    'mua_portofolio': CreatorServiceData(
      key: 'mua_portofolio',
      title: 'Portofolio MUA',
      subtitle: 'Hasil rias wajah terbaik',
      icon: Icons.face_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('120+', 'Klien', Icons.people_outline),
        ('4.9', 'Rating', Icons.star_rounded),
        ('6+', 'Tahun', Icons.work_history_outlined),
      ],
      isGrid: true,
      items: [
        CreatorServiceItem(
          title: 'Makeup Bridal',
          subtitle: 'Rias pengantin adat & modern',
          icon: Icons.favorite_outline,
          tag: 'Bridal',
          value: '40+ Klien',
        ),
        CreatorServiceItem(
          title: 'Makeup Pesta',
          subtitle: 'Rias pesta & wisuda',
          icon: Icons.celebration_outlined,
          tag: 'Party',
          value: '50+ Klien',
        ),
        CreatorServiceItem(
          title: 'Makeup Editorial',
          subtitle: 'Rias untuk foto & video',
          icon: Icons.photo_camera_outlined,
          tag: 'Editorial',
          value: '20+ Klien',
        ),
        CreatorServiceItem(
          title: 'Soft Glam Daily',
          subtitle: 'Rias natural sehari-hari',
          icon: Icons.face_outlined,
          tag: 'Daily',
          value: '30+ Klien',
        ),
      ],
    ),
    'mua_booking': CreatorServiceData(
      key: 'mua_booking',
      title: 'Jadwal Booking',
      subtitle: 'Jadwal rias Anda',
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('1', 'Hari Ini', Icons.today_outlined),
        ('3', 'Minggu Ini', Icons.date_range_outlined),
        ('2', 'Pending', Icons.pending_actions_outlined),
      ],
      actionLabel: 'Konfirmasi Booking',
      items: [
        CreatorServiceItem(
          title: 'MUA Bridal - Rina & Budi',
          subtitle: '16 Agu 2026 • 04:00 - 09:00 WIB',
          icon: Icons.favorite_outline,
          tag: 'Terkonfirmasi',
          value: 'Salon Rina',
        ),
        CreatorServiceItem(
          title: 'Makeup Wisuda - Siti A.',
          subtitle: '21 Agu 2026 • 06:00 - 08:30 WIB',
          icon: Icons.school_outlined,
          tag: 'Menunggu',
          value: 'Rumah Klien',
        ),
        CreatorServiceItem(
          title: 'Editorial Shoot - Majalah Mode',
          subtitle: '28 Agu 2026 • 09:00 - 15:00 WIB',
          icon: Icons.photo_camera_outlined,
          tag: 'Terkonfirmasi',
          value: 'Studio 21',
        ),
      ],
    ),
    'mua_paket': CreatorServiceData(
      key: 'mua_paket',
      title: 'Paket Harga',
      subtitle: 'Paket rias sesuai kebutuhan',
      icon: Icons.payments_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('3', 'Paket Aktif', Icons.card_membership_outlined),
        ('Rp 350K', 'Mulai Dari', Icons.price_change_outlined),
        ('Dengan', 'Produk Premium', Icons.health_and_safety_outlined),
      ],
      actionLabel: 'Pilih Paket',
      items: [
        CreatorServiceItem(
          title: 'Paket Soft Glam',
          subtitle: 'Rias natural • 60 menit',
          icon: Icons.face_outlined,
          tag: 'Populer',
          value: 'Rp 350.000',
        ),
        CreatorServiceItem(
          title: 'Paket Party Glam',
          subtitle: 'Rias tahan lama • 90 menit + lashes',
          icon: Icons.celebration_outlined,
          tag: 'Best Value',
          value: 'Rp 550.000',
        ),
        CreatorServiceItem(
          title: 'Paket Bridal Premium',
          subtitle: 'Rias pengantin + trial + setting',
          icon: Icons.workspace_premium_outlined,
          tag: 'Premium',
          value: 'Rp 1.500.000',
        ),
      ],
    ),
    'mua_spesialisasi': CreatorServiceData(
      key: 'mua_spesialisasi',
      title: 'Spesialisasi',
      subtitle: 'Keahlian rias & teknik',
      icon: Icons.palette_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('5', 'Spesialisasi', Icons.category_outlined),
        ('4.9', 'Rating', Icons.star_rounded),
        ('12', 'Brand Kosmetik', Icons.shopping_bag_outlined),
      ],
      items: [
        CreatorServiceItem(
          title: 'Bridal & Engagement',
          subtitle: 'Rias pengantin adat & modern',
          icon: Icons.favorite_outline,
          tag: 'Expert',
          value: '40+ Klien',
        ),
        CreatorServiceItem(
          title: 'Editorial & Commercial',
          subtitle: 'Rias untuk shooting profesional',
          icon: Icons.photo_camera_outlined,
          tag: 'Advanced',
          value: '20+ Proyek',
        ),
        CreatorServiceItem(
          title: 'Special Effects (SFX)',
          subtitle: 'Rias efek khusus & karakter',
          icon: Icons.auto_awesome_outlined,
          tag: 'Advanced',
          value: '10+ Proyek',
        ),
        CreatorServiceItem(
          title: 'Hijab & Muslimah',
          subtitle: 'Rias khsus pengantin muslimah',
          icon: Icons.volunteer_activism_outlined,
          tag: 'Expert',
          value: '30+ Klien',
        ),
      ],
    ),

    // ─── Wedding Organizer ─────────────────────────────────────────
    'wo_paket': CreatorServiceData(
      key: 'wo_paket',
      title: 'Paket Pernikahan',
      subtitle: 'Paket pernikahan lengkap',
      icon: Icons.favorite_outline,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('3', 'Paket Aktif', Icons.card_membership_outlined),
        ('250+', 'Pernikahan', Icons.favorite_border_outlined),
        ('4.9', 'Rating', Icons.star_rounded),
      ],
      actionLabel: 'Pilih Paket',
      items: [
        CreatorServiceItem(
          title: 'Paket Sakura',
          subtitle: 'Akad + resepsi • 300 tamu • 5 vendor',
          icon: Icons.favorite_outline,
          tag: 'Populer',
          value: 'Rp 25.000.000',
        ),
        CreatorServiceItem(
          title: 'Paket Premium',
          subtitle: 'Akad + resepsi + prewedding • 500 tamu',
          icon: Icons.workspace_premium_outlined,
          tag: 'Premium',
          value: 'Rp 50.000.000',
        ),
        CreatorServiceItem(
          title: 'Paket Intimate',
          subtitle: 'Acara privat • 100 tamu • 3 vendor',
          icon: Icons.favorite_border_outlined,
          tag: 'Intimate',
          value: 'Rp 15.000.000',
        ),
      ],
    ),
    'wo_jadwal': CreatorServiceData(
      key: 'wo_jadwal',
      title: 'Jadwal Event',
      subtitle: 'Jadwal pernikahan yang ditangani',
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('1', 'Bulan Ini', Icons.today_outlined),
        ('2', 'Bulan Depan', Icons.date_range_outlined),
        ('1', 'Pending', Icons.pending_actions_outlined),
      ],
      actionLabel: 'Kelola Jadwal',
      items: [
        CreatorServiceItem(
          title: 'Pernikahan Rina & Budi',
          subtitle: '22 Agu 2026 • Akad 08:00 • Resepsi 12:00',
          icon: Icons.favorite_outline,
          tag: 'Aktif',
          value: 'Hotel Borobudur',
        ),
        CreatorServiceItem(
          title: 'Pernikahan Maya & Rio',
          subtitle: '13 Sep 2026 • Akad 09:00 • Resepsi 18:00',
          icon: Icons.favorite_outline,
          tag: 'Persiapan',
          value: 'Ritz Ballroom',
        ),
        CreatorServiceItem(
          title: 'Pernikahan Dewi & Andi',
          subtitle: '27 Sep 2026 • Akad 07:00 • Resepsi 13:00',
          icon: Icons.favorite_outline,
          tag: 'Menunggu',
          value: 'Balai Kartini',
        ),
      ],
    ),
    'wo_vendor': CreatorServiceData(
      key: 'wo_vendor',
      title: 'Vendor Partner',
      subtitle: 'Jaringan vendor tepercaya',
      icon: Icons.handshake_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('25', 'Vendor Aktif', Icons.business_outlined),
        ('8', 'Kategori', Icons.category_outlined),
        ('98%', 'Ketepatan', Icons.verified_outlined),
      ],
      items: [
        CreatorServiceItem(
          title: 'Catering Dapur Nusantara',
          subtitle: 'Catering & wedding cake',
          icon: Icons.restaurant_outlined,
          tag: 'Aktif',
          value: '150+ Event',
        ),
        CreatorServiceItem(
          title: 'Dekorasi Floral Art',
          subtitle: 'Dekorasi & florist',
          icon: Icons.local_florist_outlined,
          tag: 'Aktif',
          value: '200+ Event',
        ),
        CreatorServiceItem(
          title: 'Venue Collection',
          subtitle: 'Hotel & gedung pernikahan',
          icon: Icons.apartment_outlined,
          tag: 'Aktif',
          value: '40 Venue',
        ),
        CreatorServiceItem(
          title: 'Entertainment Pro',
          subtitle: 'MC, band, & hiburan',
          icon: Icons.mic_external_on_outlined,
          tag: 'Aktif',
          value: '30+ Talent',
        ),
      ],
    ),
    'wo_timeline': CreatorServiceData(
      key: 'wo_timeline',
      title: 'Timeline WO',
      subtitle: 'Alur kerja pernikahan',
      icon: Icons.timeline_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('6', 'Tahapan', Icons.view_list_outlined),
        ('H-90', 'Mulai Persiapan', Icons.query_builder_outlined),
        ('100%', 'Acara Tepat Waktu', Icons.event_available_outlined),
      ],
      items: [
        CreatorServiceItem(
          title: 'H-90: Konsultasi & Kontrak',
          subtitle: 'Diskusi kebutuhan & penandatanganan',
          icon: Icons.edit_outlined,
          tag: 'Selesai',
          value: 'Tahap 1',
        ),
        CreatorServiceItem(
          title: 'H-60: Booking Vendor',
          subtitle: 'Venue, catering, dekorasi, dokumentasi',
          icon: Icons.handshake_outlined,
          tag: 'Selesai',
          value: 'Tahap 2',
        ),
        CreatorServiceItem(
          title: 'H-30: Fitting & Trial',
          subtitle: 'Trial makeup & fitting baju',
          icon: Icons.checkroom_outlined,
          tag: 'Berjalan',
          value: 'Tahap 3',
        ),
        CreatorServiceItem(
          title: 'H-7: Gladi Bersih',
          subtitle: 'Simulasi akad & resepsi',
          icon: Icons.fact_check_outlined,
          tag: 'Berjalan',
          value: 'Tahap 4',
        ),
        CreatorServiceItem(
          title: 'H-Day: Eksekusi',
          subtitle: 'Koordinasi penuh di hari H',
          icon: Icons.celebration_outlined,
          tag: 'Berjalan',
          value: 'Tahap 5',
        ),
        CreatorServiceItem(
          title: 'H+7: Evaluasi',
          subtitle: 'Serah terima album & evaluasi',
          icon: Icons.assignment_turned_in_outlined,
          tag: 'Selesai',
          value: 'Tahap 6',
        ),
      ],
    ),

    // ─── Event Organizer ───────────────────────────────────────────
    'eo_paket': CreatorServiceData(
      key: 'eo_paket',
      title: 'Paket Event',
      subtitle: 'Paket penyelenggaraan event',
      icon: Icons.festival_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('3', 'Paket Aktif', Icons.card_membership_outlined),
        ('80+', 'Event', Icons.event_available_outlined),
        ('4.8', 'Rating', Icons.star_rounded),
      ],
      actionLabel: 'Pilih Paket',
      items: [
        CreatorServiceItem(
          title: 'Paket Corporate',
          subtitle: 'Seminar & gathering • 200 peserta',
          icon: Icons.business_outlined,
          tag: 'Populer',
          value: 'Rp 35.000.000',
        ),
        CreatorServiceItem(
          title: 'Paket Festival',
          subtitle: 'Festival & konser • 1000+ pengunjung',
          icon: Icons.festival_outlined,
          tag: 'Premium',
          value: 'Rp 75.000.000',
        ),
        CreatorServiceItem(
          title: 'Paket Private',
          subtitle: 'Ultah & gathering privat • 100 tamu',
          icon: Icons.celebration_outlined,
          tag: 'Intimate',
          value: 'Rp 15.000.000',
        ),
      ],
    ),
    'eo_jadwal': CreatorServiceData(
      key: 'eo_jadwal',
      title: 'Jadwal Event',
      subtitle: 'Jadwal event yang ditangani',
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('2', 'Bulan Ini', Icons.today_outlined),
        ('3', 'Bulan Depan', Icons.date_range_outlined),
        ('2', 'Pending', Icons.pending_actions_outlined),
      ],
      actionLabel: 'Kelola Jadwal',
      items: [
        CreatorServiceItem(
          title: 'Seminar Digitalisasi UMKM',
          subtitle: '18 Agu 2026 • 09:00 - 17:00 WIB',
          icon: Icons.school_outlined,
          tag: 'Aktif',
          value: 'JCC',
        ),
        CreatorServiceItem(
          title: 'Festival Musik Nusantara',
          subtitle: '07 Sep 2026 • 12:00 - 22:00 WIB',
          icon: Icons.festival_outlined,
          tag: 'Persiapan',
          value: 'GBK',
        ),
        CreatorServiceItem(
          title: 'Launching Produk Tech',
          subtitle: '21 Sep 2026 • 10:00 - 16:00 WIB',
          icon: Icons.rocket_launch_outlined,
          tag: 'Menunggu',
          value: 'Jakarta Creative Hub',
        ),
        CreatorServiceItem(
          title: 'Company Anniversary PT Maju',
          subtitle: '05 Okt 2026 • 18:00 - 22:00 WIB',
          icon: Icons.celebration_outlined,
          tag: 'Menunggu',
          value: 'Ballroom Ritz',
        ),
      ],
    ),
    'eo_vendor': CreatorServiceData(
      key: 'eo_vendor',
      title: 'Vendor Partner',
      subtitle: 'Jaringan vendor event',
      icon: Icons.handshake_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('30', 'Vendor Aktif', Icons.business_outlined),
        ('10', 'Kategori', Icons.category_outlined),
        ('95%', 'Ketepatan', Icons.verified_outlined),
      ],
      items: [
        CreatorServiceItem(
          title: 'Stage & Lighting Pro',
          subtitle: 'Sound system, lighting, panggung',
          icon: Icons.light_mode_outlined,
          tag: 'Aktif',
          value: '120+ Event',
        ),
        CreatorServiceItem(
          title: 'Catering Nusantara',
          subtitle: 'Katering & konsumsi peserta',
          icon: Icons.restaurant_outlined,
          tag: 'Aktif',
          value: '90+ Event',
        ),
        CreatorServiceItem(
          title: 'Ticketing & Registrasi',
          subtitle: 'Sistem tiket & check-in',
          icon: Icons.confirmation_number_outlined,
          tag: 'Aktif',
          value: '60+ Event',
        ),
        CreatorServiceItem(
          title: 'Keamanan & Medis',
          subtitle: 'Petugas keamanan & ambulance',
          icon: Icons.health_and_safety_outlined,
          tag: 'Aktif',
          value: '40+ Event',
        ),
      ],
    ),
    'eo_timeline': CreatorServiceData(
      key: 'eo_timeline',
      title: 'Timeline EO',
      subtitle: 'Alur kerja penyelenggaraan event',
      icon: Icons.timeline_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('6', 'Tahapan', Icons.view_list_outlined),
        ('H-60', 'Mulai Persiapan', Icons.query_builder_outlined),
        ('100%', 'Event Tepat Waktu', Icons.event_available_outlined),
      ],
      items: [
        CreatorServiceItem(
          title: 'H-60: Brief & Konsep',
          subtitle: 'Diskusi kebutuhan & proposal',
          icon: Icons.edit_outlined,
          tag: 'Selesai',
          value: 'Tahap 1',
        ),
        CreatorServiceItem(
          title: 'H-45: Vendor & Venue',
          subtitle: 'Booking vendor & perizinan',
          icon: Icons.handshake_outlined,
          tag: 'Selesai',
          value: 'Tahap 2',
        ),
        CreatorServiceItem(
          title: 'H-21: Promosi & Tiket',
          subtitle: 'Marketing event & penjualan tiket',
          icon: Icons.campaign_outlined,
          tag: 'Berjalan',
          value: 'Tahap 3',
        ),
        CreatorServiceItem(
          title: 'H-7: Finalisasi',
          subtitle: 'Gladi bersih & teknis',
          icon: Icons.fact_check_outlined,
          tag: 'Berjalan',
          value: 'Tahap 4',
        ),
        CreatorServiceItem(
          title: 'H-Day: Eksekusi',
          subtitle: 'Operasional event penuh',
          icon: Icons.celebration_outlined,
          tag: 'Berjalan',
          value: 'Tahap 5',
        ),
        CreatorServiceItem(
          title: 'H+7: Laporan',
          subtitle: 'Laporan & evaluasi klien',
          icon: Icons.assignment_turned_in_outlined,
          tag: 'Selesai',
          value: 'Tahap 6',
        ),
      ],
    ),

    // ─── Komunitas ─────────────────────────────────────────────────
    'komunitas_anggota': CreatorServiceData(
      key: 'komunitas_anggota',
      title: 'Anggota',
      subtitle: 'Kelola keanggotaan komunitas',
      icon: Icons.groups_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('1.240', 'Anggota', Icons.people_outline),
        ('85', 'Aktif Minggu Ini', Icons.how_to_reg_outlined),
        ('12', 'Pengurus', Icons.admin_panel_settings_outlined),
      ],
      items: [
        CreatorServiceItem(
          title: 'Pengurus Inti',
          subtitle: 'Ketua, sekretaris, bendahara',
          icon: Icons.admin_panel_settings_outlined,
          tag: '12 Orang',
          value: 'Aktif',
        ),
        CreatorServiceItem(
          title: 'Anggota Aktif',
          subtitle: 'Kontributor kegiatan rutin',
          icon: Icons.people_outline,
          tag: '240 Orang',
          value: 'Aktif',
        ),
        CreatorServiceItem(
          title: 'Anggota Baru (Bulan Ini)',
          subtitle: 'Pendaftar anggota baru',
          icon: Icons.person_add_alt_outlined,
          tag: '35 Orang',
          value: 'Diproses',
        ),
        CreatorServiceItem(
          title: 'Anggota Tidak Aktif',
          subtitle: 'Tidak aktif 90+ hari',
          icon: Icons.person_off_outlined,
          tag: '18 Orang',
          value: 'Perlu Follow-up',
        ),
      ],
    ),
    'komunitas_kegiatan': CreatorServiceData(
      key: 'komunitas_kegiatan',
      title: 'Kegiatan',
      subtitle: 'Agenda kegiatan komunitas',
      icon: Icons.event_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('3', 'Minggu Ini', Icons.today_outlined),
        ('5', 'Bulan Ini', Icons.date_range_outlined),
        ('2', 'Rutin', Icons.repeat_outlined),
      ],
      actionLabel: 'Daftar Kegiatan',
      items: [
        CreatorServiceItem(
          title: 'Kopi Darat Bulanan',
          subtitle: '16 Agu 2026 • 10:00 - 12:00 WIB',
          icon: Icons.coffee_outlined,
          tag: 'Rutin',
          value: '12 Peserta',
        ),
        CreatorServiceItem(
          title: 'Workshop Fotografi Dasar',
          subtitle: '23 Agu 2026 • 09:00 - 15:00 WIB',
          icon: Icons.camera_outlined,
          tag: 'Workshop',
          value: '30 Peserta',
        ),
        CreatorServiceItem(
          title: 'Bakti Sosial Komunitas',
          subtitle: '30 Agu 2026 • 07:00 - 14:00 WIB',
          icon: Icons.volunteer_activism_outlined,
          tag: 'Sosial',
          value: '50 Peserta',
        ),
        CreatorServiceItem(
          title: 'Pameran Karya Anggota',
          subtitle: '12 Sep 2026 • 10:00 - 20:00 WIB',
          icon: Icons.palette_outlined,
          tag: 'Bulanan',
          value: '100+ Peserta',
        ),
      ],
    ),
    'komunitas_pengumuman': CreatorServiceData(
      key: 'komunitas_pengumuman',
      title: 'Pengumuman',
      subtitle: 'Informasi & pengumuman komunitas',
      icon: Icons.campaign_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('2', 'Penting', Icons.priority_high_outlined),
        ('5', 'Minggu Ini', Icons.mark_email_unread_outlined),
        ('12', 'Total', Icons.inbox_outlined),
      ],
      actionLabel: 'Lihat Detail',
      items: [
        CreatorServiceItem(
          title: 'Pendaftaran Pengurus Baru',
          subtitle: 'Dibuka sampai 20 Agu 2026',
          icon: Icons.how_to_reg_outlined,
          tag: 'Penting',
          value: '2 Hari Lagi',
        ),
        CreatorServiceItem(
          title: 'Perubahan Jadwal Kopdar',
          subtitle: 'Kopdar pindah ke 23 Agu 2026',
          icon: Icons.update_outlined,
          tag: 'Info',
          value: 'Baca',
        ),
        CreatorServiceItem(
          title: 'Pengumuman Sponsor Baru',
          subtitle: 'Kerjasama dengan Brand XYZ',
          icon: Icons.handshake_outlined,
          tag: 'Info',
          value: 'Baca',
        ),
        CreatorServiceItem(
          title: 'Rekap Kegiatan Juli 2026',
          subtitle: 'Laporan kegiatan bulan lalu',
          icon: Icons.summarize_outlined,
          tag: 'Rekap',
          value: 'Baca',
        ),
      ],
    ),
    'komunitas_kolaborasi': CreatorServiceData(
      key: 'komunitas_kolaborasi',
      title: 'Kolaborasi Komunitas',
      subtitle: 'Kerjasama dengan pihak lain',
      icon: Icons.handshake_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('5', 'Kolaborasi', Icons.link_outlined),
        ('3', 'Aktif', Icons.play_circle_outline),
        ('2', 'Selesai', Icons.check_circle_outline),
      ],
      actionLabel: 'Ajukan Kolaborasi',
      items: [
        CreatorServiceItem(
          title: 'Kolaborasi Brand XYZ',
          subtitle: 'Konten bersama 3 bulan',
          icon: Icons.branding_watermark_outlined,
          tag: 'Aktif',
          value: 'Sampai Okt 2026',
        ),
        CreatorServiceItem(
          title: 'Kolaborasi Komunitas Fotografi',
          subtitle: 'Pameran karya bersama',
          icon: Icons.camera_outlined,
          tag: 'Aktif',
          value: '12 Sep 2026',
        ),
        CreatorServiceItem(
          title: 'CSR Perusahaan ABC',
          subtitle: 'Program pelatihan anggota',
          icon: Icons.volunteer_activism_outlined,
          tag: 'Menunggu',
          value: 'Proposal',
        ),
        CreatorServiceItem(
          title: 'Bazaar UMKM Bersama',
          subtitle: 'Event tahunan komunitas',
          icon: Icons.storefront_outlined,
          tag: 'Selesai',
          value: 'Feb 2026',
        ),
      ],
    ),

    // ─── Desainer ──────────────────────────────────────────────────
    'desain_portofolio': CreatorServiceData(
      key: 'desain_portofolio',
      title: 'Portofolio Desain',
      subtitle: 'Karya desain grafis & branding',
      icon: Icons.palette_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('90+', 'Proyek', Icons.folder_copy_outlined),
        ('4.9', 'Rating', Icons.star_rounded),
        ('60+', 'Klien', Icons.people_outline),
      ],
      isGrid: true,
      items: [
        CreatorServiceItem(
          title: 'Desain Logo & Branding',
          subtitle: 'Identitas visual brand',
          icon: Icons.branding_watermark_outlined,
          tag: 'Branding',
          value: '35+ Proyek',
        ),
        CreatorServiceItem(
          title: 'Desain Kemasan',
          subtitle: 'Kemasan produk yang menarik',
          icon: Icons.inventory_2_outlined,
          tag: 'Packaging',
          value: '25+ Proyek',
        ),
        CreatorServiceItem(
          title: 'UI/UX Design',
          subtitle: 'Desain aplikasi & website',
          icon: Icons.design_services_outlined,
          tag: 'Digital',
          value: '18+ Proyek',
        ),
        CreatorServiceItem(
          title: 'Poster & Konten Visual',
          subtitle: 'Konten sosial media & promosi',
          icon: Icons.brush_outlined,
          tag: 'Konten',
          value: '40+ Proyek',
        ),
        CreatorServiceItem(
          title: 'Ilustrasi Digital',
          subtitle: 'Ilustrasi custom & karakter',
          icon: Icons.auto_awesome_outlined,
          tag: 'Ilustrasi',
          value: '12+ Proyek',
        ),
      ],
    ),
    'desain_proyek': CreatorServiceData(
      key: 'desain_proyek',
      title: 'Proyek & Brief',
      subtitle: 'Proyek desain yang sedang berjalan',
      icon: Icons.assignment_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('4', 'Aktif', Icons.auto_awesome_motion_outlined),
        ('2', 'Review', Icons.mark_email_unread_outlined),
        ('3', 'Selesai', Icons.check_circle_outline),
      ],
      actionLabel: 'Perbarui Status',
      items: [
        CreatorServiceItem(
          title: 'Rebranding - Kopi Senja',
          subtitle: 'Brief diterima 05 Agu • 2x revisi',
          icon: Icons.branding_watermark_outlined,
          tag: 'Sedang Dikerjakan',
          value: '70%',
        ),
        CreatorServiceItem(
          title: 'Kemasan Produk - UMKM Madu',
          subtitle: 'Brief diterima 07 Agu • 1x revisi',
          icon: Icons.inventory_2_outlined,
          tag: 'Dalam Antrian',
          value: 'Antrian #1',
        ),
        CreatorServiceItem(
          title: 'UI/UX - Aplikasi Pesantren',
          subtitle: 'Brief diterima 02 Agu • menunggu review',
          icon: Icons.design_services_outlined,
          tag: 'Menunggu Review',
          value: '100%',
        ),
        CreatorServiceItem(
          title: 'Poster Launching - Brand ABC',
          subtitle: 'Brief diterima 28 Jul • terkirim',
          icon: Icons.brush_outlined,
          tag: 'Selesai',
          value: 'Terunduh',
        ),
      ],
    ),
    'desain_paket': CreatorServiceData(
      key: 'desain_paket',
      title: 'Paket Desain',
      subtitle: 'Layanan desain dengan harga jelas',
      icon: Icons.payments_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('4', 'Layanan', Icons.miscellaneous_services_outlined),
        ('Rp 250K', 'Mulai Dari', Icons.price_change_outlined),
        ('3 Hari', 'Rata-rata', Icons.schedule_outlined),
      ],
      actionLabel: 'Pilih Paket',
      items: [
        CreatorServiceItem(
          title: 'Paket Logo Dasar',
          subtitle: '3 konsep • 2x revisi • file siap cetak',
          icon: Icons.branding_watermark_outlined,
          tag: 'Populer',
          value: 'Rp 750.000',
        ),
        CreatorServiceItem(
          title: 'Paket Branding Lengkap',
          subtitle: 'Logo + 5 media sosial + kartu nama',
          icon: Icons.palette_outlined,
          tag: 'Best Value',
          value: 'Rp 2.500.000',
        ),
        CreatorServiceItem(
          title: 'Paket Desain Kemasan',
          subtitle: 'Kemasan produk + mockup 3D',
          icon: Icons.inventory_2_outlined,
          tag: 'Produk',
          value: 'Rp 1.800.000',
        ),
        CreatorServiceItem(
          title: 'UI/UX Screen',
          subtitle: 'Per layar • prototipe interaktif',
          icon: Icons.design_services_outlined,
          tag: 'Per Screen',
          value: 'Rp 350.000',
        ),
      ],
    ),
    'desain_spesialisasi': CreatorServiceData(
      key: 'desain_spesialisasi',
      title: 'Spesialisasi',
      subtitle: 'Bidang keahlian desain',
      icon: Icons.tune_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('5', 'Bidang', Icons.category_outlined),
        ('4.9', 'Rating', Icons.star_rounded),
        ('7+', 'Tahun', Icons.work_history_outlined),
      ],
      items: [
        CreatorServiceItem(
          title: 'Brand Identity',
          subtitle: 'Logo, brand guideline & aplikasi',
          icon: Icons.branding_watermark_outlined,
          tag: 'Expert',
          value: '35+ Proyek',
        ),
        CreatorServiceItem(
          title: 'Packaging Design',
          subtitle: 'Kemasan produk F&B & retail',
          icon: Icons.inventory_2_outlined,
          tag: 'Advanced',
          value: '25+ Proyek',
        ),
        CreatorServiceItem(
          title: 'UI/UX & Web Design',
          subtitle: 'Figma, prototipe & design system',
          icon: Icons.design_services_outlined,
          tag: 'Advanced',
          value: '18+ Proyek',
        ),
        CreatorServiceItem(
          title: 'Ilustrasi & Karakter',
          subtitle: 'Procreate & vector art',
          icon: Icons.auto_awesome_outlined,
          tag: 'Intermediate',
          value: '12+ Proyek',
        ),
      ],
    ),

    // ─── Pilot Drone ───────────────────────────────────────────────
    'drone_galeri': CreatorServiceData(
      key: 'drone_galeri',
      title: 'Galeri Hasil Drone',
      subtitle: 'Foto & video udara terbaik',
      icon: Icons.airplanemode_active_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('60+', 'Proyek', Icons.airplanemode_active_outlined),
        ('4.8', 'Rating', Icons.star_rounded),
        ('100%', 'Legal & Berizin', Icons.verified_outlined),
      ],
      isGrid: true,
      items: [
        CreatorServiceItem(
          title: 'Cinematic Aerial',
          subtitle: 'Video sinematik dari udara',
          icon: Icons.movie_outlined,
          tag: 'Video',
          value: '25+ Proyek',
        ),
        CreatorServiceItem(
          title: 'Foto Udara Real Estate',
          subtitle: 'Dokumentasi properti dari udara',
          icon: Icons.apartment_outlined,
          tag: 'Foto',
          value: '18+ Proyek',
        ),
        CreatorServiceItem(
          title: 'Dokumentasi Event',
          subtitle: 'Liputan udara konser & festival',
          icon: Icons.festival_outlined,
          tag: 'Event',
          value: '12+ Proyek',
        ),
        CreatorServiceItem(
          title: 'Pemetaan & Survey',
          subtitle: 'Pemetaan lahan & konstruksi',
          icon: Icons.map_outlined,
          tag: 'Survey',
          value: '8+ Proyek',
        ),
      ],
    ),
    'drone_booking': CreatorServiceData(
      key: 'drone_booking',
      title: 'Booking & Jadwal',
      subtitle: 'Jadwal penerbangan drone',
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('1', 'Hari Ini', Icons.today_outlined),
        ('3', 'Minggu Ini', Icons.date_range_outlined),
        ('1', 'Pending', Icons.pending_actions_outlined),
      ],
      actionLabel: 'Konfirmasi Booking',
      items: [
        CreatorServiceItem(
          title: 'Aerial - Perumahan Griya Asri',
          subtitle: '15 Agu 2026 • 07:00 - 10:00 WIB',
          icon: Icons.apartment_outlined,
          tag: 'Terkonfirmasi',
          value: 'Cikarang',
        ),
        CreatorServiceItem(
          title: 'Festival Musik Nusantara',
          subtitle: '07 Sep 2026 • 14:00 - 18:00 WIB',
          icon: Icons.festival_outlined,
          tag: 'Menunggu',
          value: 'GBK',
        ),
        CreatorServiceItem(
          title: 'Pemetaan Lahan - PT Agro',
          subtitle: '12 Sep 2026 • 06:00 - 12:00 WIB',
          icon: Icons.map_outlined,
          tag: 'Terkonfirmasi',
          value: 'Subang',
        ),
      ],
    ),
    'drone_paket': CreatorServiceData(
      key: 'drone_paket',
      title: 'Paket Harga',
      subtitle: 'Layanan drone dengan harga jelas',
      icon: Icons.payments_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('3', 'Paket', Icons.card_membership_outlined),
        ('Rp 1JT', 'Mulai Dari', Icons.price_change_outlined),
        ('Legal', 'Sertifikat & Izin', Icons.verified_outlined),
      ],
      actionLabel: 'Pilih Paket',
      items: [
        CreatorServiceItem(
          title: 'Paket Foto Udara',
          subtitle: '1 jam • 50 foto • 1 lokasi',
          icon: Icons.photo_outlined,
          tag: 'Populer',
          value: 'Rp 1.000.000',
        ),
        CreatorServiceItem(
          title: 'Paket Video Sinematik',
          subtitle: '2 jam • video 4K + edit',
          icon: Icons.movie_outlined,
          tag: 'Best Value',
          value: 'Rp 2.500.000',
        ),
        CreatorServiceItem(
          title: 'Paket Pemetaan & Survey',
          subtitle: 'Full day • data ortofoto & 3D',
          icon: Icons.map_outlined,
          tag: 'Profesional',
          value: 'Rp 4.500.000',
        ),
      ],
    ),
    'drone_equipment': CreatorServiceData(
      key: 'drone_equipment',
      title: 'Peralatan Drone',
      subtitle: 'Armada drone & perlengkapan',
      icon: Icons.videocam_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('4', 'Unit Drone', Icons.airplanemode_active_outlined),
        ('4K60', 'Resolusi Maks', Icons.high_quality_outlined),
        ('A1', 'Kategori Legal', Icons.verified_outlined),
      ],
      items: [
        CreatorServiceItem(
          title: 'DJI Mavic 3 Pro',
          subtitle: 'Kamera 4K 60fps • 3 lensa',
          icon: Icons.airplanemode_active_outlined,
          tag: 'Tersedia',
          value: '2 Unit',
        ),
        CreatorServiceItem(
          title: 'DJI Mini 4 Pro',
          subtitle: 'Drone ringan < 249 gram',
          icon: Icons.flight_outlined,
          tag: 'Tersedia',
          value: '1 Unit',
        ),
        CreatorServiceItem(
          title: 'Baterai & Aksesoris',
          subtitle: '6 baterai + charger ganda',
          icon: Icons.battery_charging_full_outlined,
          tag: 'Tersedia',
          value: '6 Unit',
        ),
        CreatorServiceItem(
          title: 'Sertifikat & Izin Terbang',
          subtitle: 'Sertifikasi pilot & izin penerbangan',
          icon: Icons.verified_outlined,
          tag: 'Lengkap',
          value: 'Terdaftar',
        ),
      ],
    ),

    // ─── Talent & Model ────────────────────────────────────────────
    'talent_profil': CreatorServiceData(
      key: 'talent_profil',
      title: 'Profil Talent',
      subtitle: 'Profil profesional talent & model',
      icon: Icons.portrait_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('5+', 'Tahun', Icons.work_history_outlined),
        ('80+', 'Job', Icons.work_outline),
        ('4.9', 'Rating', Icons.star_rounded),
      ],
      items: [
        CreatorServiceItem(
          title: 'Data Diri & Portofolio',
          subtitle: 'Portofolio & comp card terbaru',
          icon: Icons.badge_outlined,
          tag: 'Lengkap',
          value: 'Diperbarui',
        ),
        CreatorServiceItem(
          title: 'Pengukuran & Spesifikasi',
          subtitle: 'Tinggi, berat, ukuran baju',
          icon: Icons.straighten_outlined,
          tag: 'Tersedia',
          value: 'On Request',
        ),
        CreatorServiceItem(
          title: 'Bahasa & Kemampuan',
          subtitle: 'Indonesia, Inggris, MC & akting',
          icon: Icons.translate_outlined,
          tag: 'Bilingual',
          value: '3 Skill',
        ),
        CreatorServiceItem(
          title: 'Visa & Dokumen',
          subtitle: 'Dokumen kerja & identitas',
          icon: Icons.folder_outlined,
          tag: 'Lengkap',
          value: 'Valid',
        ),
      ],
    ),
    'talent_jadwal': CreatorServiceData(
      key: 'talent_jadwal',
      title: 'Jadwal & Booking',
      subtitle: 'Jadwal job sebagai talent',
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('1', 'Hari Ini', Icons.today_outlined),
        ('4', 'Bulan Ini', Icons.date_range_outlined),
        ('2', 'Pending', Icons.pending_actions_outlined),
      ],
      actionLabel: 'Konfirmasi Booking',
      items: [
        CreatorServiceItem(
          title: 'Model Katalog - Fashion Brand Z',
          subtitle: '14 Agu 2026 • 08:00 - 16:00 WIB',
          icon: Icons.checkroom_outlined,
          tag: 'Terkonfirmasi',
          value: 'Studio 21',
        ),
        CreatorServiceItem(
          title: 'Talent Iklan TVC - Kopi',
          subtitle: '20 Agu 2026 • 09:00 - 17:00 WIB',
          icon: Icons.tv_outlined,
          tag: 'Menunggu',
          value: 'Production House',
        ),
        CreatorServiceItem(
          title: 'Runway Fashion Week',
          subtitle: '05 Sep 2026 • 13:00 - 18:00 WIB',
          icon: Icons.checkroom_outlined,
          tag: 'Terkonfirmasi',
          value: 'Jakarta Fashion Week',
        ),
        CreatorServiceItem(
          title: 'Brand Ambassador - Skincare',
          subtitle: '12 Sep 2026 • 10:00 - 14:00 WIB',
          icon: Icons.face_outlined,
          tag: 'Menunggu',
          value: 'Kantor Brand',
        ),
      ],
    ),
    'talent_kategori': CreatorServiceData(
      key: 'talent_kategori',
      title: 'Kategori Pekerjaan',
      subtitle: 'Jenis pekerjaan yang dilayani',
      icon: Icons.work_outline,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('6', 'Kategori', Icons.category_outlined),
        ('80+', 'Job Selesai', Icons.check_circle_outline),
        ('98%', 'Kepuasan', Icons.verified_outlined),
      ],
      items: [
        CreatorServiceItem(
          title: 'Model Fashion & Editorial',
          subtitle: 'Katalog, majalah & editorial',
          icon: Icons.checkroom_outlined,
          tag: 'Sangat Mahir',
          value: '35+ Job',
        ),
        CreatorServiceItem(
          title: 'Iklan TVC & Digital',
          subtitle: 'Bintang iklan TV & online',
          icon: Icons.tv_outlined,
          tag: 'Mahir',
          value: '20+ Job',
        ),
        CreatorServiceItem(
          title: 'Runway & Catwalk',
          subtitle: 'Model panggung fashion show',
          icon: Icons.stairs_outlined,
          tag: 'Mahir',
          value: '15+ Job',
        ),
        CreatorServiceItem(
          title: 'Brand Ambassador',
          subtitle: 'Kerjasama jangka panjang',
          icon: Icons.thumb_up_outlined,
          tag: 'Sangat Mahir',
          value: '10+ Brand',
        ),
      ],
    ),
    'talent_tarif': CreatorServiceData(
      key: 'talent_tarif',
      title: 'Tarif',
      subtitle: 'Tarif job talent & model',
      icon: Icons.payments_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('3', 'Kategori Tarif', Icons.receipt_long_outlined),
        ('Rp 1.5JT', 'Mulai Dari', Icons.price_change_outlined),
        ('Termasuk', 'Transport & MUA', Icons.local_taxi_outlined),
      ],
      actionLabel: 'Pilih Paket',
      items: [
        CreatorServiceItem(
          title: 'Katalog / Editorial',
          subtitle: 'Per sesi 4 jam • 3-5 outfit',
          icon: Icons.photo_outlined,
          tag: 'Per Sesi',
          value: 'Rp 1.500.000',
        ),
        CreatorServiceItem(
          title: 'Iklan TVC / Digital',
          subtitle: 'Per hari produksi',
          icon: Icons.tv_outlined,
          tag: 'Per Hari',
          value: 'Rp 3.500.000',
        ),
        CreatorServiceItem(
          title: 'Brand Ambassador',
          subtitle: 'Per bulan • durasi minimal 3 bulan',
          icon: Icons.thumb_up_outlined,
          tag: 'Per Bulan',
          value: 'Rp 8.000.000',
        ),
      ],
    ),

    // ─── Content Creator ───────────────────────────────────────────
    'konten_portofolio': CreatorServiceData(
      key: 'konten_portofolio',
      title: 'Portofolio Konten',
      subtitle: 'Konten kreatif untuk brand',
      icon: Icons.photo_library_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('120+', 'Konten', Icons.photo_library_outlined),
        ('4.8', 'Rating', Icons.star_rounded),
        ('450K', 'Total Reach', Icons.insights_outlined),
      ],
      isGrid: true,
      items: [
        CreatorServiceItem(
          title: 'UGC & Review Produk',
          subtitle: 'Konten testimoni pengguna',
          icon: Icons.thumb_up_outlined,
          tag: 'UGC',
          value: '45+ Konten',
        ),
        CreatorServiceItem(
          title: 'Reels & Short Video',
          subtitle: 'Video pendek viral',
          icon: Icons.movie_outlined,
          tag: 'Reels',
          value: '60+ Konten',
        ),
        CreatorServiceItem(
          title: 'Konten Foto Produk',
          subtitle: 'Foto produk lifestyle',
          icon: Icons.photo_camera_outlined,
          tag: 'Foto',
          value: '35+ Konten',
        ),
        CreatorServiceItem(
          title: 'Tutorial & Tips',
          subtitle: 'Konten edukasi untuk brand',
          icon: Icons.school_outlined,
          tag: 'Edukasi',
          value: '20+ Konten',
        ),
      ],
    ),
    'konten_campaign': CreatorServiceData(
      key: 'konten_campaign',
      title: 'Jadwal & Campaign',
      subtitle: 'Jadwal konten & campaign berjalan',
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('3', 'Campaign', Icons.campaign_outlined),
        ('5', 'Konten/Minggu', Icons.content_paste_outlined),
        ('2', 'Pending', Icons.pending_actions_outlined),
      ],
      actionLabel: 'Kelola Campaign',
      items: [
        CreatorServiceItem(
          title: 'Campaign Ramadhan - Brand X',
          subtitle: '12 Agu - 05 Sep • 12 konten',
          icon: Icons.campaign_outlined,
          tag: 'Berjalan',
          value: '8/12 Konten',
        ),
        CreatorServiceItem(
          title: 'Launching Produk Baru - Skincare',
          subtitle: '20 Agu - 10 Sep • 8 konten',
          icon: Icons.rocket_launch_outlined,
          tag: 'Menunggu',
          value: 'Brief',
        ),
        CreatorServiceItem(
          title: 'Konten Bulanan - Kopi Senja',
          subtitle: 'Sepanjang bulan • 4 konten/minggu',
          icon: Icons.coffee_outlined,
          tag: 'Berjalan',
          value: '16/16 Konten',
        ),
      ],
    ),
    'konten_paket': CreatorServiceData(
      key: 'konten_paket',
      title: 'Paket & Harga',
      subtitle: 'Paket konten untuk brand',
      icon: Icons.payments_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('3', 'Paket', Icons.card_membership_outlined),
        ('Rp 2JT', 'Mulai Dari', Icons.price_change_outlined),
        ('30 Hari', 'Durasi', Icons.date_range_outlined),
      ],
      actionLabel: 'Pilih Paket',
      items: [
        CreatorServiceItem(
          title: 'Paket Starter',
          subtitle: '4 konten/bulan • 1 platform',
          icon: Icons.photo_outlined,
          tag: 'Populer',
          value: 'Rp 2.000.000',
        ),
        CreatorServiceItem(
          title: 'Paket Professional',
          subtitle: '8 konten/bulan • 2 platform + review',
          icon: Icons.photo_library_outlined,
          tag: 'Best Value',
          value: 'Rp 4.000.000',
        ),
        CreatorServiceItem(
          title: 'Paket Campaign',
          subtitle: 'Full campaign 30 hari • konten + iklan',
          icon: Icons.campaign_outlined,
          tag: 'Premium',
          value: 'Rp 8.000.000',
        ),
      ],
    ),
    'konten_platform': CreatorServiceData(
      key: 'konten_platform',
      title: 'Platform & Niche',
      subtitle: 'Platform & niche konten',
      icon: Icons.language_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      stats: [
        ('4', 'Platform', Icons.language_outlined),
        ('3', 'Niche', Icons.category_outlined),
        ('450K', 'Total Followers', Icons.people_outline),
      ],
      items: [
        CreatorServiceItem(
          title: 'Instagram & Reels',
          subtitle: 'Konten feed, story & reels',
          icon: Icons.photo_camera_outlined,
          tag: 'Aktif',
          value: '250K Followers',
        ),
        CreatorServiceItem(
          title: 'TikTok',
          subtitle: 'Video pendek viral',
          icon: Icons.music_note_outlined,
          tag: 'Aktif',
          value: '180K Followers',
        ),
        CreatorServiceItem(
          title: 'YouTube',
          subtitle: 'Konten panjang & tutorial',
          icon: Icons.play_circle_outline,
          tag: 'Aktif',
          value: '45K Subscriber',
        ),
        CreatorServiceItem(
          title: 'Niche: Food & Kuliner',
          subtitle: 'Review kuliner & resep',
          icon: Icons.restaurant_outlined,
          tag: 'Spesialis',
          value: '40% Konten',
        ),
      ],
    ),
  };

  static CreatorServiceData? of(String key) => registry[key];
}

class CreatorServiceScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel>? onUserUpdated;
  final String serviceKey;

  const CreatorServiceScreen({
    super.key,
    required this.user,
    required this.serviceKey,
    this.onUserUpdated,
  });

  @override
  State<CreatorServiceScreen> createState() => _CreatorServiceScreenState();
}

class _CreatorServiceScreenState extends State<CreatorServiceScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedFilter = 'Semua';
  String _selectedSort = 'Terbaru';
  final Set<int> _savedItems = {};
  final Set<int> _likedItems = {};
  final Map<String, List<CreatorServiceItem>> _extraItems = {};

  late final AnimationController _fadeController;
  late final AnimationController _staggerController;
  late final List<Animation<double>> _itemAnimations;

  CreatorServiceData? get _data {
    final base = CreatorServiceData.of(widget.serviceKey);
    if (base == null) return null;
    final extras = _extraItems[base.key] ?? const [];
    if (extras.isEmpty) return base;
    return CreatorServiceData(
      key: base.key,
      title: base.title,
      subtitle: base.subtitle,
      icon: base.icon,
      gradient: base.gradient,
      stats: base.stats,
      items: [...base.items, ...extras],
      isGrid: base.isGrid,
      actionLabel: base.actionLabel,
    );
  }

  void _addItem(String key, CreatorServiceItem item) {
    setState(() {
      _extraItems.putIfAbsent(key, () => []).insert(0, item);
    });
  }

  UserModel get _user => widget.user;
  double get _personalRating => (_user.followersCount > 500)
      ? 4.95
      : ((_user.followersCount * 0.0035) + 4.2).clamp(4.2, 4.95);
  String get _ratingDisplay => _personalRating.toStringAsFixed(1);

  List<String> get _availableFilters {
    final data = _data;
    if (data == null) return ['Semua'];
    final tags = data.items
        .map((item) => item.tag)
        .whereType<String>()
        .toSet()
        .toList();
    tags.sort();
    return ['Semua', ...tags];
  }

  List<String> get _sortOptions => const [
    'Terbaru',
    'Terpopuler',
    'A - Z',
    'Harga Tertinggi',
    'Harga Terendah',
  ];

  List<CreatorServiceItem> get _filteredItems {
    final data = _data;
    if (data == null) return const [];
    var items = List<CreatorServiceItem>.from(data.items);
    if (_selectedFilter != 'Semua') {
      items = items.where((item) => item.tag == _selectedFilter).toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      items = items
          .where(
            (i) =>
                i.title.toLowerCase().contains(q) ||
                i.subtitle.toLowerCase().contains(q) ||
                (i.tag?.toLowerCase().contains(q) ?? false) ||
                (i.value?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    if (_selectedSort == 'A - Z') {
      items.sort((a, b) => a.title.compareTo(b.title));
    } else if (_selectedSort == 'Harga Tertinggi' ||
        _selectedSort == 'Harga Terendah') {
      items.sort((a, b) {
        final numA = _extractNumber(a.value);
        final numB = _extractNumber(b.value);
        if (numA == null && numB == null) return 0;
        if (numA == null) return 1;
        if (numB == null) return -1;
        return _selectedSort == 'Harga Tertinggi'
            ? numB.compareTo(numA)
            : numA.compareTo(numB);
      });
    }
    return items;
  }

  double? _parseProgress(String? value) {
    if (value == null) return null;
    final match = RegExp(r'(\d{1,3})%').firstMatch(value);
    if (match == null) return null;
    final percent = double.tryParse(match.group(1)!);
    if (percent == null) return null;
    return (percent / 100).clamp(0.0, 1.0);
  }

  double? _extractNumber(String? value) {
    if (value == null) return null;
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return double.tryParse(digits);
  }

  double? _parseSkill(String? value) {
    final progress = _parseProgress(value);
    if (progress != null) return progress;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _itemAnimations = List.generate(20, (index) {
      final start = (index * 60).clamp(0, 800) / 1200;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start, end, curve: Curves.easeOutBack),
        ),
      );
    });
    _loadPersistedState();
    Future.delayed(Duration.zero, () {
      _fadeController.forward();
      _staggerController.forward();
    });
  }

  Future<void> _loadPersistedState() async {
    try {
      final extras = await CreatorLocalStorage.getExtraItems(widget.serviceKey);
      final saved = await CreatorLocalStorage.getSavedItems();
      final submitted = await CreatorLocalStorage.getSubmittedItems();
      if (!mounted) return;
      if (extras.isNotEmpty || saved.isNotEmpty || submitted.isNotEmpty) {
        setState(() {
          if (extras.isNotEmpty) {
            _extraItems[widget.serviceKey] = List<CreatorServiceItem>.from(
              extras,
            );
          }
          for (final id in saved) {
            final idx = int.tryParse(id);
            if (idx != null) _savedItems.add(idx);
          }
          for (final id in submitted) {
            final idx = int.tryParse(id);
            if (idx != null) _likedItems.add(idx);
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  void _replayAnimations() {
    _fadeController.reset();
    _staggerController.reset();
    _fadeController.forward();
    _staggerController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return const Scaffold(
        body: Center(child: Text('Layanan tidak ditemukan')),
      );
    }

    final content = _buildContent(context, data);
    return DesktopSidebarLayout(
      user: widget.user,
      activeRoute: widget.serviceKey,
      onUserUpdated: widget.onUserUpdated,
      child: content,
    );
  }

  Widget _buildContent(BuildContext context, CreatorServiceData data) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: Row(
          children: [
            Text(
              data.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.cardShadowLight,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Premium',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _buildActionChip(
            icon: Icons.notifications_outlined,
            label: null,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppTheme.primaryPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  content: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Notifikasi',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${(_user.followersCount ~/ 18).clamp(2, 47)} notifikasi baru untuk Anda',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            hasBadge: true,
          ),
          _buildActionChip(
            icon: Icons.star_rounded,
            label: _ratingDisplay,
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  title: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF59E0B,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF59E0B),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Rating & Reputasi',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _ratingDisplay,
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFF59E0B),
                              letterSpacing: -1,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              '/5.0',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < _personalRating.round()
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 18,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Berdasarkan ${(_user.followersCount * 0.7).round()} ulasan dari klien & mitra Kreavana',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Tutup',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppTheme.primaryPurple,
                            content: Text(
                              'Melihat halaman reputasi...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Lihat Reputasi',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              );
            },
            hasBadge: false,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(_fadeController),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, data)),
            SliverToBoxAdapter(child: _buildQuickStatsRow(context, data)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: CreatorAvailabilityWidget(creatorId: _user.id ?? ''),
              ),
            ),
            SliverToBoxAdapter(child: _buildSearchBar(context, data)),
            SliverToBoxAdapter(child: _buildFilterSortBar(context, data)),
            if (_filteredItems.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState(context))
            else if (data.isGrid)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.78,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildAnimatedGridItem(
                      context,
                      data,
                      _filteredItems[index],
                      index,
                    ),
                    childCount: _filteredItems.length,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildAnimatedListItem(
                      context,
                      data,
                      _filteredItems[index],
                      index,
                    ),
                    childCount: _filteredItems.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(context, data),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String? label,
    VoidCallback? onTap,
    bool hasBadge = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isStar = label != null;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Container(
                height: 40,
                padding: EdgeInsets.symmetric(
                  horizontal: label != null ? 12 : 10,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark2 : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                  boxShadow: AppTheme.cardShadowLight,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: isStar
                            ? const Color(0xFFF59E0B)
                            : AppTheme.primaryPurple,
                      ),
                      if (label != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (hasBadge)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CreatorServiceData data) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: data.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -40,
                    right: -30,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -50,
                    left: -40,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 30,
                    right: 100,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 40,
                    right: 50,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Icon(
                                      data.icon,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppTheme.success,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          data.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    data.subtitle,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.88,
                                      ),
                                      fontSize: 13.5,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.verified_rounded,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Terverifikasi',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.flash_on_rounded,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _getResponseTime(data.key),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _buildDecorativeStats(context, data),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getResponseTime(String key) {
    if (key.contains('harga') ||
        key.contains('paket') ||
        key.contains('tarif')) {
      return 'Harga Terjangkau';
    } else if (key.contains('spesialisasi') ||
        key.contains('area') ||
        key.contains('equipment') ||
        key.contains('platform') ||
        key.contains('genre') ||
        key.contains('kategori')) {
      return 'Spesialis Handal';
    } else if (key.contains('jadwal') ||
        key.contains('booking') ||
        key.contains('antrian') ||
        key.contains('proyek') ||
        key.contains('campaign')) {
      return 'Tepat Waktu';
    } else {
      return 'Kualitas Premium';
    }
  }

  List<(String, String, IconData)> _personalizeStats(CreatorServiceData data) {
    final u = _user;
    final base = data.stats;
    final int baseProjectNum =
        int.tryParse(base[0].$1.replaceAll(RegExp(r'[^0-9]'), '')) ?? 24;
    final projectCount = u.followersCount > 0
        ? (u.followersCount * 0.55).round().clamp(6, 350)
        : baseProjectNum;
    final bool needPlus = base[0].$1.contains('+') || baseProjectNum == 24;
    final clientCount = (u.followersCount * 0.35).round().clamp(5, 420);
    return <(String, String, IconData)>[
      ('$projectCount${needPlus ? '+' : ''}', base[0].$2, base[0].$3),
      (
        _ratingDisplay,
        'Rating ${u.name.split(' ')[0]}',
        base.length > 1 ? base[1].$3 : Icons.star_rounded,
      ),
      (
        base.length > 2 ? base[2].$1 : '$clientCount+',
        base.length > 2 ? base[2].$2 : 'Klien Aktif',
        base.length > 2 ? base[2].$3 : Icons.people_outline,
      ),
    ];
  }

  Widget _buildDecorativeStats(BuildContext context, CreatorServiceData data) {
    final personalized = _personalizeStats(data);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < personalized.length; i++) ...[
            Expanded(child: _buildStatCard(personalized[i], i)),
            if (i != personalized.length - 1)
              Container(
                width: 1,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: Colors.white.withValues(alpha: 0.25),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard((String, String, IconData) stat, int index) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(stat.$3, size: 16, color: Colors.white),
        ),
        Text(
          stat.$1,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          stat.$2,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatsRow(BuildContext context, CreatorServiceData data) {
    final u = _user;
    final growth = ((u.followersCount * 0.03) + 5.2).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: _buildMiniStatCard(
              context,
              icon: Icons.trending_up_rounded,
              label: 'Pertumbuhan',
              value: '+$growth%',
              highlight: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildMiniStatCard(
              context,
              icon: Icons.access_time_filled_rounded,
              label: 'Aktivitas ${u.name.split(' ')[0]}',
              value: _getActivityCount(data.key),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildMiniStatCard(
              context,
              icon: Icons.emoji_events_rounded,
              label: 'Pencapaian',
              value: _getAchievementBadge(data.key),
            ),
          ),
        ],
      ),
    );
  }

  String _getActivityCount(String key) {
    if (key.contains('antrian') || key.contains('proyek')) return '8 Proyek';
    if (key.contains('booking') || key.contains('jadwal')) return '6 Agenda';
    if (key.contains('portofolio') || key.contains('galeri'))
      return '24 Tayangan';
    if (key.contains('harga') || key.contains('paket') || key.contains('tarif'))
      return '4 Paket';
    return '5 Item';
  }

  String _getAchievementBadge(String key) {
    if (key.contains('spesialisasi')) return 'Expert ✨';
    if (key.contains('portofolio') || key.contains('galeri'))
      return 'Top Rated ⭐';
    if (key.contains('vendor') || key.contains('partner')) return 'Trusted 🛡️';
    if (key.contains('timeline')) return 'On Track 📈';
    return 'Pro Player 💎';
  }

  Widget _buildMiniStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark2 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? AppTheme.primaryPurple.withValues(alpha: 0.4)
              : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
        ),
        boxShadow: AppTheme.cardShadowLight,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: highlight
                  ? AppTheme.primaryGradient
                  : LinearGradient(
                      colors: [
                        AppTheme.primaryPurple.withValues(alpha: 0.12),
                        AppTheme.lightPurple.withValues(alpha: 0.12),
                      ],
                    ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 16,
              color: highlight ? Colors.white : AppTheme.primaryPurple,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: highlight
                        ? AppTheme.primaryPurple
                        : (isDark ? Colors.white : AppTheme.textDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? AppTheme.textMuted
                        : AppTheme.textMutedLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, CreatorServiceData data) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryPurple.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Cari ${data.title.toLowerCase()}...',
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 62),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_query.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                Container(
                  width: 38,
                  height: 38,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppTheme.primaryShadow,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (ctx) {
                            final dark =
                                Theme.of(ctx).brightness == Brightness.dark;
                            return StatefulBuilder(
                              builder: (ctx2, setSheetState) {
                                return Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    14,
                                    20,
                                    26,
                                  ),
                                  decoration: BoxDecoration(
                                    color: dark
                                        ? AppTheme.cardBg
                                        : Colors.white,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(28),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Center(
                                        child: Container(
                                          width: 44,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: dark
                                                ? AppTheme.cardDark2
                                                : Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      const Text(
                                        'Filter & Urutan',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      const Text(
                                        'Kategori Tag',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _availableFilters.map((f) {
                                          final sel = _selectedFilter == f;
                                          return GestureDetector(
                                            onTap: () {
                                              setSheetState(() {
                                                setState(
                                                  () => _selectedFilter = f,
                                                );
                                              });
                                            },
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 220,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                gradient: sel
                                                    ? AppTheme.primaryGradient
                                                    : null,
                                                color: sel
                                                    ? null
                                                    : (dark
                                                          ? AppTheme.cardDark2
                                                          : Colors
                                                                .grey
                                                                .shade100),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: sel
                                                      ? Colors.transparent
                                                      : (dark
                                                            ? AppTheme
                                                                  .inputBorder
                                                            : Colors
                                                                  .grey
                                                                  .shade200),
                                                ),
                                              ),
                                              child: Text(
                                                f,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: sel
                                                      ? Colors.white
                                                      : (dark
                                                            ? Colors.white
                                                            : AppTheme
                                                                  .textDark),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Urutkan',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ..._sortOptions.map((opt) {
                                        final selected = _selectedSort == opt;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          child: Material(
                                            color: selected
                                                ? AppTheme.primaryPurple
                                                      .withValues(alpha: 0.08)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              onTap: () {
                                                setSheetState(() {
                                                  setState(
                                                    () => _selectedSort = opt,
                                                  );
                                                });
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 12,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      selected
                                                          ? Icons
                                                                .check_circle_rounded
                                                          : Icons
                                                                .radio_button_unchecked_rounded,
                                                      size: 17,
                                                      color: selected
                                                          ? AppTheme
                                                                .primaryPurple
                                                          : (dark
                                                                ? AppTheme
                                                                      .textMuted
                                                                : Colors
                                                                      .grey
                                                                      .shade500),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      opt,
                                                      style: TextStyle(
                                                        fontSize: 12.5,
                                                        fontWeight: selected
                                                            ? FontWeight.w800
                                                            : FontWeight.w500,
                                                        color: selected
                                                            ? AppTheme
                                                                  .primaryPurple
                                                            : (dark
                                                                  ? Colors.white
                                                                  : AppTheme
                                                                        .textDark),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                      const SizedBox(height: 18),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () {
                                                setState(() {
                                                  _selectedFilter = 'Semua';
                                                  _selectedSort = 'Terbaru';
                                                  _searchController.clear();
                                                  _query = '';
                                                });
                                                Navigator.pop(ctx);
                                                _replayAnimations();
                                              },
                                              style: OutlinedButton.styleFrom(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 14,
                                                    ),
                                              ),
                                              child: const Text(
                                                'Reset',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            flex: 2,
                                            child: ElevatedButton(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                _replayAnimations();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppTheme.primaryPurple,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 14,
                                                    ),
                                              ),
                                              child: const Text(
                                                'Terapkan Filter',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                      child: const Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            filled: true,
            fillColor: isDark ? AppTheme.cardBg : Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: AppTheme.primaryPurple,
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSortBar(BuildContext context, CreatorServiceData data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _availableFilters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _availableFilters[index];
                  final selected = filter == _selectedFilter;
                  return _buildFilterChip(filter, selected, () {
                    setState(() => _selectedFilter = filter);
                    _replayAnimations();
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildSortDropdown(context),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 18 : 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.primaryGradient : null,
          color: selected ? null : (isDark ? AppTheme.cardBg : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : (isDark ? AppTheme.inputBorder : Colors.grey.shade300),
          ),
          boxShadow: selected ? AppTheme.primaryShadow : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.white : AppTheme.textDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortDropdown(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<String>(
      onSelected: (val) {
        setState(() => _selectedSort = val);
        _replayAnimations();
      },
      color: isDark ? AppTheme.cardDark2 : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      itemBuilder: (ctx) => _sortOptions
          .map(
            (opt) => PopupMenuItem<String>(
              value: opt,
              child: Row(
                children: [
                  Icon(
                    _selectedSort == opt
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: _selectedSort == opt
                        ? AppTheme.primaryPurple
                        : (isDark ? AppTheme.textMuted : Colors.grey.shade500),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    opt,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: _selectedSort == opt
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sort_rounded,
              size: 16,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              _selectedSort,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryPurple.withValues(alpha: 0.15),
                  AppTheme.lightPurple.withValues(alpha: 0.15),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                  blurRadius: 24,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 44,
              color: AppTheme.primaryPurple,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Tidak ditemukan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Coba ubah kata kunci atau filter',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _query = '';
                _selectedFilter = 'Semua';
                _replayAnimations();
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text(
              'Reset Pencarian',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedGridItem(
    BuildContext context,
    CreatorServiceData data,
    CreatorServiceItem item,
    int index,
  ) {
    final anim = _itemAnimations[index % _itemAnimations.length];
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        final scale = 0.92 + (anim.value * 0.08);
        final opacity = anim.value.clamp(0.0, 1.0);
        final translateY = (1 - anim.value) * 30;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: _buildGridItem(context, data, item),
    );
  }

  Widget _buildGridItem(
    BuildContext context,
    CreatorServiceData data,
    CreatorServiceItem item,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _showDetail(context, data, item),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
              ),
              boxShadow: AppTheme.cardShadowLight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.deepPurple,
                                AppTheme.primaryPurple,
                                AppTheme.lightPurple,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: -20,
                                right: -20,
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -30,
                                left: -10,
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                              ),
                              Center(
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Icon(
                                    item.icon,
                                    size: 30,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (item.tag != null)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              item.tag!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryPurple,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: () {
                            final idx = '${data.key}:${item.title}'.hashCode
                                .abs();
                            setState(() {
                              if (_likedItems.contains(idx)) {
                                _likedItems.remove(idx);
                              } else {
                                _likedItems.add(idx);
                              }
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: _likedItems.contains(idx)
                                    ? const Color(0xFFEC4899)
                                    : Colors.grey.shade700,
                                duration: const Duration(milliseconds: 800),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                content: Text(
                                  _likedItems.contains(idx)
                                      ? 'Ditambahkan ke favorit ❤️'
                                      : 'Dihapus dari favorit',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutBack,
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color:
                                  _likedItems.contains(
                                    '${data.key}:${item.title}'.hashCode.abs(),
                                  )
                                  ? const Color(0xFFEC4899)
                                  : Colors.black.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                              boxShadow:
                                  _likedItems.contains(
                                    '${data.key}:${item.title}'.hashCode.abs(),
                                  )
                                  ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFEC4899,
                                        ).withValues(alpha: 0.5),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              _likedItems.contains(
                                    '${data.key}:${item.title}'.hashCode.abs(),
                                  )
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textDark,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppTheme.textMuted
                                : Colors.grey.shade600,
                            height: 1.4,
                          ),
                        ),
                        const Spacer(),
                        _buildPortfolioStars(),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primaryPurple.withValues(
                                        alpha: 0.08,
                                      ),
                                      AppTheme.lightPurple.withValues(
                                        alpha: 0.08,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.folder_rounded,
                                      size: 12,
                                      color: AppTheme.primaryPurple,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        item.value ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primaryPurple,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                final idx = 'save:${data.key}:${item.title}'
                                    .hashCode
                                    .abs();
                                setState(() {
                                  if (_savedItems.contains(idx)) {
                                    _savedItems.remove(idx);
                                  } else {
                                    _savedItems.add(idx);
                                  }
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: AppTheme.primaryPurple,
                                    duration: const Duration(milliseconds: 900),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    content: Text(
                                      _savedItems.contains(idx)
                                          ? '${item.title} disimpan'
                                          : '${item.title} dihapus dari simpanan',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  gradient:
                                      _savedItems.contains(
                                        'save:${data.key}:${item.title}'
                                            .hashCode
                                            .abs(),
                                      )
                                      ? null
                                      : AppTheme.primaryGradient,
                                  color:
                                      _savedItems.contains(
                                        'save:${data.key}:${item.title}'
                                            .hashCode
                                            .abs(),
                                      )
                                      ? AppTheme.success
                                      : null,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: AppTheme.primaryShadow,
                                ),
                                child: Icon(
                                  _savedItems.contains(
                                        'save:${data.key}:${item.title}'
                                            .hashCode
                                            .abs(),
                                      )
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_add_outlined,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            GestureDetector(
                              onTap: () => _showDetail(context, data, item),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.cardDark2
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark
                                        ? AppTheme.inputBorder
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: Icon(
                                  Icons.remove_red_eye_outlined,
                                  size: 14,
                                  color: isDark
                                      ? Colors.white70
                                      : AppTheme.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortfolioStars() {
    final r = _personalRating;
    final fullStars = r.floor();
    final hasHalf = (r - fullStars) >= 0.35 && (r - fullStars) <= 0.85;
    final totalFill =
        fullStars + (hasHalf ? 1 : ((r - fullStars) > 0.85 ? 1 : 0));
    return Row(
      children: [
        ...List.generate(5, (i) {
          IconData icn;
          if (i < fullStars) {
            icn = Icons.star_rounded;
          } else if (i < totalFill) {
            icn = hasHalf ? Icons.star_half_rounded : Icons.star_rounded;
          } else {
            icn = Icons.star_outline_rounded;
          }
          return Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Icon(icn, size: 11, color: const Color(0xFFF59E0B)),
          );
        }),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            _ratingDisplay,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedListItem(
    BuildContext context,
    CreatorServiceData data,
    CreatorServiceItem item,
    int index,
  ) {
    final anim = _itemAnimations[index % _itemAnimations.length];
    final skillValue = _parseSkill(item.value);
    final isSkillPage = data.key.contains('spesialisasi');

    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        final opacity = anim.value.clamp(0.0, 1.0);
        final translateX = (1 - anim.value) * -40;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(translateX, 0),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: isSkillPage && skillValue != null
            ? _buildSkillListItem(context, data, item, skillValue)
            : _buildListItem(context, data, item),
      ),
    );
  }

  Widget _buildListItem(
    BuildContext context,
    CreatorServiceData data,
    CreatorServiceItem item,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progressValue = _parseProgress(item.value);
    final isPricing =
        data.key.contains('harga') ||
        data.key.contains('paket') ||
        data.key.contains('tarif');
    final isTimeline = data.key.contains('timeline');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: AppTheme.cardShadowLight,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _showDetail(context, data, item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.deepPurple,
                            AppTheme.primaryPurple,
                            AppTheme.lightPurple,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPurple.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(
                              item.icon,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          if (isTimeline)
                            Positioned(
                              right: 2,
                              top: 2,
                              child: _buildTimelineDot(item.tag!),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textDark,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              if (isPricing) _buildPopularBadge(item.tag),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                isTimeline
                                    ? Icons.flag_outlined
                                    : Icons.info_outline_rounded,
                                size: 12,
                                color: isDark
                                    ? AppTheme.textMuted
                                    : Colors.grey.shade500,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  item.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppTheme.textMuted
                                        : Colors.grey.shade600,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (item.tag != null &&
                                      !isPricing &&
                                      !isTimeline)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.primaryPurple.withValues(
                                              alpha: 0.1,
                                            ),
                                            AppTheme.lightPurple.withValues(
                                              alpha: 0.1,
                                            ),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppTheme.primaryPurple
                                              .withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Text(
                                        item.tag!,
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primaryPurple,
                                        ),
                                      ),
                                    ),
                                  if (isTimeline && item.tag != null)
                                    _buildTimelineStatusPill(item.tag!),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: AppTheme.cardShadowLight,
                                    ),
                                    child: Text(
                                      item.value ?? '-',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  final idx = '${data.key}:${item.title}'
                                      .hashCode
                                      .abs();
                                  setState(() {
                                    if (_likedItems.contains(idx)) {
                                      _likedItems.remove(idx);
                                    } else {
                                      _likedItems.add(idx);
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        _likedItems.contains(
                                          '${data.key}:${item.title}'.hashCode
                                              .abs(),
                                        )
                                        ? const Color(
                                            0xFFEC4899,
                                          ).withValues(alpha: 0.1)
                                        : (isDark
                                              ? AppTheme.cardDark2
                                              : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          _likedItems.contains(
                                            '${data.key}:${item.title}'.hashCode
                                                .abs(),
                                          )
                                          ? const Color(
                                              0xFFEC4899,
                                            ).withValues(alpha: 0.3)
                                          : (isDark
                                                ? AppTheme.inputBorder
                                                : Colors.grey.shade200),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _likedItems.contains(
                                              '${data.key}:${item.title}'
                                                  .hashCode
                                                  .abs(),
                                            )
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        size: 13,
                                        color:
                                            _likedItems.contains(
                                              '${data.key}:${item.title}'
                                                  .hashCode
                                                  .abs(),
                                            )
                                            ? const Color(0xFFEC4899)
                                            : (isDark
                                                  ? Colors.white70
                                                  : Colors.grey.shade600),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Suka',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color:
                                              _likedItems.contains(
                                                '${data.key}:${item.title}'
                                                    .hashCode
                                                    .abs(),
                                              )
                                              ? const Color(0xFFEC4899)
                                              : (isDark
                                                    ? Colors.white70
                                                    : Colors.grey.shade600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  final idx = 'save:${data.key}:${item.title}'
                                      .hashCode
                                      .abs();
                                  setState(() {
                                    if (_savedItems.contains(idx)) {
                                      _savedItems.remove(idx);
                                    } else {
                                      _savedItems.add(idx);
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        _savedItems.contains(
                                          'save:${data.key}:${item.title}'
                                              .hashCode
                                              .abs(),
                                        )
                                        ? AppTheme.success.withValues(
                                            alpha: 0.1,
                                          )
                                        : (isDark
                                              ? AppTheme.cardDark2
                                              : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          _savedItems.contains(
                                            'save:${data.key}:${item.title}'
                                                .hashCode
                                                .abs(),
                                          )
                                          ? AppTheme.success.withValues(
                                              alpha: 0.3,
                                            )
                                          : (isDark
                                                ? AppTheme.inputBorder
                                                : Colors.grey.shade200),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _savedItems.contains(
                                              'save:${data.key}:${item.title}'
                                                  .hashCode
                                                  .abs(),
                                            )
                                            ? Icons.bookmark_rounded
                                            : Icons.bookmark_border_rounded,
                                        size: 13,
                                        color:
                                            _savedItems.contains(
                                              'save:${data.key}:${item.title}'
                                                  .hashCode
                                                  .abs(),
                                            )
                                            ? AppTheme.success
                                            : (isDark
                                                  ? Colors.white70
                                                  : Colors.grey.shade600),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Simpan',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color:
                                              _savedItems.contains(
                                                'save:${data.key}:${item.title}'
                                                    .hashCode
                                                    .abs(),
                                              )
                                              ? AppTheme.success
                                              : (isDark
                                                    ? Colors.white70
                                                    : Colors.grey.shade600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => _showDetail(context, data, item),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: AppTheme.primaryShadow,
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.visibility_outlined,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        'Lihat',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (progressValue != null) ...[
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  Container(
                                    height: 8,
                                    color: isDark
                                        ? AppTheme.cardDark2
                                        : Colors.grey.shade100,
                                  ),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                      begin: 0,
                                      end: progressValue,
                                    ),
                                    duration: const Duration(milliseconds: 900),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, val, _) {
                                      return FractionallySizedBox(
                                        widthFactor: val,
                                        child: Container(
                                          height: 8,
                                          decoration: BoxDecoration(
                                            gradient: AppTheme.primaryGradient,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Progress',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppTheme.textMuted
                                        : Colors.grey.shade500,
                                  ),
                                ),
                                Text(
                                  '${(progressValue * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.primaryPurple,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineStatusPill(String tag) {
    Color bg;
    Color fg;
    if (tag.toLowerCase().contains('selesai') ||
        tag.toLowerCase().contains('selesai')) {
      bg = const Color(0xFF10B981).withValues(alpha: 0.12);
      fg = const Color(0xFF10B981);
    } else if (tag.toLowerCase().contains('berjalan') ||
        tag.toLowerCase().contains('aktif') ||
        tag.toLowerCase().contains('sedang')) {
      bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
      fg = const Color(0xFFF59E0B);
    } else {
      bg = AppTheme.primaryPurple.withValues(alpha: 0.12);
      fg = AppTheme.primaryPurple;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        tag,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _buildSkillListItem(
    BuildContext context,
    CreatorServiceData data,
    CreatorServiceItem item,
    double skillValue,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: AppTheme.cardShadowLight,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _showDetail(context, data, item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.deepPurple,
                            AppTheme.primaryPurple,
                            AppTheme.lightPurple,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPurple.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(item.icon, color: Colors.white, size: 26),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textDark,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              _buildSkillLevelBadge(item.tag),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                Icons.handyman_outlined,
                                size: 12,
                                color: isDark
                                    ? AppTheme.textMuted
                                    : Colors.grey.shade500,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  item.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppTheme.textMuted
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _AnimatedSkillPercent(skillValue: skillValue),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      Container(
                        height: 10,
                        color: isDark
                            ? AppTheme.cardDark2
                            : Colors.grey.shade100,
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: skillValue),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, _) {
                          return FractionallySizedBox(
                            widthFactor: val,
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.deepPurple,
                                    AppTheme.primaryPurple,
                                    AppTheme.lightPurple,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMiniSkillMarker('Dasar', 0.25, skillValue),
                    const Spacer(),
                    _buildMiniSkillMarker('Menengah', 0.5, skillValue),
                    const Spacer(),
                    _buildMiniSkillMarker('Ahli', 0.75, skillValue),
                    const Spacer(),
                    _buildMiniSkillMarker('Expert', 1.0, skillValue),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        final idx = '${data.key}:${item.title}'.hashCode.abs();
                        setState(() {
                          if (_likedItems.contains(idx)) {
                            _likedItems.remove(idx);
                          } else {
                            _likedItems.add(idx);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _likedItems.contains(
                                '${data.key}:${item.title}'.hashCode.abs(),
                              )
                              ? const Color(0xFFEC4899).withValues(alpha: 0.1)
                              : (isDark
                                    ? AppTheme.cardDark2
                                    : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                _likedItems.contains(
                                  '${data.key}:${item.title}'.hashCode.abs(),
                                )
                                ? const Color(0xFFEC4899).withValues(alpha: 0.3)
                                : (isDark
                                      ? AppTheme.inputBorder
                                      : Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _likedItems.contains(
                                    '${data.key}:${item.title}'.hashCode.abs(),
                                  )
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 13,
                              color:
                                  _likedItems.contains(
                                    '${data.key}:${item.title}'.hashCode.abs(),
                                  )
                                  ? const Color(0xFFEC4899)
                                  : (isDark
                                        ? Colors.white70
                                        : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Suka',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color:
                                    _likedItems.contains(
                                      '${data.key}:${item.title}'.hashCode
                                          .abs(),
                                    )
                                    ? const Color(0xFFEC4899)
                                    : (isDark
                                          ? Colors.white70
                                          : Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        final idx = 'save:${data.key}:${item.title}'.hashCode
                            .abs();
                        setState(() {
                          if (_savedItems.contains(idx)) {
                            _savedItems.remove(idx);
                          } else {
                            _savedItems.add(idx);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _savedItems.contains(
                                'save:${data.key}:${item.title}'.hashCode.abs(),
                              )
                              ? AppTheme.success.withValues(alpha: 0.1)
                              : (isDark
                                    ? AppTheme.cardDark2
                                    : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                _savedItems.contains(
                                  'save:${data.key}:${item.title}'.hashCode
                                      .abs(),
                                )
                                ? AppTheme.success.withValues(alpha: 0.3)
                                : (isDark
                                      ? AppTheme.inputBorder
                                      : Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _savedItems.contains(
                                    'save:${data.key}:${item.title}'.hashCode
                                        .abs(),
                                  )
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              size: 13,
                              color:
                                  _savedItems.contains(
                                    'save:${data.key}:${item.title}'.hashCode
                                        .abs(),
                                  )
                                  ? AppTheme.success
                                  : (isDark
                                        ? Colors.white70
                                        : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Simpan',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color:
                                    _savedItems.contains(
                                      'save:${data.key}:${item.title}'.hashCode
                                          .abs(),
                                    )
                                    ? AppTheme.success
                                    : (isDark
                                          ? Colors.white70
                                          : Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _showDetail(context, data, item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: AppTheme.primaryShadow,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Detail',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniSkillMarker(String label, double threshold, double current) {
    final reached = current >= threshold;
    return Column(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: reached ? AppTheme.primaryPurple : Colors.grey.shade300,
            border: Border.all(
              color: reached ? AppTheme.lightPurple : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: reached ? FontWeight.w800 : FontWeight.w500,
            color: reached ? AppTheme.primaryPurple : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildSkillLevelBadge(String? tag) {
    Color bg;
    Color fg;
    IconData icon;
    switch ((tag ?? '').toLowerCase()) {
      case 'expert':
        bg = AppTheme.primaryGradient.colors.first.withValues(alpha: 0.12);
        fg = AppTheme.primaryPurple;
        icon = Icons.workspace_premium_rounded;
        break;
      case 'advanced':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
        fg = const Color(0xFFF59E0B);
        icon = Icons.auto_awesome_rounded;
        break;
      case 'intermediate':
        bg = const Color(0xFF10B981).withValues(alpha: 0.12);
        fg = const Color(0xFF10B981);
        icon = Icons.trending_up_rounded;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade600;
        icon = Icons.star_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            tag ?? '',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularBadge(String? tag) {
    if (tag == null) return const SizedBox.shrink();
    final lower = tag.toLowerCase();
    Gradient? grad;
    Color border = Colors.transparent;
    if (lower.contains('premium') || lower.contains('eksklusif')) {
      grad = LinearGradient(
        colors: [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
      );
      border = const Color(0xFFF59E0B);
    } else if (lower.contains('best') || lower.contains('value')) {
      grad = AppTheme.primaryGradient;
      border = AppTheme.primaryPurple;
    } else if (lower.contains('populer') || lower.contains('popular')) {
      grad = LinearGradient(
        colors: [AppTheme.deepPurple, AppTheme.lightPurple],
      );
      border = AppTheme.deepPurple;
    }
    if (grad == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      decoration: BoxDecoration(
        gradient: grad,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: border.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            lower.contains('premium')
                ? Icons.workspace_premium_rounded
                : (lower.contains('best')
                      ? Icons.local_fire_department_rounded
                      : Icons.favorite_rounded),
            size: 10,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            tag,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineDot(String tag) {
    Color c;
    switch (tag.toLowerCase()) {
      case 'selesai':
      case 'terunduh':
      case 'sudah':
        c = const Color(0xFF10B981);
        break;
      case 'berjalan':
      case 'aktif':
      case 'sedang dikerjakan':
      case 'persiapan':
        c = const Color(0xFFF59E0B);
        break;
      default:
        c = AppTheme.primaryPurple;
    }
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: c.withValues(alpha: 0.5),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildFAB(BuildContext context, CreatorServiceData data) {
    IconData icon;
    String label;
    final k = data.key.toLowerCase();
    if (k.contains('portofolio') || k.contains('galeri')) {
      icon = Icons.add_photo_alternate_outlined;
      label = 'Tambah Proyek';
    } else if (k.contains('antrian') ||
        k.contains('proyek') ||
        k.contains('campaign')) {
      icon = Icons.playlist_add_rounded;
      label = 'Ajukan';
    } else if (k.contains('harga') ||
        k.contains('paket') ||
        k.contains('tarif')) {
      icon = Icons.add_card_rounded;
      label = 'Tambah Layanan';
    } else if (k.contains('spesialisasi') ||
        k.contains('skill') ||
        k.contains('platform') ||
        k.contains('genre') ||
        k.contains('kategori')) {
      icon = Icons.add_task_rounded;
      label = 'Tambah Skill';
    } else {
      icon = Icons.add_rounded;
      label = data.actionLabel;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      builder: (_, val, child) {
        return Transform.scale(
          scale: val,
          child: Opacity(opacity: val.clamp(0.0, 1.0), child: child),
        );
      },
      child: FloatingActionButton.extended(
        onPressed: () => _showDetail(context, data, null),
        backgroundColor: Colors.transparent,
        elevation: 0,
        extendedPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 4,
        ),
        label: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppTheme.deepPurple.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 15, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(
    BuildContext context,
    CreatorServiceData data,
    CreatorServiceItem? item,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ServiceDetailSheet(
        data: data,
        item: item,
        actionLabel: data.actionLabel,
        user: widget.user,
        onAddItem: (newItem) => _addItem(data.key, newItem),
      ),
    );
  }
}

class _AnimatedSkillPercent extends StatefulWidget {
  final double skillValue;
  const _AnimatedSkillPercent({required this.skillValue});

  @override
  State<_AnimatedSkillPercent> createState() => _AnimatedSkillPercentState();
}

class _AnimatedSkillPercentState extends State<_AnimatedSkillPercent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = Tween<double>(
      begin: 0,
      end: widget.skillValue,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration.zero, () => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) {
        final pct = (_anim.value * 100).round();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(10),
            boxShadow: AppTheme.cardShadowLight,
          ),
          child: Text(
            '$pct%',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}

class _ServiceDetailSheet extends StatefulWidget {
  final CreatorServiceData data;
  final CreatorServiceItem? item;
  final String actionLabel;
  final UserModel user;
  final ValueChanged<CreatorServiceItem>? onAddItem;

  const _ServiceDetailSheet({
    required this.data,
    required this.item,
    required this.actionLabel,
    required this.user,
    this.onAddItem,
  });

  @override
  State<_ServiceDetailSheet> createState() => _ServiceDetailSheetState();
}

class _ServiceDetailSheetState extends State<_ServiceDetailSheet>
    with TickerProviderStateMixin {
  late final TabController _tabCtrl;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  int _tab = 0;
  final Set<int> _likedReviews = {};
  int _selectedFilterReview = 0;

  String _formName = '';
  String _formDesc = '';
  String _formTag = '';
  String _formPrice = '';
  IconData? _formIcon;
  DateTime? _formDate;

  final List<
    ({
      String name,
      String city,
      String text,
      int stars,
      String date,
      bool verified,
      int likes,
    })
  >
  _customReviews = [];
  bool _itemSubmitted = false;
  bool _itemSaved = false;

  final List<String> _availableFormTags = const [
    'Video Editing',
    'Retouch Foto',
    'Color Grading',
    'Motion Grafis',
    'Desain Logo',
    'UI/UX Design',
    'Sound Design',
    'Brand Identity',
    'Konten Sosmed',
    'Short Movie',
    'Dokumentasi',
    'Live Streaming',
    'Premium',
    'Unggulan',
    'Baru',
    'Trending',
    'Limited',
    'Diskon',
  ];
  final List<(String, IconData)> _availableFormIcons = const [
    ('Edit', Icons.edit_outlined),
    ('Video', Icons.movie_outlined),
    ('Kamera', Icons.photo_camera_outlined),
    ('Warna', Icons.palette_outlined),
    ('Audio', Icons.music_note_outlined),
    ('Logo', Icons.brush_outlined),
    ('Folder', Icons.folder_outlined),
    ('Bintang', Icons.star_outline),
    ('Desain', Icons.design_services_outlined),
    ('Tag', Icons.label_outline),
    ('Kalender', Icons.event_outlined),
    ('Harga', Icons.sell_outlined),
  ];

  Future<void> _openTextField({
    required String title,
    required String initial,
    required int maxLines,
    required TextInputType keyboardType,
    required String hint,
    required String prefix,
    required ValueChanged<String> onSave,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final dark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: dark ? AppTheme.cardDark2 : Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 17,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: TextField(
                controller: ctrl,
                maxLines: maxLines,
                keyboardType: keyboardType,
                autofocus: true,
                decoration: InputDecoration(
                  prefixText: prefix.isEmpty ? null : prefix,
                  prefixStyle: const TextStyle(
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade500,
                  ),
                  filled: true,
                  fillColor: dark ? AppTheme.cardBg : Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: dark ? AppTheme.inputBorder : Colors.grey.shade200,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryPurple,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Batal',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                ),
                child: const Text(
                  'Simpan',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (result != null) {
      onSave(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.success,
          duration: const Duration(milliseconds: 900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            '$title berhasil disimpan ✓',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _openTagPicker(ValueChanged<String> onSave) async {
    String temp = _formTag;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final dark = Theme.of(ctx).brightness == Brightness.dark;
        final viewInsets = MediaQuery.of(ctx).viewInsets;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: SingleChildScrollView(
              child: Container(
                decoration: BoxDecoration(
                  color: dark ? AppTheme.cardBg : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: dark ? AppTheme.cardDark2 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.label_outline_rounded,
                            size: 17,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Pilih Kategori / Tag',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableFormTags.map((t) {
                        final sel = temp == t;
                        return GestureDetector(
                          onTap: () => setSheet(() => temp = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              gradient: sel ? AppTheme.primaryGradient : null,
                              color: sel
                                  ? null
                                  : (dark
                                        ? AppTheme.cardDark2
                                        : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: sel
                                    ? Colors.transparent
                                    : (dark
                                          ? AppTheme.inputBorder
                                          : Colors.grey.shade200),
                              ),
                              boxShadow: sel ? AppTheme.primaryShadow : null,
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                color: sel
                                    ? Colors.white
                                    : (dark ? Colors.white : AppTheme.textDark),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setSheet(() => temp = '');
                              Navigator.pop(ctx);
                            },
                            child: Text(
                              'Reset',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              onSave(temp);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppTheme.success,
                                  duration: const Duration(milliseconds: 900),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  content: Text(
                                    temp.isEmpty
                                        ? 'Tag dihapus'
                                        : 'Tag "$temp" dipilih ✓',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: const Text(
                              'Pilih Tag',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openIconPicker(ValueChanged<IconData> onSave) async {
    IconData temp = _formIcon ?? Icons.edit_outlined;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final dark = Theme.of(ctx).brightness == Brightness.dark;
        final viewInsets = MediaQuery.of(ctx).viewInsets;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: SingleChildScrollView(
              child: Container(
                decoration: BoxDecoration(
                  color: dark ? AppTheme.cardBg : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: dark ? AppTheme.cardDark2 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.image_outlined,
                            size: 17,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Pilih Thumbnail / Icon',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.0,
                      children: _availableFormIcons.map((e) {
                        final sel = temp == e.$2;
                        return GestureDetector(
                          onTap: () => setSheet(() => temp = e.$2),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutBack,
                            decoration: BoxDecoration(
                              gradient: sel ? AppTheme.primaryGradient : null,
                              color: sel
                                  ? null
                                  : (dark
                                        ? AppTheme.cardDark2
                                        : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: sel
                                    ? Colors.transparent
                                    : (dark
                                          ? AppTheme.inputBorder
                                          : Colors.grey.shade200),
                              ),
                              boxShadow: sel ? AppTheme.primaryShadow : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  e.$2,
                                  size: 20,
                                  color: sel
                                      ? Colors.white
                                      : AppTheme.primaryPurple,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  e.$1,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: sel
                                        ? Colors.white
                                        : (dark
                                              ? Colors.white70
                                              : Colors.grey.shade600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              onSave(temp);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppTheme.success,
                                  duration: const Duration(milliseconds: 900),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  content: const Text(
                                    'Icon berhasil dipilih ✓',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: const Text(
                              'Gunakan Icon Ini',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDatePicker(ValueChanged<DateTime> onSave) async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDate: _formDate ?? now,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: dark
                ? const ColorScheme.dark(
                    primary: AppTheme.primaryPurple,
                    surface: AppTheme.cardDark2,
                  )
                : const ColorScheme.light(primary: AppTheme.primaryPurple),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      if (!mounted) return;
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_formDate ?? now),
        builder: (ctx, child) {
          return Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: dark
                  ? const ColorScheme.dark(
                      primary: AppTheme.primaryPurple,
                      surface: AppTheme.cardDark2,
                    )
                  : const ColorScheme.light(primary: AppTheme.primaryPurple),
            ),
            child: child!,
          );
        },
      );
      final full = DateTime(
        picked.year,
        picked.month,
        picked.day,
        t?.hour ?? 9,
        t?.minute ?? 0,
      );
      onSave(full);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.success,
          duration: const Duration(milliseconds: 900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            'Tanggal ${full.day} ${_monthId(full.month)} ${full.year} disimpan ✓',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      );
    }
  }

  void _handleFormTap(int i) {
    switch (i) {
      case 0:
        _openTextField(
          title: 'Nama Item',
          initial: _formName,
          maxLines: 1,
          keyboardType: TextInputType.text,
          hint: 'Misal: Color Grading Sinematik',
          prefix: '',
          onSave: (v) => setState(() => _formName = v),
        );
        break;
      case 1:
        _openTextField(
          title: 'Deskripsi Singkat',
          initial: _formDesc,
          maxLines: 4,
          keyboardType: TextInputType.multiline,
          hint: 'Jelaskan singkat item/layanan yang dibuat...',
          prefix: '',
          onSave: (v) => setState(() => _formDesc = v),
        );
        break;
      case 2:
        _openTagPicker((v) => setState(() => _formTag = v));
        break;
      case 3:
        _openTextField(
          title: 'Nilai / Harga',
          initial: _formPrice,
          maxLines: 1,
          keyboardType: TextInputType.number,
          hint: 'Masukkan angka tanpa titik/koma',
          prefix: 'Rp ',
          onSave: (v) => setState(() => _formPrice = v),
        );
        break;
      case 4:
        _openIconPicker((v) => setState(() => _formIcon = v));
        break;
      case 5:
        _openDatePicker((v) => setState(() => _formDate = v));
        break;
    }
  }

  Future<void> _showWriteReviewSheet() async {
    int tempStars = 5;
    final ctrl = TextEditingController();
    final displayName = widget.user.name;
    final firstLetter = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : 'U';
    final city = 'Kota Anda';
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final dark = Theme.of(ctx).brightness == Brightness.dark;
        final viewInsets = MediaQuery.of(ctx).viewInsets;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: SingleChildScrollView(
              child: Container(
                decoration: BoxDecoration(
                  color: dark ? AppTheme.cardBg : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: dark
                              ? AppTheme.cardDark2
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.edit_note_rounded,
                            size: 17,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Tulis Ulasan Anda',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: dark ? AppTheme.cardDark2 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: dark
                              ? AppTheme.inputBorder
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.primaryPurple,
                            child: Text(
                              firstLetter,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: dark
                                        ? Colors.white
                                        : AppTheme.textDark,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '$city • Terverifikasi',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: dark
                                        ? AppTheme.textMuted
                                        : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Text(
                              'Terbeli',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Beri rating Anda',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (i) {
                        final filled = i < tempStars;
                        return GestureDetector(
                          onTap: () => setSheet(() => tempStars = i + 1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutBack,
                              transform: Matrix4.identity()
                                ..scale(filled ? 1.08 : 1.0),
                              child: Icon(
                                filled
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 32,
                                color: filled
                                    ? Colors.amber.shade600
                                    : Colors.grey.shade400,
                                shadows: filled
                                    ? [
                                        BoxShadow(
                                          color: Colors.amber.withValues(
                                            alpha: 0.35,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tempStars == 1
                          ? 'Sangat Buruk'
                          : tempStars == 2
                          ? 'Buruk'
                          : tempStars == 3
                          ? 'Cukup'
                          : tempStars == 4
                          ? 'Bagus'
                          : 'Luar Biasa!',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: tempStars >= 4
                            ? Colors.amber.shade700
                            : Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: ctrl,
                      maxLines: 4,
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText:
                            'Ceritakan pengalaman Anda menggunakan layanan ini...',
                        hintStyle: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade500,
                        ),
                        filled: true,
                        fillColor: dark
                            ? AppTheme.cardDark2
                            : Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: dark
                                ? AppTheme.inputBorder
                                : Colors.grey.shade200,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppTheme.primaryPurple,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedBuilder(
                      animation: ctrl,
                      builder: (_, _) => Text(
                        '${ctrl.text.length}/500 karakter',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: ctrl.text.length > 450
                              ? Colors.orange.shade700
                              : Colors.grey.shade500,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'Batal',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              final text = ctrl.text.trim();
                              if (text.length < 10) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.orange.shade700,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    content: const Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.white,
                                          size: 17,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Ulasan minimal 10 karakter ya.',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    duration: const Duration(
                                      milliseconds: 1500,
                                    ),
                                  ),
                                );
                                return;
                              }
                              setState(() {
                                _customReviews.insert(0, (
                                  name: displayName,
                                  city: city,
                                  text: text,
                                  stars: tempStars,
                                  date: 'Baru saja',
                                  verified: true,
                                  likes: 0,
                                ));
                              });
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.green.shade600,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.verified_rounded,
                                        color: Colors.white,
                                        size: 17,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Ulasan $tempStars bintang terkirim. Terima kasih! 🙏',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: const Text(
                              'Kirim Ulasan',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() => _tab = _tabCtrl.index));
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(_animCtrl);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack));
    if (widget.item == null) {
      final title = widget.data.title;
      final now = DateTime.now();
      if (title == 'Portofolio Edit') {
        _formName = 'Color Grading Sinematik Short Movie';
        _formDesc =
            'Paket color grading sinematik untuk short movie 3-5 menit. Menggunakan referensi tone film indie dengan kontras hangat, skin tone natural, dan highlight lembut. Cocok untuk film pendek, skripsi, atau campaign branding lokal.';
        _formTag = 'Premium';
        _formPrice = '850000';
        _formIcon = Icons.palette_outlined;
        _formDate = DateTime(now.year, now.month, now.day, 9, 30);
      } else if (title == 'Antrian Kerja') {
        _formName = 'Editing Reels Toko Online Hijab';
        _formDesc =
            'Pesanan editing 6 reels promosi untuk toko online hijab segi empat. Durasi 25-30 detik per video, termasuk text overlay, backsound library, dan transisi dinamis. Client: Larasati Boutique Bandung.';
        _formTag = 'Trending';
        _formPrice = '420000';
        _formIcon = Icons.movie_outlined;
        _formDate = DateTime(now.year, now.month, now.day + 1, 13, 0);
      } else if (title == 'Daftar Harga') {
        _formName = 'Paket Retouch Foto Prewedding';
        _formDesc =
            'Paket retouch 50 foto prewedding. Termasuk skin smoothing natural (tidak over), body shaping proporsional, color correction, background cleaning, dan 2x revisi bebas. Sudah termasuk file HD & file siap cetak 24R.';
        _formTag = 'Unggulan';
        _formPrice = '1650000';
        _formIcon = Icons.photo_camera_outlined;
        _formDate = DateTime(now.year, now.month, now.day - 2, 10, 15);
      } else if (title == 'Spesialisasi') {
        _formName = 'Motion Graphics Logo Reveal';
        _formDesc =
            'Spesialis pembuatan animasi logo reveal durasi 8-12 detik dengan style 3D glassmorphism, particle effect, dan audio SFX premium. Sudah termasuk 3 opsi konsep dan 4x revisi untuk kepuasan klien.';
        _formTag = 'Limited';
        _formPrice = '750000';
        _formIcon = Icons.design_services_outlined;
        _formDate = DateTime(now.year, now.month, now.day - 5, 16, 45);
      } else {
        _formName = '';
        _formDesc = '';
        _formTag = '';
        _formPrice = '';
        _formIcon = null;
        _formDate = null;
      }
    }
    Future.delayed(Duration.zero, () => _animCtrl.forward());
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNew = widget.item == null;
    final item = widget.item;

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: GestureDetector(
          onTap: () {},
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: DraggableScrollableSheet(
                initialChildSize: 0.82,
                maxChildSize: 0.92,
                minChildSize: 0.5,
                expand: false,
                builder: (ctx, scrollCtrl) {
                  return Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardBg : Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.cardDark2
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: widget.data.gradient,
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryPurple.withValues(
                                        alpha: 0.28,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isNew
                                      ? Icons.add_rounded
                                      : (item?.icon ?? widget.data.icon),
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isNew
                                          ? widget.data.actionLabel
                                          : (item?.title ?? '-'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? Colors.white
                                            : AppTheme.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      isNew
                                          ? 'Tambah item baru ke ${widget.data.title}'
                                          : (item?.subtitle ??
                                                widget.data.subtitle),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark
                                            ? AppTheme.textMuted
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppTheme.cardDark2
                                        : Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item != null && item.value != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.deepPurple.withValues(alpha: 0.08),
                                    AppTheme.lightPurple.withValues(
                                      alpha: 0.08,
                                    ),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.primaryPurple.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.sell_rounded,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Nilai / Harga',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primaryPurple,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        item.value!,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: AppTheme.primaryPurple,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  if (item.tag != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.primaryGradient,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: AppTheme.cardShadowLight,
                                      ),
                                      child: Text(
                                        item.tag!,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.cardDark2
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: TabBar(
                              controller: _tabCtrl,
                              dividerColor: Colors.transparent,
                              indicator: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: AppTheme.cardShadowLight,
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              indicatorPadding: const EdgeInsets.all(5),
                              labelColor: Colors.white,
                              unselectedLabelColor: isDark
                                  ? AppTheme.textMuted
                                  : Colors.grey.shade600,
                              labelStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                              tabs: const [
                                Tab(text: 'Informasi'),
                                Tab(text: 'Ulasan'),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _tab == 0
                                ? _buildInfoTab(
                                    context,
                                    scrollCtrl,
                                    isDark,
                                    isNew,
                                  )
                                : _buildReviewTab(context, scrollCtrl, isDark),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.cardBg : Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            top: false,
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      final item = widget.item;
                                      final title =
                                          item?.title ?? widget.data.title;
                                      final wasSaved = _itemSaved;
                                      setState(() => _itemSaved = !_itemSaved);
                                      if (!wasSaved) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            behavior: SnackBarBehavior.floating,
                                            backgroundColor:
                                                AppTheme.primaryPurple,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            content: Row(
                                              children: [
                                                const Icon(
                                                  Icons.bookmark_added_rounded,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    '"$title" tersimpan di koleksi Anda',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            duration: const Duration(
                                              seconds: 3,
                                            ),
                                            action: SnackBarAction(
                                              label: 'Urungkan',
                                              textColor: Colors.white,
                                              onPressed: () {
                                                setState(
                                                  () => _itemSaved = false,
                                                );
                                              },
                                            ),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            behavior: SnackBarBehavior.floating,
                                            backgroundColor:
                                                Colors.grey.shade800,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            content: Row(
                                              children: [
                                                const Icon(
                                                  Icons
                                                      .bookmark_remove_outlined,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    '"$title" dihapus dari koleksi tersimpan',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            duration: const Duration(
                                              milliseconds: 1400,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      side: BorderSide(
                                        color: _itemSaved
                                            ? AppTheme.primaryPurple
                                            : (isDark
                                                  ? AppTheme.inputBorder
                                                  : Colors.grey.shade300),
                                        width: _itemSaved ? 1.5 : 1.0,
                                      ),
                                      backgroundColor: _itemSaved
                                          ? AppTheme.primaryPurple.withValues(
                                              alpha: 0.06,
                                            )
                                          : null,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    icon: Icon(
                                      _itemSaved
                                          ? Icons.bookmark_rounded
                                          : Icons.bookmark_border_rounded,
                                      size: 16,
                                      color: _itemSaved
                                          ? AppTheme.primaryPurple
                                          : null,
                                    ),
                                    label: Text(
                                      'Simpan',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: _itemSaved
                                            ? AppTheme.primaryPurple
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 1,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      final item = widget.item;
                                      final shareTitle =
                                          item?.title ?? widget.data.title;
                                      final shareDesc =
                                          item?.subtitle ??
                                          widget.data.subtitle;
                                      showModalBottomSheet(
                                        context: context,
                                        backgroundColor: Colors.transparent,
                                        builder: (ctx) => Container(
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? AppTheme.cardBg
                                                : Colors.white,
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(28),
                                                ),
                                          ),
                                          padding: const EdgeInsets.fromLTRB(
                                            20,
                                            16,
                                            20,
                                            28,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 44,
                                                height: 5,
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? AppTheme.cardDark2
                                                      : Colors.grey.shade300,
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                ),
                                              ),
                                              const SizedBox(height: 18),
                                              Text(
                                                'Bagikan $shareTitle',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w900,
                                                  color: isDark
                                                      ? Colors.white
                                                      : AppTheme.textDark,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                shareDesc,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: isDark
                                                      ? AppTheme.textMuted
                                                      : Colors.grey.shade600,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 20),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceEvenly,
                                                children: [
                                                  _buildShareTile(
                                                    Icons.sms_rounded,
                                                    'WhatsApp',
                                                    const Color(0xFF25D366),
                                                    () =>
                                                        Navigator.pop(context),
                                                  ),
                                                  _buildShareTile(
                                                    Icons.send_rounded,
                                                    'Telegram',
                                                    const Color(0xFF229ED9),
                                                    () =>
                                                        Navigator.pop(context),
                                                  ),
                                                  _buildShareTile(
                                                    Icons.email_outlined,
                                                    'Email',
                                                    const Color(0xFFEA4335),
                                                    () =>
                                                        Navigator.pop(context),
                                                  ),
                                                  _buildShareTile(
                                                    Icons.link_rounded,
                                                    'Salin Link',
                                                    AppTheme.primaryPurple,
                                                    () {
                                                      Navigator.pop(context);
                                                      ScaffoldMessenger.of(
                                                        ctx,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          behavior:
                                                              SnackBarBehavior
                                                                  .floating,
                                                          content: const Text(
                                                            'Link disalin ke clipboard',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                          backgroundColor:
                                                              AppTheme
                                                                  .primaryPurple,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  14,
                                                                ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      side: BorderSide(
                                        color: AppTheme.primaryPurple
                                            .withValues(alpha: 0.4),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.share_outlined,
                                      size: 16,
                                    ),
                                    label: Text(
                                      'Bagikan',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: AppTheme.primaryPurple,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: _itemSubmitted && !isNew
                                          ? LinearGradient(
                                              colors: [
                                                Color(0xFF0EA5E9),
                                                Color(0xFF3B82F6),
                                              ],
                                            )
                                          : AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _itemSubmitted && !isNew
                                              ? Colors.blue.withValues(
                                                  alpha: 0.35,
                                                )
                                              : AppTheme.primaryPurple
                                                    .withValues(alpha: 0.4),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () {
                                          final item = widget.item;
                                          final actionName = isNew
                                              ? 'Buat Baru'
                                              : widget.actionLabel;
                                          final targetName =
                                              item?.title ?? widget.data.title;
                                          if (isNew) {
                                            String fmtIDR(String raw) {
                                              final n =
                                                  int.tryParse(
                                                    raw.replaceAll(
                                                      RegExp(r'[^0-9]'),
                                                      '',
                                                    ),
                                                  ) ??
                                                  0;
                                              if (n == 0) return raw;
                                              final s = n.toString();
                                              String out = '';
                                              for (
                                                int i = 0;
                                                i < s.length;
                                                i++
                                              ) {
                                                if (i > 0 &&
                                                    (s.length - i) % 3 == 0)
                                                  out += '.';
                                                out += s[i];
                                              }
                                              return 'Rp $out';
                                            }

                                            if (_formName.trim().isEmpty) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  backgroundColor:
                                                      Colors.orange.shade700,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                  ),
                                                  content: const Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .warning_amber_rounded,
                                                        color: Colors.white,
                                                        size: 18,
                                                      ),
                                                      SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                          'Nama item belum diisi. Klik kolom "Nama item" untuk mengisi.',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  duration: const Duration(
                                                    milliseconds: 1800,
                                                  ),
                                                ),
                                              );
                                              return;
                                            }
                                            showDialog(
                                              context: context,
                                              builder: (dctx) => AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(22),
                                                ),
                                                title: Row(
                                                  children: [
                                                    Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        gradient: AppTheme
                                                            .primaryGradient,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Icon(
                                                        Icons.add_task_rounded,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        'Konfirmasi $actionName',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                content: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Item berikut akan ditambahkan ke ${widget.data.title}:',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            12,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors.grey.shade50,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              14,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors
                                                              .grey
                                                              .shade200,
                                                        ),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Container(
                                                                width: 30,
                                                                height: 30,
                                                                decoration: BoxDecoration(
                                                                  gradient: AppTheme
                                                                      .primaryGradient,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        10,
                                                                      ),
                                                                ),
                                                                child: Icon(
                                                                  _formIcon ??
                                                                      Icons
                                                                          .edit_outlined,
                                                                  size: 15,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              Expanded(
                                                                child: Text(
                                                                  _formName
                                                                      .trim(),
                                                                  style: const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w800,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),
                                                              ),
                                                              if (_formTag
                                                                  .isNotEmpty)
                                                                Container(
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            8,
                                                                        vertical:
                                                                            3,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    color: AppTheme
                                                                        .primaryPurple
                                                                        .withValues(
                                                                          alpha:
                                                                              0.1,
                                                                        ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          8,
                                                                        ),
                                                                  ),
                                                                  child: Text(
                                                                    _formTag,
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          9.5,
                                                                      color: AppTheme
                                                                          .primaryPurple,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w800,
                                                                    ),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                          if (_formDesc
                                                              .isNotEmpty) ...[
                                                            const SizedBox(
                                                              height: 6,
                                                            ),
                                                            Text(
                                                              _formDesc
                                                                          .trim()
                                                                          .length >
                                                                      110
                                                                  ? '${_formDesc.trim().substring(0, 110)}...'
                                                                  : _formDesc
                                                                        .trim(),
                                                              style: TextStyle(
                                                                fontSize: 10.5,
                                                                color: Colors
                                                                    .grey
                                                                    .shade600,
                                                                height: 1.4,
                                                              ),
                                                            ),
                                                          ],
                                                          if (_formPrice
                                                                  .isNotEmpty ||
                                                              _formDate !=
                                                                  null) ...[
                                                            const SizedBox(
                                                              height: 8,
                                                            ),
                                                            Divider(
                                                              color: Colors
                                                                  .grey
                                                                  .shade200,
                                                              height: 1,
                                                            ),
                                                            const SizedBox(
                                                              height: 8,
                                                            ),
                                                            Row(
                                                              children: [
                                                                if (_formPrice
                                                                    .isNotEmpty)
                                                                  Expanded(
                                                                    child: Row(
                                                                      children: [
                                                                        Icon(
                                                                          Icons
                                                                              .sell_outlined,
                                                                          size:
                                                                              13,
                                                                          color: Colors
                                                                              .green
                                                                              .shade700,
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              4,
                                                                        ),
                                                                        Text(
                                                                          fmtIDR(
                                                                            _formPrice,
                                                                          ),
                                                                          style: TextStyle(
                                                                            fontSize:
                                                                                11,
                                                                            fontWeight:
                                                                                FontWeight.w800,
                                                                            color:
                                                                                Colors.green.shade700,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                if (_formDate !=
                                                                    null)
                                                                  Expanded(
                                                                    child: Row(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .end,
                                                                      children: [
                                                                        Icon(
                                                                          Icons
                                                                              .event_rounded,
                                                                          size:
                                                                              13,
                                                                          color: Colors
                                                                              .grey
                                                                              .shade700,
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              4,
                                                                        ),
                                                                        Text(
                                                                          '${_formDate!.day} ${_monthId(_formDate!.month)} ${_formDate!.year}',
                                                                          style: TextStyle(
                                                                            fontSize:
                                                                                11,
                                                                            fontWeight:
                                                                                FontWeight.w700,
                                                                            color:
                                                                                Colors.grey.shade700,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(dctx),
                                                    child: Text(
                                                      'Batal',
                                                      style: TextStyle(
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      final finalName =
                                                          _formName.trim();
                                                      final finalDesc =
                                                          _formDesc
                                                              .trim()
                                                              .isNotEmpty
                                                          ? _formDesc.trim()
                                                          : 'Item baru di ${widget.data.title}';
                                                      final finalTag =
                                                          _formTag.isNotEmpty
                                                          ? _formTag
                                                          : 'Baru';
                                                      final finalValue =
                                                          _formPrice.isNotEmpty
                                                          ? fmtIDR(_formPrice)
                                                          : (_formDate != null
                                                                ? '${_formDate!.day} ${_monthId(_formDate!.month)} ${_formDate!.year}'
                                                                : '-');
                                                      final finalIcon =
                                                          _formIcon ??
                                                          Icons.edit_outlined;
                                                      final finalGrad =
                                                          widget.data.gradient;
                                                      final newItem =
                                                          CreatorServiceItem(
                                                            title: finalName,
                                                            subtitle: finalDesc,
                                                            icon: finalIcon,
                                                            tag: finalTag,
                                                            value: finalValue,
                                                            active: true,
                                                            gradient: finalGrad,
                                                          );
                                                      widget.onAddItem?.call(
                                                        newItem,
                                                      );
                                                      Navigator.pop(dctx);
                                                      Navigator.pop(context);
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          behavior:
                                                              SnackBarBehavior
                                                                  .floating,
                                                          backgroundColor:
                                                              Colors
                                                                  .green
                                                                  .shade600,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  14,
                                                                ),
                                                          ),
                                                          content: Row(
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .add_task_rounded,
                                                                color: Colors
                                                                    .white,
                                                                size: 18,
                                                              ),
                                                              const SizedBox(
                                                                width: 10,
                                                              ),
                                                              Expanded(
                                                                child: Text(
                                                                  '"$finalName" berhasil ditambahkan ke ${widget.data.title} 🎉',
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          duration:
                                                              const Duration(
                                                                seconds: 2,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppTheme
                                                          .primaryPurple,
                                                      foregroundColor:
                                                          Colors.white,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 18,
                                                            vertical: 10,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      actionName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          } else {
                                            if (_itemSubmitted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  backgroundColor:
                                                      Colors.blue.shade700,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                  ),
                                                  content: const Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .info_outline_rounded,
                                                        color: Colors.white,
                                                        size: 17,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          'Item sudah diajukan sebelumnya. Menunggu proses review.',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  duration: const Duration(
                                                    milliseconds: 1800,
                                                  ),
                                                ),
                                              );
                                              return;
                                            }
                                            showDialog(
                                              context: context,
                                              builder: (dctx) => AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(22),
                                                ),
                                                title: Row(
                                                  children: [
                                                    Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        gradient: AppTheme
                                                            .primaryGradient,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Icon(
                                                        Icons
                                                            .rocket_launch_rounded,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        'Konfirmasi $actionName',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                content: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Anda akan $actionName untuk item berikut:',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            12,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors.grey.shade50,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              14,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors
                                                              .grey
                                                              .shade200,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            width: 34,
                                                            height: 34,
                                                            decoration: BoxDecoration(
                                                              gradient:
                                                                  LinearGradient(
                                                                    colors: widget
                                                                        .data
                                                                        .gradient,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    10,
                                                                  ),
                                                            ),
                                                            child: Icon(
                                                              item?.icon ??
                                                                  Icons
                                                                      .edit_outlined,
                                                              size: 16,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  targetName,
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        12.5,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w800,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 2,
                                                                ),
                                                                Text(
                                                                  item?.subtitle ??
                                                                      widget
                                                                          .data
                                                                          .subtitle,
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        10.5,
                                                                    color: Colors
                                                                        .grey
                                                                        .shade600,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 14),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .schedule_rounded,
                                                          size: 13,
                                                          color: Colors
                                                              .grey
                                                              .shade600,
                                                        ),
                                                        const SizedBox(
                                                          width: 5,
                                                        ),
                                                        Text(
                                                          'Estimasi review: 1-2 hari kerja',
                                                          style: TextStyle(
                                                            fontSize: 10.5,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Colors
                                                                .grey
                                                                .shade600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .verified_user_outlined,
                                                          size: 13,
                                                          color: AppTheme
                                                              .primaryPurple,
                                                        ),
                                                        const SizedBox(
                                                          width: 5,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            'Setelah disetujui, item akan tampil di halaman publik.',
                                                            style: TextStyle(
                                                              fontSize: 10.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: AppTheme
                                                                  .primaryPurple,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(dctx),
                                                    child: Text(
                                                      'Batal',
                                                      style: TextStyle(
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _itemSubmitted = true;
                                                      });
                                                      Navigator.pop(dctx);
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          behavior:
                                                              SnackBarBehavior
                                                                  .floating,
                                                          backgroundColor:
                                                              Colors
                                                                  .green
                                                                  .shade600,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  14,
                                                                ),
                                                          ),
                                                          content: Row(
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .local_post_office_rounded,
                                                                color: Colors
                                                                    .white,
                                                                size: 17,
                                                              ),
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              Expanded(
                                                                child: Text(
                                                                  '"$targetName" berhasil diajukan 📤 Menunggu review tim.',
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          duration:
                                                              const Duration(
                                                                seconds: 2,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppTheme
                                                          .primaryPurple,
                                                      foregroundColor:
                                                          Colors.white,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 18,
                                                            vertical: 10,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      actionName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 15,
                                          ),
                                          child: Center(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isNew
                                                      ? Icons
                                                            .add_circle_outline_rounded
                                                      : (_itemSubmitted
                                                            ? Icons
                                                                  .schedule_send_rounded
                                                            : Icons
                                                                  .rocket_launch_rounded),
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  isNew
                                                      ? 'Buat Baru'
                                                      : (_itemSubmitted
                                                            ? 'Menunggu Review'
                                                            : widget
                                                                  .actionLabel),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShareTile(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab(
    BuildContext context,
    ScrollController scrollCtrl,
    bool isDark,
    bool isNew,
  ) {
    final item = widget.item;
    final user = widget.user;
    final now = DateTime.now();
    final createdDate = DateTime(now.year, now.month - 1, now.day - 3);
    final updatedDate = DateTime(now.year, now.month, now.day - 1);
    String fmtPrice(String raw) {
      if (raw.isEmpty) return '';
      final n = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (n == 0) return raw;
      final s = n.toString();
      String out = '';
      for (int i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) out += '.';
        out += s[i];
      }
      return 'Rp $out';
    }

    final detailValues = isNew
        ? <(String, IconData, String, String)>[
            (
              'Nama item',
              Icons.drive_file_rename_outline,
              _formName.isEmpty
                  ? 'Klik untuk mengisi nama item/layanan'
                  : _formName,
              _formName.isNotEmpty ? 'Siap' : 'Wajib',
            ),
            (
              'Deskripsi singkat',
              Icons.description_outlined,
              _formDesc.isEmpty
                  ? 'Klik untuk menulis deskripsi (min. 30 kata)'
                  : _formDesc,
              _formDesc.length > 60
                  ? '${_formDesc.length} karakter'
                  : (_formDesc.isNotEmpty ? 'Draft' : 'Opsional'),
            ),
            (
              'Kategori / Tag',
              Icons.label_outline_rounded,
              _formTag.isEmpty
                  ? 'Klik untuk memilih tag kategori'
                  : 'Tag aktif: $_formTag',
              _formTag.isNotEmpty ? _formTag : 'Pilih',
            ),
            (
              'Nilai / Harga',
              Icons.price_change_outlined,
              _formPrice.isEmpty
                  ? 'Klik untuk memasukkan nilai harga'
                  : fmtPrice(_formPrice),
              _formPrice.isNotEmpty
                  ? fmtPrice(_formPrice).replaceAll('Rp ', 'Rp ')
                  : '',
            ),
            (
              'Thumbnail / Icon',
              Icons.image_outlined,
              _formIcon == null
                  ? 'Klik untuk memilih icon thumbnail'
                  : 'Icon terpilih',
              _formIcon != null ? 'Terpilih' : '',
            ),
            (
              'Tanggal dibuat',
              Icons.event_available_rounded,
              _formDate == null
                  ? 'Klik untuk memilih tanggal & waktu'
                  : '${_formDate!.day} ${_monthId(_formDate!.month)} ${_formDate!.year} • ${_formDate!.hour.toString().padLeft(2, '0')}:${_formDate!.minute.toString().padLeft(2, '0')} WIB',
              _formDate != null ? 'Terjadwal' : '',
            ),
          ]
        : [
            (
              'Detail Lengkap',
              Icons.info_outline_rounded,
              item?.subtitle ?? '-',
              '',
            ),
            (
              'Dibuat pada',
              Icons.calendar_today_outlined,
              '${createdDate.day} ${_monthId(createdDate.month)} ${createdDate.year} • 09:12 WIB',
              user.name,
            ),
            (
              'Terakhir diperbarui',
              Icons.update_outlined,
              '${updatedDate.day} ${_monthId(updatedDate.month)} ${updatedDate.year} • ${updatedDate.hour.toString().padLeft(2, '0')}:${(updatedDate.minute).toString().padLeft(2, '0')} WIB',
              user.name,
            ),
            (
              'Riwayat perubahan',
              Icons.history_outlined,
              '4 revisi • terakhir oleh ${user.name}',
              'Lihat Riwayat',
            ),
            (
              'Lampiran & File',
              Icons.attach_file_outlined,
              item?.value ?? '-',
              '${item != null ? _guessFileCount(item.title) : 0} File',
            ),
            (
              'Kolaborator',
              Icons.people_outline,
              '${user.name}, Tim Kreavana',
              '2 Orang',
            ),
          ];
    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        if (item != null) ...[
          Text(
            'Ringkasan',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark2 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
              ),
            ),
            child: Text(
              item.subtitle,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
        Text(
          isNew ? 'Kolom yang Akan Diisi' : 'Detail & Metadata',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(detailValues.length, (i) {
          final f = detailValues[i];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 400 + (i * 80)),
            curve: Curves.easeOutCubic,
            builder: (_, val, child) {
              return Opacity(
                opacity: val.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1 - val) * 10),
                  child: child,
                ),
              );
            },
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                if (isNew) {
                  _handleFormTap(i);
                } else {
                  if (i == 3) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: AppTheme.primaryPurple,
                        content: const Text(
                          'Riwayat revisi sedang dimuat...',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        duration: const Duration(milliseconds: 1200),
                      ),
                    );
                  } else if (i == 4) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: AppTheme.primaryPurple,
                        content: Text(
                          'Membuka lampiran ${f.$1}...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        duration: const Duration(milliseconds: 1200),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: AppTheme.primaryPurple,
                        content: Text(
                          '${f.$1} disalin ke clipboard ✓',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        duration: const Duration(milliseconds: 1200),
                      ),
                    );
                  }
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark2 : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryPurple.withValues(alpha: 0.12),
                            AppTheme.lightPurple.withValues(alpha: 0.12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        f.$2,
                        size: 16,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.$1,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            f.$3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark
                                  ? AppTheme.textMuted
                                  : Colors.grey.shade500,
                            ),
                          ),
                          if (f.$4.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                f.$4,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: AppTheme.primaryPurple,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  int _guessFileCount(String title) {
    final h = title.hashCode.abs();
    return 2 + (h % 7);
  }

  String _monthId(int m) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return months[(m - 1).clamp(0, 11)];
  }

  Widget _buildReviewTab(
    BuildContext context,
    ScrollController scrollCtrl,
    bool isDark,
  ) {
    final user = widget.user;
    final List<
      ({
        String name,
        String city,
        String text,
        int stars,
        String date,
        bool verified,
        int likes,
      })
    >
    baseReviews = [
      (
        name: 'Siti Aisyah Putri',
        city: 'Jakarta Selatan',
        text:
            'Hasil editan video sangat memuaskan! Color grading-nya sinematik banget, sesuai dengan referensi yang saya berikan. Komunikatif dan revisi cepat. Recommended buat yang butuh edit video profesional!',
        stars: 5,
        date: '2 hari lalu',
        verified: true,
        likes: 24,
      ),
      (
        name: 'Budi Pratama',
        city: 'Bandung',
        text:
            'Retouch foto prewedding hasilnya natural, tidak over-edit. Kulit terlihat nyata tapi tetap bersih. Pengiriman tepat waktu bahkan lebih cepat dari deadline. Harga worth it untuk kualitas begini.',
        stars: 5,
        date: '5 hari lalu',
        verified: true,
        likes: 18,
      ),
      (
        name: 'Dewi Lestari',
        city: 'Surabaya',
        text:
            'Motion graphics untuk logo perusahaan saya sangat bagus, smooth dan elegan. Cuma satu revisi kecil dan langsung jadi. Komunikasi via WA cepat, nggak bikin nunggu.',
        stars: 4,
        date: '1 minggu lalu',
        verified: true,
        likes: 12,
      ),
      (
        name: 'Rizky Ramadhani',
        city: 'Yogyakarta',
        text:
            'Pengerjaan foto produk untuk katalog UMKM saya rapi banget. Background bersih, warna produk akurat. Sudah jadi langganan sampai 3 batch. Paket hemat benar-benar hemat.',
        stars: 5,
        date: '2 minggu lalu',
        verified: false,
        likes: 8,
      ),
    ];
    final reviews = [..._customReviews, ...baseReviews];
    final totalReviewsBase = user.followersCount > 0
        ? (user.followersCount ~/ 2).clamp(24, 248)
        : 124;
    final totalReviews = totalReviewsBase + _customReviews.length;
    var fiveStar = (totalReviewsBase * 0.72).round();
    var fourStar = (totalReviewsBase * 0.18).round();
    var threeStar = (totalReviewsBase * 0.07).round();
    var twoStar = (totalReviewsBase * 0.02).round();
    var oneStar = totalReviewsBase - fiveStar - fourStar - threeStar - twoStar;
    for (final r in _customReviews) {
      if (r.stars == 5) {
        fiveStar++;
      } else if (r.stars == 4) {
        fourStar++;
      } else if (r.stars == 3) {
        threeStar++;
      } else if (r.stars == 2) {
        twoStar++;
      } else {
        oneStar++;
      }
    }
    final rating = totalReviews > 0
        ? ((5 * fiveStar +
                      4 * fourStar +
                      3 * threeStar +
                      2 * twoStar +
                      1 * oneStar) /
                  totalReviews)
              .toStringAsFixed(1)
        : '4.9';
    final filterLabels = const ['Semua', '5 Bintang', 'Dengan Foto', 'Terbaru'];
    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.deepPurple.withValues(alpha: 0.08),
                AppTheme.lightPurple.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.primaryPurple.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          rating,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryPurple,
                            letterSpacing: -1,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text(
                            '/5.0',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryPurple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(5, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Icon(
                            i < 4
                                ? Icons.star_rounded
                                : Icons.star_half_rounded,
                            size: 14,
                            color: const Color(0xFFF59E0B),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Berdasarkan $totalReviews ulasan • ${user.name}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark
                            ? AppTheme.textMuted
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: List.generate(5, (i) {
                    final counts = [
                      fiveStar,
                      fourStar,
                      threeStar,
                      twoStar,
                      oneStar,
                    ];
                    final pct = totalReviews > 0
                        ? counts[i] / totalReviews
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Text(
                            '${5 - i}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTheme.textMuted
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Stack(
                                children: [
                                  Container(
                                    height: 6,
                                    color: isDark
                                        ? AppTheme.cardBg
                                        : Colors.grey.shade200,
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: pct.clamp(0.0, 1.0),
                                    child: Container(
                                      height: 6,
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.primaryGradient,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${counts[i]}',
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark
                                  ? AppTheme.textMuted
                                  : Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filterLabels.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (c, i) => GestureDetector(
              onTap: () => setState(() => _selectedFilterReview = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: _selectedFilterReview == i ? 16 : 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: _selectedFilterReview == i
                      ? AppTheme.primaryGradient
                      : null,
                  color: _selectedFilterReview == i
                      ? null
                      : (isDark ? AppTheme.cardDark2 : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedFilterReview == i
                        ? Colors.transparent
                        : (isDark
                              ? AppTheme.inputBorder
                              : Colors.grey.shade200),
                  ),
                  boxShadow: _selectedFilterReview == i
                      ? AppTheme.cardShadowLight
                      : null,
                ),
                child: Center(
                  child: Text(
                    filterLabels[i],
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: _selectedFilterReview == i
                          ? Colors.white
                          : (isDark ? Colors.white : AppTheme.textDark),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                'Ulasan Terbaru',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _showWriteReviewSheet,
              icon: const Icon(Icons.edit_note_rounded, size: 14),
              label: const Text(
                'Tulis Ulasan',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryPurple,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...List.generate(reviews.length, (idx) {
          final r = reviews[idx];
          final liked = _likedReviews.contains(idx);
          final avatarColors = [
            [const Color(0xFFF59E0B), const Color(0xFFF97316)],
            [const Color(0xFF10B981), const Color(0xFF059669)],
            [const Color(0xFF3B82F6), const Color(0xFF6366F1)],
            [const Color(0xFFEC4899), const Color(0xFFF43F5E)],
          ];
          final grad = avatarColors[idx % avatarColors.length];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark2 : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: grad),
                      ),
                      child: Center(
                        child: Text(
                          r.name[0],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                r.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textDark,
                                ),
                              ),
                              if (r.verified) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.verified_rounded,
                                        size: 9,
                                        color: AppTheme.success,
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'Terbeli',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          color: AppTheme.success,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 9,
                                color: isDark
                                    ? AppTheme.textMuted
                                    : Colors.grey.shade500,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${r.city} • ${r.date}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? AppTheme.textMuted
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: List.generate(5, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 1),
                          child: Icon(
                            i < r.stars
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 12,
                            color: const Color(0xFFF59E0B),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  r.text,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() {
                          if (liked) {
                            _likedReviews.remove(idx);
                          } else {
                            _likedReviews.add(idx);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              liked
                                  ? Icons.thumb_up_rounded
                                  : Icons.thumb_up_outlined,
                              size: 13,
                              color: liked
                                  ? AppTheme.primaryPurple
                                  : (isDark
                                        ? AppTheme.textMuted
                                        : Colors.grey.shade500),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${r.likes + (liked ? 1 : 0)} Membantu',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: liked
                                    ? AppTheme.primaryPurple
                                    : (isDark
                                          ? AppTheme.textMuted
                                          : Colors.grey.shade500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppTheme.primaryPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            content: Text(
                              'Membalas ulasan dari ${r.name.split(' ')[0]}...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 13,
                              color: isDark
                                  ? AppTheme.textMuted
                                  : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Balas',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppTheme.textMuted
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Color(0xFFDC2626),
                            content: Text(
                              'Ulasan dilaporkan',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.more_horiz_rounded,
                          size: 14,
                          color: isDark
                              ? AppTheme.textMuted
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
