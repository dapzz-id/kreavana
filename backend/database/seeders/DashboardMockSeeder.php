<?php

namespace Database\Seeders;

use App\Models\User;
use App\Models\Opportunity;
use App\Models\WalletTransaction;
use App\Models\Notification;
use App\Models\UserFollow;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DashboardMockSeeder extends Seeder
{
    public function run(): void
    {
        $client = User::create([
            'name' => 'Budi Santoso',
            'username' => 'budisantoso',
            'email' => 'budi@test.com',
            'password' => Hash::make('password'),
            'role' => \App\Enums\RoleType::User,
            'sub_role' => null,
            'is_creator_approved' => false,
            'balance' => 2500000,
        ]);

        $creators = [];
        $creatorData = [
            ['name' => 'Rina Photography', 'sub_role' => 'photographer'],
            ['name' => 'Dwiki Videography', 'sub_role' => 'videographer'],
            ['name' => 'Sari Event Organizer', 'sub_role' => 'event_organizer'],
            ['name' => 'Andi Editor Pro', 'sub_role' => 'editor'],
            ['name' => 'Maya Wedding', 'sub_role' => 'wedding_organizer'],
        ];

        foreach ($creatorData as $data) {
            $creators[] = User::create([
                'name' => $data['name'],
                'username' => fake()->unique()->userName(),
                'email' => fake()->unique()->safeEmail(),
                'password' => Hash::make('password'),
                'role' => \App\Enums\RoleType::Creator,
                'sub_role' => $data['sub_role'],
                'is_creator_approved' => true,
                'balance' => fake()->randomFloat(2, 100000, 5000000),
            ]);
        }

        Opportunity::factory()->count(5)->open()->forUser($client->id)->create();
        Opportunity::factory()->count(3)->closed()->forUser($client->id)->create();

        WalletTransaction::factory()
            ->count(8)
            ->completed()
            ->forUser($client->id)
            ->create();

        WalletTransaction::factory()
            ->count(2)
            ->pending()
            ->forUser($client->id)
            ->create();

        Notification::factory()
            ->count(5)
            ->forUser($client->id)
            ->create();

        foreach (array_slice($creators, 0, 3) as $creator) {
            UserFollow::create([
                'follower_id' => $client->id,
                'following_id' => $creator->id,
                'created_at' => now()->subDays(rand(1, 30)),
            ]);
        }

        $this->command->info("Dashboard mock data created:");
        $this->command->info("  - Client: {$client->name} ({$client->email})");
        $this->command->info("  - Password: password");
        $this->command->info("  - 5 open + 3 closed opportunities");
        $this->command->info("  - 8 completed + 2 pending transactions");
        $this->command->info("  - 5 notifications");
        $this->command->info("  - 3 followed creators");
        $this->command->info("  - " . count($creators) . " creators");
    }
}
