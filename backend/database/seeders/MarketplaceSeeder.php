<?php

namespace Database\Seeders;

use App\Models\MarketplaceItem;
use App\Models\User;
use Illuminate\Database\Seeder;

class MarketplaceSeeder extends Seeder
{
    public function run(): void
    {
        $users = User::limit(3)->get();
        if ($users->isEmpty()) return;

        $items = [
            ['title' => 'Lightroom Presets Wedding Vol 1', 'cat' => 'Fotografi', 'price' => 150000, 'rating' => 4.9, 'orders' => 48],
            ['title' => 'Template Notion Freelancer Dashboard', 'cat' => 'Desain', 'price' => 300000, 'rating' => 4.8, 'orders' => 32],
            ['title' => 'E-Book: Mastery Digital Marketing 2026', 'cat' => 'Konten', 'price' => 200000, 'rating' => 4.9, 'orders' => 56],
            ['title' => 'Bundle 50+ Social Media Templates Canva', 'cat' => 'Desain', 'price' => 450000, 'rating' => 4.7, 'orders' => 21],
            ['title' => 'Logo Asset & Icon Pack Minimalist', 'cat' => 'Desain', 'price' => 500000, 'rating' => 4.6, 'orders' => 15],
            ['title' => 'Cinematic LUTs for Premiere Pro', 'cat' => 'Videografi', 'price' => 800000, 'rating' => 4.8, 'orders' => 67],
            ['title' => 'Source Code E-Commerce Flutter App', 'cat' => 'Konten', 'price' => 2500000, 'rating' => 4.5, 'orders' => 12],
            ['title' => 'Pitch Deck Template Pro PowerPoint', 'cat' => 'Desain', 'price' => 120000, 'rating' => 4.7, 'orders' => 89],
            ['title' => 'Copywriting Prompts Swipe File', 'cat' => 'Konten', 'price' => 180000, 'rating' => 4.4, 'orders' => 23],
            ['title' => 'Brand Guideline Template PDF', 'cat' => 'Branding', 'price' => 350000, 'rating' => 4.8, 'orders' => 9],
        ];

        foreach ($items as $i => $d) {
            MarketplaceItem::create([
                'user_id' => $users[$i % $users->count()]->id,
                'title' => $d['title'],
                'description' => 'Deskripsi lengkap untuk ' . $d['title'] . '. Layanan berkualitas dari kreator terbaik.',
                'category' => $d['cat'],
                'price' => $d['price'],
                'rating' => $d['rating'],
                'review_count' => (int) ($d['orders'] * 0.6),
                'order_count' => $d['orders'],
                'is_featured' => $i < 4,
                'is_active' => true,
            ]);
        }
    }
}
