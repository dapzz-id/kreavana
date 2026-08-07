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
              .withLightness((HSLColor.fromColor(primaryColor).lightness * 0.8).clamp(0.0, 1.0))
              .toColor(),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

class SubRoleThemeEngine {
  SubRoleThemeEngine._();

  // ── Default fallback color ──────────────────────────────────────────────────
  static const Color defaultPrimary = Color(0xFF7C3AED); // Signature Kreavana Violet

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
      description: 'Pertumbuhan bisnis lokal dengan paket branding & visual terjangkau',
    ),
    'company': SubRoleThemeConfig(
      slug: 'company',
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
      label: 'Lembaga / Yayasan',
      icon: Icons.assured_workload_rounded,
      primaryColor: Color(0xFF0F766E), // Slate Teal
      description: 'Kampanye sosial, riset, dan kegiatan nirlaba',
    ),
    'instansi': SubRoleThemeConfig(
      slug: 'instansi',
      label: 'Lembaga / Yayasan',
      icon: Icons.domain_rounded,
      primaryColor: Color(0xFF0F766E),
      description: 'Kampanye sosial, riset, dan kegiatan nirlaba',
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
      label: 'Sekolah & Kampus',
      icon: Icons.school_rounded,
      primaryColor: Color(0xFF3B82F6), // Ocean Blue
      description: 'Peluang media akademik, buku tahunan, & event pendidikan',
    ),
    'sekolah': SubRoleThemeConfig(
      slug: 'sekolah',
      label: 'Sekolah & Kampus',
      icon: Icons.school_outlined,
      primaryColor: Color(0xFF3B82F6),
      description: 'Peluang media akademik, buku tahunan, & event pendidikan',
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
      description: 'Perekrutan vendor foto, video, & MUA untuk pesta pernikahan',
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
      label: 'Talent & Model',
      icon: Icons.stars_rounded,
      primaryColor: Color(0xFFEA580C), // Sunset Orange
      description: 'Model iklan, pemeran video komersial, & voiceover',
    ),
    'animator': SubRoleThemeConfig(
      slug: 'animator',
      label: 'Animator 3D & Motion Graphic',
      icon: Icons.animation_rounded,
      primaryColor: Color(0xFF0D9488), // Neon Teal
      description: 'Animasi 2D/3D, motion graphics, & efek visual (VFX)',
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

    if (clientConfigs.containsKey(cleanSub)) {
      return clientConfigs[cleanSub]!;
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
