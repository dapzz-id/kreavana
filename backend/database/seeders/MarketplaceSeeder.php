<?php

namespace Database\Seeders;

use App\Models\MarketplaceItem;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Seeder;

class MarketplaceSeeder extends Seeder
{
    public function run(): void
    {
        // Get various creator users or fallback to any users
        $creators = User::where('role', 'creator')->get();
        if ($creators->isEmpty()) {
            $creators = User::limit(10)->get();
        }
        if ($creators->isEmpty()) return;

        // Truncate or clean previous marketplace dummy items to avoid duplicates
        \Illuminate\Support\Facades\DB::statement('SET FOREIGN_KEY_CHECKS=0;');
        MarketplaceItem::truncate();
        \Illuminate\Support\Facades\DB::statement('SET FOREIGN_KEY_CHECKS=1;');

        $now = Carbon::now();

        $items = [
            // ─── VIDEOGRAFI ──────────────────────────────────────────────────────────
            [
                'title' => 'Cinematic LUTs Pro (Sony S-Log3, Canon C-Log & D-Log)',
                'description' => 'Paket 25+ profil color grading sinematik standar industri perfilman. Kompatibel dengan Premiere Pro, DaVinci Resolve, Final Cut Pro, dan CapCut Desktop.',
                'category' => 'Videografi',
                'price' => 225000,
                'rating' => 5.0,
                'orders' => 189,
                'reviews' => 120,
                'is_featured' => true,
                'created_at' => $now->copy()->subMinutes(10), // Paling Baru!
            ],
            [
                'title' => 'Template After Effects Video Opening YouTube & Podcast Modern',
                'description' => 'Template motion graphic opening intro & bumper beresolusi 4K 60fps dengan animasi tipografi bold, audio placeholder, dan kontrol warna dinamis.',
                'category' => 'Videografi',
                'price' => 350000,
                'rating' => 4.85,
                'orders' => 92,
                'reviews' => 56,
                'is_featured' => false,
                'created_at' => $now->copy()->subDays(1),
            ],
            [
                'title' => 'Jasa Video Profil Perusahaan & Liputan Event 4K Multicam',
                'description' => 'Produksi video korporat profesional lengkap dengan kru sinematografer, pilot drone bersertifikasi, rekaman audio wireless, dan pasca produksi colorist.',
                'category' => 'Videografi',
                'price' => 3500000, // Harga Tertinggi!
                'rating' => 4.90,
                'orders' => 18,
                'reviews' => 15,
                'is_featured' => true,
                'created_at' => $now->copy()->subDays(7),
            ],
            [
                'title' => 'Sound FX Pack & Transitions Bundle untuk Content Creator',
                'description' => 'Lebih dari 400+ efek suara Whoosh, Glitch, Cinematic Hit, Camera Click, dan Riser berlisensi bebas royalti untuk video pendek dan iklan.',
                'category' => 'Videografi',
                'price' => 49000, // Harga Terendah!
                'rating' => 4.60,
                'orders' => 65,
                'reviews' => 38,
                'is_featured' => false,
                'created_at' => $now->copy()->subDays(4),
            ],

            // ─── BRANDING ───────────────────────────────────────────────────────────
            [
                'title' => 'Brand Identity Guidelines & Logo Package Lengkap Vector',
                'description' => 'Panduan identitas merek komprehensif 40 halaman mencakup logo primer & sekunder, palet warna HEX/CMYK, aturan tipografi, dan mockup merchandise.',
                'category' => 'Branding',
                'price' => 850000,
                'rating' => 4.85,
                'orders' => 58,
                'reviews' => 36,
                'is_featured' => true,
                'created_at' => $now->copy()->subMinutes(25), // Sangat Baru!
            ],
            [
                'title' => 'Template Proposal Bisnis, Sponsorship & Otorisasi MoU B2B',
                'description' => 'Dokumen siap pakai berformat InDesign, Illustrator, dan Word untuk pengajuan tender, kemitraan sponsorship institusi, dan nota kesepahaman formal.',
                'category' => 'Branding',
                'price' => 175000,
                'rating' => 4.80,
                'orders' => 124, // Populer
                'reviews' => 77,
                'is_featured' => false,
                'created_at' => $now->copy()->subDays(5),
            ],
            [
                'title' => 'Paket Rebranding Menyeluruh Korporat & UKM (Logo + Stationery)',
                'description' => 'Transformasi citra merek profesional mulai dari riset kompetitor, 3 opsi konsep logo orisinal, kartu nama, kop surat, hingga template feed Instagram resmi.',
                'category' => 'Branding',
                'price' => 2900000, // Harga Sangat Tinggi
                'rating' => 4.70,
                'orders' => 8,
                'reviews' => 7,
                'is_featured' => false,
                'created_at' => $now->copy()->subWeeks(3),
            ],

            // ─── DESAIN ─────────────────────────────────────────────────────────────
            [
                'title' => 'Design System & Mobile App UI Kit Figma (iOS & Android)',
                'description' => 'Komponen UI terlengkap dengan 300+ screen e-commerce, fintech, dan SaaS. Menggunakan Auto-layout 5.0, variables token, dan mode Dark/Light terintegrasi.',
                'category' => 'Desain',
                'price' => 450000,
                'rating' => 4.92,
                'orders' => 112,
                'reviews' => 70,
                'is_featured' => true,
                'created_at' => $now->copy()->subMinutes(45), // Sangat Baru!
            ],
            [
                'title' => 'Template Pitch Deck Investor PowerPoint & Keynote 60+ Slides',
                'description' => 'Slide presentasi terstruktur standar Venture Capital: Problem, Solution, Market Size (TAM/SAM/SOM), Business Model, Traction, dan Financial Projections.',
                'category' => 'Desain',
                'price' => 125000,
                'rating' => 4.88,
                'orders' => 156, // Sangat Populer!
                'reviews' => 94,
                'is_featured' => true,
                'created_at' => $now->copy()->subDays(2),
            ],
            [
                'title' => 'Paket 200+ Template Canva Promosi Media Sosial & Stories',
                'description' => 'Koleksi layout estetis siap edit langsung di browser gratis Canva untuk promosi flash sale, testimoni pembeli, peluncuran produk, dan quotes motivasi.',
                'category' => 'Desain',
                'price' => 95000, // Harga Terjangkau
                'rating' => 4.65,
                'orders' => 85,
                'reviews' => 51,
                'is_featured' => false,
                'created_at' => $now->copy()->subDays(6),
            ],
            [
                'title' => 'Desain Maskot & Karakter 3D Ilustrasi Branding Eksklusif',
                'description' => 'Karakter maskot 3D custom dalam 15 pose ekspresif resolusi tinggi (transparan PNG + file blender/FBX) untuk maskot perusahaan atau aplikasi mobile.',
                'category' => 'Desain',
                'price' => 2400000, // Harga Tinggi
                'rating' => 4.80,
                'orders' => 12,
                'reviews' => 10,
                'is_featured' => false,
                'created_at' => $now->copy()->subWeeks(2),
            ],

            // ─── FOTOGRAFI ──────────────────────────────────────────────────────────
            [
                'title' => 'Lightroom Presets Wedding Warm & Cinematic Vol 1',
                'description' => '15 preset desktop (.xmp) dan mobile (.dng) dengan nuansa hangat keemasan yang menonjolkan skin tone alami pada foto pernikahan dan prewedding luar ruangan.',
                'category' => 'Fotografi',
                'price' => 150000,
                'rating' => 4.95,
                'orders' => 145, // Populer & Rating Tinggi!
                'reviews' => 88,
                'is_featured' => true,
                'created_at' => $now->copy()->subHours(2), // Baru!
            ],
            [
                'title' => 'Paket Foto Korporat & Headshot Eksekutif Premium',
                'description' => 'Sesi pemotretan profesional studio portabel di kantor klien dengan pencahayaan 3 titik, pengarahan gaya profesional, dan retouching detail majalah.',
                'category' => 'Fotografi',
                'price' => 1850000, // Harga Tinggi
                'rating' => 4.90,
                'orders' => 34,
                'reviews' => 22,
                'is_featured' => false,
                'created_at' => $now->copy()->subHours(6),
            ],
            [
                'title' => 'Koleksi 100+ Stock Photo Landscape & Budaya Indonesia HD',
                'description' => 'Kumpulan foto resolusi tinggi pemandangan alam Bromo, Raja Ampat, persawahan Bali, dan situs cagar budaya untuk materi promosi pariwisata dan website.',
                'category' => 'Fotografi',
                'price' => 75000, // Harga Murah
                'rating' => 4.70,
                'orders' => 78,
                'reviews' => 45,
                'is_featured' => false,
                'created_at' => $now->copy()->subDays(3),
            ],

            // ─── KONTEN ─────────────────────────────────────────────────────────────
            [
                'title' => 'Kalender Konten 365 Hari + Swipe File Copywriting Viral',
                'description' => 'Panduan ide konten harian selama 1 tahun penuh, lengkap dengan rumus copywriting AIDA/PAS, daftar call-to-action konversi tinggi, dan rekomendasi jam posting.',
                'category' => 'Konten',
                'price' => 199000,
                'rating' => 4.98, // Rating Hampir Sempurna!
                'orders' => 167, // Sangat Populer!
                'reviews' => 105,
                'is_featured' => true,
                'created_at' => $now->copy()->subHours(4),
            ],
            [
                'title' => 'Script Hook & Storytelling Framework Video TikTok/Reels',
                'description' => '50 naskah pembuka (hook) 3 detik pertama yang terbukti meningkatkan retensi audiens di algoritma TikTok, Instagram Reels, dan YouTube Shorts.',
                'category' => 'Konten',
                'price' => 85000, // Harga Murah
                'rating' => 4.75,
                'orders' => 73,
                'reviews' => 42,
                'is_featured' => false,
                'created_at' => $now->copy()->subDays(2),
            ],
            [
                'title' => 'Paket Konsultasi Strategi Digital Campaign & Content Audit',
                'description' => 'Sesi 1-on-1 audit mendalam akun media sosial bisnis, optimasi funnel pemasaran, dan penyusunan strategi konten berbasis data analitik selama 1 bulan.',
                'category' => 'Konten',
                'price' => 1500000, // Harga Menengah-Tinggi
                'rating' => 4.90,
                'orders' => 25,
                'reviews' => 20,
                'is_featured' => false,
                'created_at' => $now->copy()->subDays(10),
            ],
        ];

        foreach ($items as $i => $d) {
            $creator = $creators[$i % $creators->count()];
            MarketplaceItem::create([
                'user_id' => $creator->id,
                'title' => $d['title'],
                'description' => $d['description'],
                'category' => $d['category'],
                'type' => 'paid',
                'price' => $d['price'],
                'rating' => $d['rating'],
                'review_count' => $d['reviews'],
                'order_count' => $d['orders'],
                'is_featured' => $d['is_featured'],
                'is_active' => true,
                'status' => 'published',
                'created_at' => $d['created_at'],
                'updated_at' => $d['created_at'],
            ]);
        }
    }
}
