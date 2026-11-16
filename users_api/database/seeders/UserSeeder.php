<?php

namespace Database\Seeders;

use App\Models\User;
use App\Models\UserCredential;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class UserSeeder extends Seeder
{
    public function run(): void
    {
        $defaultPasswordHash = Hash::make('password123');

        $users = [
            // 1. Admin
            [
                'email' => 'admin@kreavana.id',
                'username' => 'admin',
                'full_name' => 'Admin Kreavana',
                'display_name' => 'Admin Kreavana',
            ],
            // 2. Client (UMKM)
            [
                'email' => 'client@kreavana.id',
                'username' => 'client_demo',
                'full_name' => 'Kreavana Demo Client',
                'display_name' => 'Demo Client',
            ],
            // 3. Corporate
            [
                'email' => 'corporate@kreavana.id',
                'username' => 'corporate_demo',
                'full_name' => 'Transforma Alam',
                'display_name' => 'Transforma Alam',
            ],
            // 4. Creator Biasa
            [
                'email' => 'creator@kreavana.id',
                'username' => 'creator_demo',
                'full_name' => 'Kreavana Demo Creator',
                'display_name' => 'Demo Creator',
            ],
            // 5. 11 Creators
            [
                'email' => 'institution@kreavana.id',
                'username' => 'institution_demo',
                'full_name' => 'Institut Seni & Rekayasa Kreatif Nusantara (ISRK)',
                'display_name' => 'Demo Institusi / Kampus',
            ],
            [
                'email' => 'smk@kreavana.id',
                'username' => 'smk_demo',
                'full_name' => 'SMK Negeri 1 Kreasi Nusantara',
                'display_name' => 'Demo SMK',
            ],
            [
                'email' => 'sekolah@kreavana.id',
                'username' => 'sekolah_demo',
                'full_name' => 'SMK Kreatif Nusantara',
                'display_name' => 'Demo Sekolah',
            ],
            [
                'email' => 'government@kreavana.id',
                'username' => 'government_demo',
                'full_name' => 'Kreavana Demo Government',
                'display_name' => 'Demo Government',
            ],
            [
                'email' => 'talent@kreavana.id',
                'username' => 'talent_demo',
                'full_name' => 'Kreavana Demo Talent',
                'display_name' => 'Demo Talent',
            ],
            [
                'email' => 'mc@kreavana.id',
                'username' => 'mc_demo',
                'full_name' => 'Kreavana Demo MC',
                'display_name' => 'Demo MC',
            ],
            [
                'email' => 'singer@kreavana.id',
                'username' => 'singer_demo',
                'full_name' => 'Kreavana Demo Singer',
                'display_name' => 'Demo Singer',
            ],
            [
                'email' => 'wedding.organizer@kreavana.id',
                'username' => 'wedding_organizer_demo',
                'full_name' => 'Kreavana Demo Wedding Organizer',
                'display_name' => 'Demo WO',
            ],
            [
                'email' => 'event.organizer@kreavana.id',
                'username' => 'event_organizer_demo',
                'full_name' => 'Kreavana Demo Event Organizer',
                'display_name' => 'Demo EO',
            ],
            [
                'email' => 'eo@kreavana.id',
                'username' => 'eo_demo',
                'full_name' => 'Kreavana Demo Event Organizer',
                'display_name' => 'Demo EO',
            ],
            [
                'email' => 'sari@test.com',
                'username' => 'sarieo',
                'full_name' => 'Sari Event Organizer',
                'display_name' => 'Sari EO',
            ],
            [
                'email' => 'community@kreavana.id',
                'username' => 'community_demo',
                'full_name' => 'Kreavana Demo Community',
                'display_name' => 'Demo Community',
            ],
            [
                'email' => 'makeup.artist@kreavana.id',
                'username' => 'makeup_artist_demo',
                'full_name' => 'Kreavana Demo Makeup Artist',
                'display_name' => 'Demo MUA',
            ],
            [
                'email' => 'photographer@kreavana.id',
                'username' => 'photographer_demo',
                'full_name' => 'Kreavana Demo Photographer',
                'display_name' => 'Demo Photographer',
            ],
            [
                'email' => 'editor@kreavana.id',
                'username' => 'editor_demo',
                'full_name' => 'Kreavana Demo Editor',
                'display_name' => 'Demo Editor',
            ],
            [
                'email' => 'videographer@kreavana.id',
                'username' => 'videographer_demo',
                'full_name' => 'Kreavana Demo Videographer',
                'display_name' => 'Demo Videographer',
            ],
            // 6. Partner Creators
            [
                'email' => 'dimas.arya@kreavana.id',
                'username' => 'dimas_arya',
                'full_name' => 'Dimas Arya',
                'display_name' => 'Dimas Arya',
            ],
            [
                'email' => 'sarah.putri@kreavana.id',
                'username' => 'sarah_putri',
                'full_name' => 'Sarah Putri',
                'display_name' => 'Sarah Putri',
            ],
            [
                'email' => 'kevin.jonathan@kreavana.id',
                'username' => 'kevin_jonathan',
                'full_name' => 'Kevin Jonathan',
                'display_name' => 'Kevin Jonathan',
            ],
            [
                'email' => 'aditya.pratama@kreavana.id',
                'username' => 'aditya_pratama',
                'full_name' => 'Aditya Pratama',
                'display_name' => 'Aditya Pratama',
            ],
            [
                'email' => 'nabila.zahra@kreavana.id',
                'username' => 'nabila_zahra',
                'full_name' => 'Nabila Zahra',
                'display_name' => 'Nabila Zahra',
            ],
            // 7. Vendors & Mitra
            [
                'email' => 'vendor@kreavana.id',
                'username' => 'vendor_demo',
                'full_name' => 'Kreavana Demo Vendor & Penyedia Jasa',
                'display_name' => 'Demo Vendor',
            ],
            [
                'email' => 'mitra@kreavana.id',
                'username' => 'mitra_demo',
                'full_name' => 'Kreavana Demo Mitra Jasa Pendukung',
                'display_name' => 'Demo Mitra',
            ],
        ];

        foreach ($users as $data) {
            $user = User::firstOrCreate(
                ['email' => $data['email']],
                [
                    'username' => $data['username'],
                    'full_name' => $data['full_name'],
                    'display_name' => $data['display_name'],
                    'is_active' => true,
                    'is_suspended' => false,
                    'locale' => 'id',
                    'timezone' => 'Asia/Jakarta',
                    'last_login_at' => now(),
                ]
            );

            UserCredential::firstOrCreate(
                ['user_id' => $user->id],
                [
                    'password_hash' => $defaultPasswordHash,
                    'is_email_verified' => true,
                    'email_verified_at' => now(),
                    'password_changed_at' => now(),
                ]
            );
        }
    }
}
