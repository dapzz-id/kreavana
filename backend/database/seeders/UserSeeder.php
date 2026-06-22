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
                'role' => 'creator',
                'selected_pihak' => 'kreator',
                'is_creator_approved' => 1,
            ]
        );

        // 2. Demo User
        User::updateOrCreate(
            ['email' => 'demo@kreavana.id'],
            [
                'name' => 'Demo User',
                'username' => 'demo',
                'password' => Hash::make('password123'),
                'role' => 'user',
                'selected_pihak' => 'kreator',
                'is_creator_approved' => 0,
            ]
        );

        // 3. Demo Creator
        User::updateOrCreate(
            ['email' => 'creator@kreavana.id'],
            [
                'name' => 'Demo Creator',
                'username' => 'creator',
                'password' => Hash::make('password123'),
                'role' => 'creator',
                'selected_pihak' => 'eo',
                'is_creator_approved' => 1,
            ]
        );
    }
}
