import 'package:flutter/material.dart';
import '../models/user_model.dart';

class CreatorSidebarMenuEntry {
  final IconData icon;
  final String label;
  final String? route;
  final String? serviceKey;

  const CreatorSidebarMenuEntry({
    required this.icon,
    required this.label,
    this.route,
    this.serviceKey,
  });
}

class CreatorSidebarMenus {
  CreatorSidebarMenus._();

  static String normalizeSubRole(String? subRole) =>
      (subRole ?? '').toLowerCase().trim();

  static bool isCreatorUser(UserModel user) =>
      user.role == 'creator' || user.isCreator;

  static bool hasSpecificSubRole(String? subRole) {
    const known = {
      'photographer', 'fotografer', 'foto',
      'videographer', 'videografer', 'video',
      'editor', 'photo_editor', 'video_editor',
      'desainer', 'designer', 'graphic_designer', 'desain',
      'mc', 'singer', 'penyanyi',
      'talent', 'model', 'talent_model',
      'makeup_artist', 'mua', 'makeup',
      'wedding_organizer', 'wo',
      'event_organizer', 'eo',
      'community', 'komunitas',
      'drone', 'drone_pilot', 'pilot_drone',
      'content_creator', 'influencer', 'ugc',
      'animator', '3d_animator', 'motion_designer',
    };
    return known.contains(normalizeSubRole(subRole));
  }

  static bool showKolaborasiInLainnya(String? subRole) {
    final sub = normalizeSubRole(subRole);
    return sub != 'community' && sub != 'komunitas';
  }

  static bool showPortofolioAgendaTopItems(UserModel user) {
    return !isCreatorUser(user) || !hasSpecificSubRole(user.subRole);
  }

  static String? layananSectionTitle(String? subRole) {
    switch (normalizeSubRole(subRole)) {
      case 'photographer':
      case 'fotografer':
      case 'foto':
        return 'LAYANAN FOTOGRAFI';
      case 'videographer':
      case 'videografer':
      case 'video':
        return 'LAYANAN VIDEOGRAFER';
      case 'editor':
      case 'photo_editor':
      case 'video_editor':
        return 'LAYANAN EDITOR';
      case 'desainer':
      case 'designer':
      case 'graphic_designer':
      case 'desain':
        return 'LAYANAN DESAINER';
      case 'mc':
        return 'LAYANAN MC';
      case 'singer':
      case 'penyanyi':
        return 'LAYANAN PENYANYI';
      case 'talent':
      case 'model':
      case 'talent_model':
        return 'LAYANAN TALENT';
      case 'makeup_artist':
      case 'mua':
      case 'makeup':
        return 'LAYANAN MUA';
      case 'wedding_organizer':
      case 'wo':
        return 'LAYANAN WO';
      case 'event_organizer':
      case 'eo':
        return 'LAYANAN EO';
      case 'community':
      case 'komunitas':
        return 'LAYANAN KOMUNITAS';
      case 'drone':
      case 'drone_pilot':
      case 'pilot_drone':
        return 'LAYANAN PILOT DRONE';
      case 'content_creator':
      case 'influencer':
      case 'ugc':
        return 'LAYANAN KONTEN KREATOR';
      case 'animator':
      case '3d_animator':
      case 'motion_designer':
        return 'LAYANAN ANIMATOR 3D';
      default:
        return null;
    }
  }

  static List<CreatorSidebarMenuEntry> layananItems(String? subRole) {
    switch (normalizeSubRole(subRole)) {
      case 'photographer':
      case 'fotografer':
      case 'foto':
        return const [
          CreatorSidebarMenuEntry(icon: Icons.photo_library_outlined, label: 'Galeri Portofolio', serviceKey: 'foto_galeri'),
          CreatorSidebarMenuEntry(icon: Icons.calendar_today_outlined, label: 'Booking & Jadwal', serviceKey: 'foto_booking'),
          CreatorSidebarMenuEntry(icon: Icons.payments_outlined, label: 'Paket Harga', serviceKey: 'foto_paket'),
          CreatorSidebarMenuEntry(icon: Icons.location_on_outlined, label: 'Cakupan Area', serviceKey: 'foto_area'),
        ];
      case 'videographer':
      case 'videografer':
      case 'video':
        return const [
          CreatorSidebarMenuEntry(icon: Icons.videocam_outlined, label: 'Galeri Video', serviceKey: 'video_galeri'),
          CreatorSidebarMenuEntry(icon: Icons.calendar_today_outlined, label: 'Booking & Jadwal', serviceKey: 'video_booking'),
          CreatorSidebarMenuEntry(icon: Icons.payments_outlined, label: 'Paket Harga', serviceKey: 'video_paket'),
          CreatorSidebarMenuEntry(icon: Icons.videocam_outlined, label: 'Equipment', serviceKey: 'video_equipment'),
        ];
      case 'editor':
      case 'photo_editor':
      case 'video_editor':
        return const [
          CreatorSidebarMenuEntry(icon: Icons.collections_outlined, label: 'Portofolio Edit', serviceKey: 'edit_portofolio'),
          CreatorSidebarMenuEntry(icon: Icons.list_alt_outlined, label: 'Antrian Kerja', serviceKey: 'edit_antrian'),
          CreatorSidebarMenuEntry(icon: Icons.payments_outlined, label: 'Daftar Harga', serviceKey: 'edit_harga'),
          CreatorSidebarMenuEntry(icon: Icons.tune_outlined, label: 'Spesialisasi', serviceKey: 'edit_spesialisasi'),
        ];
      case 'desainer':
      case 'designer':
      case 'graphic_designer':
      case 'desain':
        return const [
          CreatorSidebarMenuEntry(icon: Icons.palette_outlined, label: 'Portofolio Desain', serviceKey: 'desain_portofolio'),
          CreatorSidebarMenuEntry(icon: Icons.assignment_outlined, label: 'Proyek & Brief', serviceKey: 'desain_proyek'),
          CreatorSidebarMenuEntry(icon: Icons.payments_outlined, label: 'Paket Desain', serviceKey: 'desain_paket'),
          CreatorSidebarMenuEntry(icon: Icons.tune_outlined, label: 'Spesialisasi', serviceKey: 'desain_spesialisasi'),
        ];
      case 'mc':
        return const [
          CreatorSidebarMenuEntry(icon: Icons.mic_outlined, label: 'Profil MC', serviceKey: 'mc_profil'),
          CreatorSidebarMenuEntry(icon: Icons.calendar_today_outlined, label: 'Jadwal & Booking', serviceKey: 'mc_booking'),
          CreatorSidebarMenuEntry(icon: Icons.theater_comedy_outlined, label: 'Kategori Acara', serviceKey: 'mc_kategori'),
          CreatorSidebarMenuEntry(icon: Icons.payments_outlined, label: 'Tarif', serviceKey: 'mc_tarif'),
        ];
      case 'singer':
      case 'penyanyi':
        return const [
          CreatorSidebarMenuEntry(icon: Icons.music_note_outlined, label: 'Portofolio Musik', serviceKey: 'singer_portofolio'),
          CreatorSidebarMenuEntry(icon: Icons.calendar_today_outlined, label: 'Jadwal & Booking', serviceKey: 'singer_booking'),
          CreatorSidebarMenuEntry(icon: Icons.library_music_outlined, label: 'Genre & Repertoar', serviceKey: 'singer_genre'),
          CreatorSidebarMenuEntry(icon: Icons.payments_outlined, label: 'Tarif', serviceKey: 'singer_tarif'),
        ];
      case 'talent':
      case 'model':
      case 'talent_model':
        return const [
          CreatorSidebarMenuEntry(icon: Icons.portrait_outlined, label: 'Profil Talent', serviceKey: 'talent_profil'),
          CreatorSidebarMenuEntry(icon: Icons.calendar_today_outlined, label: 'Jadwal & Booking', serviceKey: 'talent_jadwal'),
          CreatorSidebarMenuEntry(icon: Icons.work_outline, label: 'Kategori Pekerjaan', serviceKey: 'talent_kategori'),
          CreatorSidebarMenuEntry(icon: Icons.payments_outlined, label: 'Tarif', serviceKey: 'talent_tarif'),
        ];
      case 'makeup_artist':
      case 'mua':
      case 'makeup':
        return const [
          CreatorSidebarMenuEntry(icon: Icons.face_outlined, label: 'Portofolio MUA', serviceKey: 'mua_portofolio'),
          CreatorSidebarMenuEntry(icon: Icons.calendar_today_outlined, label: 'Jadwal Booking', serviceKey: 'mua_booking'),
          CreatorSidebarMenuEntry(icon: Icons.payments_outlined, label: 'Paket Harga', serviceKey: 'mua_paket'),
          CreatorSidebarMenuEntry(icon: Icons.palette_outlined, label: 'Spesialisasi', serviceKey: 'mua_spesialisasi'),
        ];
      case 'wedding_organizer':
      case 'wo':
        return const [
          CreatorSidebarMenuEntry(icon: Icons.favorite_outline, label: 'Paket Pernikahan', serviceKey: 'wo_paket'),
          CreatorSidebarMenuEntry(icon: Icons.calendar_today_outlined, label: 'Jadwal Event', serviceKey: 'wo_jadwal'),
          CreatorSidebarMenuEntry(icon: Icons.handshake_outlined, label: 'Vendor Partner', serviceKey: 'wo_vendor'),
          CreatorSidebarMenuEntry(icon: Icons.timeline_outlined, label: 'Timeline WO', serviceKey: 'wo_timeline'),
        ];
      case 'event_organizer':
      case 'eo':
        return const [
          CreatorSidebarMenuEntry(icon: Icons.festival_outlined, label: 'Paket Event', serviceKey: 'eo_paket'),
          CreatorSidebarMenuEntry(icon: Icons.calendar_today_outlined, label: 'Jadwal Event', serviceKey: 'eo_jadwal'),
          CreatorSidebarMenuEntry(icon: Icons.handshake_outlined, label: 'Vendor Partner', serviceKey: 'eo_vendor'),
          CreatorSidebarMenuEntry(icon: Icons.timeline_outlined, label: 'Timeline EO', serviceKey: 'eo_timeline'),
        ];
      case 'community':
      case 'komunitas':
        return const [
          CreatorSidebarMenuEntry(icon: Icons.groups_outlined, label: 'Anggota', serviceKey: 'komunitas_anggota'),
          CreatorSidebarMenuEntry(icon: Icons.event_outlined, label: 'Kegiatan', serviceKey: 'komunitas_kegiatan'),
          CreatorSidebarMenuEntry(icon: Icons.campaign_outlined, label: 'Pengumuman', serviceKey: 'komunitas_pengumuman'),
          CreatorSidebarMenuEntry(icon: Icons.handshake_outlined, label: 'Kolaborasi Komunitas', serviceKey: 'komunitas_kolaborasi'),
        ];
      case 'drone':
      case 'drone_pilot':
      case 'pilot_drone':
        return const [
          CreatorSidebarMenuEntry(icon: Icons.airplanemode_active_outlined, label: 'Galeri Hasil Drone', serviceKey: 'drone_galeri'),
          CreatorSidebarMenuEntry(icon: Icons.calendar_today_outlined, label: 'Booking & Jadwal', serviceKey: 'drone_booking'),
          CreatorSidebarMenuEntry(icon: Icons.payments_outlined, label: 'Paket Harga', serviceKey: 'drone_paket'),
          CreatorSidebarMenuEntry(icon: Icons.videocam_outlined, label: 'Peralatan Drone', serviceKey: 'drone_equipment'),
        ];
      case 'content_creator':
      case 'influencer':
      case 'ugc':
        return const [
          CreatorSidebarMenuEntry(icon: Icons.photo_library_outlined, label: 'Portofolio Konten', serviceKey: 'konten_portofolio'),
          CreatorSidebarMenuEntry(icon: Icons.calendar_today_outlined, label: 'Jadwal & Campaign', serviceKey: 'konten_campaign'),
          CreatorSidebarMenuEntry(icon: Icons.payments_outlined, label: 'Paket & Harga', serviceKey: 'konten_paket'),
          CreatorSidebarMenuEntry(icon: Icons.language_outlined, label: 'Platform & Niche', serviceKey: 'konten_platform'),
        ];
      case 'animator':
      case '3d_animator':
      case 'motion_designer':
        return const [
          CreatorSidebarMenuEntry(icon: Icons.animation_outlined, label: 'Showreel 3D & Motion', serviceKey: 'animator_showreel'),
          CreatorSidebarMenuEntry(icon: Icons.view_in_ar_outlined, label: 'Asset 3D & Storyboard', serviceKey: 'animator_assets'),
          CreatorSidebarMenuEntry(icon: Icons.payments_outlined, label: 'Paket Animasi', serviceKey: 'animator_paket'),
          CreatorSidebarMenuEntry(icon: Icons.history_toggle_off_outlined, label: 'Render & Milestone', serviceKey: 'animator_render'),
        ];
      default:
        return const [];
    }
  }
}
