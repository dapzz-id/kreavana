<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\Chat;
use App\Models\ChatParticipant;
use App\Models\Message;
use App\Enums\RoleType;
use App\Enums\CreatorSubRole;
use App\Enums\ConversationType;
use App\Enums\MessageType;

class ChatSeeder extends Seeder
{
    public function run(): void
    {
        $client = User::where('email', 'client@kreavana.id')->first();
        if (!$client) return;

        $creators = User::where('role', RoleType::Creator->value)->get();

        $messagesData = [
            CreatorSubRole::INSTITUTION->value => [
                'Client' => 'Halo, kami tertarik untuk program UMKM bersama.',
                'Creator' => 'Baik, bisa dikirimkan proposal programnya?',
                'Client' => 'Segera kami kirimkan via email.',
            ],
            CreatorSubRole::GOVERNMENT->value => [
                'Client' => 'Selamat pagi, mohon info ketersediaan untuk dinas.',
                'Creator' => 'Pagi, kami tersedia untuk bulan depan.',
                'Client' => 'Baik, saya akan jadwalkan pertemuannya.',
            ],
            CreatorSubRole::MC->value => [
                'Client' => 'Apakah Anda tersedia untuk menjadi MC acara kami?',
                'Creator' => 'Bisa. Acara akan berlangsung pada tanggal berapa?',
                'Client' => 'Acara kami berlangsung akhir bulan ini.',
            ],
            CreatorSubRole::SINGER->value => [
                'Client' => 'Berapa rate untuk live performance 2 jam?',
                'Creator' => 'Rate kami di 3 juta untuk 2 jam sesi.',
                'Client' => 'Oke, kami akan book untuk tanggal 15.',
            ],
            CreatorSubRole::WEDDING_ORGANIZER->value => [
                'Client' => 'Apakah ada paket intimate wedding?',
                'Creator' => 'Ada Kak, paket mulai dari 50 pax.',
                'Client' => 'Boleh minta price list lengkapnya?',
            ],
            CreatorSubRole::EVENT_ORGANIZER->value => [
                'Client' => 'Butuh EO untuk gathering kantor 200 orang.',
                'Creator' => 'Tentu, untuk lokasi di mana rencananya?',
                'Client' => 'Di daerah Lembang, Bandung.',
            ],
            CreatorSubRole::COMMUNITY->value => [
                'Client' => 'Kami ingin kolaborasi untuk event komunitas.',
                'Creator' => 'Sangat menarik, yuk kita bicarakan via GMeet.',
                'Client' => 'Setuju, besok jam 10 pagi ya.',
            ],
            CreatorSubRole::MAKEUP_ARTIST->value => [
                'Client' => 'Saya ingin menggunakan jasa makeup untuk acara.',
                'Creator' => 'Baik, acaranya untuk wedding atau event lainnya?',
                'Client' => 'Untuk acara prewedding.',
            ],
            CreatorSubRole::PHOTOGRAPHER->value => [
                'Client' => 'Halo, saya ingin menggunakan jasa foto produk.',
                'Creator' => 'Halo, tentu. Bisa diinformasikan jumlah produk dan konsep fotonya?',
                'Client' => 'Ada sekitar 20 produk dan kami ingin konsep clean.',
            ],
            CreatorSubRole::EDITOR->value => [
                'Client' => 'Bisa edit video durasi 10 menit untuk Youtube?',
                'Creator' => 'Bisa Kak, estimasi pengerjaan 3 hari kerja.',
                'Client' => 'Bagus, nanti file mentahnya saya share lewat GDrive.',
            ],
            CreatorSubRole::VIDEOGRAPHER->value => [
                'Client' => 'Terima kasih atas video profilnya, hasilnya sangat bagus!',
                'Creator' => 'Sama-sama, senang bisa bekerja sama.',
                'Client' => 'Nanti kami akan pakai jasa Anda lagi untuk proyek selanjutnya.',
            ],
        ];

        foreach ($creators as $creator) {
            $subRole = $creator->sub_role instanceof \BackedEnum ? $creator->sub_role->value : $creator->sub_role;
            if (!$subRole || !isset($messagesData[$subRole])) continue;

            $chat = Chat::firstOrCreate([
                'type' => ConversationType::Personal,
                'name' => 'Chat dengan ' . $creator->name,
            ]);

            ChatParticipant::firstOrCreate(['chat_id' => $chat->id, 'user_id' => $client->id]);
            ChatParticipant::firstOrCreate(['chat_id' => $chat->id, 'user_id' => $creator->id]);

            foreach ($messagesData[$subRole] as $senderRole => $text) {
                $senderId = $senderRole === 'Client' ? $client->id : $creator->id;
                Message::firstOrCreate([
                    'chat_id' => $chat->id,
                    'user_id' => $senderId,
                    'message' => $text,
                    'type' => MessageType::Text,
                ]);
            }
        }
    }
}
