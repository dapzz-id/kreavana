<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Opportunity;

class OpportunityLocationSeeder extends Seeder
{
    public function run(): void
    {
        $locations = [
            [
                'title' => 'Sunrise Point Bromo',
                'description' => 'Spot hunting sunrise terbaik di Penanjakan Bromo. Cocok untuk fotografer landscape dan drone pilot.',
                'pihak_slug' => 'kreator',
                'type' => 'location',
                'location' => 'Probolinggo',
                'latitude' => -7.9425,
                'longitude' => 112.9530,
                'location_category' => 'nature',
                'address' => 'Penanjakan Viewpoint, Bromo Tengger Semeru',
                'status' => 'open',
                'posted_by' => 1,
            ],
            [
                'title' => 'Kota Tua Jakarta',
                'description' => 'Lokasi heritage urban untuk street photography, pre-wedding, dan content creator.',
                'pihak_slug' => 'kreator',
                'type' => 'location',
                'location' => 'Jakarta',
                'latitude' => -6.1352,
                'longitude' => 106.8133,
                'location_category' => 'urban',
                'address' => 'Jl. Pintu Besar Utara No.27, Pinangsia, Taman Sari',
                'status' => 'open',
                'posted_by' => 1,
            ],
            [
                'title' => 'Candi Borobudur',
                'description' => 'Peluang lokasi budaya untuk dokumentasi wisata dan event komunitas kreatif.',
                'pihak_slug' => 'komunitas',
                'type' => 'location',
                'location' => 'Magelang',
                'latitude' => -7.6079,
                'longitude' => 110.2038,
                'location_category' => 'culture',
                'address' => 'Borobudur, Magelang, Jawa Tengah',
                'status' => 'open',
                'posted_by' => 1,
            ],
            [
                'title' => 'Pantai Parangtritis',
                'description' => 'Hidden gem sunset di selatan Yogyakarta. Ideal untuk videografi dan travel content.',
                'pihak_slug' => 'kreator',
                'type' => 'location',
                'location' => 'Yogyakarta',
                'latitude' => -8.0255,
                'longitude' => 110.3295,
                'location_category' => 'hidden_gems',
                'address' => 'Parangtritis, Kretek, Bantul',
                'status' => 'open',
                'posted_by' => 1,
            ],
            [
                'title' => 'Danau Toba Viewpoint',
                'description' => 'Spot wisata alam untuk konten pariwisata dan dokumentasi event musim liburan.',
                'pihak_slug' => 'pemerintah',
                'type' => 'location',
                'location' => 'Samosir',
                'latitude' => 2.6845,
                'longitude' => 98.8759,
                'location_category' => 'tourism',
                'address' => 'Taman Simalem Resort, Samosir, Sumatera Utara',
                'status' => 'open',
                'posted_by' => 1,
            ],
            [
                'title' => 'Ladang Lavender Seasonal',
                'description' => 'Lokasi seasonal spot untuk foto musiman, brand campaign, dan kolaborasi kreator.',
                'pihak_slug' => 'umkm',
                'type' => 'location',
                'location' => 'Bandung',
                'latitude' => -6.8345,
                'longitude' => 107.6590,
                'location_category' => 'seasonal',
                'address' => 'Lembang, Bandung Barat',
                'status' => 'open',
                'posted_by' => 1,
            ],
        ];

        $projects = [
            [
                'title' => 'Fotografer Event Jakarta',
                'description' => 'Dibutuhkan fotografer profesional untuk dokumentasi event corporate di Jakarta. Minimal pengalaman 2 tahun.',
                'pihak_slug' => 'kreator',
                'type' => 'project',
                'location' => 'Jakarta',
                'deadline' => '2026-07-15',
                'budget_range' => 'Rp 3.000.000 - Rp 5.000.000',
                'status' => 'open',
                'posted_by' => 1,
            ],
            [
                'title' => 'Videografer Wedding Bandung',
                'description' => 'Mencari videografer untuk dokumentasi pernikahan di Bandung. Wajib punya portofolio wedding.',
                'pihak_slug' => 'kreator',
                'type' => 'project',
                'location' => 'Bandung',
                'deadline' => '2026-07-20',
                'budget_range' => 'Rp 5.000.000 - Rp 8.000.000',
                'status' => 'open',
                'posted_by' => 1,
            ],
            [
                'title' => 'Editor Video YouTube',
                'description' => 'Butuh editor video untuk channel YouTube brand UMKM. Style cinematic, 2 video per minggu.',
                'pihak_slug' => 'umkm',
                'type' => 'project',
                'location' => 'Remote',
                'deadline' => '2026-08-01',
                'budget_range' => 'Rp 2.000.000 - Rp 4.000.000/bulan',
                'status' => 'open',
                'posted_by' => 1,
            ],
            [
                'title' => 'Desainer Social Media',
                'description' => 'Dibutuhkan desainer grafis untuk konten Instagram & TikTok event organizer.',
                'pihak_slug' => 'eo',
                'type' => 'project',
                'location' => 'Surabaya',
                'deadline' => '2026-07-30',
                'budget_range' => 'Rp 1.500.000 - Rp 3.000.000',
                'status' => 'open',
                'posted_by' => 1,
            ],
            [
                'title' => 'Drone Pilot Dokumentasi',
                'description' => 'Pilot drone berlisensi untuk dokumentasi aerial festival budaya daerah.',
                'pihak_slug' => 'pemerintah',
                'type' => 'project',
                'location' => 'Semarang',
                'deadline' => '2026-08-20',
                'budget_range' => 'Rp 5.000.000 - Rp 10.000.000',
                'status' => 'open',
                'posted_by' => 1,
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
