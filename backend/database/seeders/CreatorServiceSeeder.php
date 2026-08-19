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
                ['title' => 'Jasa MC Acara Formal', 'category' => 'MC', 'price' => 1000000.00, 'duration' => '1 hari'],
                ['title' => 'Jasa MC Pernikahan', 'category' => 'MC', 'price' => 1500000.00, 'duration' => '1 hari'],
            ],
            CreatorSubRole::SINGER->value => [
                ['title' => 'Live Singer Wedding', 'category' => 'Music', 'price' => 2000000.00, 'duration' => '1 hari'],
                ['title' => 'Live Singer Corporate Event', 'category' => 'Music', 'price' => 2500000.00, 'duration' => '1 hari'],
            ],
            CreatorSubRole::WEDDING_ORGANIZER->value => [
                ['title' => 'Paket Wedding Organizer', 'category' => 'Event', 'price' => 15000000.00, 'duration' => '1 bulan'],
                ['title' => 'Paket Intimate Wedding', 'category' => 'Event', 'price' => 8000000.00, 'duration' => '1 bulan'],
            ],
            CreatorSubRole::EVENT_ORGANIZER->value => [
                ['title' => 'Paket Event Organizer', 'category' => 'Event', 'price' => 20000000.00, 'duration' => '2 bulan'],
                ['title' => 'Corporate Event Management', 'category' => 'Event', 'price' => 25000000.00, 'duration' => '2 bulan'],
            ],
            CreatorSubRole::MAKEUP_ARTIST->value => [
                ['title' => 'Bridal Makeup', 'category' => 'Beauty', 'price' => 3000000.00, 'duration' => '1 hari'],
                ['title' => 'Makeup Wisuda', 'category' => 'Beauty', 'price' => 500000.00, 'duration' => '1 hari'],
            ],
            CreatorSubRole::PHOTOGRAPHER->value => [
                ['title' => 'Paket Foto Produk', 'category' => 'Fotografi', 'price' => 1500000.00, 'duration' => '3 hari'],
                ['title' => 'Paket Foto Pernikahan', 'category' => 'Fotografi', 'price' => 5000000.00, 'duration' => '7 hari'],
            ],
            CreatorSubRole::EDITOR->value => [
                ['title' => 'Editing Video Social Media', 'category' => 'Videografi', 'price' => 500000.00, 'duration' => '2 hari'],
                ['title' => 'Editing Video Corporate', 'category' => 'Videografi', 'price' => 2000000.00, 'duration' => '5 hari'],
            ],
            CreatorSubRole::VIDEOGRAPHER->value => [
                ['title' => 'Video Iklan Sinematik', 'category' => 'Videografi', 'price' => 3000000.00, 'duration' => '7 hari'],
                ['title' => 'Video Company Profile', 'category' => 'Videografi', 'price' => 7000000.00, 'duration' => '14 hari'],
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
                        'status' => 'active',
                    ]
                );
            }
        }
    }
}
