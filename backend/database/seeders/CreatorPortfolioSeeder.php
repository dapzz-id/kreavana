<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Enums\RoleType;
use App\Enums\CreatorSubRole;
use App\Models\PortfolioItem;

class CreatorPortfolioSeeder extends Seeder
{
    public function run(): void
    {
        $creators = User::where('role', RoleType::Creator->value)->get();

        $portfolioData = [
            CreatorSubRole::INSTITUTION->value => [
                ['title' => 'Program Pemberdayaan UMKM', 'category' => 'Social Program', 'description' => 'Mendukung pertumbuhan bisnis lokal.'],
                ['title' => 'Kegiatan Pelatihan Digital', 'category' => 'Training', 'description' => 'Pelatihan digitalisasi untuk masyarakat.'],
            ],
            CreatorSubRole::GOVERNMENT->value => [
                ['title' => 'Dokumentasi Program Pemerintah Daerah', 'category' => 'Public Service', 'description' => 'Kegiatan dinas dan pencapaian daerah.'],
                ['title' => 'Kampanye Pelayanan Publik', 'category' => 'Campaign', 'description' => 'Kampanye kesadaran layanan masyarakat.'],
            ],
            CreatorSubRole::MC->value => [
                ['title' => 'MC Seminar Nasional', 'category' => 'Corporate', 'description' => 'Memandu acara berskala nasional.'],
                ['title' => 'MC Wedding Reception', 'category' => 'Wedding', 'description' => 'Pemandu acara resepsi pernikahan.'],
            ],
            CreatorSubRole::SINGER->value => [
                ['title' => 'Live Performance Wedding', 'category' => 'Wedding', 'description' => 'Penampilan musik live untuk pernikahan.'],
                ['title' => 'Acoustic Corporate Event', 'category' => 'Corporate', 'description' => 'Hiburan akustik untuk acara perusahaan.'],
            ],
            CreatorSubRole::WEDDING_ORGANIZER->value => [
                ['title' => 'Wedding Ceremony Package', 'category' => 'Ceremony', 'description' => 'Perencanaan dan pelaksanaan upacara pernikahan.'],
                ['title' => 'Intimate Wedding Event', 'category' => 'Reception', 'description' => 'Pernikahan konsep intim dan hangat.'],
            ],
            CreatorSubRole::EVENT_ORGANIZER->value => [
                ['title' => 'Corporate Gathering', 'category' => 'Corporate', 'description' => 'Manajemen acara gathering kantor.'],
                ['title' => 'Festival Kreatif', 'category' => 'Festival', 'description' => 'Festival seni dan budaya.'],
            ],
            CreatorSubRole::COMMUNITY->value => [
                ['title' => 'Community Gathering', 'category' => 'Gathering', 'description' => 'Kumpul komunitas tahunan.'],
                ['title' => 'Social Campaign', 'category' => 'Social', 'description' => 'Kampanye bakti sosial.'],
            ],
            CreatorSubRole::MAKEUP_ARTIST->value => [
                ['title' => 'Bridal Makeup', 'category' => 'Wedding', 'description' => 'Tata rias khusus pengantin.'],
                ['title' => 'Graduation Makeup', 'category' => 'Graduation', 'description' => 'Tata rias untuk wisuda.'],
            ],
            CreatorSubRole::PHOTOGRAPHER->value => [
                ['title' => 'Product Photography', 'category' => 'Commercial', 'description' => 'Foto produk komersial.'],
                ['title' => 'Wedding Photography', 'category' => 'Wedding', 'description' => 'Dokumentasi hari pernikahan.'],
            ],
            CreatorSubRole::EDITOR->value => [
                ['title' => 'Social Media Video Editing', 'category' => 'Social Media', 'description' => 'Pengeditan video untuk Reels/TikTok.'],
                ['title' => 'Corporate Video Editing', 'category' => 'Corporate', 'description' => 'Video profil perusahaan.'],
            ],
            CreatorSubRole::VIDEOGRAPHER->value => [
                ['title' => 'Company Profile Video', 'category' => 'Corporate', 'description' => 'Pembuatan video profil.'],
                ['title' => 'Wedding Cinematic Video', 'category' => 'Wedding', 'description' => 'Video pernikahan sinematik.'],
            ],
            'general' => [
                [
                    'title' => 'Brand Identity & Visual Design UMKM',
                    'category' => 'Branding',
                    'description' => 'Desain identitas visual lengkap dan kemasan produk untuk UMKM lokal.',
                    'image_url' => 'https://images.unsplash.com/photo-1542744094-3a31f272c490?auto=format&fit=crop&w=800&q=80',
                ],
                [
                    'title' => 'Dokumentasi & Creative Production',
                    'category' => 'Creative',
                    'description' => 'Produksi konten visual terpadu untuk kampanye promosi digital.',
                    'image_url' => 'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?auto=format&fit=crop&w=800&q=80',
                ],
                [
                    'title' => 'Digital Campaign & Social Media Content',
                    'category' => 'Social Media',
                    'description' => 'Pembuatan aset konten kreatif multi-platform dan feed Instagram.',
                    'image_url' => 'https://images.unsplash.com/photo-1611162617213-7d7a39e9b1d7?auto=format&fit=crop&w=800&q=80',
                ],
                [
                    'title' => 'Commercial Photo & Media Session',
                    'category' => 'Media',
                    'description' => 'Sesi fotografi dan videografi komersial terintegrasi untuk katalog produk.',
                    'image_url' => 'https://images.unsplash.com/photo-1542038784456-1ea8e935640e?auto=format&fit=crop&w=800&q=80',
                ],
                [
                    'title' => 'Video Reels & Promosi Kreatif UMKM',
                    'category' => 'Videografi',
                    'description' => 'Produksi video pendek sinematik dan reels interaktif untuk promosi produk.',
                    'image_url' => 'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?auto=format&fit=crop&w=800&q=80',
                ],
            ],
        ];

        foreach ($creators as $creator) {
            $subRole = $creator->sub_role instanceof \BackedEnum ? $creator->sub_role->value : $creator->sub_role;
            $roleKey = $subRole ?? 'general';
            if (!isset($portfolioData[$roleKey])) continue;

            $items = $portfolioData[$roleKey];
            foreach ($items as $index => $item) {
                PortfolioItem::updateOrCreate(
                    [
                        'user_id' => $creator->id,
                        'title' => $item['title'],
                    ],
                    [
                        'category' => $item['category'],
                        'description' => $item['description'],
                        'image_url' => $item['image_url'] ?? null,
                        'sort_order' => $index,
                        'source' => 'internal',
                        'verification_status' => 'verified',
                    ]
                );
            }
        }
    }
}
