<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use App\Models\PihakCategory;
use App\Models\DashboardStat;
use App\Models\Opportunity;

class RemainingTablesSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // 1. Pihak Categories
        $categories = [
            [
                'slug' => 'kreator',
                'name' => 'Kreator',
                'description' => 'Fotografer, Videografer, MUA, Desainer, MC, Musisi, dll',
                'icon' => 'brush',
                'color' => '#F97316'
            ],
            [
                'slug' => 'eo',
                'name' => 'Event Organizer',
                'description' => 'Cari vendor terpercaya untuk event',
                'icon' => 'event',
                'color' => '#3B82F6'
            ],
            [
                'slug' => 'wo',
                'name' => 'Wedding Organizer',
                'description' => 'Paket vendor lengkap untuk wedding',
                'icon' => 'favorite',
                'color' => '#8B5CF6'
            ],
            [
                'slug' => 'sekolah',
                'name' => 'Sekolah / Kampus',
                'description' => 'Database alumni & talenta, magang & PKL',
                'icon' => 'school',
                'color' => '#10B981'
            ],
            [
                'slug' => 'umkm',
                'name' => 'Perusahaan / UMKM',
                'description' => 'Konten branding & promosi bisnis',
                'icon' => 'business',
                'color' => '#06B6D4'
            ],
            [
                'slug' => 'pemerintah',
                'name' => 'Pemerintah',
                'description' => 'Publikasi program & kegiatan resmi',
                'icon' => 'gavel',
                'color' => '#1E3A8A'
            ],
            [
                'slug' => 'komunitas',
                'name' => 'Komunitas',
                'description' => 'Event komunitas & kolaborasi',
                'icon' => 'groups',
                'color' => '#EC4899'
            ],
            [
                'slug' => 'organisasi',
                'name' => 'Organisasi / Asosiasi',
                'description' => 'Direktori anggota & event eksklusif',
                'icon' => 'corporate_fare',
                'color' => '#3F51B5'
            ]
        ];

        foreach ($categories as $cat) {
            PihakCategory::updateOrCreate(['slug' => $cat['slug']], $cat);
        }

        // 2. Dashboard Stats
        $stats = [
            ['pihak_slug' => 'kreator', 'role_type' => 'user', 'stat_label' => 'Peluang Tersedia', 'stat_value' => '24', 'stat_icon' => 'work', 'display_order' => 1],
            ['pihak_slug' => 'kreator', 'role_type' => 'user', 'stat_label' => 'Kreator Aktif', 'stat_value' => '150', 'stat_icon' => 'people', 'display_order' => 2],
            ['pihak_slug' => 'kreator', 'role_type' => 'user', 'stat_label' => 'Rating Rata-rata', 'stat_value' => '4.7', 'stat_icon' => 'star', 'display_order' => 3],
            ['pihak_slug' => 'kreator', 'role_type' => 'user', 'stat_label' => 'Proyek Selesai', 'stat_value' => '89', 'stat_icon' => 'check_circle', 'display_order' => 4],
            
            ['pihak_slug' => 'kreator', 'role_type' => 'creator', 'stat_label' => 'Peluang Diterima', 'stat_value' => '12', 'stat_icon' => 'assignment_turned_in', 'display_order' => 1],
            ['pihak_slug' => 'kreator', 'role_type' => 'creator', 'stat_label' => 'Proyek Berjalan', 'stat_value' => '3', 'stat_icon' => 'pending_actions', 'display_order' => 2],
            ['pihak_slug' => 'kreator', 'role_type' => 'creator', 'stat_label' => 'Selesai', 'stat_value' => '18', 'stat_icon' => 'task_alt', 'display_order' => 3],
            ['pihak_slug' => 'kreator', 'role_type' => 'creator', 'stat_label' => 'Rating Kamu', 'stat_value' => '4.8', 'stat_icon' => 'star', 'display_order' => 4],
            
            ['pihak_slug' => 'eo', 'role_type' => 'user', 'stat_label' => 'Event Mendatang', 'stat_value' => '6', 'stat_icon' => 'event', 'display_order' => 1],
            ['pihak_slug' => 'eo', 'role_type' => 'user', 'stat_label' => 'Vendor Tersedia', 'stat_value' => '120', 'stat_icon' => 'storefront', 'display_order' => 2],
            ['pihak_slug' => 'eo', 'role_type' => 'user', 'stat_label' => 'Booking Minggu Ini', 'stat_value' => '8', 'stat_icon' => 'bookmark', 'display_order' => 3],
            ['pihak_slug' => 'eo', 'role_type' => 'user', 'stat_label' => 'Rating Vendor', 'stat_value' => '4.6', 'stat_icon' => 'star', 'display_order' => 4],
            
            ['pihak_slug' => 'eo', 'role_type' => 'creator', 'stat_label' => 'Proyek Event', 'stat_value' => '15', 'stat_icon' => 'event_available', 'display_order' => 1],
            ['pihak_slug' => 'eo', 'role_type' => 'creator', 'stat_label' => 'Vendor Terpilih', 'stat_value' => '4', 'stat_icon' => 'how_to_reg', 'display_order' => 2],
            ['pihak_slug' => 'eo', 'role_type' => 'creator', 'stat_label' => 'Selesai', 'stat_value' => '23', 'stat_icon' => 'task_alt', 'display_order' => 3],
            ['pihak_slug' => 'eo', 'role_type' => 'creator', 'stat_label' => 'Rating Kamu', 'stat_value' => '4.7', 'stat_icon' => 'star', 'display_order' => 4]
        ];

        foreach ($stats as $stat) {
            DashboardStat::create($stat);
        }

        // 3. Opportunities
        $opps = [
            [
                'title' => 'Fotografer Event Jakarta',
                'description' => 'Dibutuhkan fotografer profesional untuk dokumentasi event corporate di Jakarta. Minimal pengalaman 2 tahun.',
                'pihak_slug' => 'kreator',
                'location' => 'Jakarta',
                'deadline' => '2026-07-15',
                'budget_range' => 'Rp 3.000.000 - Rp 5.000.000',
                'status' => 'open',
                'posted_by' => 1
            ],
            [
                'title' => 'Videografer Wedding Bandung',
                'description' => 'Mencari videografer untuk dokumentasi pernikahan di Bandung. Wajib punya portofolio wedding.',
                'pihak_slug' => 'kreator',
                'location' => 'Bandung',
                'deadline' => '2026-07-20',
                'budget_range' => 'Rp 5.000.000 - Rp 8.000.000',
                'status' => 'open',
                'posted_by' => 1
            ],
            [
                'title' => 'MUA Fashion Show',
                'description' => 'Dibutuhkan Make Up Artist untuk fashion show brand lokal. 10 model perlu di-makeup.',
                'pihak_slug' => 'kreator',
                'location' => 'Surabaya',
                'deadline' => '2026-08-01',
                'budget_range' => 'Rp 4.000.000 - Rp 6.000.000',
                'status' => 'open',
                'posted_by' => 1
            ],
            [
                'title' => 'Konser Musik Akhir Tahun',
                'description' => 'Event organizer untuk konser musik akhir tahun kapasitas 5000 orang. Termasuk sound, lighting, dan stage.',
                'pihak_slug' => 'eo',
                'location' => 'Jakarta',
                'deadline' => '2026-12-20',
                'budget_range' => 'Rp 50.000.000 - Rp 100.000.000',
                'status' => 'open',
                'posted_by' => 1
            ],
            [
                'title' => 'Festival Kuliner Nusantara',
                'description' => 'Penyelenggaraan festival kuliner skala kota selama 3 hari. Butuh tim EO berpengalaman.',
                'pihak_slug' => 'eo',
                'location' => 'Yogyakarta',
                'deadline' => '2026-09-10',
                'budget_range' => 'Rp 30.000.000 - Rp 60.000.000',
                'status' => 'open',
                'posted_by' => 1
            ]
        ];

        foreach ($opps as $opp) {
            Opportunity::create($opp);
        }
    }
}
