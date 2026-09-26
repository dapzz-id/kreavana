<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Collaboration;
use App\Models\CollaborationMember;
use App\Models\User;
use Illuminate\Support\Str;

class CollaborationSeeder extends Seeder
{
    public function run(): void
    {
        $users = User::whereIn('email', [
            'dimas.arya@kreavana.id',
            'sarah.putri@kreavana.id',
            'kevin.jonathan@kreavana.id',
            'aditya.pratama@kreavana.id',
            'nabila.zahra@kreavana.id',
        ])->get()->keyBy('email');

        if ($users->isEmpty()) {
            return;
        }

        $collabData = [
            [
                'id' => (string) Str::uuid(),
                'requester_email' => 'dimas.arya@kreavana.id',
                'project_title' => 'Produksi Video Iklan Pariwisata Wonderful Indonesia 2026',
                'description' => 'Membutuhkan drone pilot bersertifikat FPV dan colorist DaVinci untuk shooting di Labuan Bajo & Bali selama 4 hari penuh.',
                'project_location' => 'Bali & Labuan Bajo',
                'budget_min' => 18500000,
                'budget_max' => 20000000,
                'status' => 'active',
                'start_date' => '2026-09-25',
                'end_date' => '2026-10-10',
                'notes' => json_encode([
                    'neededRoles' => ['Drone Pilot FPV', 'Colorist DaVinci', 'Audio Recordist'],
                    'compensationType' => 'Bagi Hasil & Fee Tetap',
                    'tags' => ['Cinematic', 'Travel', 'Commercial'],
                    'maxMembers' => 6,
                ]),
                'members' => [
                    ['email' => 'dimas.arya@kreavana.id', 'role' => 'Director & Produser', 'status' => 'active'],
                    ['email' => 'sarah.putri@kreavana.id', 'role' => 'Colorist', 'status' => 'active'],
                    ['email' => 'kevin.jonathan@kreavana.id', 'role' => 'Drone Pilot FPV', 'status' => 'active'],
                    ['email' => 'aditya.pratama@kreavana.id', 'role' => 'Audio Recordist', 'status' => 'active'],
                ],
            ],
            [
                'id' => (string) Str::uuid(),
                'requester_email' => 'sarah.putri@kreavana.id',
                'project_title' => 'Rebranding & Desain Kemasan UMKM Kopi Kintamani',
                'description' => 'Mencari packaging illustrator dan 3D visualizer mockup produk untuk persiapan ekspor pasar Jepang & Australia.',
                'project_location' => 'Remote / Bali',
                'budget_min' => 8500000,
                'budget_max' => 10000000,
                'status' => 'pending',
                'start_date' => '2026-09-30',
                'end_date' => '2026-10-25',
                'notes' => json_encode([
                    'neededRoles' => ['Packaging Designer', '3D Artist', 'Copywriter'],
                    'compensationType' => 'Escrow Kreavana',
                    'tags' => ['Branding', 'Packaging', 'Export'],
                    'maxMembers' => 3,
                ]),
                'members' => [
                    ['email' => 'sarah.putri@kreavana.id', 'role' => 'Brand Strategist', 'status' => 'active'],
                    ['email' => 'nabila.zahra@kreavana.id', 'role' => 'Copywriter', 'status' => 'invited'],
                ],
            ],
            [
                'id' => (string) Str::uuid(),
                'requester_email' => 'kevin.jonathan@kreavana.id',
                'project_title' => 'Photoshoot Editorial Fashion Raya Collection 2026',
                'description' => 'Kolaborasi photoshoot lookbook busana muslim modern bersama brand lokal terkemuka di studio profesional.',
                'project_location' => 'Studio Kreavana Jakarta',
                'budget_min' => 14000000,
                'budget_max' => 15000000,
                'status' => 'active',
                'start_date' => '2026-10-05',
                'end_date' => '2026-10-15',
                'notes' => json_encode([
                    'neededRoles' => ['MUA Editorial', 'Fashion Stylist', 'Lighting Assistant'],
                    'compensationType' => 'Kontrak Terproteksi',
                    'tags' => ['Fashion', 'Editorial', 'Lookbook'],
                    'maxMembers' => 5,
                ]),
                'members' => [
                    ['email' => 'kevin.jonathan@kreavana.id', 'role' => 'Fashion Photographer', 'status' => 'active'],
                    ['email' => 'dimas.arya@kreavana.id', 'role' => 'Lighting Assistant', 'status' => 'active'],
                    ['email' => 'sarah.putri@kreavana.id', 'role' => 'Fashion Stylist', 'status' => 'active'],
                ],
            ],
            [
                'id' => (string) Str::uuid(),
                'requester_email' => 'aditya.pratama@kreavana.id',
                'project_title' => 'Original Score & Sound Design Film Pendek "Suara Pesisir"',
                'description' => 'Proyek film pendek festival internasional. Membutuhkan pengisi instrumen tradisional dan mixing surround 5.1.',
                'project_location' => 'Remote / Yogyakarta',
                'budget_min' => 7500000,
                'budget_max' => 9000000,
                'status' => 'pending',
                'start_date' => '2026-10-15',
                'end_date' => '2026-11-01',
                'notes' => json_encode([
                    'neededRoles' => ['Mixing Engineer', 'Foley Artist'],
                    'compensationType' => 'Royalti & Fee',
                    'tags' => ['FilmScore', 'Festival', 'Audio'],
                    'maxMembers' => 4,
                ]),
                'members' => [
                    ['email' => 'aditya.pratama@kreavana.id', 'role' => 'Sound Designer & Composer', 'status' => 'active'],
                    ['email' => 'dimas.arya@kreavana.id', 'role' => 'Producer Advisor', 'status' => 'invited'],
                ],
            ],
            [
                'id' => (string) Str::uuid(),
                'requester_email' => 'nabila.zahra@kreavana.id',
                'project_title' => 'Campaign Konten Tiktok & Reels Kuliner Nusantara',
                'description' => 'Produksi 30 video konten pendek review kuliner khas nusantara untuk sponsor e-commerce terkemuka.',
                'project_location' => 'Jakarta & Bandung',
                'budget_min' => 12000000,
                'budget_max' => 12000000,
                'status' => 'completed',
                'start_date' => '2026-08-10',
                'end_date' => '2026-09-10',
                'notes' => json_encode([
                    'neededRoles' => ['Content Creator', 'Video Editor CapCut'],
                    'compensationType' => 'Selesai Dibayarkan',
                    'tags' => ['TikTok', 'Culinary', 'ViralContent'],
                    'maxMembers' => 4,
                ]),
                'members' => [
                    ['email' => 'nabila.zahra@kreavana.id', 'role' => 'Social Media Specialist', 'status' => 'active'],
                    ['email' => 'sarah.putri@kreavana.id', 'role' => 'Creative Director', 'status' => 'active'],
                    ['email' => 'aditya.pratama@kreavana.id', 'role' => 'Audio Editor', 'status' => 'active'],
                ],
            ],
        ];

        foreach ($collabData as $item) {
            $requester = $users[$item['requester_email']] ?? null;
            if (!$requester) {
                continue;
            }

            $collab = Collaboration::updateOrCreate(
                [
                    'project_title' => $item['project_title'],
                    'requester_id' => $requester->id,
                ],
                [
                    'description' => $item['description'],
                    'project_location' => $item['project_location'],
                    'budget_min' => $item['budget_min'],
                    'budget_max' => $item['budget_max'],
                    'status' => $item['status'],
                    'start_date' => $item['start_date'],
                    'end_date' => $item['end_date'],
                    'notes' => $item['notes'],
                ]
            );

            foreach ($item['members'] as $m) {
                $memberUser = $users[$m['email']] ?? null;
                if ($memberUser) {
                    CollaborationMember::updateOrCreate(
                        [
                            'collaboration_id' => $collab->id,
                            'user_id' => $memberUser->id,
                        ],
                        [
                            'role' => $m['role'],
                            'status' => $m['status'],
                            'joined_at' => $m['status'] === 'active' ? now() : null,
                        ]
                    );
                }
            }
        }
    }
}
