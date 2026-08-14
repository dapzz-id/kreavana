<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Opportunity;

class OpportunityLocationSeeder extends Seeder
{
    public function run(): void
    {
        $user = \App\Models\User::first();
        $adminId = $user ? $user->id : '018f0000-0000-7000-8000-000000000001';

        $locations = [
            [
                'title' => 'Sunrise Point Bromo',
                'description' => 'Spot hunting sunrise terbaik di Penanjakan Bromo. Cocok untuk fotografer landscape dan drone pilot.',
                'sub_role_slug' => 'kreator',
                'type' => 'location',
                'location' => 'Probolinggo',
                'latitude' => -7.9425,
                'longitude' => 112.9530,
                'location_category' => 'nature',
                'address' => 'Penanjakan Viewpoint, Bromo Tengger Semeru',
                'status' => 'open',
                'posted_by' => $adminId,
            ],
            [
                'title' => 'Kota Tua Jakarta',
                'description' => 'Lokasi heritage urban untuk street photography, pre-wedding, dan content creator.',
                'sub_role_slug' => 'kreator',
                'type' => 'location',
                'location' => 'Jakarta',
                'latitude' => -6.1352,
                'longitude' => 106.8133,
                'location_category' => 'urban',
                'address' => 'Jl. Pintu Besar Utara No.27, Pinangsia, Taman Sari',
                'status' => 'open',
                'posted_by' => $adminId,
            ],
            [
                'title' => 'Candi Borobudur',
                'description' => 'Peluang lokasi budaya untuk dokumentasi wisata dan event komunitas kreatif.',
                'sub_role_slug' => 'komunitas',
                'type' => 'location',
                'location' => 'Magelang',
                'latitude' => -7.6079,
                'longitude' => 110.2038,
                'location_category' => 'culture',
                'address' => 'Borobudur, Magelang, Jawa Tengah',
                'status' => 'open',
                'posted_by' => $adminId,
            ],
            [
                'title' => 'Pantai Parangtritis',
                'description' => 'Hidden gem sunset di selatan Yogyakarta. Ideal untuk videografi dan travel content.',
                'sub_role_slug' => 'kreator',
                'type' => 'location',
                'location' => 'Yogyakarta',
                'latitude' => -8.0255,
                'longitude' => 110.3295,
                'location_category' => 'hidden_gems',
                'address' => 'Parangtritis, Kretek, Bantul',
                'status' => 'open',
                'posted_by' => $adminId,
            ],
        ];

        $projects = [
            [
                'title' => 'Festival Budaya Nusantara 2024',
                'description' => 'Dibutuhkan tim dokumentasi foto & video profesional untuk merayakan Festival Budaya Nusantara 2024.',
                'sub_role_slug' => 'event_organizer',
                'type' => 'project',
                'location' => 'Jakarta',
                'deadline' => '2026-09-15',
                'budget_range' => 'Rp 8.000.000',
                'status' => 'open',
                'posted_by' => $adminId,
            ],
            [
                'title' => 'Video Promosi Produk Kreatif',
                'description' => 'Proyek pembuatan video sinematik durasi 60 detik untuk showcase produk e-commerce & social media ads.',
                'sub_role_slug' => 'videographer',
                'type' => 'project',
                'location' => 'Bandung',
                'deadline' => '2026-09-20',
                'budget_range' => 'Rp 5.000.000',
                'status' => 'open',
                'posted_by' => $adminId,
            ],
            [
                'title' => 'Kolaborasi Konten Series',
                'description' => 'Peluang kolaborasi jangka panjang untuk creator series dalam bidang konten visual, podcast, dan review.',
                'sub_role_slug' => 'kreator',
                'type' => 'project',
                'location' => 'Remote',
                'deadline' => '2026-10-01',
                'budget_range' => 'Kesepakatan Bersama',
                'status' => 'open',
                'posted_by' => $adminId,
            ],
            [
                'title' => 'Komunitas Editor Indonesia',
                'description' => 'Networking, sharing session, dan proyek gabungan bersama komunitas editor video & foto Indonesia.',
                'sub_role_slug' => 'editor',
                'type' => 'project',
                'location' => 'Online',
                'deadline' => '2026-12-31',
                'budget_range' => 'Gratis',
                'status' => 'open',
                'posted_by' => $adminId,
            ],
            [
                'title' => 'Foto Katalog Produk Summer Collection 2026',
                'description' => 'Sesi foto studio katalog busana koleksi musim panas 2026. Termasuk model & MUA.',
                'sub_role_slug' => 'photographer',
                'type' => 'project',
                'location' => 'Surabaya',
                'deadline' => '2026-08-30',
                'budget_range' => 'Rp 8.500.000',
                'status' => 'open',
                'posted_by' => $adminId,
            ],
            [
                'title' => 'Video Promosi Instagram & TikTok Commercial',
                'description' => 'Pembuatan 5 konten video reels / tiktok commercial dengan editan ritme cepat & voice over.',
                'sub_role_slug' => 'videographer',
                'type' => 'project',
                'location' => 'Jakarta',
                'deadline' => '2026-09-05',
                'budget_range' => 'Rp 14.000.000',
                'status' => 'open',
                'posted_by' => $adminId,
            ],
            [
                'title' => 'Desain Poster Campaign Digital',
                'description' => 'Pembuatan 10 desain poster digital high-res untuk media sosial dan cetak banner event.',
                'sub_role_slug' => 'kreator',
                'type' => 'project',
                'location' => 'Remote',
                'deadline' => '2026-08-25',
                'budget_range' => 'Rp 3.500.000',
                'status' => 'open',
                'posted_by' => $adminId,
            ],
        ];

        foreach (array_merge($locations, $projects) as $opp) {
            Opportunity::updateOrCreate(
                ['title' => $opp['title']],
                array_merge($opp, ['created_at' => now()])
            );
        }
    }
}
