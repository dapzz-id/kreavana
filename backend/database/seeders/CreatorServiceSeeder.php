<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Enums\RoleType;
use App\Enums\CreatorSubRole;
use App\Models\CreatorService;

class CreatorServiceSeeder extends Seeder
{
    public function run(): void
    {
        $creators = User::where('role', RoleType::Creator->value)->get();

        $serviceData = [
            CreatorSubRole::MC->value => [
                ['title' => 'Jasa MC Acara Formal', 'category' => 'MC', 'price' => 1000000.00, 'duration' => '1 hari', 'thumbnail_url' => 'https://images.unsplash.com/photo-1475721027785-f74eccf877e2?auto=format&fit=crop&w=1200&q=80'],
                ['title' => 'Jasa MC Pernikahan', 'category' => 'MC', 'price' => 1500000.00, 'duration' => '1 hari', 'thumbnail_url' => 'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?auto=format&fit=crop&w=1200&q=80'],
            ],
            CreatorSubRole::SINGER->value => [
                ['title' => 'Live Singer Wedding', 'category' => 'Music', 'price' => 2000000.00, 'duration' => '1 hari', 'thumbnail_url' => 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=1200&q=80'],
                ['title' => 'Live Singer Corporate Event', 'category' => 'Music', 'price' => 2500000.00, 'duration' => '1 hari', 'thumbnail_url' => 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=1200&q=80'],
            ],
            CreatorSubRole::WEDDING_ORGANIZER->value => [
                ['title' => 'Paket Wedding Organizer', 'category' => 'Event', 'price' => 15000000.00, 'duration' => '1 bulan', 'thumbnail_url' => 'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=1200&q=80'],
                ['title' => 'Paket Intimate Wedding', 'category' => 'Event', 'price' => 8000000.00, 'duration' => '1 bulan', 'thumbnail_url' => 'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?auto=format&fit=crop&w=1200&q=80'],
            ],
            CreatorSubRole::EVENT_ORGANIZER->value => [
                ['title' => 'Paket Event Organizer', 'category' => 'Event', 'price' => 20000000.00, 'duration' => '2 bulan', 'thumbnail_url' => 'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?auto=format&fit=crop&w=1200&q=80'],
                ['title' => 'Corporate Event Management', 'category' => 'Event', 'price' => 25000000.00, 'duration' => '2 bulan', 'thumbnail_url' => 'https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?auto=format&fit=crop&w=1200&q=80'],
            ],
            CreatorSubRole::MAKEUP_ARTIST->value => [
                ['title' => 'Bridal Makeup', 'category' => 'Beauty', 'price' => 3000000.00, 'duration' => '1 hari', 'thumbnail_url' => 'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?auto=format&fit=crop&w=1200&q=80'],
                ['title' => 'Makeup Wisuda', 'category' => 'Beauty', 'price' => 500000.00, 'duration' => '1 hari', 'thumbnail_url' => 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=1200&q=80'],
            ],
            CreatorSubRole::PHOTOGRAPHER->value => [
                ['title' => 'Paket Foto Produk', 'category' => 'Fotografi', 'price' => 1500000.00, 'duration' => '3 hari', 'thumbnail_url' => 'https://images.unsplash.com/photo-1542038784456-1ea8e935640e?auto=format&fit=crop&w=1200&q=80'],
                ['title' => 'Paket Foto Pernikahan', 'category' => 'Fotografi', 'price' => 5000000.00, 'duration' => '7 hari', 'thumbnail_url' => 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=1200&q=80'],
            ],
            CreatorSubRole::EDITOR->value => [
                ['title' => 'Editing Video Social Media', 'category' => 'Videografi', 'price' => 500000.00, 'duration' => '2 hari', 'thumbnail_url' => 'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?auto=format&fit=crop&w=1200&q=80'],
                ['title' => 'Editing Video Corporate', 'category' => 'Videografi', 'price' => 2000000.00, 'duration' => '5 hari', 'thumbnail_url' => 'https://images.unsplash.com/photo-1536240478700-b869070f9279?auto=format&fit=crop&w=1200&q=80'],
            ],
            CreatorSubRole::VIDEOGRAPHER->value => [
                ['title' => 'Video Iklan Sinematik', 'category' => 'Videografi', 'price' => 3000000.00, 'duration' => '7 hari', 'thumbnail_url' => 'https://images.unsplash.com/photo-1518133910546-b6c2fb7d79e3?auto=format&fit=crop&w=1200&q=80'],
                ['title' => 'Video Company Profile', 'category' => 'Videografi', 'price' => 7000000.00, 'duration' => '14 hari', 'thumbnail_url' => 'https://images.unsplash.com/photo-1508614589041-895b88991e3e?auto=format&fit=crop&w=1200&q=80'],
            ],
        ];

        foreach ($creators as $creator) {
            $subRole = $creator->sub_role instanceof \BackedEnum ? $creator->sub_role->value : $creator->sub_role;
            if (!$subRole || !isset($serviceData[$subRole])) continue;

            $items = $serviceData[$subRole];
            foreach ($items as $item) {
                CreatorService::updateOrCreate(
                    [
                        'creator_id' => $creator->id,
                        'title' => $item['title'],
                    ],
                    [
                        'description' => 'Layanan profesional untuk ' . $item['title'],
                        'category' => $item['category'],
                        'price' => $item['price'],
                        'duration_info' => $item['duration'],
                        'thumbnail_url' => $item['thumbnail_url'] ?? null,
                        'status' => 'active',
                    ]
                );
            }
        }

        // Seed creator packages for admin verification workflow
        $eoCreator = $creators->firstWhere('sub_role', CreatorSubRole::EVENT_ORGANIZER->value) ?? $creators->first();
        $mediaCreator = $creators->firstWhere('sub_role', CreatorSubRole::VIDEOGRAPHER->value) ?? $creators->last();

        if ($eoCreator) {
            CreatorService::updateOrCreate(
                [
                    'creator_id' => $eoCreator->id,
                    'title' => 'Paket Bundling EO Konser & Festival 2026',
                ],
                [
                    'description' => 'Paket all-in management panggung, soundsystem, ticketing, dan pengurusan perizinan instansi.',
                    'category' => 'eo_event_package',
                    'package_type' => 'premium',
                    'price' => 35000000.00,
                    'duration_info' => '1 bulan',
                    'thumbnail_url' => 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=1200&q=80',
                    'status' => 'pending',
                ]
            );

            CreatorService::updateOrCreate(
                [
                    'creator_id' => $eoCreator->id,
                    'title' => 'Paket EO Seminar Nasional Hybrid',
                ],
                [
                    'description' => 'Penyelenggaraan seminar profesional dengan integrasi zoom broadcast dan dokumentasi live.',
                    'category' => 'eo_event_package',
                    'package_type' => 'standard',
                    'price' => 18000000.00,
                    'duration_info' => '2 minggu',
                    'thumbnail_url' => 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&w=1200&q=80',
                    'status' => 'active',
                ]
            );
        }

        if ($mediaCreator) {
            CreatorService::updateOrCreate(
                [
                    'creator_id' => $mediaCreator->id,
                    'title' => 'Paket Produksi Video Sinematik Brand UMKM',
                ],
                [
                    'description' => 'Produksi reels komersial, color grading sinematik, dan lisensi audio komersial.',
                    'category' => 'creator_package',
                    'package_type' => 'starter',
                    'price' => 5000000.00,
                    'duration_info' => '5 hari',
                    'thumbnail_url' => 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=1200&q=80',
                    'status' => 'pending',
                ]
            );

            CreatorService::updateOrCreate(
                [
                    'creator_id' => $mediaCreator->id,
                    'title' => 'Paket Foto Katalog Produk Eksklusif',
                ],
                [
                    'description' => 'Sesi foto studio 50 SKU produk, retouching resolusi tinggi, dan revisi 2 kali.',
                    'category' => 'creator_package',
                    'package_type' => 'standard',
                    'price' => 3500000.00,
                    'duration_info' => '3 hari',
                    'thumbnail_url' => 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=1200&q=80',
                    'status' => 'rejected',
                    'review_note' => 'Lampiran contoh portofolio resolusi tinggi belum lengkap.',
                ]
            );
        }
    }
}
