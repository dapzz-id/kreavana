<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\InstitutionResource;
use App\Enums\RoleType;
use App\Enums\CreatorSubRole;

class InstitutionResourceSeeder extends Seeder
{
    public function run(): void
    {
        $institutionUsers = User::whereIn('sub_role', [
            CreatorSubRole::INSTITUTION->value,
            CreatorSubRole::GOVERNMENT->value,
            'institution',
            'government',
        ])->get();

        if ($institutionUsers->isEmpty()) {
            return;
        }

        foreach ($institutionUsers as $user) {
            $resources = [
                [
                    'resource_type' => 'tenders',
                    'title' => 'Pengadaan Konten Edukasi Ekonomi Kreatif 2026',
                    'description' => 'Program pengadaan materi digital interaktif untuk pembinaan UMKM kreatif binaan dinas.',
                    'status' => 'open',
                    'metadata' => [
                        'category' => 'Pengadaan Konten',
                        'budget' => 75000000,
                        'deadline' => '2026-11-30',
                    ],
                    'published_at' => now()->subDays(5),
                ],
                [
                    'resource_type' => 'tenders',
                    'title' => 'Tender Dokumentasi Multi-Kamera Festival Seni Budaya',
                    'description' => 'Kerja sama peliputan dan siaran langsung festival seni budaya tingkat regional.',
                    'status' => 'in_progress',
                    'metadata' => [
                        'category' => 'Event & Broadcast',
                        'budget' => 120000000,
                        'deadline' => '2026-10-15',
                    ],
                    'published_at' => now()->subDays(12),
                ],
                [
                    'resource_type' => 'partners',
                    'title' => 'Asosiasi Komunitas Kreatif Nusantara',
                    'description' => 'Mitra strategis dalam pengembangan jejaring kreator lokal dan fasilitasi workshop.',
                    'status' => 'published',
                    'metadata' => [
                        'category' => 'Komunitas',
                        'contact' => 'kemitraan@kreatifnusantara.id',
                    ],
                    'published_at' => now()->subMonths(1),
                ],
                [
                    'resource_type' => 'reports',
                    'title' => 'Laporan Akuntabilitas Kinerja Triwulan III 2026',
                    'description' => 'Evaluasi capaian program pendampingan 150 kreator muda dan penyerapan anggaran kreatif.',
                    'status' => 'published',
                    'metadata' => [
                        'category' => 'Laporan Kinerja',
                        'period' => 'Triwulan III 2026',
                    ],
                    'published_at' => now()->subDays(3),
                ],
                [
                    'resource_type' => 'budgets',
                    'title' => 'Alokasi Fasilitasi Sertifikasi Kompetensi Kreator',
                    'description' => 'Rencana pembiayaan uji kompetensi bidang videografi, fotografi, dan event management.',
                    'status' => 'open',
                    'metadata' => [
                        'category' => 'Fasilitasi Sertifikasi',
                        'budget' => 200000000,
                    ],
                    'published_at' => now()->subDays(8),
                ],
                [
                    'resource_type' => 'announcements',
                    'title' => 'Pembukaan Pendaftaran Inkubasi Startup Kreatif Kreavana 2026',
                    'description' => 'Kesempatan pendanaan dan mentoring intensif selama 3 bulan untuk tim kreator terpilih.',
                    'status' => 'published',
                    'metadata' => [
                        'category' => 'Pengumuman Resmi',
                    ],
                    'published_at' => now()->subDays(1),
                ],
            ];

            foreach ($resources as $res) {
                InstitutionResource::updateOrCreate(
                    [
                        'user_id' => $user->id,
                        'title' => $res['title'],
                    ],
                    [
                        'resource_type' => $res['resource_type'],
                        'description' => $res['description'],
                        'status' => $res['status'],
                        'metadata' => $res['metadata'],
                        'published_at' => $res['published_at'],
                    ]
                );
            }
        }
    }
}
