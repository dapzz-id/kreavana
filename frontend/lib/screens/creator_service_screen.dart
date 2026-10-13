import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../utils/app_errors.dart';
import '../widgets/creator_availability_widget.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../models/job_contract.dart';
import '../services/job_contract_service.dart';
import '../widgets/app_breadcrumbs.dart';
import 'main_navigation.dart';
import 'direct_message_screen.dart';
import '../features/dashboard/screens/community_dashboard_screen.dart';

const _reviewableCreatorPackageKeys = {
  'foto_paket',
  'video_paket',
  'mua_paket',
  'wo_paket',
  'eo_paket',
  'desain_paket',
  'drone_paket',
  'konten_paket',
};

const _creatorBookingKeys = {
  'foto_booking',
  'video_booking',
  'edit_antrian',
  'mc_booking',
  'singer_booking',
  'mua_booking',
  'wo_jadwal',
  'eo_jadwal',
  'drone_booking',
  'talent_jadwal',
  'desain_proyek',
  'konten_campaign',
  'animator_antrian',
};

class CreatorServiceItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? tag;
  final String? value;
  final bool active;
  final List<Color>? gradient;
  final String? id;
  final String? thumbnailUrl;

  const CreatorServiceItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.tag,
    this.value,
    this.active = true,
    this.gradient,
    this.id,
    this.thumbnailUrl,
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
    'thumbnailUrl': thumbnailUrl,
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
      thumbnailUrl: j['thumbnailUrl']?.toString(),
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

  static const _kCompletedTimeline = '${_prefix}completed_timeline_v1';
  static Future<Set<String>> getCompletedTimelineItems() =>
      _loadStringSet(_kCompletedTimeline);
  static Future<void> setCompletedTimelineItems(Set<String> ids) =>
      _saveStringSet(_kCompletedTimeline, ids);

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
    this.stats = const [],
    this.items = const [],
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
      isGrid: true,
    ),
    'foto_booking': CreatorServiceData(
      key: 'foto_booking',
      title: 'Booking & Jadwal',
      subtitle: 'Kelola jadwal pemotretan Anda',
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Konfirmasi Booking',
    ),
    'foto_paket': CreatorServiceData(
      key: 'foto_paket',
      title: 'Paket Harga',
      subtitle: 'Layanan fotografi dengan harga transparan',
      icon: Icons.payments_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Pilih Paket',
    ),
    // ─── Videografer ───────────────────────────────────────────────
    'foto_area': CreatorServiceData(
      key: 'foto_area',
      title: 'Cakupan Area',
      subtitle: 'Wilayah layanan & biaya transportasi',
      icon: Icons.location_on_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    ),
    'video_galeri': CreatorServiceData(
      key: 'video_galeri',
      title: 'Galeri Video',
      subtitle: 'Karya video & film terbaik',
      icon: Icons.videocam_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      isGrid: true,
    ),
    'video_booking': CreatorServiceData(
      key: 'video_booking',
      title: 'Booking & Jadwal',
      subtitle: 'Kelola jadwal produksi video',
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Konfirmasi Booking',
    ),
    'video_paket': CreatorServiceData(
      key: 'video_paket',
      title: 'Paket Harga',
      subtitle: 'Produksi video sesuai kebutuhan',
      icon: Icons.payments_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Pilih Paket',
    ),
    // ─── Editor ────────────────────────────────────────────────────
    'video_equipment': CreatorServiceData(
      key: 'video_equipment',
      title: 'Equipment',
      subtitle: 'Peralatan produksi yang dimiliki',
      icon: Icons.videocam_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    ),
    'edit_portofolio': CreatorServiceData(
      key: 'edit_portofolio',
      title: 'Portofolio Edit',
      subtitle: 'Hasil edit foto & video terbaik',
      icon: Icons.collections_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      isGrid: true,
    ),
    'edit_antrian': CreatorServiceData(
      key: 'edit_antrian',
      title: 'Antrian Kerja',
      subtitle: 'Status pengerjaan proyek Anda',
      icon: Icons.list_alt_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Perbarui Status',
    ),
    'edit_harga': CreatorServiceData(
      key: 'edit_harga',
      title: 'Daftar Harga',
      subtitle: 'Tarif editing transparan',
      icon: Icons.payments_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Pilih Layanan',
    ),
    // ─── MC ────────────────────────────────────────────────────────
    'edit_spesialisasi': CreatorServiceData(
      key: 'edit_spesialisasi',
      title: 'Spesialisasi',
      subtitle: 'Bidang keahlian editing',
      icon: Icons.tune_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    ),
    'mc_profil': CreatorServiceData(
      key: 'mc_profil',
      title: 'Profil MC',
      subtitle: 'Profil profesional Master of Ceremony',
      icon: Icons.mic_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    ),
    'mc_booking': CreatorServiceData(
      key: 'mc_booking',
      title: 'Jadwal & Booking',
      subtitle: 'Jadwal tampil sebagai MC',
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Konfirmasi Booking',
    ),
    'mc_kategori': CreatorServiceData(
      key: 'mc_kategori',
      title: 'Kategori Acara',
      subtitle: 'Jenis acara yang dilayani',
      icon: Icons.theater_comedy_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    ),
    // ─── Penyanyi ──────────────────────────────────────────────────
    'mc_tarif': CreatorServiceData(
      key: 'mc_tarif',
      title: 'Tarif',
      subtitle: 'Tarif layanan MC profesional',
      icon: Icons.payments_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Pilih Paket',
    ),
    'singer_portofolio': CreatorServiceData(
      key: 'singer_portofolio',
      title: 'Portofolio Musik',
      subtitle: 'Penampilan & karya musik',
      icon: Icons.music_note_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      isGrid: true,
    ),
    'singer_booking': CreatorServiceData(
      key: 'singer_booking',
      title: 'Jadwal & Booking',
      subtitle: 'Jadwal penampilan Anda',
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Konfirmasi Booking',
    ),
    'singer_genre': CreatorServiceData(
      key: 'singer_genre',
      title: 'Genre & Repertoar',
      subtitle: 'Genre musik & daftar lagu',
      icon: Icons.library_music_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    ),
    // ─── MUA ───────────────────────────────────────────────────────
    'singer_tarif': CreatorServiceData(
      key: 'singer_tarif',
      title: 'Tarif',
      subtitle: 'Tarif penampilan profesional',
      icon: Icons.payments_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Pilih Paket',
    ),
    'mua_portofolio': CreatorServiceData(
      key: 'mua_portofolio',
      title: 'Portofolio MUA',
      subtitle: 'Hasil rias wajah terbaik',
      icon: Icons.face_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      isGrid: true,
    ),
    'mua_booking': CreatorServiceData(
      key: 'mua_booking',
      title: 'Jadwal Booking',
      subtitle: 'Jadwal rias Anda',
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Konfirmasi Booking',
    ),
    'mua_paket': CreatorServiceData(
      key: 'mua_paket',
      title: 'Paket Harga',
      subtitle: 'Paket rias sesuai kebutuhan',
      icon: Icons.payments_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Pilih Paket',
    ),
    // ─── Wedding Organizer ─────────────────────────────────────────
    'mua_spesialisasi': CreatorServiceData(
      key: 'mua_spesialisasi',
      title: 'Spesialisasi',
      subtitle: 'Keahlian rias & teknik',
      icon: Icons.palette_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    ),
    'wo_paket': CreatorServiceData(
      key: 'wo_paket',
      title: 'Paket Pernikahan',
      subtitle: 'Paket pernikahan lengkap',
      icon: Icons.favorite_outline,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Pilih Paket',
    ),
    'wo_jadwal': CreatorServiceData(
      key: 'wo_jadwal',
      title: 'Jadwal Event',
      subtitle: 'Jadwal pernikahan yang ditangani',
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Kelola Jadwal',
    ),
    'wo_vendor': CreatorServiceData(
      key: 'wo_vendor',
      title: 'Vendor Partner',
      subtitle: 'Jaringan vendor tepercaya',
      icon: Icons.handshake_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    ),
    // ─── Event Organizer ───────────────────────────────────────────
    'wo_timeline': CreatorServiceData(
      key: 'wo_timeline',
      title: 'Timeline WO',
      subtitle: 'Alur kerja pernikahan',
      icon: Icons.timeline_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    ),
    'eo_paket': CreatorServiceData(
      key: 'eo_paket',
      title: 'Paket Event',
      subtitle: 'Paket penyelenggaraan event profesional',
      icon: Icons.festival_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Buat Paket Baru',
    ),
    'eo_jadwal': CreatorServiceData(
      key: 'eo_jadwal',
      title: 'Jadwal Event',
      subtitle: 'Jadwal dan agenda acara yang ditangani',
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Tambah Jadwal',
      items: [
        CreatorServiceItem(
          id: 'j-1',
          title: 'National Tech Startup Pitch Day & Expo 2026',
          subtitle: 'Jakarta Convention Center • 28 Okt 2026, 08:00 - 18:00 WIB',
          icon: Icons.event_available_outlined,
          tag: 'Aktif',
          value: 'Rp 65.000.000',
          active: true,
        ),
        CreatorServiceItem(
          id: 'j-2',
          title: 'Annual Gala Dinner & Awarding Night BUMN 2026',
          subtitle: 'Grand Ballroom Hotel Mulia • 15 Nov 2026, 19:00 - 22:30 WIB',
          icon: Icons.celebration_outlined,
          tag: 'Berjalan',
          value: 'Rp 45.000.000',
          active: true,
        ),
        CreatorServiceItem(
          id: 'j-3',
          title: 'Youth Music & Art Creative Festival',
          subtitle: 'Stadion Madya GBK • 10 Des 2026, 13:00 - 23:00 WIB',
          icon: Icons.music_note_outlined,
          tag: 'Menunggu',
          value: 'Rp 80.000.000',
          active: false,
        ),
      ],
    ),
    'eo_vendor': CreatorServiceData(
      key: 'eo_vendor',
      title: 'Vendor Partner',
      subtitle: 'Jaringan mitra vendor panggung, sound, lighting, dan katering',
      icon: Icons.handshake_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Tambah Vendor',
      items: [
        CreatorServiceItem(
          id: '01a0d6c1-64d5-7196-9c3c-af3580eccef5',
          title: 'PT Audio Kreasi Pro & Acoustic System',
          subtitle: 'Vendor sound system konser 30.000 watt, line array & mic wireless audio',
          icon: Icons.speaker_group_outlined,
          tag: 'Mitra VIP',
          value: 'Rp 15.000.000',
          active: true,
        ),
        CreatorServiceItem(
          id: '01a0d6c1-636e-71dd-beb6-a4210fb07ffb',
          title: 'Visual Prima Nusantara Stage & LED Videotron',
          subtitle: 'LED screen videotron P3.9 indoor 12x4 meter, rigging aluminium & moving beam',
          icon: Icons.tv_outlined,
          tag: 'Mitra VIP',
          value: 'Rp 28.000.000',
          active: true,
        ),
        CreatorServiceItem(
          id: '01a0d6c1-620b-70c9-a2c7-ba80501c8f12',
          title: 'Royal Rasa Boga Catering & Hospitality',
          subtitle: 'Katering prasmanan 600 porsi VIP & reguler, coffee break buffet nusantara',
          icon: Icons.restaurant_outlined,
          tag: 'Mitra Aktif',
          value: 'Rp 18.500.000',
          active: true,
        ),
        CreatorServiceItem(
          id: '01a0d6c1-60a3-727c-b1da-3c7be8aad5bd',
          title: 'Kreavana Media Multicam Live Streaming',
          subtitle: 'Broadcasting 4 kamera Sony FX3, drone live feed, switcher Blackmagic Atem Mini',
          icon: Icons.videocam_outlined,
          tag: 'Mitra Aktif',
          value: 'Rp 9.500.000',
          active: true,
        ),
      ],
    ),
    // ─── Komunitas ─────────────────────────────────────────────────
    'eo_timeline': CreatorServiceData(
      key: 'eo_timeline',
      title: 'Timeline EO',
      subtitle: 'Alur kerja dan tahapan produksi penyelenggaraan event profesional',
      icon: Icons.timeline_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Tambah Tahapan',
      items: [
        CreatorServiceItem(
          id: 't-1',
          title: 'Finalisasi Rundown, Script MC & Artist Rider',
          subtitle: 'Briefing internal panitia, koordinasi guest star, timekeeper sheet, dan technical rundown',
          icon: Icons.assignment_turned_in_outlined,
          tag: 'Selesai',
          value: '100%',
          active: true,
        ),
        CreatorServiceItem(
          id: 't-2',
          title: 'Loading Logistik, Stage Rigging & Sound Check',
          subtitle: 'Setup panggung 14x8m, instalasi videotron, testing tata suara 30.000 watt & lighting show',
          icon: Icons.build_circle_outlined,
          tag: 'Sedang Berjalan',
          value: '75%',
          active: true,
        ),
        CreatorServiceItem(
          id: 't-3',
          title: 'Gladi Resik & Technical Meeting Show Director',
          subtitle: 'Simulasi rundown menit ke menit bersama MC, penampil musik, tim keamanan, dan kru multimedia',
          icon: Icons.sports_score_outlined,
          tag: 'Persiapan',
          value: '40%',
          active: true,
        ),
        CreatorServiceItem(
          id: 't-4',
          title: 'D-Day Show Execution, Registration & VIP Hospitality',
          subtitle: 'Open gate, ticketing QR check-in, live multicam broadcast, dan monitoring stage controller',
          icon: Icons.festival_outlined,
          tag: 'Mendatang',
          value: '10%',
          active: false,
        ),
      ],
    ),
    'komunitas_anggota': CreatorServiceData(
      key: 'komunitas_anggota',
      title: 'Anggota',
      subtitle: 'Kelola keanggotaan komunitas',
      icon: Icons.groups_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    ),
    'komunitas_kegiatan': CreatorServiceData(
      key: 'komunitas_kegiatan',
      title: 'Kegiatan',
      subtitle: 'Agenda kegiatan komunitas',
      icon: Icons.event_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Daftar Kegiatan',
    ),
    'komunitas_pengumuman': CreatorServiceData(
      key: 'komunitas_pengumuman',
      title: 'Pengumuman',
      subtitle: 'Informasi & pengumuman komunitas',
      icon: Icons.campaign_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Lihat Detail',
    ),
    // ─── Desainer ──────────────────────────────────────────────────
    'komunitas_kolaborasi': CreatorServiceData(
      key: 'komunitas_kolaborasi',
      title: 'Kolaborasi Komunitas',
      subtitle: 'Kerjasama dengan pihak lain',
      icon: Icons.handshake_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Ajukan Kolaborasi',
    ),
    'desain_portofolio': CreatorServiceData(
      key: 'desain_portofolio',
      title: 'Portofolio Desain',
      subtitle: 'Karya desain grafis & branding',
      icon: Icons.palette_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      isGrid: true,
    ),
    'desain_proyek': CreatorServiceData(
      key: 'desain_proyek',
      title: 'Proyek & Brief',
      subtitle: 'Proyek desain yang sedang berjalan',
      icon: Icons.assignment_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Perbarui Status',
    ),
    'desain_paket': CreatorServiceData(
      key: 'desain_paket',
      title: 'Paket Desain',
      subtitle: 'Layanan desain dengan harga jelas',
      icon: Icons.payments_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Pilih Paket',
    ),
    // ─── Pilot Drone ───────────────────────────────────────────────
    'desain_spesialisasi': CreatorServiceData(
      key: 'desain_spesialisasi',
      title: 'Spesialisasi',
      subtitle: 'Bidang keahlian desain',
      icon: Icons.tune_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    ),
    'drone_galeri': CreatorServiceData(
      key: 'drone_galeri',
      title: 'Galeri Hasil Drone',
      subtitle: 'Foto & video udara terbaik',
      icon: Icons.airplanemode_active_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      isGrid: true,
    ),
    'drone_booking': CreatorServiceData(
      key: 'drone_booking',
      title: 'Booking & Jadwal',
      subtitle: 'Jadwal penerbangan drone',
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Konfirmasi Booking',
    ),
    'drone_paket': CreatorServiceData(
      key: 'drone_paket',
      title: 'Paket Harga',
      subtitle: 'Layanan drone dengan harga jelas',
      icon: Icons.payments_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Pilih Paket',
    ),
    // ─── Talent & Model ────────────────────────────────────────────
    'drone_equipment': CreatorServiceData(
      key: 'drone_equipment',
      title: 'Peralatan Drone',
      subtitle: 'Armada drone & perlengkapan',
      icon: Icons.videocam_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    ),
    'talent_profil': CreatorServiceData(
      key: 'talent_profil',
      title: 'Profil Talent',
      subtitle: 'Profil profesional talent & model',
      icon: Icons.portrait_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    ),
    'talent_jadwal': CreatorServiceData(
      key: 'talent_jadwal',
      title: 'Jadwal & Booking',
      subtitle: 'Jadwal job sebagai talent',
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Konfirmasi Booking',
    ),
    'talent_kategori': CreatorServiceData(
      key: 'talent_kategori',
      title: 'Kategori Pekerjaan',
      subtitle: 'Jenis pekerjaan yang dilayani',
      icon: Icons.work_outline,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    ),
    // ─── Content Creator ───────────────────────────────────────────
    'talent_tarif': CreatorServiceData(
      key: 'talent_tarif',
      title: 'Tarif',
      subtitle: 'Tarif job talent & model',
      icon: Icons.payments_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Pilih Paket',
    ),
    'konten_portofolio': CreatorServiceData(
      key: 'konten_portofolio',
      title: 'Portofolio Konten',
      subtitle: 'Konten kreatif untuk brand',
      icon: Icons.photo_library_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      isGrid: true,
    ),
    'konten_campaign': CreatorServiceData(
      key: 'konten_campaign',
      title: 'Jadwal & Campaign',
      subtitle: 'Jadwal konten & campaign berjalan',
      icon: Icons.calendar_today_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Kelola Campaign',
    ),
    'konten_paket': CreatorServiceData(
      key: 'konten_paket',
      title: 'Paket & Harga',
      subtitle: 'Paket konten untuk brand',
      icon: Icons.payments_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      actionLabel: 'Pilih Paket',
    ),
    'konten_platform': CreatorServiceData(
      key: 'konten_platform',
      title: 'Platform & Niche',
      subtitle: 'Platform & niche konten',
      icon: Icons.language_outlined,
      gradient: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
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
  String _selectedEoStatus = 'Semua';
  String _selectedSort = 'Terbaru';
  final Set<int> _savedItems = {};
  final Set<int> _likedItems = {};
  final Map<String, List<CreatorServiceItem>> _extraItems = {};
  Set<String> _completedTimelineIds = {};
  List<CreatorServiceItem> _eoPackages = [];
  bool _isLoadingEoPackages = true;
  List<CreatorServiceItem> _bookingContracts = [];
  bool _isLoadingReviewSummary = false;
  double _avgRating = 0.0;
  int _totalReviews = 0;
  final Map<int, int> _reviewDistribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

  late final AnimationController _fadeController;
  late final AnimationController _staggerController;
  late final List<Animation<double>> _itemAnimations;

  CreatorServiceData? get _data {
    final base = CreatorServiceData.of(widget.serviceKey);
    if (base == null) return null;
    if (_reviewableCreatorPackageKeys.contains(base.key)) {
      return CreatorServiceData(
        key: base.key,
        title: base.title,
        subtitle: base.subtitle,
        icon: base.icon,
        gradient: base.gradient,
        stats: base.stats,
        items: _eoPackages,
        isGrid: base.isGrid,
        actionLabel: base.actionLabel,
      );
    }
    final extras = _extraItems[base.key] ?? const [];
    if (_creatorBookingKeys.contains(base.key)) {
      final allBookings = [
        if (_bookingContracts.isNotEmpty) ..._bookingContracts else ...base.items,
        ...extras,
      ];
      return CreatorServiceData(
        key: base.key,
        title: base.title,
        subtitle: base.subtitle,
        icon: base.icon,
        gradient: base.gradient,
        stats: [
          ('${allBookings.length}', 'Total', Icons.event_note_outlined),
          ('${allBookings.where((i) => i.active).length}', 'Aktif', Icons.pending_actions_outlined),
          ('${allBookings.where((i) => !i.active).length}', 'Selesai', Icons.task_alt_outlined),
        ],
        items: allBookings,
        isGrid: base.isGrid,
        actionLabel: base.actionLabel,
      );
    }
    final combinedItems = [
      ...base.items.map((i) {
        final id = i.id ?? i.title;
        if (base.key == 'eo_timeline' && _completedTimelineIds.contains(id)) {
          return CreatorServiceItem(
            id: i.id,
            title: i.title,
            subtitle: i.subtitle,
            icon: Icons.assignment_turned_in_outlined,
            tag: 'Selesai',
            value: '100%',
            active: true,
            gradient: i.gradient,
            thumbnailUrl: i.thumbnailUrl,
          );
        }
        return i;
      }),
      ...extras.map((i) {
        final id = i.id ?? i.title;
        if (base.key == 'eo_timeline' && _completedTimelineIds.contains(id)) {
          return CreatorServiceItem(
            id: i.id,
            title: i.title,
            subtitle: i.subtitle,
            icon: Icons.assignment_turned_in_outlined,
            tag: 'Selesai',
            value: '100%',
            active: true,
            gradient: i.gradient,
            thumbnailUrl: i.thumbnailUrl,
          );
        }
        return i;
      }),
    ];
    return CreatorServiceData(
      key: base.key,
      title: base.title,
      subtitle: base.subtitle,
      icon: base.icon,
      gradient: base.gradient,
      stats: [
        ('${combinedItems.length}', 'Total Item', Icons.grid_view_outlined),
        ('${combinedItems.where((i) => i.active).length}', 'Aktif', Icons.check_circle_outline),
        ('Live', 'Status', Icons.fiber_manual_record_outlined),
      ],
      items: combinedItems,
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
  bool get _isEoMenu => widget.serviceKey.startsWith('eo_');
  bool get _isCreatorPackage =>
      _reviewableCreatorPackageKeys.contains(widget.serviceKey);

  double get _personalRating {
    if (_avgRating > 0) return _avgRating;
    return (_user.followersCount > 500)
        ? 4.95
        : ((_user.followersCount * 0.0035) + 4.2).clamp(4.2, 4.95);
  }

  String get _ratingDisplay {
    if (_isLoadingReviewSummary && _avgRating == 0.0) return '—';
    if (_totalReviews == 0 && _avgRating == 0.0) {
      return _personalRating.toStringAsFixed(1);
    }
    return _personalRating.toStringAsFixed(1);
  }

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
    _fetchReviewSummary();
    Future.delayed(Duration.zero, () {
      _fadeController.forward();
      _staggerController.forward();
    });
  }

  Future<void> _fetchReviewSummary() async {
    final uid = widget.user.id;
    if (uid == null || uid.isEmpty) return;
    setState(() => _isLoadingReviewSummary = true);
    try {
      final res = await ApiService.get('creators/$uid/reviews/summary');
      if (res['status'] == true && res['data'] != null) {
        final d = Map<String, dynamic>.from(res['data']);
        final dist = d['distribution'];
        if (mounted) {
          setState(() {
            _avgRating = (d['average_rating'] as num?)?.toDouble() ?? 0.0;
            _totalReviews = (d['total_reviews'] as num?)?.toInt() ?? 0;
            if (dist is Map) {
              for (var i = 5; i >= 1; i--) {
                final v = dist['$i'] ?? dist[i];
                _reviewDistribution[i] = (v as num?)?.toInt() ?? 0;
              }
            }
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingReviewSummary = false);
    }
  }

  Future<void> _loadPersistedState() async {
    try {
      if (_reviewableCreatorPackageKeys.contains(widget.serviceKey)) {
        await _loadCreatorPackages();
      }
      if (_creatorBookingKeys.contains(widget.serviceKey)) {
        await _loadBookingContracts();
      }
      if (widget.serviceKey == 'eo_timeline') {
        final completed = await CreatorLocalStorage.getCompletedTimelineItems();
        if (mounted && completed.isNotEmpty) {
          setState(() => _completedTimelineIds = completed);
        }
      }
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

  Future<void> _loadBookingContracts() async {
    try {
      final List<JobContract> contracts = await JobContractService.getUserContracts();
      final items = contracts.map((c) {
        final dateStr = c.deadline != null
            ? '${c.deadline!.day}/${c.deadline!.month}/${c.deadline!.year}'
            : (c.scheduledStartDate != null
                ? '${c.scheduledStartDate!.day}/${c.scheduledStartDate!.month}/${c.scheduledStartDate!.year}'
                : 'Jadwal Fleksibel');
        return CreatorServiceItem(
          id: c.id,
          title: c.title,
          subtitle: '${c.clientName.isNotEmpty ? c.clientName : "Klien"} • $dateStr',
          icon: Icons.calendar_today_outlined,
          tag: c.workStatus.toUpperCase(),
          value: 'Rp ${c.agreedPrice.toStringAsFixed(0)}',
          active: c.workStatus != 'completed',
        );
      }).toList();
      if (mounted) setState(() => _bookingContracts = items);
    } catch (_) {}
  }

  Future<void> _loadCreatorPackages() async {
    try {
      final response = await ApiService.get(
        'creator-services/mine',
        queryParams: {
          'category': 'creator_package',
          'package_type': widget.serviceKey,
        },
      );
      if (response['status'] != true || response['data'] is! List) {
        if (mounted) setState(() => _isLoadingEoPackages = false);
        return;
      }

      final packages = (response['data'] as List).map((raw) {
        final json = Map<String, dynamic>.from(raw as Map);
        final status = json['status']?.toString() ?? 'pending';
        final tag = switch (status) {
          'active' => 'Tayang Publik',
          'rejected' => 'Ditolak',
          _ => 'Menunggu Review',
        };
        final price = double.tryParse(json['price']?.toString() ?? '') ?? 0;
        final priceText = price.round().toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => '.',
        );
        final reviewNote = json['review_note']?.toString();
        final description = json['description']?.toString() ?? '';

        return CreatorServiceItem(
          id: json['id']?.toString(),
          title: json['title']?.toString() ?? 'Paket Event',
          subtitle: status == 'rejected' && reviewNote != null
              ? '$description • Catatan admin: $reviewNote'
              : description,
          icon: Icons.festival_outlined,
          tag: tag,
          value: 'Rp $priceText',
          active: status == 'active',
          thumbnailUrl: json['thumbnail_url']?.toString(),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _eoPackages = packages;
          _isLoadingEoPackages = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingEoPackages = false);
    }
  }

  Future<String?> _submitCreatorPackage(
    CreatorServiceItem item,
    PlatformFile? thumbnail,
    Uint8List? thumbnailBytes,
  ) async {
    if (thumbnail == null || thumbnailBytes == null) {
      return 'Pilih foto thumbnail terlebih dahulu.';
    }
    final price =
        double.tryParse(item.value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '') ??
        0;
    final formData = FormData.fromMap({
      'title': item.title,
      'description': item.subtitle,
      'category': 'creator_package',
      'package_type': widget.serviceKey,
      'price': price,
      'duration_info': '',
      'thumbnail': MultipartFile.fromBytes(
        thumbnailBytes,
        filename: thumbnail.name,
      ),
    });
    final response = await ApiService.postFormData(
      'creator-services',
      formData,
    );

    if (response['status'] != true) {
      return response['message']?.toString() ?? 'Paket gagal diajukan.';
    }

    await _loadCreatorPackages();
    return null;
  }

  Future<void> _handleResubmitPackage(CreatorServiceItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: dark ? AppTheme.cardDark2 : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFFEF4444),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Ajukan Ulang Paket?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Paket "${item.title}" akan diajukan ulang ke admin untuk peninjauan. Status akan berubah menjadi "Menunggu Review".',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: dark ? AppTheme.textMuted : Colors.grey.shade700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Batal',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              child: const Text(
                'Ya, Ajukan Ulang',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final price = double.tryParse(
          item.value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '',
        ) ??
        0;

    String cleanDesc = item.subtitle;
    if (cleanDesc.contains('Catatan admin:') ||
        cleanDesc.contains('catatan admin:')) {
      final parts = cleanDesc.split(
        RegExp(r'[•·]\s*Catatan admin:\s*', caseSensitive: false),
      );
      if (parts.isNotEmpty) {
        cleanDesc = parts[0].trim();
      }
    }

    try {
      final res = await ApiService.put(
        'creator-services/${item.id}',
        {
          'title': item.title,
          'description': cleanDesc,
          'price': price,
          'category': 'creator_package',
          'package_type': widget.serviceKey,
        },
      );

      if (res['status'] == true) {
        if (mounted) {
          AppSnackbar.success(
            context,
            'Paket "${item.title}" berhasil diajukan ulang ke admin.',
            title: 'Pengajuan Terkirim',
          );
        }
        await _loadCreatorPackages();
      } else {
        if (mounted) {
          AppSnackbar.error(
            context,
            res['message']?.toString() ?? 'Gagal mengajukan ulang paket.',
            title: 'Gagal Mengajukan Ulang',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(
          context,
          'Terjadi kesalahan saat mengajukan ulang.',
          title: 'Kesalahan Jaringan',
        );
      }
    }
  }

  Future<void> _handleConfirmSchedule(CreatorServiceItem item) async {
    final contractId = item.id;
    if (contractId == null || contractId.isEmpty) {
      AppSnackbar.warning(
        context,
        'ID kontrak agenda tidak ditemukan.',
        title: 'Gagal Konfirmasi',
      );
      return;
    }

    try {
      final success = await JobContractService.confirmSchedule(contractId);
      if (success) {
        if (mounted) {
          AppSnackbar.success(
            context,
            'Jadwal agenda "${item.title}" berhasil dikonfirmasi dan status diperbarui.',
            title: 'Jadwal Dikonfirmasi',
          );
          await _loadBookingContracts();
        }
      } else {
        if (mounted) {
          AppSnackbar.error(
            context,
            'Gagal mengonfirmasi jadwal agenda ke server.',
            title: 'Gagal',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(
          context,
          'Terjadi kesalahan saat mengonfirmasi jadwal: $e',
          title: 'Kesalahan Sistem',
        );
      }
    }
  }

  void _handleCompleteTimeline(CreatorServiceItem item) {
    final itemId = item.id ?? item.title;
    setState(() {
      _completedTimelineIds.add(itemId);
    });
    CreatorLocalStorage.setCompletedTimelineItems(_completedTimelineIds);
    AppSnackbar.success(
      context,
      'Tahapan "${item.title}" berhasil ditandai selesai (100%).',
      title: 'Progres Diperbarui',
    );
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
    if (widget.serviceKey.startsWith('komunitas_')) {
      return CommunityDashboardScreen(
        user: widget.user,
        initialServiceKey: widget.serviceKey,
        onUserUpdated: widget.onUserUpdated ?? (_) {},
        showSidebar: true,
      );
    }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      backgroundColor: _isEoMenu
          ? (isDark ? AppTheme.surfaceDark : const Color(0xFFF7F8FC))
          : null,
      appBar: _isEoMenu
          ? null
          : AppBar(
        toolbarHeight: _isEoMenu ? 64 : 75,
        backgroundColor: _isEoMenu
            ? (isDark ? AppTheme.cardDark : Colors.white)
            : null,
        surfaceTintColor: Colors.transparent,
        title: _isEoMenu
            ? Text(
                data.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              )
            : Row(
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
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
        automaticallyImplyLeading: !isDesktop && Navigator.canPop(context),
        leading: (!isDesktop && Navigator.canPop(context))
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: _isEoMenu
            ? const []
            : [
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
      body: _isEoMenu || _isCreatorPackage
          ? _buildEoMenuBody(context, data)
          : FadeTransition(
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
                      child: CreatorAvailabilityWidget(
                        creatorId: _user.id ?? '',
                      ),
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
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
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
      floatingActionButton: _isEoMenu
          ? (!isDesktop
              ? FloatingActionButton.extended(
                  onPressed: () => _showDetail(context, data, null),
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  icon: const Icon(Icons.add),
                  label: Text(
                    _isCreatorPackage ? 'Ajukan Paket' : data.actionLabel,
                  ),
                )
              : null)
          : (_isCreatorPackage
              ? FloatingActionButton.extended(
                  onPressed: () => _showDetail(context, data, null),
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajukan Paket'),
                )
              : _buildFAB(context, data)),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildEoMenuBody(BuildContext context, CreatorServiceData data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final screenWidth = MediaQuery.of(context).size.width;

    final allItems = data.items;
    final filteredItems = _getFilteredEoItems(data);

    return RefreshIndicator(
      onRefresh: _refreshEoData,
      color: AppTheme.primaryPurple,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1260),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 32 : 16,
                isDesktop ? 32 : 16,
                isDesktop ? 32 : 16,
                isDesktop ? 60 : 100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Breadcrumbs ──
                  AppBreadcrumbs(
                    items: [
                      BreadcrumbItem(
                        label: 'Beranda',
                        icon: Icons.home_rounded,
                        onTap: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MainNavigation(
                                initialUser: widget.user,
                                initialIndex: 0,
                              ),
                            ),
                            (r) => false,
                          );
                        },
                      ),
                      const BreadcrumbItem(
                        label: 'Layanan EO',
                        icon: Icons.festival_rounded,
                      ),
                      BreadcrumbItem(
                        label: data.title,
                        icon: data.icon,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Header Desktop & Mobile ──
                  _buildEoHeader(data, isDark, isDesktop),
                  const SizedBox(height: 24),

                  // ── KPI Summary Cards ──
                  _buildEoSummaryMetrics(data, allItems, isDark, isDesktop),
                  const SizedBox(height: 24),

                  // ── Search & Filter Controls ──
                  _buildEoSearchAndFilters(data, allItems, isDark, isDesktop),
                  const SizedBox(height: 20),

                  // ── Content Grid or Empty State ──
                  if (_isLoadingEoPackages &&
                      _reviewableCreatorPackageKeys.contains(data.key))
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (filteredItems.isEmpty)
                    _buildEoEmptyState(isDark)
                  else
                    _buildEoProjectsGrid(
                      filteredItems,
                      data,
                      isDark,
                      isDesktop,
                      screenWidth,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshEoData() async {
    if (_reviewableCreatorPackageKeys.contains(widget.serviceKey)) {
      await _loadCreatorPackages();
    }
    if (_creatorBookingKeys.contains(widget.serviceKey)) {
      await _loadBookingContracts();
    }
    await _loadPersistedState();
  }

  List<CreatorServiceItem> _getFilteredEoItems(CreatorServiceData data) {
    var items = List<CreatorServiceItem>.from(data.items);
    if (_selectedEoStatus != 'Semua') {
      final s = _selectedEoStatus.toLowerCase();
      items = items.where((item) {
        final tag = (item.tag ?? '').toLowerCase();
        if (s == 'tayang publik') {
          return tag.contains('tayang') || item.active;
        } else if (s == 'menunggu review' || s == 'menunggu') {
          return tag.contains('menunggu') || tag.contains('pending');
        } else if (s == 'ditolak') {
          return tag.contains('ditolak') || tag.contains('rejected');
        } else if (s == 'aktif' || s == 'mitra aktif' || s == 'jadwal aktif') {
          return tag.contains('aktif') || item.active;
        } else if (s == 'berjalan' || s == 'sedang berjalan') {
          return tag.contains('berjalan');
        } else if (s == 'selesai') {
          return tag.contains('selesai') || item.value == '100%';
        } else if (s == 'persiapan') {
          return tag.contains('persiapan');
        } else if (s == 'mitra vip') {
          return tag.contains('vip');
        } else if (s == 'reguler' || s == 'mitra reguler') {
          return tag.contains('reguler');
        } else if (s == 'mendatang') {
          return tag.contains('mendatang');
        }
        return tag == s;
      }).toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      items = items.where((i) {
        return i.title.toLowerCase().contains(q) ||
            i.subtitle.toLowerCase().contains(q) ||
            (i.tag?.toLowerCase().contains(q) ?? false) ||
            (i.value?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    return items;
  }

  Widget _buildEoHeader(CreatorServiceData data, bool isDark, bool isDesktop) {
    final titleText = switch (data.key) {
      'eo_paket' => 'Kelola Penawaran Event',
      'eo_jadwal' => 'Jadwal & Agenda Event',
      'eo_vendor' => 'Vendor Partner & Mitra',
      'eo_timeline' => 'Timeline & Progres EO',
      _ => data.title,
    };

    final subtitleText = switch (data.key) {
      'eo_paket' =>
        'Pantau penawaran paket, pengajuan review, dan status tayang publik Anda.',
      'eo_jadwal' =>
        'Pantau kalender pelaksanaan event, jadwal gladi resik, dan hari penyelenggaraan.',
      'eo_vendor' =>
        'Kelola kemitraan vendor panggung, tata suara, videotron LED, katering, dan lighting.',
      'eo_timeline' =>
        'Pantau alur kerja tahapan persiapan, rundown produksi, dan progres eksekusi event Anda.',
      _ => data.subtitle,
    };

    final actionLabel = switch (data.key) {
      'eo_paket' => 'Buat Paket Baru',
      'eo_jadwal' => 'Tambah Jadwal',
      'eo_vendor' => 'Tambah Vendor',
      'eo_timeline' => 'Tambah Tahapan',
      _ => data.actionLabel,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!isDesktop && Navigator.canPop(context))
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardBg : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titleText,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitleText,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _refreshEoData,
          tooltip: 'Segarkan data realtime',
          style: IconButton.styleFrom(
            backgroundColor: isDark ? AppTheme.cardBg : Colors.white,
            side: BorderSide(
              color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        if (isDesktop) ...[
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _showDetail(context, data, null),
            icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            label: Text(
              actionLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Map<String, dynamic>> _getEoMetricOptions(
    CreatorServiceData data,
    List<CreatorServiceItem> allItems,
  ) {
    switch (data.key) {
      case 'eo_paket':
        final total = allItems.length;
        final tayang = allItems
            .where(
              (i) =>
                  (i.tag?.toLowerCase().contains('tayang') ?? false) ||
                  i.active,
            )
            .length;
        final menunggu = allItems
            .where((i) => i.tag?.toLowerCase().contains('menunggu') ?? false)
            .length;
        final ditolak = allItems
            .where((i) => i.tag?.toLowerCase().contains('ditolak') ?? false)
            .length;
        return [
          {
            'status': 'Semua',
            'label': 'Total Paket',
            'value': '$total',
            'icon': Icons.folder_special_rounded,
            'color': const Color(0xFF6366F1),
          },
          {
            'status': 'Tayang Publik',
            'label': 'Tayang Publik',
            'value': '$tayang',
            'icon': Icons.public_rounded,
            'color': const Color(0xFF10B981),
          },
          {
            'status': 'Menunggu Review',
            'label': 'Menunggu Review',
            'value': '$menunggu',
            'icon': Icons.hourglass_top_rounded,
            'color': const Color(0xFFF59E0B),
          },
          {
            'status': 'Ditolak',
            'label': 'Ditolak',
            'value': '$ditolak',
            'icon': Icons.cancel_outlined,
            'color': const Color(0xFFEF4444),
          },
        ];
      case 'eo_jadwal':
        final total = allItems.length;
        final aktif = allItems
            .where(
              (i) =>
                  (i.tag?.toLowerCase().contains('aktif') ?? false) ||
                  i.active,
            )
            .length;
        final berjalan = allItems
            .where((i) => i.tag?.toLowerCase().contains('berjalan') ?? false)
            .length;
        final menunggu = allItems
            .where((i) => i.tag?.toLowerCase().contains('menunggu') ?? false)
            .length;
        final selesai = allItems
            .where(
              (i) =>
                  (i.tag?.toLowerCase().contains('selesai') ?? false) ||
                  !i.active,
            )
            .length;
        return [
          {
            'status': 'Semua',
            'label': 'Total Agenda',
            'value': '$total',
            'icon': Icons.calendar_month_rounded,
            'color': const Color(0xFF6366F1),
          },
          {
            'status': 'Aktif',
            'label': 'Jadwal Aktif',
            'value': '$aktif',
            'icon': Icons.event_available_rounded,
            'color': const Color(0xFF10B981),
          },
          {
            'status': 'Berjalan',
            'label': 'Sedang Berjalan',
            'value': '$berjalan',
            'icon': Icons.trending_up_rounded,
            'color': const Color(0xFF8B5CF6),
          },
          {
            'status': 'Menunggu',
            'label': 'Menunggu Konfirmasi',
            'value': '$menunggu',
            'icon': Icons.hourglass_top_rounded,
            'color': const Color(0xFFF59E0B),
          },
          {
            'status': 'Selesai',
            'label': 'Selesai',
            'value': '$selesai',
            'icon': Icons.check_circle_rounded,
            'color': const Color(0xFF3B82F6),
          },
        ];
      case 'eo_vendor':
        final total = allItems.length;
        final vip = allItems
            .where((i) => i.tag?.toLowerCase().contains('vip') ?? false)
            .length;
        final aktif = allItems
            .where(
              (i) =>
                  (i.tag?.toLowerCase().contains('aktif') ?? false) ||
                  i.active,
            )
            .length;
        final reguler = allItems
            .where((i) => i.tag?.toLowerCase().contains('reguler') ?? false)
            .length;
        return [
          {
            'status': 'Semua',
            'label': 'Total Mitra',
            'value': '$total',
            'icon': Icons.handshake_rounded,
            'color': const Color(0xFF6366F1),
          },
          {
            'status': 'Mitra VIP',
            'label': 'Mitra VIP',
            'value': '$vip',
            'icon': Icons.workspace_premium_rounded,
            'color': const Color(0xFF8B5CF6),
          },
          {
            'status': 'Mitra Aktif',
            'label': 'Mitra Aktif',
            'value': '$aktif',
            'icon': Icons.verified_rounded,
            'color': const Color(0xFF10B981),
          },
          {
            'status': 'Mitra Reguler',
            'label': 'Mitra Reguler',
            'value': '$reguler',
            'icon': Icons.groups_rounded,
            'color': const Color(0xFF3B82F6),
          },
        ];
      case 'eo_timeline':
        final total = allItems.length;
        final selesai = allItems
            .where(
              (i) =>
                  (i.tag?.toLowerCase().contains('selesai') ?? false) ||
                  i.value == '100%',
            )
            .length;
        final berjalan = allItems
            .where((i) => i.tag?.toLowerCase().contains('berjalan') ?? false)
            .length;
        final persiapan = allItems
            .where((i) => i.tag?.toLowerCase().contains('persiapan') ?? false)
            .length;
        final mendatang = allItems
            .where((i) => i.tag?.toLowerCase().contains('mendatang') ?? false)
            .length;
        return [
          {
            'status': 'Semua',
            'label': 'Total Tahapan',
            'value': '$total',
            'icon': Icons.timeline_rounded,
            'color': const Color(0xFF6366F1),
          },
          {
            'status': 'Selesai',
            'label': 'Tahap Selesai',
            'value': '$selesai',
            'icon': Icons.check_circle_rounded,
            'color': const Color(0xFF10B981),
          },
          {
            'status': 'Berjalan',
            'label': 'Sedang Berjalan',
            'value': '$berjalan',
            'icon': Icons.trending_up_rounded,
            'color': const Color(0xFFF59E0B),
          },
          {
            'status': 'Persiapan',
            'label': 'Tahap Persiapan',
            'value': '$persiapan',
            'icon': Icons.pending_actions_rounded,
            'color': const Color(0xFF8B5CF6),
          },
          {
            'status': 'Mendatang',
            'label': 'Mendatang',
            'value': '$mendatang',
            'icon': Icons.schedule_rounded,
            'color': const Color(0xFF64748B),
          },
        ];
      default:
        return [
          {
            'status': 'Semua',
            'label': 'Total Item',
            'value': '${allItems.length}',
            'icon': Icons.folder_special_rounded,
            'color': const Color(0xFF6366F1),
          },
          {
            'status': 'Aktif',
            'label': 'Aktif',
            'value': '${allItems.where((i) => i.active).length}',
            'icon': Icons.check_circle_rounded,
            'color': const Color(0xFF10B981),
          },
        ];
    }
  }

  Widget _buildEoSummaryMetrics(
    CreatorServiceData data,
    List<CreatorServiceItem> allItems,
    bool isDark,
    bool isDesktop,
  ) {
    final metricData = _getEoMetricOptions(data, allItems);

    if (isDesktop) {
      return Row(
        children: metricData.map((m) {
          final isSelected = _selectedEoStatus == m['status'];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _buildEoMetricCard(m, isSelected, isDark),
            ),
          );
        }).toList(),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: metricData.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 10),
        itemBuilder: (context, idx) {
          final m = metricData[idx];
          final isSelected = _selectedEoStatus == m['status'];
          return SizedBox(
            width: 155,
            child: _buildEoMetricCard(m, isSelected, isDark),
          );
        },
      ),
    );
  }

  Widget _buildEoMetricCard(
    Map<String, dynamic> m,
    bool isSelected,
    bool isDark,
  ) {
    final color = m['color'] as Color;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() {
          if (_selectedEoStatus == m['status']) {
            _selectedEoStatus = 'Semua';
          } else {
            _selectedEoStatus = m['status'] as String;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardBg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(m['icon'] as IconData, size: 18, color: color),
                ),
                Text(
                  m['value'] as String,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              m['label'] as String,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? color
                    : (isDark ? AppTheme.textMuted : Colors.grey.shade600),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEoSearchAndFilters(
    CreatorServiceData data,
    List<CreatorServiceItem> allItems,
    bool isDark,
    bool isDesktop,
  ) {
    final statusOptions = _getEoMetricOptions(data, allItems).map((m) => {
      'key': m['status'] as String,
      'label': m['label'] as String,
      'count': int.tryParse(m['value'] as String) ?? 0,
    }).toList();

    final searchField = TextField(
      controller: _searchController,
      onChanged: (v) {
        setState(() => _query = v);
      },
      decoration: InputDecoration(
        hintText: 'Cari ${data.title.toLowerCase()}...',
        hintStyle: TextStyle(
          fontSize: 13,
          color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
        ),
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _query.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              )
            : null,
        filled: true,
        fillColor: isDark ? AppTheme.cardBg : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppTheme.primaryPurple,
            width: 1.6,
          ),
        ),
      ),
    );

    final filterChips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statusOptions.map((opt) {
          final key = opt['key'] as String;
          final label = opt['label'] as String;
          final count = opt['count'] as int;
          final isSel = _selectedEoStatus == key;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isSel
                          ? Colors.white.withValues(alpha: 0.25)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSel
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
              selected: isSel,
              selectedColor: AppTheme.primaryPurple,
              backgroundColor: isDark ? AppTheme.cardBg : Colors.white,
              side: BorderSide(
                color: isSel
                    ? AppTheme.primaryPurple
                    : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
              ),
              labelStyle: TextStyle(
                color: isSel
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey.shade800),
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
              onSelected: (val) {
                if (val) setState(() => _selectedEoStatus = key);
              },
            ),
          );
        }).toList(),
      ),
    );

    if (isDesktop) {
      return Row(
        children: [
          Expanded(flex: 3, child: searchField),
          const SizedBox(width: 16),
          Expanded(flex: 4, child: filterChips),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        searchField,
        const SizedBox(height: 12),
        filterChips,
      ],
    );
  }

  Widget _buildEoEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: AppTheme.primaryPurple,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak ada item yang sesuai',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Coba sesuaikan kata kunci pencarian atau pilih filter status lainnya.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _selectedEoStatus = 'Semua';
                _query = '';
                _searchController.clear();
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Reset Filter'),
          ),
        ],
      ),
    );
  }

  Widget _buildEoProjectsGrid(
    List<CreatorServiceItem> items,
    CreatorServiceData data,
    bool isDark,
    bool isDesktop,
    double screenWidth,
  ) {
    if (isDesktop) {
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: items.indexed.map((entry) {
          final cardWidth =
              (screenWidth > 1260 ? 1260 : screenWidth) / 2 - 40;
          return SizedBox(
            width: cardWidth > 450 ? cardWidth : double.infinity,
            child: _buildEoUnifiedCard(
              context,
              data,
              entry.$2,
              entry.$1,
              isDark,
            ),
          );
        }).toList(),
      );
    }

    return Column(
      children: items.indexed.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _buildEoUnifiedCard(
            context,
            data,
            entry.$2,
            entry.$1,
            isDark,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEoUnifiedCard(
    BuildContext context,
    CreatorServiceData data,
    CreatorServiceItem item,
    int index,
    bool isDark,
  ) {
    final status = (item.tag ?? '').toLowerCase();

    Color statusColor;
    if (status.contains('tayang') ||
        status.contains('aktif') ||
        status.contains('vip') ||
        status.contains('selesai') ||
        status.contains('disetujui')) {
      statusColor = const Color(0xFF10B981);
    } else if (status.contains('menunggu') ||
        status.contains('pending') ||
        status.contains('persiapan') ||
        status.contains('berjalan')) {
      statusColor = const Color(0xFFF59E0B);
    } else if (status.contains('ditolak') || status.contains('rejected')) {
      statusColor = const Color(0xFFEF4444);
    } else if (status.contains('mendatang')) {
      statusColor = const Color(0xFF64748B);
    } else {
      statusColor = const Color(0xFF8B5CF6);
    }

    final categoryIcon = switch (data.key) {
      'eo_paket' => Icons.festival_rounded,
      'eo_jadwal' => Icons.calendar_month_rounded,
      'eo_vendor' => Icons.handshake_rounded,
      'eo_timeline' => Icons.timeline_rounded,
      _ => item.icon,
    };

    final categoryLabel = switch (data.key) {
      'eo_paket' => 'Paket Event',
      'eo_jadwal' => 'Jadwal Acara',
      'eo_vendor' => 'Mitra Vendor',
      'eo_timeline' => 'Tahapan Rundown',
      _ => data.title,
    };

    final buttonLabel = switch (data.key) {
      'eo_paket' => 'Detail Paket',
      'eo_jadwal' => 'Detail Jadwal',
      'eo_vendor' => 'Detail Vendor',
      'eo_timeline' => 'Detail Tahapan',
      _ => 'Detail Item',
    };

    String mainDesc = item.subtitle;
    String? adminNote;
    if (mainDesc.contains('Catatan admin:') ||
        mainDesc.contains('catatan admin:')) {
      final parts = mainDesc.split(
        RegExp(r'[•·]\s*Catatan admin:\s*', caseSensitive: false),
      );
      if (parts.length > 1) {
        mainDesc = parts[0].trim();
        adminNote = parts[1].trim();
      }
    }

    double? progressDouble;
    if (data.key == 'eo_timeline' || (item.value?.contains('%') ?? false)) {
      progressDouble = _parseProgress(item.value);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Type Pill & Status Badge ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      categoryIcon,
                      size: 14,
                      color: const Color(0xFF8B5CF6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      categoryLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.tag ?? (item.active ? 'Aktif' : 'Nonaktif'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Title ──
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (mainDesc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              mainDesc,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // ── Admin Rejection Note (Alert Badge) ──
          if (adminNote != null && adminNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Catatan Admin: $adminNote',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEF4444),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // ── Metadata Pills (Category, Price/Value, Thumbnail) ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildEoMetaChip(categoryIcon, categoryLabel, isDark),
              if (item.value != null && item.value!.isNotEmpty)
                _buildEoMetaChip(
                  (progressDouble != null)
                      ? Icons.trending_up_rounded
                      : Icons.payments_rounded,
                  item.value!,
                  isDark,
                  highlight: true,
                ),
              if (item.thumbnailUrl != null)
                _buildEoMetaChip(
                  Icons.image_rounded,
                  'Foto Thumbnail',
                  isDark,
                ),
            ],
          ),

          // ── Progress Bar (for Timeline or % items) ──
          if (progressDouble != null) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progres Tahapan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.textMuted
                        : Colors.grey.shade600,
                  ),
                ),
                Text(
                  item.value ?? '${(progressDouble * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progressDouble,
                minHeight: 6,
                backgroundColor: isDark
                    ? Colors.grey.shade800
                    : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // ── Action Buttons ──
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (item.tag?.toLowerCase().contains('ditolak') ?? false) ...[
                OutlinedButton.icon(
                  onPressed: () => _handleResubmitPackage(item),
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text(
                    'Ajukan Ulang',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFFEF4444,
                    ).withValues(alpha: 0.1),
                    foregroundColor: const Color(0xFFDC2626),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    side: const BorderSide(
                      color: Color(0xFFEF4444),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ).copyWith(
                    overlayColor: WidgetStateProperty.all(
                      const Color(0xFFEF4444).withValues(alpha: 0.15),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              OutlinedButton(
                onPressed: () => _showDetail(context, data, item),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryPurple,
                  side: BorderSide(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEoMetaChip(
    IconData icon,
    String text,
    bool isDark, {
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.primaryPurple.withValues(alpha: 0.08)
            : (isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? AppTheme.primaryPurple.withValues(alpha: 0.2)
              : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: highlight
                ? AppTheme.primaryPurple
                : (isDark ? AppTheme.textMuted : Colors.grey.shade600),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              color: highlight
                  ? AppTheme.primaryPurple
                  : (isDark ? Colors.white70 : Colors.grey.shade800),
            ),
          ),
        ],
      ),
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
    if (key.contains('antrian') || key.contains('proyek')) {
      return '8 Proyek';
    }
    if (key.contains('booking') || key.contains('jadwal')) {
      return '6 Agenda';
    }
    if (key.contains('portofolio') || key.contains('galeri')) {
      return '24 Tayangan';
    }
    if (key.contains('harga') ||
        key.contains('paket') ||
        key.contains('tarif')) {
      return '4 Paket';
    }
    return '5 Item';
  }

  String _getAchievementBadge(String key) {
    if (key.contains('spesialisasi')) {
      return 'Expert ✨';
    }
    if (key.contains('portofolio') || key.contains('galeri')) {
      return 'Top Rated ⭐';
    }
    if (key.contains('vendor') || key.contains('partner')) {
      return 'Trusted 🛡️';
    }
    if (key.contains('timeline')) {
      return 'On Track 📈';
    }
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
    final isFiltered = _query.trim().isNotEmpty || _selectedFilter != 'Semua';
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
              isFiltered ? Icons.search_off_rounded : Icons.inbox_outlined,
              size: 44,
              color: AppTheme.primaryPurple,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isFiltered ? 'Tidak ditemukan' : 'Belum Ada Data Tersedia',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isFiltered
                ? 'Coba ubah kata kunci atau filter'
                : 'Data layanan ini masih kosong atau belum ada pemesanan tersimpan.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
            ),
          ),
          if (isFiltered) ...[
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
                          child: _buildEnhancedTag(item.tag!, isDark),
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
                                    _buildEnhancedTag(item.tag!, isDark),
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

  Widget _buildEnhancedTag(String tag, bool isDark) {
    final status = tag.toLowerCase();

    // Enhanced tag colors with gradients
    Color tagColor;
    Color tagBgColor;
    IconData? tagIcon;

    if (status.contains('populer') || status.contains('best value')) {
      tagColor = const Color(0xFF8B5CF6);
      tagBgColor = const Color(0xFF8B5CF6);
      tagIcon = Icons.local_fire_department;
    } else if (status.contains('premium') || status.contains('eksklusif')) {
      tagColor = const Color(0xFFEC4899);
      tagBgColor = const Color(0xFFEC4899);
      tagIcon = Icons.workspace_premium;
    } else if (status.contains('intimate') || status.contains('personal')) {
      tagColor = const Color(0xFF10B981);
      tagBgColor = const Color(0xFF10B981);
      tagIcon = Icons.favorite;
    } else if (status.contains('selesai') || status.contains('aktif')) {
      tagColor = const Color(0xFF27845A);
      tagBgColor = const Color(0xFF27845A);
      tagIcon = Icons.check_circle;
    } else if (status.contains('berjalan') || status.contains('persiapan')) {
      tagColor = const Color(0xFF9A6A16);
      tagBgColor = const Color(0xFF9A6A16);
      tagIcon = Icons.pending;
    } else {
      tagColor = isDark ? AppTheme.textMuted : Colors.grey.shade600;
      tagBgColor = isDark ? AppTheme.textMuted : Colors.grey.shade600;
      tagIcon = null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tagBgColor.withValues(alpha: 0.15),
            tagBgColor.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tagBgColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: tagBgColor.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tagIcon != null) ...[
            Icon(tagIcon, size: 10, color: tagColor),
            const SizedBox(width: 3),
          ],
          Text(
            tag,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: tagColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
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
      barrierColor: data.key.startsWith('eo_') ? Colors.transparent : null,
      builder: (ctx) => _ServiceDetailSheet(
        data: data,
        item: item,
        actionLabel: data.actionLabel,
        user: widget.user,
        totalReviews: _totalReviews,
        avgRating: _avgRating,
        reviewDistribution: _reviewDistribution,
        onAddItem: (newItem) => _addItem(data.key, newItem),
        onSubmitCreatorPackage: _reviewableCreatorPackageKeys.contains(data.key)
            ? _submitCreatorPackage
            : null,
        onResubmitPackage: _reviewableCreatorPackageKeys.contains(data.key)
            ? _handleResubmitPackage
            : null,
        onConfirmSchedule: _handleConfirmSchedule,
        onCompleteTimeline: _handleCompleteTimeline,
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
  final int totalReviews;
  final double avgRating;
  final Map<int, int> reviewDistribution;
  final ValueChanged<CreatorServiceItem>? onAddItem;
  final Future<String?> Function(CreatorServiceItem, PlatformFile?, Uint8List?)?
  onSubmitCreatorPackage;
  final Future<void> Function(CreatorServiceItem)? onResubmitPackage;
  final Future<void> Function(CreatorServiceItem)? onConfirmSchedule;
  final void Function(CreatorServiceItem)? onCompleteTimeline;

  const _ServiceDetailSheet({
    required this.data,
    required this.item,
    required this.actionLabel,
    required this.user,
    this.totalReviews = 0,
    this.avgRating = 0.0,
    this.reviewDistribution = const {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
    this.onAddItem,
    this.onSubmitCreatorPackage,
    this.onResubmitPackage,
    this.onConfirmSchedule,
    this.onCompleteTimeline,
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

  bool get _isEo => widget.data.key.startsWith('eo_');

  Future<void> _openEoVendorChat(String? vendorId, String vendorName) async {
    Navigator.pop(context);
    final targetId = (vendorId != null &&
            vendorId.isNotEmpty &&
            vendorId != widget.user.id &&
            !vendorId.startsWith('v-'))
        ? vendorId
        : '01a0d6c1-64d5-7196-9c3c-af3580eccef5';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DirectMessageScreen(
          currentUser: widget.user,
          targetUserId: targetId,
        ),
      ),
    );
  }

  void _handleEoSubmit({required bool isNew}) {
    if (_formName.trim().isEmpty) {
      AppSnackbar.warning(
        context,
        'Nama item belum diisi. Silakan isi terlebih dahulu.',
        title: 'Nama Wajib Diisi',
      );
      return;
    }
    final newItem = CreatorServiceItem(
      title: _formName.trim(),
      subtitle: _formDesc.trim().isEmpty
          ? 'Item layanan baru ${widget.data.title}'
          : _formDesc.trim(),
      icon: _formIcon ?? widget.data.icon,
      tag: _formTag.isNotEmpty
          ? _formTag
          : (widget.data.key == 'eo_timeline' ? 'Sedang Berjalan' : 'Aktif'),
      value: _formPrice.isNotEmpty
          ? _formPrice
          : (widget.data.key == 'eo_timeline' ? '0%' : '-'),
      active: true,
    );
    widget.onAddItem?.call(newItem);
    Navigator.pop(context);
    AppSnackbar.success(
      context,
      '"${_formName.trim()}" berhasil ditambahkan ke ${widget.data.title}.',
      title: 'Berhasil Ditambahkan',
    );
  }

  void _handleEoFormTap(int i) {
    if (widget.data.key == 'eo_timeline') {
      switch (i) {
        case 0:
          _openTextField(
            title: 'Nama Tahapan',
            initial: _formName,
            maxLines: 1,
            keyboardType: TextInputType.text,
            hint: 'Misal: Gladi Resik Panggung Utama',
            prefix: '',
            onSave: (v) => setState(() => _formName = v),
          );
          break;
        case 1:
          _openTextField(
            title: 'Deskripsi Tahapan',
            initial: _formDesc,
            maxLines: 3,
            keyboardType: TextInputType.multiline,
            hint: 'Rincian alur kerja dan tim pelaksana...',
            prefix: '',
            onSave: (v) => setState(() => _formDesc = v),
          );
          break;
        case 2:
          _openTagPicker((v) => setState(() => _formTag = v));
          break;
        case 3:
          _openTextField(
            title: 'Target Progres',
            initial: _formPrice,
            maxLines: 1,
            keyboardType: TextInputType.text,
            hint: 'Misal: 75% atau 100%',
            prefix: '',
            onSave: (v) => setState(() => _formPrice = v),
          );
          break;
      }
    } else if (widget.data.key == 'eo_vendor') {
      switch (i) {
        case 0:
          _openTextField(
            title: 'Nama Mitra Vendor',
            initial: _formName,
            maxLines: 1,
            keyboardType: TextInputType.text,
            hint: 'Misal: PT Sound Prima Nusantara',
            prefix: '',
            onSave: (v) => setState(() => _formName = v),
          );
          break;
        case 1:
          _openTextField(
            title: 'Spesifikasi & Layanan',
            initial: _formDesc,
            maxLines: 3,
            keyboardType: TextInputType.multiline,
            hint: 'Detail peralatan, panggung, atau katering...',
            prefix: '',
            onSave: (v) => setState(() => _formDesc = v),
          );
          break;
        case 2:
          _openTagPicker((v) => setState(() => _formTag = v));
          break;
        case 3:
          _openTextField(
            title: 'Nilai Kontrak / Biaya',
            initial: _formPrice,
            maxLines: 1,
            keyboardType: TextInputType.number,
            hint: 'Masukkan angka biaya',
            prefix: 'Rp ',
            onSave: (v) => setState(() => _formPrice = v),
          );
          break;
      }
    } else {
      _handleFormTap(i);
    }
  }

  // State untuk menampilkan detail konten di dalam modal yang sama
  String? _expandedDetailTitle;
  String? _expandedDetailContent;

  String _formName = '';
  String _formDesc = '';
  String _formTag = '';
  String _formPrice = '';
  IconData? _formIcon;
  PlatformFile? _formThumbnailFile;
  Uint8List? _formThumbnailBytes;
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
  _apiReviews = [];

  Future<void> _fetchApiReviews() async {
    final uid = widget.user.id;
    if (uid == null || uid.isEmpty) return;
    try {
      final res = await ApiService.get('reviews?creator_id=$uid');
      if (res['status'] == true && res['data'] is List) {
        final list = (res['data'] as List).map((r) {
          final m = Map<String, dynamic>.from(r);
          return (
            name: (m['name'] as String?) ?? 'Klien',
            city: (m['role'] as String?) ?? 'Indonesia',
            text: (m['comment'] as String?) ?? '',
            stars: ((m['rating'] as num?)?.round() ?? 5).clamp(1, 5),
            date: (m['date'] as String?) ?? 'Baru saja',
            verified: (m['verified'] as bool?) ?? true,
            likes: (m['helpfulCount'] as num?)?.toInt() ?? 0,
          );
        }).toList();
        if (mounted) {
          setState(() {
            _apiReviews = list;
          });
        }
      }
    } catch (_) {}
  }
  bool _itemSubmitted = false;
  bool _itemSaved = false;
  bool _isSubmitting = false;

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

  Future<void> _openThumbnailPicker() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (!mounted || file == null) return;
    if (file.size > 5 * 1024 * 1024) {
      AppSnackbar.warning(
        context,
        'Ukuran foto maksimal 5 MB.',
        title: 'Ukuran foto terlalu besar',
      );
      return;
    }

    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _formThumbnailFile = file;
        _formThumbnailBytes = bytes;
      });
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(
        context,
        'Foto tidak dapat dibaca. Silakan pilih file gambar lain.',
        title: 'Gagal membaca foto',
      );
    }
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
        if (_reviewableCreatorPackageKeys.contains(widget.data.key)) {
          _openThumbnailPicker();
        } else {
          _openIconPicker((v) => setState(() => _formIcon = v));
        }
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
                              transform: Matrix4.diagonal3Values(
                                filled ? 1.08 : 1.0,
                                filled ? 1.08 : 1.0,
                                1.0,
                              ),
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
    _fetchApiReviews();
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

    final isRejected = item?.tag?.toLowerCase().contains('ditolak') ?? false;
    final isVendor = widget.data.key == 'eo_vendor';
    final isTimelineNotDone = widget.data.key == 'eo_timeline' &&
        !(item?.tag?.toLowerCase().contains('selesai') ?? false);
    final isJadwal = widget.data.key == 'eo_jadwal';
    final isJadwalPending = isJadwal &&
        (item?.tag?.toUpperCase() == 'SCHEDULED' ||
            item?.tag?.toLowerCase() == 'terjadwal' ||
            item?.tag?.toLowerCase() == 'pending');
    final hasSecondaryAction =
        isRejected || isVendor || isTimelineNotDone || isJadwalPending;

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.transparent,
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
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _isEo
                                      ? AppTheme.primaryPurple.withValues(alpha: 0.1)
                                      : null,
                                  gradient: _isEo
                                      ? null
                                      : LinearGradient(
                                          colors: widget.data.gradient,
                                        ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: _isEo
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: AppTheme.primaryPurple.withValues(
                                              alpha: 0.28,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: !isNew && item?.thumbnailUrl != null
                                    ? Image.network(
                                        ApiService.resolveAssetUrl(
                                          item!.thumbnailUrl,
                                        ),
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Icon(
                                          item.icon,
                                          color: _isEo
                                              ? AppTheme.primaryPurple
                                              : Colors.white,
                                          size: 20,
                                        ),
                                      )
                                    : Icon(
                                        isNew
                                            ? Icons.add_rounded
                                            : (item?.icon ?? widget.data.icon),
                                        color: _isEo
                                            ? AppTheme.primaryPurple
                                            : Colors.white,
                                        size: 20,
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
                                          : (_isEo
                                              ? 'Layanan EO • ${widget.data.title}'
                                              : (item?.subtitle ??
                                                  widget.data.subtitle)),
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
                            child: _isEo
                                ? Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppTheme.cardDark2
                                          : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark
                                            ? AppTheme.inputBorder
                                            : Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryPurple
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                widget.data.key == 'eo_timeline'
                                                    ? Icons.timeline_rounded
                                                    : widget.data.key ==
                                                            'eo_vendor'
                                                        ? Icons
                                                            .payments_outlined
                                                        : widget.data.key ==
                                                                'eo_jadwal'
                                                            ? Icons
                                                                .account_balance_wallet_outlined
                                                            : Icons
                                                                .festival_outlined,
                                                size: 19,
                                                color: AppTheme.primaryPurple,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    widget.data.key ==
                                                            'eo_timeline'
                                                        ? 'Progres Tahapan'
                                                        : widget.data.key ==
                                                                'eo_vendor'
                                                            ? 'Nilai Kontrak / Biaya'
                                                            : widget.data.key ==
                                                                    'eo_jadwal'
                                                                ? 'Estimasi Anggaran'
                                                                : 'Harga Paket',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isDark
                                                          ? AppTheme.textMuted
                                                          : Colors
                                                              .grey.shade600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    item.value!,
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: isDark
                                                          ? Colors.white
                                                          : AppTheme.textDark,
                                                      letterSpacing: -0.2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (item.tag != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: (item.tag?.toLowerCase().contains('ditolak') ?? false)
                                                      ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                                                      : (item.tag == 'Selesai'
                                                          ? const Color(0xFF10B981)
                                                              .withValues(
                                                                alpha: 0.12,
                                                              )
                                                          : AppTheme.primaryPurple
                                                              .withValues(
                                                                alpha: 0.1,
                                                              )),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  item.tag!,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: (item.tag?.toLowerCase().contains('ditolak') ?? false)
                                                        ? const Color(0xFFEF4444)
                                                        : (item.tag == 'Selesai'
                                                            ? const Color(
                                                                0xFF10B981,
                                                              )
                                                            : AppTheme
                                                                .primaryPurple),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (widget.data.key ==
                                            'eo_timeline') ...[
                                          const SizedBox(height: 10),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: ((double.tryParse(item
                                                              .value!
                                                              .replaceAll(
                                                                '%',
                                                                '',
                                                              )
                                                              .trim()) ??
                                                          0) /
                                                      100)
                                                  .clamp(0.0, 1.0),
                                              backgroundColor: isDark
                                                  ? Colors.white12
                                                  : Colors.grey.shade200,
                                              valueColor:
                                                  const AlwaysStoppedAnimation(
                                                AppTheme.primaryPurple,
                                              ),
                                              minHeight: 6,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  )
                                : Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.deepPurple.withValues(
                                            alpha: 0.08,
                                          ),
                                          AppTheme.lightPurple.withValues(
                                            alpha: 0.08,
                                          ),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppTheme.primaryPurple
                                            .withValues(alpha: 0.15),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            gradient: AppTheme.primaryGradient,
                                            borderRadius:
                                                BorderRadius.circular(14),
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
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow:
                                                  AppTheme.cardShadowLight,
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
                        // Hide TabBar for community and EO services - simplify UI
                        if (!widget.data.key.startsWith('komunitas_') && !_isEo)
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
                          child: (widget.data.key.startsWith('komunitas_') || _isEo)
                              ? _buildInfoTab(
                                  context,
                                  scrollCtrl,
                                  isDark,
                                  isNew,
                                )
                              : AnimatedSwitcher(
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
                                if (_isEo) ...[
                                  if (isNew) ...[
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          side: BorderSide(
                                            color: isDark
                                                ? AppTheme.inputBorder
                                                : Colors.grey.shade300,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                        child: Text(
                                          'Batal',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: isDark
                                                ? AppTheme.textMuted
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _handleEoSubmit(isNew: true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.primaryPurple,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.check_rounded,
                                          size: 17,
                                        ),
                                        label: Text(
                                          widget.data.actionLabel,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    if (!hasSecondaryAction) ...[
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            side: BorderSide(
                                              color: isDark
                                                  ? AppTheme.inputBorder
                                                  : Colors.grey.shade300,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: Text(
                                            'Tutup',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: isDark
                                                  ? AppTheme.textMuted
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            side: BorderSide(
                                              color: isDark
                                                  ? AppTheme.inputBorder
                                                  : Colors.grey.shade300,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: Text(
                                            'Tutup',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: isDark
                                                  ? AppTheme.textMuted
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: isVendor ? 2 : 1,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            if (isRejected) {
                                              Navigator.pop(context);
                                              if (item != null) {
                                                widget.onResubmitPackage
                                                    ?.call(item);
                                              }
                                            } else if (isVendor) {
                                              _openEoVendorChat(
                                                item?.id,
                                                item?.title ?? 'Vendor',
                                              );
                                            } else if (widget.data.key ==
                                                'eo_timeline') {
                                              Navigator.pop(context);
                                              if (item != null) {
                                                widget.onCompleteTimeline
                                                    ?.call(item);
                                              }
                                            } else if (widget.data.key ==
                                                'eo_jadwal') {
                                              Navigator.pop(context);
                                              if (item != null) {
                                                widget.onConfirmSchedule
                                                    ?.call(item);
                                              }
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isRejected
                                                ? const Color(0xFFEF4444)
                                                : AppTheme.primaryPurple,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          icon: Icon(
                                            isRejected
                                                ? Icons.refresh_rounded
                                                : (isVendor
                                                    ? Icons
                                                        .chat_bubble_outline_rounded
                                                    : (widget.data.key ==
                                                            'eo_timeline'
                                                        ? Icons.task_alt_rounded
                                                        : Icons
                                                            .check_circle_outline_rounded)),
                                            size: 17,
                                          ),
                                          label: Text(
                                            isRejected
                                                ? 'Ajukan Ulang'
                                                : (isVendor
                                                    ? 'Hubungi Vendor'
                                                    : (widget.data.key ==
                                                            'eo_timeline'
                                                        ? 'Tandai Selesai'
                                                        : 'Konfirmasi Jadwal')),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ] else ...[
                                  // Hide Simpan and Bagikan buttons for community services
                                  if (!widget.data.key.startsWith('komunitas_')) ...[
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
                                ],
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
                                          final isCreatorPackage =
                                              _reviewableCreatorPackageKeys
                                                  .contains(widget.data.key);
                                          final actionName = isNew
                                              ? (isCreatorPackage
                                                    ? 'Ajukan untuk Review'
                                                    : 'Buat Baru')
                                              : (isCreatorPackage
                                                    ? item?.tag ??
                                                          'Status Paket'
                                                    : widget.actionLabel);
                                          final targetName =
                                              item?.title ?? widget.data.title;
                                          if (isCreatorPackage && !isNew) {
                                            AppSnackbar.info(
                                              context,
                                              item?.tag == 'Tayang Publik'
                                                  ? 'Paket ini sudah tampil di publik.'
                                                  : item?.tag == 'Ditolak'
                                                  ? 'Lihat catatan admin pada detail paket untuk memperbaiki pengajuan.'
                                                  : 'Paket ini sedang menunggu review admin.',
                                              title:
                                                  item?.tag ?? 'Status Paket',
                                            );
                                            return;
                                          }
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
                                                    (s.length - i) % 3 == 0) {
                                                  out += '.';
                                                }
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
                                            if (isCreatorPackage &&
                                                _formPrice.trim().isEmpty) {
                                              AppSnackbar.warning(
                                                context,
                                                'Isi harga paket sebelum mengirim pengajuan.',
                                                title: 'Harga belum diisi',
                                              );
                                              return;
                                            }
                                            if (isCreatorPackage &&
                                                _formThumbnailFile == null) {
                                              AppSnackbar.warning(
                                                context,
                                                'Pilih foto thumbnail sebelum mengirim pengajuan.',
                                                title:
                                                    'Thumbnail belum dipilih',
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
                                                      isCreatorPackage
                                                          ? 'Paket akan dikirim ke admin untuk ditinjau sebelum tampil di publik:'
                                                          : 'Item berikut akan ditambahkan ke ${widget.data.title}:',
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
                                                                clipBehavior: Clip
                                                                    .antiAlias,
                                                                child:
                                                                    _formThumbnailBytes !=
                                                                            null &&
                                                                        _reviewableCreatorPackageKeys.contains(
                                                                          widget
                                                                              .data
                                                                              .key,
                                                                        )
                                                                    ? Image.memory(
                                                                        _formThumbnailBytes!,
                                                                        fit: BoxFit
                                                                            .cover,
                                                                      )
                                                                    : Icon(
                                                                        _formIcon ??
                                                                            Icons.edit_outlined,
                                                                        size:
                                                                            15,
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
                                                    onPressed: () async {
                                                      if (_isSubmitting) return;
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
                                                      if (widget
                                                              .onSubmitCreatorPackage !=
                                                          null) {
                                                        setState(() {
                                                          _isSubmitting = true;
                                                        });
                                                        final error =
                                                            await widget
                                                                .onSubmitCreatorPackage!(
                                                              newItem,
                                                              _formThumbnailFile,
                                                              _formThumbnailBytes,
                                                            );
                                                        if (!mounted ||
                                                            !dctx.mounted ||
                                                            !context.mounted) {
                                                          return;
                                                        }
                                                        setState(() {
                                                          _isSubmitting = false;
                                                        });
                                                        if (error != null) {
                                                          AppSnackbar.error(
                                                            context,
                                                            error,
                                                            title:
                                                                'Pengajuan gagal',
                                                          );
                                                          return;
                                                        }
                                                        Navigator.pop(dctx);
                                                        Navigator.pop(context);
                                                        AppSnackbar.success(
                                                          context,
                                                          '"$finalName" masuk antrean review admin.',
                                                          title:
                                                              'Menunggu Review',
                                                        );
                                                        return;
                                                      }
                                                      widget.onAddItem?.call(
                                                        newItem,
                                                      );
                                                      Navigator.pop(dctx);
                                                      Navigator.pop(context);
                                                      AppSnackbar.success(
                                                        context,
                                                        '"$finalName" berhasil ditambahkan ke ${widget.data.title}.',
                                                        title:
                                                            'Berhasil ditambahkan',
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
                                                      _isSubmitting
                                                          ? 'Mengirim...'
                                                          : actionName,
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
                                              AppSnackbar.info(
                                                context,
                                                'Item ini sudah berstatus Menunggu Review.',
                                                title:
                                                    'Pengajuan sudah dicatat',
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
                                                        isCreatorPackage
                                                            ? 'Konfirmasi Pengajuan Paket'
                                                            : 'Konfirmasi $actionName',
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
                                                      isCreatorPackage
                                                          ? 'Ajukan paket ini untuk ditinjau?'
                                                          : 'Anda akan $actionName untuk item berikut:',
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
                                                          isCreatorPackage
                                                              ? 'Status paket akan menjadi Menunggu Review.'
                                                              : 'Estimasi review: 1-2 hari kerja',
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
                                                            isCreatorPackage
                                                                ? 'Pengajuan hanya ditandai di halaman ini.'
                                                                : 'Setelah disetujui, item akan tampil di halaman publik.',
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
                                                      AppSnackbar.success(
                                                        context,
                                                        isCreatorPackage
                                                            ? '"$targetName" ditandai Menunggu Review di halaman ini.'
                                                            : '"$targetName" berhasil diajukan. Menunggu review tim.',
                                                        title: isCreatorPackage
                                                            ? 'Status diperbarui'
                                                            : 'Pengajuan dicatat',
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
      final amount = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (amount == 0) return raw;
      final digits = amount.toString();
      final formatted = StringBuffer();
      for (var i = 0; i < digits.length; i++) {
        if (i > 0 && (digits.length - i) % 3 == 0) formatted.write('.');
        formatted.write(digits[i]);
      }
      return 'Rp $formatted';
    }

    final detailValues = isNew
        ? (_isEo
            ? <(String, IconData, String, String)>[
                (
                  widget.data.key == 'eo_timeline'
                      ? 'Nama Tahapan'
                      : widget.data.key == 'eo_vendor'
                          ? 'Nama Mitra Vendor'
                          : widget.data.key == 'eo_jadwal'
                              ? 'Nama Acara'
                              : 'Nama Paket',
                  Icons.drive_file_rename_outline,
                  _formName.isEmpty
                      ? 'Klik untuk mengisi nama item'
                      : _formName,
                  _formName.isNotEmpty ? 'Siap' : 'Wajib',
                ),
                (
                  widget.data.key == 'eo_timeline'
                      ? 'Deskripsi Tahapan'
                      : widget.data.key == 'eo_vendor'
                          ? 'Spesifikasi & Layanan'
                          : widget.data.key == 'eo_jadwal'
                              ? 'Deskripsi & Agenda'
                              : 'Deskripsi Paket',
                  Icons.description_outlined,
                  _formDesc.isEmpty
                      ? 'Klik untuk menulis rincian'
                      : _formDesc,
                  _formDesc.isNotEmpty ? 'Siap' : 'Opsional',
                ),
                (
                  widget.data.key == 'eo_timeline'
                      ? 'Status Tahapan'
                      : widget.data.key == 'eo_vendor'
                          ? 'Kategori Mitra'
                          : widget.data.key == 'eo_jadwal'
                              ? 'Status Jadwal'
                              : 'Tag Paket',
                  Icons.label_outline_rounded,
                  _formTag.isEmpty
                      ? 'Pilih status'
                      : _formTag,
                  _formTag.isNotEmpty ? _formTag : 'Pilih',
                ),
                (
                  widget.data.key == 'eo_timeline'
                      ? 'Target Progres (%)'
                      : widget.data.key == 'eo_vendor'
                          ? 'Estimasi Biaya / Kontrak'
                          : widget.data.key == 'eo_jadwal'
                              ? 'Estimasi Anggaran'
                              : 'Harga Paket',
                  widget.data.key == 'eo_timeline'
                      ? Icons.timeline_rounded
                      : Icons.price_change_outlined,
                  _formPrice.isEmpty
                      ? 'Klik untuk memasukkan nilai'
                      : _formPrice,
                  _formPrice.isNotEmpty ? _formPrice : '',
                ),
              ]
            : widget.data.key.startsWith('komunitas_')
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
                          ? 'Klik untuk menulis deskripsi'
                          : _formDesc,
                      _formDesc.isNotEmpty ? 'Siap' : 'Opsional',
                    ),
                    (
                      'Status',
                      Icons.label_outline_rounded,
                      _formTag.isEmpty
                          ? 'Menunggu'
                          : _formTag,
                      _formTag.isNotEmpty ? _formTag : 'Menunggu',
                    ),
                  ]
                : <(String, IconData, String, String)>[
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
                      _formPrice.isNotEmpty ? fmtPrice(_formPrice) : '',
                    ),
                    (
                      _reviewableCreatorPackageKeys.contains(widget.data.key)
                          ? 'Foto Thumbnail'
                          : 'Thumbnail / Icon',
                      Icons.image_outlined,
                      _reviewableCreatorPackageKeys.contains(widget.data.key)
                          ? (_formThumbnailFile?.name ??
                              'Pilih foto thumbnail paket')
                          : (_formIcon == null
                              ? 'Klik untuk memilih icon thumbnail'
                              : 'Icon terpilih'),
                      _reviewableCreatorPackageKeys.contains(widget.data.key)
                          ? (_formThumbnailFile != null
                              ? 'Foto dipilih'
                              : 'Wajib')
                          : (_formIcon != null ? 'Terpilih' : ''),
                    ),
                    (
                      'Tanggal dibuat',
                      Icons.event_available_rounded,
                      _formDate == null
                          ? 'Klik untuk memilih tanggal & waktu'
                          : '${_formDate!.day} ${_monthId(_formDate!.month)} ${_formDate!.year} • ${_formDate!.hour.toString().padLeft(2, '0')}:${_formDate!.minute.toString().padLeft(2, '0')} WIB',
                      _formDate != null ? 'Terjadwal' : '',
                    ),
                  ])
        : (_isEo
            ? (widget.data.key == 'eo_timeline'
                ? <(String, IconData, String, String)>[
                    (
                      'Tahapan',
                      Icons.checklist_rounded,
                      item?.title ?? '-',
                      '',
                    ),
                    (
                      'Status',
                      Icons.flag_outlined,
                      item?.tag ?? 'Aktif',
                      '',
                    ),
                    (
                      'Progres',
                      Icons.trending_up_rounded,
                      item?.value ?? '0%',
                      '',
                    ),
                    (
                      'Penanggung Jawab',
                      Icons.person_outline_rounded,
                      user.name,
                      'EO Team',
                    ),
                    (
                      'Terakhir Diperbarui',
                      Icons.schedule_rounded,
                      '${updatedDate.day} ${_monthId(updatedDate.month)} ${updatedDate.year} • 09:12 WIB',
                      '',
                    ),
                  ]
                : widget.data.key == 'eo_vendor'
                    ? <(String, IconData, String, String)>[
                        (
                          'Mitra Vendor',
                          Icons.handshake_outlined,
                          item?.title ?? '-',
                          '',
                        ),
                        (
                          'Status Kemitraan',
                          Icons.verified_outlined,
                          item?.tag ?? 'Mitra Aktif',
                          '',
                        ),
                        (
                          'Biaya Kontrak',
                          Icons.payments_outlined,
                          item?.value ?? '-',
                          '',
                        ),
                        (
                          'PIC / Kontak',
                          Icons.contact_phone_outlined,
                          switch (item?.id) {
                            '01a0d6c1-64d5-7196-9c3c-af3580eccef5' =>
                              'Aditya Pratama (Sound Lead)',
                            '01a0d6c1-636e-71dd-beb6-a4210fb07ffb' =>
                              'Kevin Jonathan (Stage & LED Lead)',
                            '01a0d6c1-620b-70c9-a2c7-ba80501c8f12' =>
                              'Sarah Putri (Catering & F&B Lead)',
                            '01a0d6c1-60a3-727c-b1da-3c7be8aad5bd' =>
                              'Dimas Arya (Broadcast Lead)',
                            _ => 'PIC Vendor Rekanan',
                          },
                          '',
                        ),
                        (
                          'Terakhir Diperbarui',
                          Icons.update_outlined,
                          '${updatedDate.day} ${_monthId(updatedDate.month)} ${updatedDate.year}',
                          '',
                        ),
                      ]
                    : widget.data.key == 'eo_jadwal'
                        ? <(String, IconData, String, String)>[
                            (
                              'Nama Acara',
                              Icons.festival_outlined,
                              item?.title ?? '-',
                              '',
                            ),
                            (
                              'Status Jadwal',
                              Icons.event_available_outlined,
                              item?.tag ?? 'Terjadwal',
                              '',
                            ),
                            (
                              'Estimasi Anggaran',
                              Icons.account_balance_wallet_outlined,
                              item?.value ?? '-',
                              '',
                            ),
                            (
                              'Penyelenggara',
                              Icons.business_outlined,
                              user.name,
                              '',
                            ),
                            (
                              'Terakhir Diperbarui',
                              Icons.update_outlined,
                              '${updatedDate.day} ${_monthId(updatedDate.month)} ${updatedDate.year}',
                              '',
                            ),
                          ]
                        : <(String, IconData, String, String)>[
                            (
                              'Paket Event',
                              Icons.card_giftcard_outlined,
                              item?.title ?? '-',
                              '',
                            ),
                            (
                              'Status Paket',
                              Icons.sell_outlined,
                              item?.tag ?? 'Aktif',
                              '',
                            ),
                            (
                              'Harga Paket',
                              Icons.payments_outlined,
                              item?.value ?? '-',
                              '',
                            ),
                            (
                              'Penyedia Layanan',
                              Icons.storefront_outlined,
                              user.name,
                              '',
                            ),
                            (
                              'Dibuat Pada',
                              Icons.calendar_today_outlined,
                              '${createdDate.day} ${_monthId(createdDate.month)} ${createdDate.year}',
                              '',
                            ),
                          ])
            : <(String, IconData, String, String)>[
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
              ]);

    // Jika ada detail yang diperluas, tampilkan kontennya
    if (_expandedDetailTitle != null && _expandedDetailContent != null) {
      return ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          // Header untuk kembali
          InkWell(
            onTap: () {
              setState(() {
                _expandedDetailTitle = null;
                _expandedDetailContent = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark2 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Kembali',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Judul detail
          Text(
            _expandedDetailTitle!,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          // Konten detail
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark2 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
              ),
            ),
            child: Text(
              _expandedDetailContent!,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      );
    }

    String modalMainDesc = item?.subtitle ?? '';
    String? modalAdminNote;
    if (modalMainDesc.contains('Catatan admin:') ||
        modalMainDesc.contains('catatan admin:')) {
      final parts = modalMainDesc.split(
        RegExp(r'[•·]\s*Catatan admin:\s*', caseSensitive: false),
      );
      if (parts.length > 1) {
        modalMainDesc = parts[0].trim();
        modalAdminNote = parts[1].trim();
      }
    }

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        if (item != null) ...[
          if (_isEo) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.data.key == 'eo_timeline'
                    ? 'Deskripsi Alur Kerja'
                    : widget.data.key == 'eo_vendor'
                        ? 'Spesifikasi & Fasilitas'
                        : widget.data.key == 'eo_jadwal'
                            ? 'Rincian Agenda Acara'
                            : 'Deskripsi Paket',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
            ),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark2 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  modalMainDesc,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                  ),
                ),
                if (modalAdminNote != null && modalAdminNote.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Catatan Admin: $modalAdminNote',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          isNew ? 'Kolom yang Akan Diisi' : 'Detail & Metadata',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < detailValues.length; i++)
          _buildDetailItem(detailValues[i], i, isDark, isNew),
      ],
    );
  }

  Widget _buildDetailItem(
    (String, IconData, String, String) f,
    int index,
    bool isDark,
    bool isNew,
  ) {
    final canTap = isNew || !_isEo;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: canTap
          ? () {
              if (isNew) {
                if (_isEo) {
                  _handleEoFormTap(index);
                } else {
                  _handleFormTap(index);
                }
              } else {
                // Tampilkan detail di dalam modal yang sama
                setState(() {
                  _expandedDetailTitle = f.$1;
                  _expandedDetailContent = f.$3;
                });
              }
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark2 : Colors.white,
          borderRadius: BorderRadius.circular(12),
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
              child: Icon(f.$2, size: 16, color: AppTheme.primaryPurple),
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
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
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
                        color: AppTheme.primaryPurple.withValues(alpha: 0.08),
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
            if (canTap)
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
              ),
          ],
        ),
      ),
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
    final reviews = [..._customReviews, ..._apiReviews];
    final totalReviews = widget.totalReviews > 0
        ? widget.totalReviews
        : reviews.length;
    final counts = widget.totalReviews > 0
        ? [
            widget.reviewDistribution[5] ?? 0,
            widget.reviewDistribution[4] ?? 0,
            widget.reviewDistribution[3] ?? 0,
            widget.reviewDistribution[2] ?? 0,
            widget.reviewDistribution[1] ?? 0,
          ]
        : reviews.fold<List<int>>([0, 0, 0, 0, 0], (acc, r) {
            final idx = 5 - (r.stars.clamp(1, 5));
            if (idx >= 0 && idx < 5) acc[idx]++;
            return acc;
          });
    final fiveStar = counts[0];
    final fourStar = counts[1];
    final threeStar = counts[2];
    final twoStar = counts[3];
    final oneStar = counts[4];
    final rating = widget.avgRating > 0
        ? widget.avgRating.toStringAsFixed(1)
        : (totalReviews > 0
            ? ((5 * fiveStar +
                          4 * fourStar +
                          3 * threeStar +
                          2 * twoStar +
                          1 * oneStar) /
                      totalReviews)
                  .toStringAsFixed(1)
            : '—');
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
        if (reviews.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  size: 44,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade400,
                ),
                const SizedBox(height: 10),
                Text(
                  'Belum ada ulasan untuk kreator ini',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          )
        else
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
            final initialChar = r.name.isNotEmpty ? r.name[0] : 'U';
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
                            initialChar,
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