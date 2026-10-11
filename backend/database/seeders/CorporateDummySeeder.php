<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\JobContract;
use App\Models\InstitutionResource;
use App\Enums\RoleType;
use App\Enums\ContractStatus;
use App\Enums\WorkStatus;
use Carbon\Carbon;

class CorporateDummySeeder extends Seeder
{
    public function run(): void
    {
        $corp = User::where('username', 'corporate_demo')->first();
        if (!$corp) {
            $corp = User::where('email', 'corporate@kreavana.id')->first();
        }

        if (!$corp) {
            return;
        }

        // Pastikan sub_role corporate aktif
        $corp->update([
            'role' => RoleType::User,
            'sub_role' => 'corporate',
        ]);

        \App\Models\UserSubRole::updateOrCreate(
            [
                'user_id' => $corp->id,
                'sub_role_slug' => 'corporate',
            ],
            [
                'role_type' => RoleType::User->value,
                'is_active' => true,
            ]
        );

        $creators = User::where('role', RoleType::Creator)->get();
        $videographer = $creators->firstWhere('username', 'videographer_demo') ?? $creators->first();
        $photographer = $creators->firstWhere('username', 'photographer_demo') ?? $creators->skip(1)->first() ?? $creators->first();
        $editor = $creators->firstWhere('username', 'editor_demo') ?? $creators->skip(2)->first() ?? $creators->first();
        $eo = $creators->firstWhere('username', 'event_organizer_demo') ?? $creators->skip(3)->first() ?? $creators->first();

        // 1. DUMMY 5 PROYEK & KONTRAK PERUSAHAAN (Untuk Dasbor Perusahaan & Proyek)
        $contracts = [
            [
                'title' => 'Pengadaan Rebranding Brand & Visual Identity 2026',
                'description' => 'Paket komprehensif redesign visual identity enterprise, brand guideline 120 halaman, dan asset kit digital.',
                'creator_id' => $editor?->id ?? $corp->id,
                'agreed_price' => 45000000.00,
                'escrow_amount' => 45000000.00,
                'contract_status' => ContractStatus::Active->value,
                'work_status' => WorkStatus::InProgress->value,
                'deadline' => Carbon::now()->addDays(20)->format('Y-m-d'),
                'scheduled_start_date' => Carbon::now()->subDays(10)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->addDays(20)->format('Y-m-d'),
                'creator_approved' => true,
                'client_approved' => true,
            ],
            [
                'title' => 'Produksi Video Profil Korporat 4K & Annual Report',
                'description' => 'Shooting video profil perusahaan multi-lokasi pabrik & kantor pusat beserta motion graphic data tahunan.',
                'creator_id' => $videographer?->id ?? $corp->id,
                'agreed_price' => 38500000.00,
                'escrow_amount' => 38500000.00,
                'contract_status' => ContractStatus::Active->value,
                'work_status' => 'review',
                'deadline' => Carbon::now()->addDays(5)->format('Y-m-d'),
                'scheduled_start_date' => Carbon::now()->subDays(15)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->addDays(5)->format('Y-m-d'),
                'creator_approved' => true,
                'client_approved' => true,
            ],
            [
                'title' => 'Revamp UI/UX & Design System Portal Enterprise B2B',
                'description' => 'Perancangan arsitektur antarmuka dan design token modul procurement enterprise berbasis Tailwind & Figma.',
                'creator_id' => $editor?->id ?? $corp->id,
                'agreed_price' => 32000000.00,
                'escrow_amount' => 32000000.00,
                'contract_status' => ContractStatus::Active->value,
                'work_status' => WorkStatus::InProgress->value,
                'deadline' => Carbon::now()->addDays(35)->format('Y-m-d'),
                'scheduled_start_date' => Carbon::now()->subDays(5)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->addDays(35)->format('Y-m-d'),
                'creator_approved' => true,
                'client_approved' => true,
            ],
            [
                'title' => 'Dokumentasi & Media Coverage Gala Dinner RUPS Tahunan',
                'description' => 'Liputan fotografi VIP, live streaming feed ke 3 cabang, dan fast video recap dalam 24 jam.',
                'creator_id' => $photographer?->id ?? $corp->id,
                'agreed_price' => 18500000.00,
                'escrow_amount' => 18500000.00,
                'contract_status' => ContractStatus::Completed->value,
                'work_status' => WorkStatus::Completed->value,
                'deadline' => Carbon::now()->subDays(2)->format('Y-m-d'),
                'scheduled_start_date' => Carbon::now()->subDays(7)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->subDays(2)->format('Y-m-d'),
                'creator_approved' => true,
                'client_approved' => true,
            ],
            [
                'title' => 'Management Acara & Show Director Customer Gathering 2026',
                'description' => 'Penyelenggaraan event hibrida 500 peserta VIP dengan konsep stage lighting interaktif dan entertainment.',
                'creator_id' => $eo?->id ?? $corp->id,
                'agreed_price' => 52000000.00,
                'escrow_amount' => 52000000.00,
                'contract_status' => ContractStatus::Active->value,
                'work_status' => WorkStatus::Scheduled->value,
                'deadline' => Carbon::now()->addDays(45)->format('Y-m-d'),
                'scheduled_start_date' => Carbon::now()->addDays(10)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->addDays(45)->format('Y-m-d'),
                'creator_approved' => true,
                'client_approved' => true,
            ],
        ];

        foreach ($contracts as $cData) {
            JobContract::updateOrCreate(
                [
                    'client_id' => $corp->id,
                    'title' => $cData['title'],
                ],
                [
                    'creator_id' => $cData['creator_id'],
                    'description' => $cData['description'],
                    'agreed_price' => $cData['agreed_price'],
                    'escrow_amount' => $cData['escrow_amount'],
                    'contract_status' => $cData['contract_status'],
                    'work_status' => $cData['work_status'],
                    'deadline' => $cData['deadline'],
                    'scheduled_start_date' => $cData['scheduled_start_date'],
                    'scheduled_end_date' => $cData['scheduled_end_date'],
                    'creator_approved' => $cData['creator_approved'],
                    'client_approved' => $cData['client_approved'],
                ]
            );
        }

        // 2. DUMMY DATA MODUL PENGELOLAAN PERUSAHAAN (5 DATA TIAP SUBMENU)
        $resources = [
            // --- 5 PENGADAAN & TENDER (RFP) ---
            [
                'resource_type' => 'tenders',
                'title' => 'RFP-2026-001: Pengadaan Sistem Dokumentasi & Multi-Camera RUPS',
                'description' => 'Tender terbuka pengadaan vendor dokumentasi, broadcast multi-kamera, dan live switcher untuk RUPS PT Kreavana Nusantara.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Broadcast & Media',
                    'budget' => 65000000,
                    'deadline' => '2026-11-15',
                ],
                'published_at' => Carbon::now()->subDays(3),
            ],
            [
                'resource_type' => 'tenders',
                'title' => 'RFP-2026-002: Tender Desain Kemasan & Brand Identity Produk Ekspor',
                'description' => 'Pengadaan konsultan perancangan identitas kemasan ramah lingkungan berstandar sertifikasi ekspor Uni Eropa.',
                'status' => 'in_progress',
                'metadata' => [
                    'category' => 'Desain & Branding',
                    'budget' => 85000000,
                    'deadline' => '2026-10-30',
                ],
                'published_at' => Carbon::now()->subDays(8),
            ],
            [
                'resource_type' => 'tenders',
                'title' => 'RFP-2026-003: Jasa Produksi TVC Iklan Digital & Video 3D CGI',
                'description' => 'Pembuatan iklan komersial berdurasi 30 detik dan varian cutdown media sosial resolusi 4K dengan visual 3D CGI photorealistic.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Video Advertising',
                    'budget' => 120000000,
                    'deadline' => '2026-12-01',
                ],
                'published_at' => Carbon::now()->subDays(2),
            ],
            [
                'resource_type' => 'tenders',
                'title' => 'RFP-2026-004: Konsultan Audio Branding & Jingle Resmi Korporat',
                'description' => 'Pengadaan komposer dan produser audio untuk menciptakan sonic logo, jingle resmi, dan sound design video korporasi.',
                'status' => 'completed',
                'metadata' => [
                    'category' => 'Music & Audio',
                    'budget' => 35000000,
                    'deadline' => '2026-09-25',
                ],
                'published_at' => Carbon::now()->subDays(30),
            ],
            [
                'resource_type' => 'tenders',
                'title' => 'RFP-2026-005: Vendor Konstruksi Booth Exhibition & Media Interaktif',
                'description' => 'Pengadaan kontraktor booth pameran seluas 60m² terintegrasi layar sentuh interaktif dan simulasi AR.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Exhibition & Stage',
                    'budget' => 95000000,
                    'deadline' => '2026-11-20',
                ],
                'published_at' => Carbon::now()->subDays(4),
            ],

            // --- 5 MITRA & VENDOR B2B ---
            [
                'resource_type' => 'partners',
                'title' => 'PT Visual Kreasi Nusantara',
                'description' => 'Mitra penyedia rumah produksi (production house), peralatan kamera cinema, dan kru dokumentasi enterprise berlisensi.',
                'status' => 'active',
                'metadata' => [
                    'category' => 'Production House & Video',
                    'contact' => 'partner@visualkreasi.co.id',
                    'website' => 'https://visualkreasi.co.id',
                ],
                'published_at' => Carbon::now()->subDays(15),
            ],
            [
                'resource_type' => 'partners',
                'title' => 'Studio Grafika Mandiri Indonesia',
                'description' => 'Agensi spesialis desain grafis enterprise, identitas korporat, layout publikasi tahunan, dan packaging design.',
                'status' => 'active',
                'metadata' => [
                    'category' => 'Branding & Graphic Design',
                    'contact' => 'procurement@grafikamandiri.com',
                    'website' => 'https://grafikamandiri.com',
                ],
                'published_at' => Carbon::now()->subDays(20),
            ],
            [
                'resource_type' => 'partners',
                'title' => 'Nusantara Audio & Sound Lab',
                'description' => 'Studio rekaman dan tata suara profesional untuk voice over multibahasa, scoring iklan, dan master sound editing.',
                'status' => 'active',
                'metadata' => [
                    'category' => 'Audio & Sound Engineering',
                    'contact' => 'b2b@nusantarasound.id',
                    'website' => 'https://nusantarasound.id',
                ],
                'published_at' => Carbon::now()->subDays(25),
            ],
            [
                'resource_type' => 'partners',
                'title' => 'Cipta Event Solusindo Enterprise',
                'description' => 'Vendor manajemen MICE, panggung, tata cahaya panggung, sound system line-array konser, dan perizinan event korporat.',
                'status' => 'active',
                'metadata' => [
                    'category' => 'Event Organizer & Production',
                    'contact' => 'corporate@ciptaevent.co.id',
                    'website' => 'https://ciptaevent.co.id',
                ],
                'published_at' => Carbon::now()->subDays(30),
            ],
            [
                'resource_type' => 'partners',
                'title' => 'Pixel Craft Studio 3D & Animation',
                'description' => 'Studio animasi visual efek (VFX), 3D render arsitektural, dan visual interaktif augmented reality.',
                'status' => 'active',
                'metadata' => [
                    'category' => '3D Animation & VFX',
                    'contact' => 'enterprise@pixelcraft.id',
                    'website' => 'https://pixelcraft.id',
                ],
                'published_at' => Carbon::now()->subDays(10),
            ],

            // --- 5 OTORISASI PO & MOU ---
            [
                'resource_type' => 'documents',
                'title' => 'MoU Kerjasama Strategis Penyedia Konten Kreatif Enterprise 2026',
                'description' => 'Nota kesepahaman kemitraan jangka panjang penyediaan layanan kreatif eksklusif dan jaminan SLA 99.8%.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Memorandum of Understanding (MoU)',
                    'document_date' => '2026-01-15',
                    'url' => 'https://docs.kreavana.id/mou-corp-2026-01',
                ],
                'published_at' => Carbon::now()->subDays(40),
            ],
            [
                'resource_type' => 'documents',
                'title' => 'Purchase Order (PO-2026-B2B-042) Pelaksanaan Video Annual Report',
                'description' => 'Surat pesanan resmi pengadaan jasa produksi video laporan tahunan dan paket foto dewan komisaris.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Purchase Order (PO)',
                    'document_date' => '2026-02-10',
                    'url' => 'https://docs.kreavana.id/po-2026-042',
                ],
                'published_at' => Carbon::now()->subDays(35),
            ],
            [
                'resource_type' => 'documents',
                'title' => 'Surat Perjanjian Kerja (SPK) Vendor Booth Pameran Hannover Messe',
                'description' => 'Kontrak kerja spesifik pembuatan instalasi booth delegasi Indonesia pada ajang pameran teknologi industri.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Surat Perintah Kerja (SPK)',
                    'document_date' => '2026-02-28',
                    'url' => 'https://docs.kreavana.id/spk-booth-2026',
                ],
                'published_at' => Carbon::now()->subDays(25),
            ],
            [
                'resource_type' => 'documents',
                'title' => 'Berita Acara Serah Terima (BAST-019) Aset UI/UX & Design System',
                'description' => 'Verifikasi serah terima paket final design token, komponen Figma enterprise, dan dokumentasi guideline.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Berita Acara Serah Terima (BAST)',
                    'document_date' => '2026-03-20',
                    'url' => 'https://docs.kreavana.id/bast-uiux-019',
                ],
                'published_at' => Carbon::now()->subDays(12),
            ],
            [
                'resource_type' => 'documents',
                'title' => 'Non-Disclosure Agreement (NDA) & Klausul Hak Cipta Kekayaan Intelektual',
                'description' => 'Dokumen kerahasiaan data dan kesepakatan peralihan penuh hak cipta karya cipta dari kreator ke korporat.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'NDA & Hak Intelektual',
                    'document_date' => '2026-03-30',
                    'url' => 'https://docs.kreavana.id/nda-ip-transfer-2026',
                ],
                'published_at' => Carbon::now()->subDays(5),
            ],

            // --- 5 ALOKASI ANGGARAN & PAJAK ---
            [
                'resource_type' => 'budgets',
                'title' => 'Pagu Anggaran Kampanye Branding & Rebranding Korporat Q1-Q2',
                'description' => 'Alokasi anggaran khusus untuk transformasi brand visual, kampanye digital eksternal, dan PR release media nasional.',
                'status' => 'in_progress',
                'metadata' => [
                    'period' => '2026',
                    'allocation' => 150000000,
                    'realization' => 112500000,
                ],
                'published_at' => Carbon::now()->subDays(45),
            ],
            [
                'resource_type' => 'budgets',
                'title' => 'Alokasi Produksi Video Profil & Annual Report Perusahaan 2026',
                'description' => 'Anggaran khusus pembuatan aset multimedia pelaporan akuntabilitas keuangan dan operasional pemegang saham.',
                'status' => 'in_progress',
                'metadata' => [
                    'period' => '2026',
                    'allocation' => 75000000,
                    'realization' => 38500000,
                ],
                'published_at' => Carbon::now()->subDays(30),
            ],
            [
                'resource_type' => 'budgets',
                'title' => 'Pagu Anggaran Event Gathering & Customer Appreciation Day',
                'description' => 'Pos belanja penyewaan venue, sound system, show management, bintang tamu, dan honorarium MC profesional.',
                'status' => 'in_progress',
                'metadata' => [
                    'period' => '2026',
                    'allocation' => 90000000,
                    'realization' => 52000000,
                ],
                'published_at' => Carbon::now()->subDays(20),
            ],
            [
                'resource_type' => 'budgets',
                'title' => 'Anggaran Riset Desain Interaktif & Augmented Reality Experience',
                'description' => 'Pendanaan proyek inovasi digital visual interaktif untuk pameran teknologi enterprise B2B.',
                'status' => 'in_progress',
                'metadata' => [
                    'period' => '2026',
                    'allocation' => 60000000,
                    'realization' => 32000000,
                ],
                'published_at' => Carbon::now()->subDays(15),
            ],
            [
                'resource_type' => 'budgets',
                'title' => 'Pencadangan Pajak PPh Pasal 23 & Retensi Pembayaran Jasa Kreatif',
                'description' => 'Rekapitulasi pemotongan dan penyetoran bukti potong PPh 23 (2%) untuk seluruh transaksi pengadaan jasa kreator berbadan usaha/individu.',
                'status' => 'completed',
                'metadata' => [
                    'period' => '2026',
                    'allocation' => 28500000,
                    'realization' => 28500000,
                ],
                'published_at' => Carbon::now()->subDays(5),
            ],

            // --- 5 LAPORAN & AUDIT B2B ---
            [
                'resource_type' => 'reports',
                'title' => 'Laporan Hasil Audit Kualitas Karya & Kepatuhan Vendor Q1 2026',
                'description' => 'Evaluasi kepatuhan spesifikasi teknis karya cipta, ketepatan deadline serah terima, dan feedback pengguna internal.',
                'status' => 'published',
                'metadata' => [
                    'period' => 'Triwulan I 2026',
                    'category' => 'Audit Mutu Vendor',
                    'result' => 'Tingkat kepatuhan vendor 98.4%, 0 sengketa mutu, seluruh aset lulus quality check teknis.',
                ],
                'published_at' => Carbon::now()->subDays(14),
            ],
            [
                'resource_type' => 'reports',
                'title' => 'Laporan Analisis Efektivitas Anggaran Pengadaan Jasa Kreatif',
                'description' => 'Kajian penghematan biaya pengadaan (cost saving) menggunakan platform terpadu Kreavana B2B dibandingkan agen konvensional.',
                'status' => 'published',
                'metadata' => [
                    'period' => 'Semester I 2026',
                    'category' => 'Efisiensi Anggaran',
                    'result' => 'Efisiensi biaya pengadaan mencapai 24.8% dan percepatan waktu kurasi vendor hingga 65%.',
                ],
                'published_at' => Carbon::now()->subDays(20),
            ],
            [
                'resource_type' => 'reports',
                'title' => 'Laporan Kepatuhan Pajak (PPh 23) & Kelengkapan Faktur Mitra B2B',
                'description' => 'Rekapitulasi pelaporan SPT masa pemotongan PPh 23 seluruh invoice kreator/vendor pada sistem escrow.',
                'status' => 'published',
                'metadata' => [
                    'period' => 'Maret 2026',
                    'category' => 'Kepatuhan Fiskal',
                    'result' => '100% invoice terverifikasi faktur pajak dan bukti setor PPh 23 telah diarsip secara digital.',
                ],
                'published_at' => Carbon::now()->subDays(8),
            ],
            [
                'resource_type' => 'reports',
                'title' => 'Laporan Evaluasi SLA (Service Level Agreement) Layanan Produksi Video',
                'description' => 'Pemeriksaan milestone waktu produksi video, jumlah revisi, dan kecepatan respon tim vendor selama proses pra hingga pasca produksi.',
                'status' => 'published',
                'metadata' => [
                    'period' => 'Triwulan I 2026',
                    'category' => 'Evaluasi SLA',
                    'result' => 'Rata-rata penyelesaian 3 hari sebelum tenggat waktu dengan rata-rata revisi minor hanya 1.2 putaran.',
                ],
                'published_at' => Carbon::now()->subDays(10),
            ],
            [
                'resource_type' => 'reports',
                'title' => 'Rekomendasi Strategis Pemilihan Vendor Unggulan Semester 2 2026',
                'description' => 'Analisis komparatif kinerja kreator lokal berbasis rating kepuasan dan rekam jejak untuk prioritas kontrak perpanjangan tahunan.',
                'status' => 'draft',
                'metadata' => [
                    'period' => 'Tahun Anggaran 2026',
                    'category' => 'Riset & Rekomendasi',
                    'result' => '5 vendor direkomendasikan untuk status Preferred Vendor Partner dengan skema retainer berkala.',
                ],
                'published_at' => Carbon::now()->subDays(2),
            ],
        ];

        foreach ($resources as $resData) {
            InstitutionResource::updateOrCreate(
                [
                    'user_id' => $corp->id,
                    'resource_type' => $resData['resource_type'],
                    'title' => $resData['title'],
                ],
                [
                    'description' => $resData['description'],
                    'status' => $resData['status'],
                    'metadata' => $resData['metadata'],
                    'published_at' => $resData['published_at'],
                ]
            );
        }
    }
}
