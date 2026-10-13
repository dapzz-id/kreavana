<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\CommunityActivity;
use App\Models\CommunityMember;
use App\Models\CommunityActivityParticipant;
use App\Models\CommunityAnnouncement;
use Illuminate\Support\Str;

class CommunityCompleteSeeder extends Seeder
{
    public function run(): void
    {
        $communityUsers = User::where('sub_role', 'community')->get();

        if ($communityUsers->isEmpty()) {
            $this->command->warn('No community user found in database.');
            return;
        }

        // Get some other creator users to become members
        $creators = User::where('role', 'creator')
            ->where('sub_role', '!=', 'community')
            ->take(15)
            ->get();

        if ($creators->isEmpty()) {
            $creators = User::where('id', '!=', $communityUsers->first()->id)->take(10)->get();
        }

        foreach ($communityUsers as $communityUser) {
            // 1. Seed Activities
            $existingActivities = CommunityActivity::where('community_id', $communityUser->id)->count();
            if ($existingActivities === 0) {
                $activities = [
                    [
                        'title' => 'Hunting Fotografi Landscape & Golden Hour',
                        'description' => 'Kegiatan hunting foto landscape bersama seluruh anggota komunitas di area pegunungan. Wajib membawa perlengkapan kamera, lensa wide, dan tripod.',
                        'activity_date' => now()->addDays(3)->setTime(6, 0),
                        'location' => 'Puncak Pass, Bogor',
                        'status' => 'active',
                        'max_participants' => 25,
                    ],
                    [
                        'title' => 'Workshop Color Grading & Video Sinematik',
                        'description' => 'Pelatihan intensif editing video & teknik grading DaVinci Resolve bersama editor profesional mitra komunitas.',
                        'activity_date' => now()->addDays(8)->setTime(13, 30),
                        'location' => 'Creative Space Kreavana, Jakarta Selatan',
                        'status' => 'active',
                        'max_participants' => 30,
                    ],
                    [
                        'title' => 'Pameran Karya Street Photography 2026',
                        'description' => 'Pameran visual karya terbaik kurasi anggota komunitas. Terbuka untuk umum dan mitra media.',
                        'activity_date' => now()->addDays(14)->setTime(10, 0),
                        'location' => 'Galeri Seni Ruang Rupa, Bandung',
                        'status' => 'pending',
                        'max_participants' => 50,
                    ],
                    [
                        'title' => 'Meetup Kreatif & Sharing Session Sponsorship',
                        'description' => 'Diskusi panel strategi pitching proposal kegiatan ke calon investor/sponsor brand ternama.',
                        'activity_date' => now()->addDays(20)->setTime(15, 0),
                        'location' => 'Kopi Kolaborasi, Jakarta Pusat',
                        'status' => 'pending',
                        'max_participants' => 40,
                    ],
                    [
                        'title' => 'Sesi Dokumentasi Kebudayaan Nusantara',
                        'description' => 'Proyek dokumentasi adat dan pengerjaan portofolio arsip kebudayaan lokal bersama talenta binaan.',
                        'activity_date' => now()->subDays(5)->setTime(9, 0),
                        'location' => 'Desa Wisata Tradisional, Yogyakarta',
                        'status' => 'completed',
                        'max_participants' => 20,
                    ],
                ];

                foreach ($activities as $act) {
                    $createdActivity = CommunityActivity::create([
                        'id' => (string) Str::uuid(),
                        'community_id' => $communityUser->id,
                        'title' => $act['title'],
                        'description' => $act['description'],
                        'activity_date' => $act['activity_date'],
                        'location' => $act['location'],
                        'status' => $act['status'],
                        'max_participants' => $act['max_participants'],
                        'created_by' => $communityUser->id,
                    ]);

                    // Add participants
                    foreach ($creators->take(4) as $participant) {
                        CommunityActivityParticipant::firstOrCreate([
                            'activity_id' => $createdActivity->id,
                            'user_id' => $participant->id,
                        ], [
                            'id' => (string) Str::uuid(),
                            'status' => 'confirmed',
                            'joined_at' => now()->subDays(rand(1, 4)),
                        ]);
                    }
                }
            }

            // 2. Seed Members
            $existingMembers = CommunityMember::where('community_id', $communityUser->id)->count();
            if ($existingMembers === 0) {
                $roles = [
                    'Ketua & Koordinator Umum',
                    'Sekretaris & Humas',
                    'Koordinator Event & Agenda',
                    'Kreator Foto & Kurator',
                    'Kreator Video & Dokumentasi',
                    'Desainer Visual & Media',
                    'Mitra Studio & Perlengkapan',
                    'Koordinator Kemitraan & Sponsor',
                    'Anggota Aktif Komunitas',
                    'Anggota Muda Komunitas',
                ];

                $idx = 0;
                foreach ($creators as $creator) {
                    $assignedRole = $roles[$idx % count($roles)];
                    CommunityMember::create([
                        'id' => (string) Str::uuid(),
                        'community_id' => $communityUser->id,
                        'user_id' => $creator->id,
                        'role' => $assignedRole,
                        'status' => 'active',
                        'joined_at' => now()->subDays(rand(10, 180)),
                    ]);
                    $idx++;
                }
            }

            // 3. Seed Announcements
            $existingAnnouncements = CommunityAnnouncement::where('community_id', $communityUser->id)->count();
            if ($existingAnnouncements === 0) {
                $announcements = [
                    [
                        'title' => 'Pendaftaran Workshop Color Grading Resmi Dibuka',
                        'content' => 'Halo Sahabat Kreatif! Kuota peserta workshop sinematik terbatas untuk 30 orang anggota. Segera konfirmasi kehadiran melalui modul agenda kegiatan.',
                        'type' => 'event',
                        'priority' => 'high',
                        'published_at' => now()->subDays(1),
                        'expires_at' => now()->addDays(10),
                    ],
                    [
                        'title' => 'Open Call: Submit Karya Pameran Foto Street Photography 2026',
                        'content' => 'Kurasi karya pameran foto tahunan komunitas telah dibuka! Kirimkan karya visual terbaik Anda dengan resolusi tinggi sebelum batas waktu akhir pekan ini.',
                        'type' => 'important',
                        'priority' => 'urgent',
                        'published_at' => now()->subDays(3),
                        'expires_at' => now()->addDays(12),
                    ],
                    [
                        'title' => 'Kemitraan Sponsorship & Dukungan Brand Aksesori Kamera',
                        'content' => 'Kabar gembira! Komunitas kita resmi menjalin kemitraan sponsorship dengan penyedia gear kreatif. Anggota aktif berhak atas diskon sewa alat dan merchandise resmi.',
                        'type' => 'general',
                        'priority' => 'normal',
                        'published_at' => now()->subDays(6),
                        'expires_at' => now()->addDays(30),
                    ],
                    [
                        'title' => 'Pemberitahuan Keselamatan & Perlengkapan Hunting Pegunungan',
                        'content' => 'Mengingat cuaca pegunungan yang dinamis, seluruh peserta hunting akhir pekan wajib mengenakan jaket tahan angin dan membawa rain cover untuk kamera.',
                        'type' => 'warning',
                        'priority' => 'high',
                        'published_at' => now()->subHours(12),
                        'expires_at' => now()->addDays(4),
                    ],
                ];

                foreach ($announcements as $ann) {
                    CommunityAnnouncement::create([
                        'id' => (string) Str::uuid(),
                        'community_id' => $communityUser->id,
                        'title' => $ann['title'],
                        'content' => $ann['content'],
                        'type' => $ann['type'],
                        'priority' => $ann['priority'],
                        'published_at' => $ann['published_at'],
                        'expires_at' => $ann['expires_at'],
                        'created_by' => $communityUser->id,
                        'status' => 'published',
                    ]);
                }
            }
        }

        $this->command->info('Community Complete Seeder executed successfully for ' . $communityUsers->count() . ' community accounts.');
    }
}
