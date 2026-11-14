import 'package:flutter/material.dart';
import '../models/user_model.dart';

class SubRoleThemeConfig {
  final String slug;
  final String label;
  final IconData icon;
  final Color primaryColor;
  final String description;

  const SubRoleThemeConfig({
    required this.slug,
    required this.label,
    required this.icon,
    required this.primaryColor,
    required this.description,
  });

  Color get subtleBgLight => primaryColor.withValues(alpha: 0.08);
  Color get subtleBgDark => primaryColor.withValues(alpha: 0.15);
  Color get borderLight => primaryColor.withValues(alpha: 0.25);
  Color get borderDark => primaryColor.withValues(alpha: 0.35);

  LinearGradient get gradient => LinearGradient(
    colors: [
      primaryColor,
      HSLColor.fromColor(primaryColor)
          .withLightness(
            (HSLColor.fromColor(primaryColor).lightness * 0.8).clamp(0.0, 1.0),
          )
          .toColor(),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class SubRoleThemeEngine {
  SubRoleThemeEngine._();

  // ── Default fallback color ──────────────────────────────────────────────────
  static const Color defaultPrimary = Color(
    0xFF7C3AED,
  ); // Signature Kreavana Violet

  // ── Admin Theme ─────────────────────────────────────────────────────────────
  static const SubRoleThemeConfig adminConfig = SubRoleThemeConfig(
    slug: 'admin',
    label: 'Administrator System',
    icon: Icons.admin_panel_settings_rounded,
    primaryColor: Color(0xFFD97706), // Amber Gold
    description: 'Manajemen sistem, verifikasi kreator, dan audit escrow',
  );

  // ── Client Sub-Roles (11) ───────────────────────────────────────────────────
  static const Map<String, SubRoleThemeConfig> clientConfigs = {
    'umkm': SubRoleThemeConfig(
      slug: 'umkm',
      label: 'UMKM & Usaha Lokal',
      icon: Icons.storefront_rounded,
      primaryColor: Color(0xFF10B981), // Emerald Green
      description:
          'Pertumbuhan bisnis lokal dengan paket branding & visual terjangkau',
    ),
    'company': SubRoleThemeConfig(
      slug: 'company',
      label: 'Perusahaan Korporat',
      icon: Icons.corporate_fare_rounded,
      primaryColor: Color(0xFF2563EB), // Sapphire Blue
      description: 'Pengadaan proyek media & branding skala enterprise',
    ),
    'corporate': SubRoleThemeConfig(
      slug: 'corporate',
      label: 'Perusahaan Korporat',
      icon: Icons.corporate_fare_rounded,
      primaryColor: Color(0xFF2563EB), // Sapphire Blue
      description: 'Pengadaan proyek media & branding skala enterprise',
    ),
    'perusahaan': SubRoleThemeConfig(
      slug: 'perusahaan',
      label: 'Perusahaan Korporat',
      icon: Icons.business_center_rounded,
      primaryColor: Color(0xFF2563EB),
      description: 'Pengadaan proyek media & branding skala enterprise',
    ),
    'bisnis': SubRoleThemeConfig(
      slug: 'bisnis',
      label: 'Perusahaan Korporat',
      icon: Icons.business_center_rounded,
      primaryColor: Color(0xFF2563EB),
      description: 'Pengadaan proyek media & branding skala enterprise',
    ),
    'b2b': SubRoleThemeConfig(
      slug: 'b2b',
      label: 'Perusahaan Korporat',
      icon: Icons.business_rounded,
      primaryColor: Color(0xFF2563EB),
      description: 'Pengadaan proyek media & branding skala enterprise',
    ),
    'government': SubRoleThemeConfig(
      slug: 'government',
      label: 'Instansi Pemerintah',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFF1D4ED8), // Deep Indigo Navy
      description: 'Dokumentasi & publikasi program pelayanan masyarakat',
    ),
    'pemerintah': SubRoleThemeConfig(
      slug: 'pemerintah',
      label: 'Instansi Pemerintah',
      icon: Icons.gavel_rounded,
      primaryColor: Color(0xFF1D4ED8),
      description: 'Dokumentasi & publikasi program pelayanan masyarakat',
    ),
    'institution': SubRoleThemeConfig(
      slug: 'institution',
      label: 'Sekolah & Perguruan Tinggi',
      icon: Icons.school_rounded,
      primaryColor: Color(0xFF4338CA), // Solid Academic Indigo
      description: 'Menghubungkan talenta, ilmu pengetahuan dan peluang masa depan',
    ),
    'institusi': SubRoleThemeConfig(
      slug: 'institusi',
      label: 'Sekolah & Perguruan Tinggi',
      icon: Icons.school_rounded,
      primaryColor: Color(0xFF4338CA),
      description: 'Menghubungkan talenta, ilmu pengetahuan dan peluang masa depan',
    ),
    'lembaga': SubRoleThemeConfig(
      slug: 'lembaga',
      label: 'Sekolah & Perguruan Tinggi',
      icon: Icons.school_rounded,
      primaryColor: Color(0xFF4338CA),
      description: 'Menghubungkan talenta, ilmu pengetahuan dan peluang masa depan',
    ),
    'yayasan': SubRoleThemeConfig(
      slug: 'yayasan',
      label: 'Sekolah & Perguruan Tinggi',
      icon: Icons.school_rounded,
      primaryColor: Color(0xFF4338CA),
      description: 'Menghubungkan talenta, ilmu pengetahuan dan peluang masa depan',
    ),
    'instansi': SubRoleThemeConfig(
      slug: 'instansi',
      label: 'Sekolah & Perguruan Tinggi',
      icon: Icons.school_rounded,
      primaryColor: Color(0xFF4338CA),
      description: 'Menghubungkan talenta, ilmu pengetahuan dan peluang masa depan',
    ),
    'community': SubRoleThemeConfig(
      slug: 'community',
      label: 'Komunitas & Publik',
      icon: Icons.groups_rounded,
      primaryColor: Color(0xFF06B6D4), // Bright Cyan
      description: 'Kolaborasi event komunitas & jaringan kreator lokal',
    ),
    'komunitas': SubRoleThemeConfig(
      slug: 'komunitas',
      label: 'Komunitas & Publik',
      icon: Icons.people_alt_rounded,
      primaryColor: Color(0xFF06B6D4),
      description: 'Kolaborasi event komunitas & jaringan kreator lokal',
    ),
    'school': SubRoleThemeConfig(
      slug: 'school',
      label: 'Sekolah & Perguruan Tinggi',
      icon: Icons.school_rounded,
      primaryColor: Color(0xFF4338CA),
      description: 'Menghubungkan talenta, ilmu pengetahuan dan peluang masa depan',
    ),
    'sekolah': SubRoleThemeConfig(
      slug: 'sekolah',
      label: 'Sekolah & Perguruan Tinggi',
      icon: Icons.school_outlined,
      primaryColor: Color(0xFF4338CA),
      description: 'Menghubungkan talenta, ilmu pengetahuan dan peluang masa depan',
    ),
    'tourism': SubRoleThemeConfig(
      slug: 'tourism',
      label: 'Destinasi Pariwisata',
      icon: Icons.tour_rounded,
      primaryColor: Color(0xFFF59E0B), // Warm Amber
      description: 'Promosi keindahan tempat wisata, hotel, & budaya',
    ),
    'pariwisata': SubRoleThemeConfig(
      slug: 'pariwisata',
      label: 'Destinasi Pariwisata',
      icon: Icons.travel_explore_rounded,
      primaryColor: Color(0xFFF59E0B),
      description: 'Promosi keindahan tempat wisata, hotel, & budaya',
    ),
    'individual': SubRoleThemeConfig(
      slug: 'individual',
      label: 'Klien Perorangan',
      icon: Icons.person_rounded,
      primaryColor: Color(0xFF6366F1), // Indigo Violet
      description: 'Kebutuhan dokumentasi pribadi, wisuda, & momen spesial',
    ),
    'individu': SubRoleThemeConfig(
      slug: 'individu',
      label: 'Klien Perorangan',
      icon: Icons.person_outline_rounded,
      primaryColor: Color(0xFF6366F1),
      description: 'Kebutuhan dokumentasi pribadi, wisuda, & momen spesial',
    ),
    'wedding_organizer': SubRoleThemeConfig(
      slug: 'wedding_organizer',
      label: 'Wedding Organizer (Client)',
      icon: Icons.favorite_rounded,
      primaryColor: Color(0xFFF43F5E), // Rose Crimson
      description:
          'Perekrutan vendor foto, video, & MUA untuk pesta pernikahan',
    ),
    'event_organizer': SubRoleThemeConfig(
      slug: 'event_organizer',
      label: 'Event Organizer (Client)',
      icon: Icons.festival_rounded,
      primaryColor: Color(0xFF0284C7), // Sky Cyan
      description: 'Perekrutan kru panggung, MC, & talent untuk konser/event',
    ),
    'brand_agency': SubRoleThemeConfig(
      slug: 'brand_agency',
      label: 'Creative Brand Agency',
      icon: Icons.campaign_rounded,
      primaryColor: Color(0xFFC026D3), // Deep Magenta
      description: 'Outsourcing kreator untuk eksekusi kampanye periklanan',
    ),
  };

  // ── Creator Sub-Roles (11) ──────────────────────────────────────────────────
  static const Map<String, SubRoleThemeConfig> creatorConfigs = {
    'institution': SubRoleThemeConfig(
      slug: 'institution',
      label: 'Sekolah & Perguruan Tinggi',
      icon: Icons.school_rounded,
      primaryColor: Color(0xFF4338CA), // Solid Academic Indigo
      description: 'Menghubungkan talenta, ilmu pengetahuan dan peluang masa depan',
    ),
    'institusi': SubRoleThemeConfig(
      slug: 'institusi',
      label: 'Sekolah & Perguruan Tinggi',
      icon: Icons.school_rounded,
      primaryColor: Color(0xFF4338CA),
      description: 'Menghubungkan talenta, ilmu pengetahuan dan peluang masa depan',
    ),
    'lembaga': SubRoleThemeConfig(
      slug: 'lembaga',
      label: 'Sekolah & Perguruan Tinggi',
      icon: Icons.school_rounded,
      primaryColor: Color(0xFF4338CA),
      description: 'Menghubungkan talenta, ilmu pengetahuan dan peluang masa depan',
    ),
    'yayasan': SubRoleThemeConfig(
      slug: 'yayasan',
      label: 'Sekolah & Perguruan Tinggi',
      icon: Icons.school_rounded,
      primaryColor: Color(0xFF4338CA),
      description: 'Menghubungkan talenta, ilmu pengetahuan dan peluang masa depan',
    ),
    'government': SubRoleThemeConfig(
      slug: 'government',
      label: 'Instansi Pemerintah',
      icon: Icons.account_balance_rounded,
      primaryColor: Color(0xFF1D4ED8), // Deep Indigo Navy
      description: 'Dokumentasi & publikasi program pelayanan masyarakat',
    ),
    'community': SubRoleThemeConfig(
      slug: 'community',
      label: 'Komunitas & Publik',
      icon: Icons.groups_rounded,
      primaryColor: Color(0xFF06B6D4), // Bright Cyan
      description: 'Kolaborasi event komunitas & jaringan kreator lokal',
    ),
    'wedding_organizer': SubRoleThemeConfig(
      slug: 'wedding_organizer',
      label: 'Wedding Organizer',
      icon: Icons.favorite_rounded,
      primaryColor: Color(0xFFF43F5E), // Rose Crimson
      description: 'Penyelenggara pesta pernikahan profesional',
    ),
    'event_organizer': SubRoleThemeConfig(
      slug: 'event_organizer',
      label: 'Event Organizer',
      icon: Icons.festival_rounded,
      primaryColor: Color(0xFF0284C7), // Sky Cyan
      description: 'Penyelenggara konser, pameran, & event',
    ),
    'photographer': SubRoleThemeConfig(
      slug: 'photographer',
      label: 'Fotografer Profesional',
      icon: Icons.photo_camera_rounded,
      primaryColor: Color(0xFF7C3AED), // Royal Purple
      description: 'Spesialis fotografi komersial, studio, event, & portrait',
    ),
    'fotografer': SubRoleThemeConfig(
      slug: 'fotografer',
      label: 'Fotografer Profesional',
      icon: Icons.camera_alt_rounded,
      primaryColor: Color(0xFF7C3AED),
      description: 'Spesialis fotografi komersial, studio, event, & portrait',
    ),
    'videographer': SubRoleThemeConfig(
      slug: 'videographer',
      label: 'Videografer & Cinematographer',
      icon: Icons.videocam_rounded,
      primaryColor: Color(0xFFE11D48), // Rose Coral
      description: 'Produksi video komersial, cinematic reel, & video event',
    ),
    'videografer': SubRoleThemeConfig(
      slug: 'videografer',
      label: 'Videografer & Cinematographer',
      icon: Icons.video_camera_back_rounded,
      primaryColor: Color(0xFFE11D48),
      description: 'Produksi video komersial, cinematic reel, & video event',
    ),
    'desainer': SubRoleThemeConfig(
      slug: 'desainer',
      label: 'Desainer Grafis & UI/UX',
      icon: Icons.palette_rounded,
      primaryColor: Color(0xFF4F46E5), // Royal Indigo
      description: 'Branding visual, logo, desain media sosial, & UI/UX',
    ),
    'designer': SubRoleThemeConfig(
      slug: 'designer',
      label: 'Desainer Grafis & UI/UX',
      icon: Icons.brush_rounded,
      primaryColor: Color(0xFF4F46E5),
      description: 'Branding visual, logo, desain media sosial, & UI/UX',
    ),
    'editor': SubRoleThemeConfig(
      slug: 'editor',
      label: 'Editor Video & Pascaproduksi',
      icon: Icons.auto_fix_high_rounded,
      primaryColor: Color(0xFF9333EA), // Amethyst Violet
      description: 'Penyuntingan video, color grading, & retouching foto',
    ),
    'makeup_artist': SubRoleThemeConfig(
      slug: 'makeup_artist',
      label: 'Makeup Artist (MUA)',
      icon: Icons.face_retouching_natural_rounded,
      primaryColor: Color(0xFFEC4899), // Hot Pink
      description: 'Tata rias pengantin, wisuda, photoshoot, & event',
    ),
    'mua': SubRoleThemeConfig(
      slug: 'mua',
      label: 'Makeup Artist (MUA)',
      icon: Icons.face_rounded,
      primaryColor: Color(0xFFEC4899),
      description: 'Tata rias pengantin, wisuda, photoshoot, & event',
    ),
    'mc': SubRoleThemeConfig(
      slug: 'mc',
      label: 'Master of Ceremony (MC)',
      icon: Icons.mic_external_on_rounded,
      primaryColor: Color(0xFFF59E0B), // Warm Amber
      description: 'Pemandu acara formal, pernikahan, konser, & seminar',
    ),
    'singer': SubRoleThemeConfig(
      slug: 'singer',
      label: 'Penyanyi & Musisi',
      icon: Icons.music_note_rounded,
      primaryColor: Color(0xFF8B5CF6), // Bright Purple
      description: 'Pengisi acara musik, vokal jingle, & penampilan live',
    ),
    'penyanyi': SubRoleThemeConfig(
      slug: 'penyanyi',
      label: 'Penyanyi & Musisi',
      icon: Icons.library_music_rounded,
      primaryColor: Color(0xFF8B5CF6),
      description: 'Pengisi acara musik, vokal jingle, & penampilan live',
    ),
    'drone': SubRoleThemeConfig(
      slug: 'drone',
      label: 'Pilot Drone Udara',
      icon: Icons.flight_takeoff_rounded,
      primaryColor: Color(0xFF0891B2), // Cyan Teal
      description: 'Pengambilan gambar & video pemandangan dari udara',
    ),
    'drone_pilot': SubRoleThemeConfig(
      slug: 'drone_pilot',
      label: 'Pilot Drone Udara',
      icon: Icons.airplanemode_active_rounded,
      primaryColor: Color(0xFF0891B2),
      description: 'Pengambilan gambar & video pemandangan dari udara',
    ),
    'content_creator': SubRoleThemeConfig(
      slug: 'content_creator',
      label: 'Content Creator & Influencer',
      icon: Icons.movie_creation_rounded,
      primaryColor: Color(0xFF059669), // Mint Emerald
      description: 'Kreator konten digital, UGC, & endorsement produk',
    ),
    'talent': SubRoleThemeConfig(
      slug: 'talent',
      label: 'Talent & Performer',
      icon: Icons.stars_rounded,
      primaryColor: Color(0xFFEA580C), // Vibrant Sunset Orange
      description: 'Model, aktor, MC, penyanyi, musisi, penari, voice over, & KOL',
    ),
    'performer': SubRoleThemeConfig(
      slug: 'performer',
      label: 'Talent & Performer',
      icon: Icons.theater_comedy_rounded,
      primaryColor: Color(0xFFEA580C),
      description: 'Model, aktor, MC, penyanyi, musisi, penari, voice over, & KOL',
    ),
    'talent_performer': SubRoleThemeConfig(
      slug: 'talent_performer',
      label: 'Talent & Performer',
      icon: Icons.stars_rounded,
      primaryColor: Color(0xFFEA580C),
      description: 'Model, aktor, MC, penyanyi, musisi, penari, voice over, & KOL',
    ),
    'model': SubRoleThemeConfig(
      slug: 'model',
      label: 'Model & Performer',
      icon: Icons.portrait_rounded,
      primaryColor: Color(0xFFEA580C),
      description: 'Model iklan, catwalk, photoshoot katalog, & brand ambassador',
    ),
    'actor': SubRoleThemeConfig(
      slug: 'actor',
      label: 'Aktor & Pemeran',
      icon: Icons.movie_rounded,
      primaryColor: Color(0xFFEA580C),
      description: 'Pemeran video komersial, serial web, teater, & voice over',
    ),
    'aktor': SubRoleThemeConfig(
      slug: 'aktor',
      label: 'Aktor & Pemeran',
      icon: Icons.movie_rounded,
      primaryColor: Color(0xFFEA580C),
      description: 'Pemeran video komersial, serial web, teater, & voice over',
    ),
    'penari': SubRoleThemeConfig(
      slug: 'penari',
      label: 'Penari & Koreografer',
      icon: Icons.accessibility_new_rounded,
      primaryColor: Color(0xFFEA580C),
      description: 'Penari kontemporer, tari tradisional, modern dance, & koreografi',
    ),
    'dancer': SubRoleThemeConfig(
      slug: 'dancer',
      label: 'Penari & Koreografer',
      icon: Icons.accessibility_new_rounded,
      primaryColor: Color(0xFFEA580C),
      description: 'Penari kontemporer, tari tradisional, modern dance, & koreografi',
    ),
    'voice_over': SubRoleThemeConfig(
      slug: 'voice_over',
      label: 'Voice Over & Talent',
      icon: Icons.record_voice_over_rounded,
      primaryColor: Color(0xFFEA580C),
      description: 'Pengisi suara iklan, audio book, dubbing video, & podcast',
    ),
    'animator': SubRoleThemeConfig(
      slug: 'animator',
      label: 'Animator 3D & Motion Graphic',
      icon: Icons.animation_rounded,
      primaryColor: Color(0xFF0D9488), // Neon Teal
      description: 'Animasi 2D/3D, motion graphics, & efek visual (VFX)',
    ),
    // ── Role 3: Vendor & Penyedia Jasa Pendukung ──────────────────────────────
    'vendor': SubRoleThemeConfig(
      slug: 'vendor',
      label: 'Vendor & Penyedia Jasa Pendukung',
      icon: Icons.storefront_rounded,
      primaryColor: Color(0xFFD97706), // Warm Amber Gold
      description: 'Studio, rental alat, MUA, wardrobe, dekorasi, katering, printing, lighting, sound, & transportasi',
    ),
    'vendor_pendukung': SubRoleThemeConfig(
      slug: 'vendor_pendukung',
      label: 'Vendor & Penyedia Jasa Pendukung',
      icon: Icons.storefront_rounded,
      primaryColor: Color(0xFFD97706),
      description: 'Studio, rental alat, MUA, wardrobe, dekorasi, katering, printing, lighting, sound, & transportasi',
    ),
    'penyedia_jasa': SubRoleThemeConfig(
      slug: 'penyedia_jasa',
      label: 'Vendor & Penyedia Jasa Pendukung',
      icon: Icons.storefront_rounded,
      primaryColor: Color(0xFFD97706),
      description: 'Studio, rental alat, MUA, wardrobe, dekorasi, katering, printing, lighting, sound, & transportasi',
    ),
    'mitra_pendukung': SubRoleThemeConfig(
      slug: 'mitra_pendukung',
      label: 'Mitra Jasa Pendukung',
      icon: Icons.handshake_rounded,
      primaryColor: Color(0xFFEA580C), // Vibrant Sunset Amber
      description: 'Layanan keahlian teknis pendukung produksi event, dekorasi, rias, tata panggung & katering',
    ),
    'mitra': SubRoleThemeConfig(
      slug: 'mitra',
      label: 'Mitra Jasa Pendukung',
      icon: Icons.handshake_rounded,
      primaryColor: Color(0xFFEA580C),
      description: 'Layanan keahlian teknis pendukung produksi event, dekorasi, rias, tata panggung & katering',
    ),
    'studio': SubRoleThemeConfig(
      slug: 'studio',
      label: 'Studio & Ruang Produksi',
      icon: Icons.camera_indoor_rounded,
      primaryColor: Color(0xFF0284C7), // Sky Blue
      description: 'Penyewaan studio foto, video, podcast, green screen, & ruang produksi',
    ),
    'rental_alat': SubRoleThemeConfig(
      slug: 'rental_alat',
      label: 'Rental Alat Foto & Video',
      icon: Icons.camera_alt_rounded,
      primaryColor: Color(0xFFD97706), // Warm Amber
      description: 'Penyewaan kamera, lensa, gimbal, drone, lighting, & perlengkapan visual',
    ),
    'sewa_alat': SubRoleThemeConfig(
      slug: 'sewa_alat',
      label: 'Rental Alat Foto & Video',
      icon: Icons.camera_alt_rounded,
      primaryColor: Color(0xFFD97706),
      description: 'Penyewaan kamera, lensa, gimbal, drone, lighting, & perlengkapan visual',
    ),
    'wardrobe': SubRoleThemeConfig(
      slug: 'wardrobe',
      label: 'Wardrobe & Kostum',
      icon: Icons.checkroom_rounded,
      primaryColor: Color(0xFFC026D3), // Magenta
      description: 'Penyewaan pakaian panggung, busana pengantin, jas, & kostum tematik',
    ),
    'kostum': SubRoleThemeConfig(
      slug: 'kostum',
      label: 'Wardrobe & Kostum',
      icon: Icons.checkroom_rounded,
      primaryColor: Color(0xFFC026D3),
      description: 'Penyewaan pakaian panggung, busana pengantin, jas, & kostum tematik',
    ),
    'dekorasi': SubRoleThemeConfig(
      slug: 'dekorasi',
      label: 'Dekorasi & Properti',
      icon: Icons.local_florist_rounded,
      primaryColor: Color(0xFF10B981), // Emerald Green
      description: 'Dekorasi panggung, backdrop, instalasi pameran, properti set, & tata ruang',
    ),
    'properti': SubRoleThemeConfig(
      slug: 'properti',
      label: 'Dekorasi & Properti',
      icon: Icons.local_florist_rounded,
      primaryColor: Color(0xFF10B981),
      description: 'Dekorasi panggung, backdrop, instalasi pameran, properti set, & tata ruang',
    ),
    'katering': SubRoleThemeConfig(
      slug: 'katering',
      label: 'Katering & Food Service',
      icon: Icons.restaurant_menu_rounded,
      primaryColor: Color(0xFFF59E0B), // Amber
      description: 'Konsumsi kru produksi, prasmanan acara, coffee break VIP, & meal box',
    ),
    'catering': SubRoleThemeConfig(
      slug: 'catering',
      label: 'Katering & Food Service',
      icon: Icons.restaurant_menu_rounded,
      primaryColor: Color(0xFFF59E0B),
      description: 'Konsumsi kru produksi, prasmanan acara, coffee break VIP, & meal box',
    ),
    'printing': SubRoleThemeConfig(
      slug: 'printing',
      label: 'Printing & Merchandise',
      icon: Icons.print_rounded,
      primaryColor: Color(0xFF4F46E5), // Indigo
      description: 'Cetak banner, backdrop, photobook, merchandise, lanyard, & media promosi',
    ),
    'merchandise': SubRoleThemeConfig(
      slug: 'merchandise',
      label: 'Printing & Merchandise',
      icon: Icons.print_rounded,
      primaryColor: Color(0xFF4F46E5),
      description: 'Cetak banner, backdrop, photobook, merchandise, lanyard, & media promosi',
    ),
    'lighting_sound': SubRoleThemeConfig(
      slug: 'lighting_sound',
      label: 'Lighting & Sound System',
      icon: Icons.speaker_group_rounded,
      primaryColor: Color(0xFF0284C7), // Blue
      description: 'Tata suara panggung, moving beam, LED screen, par-light, mixer, & genset',
    ),
    'sound_system': SubRoleThemeConfig(
      slug: 'sound_system',
      label: 'Lighting & Sound System',
      icon: Icons.speaker_group_rounded,
      primaryColor: Color(0xFF0284C7),
      description: 'Tata suara panggung, moving beam, LED screen, par-light, mixer, & genset',
    ),
    'transportasi': SubRoleThemeConfig(
      slug: 'transportasi',
      label: 'Transportasi & Logistik',
      icon: Icons.local_shipping_rounded,
      primaryColor: Color(0xFF334155), // Slate
      description: 'Armada van kru, truk pengangkut logistik alat, & transportasi produksi',
    ),
    'logistik': SubRoleThemeConfig(
      slug: 'logistik',
      label: 'Transportasi & Logistik',
      icon: Icons.local_shipping_rounded,
      primaryColor: Color(0xFF334155),
      description: 'Armada van kru, truk pengangkut logistik alat, & transportasi produksi',
    ),
  };

  // ── Helper Resolvers ────────────────────────────────────────────────────────
  static SubRoleThemeConfig getConfig(String? role, String? subRole) {
    final cleanRole = (role ?? '').toLowerCase().trim();
    final cleanSub = (subRole ?? '').toLowerCase().trim();

    if (cleanRole == 'admin') return adminConfig;

    if (cleanRole == 'creator' || cleanRole == 'kreator') {
      if (creatorConfigs.containsKey(cleanSub)) {
        return creatorConfigs[cleanSub]!;
      }
    }

    if (cleanRole == 'vendor' ||
        cleanRole == 'mitra' ||
        cleanRole == 'mitra_pendukung' ||
        cleanSub == 'vendor' ||
        cleanSub == 'vendor_pendukung' ||
        cleanSub == 'penyedia_jasa' ||
        cleanSub == 'mitra' ||
        cleanSub == 'mitra_pendukung' ||
        cleanSub == 'studio' ||
        cleanSub == 'rental_alat' ||
        cleanSub == 'wardrobe' ||
        cleanSub == 'dekorasi' ||
        cleanSub == 'katering' ||
        cleanSub == 'catering' ||
        cleanSub == 'printing' ||
        cleanSub == 'lighting_sound' ||
        cleanSub == 'transportasi') {
      return creatorConfigs[cleanSub] ?? creatorConfigs['vendor']!;
    }

    if (cleanRole == 'corporate' ||
        cleanRole == 'company' ||
        cleanRole == 'perusahaan' ||
        cleanRole == 'bisnis' ||
        cleanSub == 'corporate' ||
        cleanSub == 'company' ||
        cleanSub == 'perusahaan' ||
        cleanSub == 'bisnis' ||
        cleanSub == 'b2b' ||
        cleanSub == 'business') {
      return clientConfigs['corporate'] ?? clientConfigs['company']!;
    }

    if (clientConfigs.containsKey(cleanSub)) {
      return clientConfigs[cleanSub]!;
    }

    if (clientConfigs.containsKey(cleanRole)) {
      return clientConfigs[cleanRole]!;
    }

    return SubRoleThemeConfig(
      slug: cleanSub.isEmpty ? 'default' : cleanSub,
      label: cleanSub.isEmpty ? 'Kreavana Member' : cleanSub.toUpperCase(),
      icon: Icons.auto_awesome_rounded,
      primaryColor: defaultPrimary,
      description: 'Layanan platform ekosistem kreatif Kreavana',
    );
  }

  static Color getAccentColor(String? role, String? subRole) {
    return getConfig(role, subRole).primaryColor;
  }

  static Color getAccentColorForUser(UserModel user) {
    return getAccentColor(user.role, user.subRole);
  }

  static Color getSubtleBg(String? role, String? subRole, bool isDark) {
    final cfg = getConfig(role, subRole);
    return isDark ? cfg.subtleBgDark : cfg.subtleBgLight;
  }

  static Color getBorderColor(String? role, String? subRole, bool isDark) {
    final cfg = getConfig(role, subRole);
    return isDark ? cfg.borderDark : cfg.borderLight;
  }

  static LinearGradient getGradient(String? role, String? subRole) {
    return getConfig(role, subRole).gradient;
  }
}
