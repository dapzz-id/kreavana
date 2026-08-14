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
            ['title' => 'Paket Foto Produk Premium', 'cat' => 'Fotografi', 'price' => 1500000, 'rating' => 4.9, 'orders' => 48],
            ['title' => 'Video Profil Usaha 1 Menit', 'cat' => 'Videografi', 'price' => 3000000, 'rating' => 4.8, 'orders' => 32],
            ['title' => 'Paket Desain Logo & Branding', 'cat' => 'Desain', 'price' => 2000000, 'rating' => 4.9, 'orders' => 56],
            ['title' => 'Konten Sosial Media 30 Hari', 'cat' => 'Konten', 'price' => 4500000, 'rating' => 4.7, 'orders' => 21],
            ['title' => 'Brand Identity Lengkap', 'cat' => 'Branding', 'price' => 5000000, 'rating' => 4.6, 'orders' => 15],
            ['title' => 'Foto Produk UMKM', 'cat' => 'Fotografi', 'price' => 800000, 'rating' => 4.8, 'orders' => 67],
            ['title' => 'Video Tutorial YouTube', 'cat' => 'Videografi', 'price' => 2500000, 'rating' => 4.5, 'orders' => 12],
            ['title' => 'Desain Feed Instagram', 'cat' => 'Desain', 'price' => 1200000, 'rating' => 4.7, 'orders' => 89],
            ['title' => 'Copywriting Landing Page', 'cat' => 'Konten', 'price' => 1800000, 'rating' => 4.4, 'orders' => 23],
            ['title' => 'Rebranding Toko Online', 'cat' => 'Branding', 'price' => 3500000, 'rating' => 4.8, 'orders' => 9],
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
