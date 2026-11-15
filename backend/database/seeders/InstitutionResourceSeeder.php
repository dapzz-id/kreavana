<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\InstitutionResource;
use App\Enums\RoleType;
use App\Enums\CreatorSubRole;

class InstitutionResourceSeeder extends Seeder
{
    public function run(): void
    {
        $institutionUsers = User::whereIn('sub_role', [
            CreatorSubRole::INSTITUTION->value,
            CreatorSubRole::GOVERNMENT->value,
            'institution',
            'institusi',
            'government',
            'school',
            'campus',
        ])
        ->orWhere('username', 'institution_demo')
        ->orWhere('email', 'institution@kreavana.id')
        ->get();

        if ($institutionUsers->isEmpty()) {
            return;
        }

        foreach ($institutionUsers as $user) {
            self::seedForUser($user);
        }
    }

    public static function seedForUser(User $user): void
    {
        $resources = [
            // ─────────────────────────────────────────────────────────────
            // 1. PROGRAM STUDI & KEUNGGULAN (study_programs)
            // ─────────────────────────────────────────────────────────────
            [
                'resource_type' => 'study_programs',
                'title' => 'D4 Animasi & Desain Game Terapan',
                'description' => 'Fokus pada modeling 3D, rigging karakter, animasi motion capture, unreal engine environment, dan asset visual effect (VFX).',
                'status' => 'published',
                'metadata' => [
                    'level' => 'D4 / Sarjana Terapan',
                    'accreditation' => 'Unggul (A)',
                    'focus_areas' => '3D Character Animation, Rigging, Unreal Engine, Game Assets',
                    'total_students' => 195,
                    'head_of_program' => 'Ir. Hendra Kusuma, M.Sn',
                    'contact' => 'kaprodi.animasi@kreavana.sch.id',
                ],
                'published_at' => now()->subMonths(6),
            ],
            [
                'resource_type' => 'study_programs',
                'title' => 'S1 Desain Komunikasi Visual (DKV)',
                'description' => 'Pusat pembelajaran brand identity system, creative visual advertising, packaging, UI/UX interaction, dan ilustrasi digital kontemporer.',
                'status' => 'published',
                'metadata' => [
                    'level' => 'S1 / Sarjana',
                    'accreditation' => 'Unggul (A)',
                    'focus_areas' => 'Brand Identity, Packaging Design, UI/UX, Creative Advertising',
                    'total_students' => 240,
                    'head_of_program' => 'Dra. Nurul Hidayati, M.Ds',
                    'contact' => 'kaprodi.dkv@kreavana.sch.id',
                ],
                'published_at' => now()->subMonths(6),
            ],
            [
                'resource_type' => 'study_programs',
                'title' => 'D3 Broadcasting & Media Televisi',
                'description' => 'Konsentrasi produksi sinematografi 4K, live multi-camera broadcast, audio engineering lapangan, tata pencahayaan, dan penyutradaraan.',
                'status' => 'published',
                'metadata' => [
                    'level' => 'D3 / Ahli Madya',
                    'accreditation' => 'Baik Sekali (B+)',
                    'focus_areas' => 'Multi-Cam Live Broadcast, Sinematografi 4K, Audio Engineering, Tata Suara',
                    'total_students' => 160,
                    'head_of_program' => 'Bambang Triyono, S.Sn, M.A',
                    'contact' => 'kaprodi.broadcast@kreavana.sch.id',
                ],
                'published_at' => now()->subMonths(6),
            ],
            [
                'resource_type' => 'study_programs',
                'title' => 'D4 Rekayasa Perangkat Lunak & Teknologi Media',
                'description' => 'Rekayasa aplikasi mobile interaktif, Augmented Reality (AR/VR), web frontend kreatif, dan kecerdasan artifisial terapan.',
                'status' => 'published',
                'metadata' => [
                    'level' => 'D4 / Sarjana Terapan',
                    'accreditation' => 'Unggul (A)',
                    'focus_areas' => 'AR/VR Applications, Flutter Mobile, Creative Web, Interactive Media',
                    'total_students' => 210,
                    'head_of_program' => 'Dr. Arif Wibowo, M.T',
                    'contact' => 'kaprodi.rpl@kreavana.sch.id',
                ],
                'published_at' => now()->subMonths(5),
            ],
            [
                'resource_type' => 'study_programs',
                'title' => 'S1 Seni Rupa Murni & Kriya Nusantara',
                'description' => 'Pengembangan seni rupa kontemporer, kriya tekstil tradisional, seni instalasi ruang publik, dan kurasi pameran seni budaya.',
                'status' => 'published',
                'metadata' => [
                    'level' => 'S1 / Sarjana',
                    'accreditation' => 'Baik Sekali (B+)',
                    'focus_areas' => 'Seni Instalasi, Kriya Tekstil Nusantara, Seni Patung, Kurasi Seni Rupa',
                    'total_students' => 120,
                    'head_of_program' => 'Siti Nurjanah, S.Sn, M.Hum',
                    'contact' => 'kaprodi.senirupa@kreavana.sch.id',
                ],
                'published_at' => now()->subMonths(4),
            ],
            [
                'resource_type' => 'study_programs',
                'title' => 'D3 Produksi Audio & Rekayasa Suara Digital',
                'description' => 'Rekayasa tata suara rekaman studio, scoring musik film, sound design interaktif game, dan mastering audio siaran.',
                'status' => 'published',
                'metadata' => [
                    'level' => 'D3 / Ahli Madya',
                    'accreditation' => 'Baik Sekali (B)',
                    'focus_areas' => 'Studio Recording, Film Scoring, Audio Mixing & Mastering, Sound Design',
                    'total_students' => 110,
                    'head_of_program' => 'Kevin Mahardika, M.Mus',
                    'contact' => 'kaprodi.audio@kreavana.sch.id',
                ],
                'published_at' => now()->subMonths(4),
            ],

            // ─────────────────────────────────────────────────────────────
            // 2. KARYA & SHOWCASE SISWA (showcases)
            // ─────────────────────────────────────────────────────────────
            [
                'resource_type' => 'showcases',
                'title' => 'Portofolio Videografi & Sinematografi Komersial 4K',
                'description' => 'Kompilasi karya video iklan komersial, teaser visual kreatif, dan showreel videografi korporat resolusi 4K dengan color grading sinematik.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Desain Komunikasi Visual & Videografi',
                    'creator_name' => 'Achmad Bilzan',
                    'image_url' => 'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?auto=format&fit=crop&w=600&q=80',
                    'portfolio_url' => 'https://github.com/blznqhtn',
                    'year' => '2026',
                ],
                'published_at' => now()->subDays(1),
            ],
            [
                'resource_type' => 'showcases',
                'title' => 'Film Animasi Pendek 3D: "Legenda Sang Penjaga Rimba"',
                'description' => 'Karya tugas akhir kolaborasi 8 siswa Animasi 3D bertema konservasi satwa langka nusantara dengan visual CGI cinematic 4K.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Animasi 3D & CGI',
                    'creator_name' => 'Tim Studio Animasi XII-A',
                    'image_url' => 'https://images.unsplash.com/photo-1634017839464-5c339ebe3cb4?auto=format&fit=crop&w=600&q=80',
                    'portfolio_url' => 'https://youtube.com/watch?v=legenda-penjaga-rimba',
                    'year' => '2026',
                ],
                'published_at' => now()->subDays(3),
            ],
            [
                'resource_type' => 'showcases',
                'title' => 'Redesain Kemasan & Identitas Visual 10 UMKM Kopi Lereng Gunung',
                'description' => 'Proyek hilirisasi riset mata kuliah DKV membantu UMKM lokal binaan kampus menembus ritel modern dan marketplace nasional.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'DKV & Packaging',
                    'creator_name' => 'Clarissa Maharani & Tim DKV VI',
                    'image_url' => 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?auto=format&fit=crop&w=600&q=80',
                    'portfolio_url' => 'https://behance.net/gallery/kreavana-umkm-packaging',
                    'year' => '2026',
                ],
                'published_at' => now()->subDays(7),
            ],
            [
                'resource_type' => 'showcases',
                'title' => 'Film Dokumenter Budaya: "Benang Emas Tenun Tradisional Ikat NTT"',
                'description' => 'Dokumenter sinematik berdurasi 24 menit mengenai ketahanan perajin tenun ikat tradisional Flores, tayang di festival film independen.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Broadcasting & Film',
                    'creator_name' => 'Rizky Ramadhan & Tim Sinematografi',
                    'image_url' => 'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?auto=format&fit=crop&w=600&q=80',
                    'portfolio_url' => 'https://vimeo.com/kreavana-tenun-ikat',
                    'year' => '2026',
                ],
                'published_at' => now()->subDays(12),
            ],
            [
                'resource_type' => 'showcases',
                'title' => 'Aplikasi Edukasi Interaktif AR: "Jelajah Aksara Kuno Nusantara"',
                'description' => 'Aplikasi pembelajaran berbasis Augmented Reality untuk mengenali aksara Jawa, Sunda, dan Bali melalui interaksi kartu 3D.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'AR/VR & Game Dev',
                    'creator_name' => 'Dimas Setiawan & Tim RPL Media',
                    'image_url' => 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=600&q=80',
                    'portfolio_url' => 'https://play.google.com/store/apps/details?id=id.kreavana.aksara',
                    'year' => '2026',
                ],
                'published_at' => now()->subDays(15),
            ],
            [
                'resource_type' => 'showcases',
                'title' => 'Kampanye Desain Sosial: "Laut Bersih Generasi Lestari"',
                'description' => 'Sistem kampanye terpadu poster editorial, animasi infografis bergerak, dan merchandise ramah lingkungan untuk edukasi pesisir.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'DKV & Kampanye Sosial',
                    'creator_name' => 'Nadia Safitri (Mahasiswa DKV)',
                    'image_url' => 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?auto=format&fit=crop&w=600&q=80',
                    'portfolio_url' => 'https://instagram.com/lautlestari.project',
                    'year' => '2026',
                ],
                'published_at' => now()->subDays(20),
            ],
            [
                'resource_type' => 'showcases',
                'title' => 'Komposisi Musik & Soundscape Ambient: "Nadi Khatulistiwa"',
                'description' => 'Penggabungan instrumen gamelan tradisional dengan synthesizers modern dalam album soundscape lingkungan tropis.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Produksi Audio & Musik',
                    'creator_name' => 'Kevin Pratama & Studio Audio Kampus',
                    'image_url' => 'https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?auto=format&fit=crop&w=600&q=80',
                    'portfolio_url' => 'https://soundcloud.com/kreavana/nadi-khatulistiwa',
                    'year' => '2026',
                ],
                'published_at' => now()->subDays(25),
            ],

            // ─────────────────────────────────────────────────────────────
            // 3. TALENTA MAHASISWA / BURSA BKK (talents)
            // ─────────────────────────────────────────────────────────────
            [
                'resource_type' => 'talents',
                'title' => 'Fajar Nugraha — 3D Character Artist & Modeler',
                'description' => 'Spesialis perancangan karakter anatomi 3D dan rigging ekspresif di Blender & Maya. Pernah magang di proyek film indie lokal.',
                'status' => 'published',
                'metadata' => [
                    'study_program' => 'D4 Animasi & Desain Game Terapan',
                    'skills' => 'Blender, Autodesk Maya, ZBrush, Substance Painter',
                    'status_readiness' => 'Siap Magang PKL',
                    'gpa' => '3.92',
                    'portfolio_link' => 'https://artstation.com/fajarnugraha-3d',
                    'contact' => 'fajar.nugraha@student.kreavana.sch.id',
                ],
                'published_at' => now()->subDays(5),
            ],
            [
                'resource_type' => 'talents',
                'title' => 'Clarissa Maharani — UI/UX & Brand Identity Designer',
                'description' => 'Desainer sistem identitas visual dan wireframe prototipe web/mobile responsif. Juara 1 UI/UX Competition Tingkat Nasional.',
                'status' => 'published',
                'metadata' => [
                    'study_program' => 'S1 Desain Komunikasi Visual (DKV)',
                    'skills' => 'Figma, Design Token, Adobe Illustrator, Miro',
                    'status_readiness' => 'Siap Magang Industri',
                    'gpa' => '3.88',
                    'portfolio_link' => 'https://behance.net/clarissamaharani',
                    'contact' => 'clarissa.m@student.kreavana.sch.id',
                ],
                'published_at' => now()->subDays(8),
            ],
            [
                'resource_type' => 'talents',
                'title' => 'Rizky Ramadhan — Sinematografer & Pilot Drone APDI',
                'description' => 'Operator kamera sinema Blackmagic 6K Pro dan pilot drone bersertifikat APDI. Portofolio meliput konser, profil institusi, dan festival seni.',
                'status' => 'published',
                'metadata' => [
                    'study_program' => 'D3 Broadcasting & Media Televisi',
                    'skills' => 'Blackmagic Cinema Camera, DaVinci Resolve Studio, Drone Pilot APDI',
                    'status_readiness' => 'Siap Kerja / Project-Based',
                    'gpa' => '3.85',
                    'portfolio_link' => 'https://youtube.com/watch?v=rizky-reel2026',
                    'contact' => 'rizky.ramadhan@student.kreavana.sch.id',
                ],
                'published_at' => now()->subDays(12),
            ],
            [
                'resource_type' => 'talents',
                'title' => 'Nadia Safitri — 2D Illustrator & Visual Storyteller',
                'description' => 'Kreator ilustrasi editorial, buku cerita anak, dan visual asset kampanye sosial menggunakan Clip Studio Paint dan Procreate.',
                'status' => 'published',
                'metadata' => [
                    'study_program' => 'S1 Desain Komunikasi Visual (DKV)',
                    'skills' => 'Clip Studio Paint, Adobe Photoshop, Procreate, Storyboarding',
                    'status_readiness' => 'Siap Magang PKL',
                    'gpa' => '3.90',
                    'portfolio_link' => 'https://instagram.com/nadiasafitri.art',
                    'contact' => 'nadia.safitri@student.kreavana.sch.id',
                ],
                'published_at' => now()->subDays(14),
            ],
            [
                'resource_type' => 'talents',
                'title' => 'Kevin Pratama — Audio Mixing Engineer & Film Scorer',
                'description' => 'Spesialis mixing audio rekaman multi-track, sound effect foley, dan komposisi musik latar film pendek pada Pro Tools & Ableton.',
                'status' => 'published',
                'metadata' => [
                    'study_program' => 'D3 Produksi Audio & Rekayasa Suara Digital',
                    'skills' => 'Pro Tools, Logic Pro, Ableton Live, Sound Foley, Audio Mastering',
                    'status_readiness' => 'Siap Magang Industri',
                    'gpa' => '3.82',
                    'portfolio_link' => 'https://soundcloud.com/kevinpratama-audio',
                    'contact' => 'kevin.p@student.kreavana.sch.id',
                ],
                'published_at' => now()->subDays(18),
            ],
            [
                'resource_type' => 'talents',
                'title' => 'Dimas Setiawan — Interactive Frontend & Game Developer',
                'description' => 'Pengembang antarmuka Flutter responsif, implementasi web interaktif Three.js, dan prototype game engine di Unity C#.',
                'status' => 'published',
                'metadata' => [
                    'study_program' => 'D4 Rekayasa Perangkat Lunak & Teknologi Media',
                    'skills' => 'Flutter, Dart, Three.js, Unity C#, WebGL, Git',
                    'status_readiness' => 'Siap Kerja / Full-Time',
                    'gpa' => '3.94',
                    'portfolio_link' => 'https://github.com/dimassetiawan-dev',
                    'contact' => 'dimas.s@student.kreavana.sch.id',
                ],
                'published_at' => now()->subDays(22),
            ],

            // ─────────────────────────────────────────────────────────────
            // 4. DIREKTORI MITRA IDUKA & KERJASAMA (partners)
            // ─────────────────────────────────────────────────────────────
            [
                'resource_type' => 'partners',
                'title' => 'PT Studio Kreasi Nusantara',
                'description' => 'Mitra IDUKA utama bidang animasi, periklanan digital, dan penyerapan lulusan industri kreatif tingkat nasional.',
                'status' => 'published',
                'metadata' => [
                    'partner_type' => 'Industri & Dunia Usaha (IDUKA)',
                    'category' => 'Industri Animasi & CGI',
                    'mou_number' => '042/MOU-IDUKA/KRV/2026',
                    'mou_duration' => '15 Jan 2026 - 15 Jan 2029',
                    'scope' => 'Penyaluran Magang PKL, Kelas Industri, & Rekrutmen Lulusan',
                    'contact' => 'partnership@kreastudios.id',
                    'website' => 'https://kreastudios.id',
                ],
                'published_at' => now()->subMonths(3),
            ],
            [
                'resource_type' => 'partners',
                'title' => 'Pixel Craft Production House',
                'description' => 'Vendor penyedia peralatan sinematografi, broadcast live streaming, dan tata suara panggung resmi kegiatan kampus.',
                'status' => 'published',
                'metadata' => [
                    'partner_type' => 'Mitra & Vendor Jasa',
                    'category' => 'Production House & Rental Alat',
                    'mou_number' => '018/PKS-VENDOR/2026',
                    'mou_duration' => '01 Feb 2026 - 01 Feb 2028',
                    'scope' => 'Pengadaan Alat Produksi, Dokumentasi Event & Wisuda',
                    'contact' => 'sales@pixelcraft.co.id',
                    'website' => 'https://pixelcraft.co.id',
                ],
                'published_at' => now()->subMonths(2),
            ],
            [
                'resource_type' => 'partners',
                'title' => 'Asosiasi Desainer Grafis Indonesia (ADGI)',
                'description' => 'Mitra strategis dalam penyelarasan kurikulum DKV, penguji eksternal uji kompetensi, dan fasilitasi pameran karya siswa.',
                'status' => 'published',
                'metadata' => [
                    'partner_type' => 'Komunitas & Asosiasi Profesi',
                    'category' => 'Asosiasi Desain Nasional',
                    'mou_number' => '009/MOU-ADGI/2025',
                    'mou_duration' => '10 Okt 2025 - 10 Okt 2027',
                    'scope' => 'Penyelarasan Kurikulum, Uji Sertifikasi Kompetensi, Juri Pameran',
                    'contact' => 'kerjasama@adgi.or.id',
                    'website' => 'https://adgi.or.id',
                ],
                'published_at' => now()->subMonths(1),
            ],
            [
                'resource_type' => 'partners',
                'title' => 'PT Agensi Periklanan Digital Asia',
                'description' => 'Agensi creative branding partner untuk penyaluran magang mahasiswa jurusan DKV dan penulisan copywriting periklanan.',
                'status' => 'published',
                'metadata' => [
                    'partner_type' => 'Industri & Dunia Usaha (IDUKA)',
                    'category' => 'Advertising & Digital Agency',
                    'mou_number' => '031/MOU-ADV/KRV/2026',
                    'mou_duration' => '01 Mar 2026 - 01 Mar 2028',
                    'scope' => 'Magang MBKM, Proyek Kolaboratif Branding Klien, Dosen Tamu',
                    'contact' => 'hr@digitalasia.co.id',
                    'website' => 'https://digitalasia.co.id',
                ],
                'published_at' => now()->subMonths(2),
            ],
            [
                'resource_type' => 'partners',
                'title' => 'Yayasan Inovasi Digital Berkelanjutan',
                'description' => 'Lembaga pendukung penyalur hibah fasilitas lab komputer kreatif dan beasiswa sertifikasi keahlian siswa berprestasi.',
                'status' => 'published',
                'metadata' => [
                    'partner_type' => 'Sponsor & Pendukung',
                    'category' => 'CSR & Lembaga Hibah',
                    'mou_number' => '005/HIBAH-CSR/2026',
                    'mou_duration' => '05 Jan 2026 - 05 Jan 2027',
                    'scope' => 'Hibah Lab Grafis, Beasiswa Uji Kompetensi BNSP',
                    'contact' => 'program@inovasidigital.org',
                    'website' => 'https://inovasidigital.org',
                ],
                'published_at' => now()->subMonths(4),
            ],
            [
                'resource_type' => 'partners',
                'title' => 'PT Solusi Software & Media Interaktif',
                'description' => 'Software house mitra penyalur magang siswa jurusan Rekayasa Perangkat Lunak dan inkubasi produk rintisan digital.',
                'status' => 'published',
                'metadata' => [
                    'partner_type' => 'Industri & Dunia Usaha (IDUKA)',
                    'category' => 'Software House & IT Consultant',
                    'mou_number' => '024/MOU-IT/KRV/2026',
                    'mou_duration' => '10 Feb 2026 - 10 Feb 2029',
                    'scope' => 'Magang Mahasiswa, Mentoring Startup Kampus, Riset Bersama',
                    'contact' => 'career@solusisoftware.id',
                    'website' => 'https://solusisoftware.id',
                ],
                'published_at' => now()->subMonths(3),
            ],

            // ─────────────────────────────────────────────────────────────
            // 5. TENDER & PENGADAAN SARPRAS (tenders)
            // ─────────────────────────────────────────────────────────────
            [
                'resource_type' => 'tenders',
                'title' => 'Pengadaan Workstation Lab Animasi 3D & Server Rendering Farm',
                'description' => 'Pengadaan 30 unit PC workstation spesifikasi tinggi (RTX 4080) dan server render farm untuk menunjang kelas industri animasi.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Sarpras Laboratorium',
                    'budget' => 450000000,
                    'deadline' => '2026-11-20',
                ],
                'published_at' => now()->subDays(4),
            ],
            [
                'resource_type' => 'tenders',
                'title' => 'Tender Dokumentasi Multi-Kamera Festival Seni Budaya & Wisuda',
                'description' => 'Kerja sama peliputan siaran langsung multi-kamera 4K, videotron panggung, dan rekaman master audio prosesi wisuda terpadu.',
                'status' => 'in_progress',
                'metadata' => [
                    'category' => 'Event & Broadcast',
                    'budget' => 85000000,
                    'deadline' => '2026-10-25',
                ],
                'published_at' => now()->subDays(10),
            ],
            [
                'resource_type' => 'tenders',
                'title' => 'Pengembangan Modul Pembelajaran Interaktif LMS Kampus Digital',
                'description' => 'Pembuatan 50 modul video motion graphic dan bank soal interaktif berbasis web untuk blended learning vokasi.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Pengembangan Konten Edukasi',
                    'budget' => 60000000,
                    'deadline' => '2026-12-05',
                ],
                'published_at' => now()->subDays(6),
            ],
            [
                'resource_type' => 'tenders',
                'title' => 'Fabrikasi & Penataan Booth Pameran Creative Expo Nasional 2026',
                'description' => 'Pengerjaan interior booth showcase karya siswa seluas 6x6 meter dengan konsep futuristik ramah lingkungan.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Pameran & Tata Panggung',
                    'budget' => 45000000,
                    'deadline' => '2026-11-15',
                ],
                'published_at' => now()->subDays(8),
            ],
            [
                'resource_type' => 'tenders',
                'title' => 'Percetakan Buku Tahunan & Katalog Portofolio Lulusan Angkatan 2026',
                'description' => 'Cetak hardcover full color 350 eksemplar buku katalog karya lulusan kejuruan berstandar kualitas internasional.',
                'status' => 'completed',
                'metadata' => [
                    'category' => 'Percetakan & Publikasi',
                    'budget' => 38000000,
                    'deadline' => '2026-09-30',
                ],
                'published_at' => now()->subMonths(1),
            ],

            // ─────────────────────────────────────────────────────────────
            // 6. MONITORING & EVALUASI (monitoring)
            // ─────────────────────────────────────────────────────────────
            [
                'resource_type' => 'monitoring',
                'title' => 'Monitoring Logbook & Kehadiran Mahasiswa Magang IDUKA Semester Ganjil',
                'description' => 'Evaluasi mingguan catatan harian aktivitas magang 45 mahasiswa vokasi pada 12 perusahaan mitra industri kreatif.',
                'status' => 'in_progress',
                'metadata' => [
                    'category' => 'Monitoring Magang PKL',
                    'period' => 'Semester Ganjil 2026',
                    'progress' => 68,
                    'target_date' => '2026-12-20',
                ],
                'published_at' => now()->subDays(2),
            ],
            [
                'resource_type' => 'monitoring',
                'title' => 'Evaluasi Uji Kompetensi Keahlian (UKK) & Sertifikasi BNSP Animasi',
                'description' => 'Pelacakan progres verifikasi portofolio dan kelulusan 60 peserta uji kompetensi skema animator madya bersertifikat BNSP.',
                'status' => 'in_progress',
                'metadata' => [
                    'category' => 'Uji Sertifikasi Profesi',
                    'period' => 'Batch II 2026',
                    'progress' => 85,
                    'target_date' => '2026-11-10',
                ],
                'published_at' => now()->subDays(5),
            ],
            [
                'resource_type' => 'monitoring',
                'title' => 'Monitoring Capaian Kelas Dosen Praktisi Industri Perfilman',
                'description' => 'Pengawasan kehadiran praktisi, realisasi silabus praktikum sinematografi, dan kepuasan mahasiswa selama 14 sesi pertemuan.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Program Dosen Praktisi',
                    'period' => 'TA 2026/2027',
                    'progress' => 50,
                    'target_date' => '2026-12-15',
                ],
                'published_at' => now()->subDays(8),
            ],
            [
                'resource_type' => 'monitoring',
                'title' => 'Pelacakan Hilirisasi Riset Terapan LPPM & Inkubasi UMKM',
                'description' => 'Monitoring tahapan uji coba pasar dan pendaftaran sertifikasi HKI desain kemasan 20 produk UMKM binaan kampus.',
                'status' => 'in_progress',
                'metadata' => [
                    'category' => 'Hilirisasi Riset Terapan',
                    'period' => 'Tahap II 2026',
                    'progress' => 75,
                    'target_date' => '2026-11-30',
                ],
                'published_at' => now()->subDays(11),
            ],
            [
                'resource_type' => 'monitoring',
                'title' => 'Evaluasi Pemenuhan Standar Mutu Akreditasi BAN-PT Fasilitas Sarpras',
                'description' => 'Verifikasi kelengkapan instrumen akreditasi program studi vokasi untuk laboratorium multimedia, studio TV, dan rasio dosen.',
                'status' => 'completed',
                'metadata' => [
                    'category' => 'Akreditasi Lembaga',
                    'period' => 'Siklus 2026',
                    'progress' => 100,
                    'target_date' => '2026-09-30',
                ],
                'published_at' => now()->subDays(20),
            ],

            // ─────────────────────────────────────────────────────────────
            // 7. PENGUMUMAN RESMI (announcements)
            // ─────────────────────────────────────────────────────────────
            [
                'resource_type' => 'announcements',
                'title' => 'Pendaftaran Seleksi Program Magang IDUKA Semester Genap Batch 2',
                'description' => 'Dibuka kesempatan magang selama 6 bulan di 15 studio animasi, PH perfilman, dan agensi periklanan mitra resmi kampus. Kuota 50 kursi.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Bursa Magang & Karir',
                    'valid_until' => '2026-11-25',
                ],
                'published_at' => now()->subDays(1),
            ],
            [
                'resource_type' => 'announcements',
                'title' => 'Jadwal Uji Sertifikasi Kompetensi Profesi BNSP Skema Desain Grafis',
                'description' => 'Pelaksanaan asesmen uji kompetensi oleh Asesor LSP Kreatif Nusantara dijadwalkan tanggal 10-12 November 2026 di Lab Desain Kampus.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Sertifikasi BNSP',
                    'valid_until' => '2026-11-09',
                ],
                'published_at' => now()->subDays(3),
            ],
            [
                'resource_type' => 'announcements',
                'title' => 'Kuliah Umum Praktisi Tamu: "Masa Depan AI Generatif dalam Industri Animasi"',
                'description' => 'Menghadirkan Lead Technical Director Studio Animasi Hollywood. Terbuka gratis untuk seluruh civitas akademika dan umum.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Kuliah Umum & Webinar',
                    'valid_until' => '2026-10-30',
                ],
                'published_at' => now()->subDays(6),
            ],
            [
                'resource_type' => 'announcements',
                'title' => 'Call for Proposals: Hibah Riset Terapan Vokasi Kreavana Batch I 2027',
                'description' => 'Pendanaan riset inovasi teknologi kreatif hingga Rp 50.000.000 per tim dosen dan mahasiswa yang berkolaborasi dengan industri.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Hibah Riset LPPM',
                    'valid_until' => '2026-12-15',
                ],
                'published_at' => now()->subDays(10),
            ],
            [
                'resource_type' => 'announcements',
                'title' => 'Undangan Pameran & Showcase Karya Siswa "Kreavana Creative Festival 2026"',
                'description' => 'Pameran terbuka menampilkan 120 karya seni, game interaktif, dan animasi karya siswa kejuruan kepada publik dan industri.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Pameran & Expo',
                    'valid_until' => '2026-11-05',
                ],
                'published_at' => now()->subDays(14),
            ],

            // ─────────────────────────────────────────────────────────────
            // 8. DOKUMEN LEGAL & REGULASI (documents)
            // ─────────────────────────────────────────────────────────────
            [
                'resource_type' => 'documents',
                'title' => 'Nota Kesepahaman (MoU) Kemitraan Strategis IDUKA No. 042/MOU/2026',
                'description' => 'Perjanjian payung hukum kerjasama kurikulum kelas industri, program magang bersertifikat, dan penyerapan kerja lulusan.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Nota Kesepahaman (MoU)',
                    'document_date' => '2026-01-15',
                    'url' => 'https://docs.kreavana.id/legal/mou-iduka-042-2026.pdf',
                ],
                'published_at' => now()->subMonths(3),
            ],
            [
                'resource_type' => 'documents',
                'title' => 'Perjanjian Kerja Sama (PKS) Jasa Dokumentasi Multi-Kamera Wisuda',
                'description' => 'Surat kesepakatan pengikatan vendor broadcast streaming dan hak royalti rekaman master audio-visual wisuda terpadu.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Perjanjian Kerja Sama (PKS)',
                    'document_date' => '2026-09-10',
                    'url' => 'https://docs.kreavana.id/legal/pks-broadcast-wisuda-2026.pdf',
                ],
                'published_at' => now()->subDays(25),
            ],
            [
                'resource_type' => 'documents',
                'title' => 'Surat Perintah Kerja (SPK) Vendor Fabrikasi Booth Creative Expo',
                'description' => 'Otorisasi resmi pengerjaan interior pameran dan instalasi modul panggung siswa tertanggal 01 Oktober 2026.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Surat Perintah Kerja (SPK)',
                    'document_date' => '2026-10-01',
                    'url' => 'https://docs.kreavana.id/legal/spk-booth-expo-2026.pdf',
                ],
                'published_at' => now()->subDays(15),
            ],
            [
                'resource_type' => 'documents',
                'title' => 'Berita Acara Serah Terima (BAST) 30 Unit Komputer Lab Grafis',
                'description' => 'Berita acara pemeriksaan fisik dan verifikasi spesifikasi perangkat workstation animasi sesuai standar spesifikasi tender.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Berita Acara (BAST)',
                    'document_date' => '2026-08-20',
                    'url' => 'https://docs.kreavana.id/legal/bast-lab-grafis-2026.pdf',
                ],
                'published_at' => now()->subMonths(1),
            ],
            [
                'resource_type' => 'documents',
                'title' => 'Surat Keputusan (SK) Direktur tentang Tim Pengelola BKK & Magang',
                'description' => 'Surat keputusan legalitas struktur panitia bursa kerja khusus, pembimbing lapangan, dan kurator galeri karya siswa.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Surat Keputusan (SK)',
                    'document_date' => '2026-01-05',
                    'url' => 'https://docs.kreavana.id/legal/sk-tim-bkk-magang-2026.pdf',
                ],
                'published_at' => now()->subMonths(6),
            ],

            // ─────────────────────────────────────────────────────────────
            // 9. ANGGARAN & PAGU (budgets)
            // ─────────────────────────────────────────────────────────────
            [
                'resource_type' => 'budgets',
                'title' => 'Alokasi Pengadaan Sarpras Lab Multimedia & Rendering Farm',
                'description' => 'Pagu anggaran belanja modal untuk peremajaan unit workstation animasi 3D dan lisensi software editing profesional.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Belanja Sarpras Lab',
                    'budget' => 450000000,
                ],
                'published_at' => now()->subDays(5),
            ],
            [
                'resource_type' => 'budgets',
                'title' => 'Pagu Hibah Riset Terapan Dosen & Hilirisasi UMKM LPPM',
                'description' => 'Pendanaan penelitian terapan kemitraan vokasi dan pendampingan branding kemasan produk UMKM binaan kampus.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Hibah Riset LPPM',
                    'budget' => 150000000,
                ],
                'published_at' => now()->subDays(9),
            ],
            [
                'resource_type' => 'budgets',
                'title' => 'Anggaran Operasional Gelar Karya Siswa & Pameran Expo 2026',
                'description' => 'Pembiayaan sewa venue pameran, dekorasi booth, promosi media, dan penyelenggaraan talkshow industri kreatif.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Pameran & Dies Natalis',
                    'budget' => 95000000,
                ],
                'published_at' => now()->subDays(12),
            ],
            [
                'resource_type' => 'budgets',
                'title' => 'Fasilitasi Sertifikasi Kompetensi BNSP & Uji Keahlian (UKK)',
                'description' => 'Alokasi pembiayaan pendaftaran asesor, penerbitan sertifikat kompetensi resmi negara, dan bahan uji praktikum siswa.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Uji Sertifikasi Profesi',
                    'budget' => 80000000,
                ],
                'published_at' => now()->subDays(16),
            ],
            [
                'resource_type' => 'budgets',
                'title' => 'Honorarium Program Dosen Praktisi Industri & Kuliah Tamu',
                'description' => 'Anggaran insentif mengajar bagi praktisi industri perfilman, studio game, dan agensi desain selama 1 semester.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Honor Praktisi Industri',
                    'budget' => 65000000,
                ],
                'published_at' => now()->subDays(20),
            ],

            // ─────────────────────────────────────────────────────────────
            // 10. LAPORAN KEGIATAN & AKREDITASI (reports)
            // ─────────────────────────────────────────────────────────────
            [
                'resource_type' => 'reports',
                'title' => 'Laporan Akuntabilitas Kinerja Instansi Pemerintah (LAKIP) Q3 2026',
                'description' => 'Evaluasi capaian sasaran strategis, penyerapan anggaran sarpras, dan indikator kinerja utama lembaga pendidikan.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Laporan Kinerja Lembaga',
                    'period' => 'Triwulan III 2026',
                    'result' => 'Capaian IKU mencapai 94.2% dengan serapan anggaran 88.5%',
                ],
                'published_at' => now()->subDays(3),
            ],
            [
                'resource_type' => 'reports',
                'title' => 'Laporan Evaluasi Program Link & Match Kurikulum Bersama IDUKA',
                'description' => 'Rekapitulasi hasil sinkronisasi silabus DKV dan Animasi 3D bersama 8 industri mitra untuk standar kurikulum nasional.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Evaluasi Akademik IDUKA',
                    'period' => 'Tahun Ajaran 2025/2026',
                    'result' => '100% silabus kejuruan telah diselaraskan dengan kebutuhan kompetensi IDUKA',
                ],
                'published_at' => now()->subDays(8),
            ],
            [
                'resource_type' => 'reports',
                'title' => 'Hasil Tracer Study & Penyerapan Lulusan Vokasi Angkatan 2025',
                'description' => 'Survei waktu tunggu kerja lulusan kejuruan, persentase bekerja di industri kreatif (78%), dan gaji pertama di atas UMR.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Tracer Study Alumni',
                    'period' => 'Lulusan TA 2025',
                    'result' => 'Waktu tunggu rata-rata 2.4 bulan, penyerapan di bidang kreatif 82.6%',
                ],
                'published_at' => now()->subDays(14),
            ],
            [
                'resource_type' => 'reports',
                'title' => 'Laporan Audit Mutu Internal (AMI) Laboratorium & K3 Studio TV',
                'description' => 'Hasil inspeksi keselamatan kerja, kelaikan perangkat kelistrikan, dan inventarisasi aset hardware multimedia kampus.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Audit Mutu Internal',
                    'period' => 'Semester Gasal 2026',
                    'result' => 'Predikat A (Sangat Layak), zero incident keselamatan kerja K3',
                ],
                'published_at' => now()->subDays(21),
            ],
            [
                'resource_type' => 'reports',
                'title' => 'Laporan Pertanggungjawaban (LPJ) Hibah Riset Terapan LPPM 2026',
                'description' => 'Dokumentasi luaran paten sederhana desain industri dan laporan penggunaan dana hibah kemitraan UMKM kemasan.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Pertanggungjawaban LPPM',
                    'period' => 'Tahun Anggaran 2026',
                    'result' => '3 hak cipta terdaftar, 20 katalog kemasan UMKM selesai dicetak',
                ],
                'published_at' => now()->subDays(30),
            ],

            // ─────────────────────────────────────────────────────────────
            // 11. TIM & HAK AKSES PENGELOLA (members)
            // ─────────────────────────────────────────────────────────────
            [
                'resource_type' => 'members',
                'title' => 'Dra. Sri Wahyuni, M.Pd',
                'description' => 'Waka Humas & Hubungan Kerjasama Industri',
                'status' => 'published',
                'metadata' => [
                    'email' => 'sri.wahyuni@kreavana.sch.id',
                    'role' => 'Karyawan / Staf',
                    'permissions' => ['mitra_industri', 'dokumen_institusi'],
                    'department' => 'Waka Humas & Kemitraan IDUKA',
                    'is_online' => true,
                    'joined_at' => '12 Jan 2025',
                ],
                'published_at' => now()->subMonths(8),
            ],
            [
                'resource_type' => 'members',
                'title' => 'Budi Santoso, S.T',
                'description' => 'Koordinator Bursa Kerja Khusus (BKK) & Program Magang',
                'status' => 'published',
                'metadata' => [
                    'email' => 'budi.santoso@kreavana.sch.id',
                    'role' => 'Karyawan / Staf',
                    'permissions' => ['program_magang', 'kegiatan_event'],
                    'department' => 'Bursa Kerja Khusus & Penyaluran Karir',
                    'is_online' => false,
                    'joined_at' => '04 Feb 2025',
                ],
                'published_at' => now()->subMonths(7),
            ],
            [
                'resource_type' => 'members',
                'title' => 'Ahmad Fauzi, S.Kom',
                'description' => 'Dosen / Guru Pembimbing Praktik Kerja Lapangan (PKL)',
                'status' => 'published',
                'metadata' => [
                    'email' => 'ahmad.fauzi@kreavana.sch.id',
                    'role' => 'Karyawan / Staf',
                    'permissions' => ['program_magang', 'karya_siswa'],
                    'department' => 'Pembimbing Praktik & Logbook Magang',
                    'is_online' => true,
                    'joined_at' => '18 Feb 2025',
                ],
                'published_at' => now()->subMonths(6),
            ],
            [
                'resource_type' => 'members',
                'title' => 'Siti Rahmawati, S.Pd',
                'description' => 'Staf Tata Usaha & Pengelola Berkas Dokumen MoU',
                'status' => 'published',
                'metadata' => [
                    'email' => 'siti.rahma@kreavana.sch.id',
                    'role' => 'Karyawan / Staf',
                    'permissions' => ['dokumen_institusi', 'pengumuman_institusi'],
                    'department' => 'Administrasi & Arsip Legal Instansi',
                    'is_online' => false,
                    'joined_at' => '01 Mar 2025',
                ],
                'published_at' => now()->subMonths(5),
            ],
            [
                'resource_type' => 'members',
                'title' => 'Ir. Hendra Kusuma, M.Sn',
                'description' => 'Kurator Galeri & Penilai Portofolio Karya Siswa',
                'status' => 'published',
                'metadata' => [
                    'email' => 'hendra.kusuma@kreavana.sch.id',
                    'role' => 'Karyawan / Staf',
                    'permissions' => ['karya_siswa', 'kegiatan_event'],
                    'department' => 'Divisi Kurasi & Portofolio Siswa',
                    'is_online' => true,
                    'joined_at' => '15 Mar 2025',
                ],
                'published_at' => now()->subMonths(4),
            ],
        ];

        foreach ($resources as $res) {
            InstitutionResource::updateOrCreate(
                [
                    'user_id' => $user->id,
                    'title' => $res['title'],
                ],
                [
                    'resource_type' => $res['resource_type'],
                    'description' => $res['description'],
                    'status' => $res['status'],
                    'metadata' => $res['metadata'],
                    'published_at' => $res['published_at'],
                ]
            );
        }
    }
}
