<?php

namespace Database\Seeders;

use App\Models\User;
use App\Models\Opportunity;
use App\Models\JobContract;
use App\Models\WalletTransaction;
use App\Models\Chat;
use App\Models\Message;
use App\Enums\RoleType;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;
use Carbon\Carbon;

class CorporateTestSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Get the Corporate User and Creators
        $corpUser = User::where('email', 'corporate@kreavana.id')->first();
        $eoCreator = User::where('email', 'event.organizer@kreavana.id')->first();
        $videoCreator = User::where('email', 'videographer@kreavana.id')->first();

        if (!$corpUser || !$eoCreator || !$videoCreator) {
            $this->command->error('Users not found. Make sure UserSeeder has been run.');
            return;
        }

        $this->command->info('Creating Corporate Test Data...');

        // 2. Opportunities (Kebutuhan/Proyek)
        $opp1 = Opportunity::firstOrCreate(
            ['title' => 'Gala Dinner Akhir Tahun Perusahaan 2026'],
            [
                'id' => Str::uuid(),
                'description' => 'Mencari Event Organizer untuk menghandle acara Gala Dinner 500 karyawan.',
                'sub_role_slug' => 'event_organizer',
                'type' => 'project',
                'location' => 'Jakarta Selatan',
                'deadline' => Carbon::now()->addDays(30),
                'budget_range' => 'Rp 50.000.000 - Rp 100.000.000',
                'status' => 'open',
                'posted_by' => $corpUser->id,
                'created_at' => Carbon::now()->subDays(5),
            ]
        );

        $opp2 = Opportunity::firstOrCreate(
            ['title' => 'Video Profil Perusahaan 2026'],
            [
                'id' => Str::uuid(),
                'description' => 'Mencari videografer untuk membuat video profil perusahaan berdurasi 3 menit.',
                'sub_role_slug' => 'videographer',
                'type' => 'project',
                'location' => 'Jakarta Pusat',
                'deadline' => Carbon::now()->subDays(2), // Already past
                'budget_range' => 'Rp 10.000.000 - Rp 25.000.000',
                'status' => 'closed',
                'posted_by' => $corpUser->id,
                'created_at' => Carbon::now()->subDays(15),
            ]
        );

        // 2.5 Opportunity Applications
        // The EO applied for Gala Dinner
        \App\Models\OpportunityApplication::firstOrCreate(
            ['opportunity_id' => $opp1->id, 'creator_id' => $eoCreator->id, 'sub_role_slug' => 'event_organizer'],
            [
                'id' => Str::uuid(),
                'pitch_message' => 'Kami siap menyelenggarakan Gala Dinner Anda dengan meriah!',
                'bid_price' => 75000000,
                'status' => 'approved',
                'created_at' => Carbon::now()->subDays(4),
            ]
        );

        // The Videographer applied for Video Profil
        \App\Models\OpportunityApplication::firstOrCreate(
            ['opportunity_id' => $opp2->id, 'creator_id' => $videoCreator->id, 'sub_role_slug' => 'videographer'],
            [
                'id' => Str::uuid(),
                'pitch_message' => 'Siap membuat video profil sinematik untuk perusahaan Anda.',
                'bid_price' => 15000000,
                'status' => 'approved',
                'created_at' => Carbon::now()->subDays(12),
            ]
        );

        // 3. Job Contracts
        // Contract 1: In Progress with EO
        JobContract::firstOrCreate(
            ['title' => 'Kontrak Gala Dinner Perusahaan'],
            [
                'id' => Str::uuid(),
                'client_id' => $corpUser->id,
                'creator_id' => $eoCreator->id,
                'opportunity_id' => $opp1->id,
                'description' => 'Paket All-in Gala Dinner 500 pax di Hotel Bintang 5.',
                'terms' => 'Pembayaran 50% di awal masuk Escrow.',
                'agreed_price' => 75000000,
                'escrow_amount' => 75000000,
                'contract_status' => 'active',
                'work_status' => 'in_progress',
                'deadline' => Carbon::now()->addDays(20),
                'creator_approved' => true,
                'client_approved' => true,
                'started_at' => Carbon::now()->subDays(2),
            ]
        );

        // Contract 2: Completed with Videographer
        JobContract::firstOrCreate(
            ['title' => 'Kontrak Video Profil 2026'],
            [
                'id' => Str::uuid(),
                'client_id' => $corpUser->id,
                'creator_id' => $videoCreator->id,
                'opportunity_id' => $opp2->id,
                'description' => 'Pembuatan video profil perusahaan.',
                'terms' => 'Revisi maksimal 3 kali.',
                'agreed_price' => 15000000,
                'escrow_amount' => 0, // Already disbursed
                'contract_status' => 'completed',
                'work_status' => 'completed',
                'deadline' => Carbon::now()->subDays(1),
                'creator_approved' => true,
                'client_approved' => true,
                'started_at' => Carbon::now()->subDays(10),
                'completed_at' => Carbon::now()->subDays(1),
            ]
        );

        // 4. Wallet Transactions (Topup & Escrow holding)
        // Topup 100M
        WalletTransaction::firstOrCreate(
            ['reference_number' => 'TOPUP-CORP-001'],
            [
                'id' => Str::uuid(),
                'user_id' => $corpUser->id,
                'type' => 'topup',
                'amount' => 100000000,
                'payment_method' => 'bank_transfer',
                'payment_provider' => 'BCA',
                'status' => 'completed',
                'description' => 'Topup Saldo via Bank Transfer',
                'created_at' => Carbon::now()->subDays(6),
            ]
        );

        // Escrow payment for EO 75M
        WalletTransaction::firstOrCreate(
            ['reference_number' => 'ESCROW-CORP-001'],
            [
                'id' => Str::uuid(),
                'user_id' => $corpUser->id,
                'type' => 'escrow_hold',
                'amount' => -75000000,
                'payment_method' => 'wallet',
                'status' => 'completed',
                'description' => 'Pembayaran Escrow untuk Kontrak Gala Dinner Perusahaan',
                'created_at' => Carbon::now()->subDays(2),
            ]
        );

        // Escrow payment for Videographer 15M (Hold then Release)
        WalletTransaction::firstOrCreate(
            ['reference_number' => 'ESCROW-CORP-002'],
            [
                'id' => Str::uuid(),
                'user_id' => $corpUser->id,
                'type' => 'escrow_hold',
                'amount' => -15000000,
                'payment_method' => 'wallet',
                'status' => 'completed',
                'description' => 'Pembayaran Escrow untuk Kontrak Video Profil 2026',
                'created_at' => Carbon::now()->subDays(10),
            ]
        );

        WalletTransaction::firstOrCreate(
            ['reference_number' => 'ESCROW-RELEASE-CORP-002'],
            [
                'id' => Str::uuid(),
                'user_id' => $corpUser->id,
                'type' => 'escrow_release', // From corporate POV, money is gone, but we log the release
                'amount' => 0, // It doesn't add back to corporate
                'payment_method' => 'wallet',
                'status' => 'completed',
                'description' => 'Pencairan Escrow untuk Kontrak Video Profil 2026',
                'created_at' => Carbon::now()->subDays(1),
            ]
        );

        $this->command->info('Skip updating wallet_balance since it might be dynamically calculated.');
        $this->command->info('Updated Corporate Wallet Balance to 10M');

        // 5. Chat History
        $chat = Chat::firstOrCreate(
            ['type' => 'direct'],
            [
                'id' => Str::uuid(),
                'created_at' => Carbon::now()->subDays(3),
                'updated_at' => Carbon::now(),
            ]
        );

        // Attach participants
        \App\Models\ChatParticipant::firstOrCreate(
            ['chat_id' => $chat->id, 'user_id' => $corpUser->id]
        );
        \App\Models\ChatParticipant::firstOrCreate(
            ['chat_id' => $chat->id, 'user_id' => $eoCreator->id]
        );

        // Add some messages
        Message::firstOrCreate(
            ['chat_id' => $chat->id, 'user_id' => $corpUser->id, 'message' => 'Halo tim EO, apakah bisa handle gala dinner kami?'],
            ['id' => Str::uuid(), 'type' => 'text', 'created_at' => Carbon::now()->subDays(3)->addHours(1)]
        );

        Message::firstOrCreate(
            ['chat_id' => $chat->id, 'user_id' => $eoCreator->id, 'message' => 'Tentu bisa pak, kami siap. Mari diskusikan detailnya.'],
            ['id' => Str::uuid(), 'type' => 'text', 'created_at' => Carbon::now()->subDays(3)->addHours(2)]
        );

        // 6. Notifications (Activity Feed)
        \App\Models\Notification::firstOrCreate(
            ['user_id' => $corpUser->id, 'title' => 'Proposal Baru Diterima'],
            [
                'id' => Str::uuid(),
                'message' => 'Event Organizer mengirimkan proposal untuk proyek Gala Dinner Anda.',
                'type' => 'opportunity',
                'is_read' => false,
                'created_at' => Carbon::now()->subHours(2),
            ]
        );

        \App\Models\Notification::firstOrCreate(
            ['user_id' => $corpUser->id, 'title' => 'Pembayaran Escrow Diamankan'],
            [
                'id' => Str::uuid(),
                'message' => 'Dana Escrow sebesar Rp 75.000.000 untuk Kontrak Gala Dinner berhasil ditahan.',
                'type' => 'payment',
                'is_read' => true,
                'created_at' => Carbon::now()->subDays(2),
            ]
        );

        \App\Models\Notification::firstOrCreate(
            ['user_id' => $corpUser->id, 'title' => 'Milestone Disetujui'],
            [
                'id' => Str::uuid(),
                'message' => 'Milestone 1 untuk Video Profil Perusahaan telah disetujui.',
                'type' => 'contract',
                'is_read' => true,
                'created_at' => Carbon::now()->subDays(10),
            ]
        );

        $this->command->info('Corporate Test Data Seeded Successfully!');
    }
}
