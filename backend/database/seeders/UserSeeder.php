<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\UserSubRole;
use Illuminate\Support\Facades\Hash;
use App\Enums\RoleType;
use App\Enums\CreatorSubRole;

class UserSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Admin Kreavana
        User::updateOrCreate(
            ['email' => 'admin@kreavana.id'],
            [
                'name' => 'Admin Kreavana',
                'username' => 'admin',
                'role' => RoleType::Admin,
                'is_creator_approved' => 0,
                'email_verified_at' => now(),
            ]
        );

        // 2. Client Kreavana (UMKM)
        $client = User::where('email', 'client@kreavana.id')->first();
        if (!$client) {
            $client = User::create([
                'name' => 'Kreavana Demo Client',
                'username' => 'client_demo',
                'email' => 'client@kreavana.id',
                'role' => RoleType::User,
                'is_creator_approved' => 0,
                'email_verified_at' => now(),
                'balance' => 0.00,
                'wallet_pin' => \Illuminate\Support\Facades\Hash::make('123456'),
            ]);
        } else {
            $client->update([
                'name' => 'Kreavana Demo Client',
                'username' => 'client_demo',
                'role' => RoleType::User,
                'is_creator_approved' => 0,
                'email_verified_at' => now(),
                'wallet_pin' => $client->wallet_pin ?: \Illuminate\Support\Facades\Hash::make('123456'),
            ]);
        }

        \App\Models\Subscription::updateOrCreate(
            [
                'user_id' => $client->id,
                'tier' => 'pro',
            ],
            [
                'price_paid' => 199999,
                'auto_renew' => true,
                'expires_at' => now()->addYear(),
            ]
        );

        // 2.5 Corporate
        $corp = User::updateOrCreate(
            ['email' => 'corporate@kreavana.id'],
            [
                'name' => 'PT Kreavana Nusantara Korporat',
                'username' => 'corporate_demo',
                'role' => RoleType::User,
                'sub_role' => 'corporate',
                'is_creator_approved' => 0,
                'email_verified_at' => now(),
            ]
        );
        UserSubRole::updateOrCreate(
            [
                'user_id' => $corp->id,
                'sub_role_slug' => 'corporate',
            ],
            [
                'role_type' => RoleType::User->value,
                'is_active' => true,
            ]
        );

        // 2.8 Creator Biasa / Umum (Tanpa Sub-Role)
        $creatorDemo = User::where('email', 'creator@kreavana.id')->first();
        if (!$creatorDemo) {
            User::create([
                'email' => 'creator@kreavana.id',
                'name' => 'Kreavana Demo Creator',
                'username' => 'creator_demo',
                'role' => RoleType::Creator,
                'sub_role' => null,
                'is_creator_approved' => 1,
                'is_verified' => 1,
                'verification_type' => 'creator',
                'max_work_capacity' => 3,
                'balance' => 0.00,
                'email_verified_at' => now(),
            ]);
        } else {
            $creatorDemo->update([
                'name' => 'Kreavana Demo Creator',
                'username' => 'creator_demo',
                'role' => RoleType::Creator,
                'sub_role' => null,
                'is_creator_approved' => 1,
                'is_verified' => 1,
                'verification_type' => 'creator',
                'max_work_capacity' => 3,
                'email_verified_at' => now(),
            ]);
        }

        // 3. 11 Creators
        $creators = [
            [
                'sub_role' => CreatorSubRole::INSTITUTION,
                'name' => 'Kreavana Demo Institution',
                'email' => 'institution@kreavana.id',
                'username' => 'institution_demo',
            ],
            [
                'sub_role' => CreatorSubRole::INSTITUTION,
                'name' => 'SMK Negeri 1 Kreasi Nusantara',
                'email' => 'smk@kreavana.id',
                'username' => 'smk_demo',
            ],
            [
                'sub_role' => CreatorSubRole::INSTITUTION,
                'name' => 'SMK Kreatif Nusantara',
                'email' => 'sekolah@kreavana.id',
                'username' => 'sekolah_demo',
            ],
            [
                'sub_role' => CreatorSubRole::GOVERNMENT,
                'name' => 'Kreavana Demo Government',
                'email' => 'government@kreavana.id',
                'username' => 'government_demo',
            ],
            [
                'sub_role' => CreatorSubRole::TALENT,
                'name' => 'Kreavana Demo Talent',
                'email' => 'talent@kreavana.id',
                'username' => 'talent_demo',
            ],
            [
                'sub_role' => CreatorSubRole::MC,
                'name' => 'Kreavana Demo MC',
                'email' => 'mc@kreavana.id',
                'username' => 'mc_demo',
            ],
            [
                'sub_role' => CreatorSubRole::SINGER,
                'name' => 'Kreavana Demo Singer',
                'email' => 'singer@kreavana.id',
                'username' => 'singer_demo',
            ],
            [
                'sub_role' => CreatorSubRole::WEDDING_ORGANIZER,
                'name' => 'Kreavana Demo Wedding Organizer',
                'email' => 'wedding.organizer@kreavana.id',
                'username' => 'wedding_organizer_demo',
            ],
            [
                'sub_role' => CreatorSubRole::EVENT_ORGANIZER,
                'name' => 'Kreavana Demo Event Organizer',
                'email' => 'event.organizer@kreavana.id',
                'username' => 'event_organizer_demo',
            ],
            [
                'sub_role' => CreatorSubRole::EVENT_ORGANIZER,
                'name' => 'Kreavana Demo Event Organizer',
                'email' => 'eo@kreavana.id',
                'username' => 'eo_demo',
            ],
            [
                'sub_role' => CreatorSubRole::COMMUNITY,
                'name' => 'Kreavana Demo Community',
                'email' => 'community@kreavana.id',
                'username' => 'community_demo',
            ],
            [
                'sub_role' => CreatorSubRole::MAKEUP_ARTIST,
                'name' => 'Kreavana Demo Makeup Artist',
                'email' => 'makeup.artist@kreavana.id',
                'username' => 'makeup_artist_demo',
            ],
            [
                'sub_role' => CreatorSubRole::PHOTOGRAPHER,
                'name' => 'Kreavana Demo Photographer',
                'email' => 'photographer@kreavana.id',
                'username' => 'photographer_demo',
            ],
            [
                'sub_role' => CreatorSubRole::EDITOR,
                'name' => 'Kreavana Demo Editor',
                'email' => 'editor@kreavana.id',
                'username' => 'editor_demo',
            ],
            [
                'sub_role' => CreatorSubRole::VIDEOGRAPHER,
                'name' => 'Kreavana Demo Videographer',
                'email' => 'videographer@kreavana.id',
                'username' => 'videographer_demo',
            ],
            // 4. Kolaborasi Partner Creators (Akun Nyata Kreavana)
            [
                'sub_role' => CreatorSubRole::VIDEOGRAPHER,
                'name' => 'Dimas Arya',
                'email' => 'dimas.arya@kreavana.id',
                'username' => 'dimas_arya',
            ],
            [
                'sub_role' => CreatorSubRole::EDITOR,
                'name' => 'Sarah Putri',
                'email' => 'sarah.putri@kreavana.id',
                'username' => 'sarah_putri',
            ],
            [
                'sub_role' => CreatorSubRole::PHOTOGRAPHER,
                'name' => 'Kevin Jonathan',
                'email' => 'kevin.jonathan@kreavana.id',
                'username' => 'kevin_jonathan',
            ],
            [
                'sub_role' => CreatorSubRole::SINGER,
                'name' => 'Aditya Pratama',
                'email' => 'aditya.pratama@kreavana.id',
                'username' => 'aditya_pratama',
            ],
            [
                'sub_role' => CreatorSubRole::COMMUNITY,
                'name' => 'Nabila Zahra',
                'email' => 'nabila.zahra@kreavana.id',
                'username' => 'nabila_zahra',
            ],
            // 5. Role 3: Vendor & Penyedia Jasa Pendukung
            [
                'sub_role' => CreatorSubRole::VENDOR,
                'name' => 'Kreavana Demo Vendor & Penyedia Jasa',
                'email' => 'vendor@kreavana.id',
                'username' => 'vendor_demo',
            ],
            [
                'sub_role' => CreatorSubRole::MITRA_PENDUKUNG,
                'name' => 'Kreavana Demo Mitra Jasa Pendukung',
                'email' => 'mitra@kreavana.id',
                'username' => 'mitra_demo',
            ],
        ];

        $capacities = [
            CreatorSubRole::PHOTOGRAPHER->value => 3,
            CreatorSubRole::VIDEOGRAPHER->value => 2,
            CreatorSubRole::EDITOR->value => 5,
            CreatorSubRole::MAKEUP_ARTIST->value => 3,
            CreatorSubRole::MC->value => 4,
            CreatorSubRole::SINGER->value => 3,
            CreatorSubRole::WEDDING_ORGANIZER->value => 2,
            CreatorSubRole::EVENT_ORGANIZER->value => 2,
            CreatorSubRole::COMMUNITY->value => 5,
            CreatorSubRole::INSTITUTION->value => 5,
            CreatorSubRole::GOVERNMENT->value => 5,
            CreatorSubRole::VENDOR->value => 10,
            CreatorSubRole::MITRA_PENDUKUNG->value => 8,
        ];

        foreach ($creators as $data) {
            $creator = User::updateOrCreate(
                ['email' => $data['email']],
                [
                    'name' => $data['name'],
                    'username' => $data['username'],
                    'role' => RoleType::Creator,
                    'sub_role' => $data['sub_role']->value,
                    'is_creator_approved' => 1,
                    'max_work_capacity' => $capacities[$data['sub_role']->value] ?? 3,
                    'email_verified_at' => now(),
                ]
            );

            UserSubRole::updateOrCreate(
                [
                    'user_id' => $creator->id,
                    'sub_role_slug' => $data['sub_role']->value,
                ],
                [
                    'role_type' => RoleType::Creator->value,
                    'is_active' => true,
                ]
            );

            $defaultCity = match($data['sub_role']) {
                CreatorSubRole::WEDDING_ORGANIZER => 'Kota Bekasi',
                CreatorSubRole::MAKEUP_ARTIST => 'Kota Bekasi',
                CreatorSubRole::SINGER => 'Kota Bekasi',
                CreatorSubRole::VIDEOGRAPHER => 'Kota Bekasi',
                CreatorSubRole::PHOTOGRAPHER => 'Jakarta Pusat',
                CreatorSubRole::EVENT_ORGANIZER => 'Jakarta Selatan',
                CreatorSubRole::MC => 'Jakarta Selatan',
                CreatorSubRole::EDITOR => 'Jakarta Selatan',
                CreatorSubRole::COMMUNITY => 'Jakarta Pusat',
                default => 'Kota Bekasi',
            };
            $defaultProvince = ($defaultCity === 'Kota Bekasi') ? 'Jawa Barat' : 'DKI Jakarta';

            \App\Models\UserAddress::updateOrCreate(
                ['user_id' => $creator->id, 'is_default' => true],
                [
                    'label' => 'Kantor / Studio Utama',
                    'recipient_name' => $creator->name,
                    'phone' => '0812' . rand(10000000, 99999999),
                    'address' => 'Jl. Kreatif No. ' . rand(1, 99),
                    'city' => $defaultCity,
                    'province' => $defaultProvince,
                    'postal_code' => '17144',
                ]
            );
            if ($creator->username === 'event_organizer_demo' || $creator->username === 'eo_demo') {
                if (empty($creator->wallet_pin)) {
                    $creator->wallet_pin = Hash::make('123456');
                    $creator->save();
                }

                \App\Models\Subscription::updateOrCreate(
                    [
                        'user_id' => $creator->id,
                        'tier' => 'pro',
                    ],
                    [
                        'price_paid' => 199999,
                        'auto_renew' => true,
                        'expires_at' => now()->addYear(),
                    ]
                );
            }
        }
    }
}
