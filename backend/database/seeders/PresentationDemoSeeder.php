<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\Opportunity;
use App\Models\OpportunityRequirement;
use App\Models\OpportunityApplication;
use App\Models\OpportunityReview;
use App\Models\JobContract;
use App\Models\JobStatusHistory;
use App\Enums\ContractStatus;
use App\Enums\WorkStatus;
use Carbon\Carbon;

class PresentationDemoSeeder extends Seeder
{
    public function run(): void
    {
        // Temukan akun demo
        $eventOrganizer = User::where('email', 'event.organizer@kreavana.id')->first();
        $clientDemo     = User::where('email', 'client@kreavana.id')->first();
        $institution    = User::where('email', 'institution@kreavana.id')->first();
        $photographer   = User::where('email', 'photographer@kreavana.id')->first();
        $videographer   = User::where('email', 'videographer@kreavana.id')->first();
        $mc             = User::where('email', 'mc@kreavana.id')->first();

        if (!$eventOrganizer && !$clientDemo && !$institution) {
            $this->command?->error('User demo tidak ditemukan. Harap jalankan UserSeeder terlebih dahulu.');
            return;
        }

        // Target pemilik proyek (prioritaskan event_organizer_demo jika ada)
        $owners = array_filter([$eventOrganizer, $clientDemo, $institution]);

        foreach ($owners as $owner) {
            $this->seedForOwner($owner, $photographer, $videographer, $mc);
        }

        $this->command?->info('Dummy data presentasi berhasil dibuat untuk presentasi demo!');
    }

    private function seedForOwner(User $owner, ?User $photographer, ?User $videographer, ?User $mc): void
    {
        // ── 1. Proyek Sedang Berjalan / Mencari Kreator (Ada Rating Eksternal) ──
        $opp1 = Opportunity::firstOrCreate(
            [
                'title'     => 'Jakarta Indie Music & Art Fest 2026',
                'posted_by' => $owner->id,
            ],
            [
                'description'            => 'Festival musik dan seni tahunan yang mempertemukan 20+ musisi independen tanah air. Membutuhkan tim dokumentasi visual profesional untuk liputan panggung utama, crowd ambience, dan aftermovie viral.',
                'sub_role_slug'          => 'event_organizer',
                'type'                   => 'project',
                'location'               => 'Istora Senayan, Jakarta',
                'latitude'               => -6.2185,
                'longitude'              => 106.8025,
                'location_category'      => 'urban',
                'address'                => 'Gelora Bung Karno Sports Complex, Senayan, Jakarta Pusat',
                'deadline'               => Carbon::now()->addDays(20)->toDateString(),
                'event_date'             => Carbon::now()->addDays(25)->toDateString(),
                'event_start_date'       => Carbon::now()->addDays(25)->toDateString(),
                'event_end_date'         => Carbon::now()->addDays(27)->toDateString(),
                'budget_range'           => 'Rp 18.000.000 - Rp 25.000.000',
                'status'                 => 'open',
                'external_rating'        => 4.90,
                'external_rating_source' => 'Loket.com & Google Reviews (Edisi 2025)',
                'external_proof_url'     => 'https://loket.com/event/jakarta-indie-music-art-fest',
                'escrow_status'          => 'none',
                'event_progress'         => 35,
                'created_at'             => Carbon::now()->subDays(3),
            ]
        );

        // Kebutuhan role (requirements)
        OpportunityRequirement::firstOrCreate(
            ['opportunity_id' => $opp1->id, 'sub_role_slug' => 'fotografer'],
            ['quantity' => 2, 'notes' => 'Stage photography, crowd, gear full-frame']
        );
        OpportunityRequirement::firstOrCreate(
            ['opportunity_id' => $opp1->id, 'sub_role_slug' => 'videografer'],
            ['quantity' => 2, 'notes' => 'Aftermovie 4K 60fps, reels vertical format']
        );
        OpportunityRequirement::firstOrCreate(
            ['opportunity_id' => $opp1->id, 'sub_role_slug' => 'drone'],
            ['quantity' => 1, 'notes' => 'Night aerial crowd, lisensi pilot']
        );

        // Pelamar yang masuk
        if ($photographer) {
            OpportunityApplication::firstOrCreate(
                [
                    'opportunity_id' => $opp1->id,
                    'creator_id'     => $photographer->id,
                ],
                [
                    'sub_role_slug'   => 'fotografer',
                    'pitch_message'   => 'Halo! Kami berpengalaman meliput Synchronize Fest & Java Jazz. Siap memberikan foto panggung tajam & ekspresif.',
                    'bid_price'       => 7000000,
                    'status'          => 'pending',
                    'reviewed_at'     => null,
                ]
            );
        }

        if ($videographer) {
            OpportunityApplication::firstOrCreate(
                [
                    'opportunity_id' => $opp1->id,
                    'creator_id'     => $videographer->id,
                ],
                [
                    'sub_role_slug'   => 'videografer',
                    'pitch_message'   => 'Tim kami siap menangani aftermovie sinematik dengan color grading profesional khas Kreavana.',
                    'bid_price'       => 8500000,
                    'status'          => 'pending',
                    'reviewed_at'     => null,
                ]
            );
        }


        // ── 2. Proyek Gala Dinner Korporat (Ada Rating Eksternal) ──
        $opp2 = Opportunity::firstOrCreate(
            [
                'title'     => 'Gala Dinner & Corporate Anniversary PT Kreavana Nusantara',
                'posted_by' => $owner->id,
            ],
            [
                'description'            => 'Perayaan hari jadi korporat ke-5 yang dihadiri 500+ tamu undangan VIP & stakeholders. Acara mengusung tema Glamour Modern Nusantara dengan tata panggung megah.',
                'sub_role_slug'          => 'event_organizer',
                'type'                   => 'project',
                'location'               => 'The Ritz-Carlton Mega Kuningan, Jakarta',
                'latitude'               => -6.2289,
                'longitude'              => 106.8272,
                'location_category'      => 'urban',
                'address'                => 'Jl. DR. Ide Anak Agung Gde Agung Kav.E.1.1 No.1, Mega Kuningan, Jakarta',
                'deadline'               => Carbon::now()->addDays(14)->toDateString(),
                'event_date'             => Carbon::now()->addDays(18)->toDateString(),
                'budget_range'           => 'Rp 30.000.000 - Rp 45.000.000',
                'status'                 => 'open',
                'external_rating'        => 4.85,
                'external_rating_source' => 'Survei Kepuasan Klien & Vendor Korporat 2025',
                'external_proof_url'     => 'https://kreavana.id/showcase/gala-dinner-anniversary',
                'escrow_status'          => 'none',
                'event_progress'         => 20,
                'created_at'             => Carbon::now()->subDays(5),
            ]
        );

        OpportunityRequirement::firstOrCreate(
            ['opportunity_id' => $opp2->id, 'sub_role_slug' => 'mc'],
            ['quantity' => 2, 'notes' => 'Bilingual MC (ID/EN), formal & interaktif']
        );


        // ── 3. Proyek SELESAI (Status Closed) — DEMO REVIEW DUA ARAH & HASIL ULASAN ──
        $oppClosed = Opportunity::firstOrCreate(
            [
                'title'     => 'Nusantara Creative & Coffee Expo 2026',
                'posted_by' => $owner->id,
            ],
            [
                'description'            => 'Pameran industri kopi dan ekonomi kreatif terbesar di Jakarta. Sukses diselenggarakan selama 3 hari dengan lebih dari 15.000 pengunjung dan 80 booth artisan.',
                'sub_role_slug'          => 'event_organizer',
                'type'                   => 'project',
                'location'               => 'Jakarta Convention Center (JCC), Senayan',
                'latitude'               => -6.2144,
                'longitude'              => 106.8075,
                'location_category'      => 'urban',
                'address'                => 'Jl. Gatot Subroto No.1, Gelora, Tanah Abang, Jakarta Pusat',
                'deadline'               => Carbon::now()->subDays(10)->toDateString(),
                'event_date'             => Carbon::now()->subDays(12)->toDateString(),
                'event_start_date'       => Carbon::now()->subDays(14)->toDateString(),
                'event_end_date'         => Carbon::now()->subDays(12)->toDateString(),
                'budget_range'           => 'Rp 22.000.000',
                'status'                 => 'closed',
                'external_rating'        => 4.75,
                'external_rating_source' => 'Tiket.com Events (Rating Pengunjung Edisi 2025)',
                'external_proof_url'     => 'https://tiket.com/event/nusantara-coffee-expo-2025',
                'escrow_status'          => 'released_to_creators',
                'event_progress'         => 100,
                'created_at'             => Carbon::now()->subDays(25),
            ]
        );

        OpportunityRequirement::firstOrCreate(
            ['opportunity_id' => $oppClosed->id, 'sub_role_slug' => 'fotografer'],
            ['quantity' => 1, 'notes' => 'Dokumentasi booth & kompetisi latte art']
        );
        OpportunityRequirement::firstOrCreate(
            ['opportunity_id' => $oppClosed->id, 'sub_role_slug' => 'videografer'],
            ['quantity' => 1, 'notes' => 'Video highlight dan wawancara barista']
        );

        // Kreator yang disetujui (Approved Creators)
        if ($photographer) {
            OpportunityApplication::updateOrCreate(
                [
                    'opportunity_id' => $oppClosed->id,
                    'creator_id'     => $photographer->id,
                ],
                [
                    'sub_role_slug'   => 'fotografer',
                    'pitch_message'   => 'Siap meliput seluruh booth dan ekspresi barista terbaik.',
                    'bid_price'       => 7500000,
                    'status'          => 'approved',
                    'reviewed_at'     => Carbon::now()->subDays(20),
                ]
            );

            // Ulasan 1: Klien / EO mengulas Fotografer
            OpportunityReview::firstOrCreate(
                [
                    'opportunity_id' => $oppClosed->id,
                    'reviewer_id'    => $owner->id,
                    'creator_id'     => $photographer->id,
                ],
                [
                    'rating'           => 5.0,
                    'is_on_time'       => true,
                    'delivery_days'    => 2,
                    'comment'          => 'Hasil foto pameran dan suasana booth luar biasa tajam dan estetik! Penyerahan file master 2 hari lebih cepat dari jadwal. Sangat responsif dan komunikatif.',
                    'reviewer_role'    => 'Event Organizer Lead',
                    'reviewer_company' => $owner->name,
                    'helpful_count'    => 7,
                    'created_at'       => Carbon::now()->subDays(10),
                ]
            );

            // Ulasan 2: Fotografer mengulas balik Klien / EO (Bilateral Review)
            OpportunityReview::firstOrCreate(
                [
                    'opportunity_id' => $oppClosed->id,
                    'reviewer_id'    => $photographer->id,
                    'creator_id'     => $owner->id,
                ],
                [
                    'rating'           => 5.0,
                    'is_on_time'       => true,
                    'delivery_days'    => 1,
                    'comment'          => 'Penyelenggara acara sangat kooperatif dan profesional. Brief dan rundown jelas, konsumsi serta akses panggung terjamin. Senang sekali bisa berkolaborasi!',
                    'reviewer_role'    => 'Fotografer Profesional',
                    'reviewer_company' => 'Studio Lensa Kreatif',
                    'helpful_count'    => 5,
                    'created_at'       => Carbon::now()->subDays(9),
                ]
            );
        }

        if ($videographer) {
            OpportunityApplication::updateOrCreate(
                [
                    'opportunity_id' => $oppClosed->id,
                    'creator_id'     => $videographer->id,
                ],
                [
                    'sub_role_slug'   => 'videografer',
                    'pitch_message'   => 'Videografer spesialis expo dan cinematic storytelling.',
                    'bid_price'       => 9000000,
                    'status'          => 'approved',
                    'reviewed_at'     => Carbon::now()->subDays(20),
                ]
            );
            // Catatan: Belum ada ulasan ke videografer, sehingga tombol "Beri Ulasan" bisa diklik saat demo!
        }


        // ── 4. Kontrak Kerja Selesai (Job Contract Completed) ──
        if ($videographer) {
            JobContract::firstOrCreate(
                [
                    'title'     => 'Produksi Teaser & Aftermovie Cinematic 4K Expo',
                    'client_id' => $owner->id,
                ],
                [
                    'creator_id'           => $videographer->id,
                    'opportunity_id'       => $oppClosed->id,
                    'description'          => 'Editing dan produksi teaser video 60 detik serta full aftermovie 3 menit untuk publikasi media dan sponsor.',
                    'terms'                => 'Revisi maksimal 2 kali, penyerahan master ProRes 422.',
                    'agreed_price'         => 8500000,
                    'escrow_amount'        => 8500000,
                    'contract_status'      => ContractStatus::Completed->value,
                    'work_status'          => WorkStatus::Completed->value,
                    'scheduled_start_date' => Carbon::now()->subDays(15)->toDateString(),
                    'scheduled_end_date'   => Carbon::now()->subDays(8)->toDateString(),
                    'deadline'             => Carbon::now()->subDays(7)->toDateString(),
                    'creator_approved'     => true,
                    'client_approved'      => true,
                    'completed_at'         => Carbon::now()->subDays(7),
                    'created_at'           => Carbon::now()->subDays(16),
                ]
            );
        }

        // ── 5. Kontrak Kerja Berjalan (Job Contract Active) ──
        if ($mc) {
            JobContract::firstOrCreate(
                [
                    'title'     => 'Master of Ceremony 2 Hari Mainstage Festival',
                    'client_id' => $owner->id,
                ],
                [
                    'creator_id'           => $mc->id,
                    'opportunity_id'       => $opp1->id,
                    'description'          => 'Pemandu acara utama untuk 2 hari festival musik, memandu interaksi dengan 10.000+ audiens dan sponsor game show.',
                    'terms'                => 'Wajib hadir gladi resik H-1.',
                    'agreed_price'         => 6000000,
                    'escrow_amount'        => 6000000,
                    'contract_status'      => ContractStatus::Active->value,
                    'work_status'          => WorkStatus::InProgress->value,
                    'scheduled_start_date' => Carbon::now()->addDays(24)->toDateString(),
                    'scheduled_end_date'   => Carbon::now()->addDays(26)->toDateString(),
                    'deadline'             => Carbon::now()->addDays(27)->toDateString(),
                    'creator_approved'     => true,
                    'client_approved'      => true,
                    'started_at'           => Carbon::now()->subDays(1),
                    'created_at'           => Carbon::now()->subDays(2),
                ]
            );
        }

        // ── 6. Kontrak Berjalan Tambahan (Job Contract: Berjalan) ──
        if ($videographer) {
            JobContract::firstOrCreate(
                [
                    'title'     => 'Dokumentasi Live Drone & LED Stage Visuals',
                    'client_id' => $owner->id,
                ],
                [
                    'creator_id'           => $videographer->id,
                    'opportunity_id'       => $opp1->id,
                    'description'          => 'Liputan visual udara malam dan integrasi output visual LED panggung utama.',
                    'terms'                => 'Wajib safety pilot drone sesuai regulasi.',
                    'agreed_price'         => 5500000,
                    'escrow_amount'        => 5500000,
                    'contract_status'      => ContractStatus::Approved->value,
                    'work_status'          => WorkStatus::InProgress->value,
                    'scheduled_start_date' => Carbon::now()->subDays(1)->toDateString(),
                    'scheduled_end_date'   => Carbon::now()->addDays(2)->toDateString(),
                    'deadline'             => Carbon::now()->addDays(3)->toDateString(),
                    'creator_approved'     => true,
                    'client_approved'      => true,
                    'started_at'           => Carbon::now()->subDays(1),
                    'created_at'           => Carbon::now()->subDays(6),
                ]
            );
        }

        // ── 7. Kategori Menunggu (Pending / Proposed / Draft Contracts & Under Dispute) ──
        // A. Opportunity Menunggu (Status: under_dispute)
        Opportunity::firstOrCreate(
            [
                'title'     => 'National Tech Startup Pitch Day & Expo 2026',
                'posted_by' => $owner->id,
            ],
            [
                'description'            => 'Ajang temu 100+ startup digital dan venture capital terkemuka se-Asia Tenggara. Sedang dalam tahap mediasi konfirmasi jadwal dan venue.',
                'sub_role_slug'          => 'event_organizer',
                'type'                   => 'project',
                'location'               => 'ICE BSD Hall 3, Tangerang',
                'latitude'               => -6.3023,
                'longitude'              => 106.6371,
                'location_category'      => 'urban',
                'address'                => 'Jl. BSD Grand Boulevard No.1, Pagedangan, Tangerang, Banten',
                'deadline'               => Carbon::now()->addDays(30)->toDateString(),
                'budget_range'           => 'Rp 25.000.000 - Rp 35.000.000',
                'status'                 => 'under_dispute',
                'external_rating'        => 4.90,
                'external_rating_source' => 'Survei Kepuasan Komunitas Startup 2025',
                'external_proof_url'     => 'https://kreavana.id/events/tech-startup-pitch-day',
                'created_at'             => Carbon::now()->subDays(1),
            ]
        );

        // B. Kontrak Menunggu Persetujuan Kreator (Status: Proposed)
        if ($mc) {
            JobContract::firstOrCreate(
                [
                    'title'     => 'Produksi Voice Over & Audio Jingle Acara Startup',
                    'client_id' => $owner->id,
                ],
                [
                    'creator_id'           => $mc->id,
                    'opportunity_id'       => null,
                    'description'          => 'Pengisian suara (voice over) narasi video pembuka dan countdown timer acara pitch day.',
                    'terms'                => 'Format file WAV 24-bit 48kHz, penyerahan H-3.',
                    'agreed_price'         => 3000000,
                    'escrow_amount'        => 3000000,
                    'contract_status'      => ContractStatus::Proposed->value,
                    'work_status'          => WorkStatus::Pending->value,
                    'scheduled_start_date' => Carbon::now()->addDays(10)->toDateString(),
                    'scheduled_end_date'   => Carbon::now()->addDays(12)->toDateString(),
                    'deadline'             => Carbon::now()->addDays(14)->toDateString(),
                    'creator_approved'     => false,
                    'client_approved'      => true,
                    'created_at'           => Carbon::now()->subHours(12),
                ]
            );
        }

        // C. Kontrak Menunggu Konfirmasi / Draft (Status: Draft)
        if ($photographer) {
            JobContract::firstOrCreate(
                [
                    'title'     => 'Desain Visual Backdrop Panggung & Merchandise VIP',
                    'client_id' => $owner->id,
                ],
                [
                    'creator_id'           => $photographer->id,
                    'opportunity_id'       => null,
                    'description'          => 'Perancangan aset grafis resolusi ultra-tinggi untuk backdrop panggung utama 12x4 meter dan lanyard VIP.',
                    'terms'                => 'File vector AI/PDF siap cetak.',
                    'agreed_price'         => 4000000,
                    'escrow_amount'        => 4000000,
                    'contract_status'      => ContractStatus::Draft->value,
                    'work_status'          => WorkStatus::Pending->value,
                    'scheduled_start_date' => Carbon::now()->addDays(7)->toDateString(),
                    'scheduled_end_date'   => Carbon::now()->addDays(11)->toDateString(),
                    'deadline'             => Carbon::now()->addDays(12)->toDateString(),
                    'creator_approved'     => false,
                    'client_approved'      => false,
                    'created_at'           => Carbon::now()->subHours(5),
                ]
            );
        }
    }
}
