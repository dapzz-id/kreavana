<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\Opportunity;
use App\Models\OpportunityReview;
use App\Enums\RoleType;
use Illuminate\Support\Facades\Hash;
use Carbon\Carbon;

class ReviewSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Get or create demo creators to receive reviews
        $clientDemo = User::where('email', 'client@kreavana.id')->first();
        $admin = User::where('email', 'admin@kreavana.id')->first();
        $creators = User::where('role', RoleType::Creator->value)->get();

        if ($creators->isEmpty()) {
            $this->command?->warn('No creators found to seed reviews.');
            return;
        }

        $defaultPosterId = $clientDemo ? $clientDemo->id : ($admin ? $admin->id : $creators->first()->id);

        // 2. Definisi Reviewer dan Ulasannya
        $reviewData = [
            [
                'reviewer_name' => 'Budi Wicaksono',
                'reviewer_email' => 'budi.wicaksono@gojek.com',
                'reviewer_username' => 'budi_wicaksono',
                'reviewer_role' => 'Senior Marketing Lead',
                'reviewer_company' => 'PT Gojek Indonesia',
                'rating' => 5.0,
                'project_title' => 'Video Commercial Peluncuran Fitur Baru 2026',
                'category' => 'Video Commercial',
                'date' => '2026-09-14 10:30:00',
                'comment' => 'Pengerjaan sangat profesional! Angle video sinematik dan color grading pas banget dengan brand guideline kami. Komunikasi tim responsif, cepat tanggap terhadap revisi minor, dan penyerahan file master 2 hari lebih cepat dari deadline.',
                'helpful_count' => 12,
            ],
            [
                'reviewer_name' => 'Maya Anggraini',
                'reviewer_email' => 'maya.anggraini@botanica.id',
                'reviewer_username' => 'maya_anggraini',
                'reviewer_role' => 'Founder & CEO',
                'reviewer_company' => 'Botanica Skincare Organic',
                'rating' => 5.0,
                'project_title' => 'Fotografi Produk Komersial & Model Studio',
                'category' => 'Fotografi Komersial',
                'date' => '2026-09-02 14:15:00',
                'comment' => 'Kreator sangat memahami konsep visual clean and natural aesthetic. Penataan lighting di studio memukau dan retouching detailnya rapi. Konversi penjualan e-commerce kami naik 35% setelah pasang visual ini.',
                'helpful_count' => 8,
            ],
            [
                'reviewer_name' => 'Rian Pratama',
                'reviewer_email' => 'rian.pratama@nusantara.id',
                'reviewer_username' => 'rian_pratama',
                'reviewer_role' => 'Creative Director',
                'reviewer_company' => 'Nusantara Media Agency',
                'rating' => 4.8,
                'project_title' => 'Motion Graphics & 3D Bumper TVC',
                'category' => 'Motion & 3D Design',
                'date' => '2026-08-22 16:45:00',
                'comment' => 'Kerja sama lintas kota berjalan tanpa kendala. Asset 3D beresolusi tinggi, format file rapi, dan sinkronisasi audio sound design sangat punchy. Pasti akan kerja sama lagi di project mendatang.',
                'helpful_count' => 5,
            ],
            [
                'reviewer_name' => 'Citra Kirana',
                'reviewer_email' => 'citra.kirana@alana.id',
                'reviewer_username' => 'citra_kirana',
                'reviewer_role' => 'Managing Director',
                'reviewer_company' => 'Alana Wedding Organizer',
                'rating' => 5.0,
                'project_title' => 'Dokumentasi Foto & Highlight Cinematic Wedding',
                'category' => 'Wedding & Event',
                'date' => '2026-08-10 11:20:00',
                'comment' => 'Momen sakral akad dan kemeriahan resepsi tertangkap dengan penuh emosi. Kualitas video 4K jernih dan pilihan instrumen lagunya sangat menyentuh. Mempelai dan keluarga sangat puas!',
                'helpful_count' => 15,
            ],
            [
                'reviewer_name' => 'Hendro Santoso',
                'reviewer_email' => 'hendro.santoso@kintamani.id',
                'reviewer_username' => 'hendro_santoso',
                'reviewer_role' => 'Head of Brand Marketing',
                'reviewer_company' => 'Kopi Kintamani Roastery',
                'rating' => 4.7,
                'project_title' => 'Desain Identitas Kemasan Produk Ekspor',
                'category' => 'Branding & Packaging',
                'date' => '2026-07-28 09:10:00',
                'comment' => 'Konsep ilustrasi kemasan sangat berkarakter dan memiliki nilai filosofis lokal. File cetak lengkap dengan panduan warna CMYK dan spesifikasi bahan ramah lingkungan.',
                'helpful_count' => 4,
            ],
        ];

        foreach ($reviewData as $index => $item) {
            // A. Buat atau perbarui akun Reviewer di DB
            $reviewer = User::firstOrCreate(
                ['email' => $item['reviewer_email']],
                [
                    'name' => $item['reviewer_name'],
                    'username' => $item['reviewer_username'],
                    'password' => Hash::make('password123'),
                    'role' => RoleType::User->value,
                    'email_verified_at' => now(),
                    'is_creator_approved' => 0,
                ]
            );

            // B. Tentukan Kreator penerima ulasan
            $creator = $creators[$index % $creators->count()];

            // C. Buat atau cari Opportunity / Proyek terkait di DB
            $opportunity = Opportunity::firstOrCreate(
                ['title' => $item['project_title']],
                [
                    'description' => 'Proyek kolaborasi ' . $item['category'] . ' bersama ' . $item['reviewer_company'],
                    'type' => 'project',
                    'sub_role_slug' => 'kreator',
                    'location' => 'Jakarta',
                    'status' => 'closed',
                    'posted_by' => $defaultPosterId,
                    'created_at' => Carbon::parse($item['date'])->subDays(15),
                ]
            );

            // D. Buat / update OpportunityReview di DB
            OpportunityReview::updateOrCreate(
                [
                    'opportunity_id' => $opportunity->id,
                    'reviewer_id' => $reviewer->id,
                    'creator_id' => $creator->id,
                ],
                [
                    'rating' => $item['rating'],
                    'comment' => $item['comment'],
                    'helpful_count' => $item['helpful_count'],
                    'is_on_time' => true,
                    'delivery_days' => 2,
                    'created_at' => Carbon::parse($item['date']),
                    'updated_at' => Carbon::parse($item['date']),
                ]
            );
        }

        // Juga tambahkan 1 ulasan langsung dari Kreavana Demo Client jika ada
        if ($clientDemo && $creators->isNotEmpty()) {
            $clientCreator = $creators->first();
            $clientOpp = Opportunity::firstOrCreate(
                ['title' => 'Branding & Social Media Campaign Kreavana UMKM'],
                [
                    'description' => 'Kampanye media sosial dan peluncuran produk UMKM kreatif binaan Kreavana.',
                    'type' => 'project',
                    'sub_role_slug' => 'kreator',
                    'location' => 'Jakarta',
                    'status' => 'closed',
                    'posted_by' => $clientDemo->id,
                    'created_at' => Carbon::now()->subDays(20),
                ]
            );

            OpportunityReview::updateOrCreate(
                [
                    'opportunity_id' => $clientOpp->id,
                    'reviewer_id' => $clientDemo->id,
                    'creator_id' => $clientCreator->id,
                ],
                [
                    'rating' => 5.0,
                    'comment' => 'Kreator sangat profesional dan memahami kebutuhan bisnis kami dengan cepat. Hasil desain dan copywriting melampaui ekspektasi!',
                    'helpful_count' => 7,
                    'is_on_time' => true,
                    'delivery_days' => 1,
                    'created_at' => Carbon::now()->subDays(5),
                    'updated_at' => Carbon::now()->subDays(5),
                ]
            );
        }
    }
}
