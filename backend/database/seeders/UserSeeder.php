<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

class UserSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // 1. Admin Kreavana
        User::updateOrCreate(
            ['email' => 'admin@kreavana.id'],
            [
                'name' => 'Admin Kreavana',
                'username' => 'admin',
                'password' => Hash::make('password123'),
                'role' => 'admin',
                'selected_pihak' => 'kreator',
                'is_creator_approved' => 0,
            ]
        );

        // 2. User Kreavana
        User::updateOrCreate(
            ['email' => 'user@kreavana.id'],
            [
                'name' => 'User Kreavana',
                'username' => 'user',
                'password' => Hash::make('password123'),
                'role' => 'user',
                'selected_pihak' => 'kreator',
                'is_creator_approved' => 0,
            ]
        );

        // 3. Creator Kreavana
        User::updateOrCreate(
            ['email' => 'creator@kreavana.id'],
            [
                'name' => 'Creator Kreavana',
                'username' => 'creator',
                'password' => Hash::make('password123'),
                'role' => 'creator',
                'selected_pihak' => 'kreator',
                'is_creator_approved' => 1,
            ]
        );
    }
}
