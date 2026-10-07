<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use App\Models\CommunityActivity;
use App\Models\User;
use Illuminate\Support\Str;

class CommunityActivitySeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Get a community user as community_id
        $communityUser = User::where('sub_role', 'community')->first();

        if (!$communityUser) {
            $this->command->warn('No community user found. Skipping seeder.');
            return;
        }

        $activities = [
            [
                'title' => 'Hunting Fotografi Landscape',
                'description' => 'Kegiatan hunting landscape di area puncak bersama komunitas. Wajib membawa kamera dan tripod.',
                'activity_date' => now()->addDays(3),
                'location' => 'Puncak, Bogor',
                'status' => 'active',
                'max_participants' => 20,
            ],
            [
                'title' => 'Workshop Color Grading Sinematik',
                'description' => 'Belajar teknik color grading sinematik menggunakan DaVinci Resolve untuk video komunitas.',
                'activity_date' => now()->addDays(7),
                'location' => 'Studio Kreavana, Jakarta',
                'status' => 'pending',
                'max_participants' => 15,
            ],
            [
                'title' => 'Pameran Foto Anggota',
                'description' => 'Pameran karya terbaik anggota komunitas bulan ini. Tema: Street Photography.',
                'activity_date' => now()->addDays(10),
                'location' => 'Galeri Seni, Bandung',
                'status' => 'active',
                'max_participants' => 30,
            ],
            [
                'title' => 'Meet & Shoot Portrait Session',
                'description' => 'Sesi foto portrait bersama model profesional. Pembagian lighting setup dan tips posing.',
                'activity_date' => now()->addDays(14),
                'location' => 'Urban Park, Jakarta Selatan',
                'status' => 'pending',
                'max_participants' => 25,
            ],
            [
                'title' => 'Trip Fotografi Desa Tradisional',
                'description' => 'Dokumentasi kehidupan desa tradisional dan budaya lokal. Durasi 2 hari 1 malam.',
                'activity_date' => now()->addDays(21),
                'location' => 'Desa Adat, Yogyakarta',
                'status' => 'active',
                'max_participants' => 12,
            ],
        ];

        foreach ($activities as $activity) {
            CommunityActivity::create([
                'id' => Str::uuid(),
                'community_id' => $communityUser->id,
                'title' => $activity['title'],
                'description' => $activity['description'],
                'activity_date' => $activity['activity_date'],
                'location' => $activity['location'],
                'status' => $activity['status'],
                'max_participants' => $activity['max_participants'],
                'created_by' => $communityUser->id,
            ]);
        }

        $this->command->info('Community activities seeded successfully.');
    }
}
