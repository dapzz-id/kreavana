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
        $client = User::where('email', 'budi@test.com')
            ->orWhere('username', 'budisantoso')
            ->first();

        if (!$client) {
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
        }

        $creators = [];
        $creatorData = [
            [
                'name' => 'Maya Wedding',
                'username' => 'mayawedding',
                'email' => 'maya@test.com',
                'sub_role' => 'wedding_organizer',
                'avatar_url' => 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
                'city' => 'Jakarta Selatan',
                'services' => [
                    [
                        'title' => 'Paket Intimate Wedding',
                        'category' => 'Event',
                        'price' => 8000000,
                        'duration' => '1 bulan',
                        'thumbnail_url' => 'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=1200&q=80',
                    ],
                    [
                        'title' => 'Full Wedding Organizer & Reception',
                        'category' => 'Event',
                        'price' => 18000000,
                        'duration' => '2 bulan',
                        'thumbnail_url' => 'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?auto=format&fit=crop&w=1200&q=80',
                    ],
                ],
                'portfolios' => [
                    [
                        'title' => 'Rustic Botanical Wedding Bali',
                        'category' => 'Wedding',
                        'image_url' => 'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=1200&q=80',
                    ],
                    [
                        'title' => 'Grand Ballroom Glamour Wedding',
                        'category' => 'Wedding',
                        'image_url' => 'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?auto=format&fit=crop&w=1200&q=80',
                    ],
                ],
            ],
            [
                'name' => 'Andi Editor Pro',
                'username' => 'andieditor',
                'email' => 'andi@test.com',
                'sub_role' => 'editor',
                'avatar_url' => 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
                'city' => 'Bandung',
                'services' => [
                    [
                        'title' => 'Editing Video Social Media (Reels/TikTok)',
                        'category' => 'Videografi',
                        'price' => 500000,
                        'duration' => '2 hari',
                        'thumbnail_url' => 'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?auto=format&fit=crop&w=1200&q=80',
                    ],
                    [
                        'title' => 'Color Grading & Cinematic Post Production',
                        'category' => 'Videografi',
                        'price' => 1800000,
                        'duration' => '4 hari',
                        'thumbnail_url' => 'https://images.unsplash.com/photo-1536240478700-b869070f9279?auto=format&fit=crop&w=1200&q=80',
                    ],
                ],
                'portfolios' => [
                    [
                        'title' => 'Cinematic Travel Vlog Color Grade',
                        'category' => 'Color Grading',
                        'image_url' => 'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?auto=format&fit=crop&w=1200&q=80',
                    ],
                    [
                        'title' => 'Commercial Brand Reel Premiere Pro',
                        'category' => 'Motion & Edit',
                        'image_url' => 'https://images.unsplash.com/photo-1536240478700-b869070f9279?auto=format&fit=crop&w=1200&q=80',
                    ],
                ],
            ],
            [
                'name' => 'Rina Photography',
                'username' => 'rinaphoto',
                'email' => 'rina@test.com',
                'sub_role' => 'photographer',
                'avatar_url' => 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=400&q=80',
                'city' => 'Yogyakarta',
                'services' => [
                    [
                        'title' => 'Paket Foto Produk & Katalog Komersil',
                        'category' => 'Fotografi',
                        'price' => 1500000,
                        'duration' => '3 hari',
                        'thumbnail_url' => 'https://images.unsplash.com/photo-1542038784456-1ea8e935640e?auto=format&fit=crop&w=1200&q=80',
                    ],
                    [
                        'title' => 'Studio Portrait & Fashion Editorial',
                        'category' => 'Fotografi',
                        'price' => 3200000,
                        'duration' => '5 hari',
                        'thumbnail_url' => 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=1200&q=80',
                    ],
                ],
                'portfolios' => [
                    [
                        'title' => 'Editorial Studio Portrait Series',
                        'category' => 'Commercial Photography',
                        'image_url' => 'https://images.unsplash.com/photo-1542038784456-1ea8e935640e?auto=format&fit=crop&w=1200&q=80',
                    ],
                    [
                        'title' => 'Fashion Lookbook Minimalist',
                        'category' => 'Fashion',
                        'image_url' => 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=1200&q=80',
                    ],
                ],
            ],
            [
                'name' => 'Dwiki Videography',
                'username' => 'dwikivideo',
                'email' => 'dwiki@test.com',
                'sub_role' => 'videographer',
                'avatar_url' => 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
                'city' => 'Surabaya',
                'services' => [
                    [
                        'title' => 'Video Iklan Sinematik & Company Profile',
                        'category' => 'Videografi',
                        'price' => 3000000,
                        'duration' => '7 hari',
                        'thumbnail_url' => 'https://images.unsplash.com/photo-1518133910546-b6c2fb7d79e3?auto=format&fit=crop&w=1200&q=80',
                    ],
                    [
                        'title' => 'Aerial Drone 4K Cinematography',
                        'category' => 'Videografi',
                        'price' => 4500000,
                        'duration' => '5 hari',
                        'thumbnail_url' => 'https://images.unsplash.com/photo-1508614589041-895b88991e3e?auto=format&fit=crop&w=1200&q=80',
                    ],
                ],
                'portfolios' => [
                    [
                        'title' => 'Automotive Brand Commercial 4K',
                        'category' => 'Commercial Video',
                        'image_url' => 'https://images.unsplash.com/photo-1518133910546-b6c2fb7d79e3?auto=format&fit=crop&w=1200&q=80',
                    ],
                    [
                        'title' => 'Aerial Coastline Drone Shot',
                        'category' => 'Aerial Video',
                        'image_url' => 'https://images.unsplash.com/photo-1508614589041-895b88991e3e?auto=format&fit=crop&w=1200&q=80',
                    ],
                ],
            ],
            [
                'name' => 'Sari Event Organizer',
                'username' => 'sarieo',
                'email' => 'sari@test.com',
                'sub_role' => 'event_organizer',
                'avatar_url' => 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=400&q=80',
                'city' => 'Jakarta Pusat',
                'services' => [
                    [
                        'title' => 'Paket Event Organizer & Gala Dinner',
                        'category' => 'Event',
                        'price' => 20000000,
                        'duration' => '1 bulan',
                        'thumbnail_url' => 'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?auto=format&fit=crop&w=1200&q=80',
                    ],
                    [
                        'title' => 'International Conference & Expo Production',
                        'category' => 'Event',
                        'price' => 35000000,
                        'duration' => '2 bulan',
                        'thumbnail_url' => 'https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?auto=format&fit=crop&w=1200&q=80',
                    ],
                ],
                'portfolios' => [
                    [
                        'title' => 'Tech Summit 2026 Grand Stage',
                        'category' => 'Conference Production',
                        'image_url' => 'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?auto=format&fit=crop&w=1200&q=80',
                    ],
                    [
                        'title' => 'Corporate Anniversary Celebration',
                        'category' => 'Corporate Event',
                        'image_url' => 'https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?auto=format&fit=crop&w=1200&q=80',
                    ],
                ],
            ],
        ];

        foreach ($creatorData as $data) {
            $user = User::where('email', $data['email'])
                ->orWhere('username', $data['username'])
                ->first();

            if (!$user) {
                $user = User::create([
                    'name' => $data['name'],
                    'username' => $data['username'],
                    'email' => $data['email'],
                    'password' => Hash::make('password'),
                    'role' => \App\Enums\RoleType::Creator,
                    'sub_role' => $data['sub_role'],
                    'is_creator_approved' => true,
                    'avatar_url' => $data['avatar_url'],
                    'balance' => fake()->randomFloat(2, 100000, 5000000),
                ]);
            } else {
                $user->update([
                    'name' => $data['name'],
                    'sub_role' => $data['sub_role'],
                    'is_creator_approved' => true,
                    'avatar_url' => $data['avatar_url'],
                ]);
            }

            // Ensure address
            \App\Models\UserAddress::updateOrCreate(
                [
                    'user_id' => $user->id,
                    'is_default' => true,
                ],
                [
                    'label' => 'Studio Utama',
                    'recipient_name' => $data['name'],
                    'phone' => '0812' . rand(10000000, 99999999),
                    'address' => 'Jl. Kreatif No. ' . rand(1, 99),
                    'city' => $data['city'],
                    'province' => 'Indonesia',
                    'postal_code' => '12345',
                ]
            );

            // Ensure creator services with thumbnails
            foreach ($data['services'] as $svc) {
                \App\Models\CreatorService::updateOrCreate(
                    [
                        'creator_id' => $user->id,
                        'title' => $svc['title'],
                    ],
                    [
                        'description' => 'Layanan resmi berkualitas tinggi oleh ' . $data['name'],
                        'category' => $svc['category'],
                        'price' => $svc['price'],
                        'duration_info' => $svc['duration'],
                        'thumbnail_url' => $svc['thumbnail_url'],
                        'status' => 'active',
                    ]
                );
            }

            // Ensure portfolio items with photos
            foreach ($data['portfolios'] as $pIdx => $port) {
                \App\Models\PortfolioItem::updateOrCreate(
                    [
                        'user_id' => $user->id,
                        'title' => $port['title'],
                    ],
                    [
                        'category' => $port['category'],
                        'description' => 'Karya portofolio terpilih dari ' . $data['name'],
                        'image_url' => $port['image_url'],
                        'sort_order' => $pIdx,
                        'event_date' => now()->subDays(rand(5, 60)),
                        'location' => $data['city'],
                        'verification_status' => 'verified',
                    ]
                );
            }

            $creators[] = $user;
        }

        // Only create mock opportunities and transactions if client doesn't have any yet
        if ($client->opportunities()->count() === 0) {
            Opportunity::factory()->count(5)->open()->forUser($client->id)->create();
            Opportunity::factory()->count(3)->closed()->forUser($client->id)->create();
        }

        if (WalletTransaction::where('user_id', $client->id)->count() === 0) {
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
        }

        if (Notification::where('user_id', $client->id)->count() === 0) {
            Notification::factory()
                ->count(5)
                ->forUser($client->id)
                ->create();
        }

        foreach (array_slice($creators, 0, 3) as $creator) {
            UserFollow::firstOrCreate([
                'follower_id' => $client->id,
                'following_id' => $creator->id,
            ], [
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
