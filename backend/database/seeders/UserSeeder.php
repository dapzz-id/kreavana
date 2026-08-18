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
                'password' => Hash::make('password123'),
                'role' => RoleType::Admin,
                'is_creator_approved' => 0,
            ]
        );

        // 2. Client Kreavana (UMKM)
        User::updateOrCreate(
            ['email' => 'client@kreavana.id'],
            [
                'name' => 'Kreavana Demo Client',
                'username' => 'client_demo',
                'password' => Hash::make('password123'),
                'role' => RoleType::User,
                'is_creator_approved' => 0,
            ]
        );

        // 3. 11 Creators
        $creators = [
            [
                'sub_role' => CreatorSubRole::INSTITUTION,
                'name' => 'Kreavana Demo Institution',
                'email' => 'institution@kreavana.id',
                'username' => 'institution_demo',
            ],
            [
                'sub_role' => CreatorSubRole::GOVERNMENT,
                'name' => 'Kreavana Demo Government',
                'email' => 'government@kreavana.id',
                'username' => 'government_demo',
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
        ];

        foreach ($creators as $data) {
            $creator = User::updateOrCreate(
                ['email' => $data['email']],
                [
                    'name' => $data['name'],
                    'username' => $data['username'],
                    'password' => Hash::make('password123'),
                    'role' => RoleType::Creator,
                    'sub_role' => $data['sub_role']->value,
                    'is_creator_approved' => 1,
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
        }
    }
}
