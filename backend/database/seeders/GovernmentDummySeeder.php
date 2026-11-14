<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\JobContract;
use App\Models\InstitutionResource;
use App\Models\Notification;
use App\Enums\RoleType;
use App\Enums\ContractStatus;
use App\Enums\WorkStatus;
use Carbon\Carbon;

class GovernmentDummySeeder extends Seeder
{
    public function run(): void
    {
        $gov = User::where('username', 'government_demo')->first();
        if (!$gov) {
            $gov = User::where('email', 'government@kreavana.id')->first();
        }

        if (!$gov) {
            $gov = User::where('sub_role', 'government')->first();
        }

        if (!$gov) {
            return;
        }

        self::seedForUser($gov);
    }

    public static function seedForUser(User $gov): void
    {
        // Pastikan sub_role government aktif
        $gov->update([
            'role' => RoleType::Creator,
            'sub_role' => 'government',
        ]);

        \App\Models\UserSubRole::updateOrCreate(
            [
                'user_id' => $gov->id,
                'sub_role_slug' => 'government',
            ],
            [
                'role_type' => RoleType::Creator->value,
                'is_active' => true,
            ]
        );

        $creators = User::where('role', RoleType::Creator)->where('id', '!=', $gov->id)->get();
        $videographer = $creators->firstWhere('username', 'videographer_demo') ?? $creators->first();
        $photographer = $creators->firstWhere('username', 'photographer_demo') ?? $creators->skip(1)->first() ?? $creators->first();
        $editor = $creators->firstWhere('username', 'editor_demo') ?? $creators->skip(2)->first() ?? $creators->first();
        $eo = $creators->firstWhere('username', 'event_organizer_demo') ?? $creators->skip(3)->first() ?? $creators->first();

        // 1. DUMMY 5 PROYEK & KONTRAK PENGADAAN PEMERINTAH (JobContract)
        $contracts = [
            [
                'title' => 'Pengadaan Jasa Video Dokumenter Wisata Daerah & Cagar Budaya',
                'description' => 'Produksi video promosi potensi pariwisata daerah 4K, video teaser media sosial, dan arsip audio-visual cagar budaya daerah.',
                'creator_id' => $videographer?->id ?? $gov->id,
                'agreed_price' => 75000000.00,
                'escrow_amount' => 75000000.00,
                'contract_status' => ContractStatus::Active->value,
                'work_status' => WorkStatus::InProgress->value,
                'deadline' => Carbon::now()->addDays(25)->format('Y-m-d'),
                'scheduled_start_date' => Carbon::now()->subDays(10)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->addDays(25)->format('Y-m-d'),
                'creator_approved' => true,
                'client_approved' => true,
            ],
            [
                'title' => 'Kampanye Publikasi Digital & Infografis APBD Transparan 2026',
                'description' => 'Perancangan 40 aset infografis edukasi APBD, visualisasi data penyerapan anggaran, dan motion graphic kehumasan daerah.',
                'creator_id' => $editor?->id ?? $gov->id,
                'agreed_price' => 42000000.00,
                'escrow_amount' => 42000000.00,
                'contract_status' => ContractStatus::Active->value,
                'work_status' => 'review',
                'deadline' => Carbon::now()->addDays(7)->format('Y-m-d'),
                'scheduled_start_date' => Carbon::now()->subDays(14)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->addDays(7)->format('Y-m-d'),
                'creator_approved' => true,
                'client_approved' => true,
            ],
            [
                'title' => 'Liputan Media & Multi-Camera Live Broadcast Upacara Hari Kemerdekaan',
                'description' => 'Peliputan multi-kamera 6 titik, live streaming broadcast resolusi full HD ke portal daerah, dan dokumentasi foto resmi protokol dinas.',
                'creator_id' => $photographer?->id ?? $gov->id,
                'agreed_price' => 28500000.00,
                'escrow_amount' => 28500000.00,
                'contract_status' => ContractStatus::Completed->value,
                'work_status' => WorkStatus::Completed->value,
                'deadline' => Carbon::now()->subDays(3)->format('Y-m-d'),
                'scheduled_start_date' => Carbon::now()->subDays(7)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->subDays(3)->format('Y-m-d'),
                'creator_approved' => true,
                'client_approved' => true,
            ],
            [
                'title' => 'Penyelenggaraan Festival Ekonomi Kreatif & Expo UMKM Binaan Daerah',
                'description' => 'Event management pameran 3 hari untuk 120 UMKM dan sanggar seni lokal, panggung pertunjukan terbuka, dan tata suara profesional.',
                'creator_id' => $eo?->id ?? $gov->id,
                'agreed_price' => 110000000.00,
                'escrow_amount' => 110000000.00,
                'contract_status' => ContractStatus::Active->value,
                'work_status' => WorkStatus::Scheduled->value,
                'deadline' => Carbon::now()->addDays(40)->format('Y-m-d'),
                'scheduled_start_date' => Carbon::now()->addDays(15)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->addDays(40)->format('Y-m-d'),
                'creator_approved' => true,
                'client_approved' => true,
            ],
            [
                'title' => 'Revitalisasi Brand Identity & Maskot Resmi Pekan Olahraga Daerah',
                'description' => 'Pembuatan panduan identitas visual (brand guideline) 90 halaman, aset 3D maskot animasi, dan desain seragam kontingen.',
                'creator_id' => $editor?->id ?? $gov->id,
                'agreed_price' => 35000000.00,
                'escrow_amount' => 35000000.00,
                'contract_status' => ContractStatus::Completed->value,
                'work_status' => WorkStatus::Completed->value,
                'deadline' => Carbon::now()->subDays(15)->format('Y-m-d'),
                'scheduled_start_date' => Carbon::now()->subDays(45)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->subDays(15)->format('Y-m-d'),
                'creator_approved' => true,
                'client_approved' => true,
            ],
        ];

        foreach ($contracts as $cData) {
            JobContract::updateOrCreate(
                [
                    'client_id' => $gov->id,
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

        // 2. DUMMY DATA MODUL PENGELOLAAN PEMERINTAH (InstitutionResource)
        $resources = [
            // --- 5 TENDER & PENGADAAN (RFP / LPSE PEMERINTAH) ---
            [
                'resource_type' => 'tenders',
                'title' => 'LPSE-2026-001: Pengadaan Jasa Produksi Film Dokumenter Potensi Daerah',
                'description' => 'Pengadaan terbuka jasa rumah produksi kreatif untuk pembuatan film dokumenter 45 menit bertema warisan sejarah dan potensi ekowisata pesisir.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Video & Multimedia',
                    'budget' => 85000000,
                    'deadline' => '2026-11-20',
                    'procurement_code' => 'TND-PEMDA-2026-01',
                    'unit' => 'Dinas Pariwisata dan Kebudayaan',
                ],
                'published_at' => Carbon::now()->subDays(3),
            ],
            [
                'resource_type' => 'tenders',
                'title' => 'LPSE-2026-002: Tender Desain Maskot 3D & Jingle Resmi Porda 2026',
                'description' => 'Seleksi vendor studio desain grafis dan komposer audio untuk memproduksi maskot 3D karakter fauna endemik dan jingle mars resmi perhelatan akbar olahraga daerah.',
                'status' => 'in_progress',
                'metadata' => [
                    'category' => 'Desain 3D & Audio',
                    'budget' => 60000000,
                    'deadline' => '2026-10-30',
                    'procurement_code' => 'TND-PEMDA-2026-02',
                    'unit' => 'Dinas Pemuda dan Olahraga',
                ],
                'published_at' => Carbon::now()->subDays(8),
            ],
            [
                'resource_type' => 'tenders',
                'title' => 'LPSE-2026-003: Pengadaan Konsultan Revamp Portal Informasi Publik & Infografis APBD',
                'description' => 'Pengadaan konsultan perancangan antarmuka (UI/UX) dan sistem infografis digital transparan untuk keterbukaan informasi publik bagi masyarakat.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'UI/UX & Desain Grafis',
                    'budget' => 95000000,
                    'deadline' => '2026-12-05',
                    'procurement_code' => 'TND-PEMDA-2026-03',
                    'unit' => 'Dinas Komunikasi dan Informatika',
                ],
                'published_at' => Carbon::now()->subDays(2),
            ],
            [
                'resource_type' => 'tenders',
                'title' => 'LPSE-2026-004: Tender Vendor Event Organizer Expo UMKM Kreatif Nusantara',
                'description' => 'Pengadaan event organizer bersertifikasi untuk menyelenggarakan pameran akbar produk ekonomi kreatif nusantara selama 4 hari penuh.',
                'status' => 'completed',
                'metadata' => [
                    'category' => 'Event Management & Expo',
                    'budget' => 145000000,
                    'deadline' => '2026-09-30',
                    'procurement_code' => 'TND-PEMDA-2026-04',
                    'unit' => 'Dinas Koperasi dan UKM',
                ],
                'published_at' => Carbon::now()->subDays(25),
            ],
            [
                'resource_type' => 'tenders',
                'title' => 'LPSE-2026-005: Dokumentasi Drone & Pemetaan Fotogrametri Cagar Budaya',
                'description' => 'Pengadaan jasa pilot drone berlisensi dan pemetaan 3D orthophoto digital untuk restorasi dan inventarisasi 15 cagar budaya bersejarah.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Drone & Fotogrametri',
                    'budget' => 52000000,
                    'deadline' => '2026-11-15',
                    'procurement_code' => 'TND-PEMDA-2026-05',
                    'unit' => 'Balai Pelestarian Kebudayaan',
                ],
                'published_at' => Carbon::now()->subDays(5),
            ],

            // --- 5 MITRA & KOMUNITAS BINAAN PEMERINTAH ---
            [
                'resource_type' => 'partners',
                'title' => 'Sanggar Tari & Seni Budaya Swara Mahardika',
                'description' => 'Sanggar seni mitra resmi kebudayaan daerah dalam penyediaan tari sambutan kenegaraan, gamelan klasik, dan pelestarian seni tradisional.',
                'status' => 'active',
                'metadata' => [
                    'category' => 'Seni Pertunjukan & Tari Tradisional',
                    'contact' => '081298341101',
                    'phone' => '081298341101',
                    'email' => 'swaramahardika@mitrapemda.go.id',
                    'website' => 'https://swaramahardika.or.id',
                    'institution_type' => 'Sanggar Binaan Dinas Kebudayaan',
                ],
                'published_at' => Carbon::now()->subDays(18),
            ],
            [
                'resource_type' => 'partners',
                'title' => 'Asosiasi Desainer Grafis Daerah (ADGD)',
                'description' => 'Wadah perkumpulan profesional desainer grafis lokal untuk kemitraan perancangan materi sosialisasi publik, branding UMKM, dan kurikulum vokasi.',
                'status' => 'active',
                'metadata' => [
                    'category' => 'Komunitas Desain & Grafika',
                    'contact' => '081387654321',
                    'phone' => '081387654321',
                    'email' => 'sekretariat@adgd.or.id',
                    'website' => 'https://adgd.or.id',
                    'institution_type' => 'Asosiasi Profesi Mitra Dispora',
                ],
                'published_at' => Carbon::now()->subDays(22),
            ],
            [
                'resource_type' => 'partners',
                'title' => 'Komunitas Sinema & Sineas Muda Nusantara',
                'description' => 'Komunitas sineas independen mitra produksi film edukasi layanan masyarakat, festival film pendek daerah, dan workshop videografi pemula.',
                'status' => 'active',
                'metadata' => [
                    'category' => 'Film & Sinematografi',
                    'contact' => '081198765432',
                    'phone' => '081198765432',
                    'email' => 'info@sinemamuda.org',
                    'website' => 'https://sinemamuda.org',
                    'institution_type' => 'Komunitas Kreatif Binaan Diskominfo',
                ],
                'published_at' => Carbon::now()->subDays(14),
            ],
            [
                'resource_type' => 'partners',
                'title' => 'Dewan Kesenian & Budaya Daerah',
                'description' => 'Lembaga independen pembina kesenian daerah yang bertindak sebagai dewan penilai kuratorial karya seni dan perhelatan budaya resmi.',
                'status' => 'active',
                'metadata' => [
                    'category' => 'Kuratorial & Dewan Kesenian',
                    'contact' => '081211223344',
                    'phone' => '081211223344',
                    'email' => 'dewan.kesenian@pemda.go.id',
                    'website' => 'https://dewankesenian.go.id',
                    'institution_type' => 'Lembaga Kesenian Daerah',
                ],
                'published_at' => Carbon::now()->subDays(30),
            ],
            [
                'resource_type' => 'partners',
                'title' => 'Forum Pewarta Foto & Jurnalis Visual Pemerintah',
                'description' => 'Jejaring fotografer jurnalistik terakreditasi untuk liputan resmi protokoler pimpinan daerah, kearsipan visual, dan pameran foto pembangunan.',
                'status' => 'active',
                'metadata' => [
                    'category' => 'Fotografi Jurnalistik & Protokol',
                    'contact' => '081233445566',
                    'phone' => '081233445566',
                    'email' => 'pewartafoto@humas.pemda.go.id',
                    'website' => 'https://pewartafoto.go.id',
                    'institution_type' => 'Forum Jurnalistik Resmi',
                ],
                'published_at' => Carbon::now()->subDays(10),
            ],

            // --- 5 LAPORAN KEGIATAN & KINERJA (LAKIP) ---
            [
                'resource_type' => 'reports',
                'title' => 'LAKIP 2026: Laporan Akuntabilitas Kinerja Bidang Ekonomi Kreatif Triwulan I',
                'description' => 'Laporan komprehensif realisasi fisik, evaluasi IKU dinas, penyerapan anggaran pengadaan kreatif, dan kepuasan penerima manfaat program.',
                'status' => 'published',
                'metadata' => [
                    'period' => 'Triwulan I 2026',
                    'category' => 'Laporan Akuntabilitas Kinerja (LAKIP)',
                    'result' => 'Tingkat kepuasan publik 92.4%, penyerapan anggaran mencapai 96.8% dari target kuartal.',
                    'doc_number' => 'LAKIP-EKRAF/2026/01',
                    'signatory' => 'Kepala Dinas Pariwisata & Ekonomi Kreatif',
                ],
                'published_at' => Carbon::now()->subDays(5),
            ],
            [
                'resource_type' => 'reports',
                'title' => 'Laporan Evaluasi Pelaksanaan Festival Seni Budaya Nusantara 2026',
                'description' => 'Dokumen pertanggungjawaban kegiatan festival seni budaya mencakup rekap kehadiran 15.000 pengunjung, perputaran ekonomi UMKM, dan siaran pers.',
                'status' => 'published',
                'metadata' => [
                    'period' => 'Semester I 2026',
                    'category' => 'Evaluasi Penyelenggaraan Event',
                    'result' => 'Perputaran transaksi UMKM lokal tercatat Rp 1,8 Milyar selama 3 hari festival.',
                    'doc_number' => 'LAP-FEST/04/2026',
                    'signatory' => 'Ketua Panitia Pelaksana & PPK',
                ],
                'published_at' => Carbon::now()->subDays(12),
            ],
            [
                'resource_type' => 'reports',
                'title' => 'Laporan Kinerja Fasilitasi Hak Kekayaan Intelektual (HKI) Kreator Lokal',
                'description' => 'Pencatatan 85 sertifikat hak cipta dan merek dagang bagi kreator seni rupa, musik, dan desain grafis yang didanai pemerintah daerah.',
                'status' => 'published',
                'metadata' => [
                    'period' => 'Tahap I 2026',
                    'category' => 'Fasilitasi HKI & Legalitas',
                    'result' => '85 Sertifikat HKI terbit resmi melalui Kemenkumham tanpa kendala.',
                    'doc_number' => 'LAP-HKI/2026/02',
                    'signatory' => 'Kepala Bidang Fasilitasi HKI',
                ],
                'published_at' => Carbon::now()->subDays(20),
            ],
            [
                'resource_type' => 'reports',
                'title' => 'Laporan Monitoring Pelatihan Vokasi & Sertifikasi Kompetensi Kreator',
                'description' => 'Evaluasi kelulusan uji kompetensi BNSP bagi 120 kreator videografi dan fotografi pemula binaan balai pelatihan kerja daerah.',
                'status' => 'published',
                'metadata' => [
                    'period' => 'Triwulan II 2026',
                    'category' => 'Pelatihan & Vokasi Kreatif',
                    'result' => 'Tingkat kelulusan sertifikasi BNSP mencapai 98.3% (118 peserta kompeten).',
                    'doc_number' => 'LAP-VOKASI/06/2026',
                    'signatory' => 'Kepala Balai Pelatihan Vokasi',
                ],
                'published_at' => Carbon::now()->subDays(2),
            ],
            [
                'resource_type' => 'reports',
                'title' => 'Laporan Pengawasan Kepatuhan Pajak & Administrasi Pengadaan Vendor (Draft)',
                'description' => 'Laporan review kepatuhan pemotongan PPh Pasal 23, validitas faktur pajak, dan kelengkapan dokumen BAST pengadaan jasa kreatif.',
                'status' => 'draft',
                'metadata' => [
                    'period' => 'Bulan Berjalan',
                    'category' => 'Audit Kepatuhan Pajak & Administrasi',
                    'result' => 'Semua SP2D terverifikasi patuh terhadap aturan perpajakan pengadaan barang/jasa.',
                    'doc_number' => 'DRAFT-AUDIT-TAX/2026',
                    'signatory' => 'Inspektorat Daerah / Auditor Internal',
                ],
                'published_at' => Carbon::now()->subDays(1),
            ],

            // --- 5 REALISASI ANGGARAN APBD / DIPA PEMERINTAH ---
            [
                'resource_type' => 'budgets',
                'title' => 'DIPA-01: Pos Anggaran Publikasi & Kehumasan Kedinasan 2026',
                'description' => 'Alokasi belanja jasa kehumasan, pembuatan materi publikasi media cetak/digital, infografis layanan publik, dan siaran langsung.',
                'status' => 'in_progress',
                'metadata' => [
                    'period' => 'TA 2026',
                    'allocation' => 280000000,
                    'realization' => 218500000,
                    'category' => 'Belanja Jasa Publikasi & Humas',
                    'percentage' => 78.0,
                    'code' => '5.1.02.02.01.0026',
                ],
                'published_at' => Carbon::now()->subDays(30),
            ],
            [
                'resource_type' => 'budgets',
                'title' => 'DIPA-02: Dana Bantuan Pembinaan Sanggar Seni & Komunitas Budaya',
                'description' => 'Pos belanja hibah barang dan fasilitasi sarana pertunjukan bagi 25 sanggar seni tradisional dan paguyuban kesenian lokal.',
                'status' => 'in_progress',
                'metadata' => [
                    'period' => 'TA 2026',
                    'allocation' => 150000000,
                    'realization' => 125000000,
                    'category' => 'Hibah & Pembinaan Sanggar Budaya',
                    'percentage' => 83.3,
                    'code' => '5.1.05.01.02.0014',
                ],
                'published_at' => Carbon::now()->subDays(30),
            ],
            [
                'resource_type' => 'budgets',
                'title' => 'DIPA-03: Belanja Modal Pengadaan Konten Media Interaktif & Digital',
                'description' => 'Pagu anggaran pembuatan aset 3D animasi edukasi cagar budaya dan virtual tour museum daerah resolusi ultra high-definition.',
                'status' => 'in_progress',
                'metadata' => [
                    'period' => 'TA 2026',
                    'allocation' => 380000000,
                    'realization' => 245000000,
                    'category' => 'Belanja Modal Media Kreatif',
                    'percentage' => 64.5,
                    'code' => '5.2.02.08.01.0005',
                ],
                'published_at' => Carbon::now()->subDays(30),
            ],
            [
                'resource_type' => 'budgets',
                'title' => 'DIPA-04: Fasilitasi Hak Cipta & Uji Sertifikasi Kompetensi Kreator',
                'description' => 'Pos pembiayaan pendaftaran hak cipta gratis bagi kreator lokal dan uji sertifikasi BNSP profesi fotografi & videografi.',
                'status' => 'completed',
                'metadata' => [
                    'period' => 'TA 2026',
                    'allocation' => 95000000,
                    'realization' => 92500000,
                    'category' => 'Fasilitasi HKI & Sertifikasi BNSP',
                    'percentage' => 97.4,
                    'code' => '5.1.02.02.01.0088',
                ],
                'published_at' => Carbon::now()->subDays(40),
            ],
            [
                'resource_type' => 'budgets',
                'title' => 'DIPA-05: Penyelenggaraan Event Budaya & Expo Kreatif Tahunan',
                'description' => 'Alokasi pelaksanaan perhelatan akbar pekan kebudayaan, panggung kreasi nusantara, dan pameran kriya ekonomi kreatif.',
                'status' => 'in_progress',
                'metadata' => [
                    'period' => 'TA 2026',
                    'allocation' => 450000000,
                    'realization' => 395000000,
                    'category' => 'Belanja Penyelenggaraan Event Akbar',
                    'percentage' => 87.8,
                    'code' => '5.1.02.04.01.0019',
                ],
                'published_at' => Carbon::now()->subDays(30),
            ],

            // --- 5 MONITORING & EVALUASI PROGRAM (MONEV) ---
            [
                'resource_type' => 'monitoring',
                'title' => 'Monev Program Inkubasi 100 Kreator Digital Daerah',
                'description' => 'Pemantauan tahapan mentoring intensif, penyerapan modul pelatihan, dan penciptaan karya komersial oleh 100 kreator terpilih.',
                'status' => 'in_progress',
                'metadata' => [
                    'indicator' => 'Persentase kelulusan portofolio komersial siap pakai',
                    'progress' => 85,
                    'target_date' => '2026-11-30',
                    'supervisor' => 'Bidang Pengembangan SDM Kreatif',
                ],
                'published_at' => Carbon::now()->subDays(10),
            ],
            [
                'resource_type' => 'monitoring',
                'title' => 'Monitoring Penyerapan Dana Hibah Sanggar Seni Tradisional',
                'description' => 'Pengawasan fisik penggunaan dana fasilitasi peralatan musik, kostum tari, dan pementasan seni pada 25 sanggar penerima hibah.',
                'status' => 'in_progress',
                'metadata' => [
                    'indicator' => 'Kelengkapan SPJ dan verifikasi fisik perlengkapan sanggar',
                    'progress' => 92,
                    'target_date' => '2026-12-15',
                    'supervisor' => 'Seksi Kesenian Tradisional Disbud',
                ],
                'published_at' => Carbon::now()->subDays(15),
            ],
            [
                'resource_type' => 'monitoring',
                'title' => 'Evaluasi Efektivitas Kampanye Sadar Pajak & Layanan Publik Digital',
                'description' => 'Audit performa jangkauan konten video animasi dan infografis kehumasan pada saluran media sosial resmi pemerintah daerah.',
                'status' => 'completed',
                'metadata' => [
                    'indicator' => 'Jangkauan tayangan publik & peningkatan kepatuhan wajib pajak',
                    'progress' => 100,
                    'target_date' => '2026-10-10',
                    'supervisor' => 'Badan Pendapatan Daerah (Bapenda)',
                ],
                'published_at' => Carbon::now()->subDays(8),
            ],
            [
                'resource_type' => 'monitoring',
                'title' => 'Survei Kepuasan Publik terhadap Layanan Informasi Kreatif Pemda',
                'description' => 'Pengumpulan data kuesioner indeks kepuasan masyarakat (IKM) terhadap kemudahan akses informasi lelang dan program fasilitasi.',
                'status' => 'in_progress',
                'metadata' => [
                    'indicator' => 'Indeks Kepuasan Masyarakat (IKM) minimal predikat Sangat Baik',
                    'progress' => 74,
                    'target_date' => '2026-11-25',
                    'supervisor' => 'Bagian Organisasi & Tata Laksana',
                ],
                'published_at' => Carbon::now()->subDays(6),
            ],
            [
                'resource_type' => 'monitoring',
                'title' => 'Audit Mutu & Kinerja Vendor Dokumentasi Publikasi Daerah',
                'description' => 'Pengecekan kualitas berkas resolusi video, ketepatan jadwal penyerahan materi liputan, dan ketaatan protokol kerahasiaan data.',
                'status' => 'in_progress',
                'metadata' => [
                    'indicator' => 'Kesesuaian spesifikasi teknis Kerangka Acuan Kerja (KAK)',
                    'progress' => 88,
                    'target_date' => '2026-12-01',
                    'supervisor' => 'Pejabat Pembuat Komitmen (PPK)',
                ],
                'published_at' => Carbon::now()->subDays(4),
            ],

            // --- 5 DOKUMEN RESMI & MOU INSTANSI ---
            [
                'resource_type' => 'documents',
                'title' => 'MoU Kerjasama Kemitraan Strategis Platform Kreavana & Dinas Pariwisata',
                'description' => 'Nota kesepahaman resmi pemanfaatan ekosistem digital Kreavana untuk pengadaan vendor terverifikasi dan pembinaan talenta seni daerah.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Nota Kesepahaman (MoU)',
                    'document_date' => '2026-08-15',
                    'doc_number' => '100.3.7/MOU-DISPAR/2026',
                    'url' => 'https://docs.kreavana.id/pemda/mou-kemitraan-2026.pdf',
                    'author' => 'Bupati / Kepala Dinas Pariwisata',
                ],
                'published_at' => Carbon::now()->subDays(45),
            ],
            [
                'resource_type' => 'documents',
                'title' => 'Surat Keputusan (SK) Penetapan Pemenang Tender Film Dokumenter Daerah',
                'description' => 'Surat keputusan resmi penetapan penyedia jasa terpilih hasil evaluasi kualifikasi administrasi, teknis, dan penawaran harga LPSE.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Surat Keputusan (SK)',
                    'document_date' => '2026-09-28',
                    'doc_number' => 'SK-POKJA/024/DISBUD/2026',
                    'url' => 'https://docs.kreavana.id/pemda/sk-pemenang-tender-01.pdf',
                    'author' => 'Pokja Pemilihan Pengadaan Barang/Jasa',
                ],
                'published_at' => Carbon::now()->subDays(20),
            ],
            [
                'resource_type' => 'documents',
                'title' => 'Peraturan Daerah (Perda) No. 4/2026 tentang Pengembangan Ekonomi Kreatif',
                'description' => 'Payung hukum legalitas fasilitasi permodalan, perlindungan karya intelektual, dan alokasi anggaran belanja daerah bagi pelaku kreatif lokal.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Peraturan Daerah (Perda)',
                    'document_date' => '2026-05-10',
                    'doc_number' => 'PERDA-NO-4-TAHUN-2026',
                    'url' => 'https://jdih.pemda.go.id/produk-hukum/perda-4-2026.pdf',
                    'author' => 'DPRD & Pemerintah Daerah',
                ],
                'published_at' => Carbon::now()->subDays(60),
            ],
            [
                'resource_type' => 'documents',
                'title' => 'Standar Operasional Prosedur (SOP) Kerjasama Kreator & Vendor Eksternal',
                'description' => 'Petunjuk teknis pengajuan proposal, verifikasi legalitas NIB/NPWP vendor, serah terima berkas digital, dan tata cara penagihan SP2D.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Standar Operasional Prosedur (SOP)',
                    'document_date' => '2026-07-01',
                    'doc_number' => 'SOP-PENGADAAN/KREAVANA/2026',
                    'url' => 'https://docs.kreavana.id/pemda/sop-pengadaan-kreatif.pdf',
                    'author' => 'Inspektorat & Bagian Pengadaan Barang/Jasa',
                ],
                'published_at' => Carbon::now()->subDays(35),
            ],
            [
                'resource_type' => 'documents',
                'title' => 'Berita Acara Serah Terima (BAST) Pekerjaan Liputan Video Multi-Kamera',
                'description' => 'Dokumen resmi bukti serah terima hasil master video 4K, foto arsip resolusi tinggi, dan pengesahan pencairan anggaran termin akhir.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Berita Acara Serah Terima (BAST)',
                    'document_date' => '2026-10-12',
                    'doc_number' => 'BAST-019/KONTRAK-PROT/2026',
                    'url' => 'https://docs.kreavana.id/pemda/bast-liputan-upacara.pdf',
                    'author' => 'Pejabat Pembuat Komitmen & Direktur Vendor',
                ],
                'published_at' => Carbon::now()->subDays(4),
            ],

            // --- 5 PENGUMUMAN PUBLIK & SIARAN PERS KEDINASAN ---
            [
                'resource_type' => 'announcements',
                'title' => 'Pengumuman Resmi: Pendaftaran Terbuka Program Hibah Karya Kreatif 2026',
                'description' => 'Pemerintah daerah mengundang kreator, animator, komposer, dan videografer lokal untuk mengajukan proposal karya kreatif dengan pagu hibah hingga Rp 25 Juta per karya.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Program Bantuan & Hibah',
                    'valid_until' => '2026-11-30',
                    'issuer' => 'Dinas Pariwisata dan Ekonomi Kreatif',
                    'target_audience' => 'Seluruh Kreator & Sanggar Seni Terdaftar',
                ],
                'published_at' => Carbon::now()->subDays(3),
            ],
            [
                'resource_type' => 'announcements',
                'title' => 'Siaran Pers: Peluncuran Gerakan Kreator Lokal Masuk Ekosistem Pengadaan Pemerintah',
                'description' => 'Inisiatif strategis pemda mewajibkan alokasi minimal 30% pengadaan materi promosi dan dokumentasi kedinasan bermitra langsung dengan talenta terdaftar di Kreavana.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Siaran Pers Resmi',
                    'valid_until' => '2026-12-31',
                    'issuer' => 'Biro Administrasi Pimpinan & Humas Pemda',
                    'target_audience' => 'Publik & Media Massa',
                ],
                'published_at' => Carbon::now()->subDays(7),
            ],
            [
                'resource_type' => 'announcements',
                'title' => 'Pemberitahuan Hasil Seleksi Administrasi Vendor Kreatif Terverifikasi LPSE',
                'description' => 'Daftar 42 vendor dan rumah produksi yang dinyatakan lolos verifikasi administrasi kualifikasi pengadaan jasa kehumasan dan multimedia tahun anggaran 2026.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Hasil Seleksi & Tender',
                    'valid_until' => '2026-11-15',
                    'issuer' => 'Unit Kerja Pengadaan Barang/Jasa (UKPBJ)',
                    'target_audience' => 'Peserta Tender LPSE Terdaftar',
                ],
                'published_at' => Carbon::now()->subDays(10),
            ],
            [
                'resource_type' => 'announcements',
                'title' => 'Jadwal Sosialisasi Pemanfaatan Platform Kreavana untuk OPD dan Kecamatan',
                'description' => 'Undangan bimbingan teknis pembuatan kebutuhan kreatif (RFP) bagi pejabat pengadaan di seluruh Organisasi Perangkat Daerah dan kantor kecamatan.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Bimbingan Teknis & Sosialisasi',
                    'valid_until' => '2026-11-05',
                    'issuer' => 'Dinas Komunikasi dan Informatika',
                    'target_audience' => 'Pejabat Pengadaan & Operator OPD',
                ],
                'published_at' => Carbon::now()->subDays(5),
            ],
            [
                'resource_type' => 'announcements',
                'title' => 'Undangan Terbuka Diskusi Publik Arah Kebijakan Ekonomi Kreatif Daerah',
                'description' => 'Forum rembug kreatif bersama pimpinan daerah, asosiasi kreator, dan akademisi dalam rangka penyusunan Rencana Induk Pengembangan Ekonomi Kreatif Daerah 2026-2030.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Forum & Diskusi Kebijakan',
                    'valid_until' => '2026-11-20',
                    'issuer' => 'Bappeda & Dinas Pariwisata',
                    'target_audience' => 'Pelaku Kreatif, Akademisi, dan Tokoh Budaya',
                ],
                'published_at' => Carbon::now()->subDays(2),
            ],

            // --- 5 FASILITAS & VENUE DAERAH (AKSES LOKASI & SARANA KREATIF) ---
            [
                'resource_type' => 'facilities',
                'title' => 'Gedung Graha Kesenian Daerah & Teater Terbuka',
                'description' => 'Gedung pertunjukan seni berpendingin udara lengkap dengan tata suara line-array 20kW, lighting panggung DMX terintegrasi, dan ruang rias VIP yang dapat dipinjamkan untuk festival/pementasan kreator.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Gedung Pertunjukan & Teater',
                    'capacity' => '850 Kursi Penonton',
                    'location' => 'Jl. Pemuda No. 12, Kompleks Budaya Daerah',
                    'facilities' => 'Sound System 20kW, 40 Unit Moving Head Lighting, Ruang Ganti VIP, Genset Cadangan 150kVA',
                    'terms' => 'Pengajuan H-14 melalui surat permohonan resmi atau kolaborasi kemitraan dinas.',
                    'manager' => 'UPT Pengelolaan Sarana Kebudayaan',
                ],
                'published_at' => Carbon::now()->subDays(12),
            ],
            [
                'resource_type' => 'facilities',
                'title' => 'Creative Hub & Studio Multimedia Kominfo',
                'description' => 'Fasilitas studio produksi audio visual dan ruang podcast profesional milik pemda yang disediakan gratis untuk pelatihan, rekaman kreator binaan, dan editing karya digital.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Studio Rekaman & Multimedia',
                    'capacity' => '40 Workstation Editing + 2 Bilik Podcast',
                    'location' => 'Gedung Smart City Pemda Lt. 3',
                    'facilities' => 'Apple Mac Studio M2, Kamera Cinema 4K, Mikrofon Shure SM7B, Green Screen 6x4m',
                    'terms' => 'Wajib memiliki akun Kreator terdaftar di Kreavana dan portofolio aktif.',
                    'manager' => 'Dinas Komunikasi, Informatika dan Persandian',
                ],
                'published_at' => Carbon::now()->subDays(15),
            ],
            [
                'resource_type' => 'facilities',
                'title' => 'Amphiteater Budaya Taman Kota Terbuka',
                'description' => 'Panggung terbuka di jantung taman kota yang cocok untuk festival musik etnik, parade teater rakyat, pameran instalasi seni luar ruang, dan street art performance.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Panggung Terbuka & Festival',
                    'capacity' => '2.500 Pengunjung',
                    'location' => 'Kawasan Hutan Kota Terbuka, Sektor Barat',
                    'facilities' => 'Panggung Rigging 12x10m, Titik Daya Listrik 60A 3-Phase, Akses Parkir Bus & Pengunjung',
                    'terms' => 'Peminjaman non-komersial bebas retribusi untuk agenda kebudayaan daerah.',
                    'manager' => 'Dinas Lingkungan Hidup & Dinas Pariwisata',
                ],
                'published_at' => Carbon::now()->subDays(20),
            ],
            [
                'resource_type' => 'facilities',
                'title' => 'Galeri Seni Rupa & Balai Pameran Daerah',
                'description' => 'Ruang pameran standar kuratorial internasional dengan sistem pencahayaan track light fleksibel, pengaturan kelembaban stabil, dan sistem partisi modular untuk pameran lukisan, patung, dan kriya.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Galeri Seni & Exhibition Hall',
                    'capacity' => '400 Pengunjung Sekaligus / 120 Titik Display',
                    'location' => 'Pusat Kerajinan dan Seni Daerah Kav. 4',
                    'facilities' => 'Track Light LED CRI 95+, Partisi Bergerak Kayu Jati, Sistem Keamanan CCTV 24 Jam',
                    'terms' => 'Karya yang dipamerkan telah lolos kurasi Dewan Kesenian Daerah.',
                    'manager' => 'Dinas Perindustrian, Perdagangan dan Koperasi',
                ],
                'published_at' => Carbon::now()->subDays(8),
            ],
            [
                'resource_type' => 'facilities',
                'title' => 'Coworking Space & Inkubator Kreator Pemda',
                'description' => 'Ruang kerja bersama gratis dilengkapi akses internet dedicated 500 Mbps, ruang meeting presentasi pitching ke investor, dan perpustakaan literatur kreatif.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Coworking & Ruang Kolaborasi',
                    'capacity' => '60 Meja Kolaboratif + 3 Ruang Rapat',
                    'location' => 'Gedung Balai Pemuda Lt. 2',
                    'facilities' => 'WiFi 500 Mbps, Layar Interaktif Smart Board 75 Inch, Free Flow Coffee & Air Minum',
                    'terms' => 'Dapat digunakan setiap hari kerja pukul 08.00 - 21.00 WIB.',
                    'manager' => 'Dinas Pemuda, Olahraga dan Ekonomi Kreatif',
                ],
                'published_at' => Carbon::now()->subDays(5),
            ],

            // --- 5 LAPORAN DAMPAK PUBLIK & KISAH KEBERHASILAN (LANGKAH 6 EVALUASI REPUTASI) ---
            [
                'resource_type' => 'reports',
                'title' => 'Laporan Dampak Publik: Festival Seni Nusantara & Expo Ekraf 2026',
                'description' => 'Evaluasi menyeluruh pelaksanaan festival kebudayaan daerah tahun 2026 yang berhasil memberdayakan 92 sanggar seni lokal dan menggerakkan perputaran ekonomi kreatif sebesar Rp 1,45 Miliar.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Evaluasi Dampak Program & Festival',
                    'period' => 'Triwulan I 2026',
                    'beneficiaries' => '14.500 Pengunjung & 92 Sanggar Seni',
                    'economic_impact' => 'Rp 1.450.000.000 (Perputaran Omset)',
                    'satisfaction_rate' => '98.4% Indeks Kepuasan Masyarakat',
                    'testimonial_author' => 'Ki Suryo Sasongko (Ketua Sanggar Swara Mahardika)',
                    'testimonial_quote' => 'Kolaborasi lewat Kreavana memotong jalur birokrasi yang berbelit. Kami menerima kepastian anggaran, panggung representatif, dan pembinaan profesional.',
                    'verified_badge' => 'LAKIP SAKIP Grade A+',
                ],
                'published_at' => Carbon::now()->subDays(4),
            ],
            [
                'resource_type' => 'reports',
                'title' => 'Kisah Keberhasilan: Revitalisasi Brand Identity & Packaging 120 UMKM Binaan',
                'description' => 'Hasil kolaborasi dinas bersama 35 desainer grafis muda Kreavana dalam meredesain kemasan dan materi promosi 120 produk pangan lokal unggulan daerah.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Pemberdayaan UMKM & Desain',
                    'period' => 'Semester I 2026',
                    'beneficiaries' => '120 UMKM Kuliner & Kriya Binaan',
                    'economic_impact' => 'Peningkatan Rata-rata Penjualan +42%',
                    'satisfaction_rate' => '99.1% Pelaku Usaha Puas',
                    'testimonial_author' => 'Hj. Endang Rahayu (Ketua Paguyuban Kripik Singkong Juara)',
                    'testimonial_quote' => 'Dulu produk kami ditolak masuk toko oleh-oleh modern karena bungkusnya polos. Setelah didesainkan oleh anak muda Kreavana, pesanan kami naik 3 kali lipat!',
                    'verified_badge' => 'Program Unggulan Dekranasda',
                ],
                'published_at' => Carbon::now()->subDays(9),
            ],
            [
                'resource_type' => 'reports',
                'title' => 'Laporan Kinerja Program: Arsip Digital Sinematik Cagar Budaya & WBTb',
                'description' => 'Dokumentasi audio-visual berkualitas 4K dan tur virtual 360 derajat untuk 15 objek cagar budaya takbenda yang kini dapat diakses pelajar dan wisatawan global.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Pelestarian Budaya & Multimedia',
                    'period' => 'TA 2026',
                    'beneficiaries' => '280.000+ Penonton Kanal Edukasi Publik',
                    'economic_impact' => 'Peningkatan Kunjungan Situs Wisata Sejarah +28%',
                    'satisfaction_rate' => '97.8% Respon Positif Netizen',
                    'testimonial_author' => 'Aris Budiman (Sutradara Rumah Produksi Sineas Nusantara)',
                    'testimonial_quote' => 'Pemerintah daerah memberikan kebebasan kreatif bagi sutradara lokal namun tetap menjaga akurasi sejarah. Ini sinergi pemerintah dan kreator yang luar biasa.',
                    'verified_badge' => 'Penghargaan Anugerah Kebudayaan 2026',
                ],
                'published_at' => Carbon::now()->subDays(14),
            ],
            [
                'resource_type' => 'reports',
                'title' => 'Evaluasi Vokasi Kreatif: Pelatihan Fotografi Produk & Konten Kreator Pemuda Desa',
                'description' => 'Rangkaian bimbingan intensif selama 2 pekan bagi 500 pemuda desa dan santri untuk membekali keterampilan produksi konten promosi potensi desa wisata.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Pelatihan Vokasi & Kapasitas Pemuda',
                    'period' => 'Februari - Maret 2026',
                    'beneficiaries' => '488 Pemuda Desa Lulus Uji Kompetensi',
                    'economic_impact' => '135 Peserta Langsung Menerima Jasa Pembuatan Konten',
                    'satisfaction_rate' => '96.9% Kepuasan Peserta Pelatihan',
                    'testimonial_author' => 'Faisal Rahman (Peserta dari Desa Wisata Karanganyar)',
                    'testimonial_quote' => 'Pelatihan ini gratis, kami diajari pakai kamera profesional, dan sekarang desa kami punya akun sosmed yang mendatangkan ribuan wisatawan tiap akhir pekan.',
                    'verified_badge' => 'Sertifikasi BNSP Ekraf',
                ],
                'published_at' => Carbon::now()->subDays(21),
            ],
            [
                'resource_type' => 'reports',
                'title' => 'Kisah Sukses: Sayembara Terbuka Maskot & Jingle Resmi Porda 2026',
                'description' => 'Sayembara desain terbuka yang melibatkan 320 karya dari seniman seluruh nusantara dengan penilaian transparan oleh dewan kurator independen dan voting warga.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Sayembara Publik & Partisipasi Warga',
                    'period' => 'TA 2026',
                    'beneficiaries' => '320 Desainer/Musisi Terdaftar, 45.000 Vote Warga',
                    'economic_impact' => 'Total Hadiah Apresiasi Rp 120.000.000 Disalurkan',
                    'satisfaction_rate' => '99.5% Transparansi Tanpa Potongan',
                    'testimonial_author' => 'Dimas Arya (Pemenang Utama Sayembara Maskot Porda)',
                    'testimonial_quote' => 'Sayembara pemerintah paling profesional dan transparan yang pernah saya ikuti. Pembayaran hadiah langsung cair dan hak cipta dihormati dengan adil.',
                    'verified_badge' => 'Audit Transparansi Inspektorat 100%',
                ],
                'published_at' => Carbon::now()->subDays(28),
            ],

            // --- 5 TIM & PEJABAT PENGADAAN INSTANSI ---
            [
                'resource_type' => 'team',
                'title' => 'Drs. H. Bambang Haryanto, M.Si',
                'description' => 'Pengguna Anggaran (PA) / Kepala Dinas. Bertanggung jawab atas kebijakan umum pengadaan, persetujuan alokasi anggaran, dan otorisasi DIPA kedinasan.',
                'status' => 'active',
                'metadata' => [
                    'role_title' => 'Kepala Dinas / Pengguna Anggaran (PA)',
                    'nip' => '19710815 199603 1 002',
                    'department' => 'Pimpinan Instansi',
                    'phone' => '081122334455',
                    'email' => 'bambang.haryanto@pemda.go.id',
                ],
                'published_at' => Carbon::now()->subDays(60),
            ],
            [
                'resource_type' => 'team',
                'title' => 'Siti Rahmawati, S.STP, M.AP',
                'description' => 'Pejabat Pembuat Komitmen (PPK). Bertanggung jawab atas perencanaan spesifikasi teknis (KAK), penerbitan SPK kontrak, dan pengawasan mutu vendor.',
                'status' => 'active',
                'metadata' => [
                    'role_title' => 'Pejabat Pembuat Komitmen (PPK)',
                    'nip' => '19840321 200701 2 004',
                    'department' => 'Bidang Pengembangan Ekonomi Kreatif',
                    'phone' => '081233445566',
                    'email' => 'siti.rahmawati@pemda.go.id',
                ],
                'published_at' => Carbon::now()->subDays(60),
            ],
            [
                'resource_type' => 'team',
                'title' => 'Rian Pratama, S.Kom, M.T',
                'description' => 'Pejabat Pengadaan / Pokja Pemilihan UKPBJ. Mengelola proses lelang tender terbuka LPSE, evaluasi penawaran harga, dan klarifikasi kualifikasi.',
                'status' => 'active',
                'metadata' => [
                    'role_title' => 'Pejabat Pengadaan / Pokja LPSE',
                    'nip' => '19881109 201101 1 003',
                    'department' => 'Unit Kerja Pengadaan Barang/Jasa (UKPBJ)',
                    'phone' => '081344556677',
                    'email' => 'rian.pratama@pemda.go.id',
                ],
                'published_at' => Carbon::now()->subDays(60),
            ],
            [
                'resource_type' => 'team',
                'title' => 'Dewi Anggraini, S.Sn',
                'description' => 'Verifikator Teknis Konten & Kesenian. Bertanggung jawab atas kurasi materi visual, pengujian resolusi berkas digital, dan rekomendasi BAST.',
                'status' => 'active',
                'metadata' => [
                    'role_title' => 'Verifikator Teknis & Kurator Konten',
                    'nip' => '19920514 201503 2 001',
                    'department' => 'Seksi Kebudayaan dan Kesenian',
                    'phone' => '081255667788',
                    'email' => 'dewi.anggraini@pemda.go.id',
                ],
                'published_at' => Carbon::now()->subDays(60),
            ],
            [
                'resource_type' => 'team',
                'title' => 'Ahmad Fauzi, A.Md.Kom',
                'description' => 'Operator Sistem & Publikasi Informasi Kedinasan. Mengelola integrasi portal Kreavana, update pengumuman siaran pers, dan rekapitulasi data serapan.',
                'status' => 'active',
                'metadata' => [
                    'role_title' => 'Operator Sistem & Admin Publikasi',
                    'nip' => '19950720 201902 1 002',
                    'department' => 'Sub Bagian Perencanaan dan Humas',
                    'phone' => '081366778899',
                    'email' => 'ahmad.fauzi@pemda.go.id',
                ],
                'published_at' => Carbon::now()->subDays(60),
            ],
        ];

        foreach ($resources as $resData) {
            InstitutionResource::updateOrCreate(
                [
                    'user_id' => $gov->id,
                    'resource_type' => $resData['resource_type'],
                    'title' => $resData['title'],
                ],
                [
                    'description' => $resData['description'],
                    'status' => $resData['status'],
                    'metadata' => $resData['metadata'],
                    'published_at' => $resData['published_at'] ?? now(),
                ]
            );
        }

        // 3. DUMMY NOTIFIKASI KEDINASAN
        $notifs = [
            [
                'title' => 'Tender LPSE-2026-001 Menerima Penawaran Baru',
                'message' => 'PT Visual Kreasi Nusantara telah mengajukan dokumen penawaran teknis dan administrasi lelang film dokumenter.',
                'type' => 'contract',
            ],
            [
                'title' => 'Review Laporan Kinerja LAKIP Triwulan I Disetujui',
                'message' => 'Inspektorat daerah telah memverifikasi kelengkapan berkas LAKIP TA 2026 dengan predikat Sangat Baik.',
                'type' => 'system',
            ],
            [
                'title' => 'Pemberitahuan Serapan Anggaran DIPA-01',
                'message' => 'Serapan belanja jasa kehumasan kedinasan telah mencapai 78% dari pagu yang ditetapkan.',
                'type' => 'system',
            ],
        ];

        foreach ($notifs as $nData) {
            Notification::firstOrCreate(
                [
                    'user_id' => $gov->id,
                    'title' => $nData['title'],
                ],
                [
                    'message' => $nData['message'],
                    'type' => $nData['type'],
                    'is_read' => false,
                    'created_at' => Carbon::now()->subHours(rand(1, 48)),
                ]
            );
        }
    }
}
