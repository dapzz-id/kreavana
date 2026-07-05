<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use App\Models\SubRoleCategory;
use App\Models\DashboardStat;
use App\Models\Opportunity;

class RemainingTablesSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $admin = \App\Models\User::where('role', 'admin')->first();
        $adminId = $admin ? $admin->id : null;

        // 1. Sub Role Categories — slugs aligned with App\Enums\CreatorSubRole
        $categories = [
            [
                'slug' => 'institution',
                'name' => 'Institution',
                'description' => 'Lembaga pendidikan, penelitian, atau organisasi non-profit',
                'icon' => 'account_balance',
                'color' => '#10B981'
            ],
            [
                'slug' => 'government',
                'name' => 'Government',
                'description' => 'Publikasi program & kegiatan pemerintah resmi',
                'icon' => 'gavel',
                'color' => '#1E3A8A'
            ],
            [
                'slug' => 'mc',
                'name' => 'MC',
                'description' => 'Master of Ceremony profesional untuk berbagai acara',
                'icon' => 'mic',
                'color' => '#F59E0B'
            ],
            [
                'slug' => 'singer',
                'name' => 'Singer',
                'description' => 'Artis musik, penyanyi solo, atau grup vokal',
                'icon' => 'music_note',
                'color' => '#8B5CF6'
            ],
            [
                'slug' => 'wedding_organizer',
                'name' => 'Wedding Organizer',
                'description' => 'Paket vendor dan konsultasi lengkap untuk pernikahan',
                'icon' => 'favorite',
                'color' => '#EC4899'
            ],
            [
                'slug' => 'event_organizer',
                'name' => 'Event Organizer',
                'description' => 'Penyelenggara event profesional dari berbagai skala',
                'icon' => 'event',
                'color' => '#3B82F6'
            ],
            [
                'slug' => 'community',
                'name' => 'Community',
                'description' => 'Event komunitas, kolaborasi, & jaringan sosial',
                'icon' => 'groups',
                'color' => '#06B6D4'
            ],
            [
                'slug' => 'makeup_artist',
                'name' => 'Makeup Artist',
                'description' => 'Jasa tata rias dan makeup profesional untuk berbagai acara',
                'icon' => 'face_retouching_natural',
                'color' => '#F472B6'
            ],
            [
                'slug' => 'photographer',
                'name' => 'Photographer',
                'description' => 'Layanan fotografi profesional untuk dokumentasi, komersial, dan personal',
                'icon' => 'photo_camera',
                'color' => '#38BDF8'
            ],
            [
                'slug' => 'editor',
                'name' => 'Editor',
                'description' => 'Penyunting video, foto, dan konten digital lainnya',
                'icon' => 'edit',
                'color' => '#A78BFA'
            ],
            [
                'slug' => 'videographer',
                'name' => 'Videographer',
                'description' => 'Layanan produksi dan dokumentasi video profesional',
                'icon' => 'videocam',
                'color' => '#FB7185'
            ],
        ];

        foreach ($categories as $cat) {
            SubRoleCategory::updateOrCreate(['slug' => $cat['slug']], $cat);
        }

        // 2. Dashboard Stats
        $stats = [
            ['sub_role_slug' => 'photographer', 'role_type' => 'user', 'stat_label' => 'Peluang Tersedia', 'stat_value' => '24', 'stat_icon' => 'work', 'display_order' => 1],
            ['sub_role_slug' => 'photographer', 'role_type' => 'user', 'stat_label' => 'Kreator Aktif', 'stat_value' => '150', 'stat_icon' => 'people', 'display_order' => 2],
            ['sub_role_slug' => 'photographer', 'role_type' => 'user', 'stat_label' => 'Rating Rata-rata', 'stat_value' => '4.7', 'stat_icon' => 'star', 'display_order' => 3],
            ['sub_role_slug' => 'photographer', 'role_type' => 'user', 'stat_label' => 'Proyek Selesai', 'stat_value' => '89', 'stat_icon' => 'check_circle', 'display_order' => 4],

            ['sub_role_slug' => 'photographer', 'role_type' => 'creator', 'stat_label' => 'Peluang Diterima', 'stat_value' => '12', 'stat_icon' => 'assignment_turned_in', 'display_order' => 1],
            ['sub_role_slug' => 'photographer', 'role_type' => 'creator', 'stat_label' => 'Proyek Berjalan', 'stat_value' => '3', 'stat_icon' => 'pending_actions', 'display_order' => 2],
            ['sub_role_slug' => 'photographer', 'role_type' => 'creator', 'stat_label' => 'Selesai', 'stat_value' => '18', 'stat_icon' => 'task_alt', 'display_order' => 3],
            ['sub_role_slug' => 'photographer', 'role_type' => 'creator', 'stat_label' => 'Rating Kamu', 'stat_value' => '4.8', 'stat_icon' => 'star', 'display_order' => 4],

            ['sub_role_slug' => 'event_organizer', 'role_type' => 'user', 'stat_label' => 'Event Mendatang', 'stat_value' => '6', 'stat_icon' => 'event', 'display_order' => 1],
            ['sub_role_slug' => 'event_organizer', 'role_type' => 'user', 'stat_label' => 'Vendor Tersedia', 'stat_value' => '120', 'stat_icon' => 'storefront', 'display_order' => 2],
            ['sub_role_slug' => 'event_organizer', 'role_type' => 'user', 'stat_label' => 'Booking Minggu Ini', 'stat_value' => '8', 'stat_icon' => 'bookmark', 'display_order' => 3],
            ['sub_role_slug' => 'event_organizer', 'role_type' => 'user', 'stat_label' => 'Rating Vendor', 'stat_value' => '4.6', 'stat_icon' => 'star', 'display_order' => 4],

            ['sub_role_slug' => 'event_organizer', 'role_type' => 'creator', 'stat_label' => 'Proyek Event', 'stat_value' => '15', 'stat_icon' => 'event_available', 'display_order' => 1],
            ['sub_role_slug' => 'event_organizer', 'role_type' => 'creator', 'stat_label' => 'Vendor Terpilih', 'stat_value' => '4', 'stat_icon' => 'how_to_reg', 'display_order' => 2],
            ['sub_role_slug' => 'event_organizer', 'role_type' => 'creator', 'stat_label' => 'Selesai', 'stat_value' => '23', 'stat_icon' => 'task_alt', 'display_order' => 3],
            ['sub_role_slug' => 'event_organizer', 'role_type' => 'creator', 'stat_label' => 'Rating Kamu', 'stat_value' => '4.7', 'stat_icon' => 'star', 'display_order' => 4],
        ];

        foreach ($stats as $stat) {
            DashboardStat::create($stat);
        }

        // 3. Opportunities
        $opps = [
            [
                'title' => 'Fotografer Event Jakarta',
                'description' => 'Dibutuhkan fotografer profesional untuk dokumentasi event corporate di Jakarta. Minimal pengalaman 2 tahun.',
                'sub_role_slug' => 'photographer',
                'location' => 'Jakarta',
                'deadline' => '2026-07-15',
                'budget_range' => 'Rp 3.000.000 - Rp 5.000.000',
                'status' => 'open',
                'posted_by' => $adminId
            ],
            [
                'title' => 'MC Pernikahan & Event Korporat',
                'description' => 'Mencari MC profesional untuk acara pernikahan dan event korporat. Pengalaman minimal 2 tahun.',
                'sub_role_slug' => 'mc',
                'location' => 'Bandung',
                'deadline' => '2026-07-20',
                'budget_range' => 'Rp 2.000.000 - Rp 5.000.000',
                'status' => 'open',
                'posted_by' => $adminId
            ],
            [
                'title' => 'Penyanyi Wedding Organizer',
                'description' => 'Butuh penyanyi untuk paket pernikahan premium. Genre: pop, jazz, dan akustik.',
                'sub_role_slug' => 'singer',
                'location' => 'Surabaya',
                'deadline' => '2026-08-01',
                'budget_range' => 'Rp 4.000.000 - Rp 8.000.000',
                'status' => 'open',
                'posted_by' => $adminId
            ],
            [
                'title' => 'Konser Musik Akhir Tahun',
                'description' => 'Event organizer untuk konser musik akhir tahun kapasitas 5000 orang. Termasuk sound, lighting, dan stage.',
                'sub_role_slug' => 'event_organizer',
                'location' => 'Jakarta',
                'deadline' => '2026-12-20',
                'budget_range' => 'Rp 50.000.000 - Rp 100.000.000',
                'status' => 'open',
                'posted_by' => $adminId
            ],
            [
                'title' => 'Peliputan Kegiatan Pemerintah Daerah',
                'description' => 'Dibutuhkan kreator konten untuk dokumentasi dan publikasi program kegiatan pemerintah daerah.',
                'sub_role_slug' => 'government',
                'location' => 'Yogyakarta',
                'deadline' => '2026-09-10',
                'budget_range' => 'Rp 10.000.000 - Rp 25.000.000',
                'status' => 'open',
                'posted_by' => $adminId
            ],
            [
                'title' => 'Makeup Artist Wedding Premium',
                'description' => 'Dibutuhkan makeup artist profesional untuk pernikahan premium di Bali. Termasuk trial makeup.',
                'sub_role_slug' => 'makeup_artist',
                'location' => 'Bali',
                'deadline' => '2026-07-25',
                'budget_range' => 'Rp 2.500.000 - Rp 4.000.000',
                'status' => 'open',
                'posted_by' => $adminId
            ],
            [
                'title' => 'Videografer Dokumentasi Event',
                'description' => 'Mencari videografer untuk dokumentasi event corporate dan wedding. Portfolio wajib.',
                'sub_role_slug' => 'videographer',
                'location' => 'Jakarta',
                'deadline' => '2026-08-10',
                'budget_range' => 'Rp 5.000.000 - Rp 8.000.000',
                'status' => 'open',
                'posted_by' => $adminId
            ],
            [
                'title' => 'Editor Video Konten Sosial',
                'description' => 'Dibutuhkan editor video untuk konten sosial (Instagram, TikTok, YouTube). Style: modern dan dynamic.',
                'sub_role_slug' => 'editor',
                'location' => 'Remote',
                'deadline' => '2026-07-30',
                'budget_range' => 'Rp 1.500.000 - Rp 3.000.000',
                'status' => 'open',
                'posted_by' => $adminId
            ],
        ];

        foreach ($opps as $opp) {
            // Trim any accidental whitespace from slug
            $opp['sub_role_slug'] = trim($opp['sub_role_slug']);
            Opportunity::create($opp);
        }
    }
}
