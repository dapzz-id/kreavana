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

class SchoolDummySeeder extends Seeder
{
    public function run(): void
    {
        // Pastikan tidak ada resource tenders yang tertinggal untuk institusi / sekolah (tenders khusus corporate)
        InstitutionResource::where('resource_type', 'tenders')
            ->whereHas('owner', function ($q) {
                $q->whereIn('sub_role', ['institution', 'school', 'sekolah', 'kampus', 'smk', 'universitas', 'education', 'institusi']);
            })
            ->delete();

        $usernames = ['institution_demo', 'smk_demo', 'sekolah_demo'];
        $seeded = 0;

        foreach ($usernames as $uname) {
            $school = User::where('username', $uname)->first();
            if ($school) {
                self::seedForUser($school);
                $seeded++;
            }
        }

        if ($seeded === 0) {
            $fallback = User::where('sub_role', 'institution')->first();
            if ($fallback) {
                self::seedForUser($fallback);
            }
        }
    }

    public static function seedForUser(User $school): void
    {
        $schoolName = match ($school->username) {
            'smk_demo' => 'SMK Negeri 1 Kreasi Nusantara',
            'sekolah_demo' => 'SMK Kreatif Nusantara',
            default => $school->name ?: 'Institut Seni & Rekayasa Kreatif Nusantara (ISRK)',
        };

        // 1. Update Profile Sekolah / Perguruan Tinggi
        $school->update([
            'name' => $schoolName,
            'phone' => '(021) 8849-201',
            'role' => RoleType::Creator,
            'sub_role' => 'institution',
            'is_verified' => 1,
            'is_creator_approved' => 1,
            'verification_type' => 'institution',
        ]);

        \App\Models\UserSubRole::updateOrCreate(
            [
                'user_id' => $school->id,
                'sub_role_slug' => 'institution',
            ],
            [
                'role_type' => RoleType::Creator->value,
                'is_active' => true,
            ]
        );

        // Hapus data lama agar ter-update bersih
        InstitutionResource::where('user_id', $school->id)->delete();

        // ── FITUR 0: PROFIL RESMI INSTITUSI PENDIDIKAN & NPSN ────────────────────
        $schoolProfileResource = [
            [
                'resource_type' => 'profile',
                'title' => $schoolName,
                'description' => 'Institut pendidikan tinggi vokasi seni, animasi 3D, DKV, dan rekayasa kreatif nusantara yang terakreditasi Unggul oleh BAN-PT dan berstandar internasional.',
                'status' => 'published',
                'metadata' => [
                    'npsn' => match ($school->username) {
                        'smk_demo' => '20108942',
                        'sekolah_demo' => '20104521',
                        default => '20401829',
                    },
                    'institution_type' => match ($school->username) {
                        'smk_demo', 'sekolah_demo' => 'Sekolah Menengah Kejuruan (SMK Vokasi)',
                        default => 'Perguruan Tinggi Vokasi / Institut Seni & Desain',
                    },
                    'accreditation' => 'A (Unggul)',
                    'permit_number' => '842/E/O/2021',
                    'headmaster_name' => match ($school->username) {
                        'smk_demo' => 'Drs. H. Hendra Setiawan, M.Pd.',
                        default => 'Prof. Dr. Ir. H. Bambang Sudarsono, M.Ds.',
                    },
                    'headmaster_nip' => '19740512 199903 1 004',
                    'official_phone' => '(021) 8849-201',
                    'official_email' => match ($school->username) {
                        'smk_demo' => 'info@smkn1kreasi.sch.id',
                        default => 'kemitraan@isrk.ac.id',
                    },
                    'website' => match ($school->username) {
                        'smk_demo' => 'https://smkn1kreasi.sch.id',
                        default => 'https://isrk.ac.id',
                    },
                    'address' => 'Jl. Pendidikan Kreatif No. 45, Kampus Budaya Vokasi Terpadu, Jakarta Selatan',
                    'city' => 'Jakarta Selatan, DKI Jakarta',
                    'postal_code' => '12340',
                    'total_students' => '1.250',
                    'total_prodi' => '5 Program Keahlian',
                    'industry_partners_count' => '24 Mitra Industri',
                ],
                'published_at' => Carbon::now(),
            ],
        ];

        // ── FITUR 1: PROFIL INSTITUSI & PROGRAM STUDI ────────────────────────────
        $studyPrograms = [
            [
                'resource_type' => 'study_programs',
                'title' => 'S1 / D4 Desain Komunikasi Visual (DKV)',
                'description' => 'Program studi unggulan fokus pada Brand Identity, UI/UX Design, Motion Graphics, dan Desain Interaktif berbasis kebutuhan industri digital modern.',
                'status' => 'published',
                'metadata' => [
                    'degree' => 'D4 / Sarjana Terapan',
                    'faculty' => 'Fakultas Desain & Industri Kreatif',
                    'accreditation' => 'Unggul (BAN-PT)',
                    'total_students' => 340,
                    'employment_rate' => '94.2%',
                    'head_of_program' => 'Dr. Maya Kartika, M.Ds.',
                    'featured_skills' => ['UI/UX Design', 'Brand Identity', 'Motion Graphics', 'Design System'],
                    'curriculum_type' => 'Kurikulum Berbasis MBKM & Kemitraan Industri',
                ],
                'published_at' => Carbon::now()->subMonths(3),
            ],
            [
                'resource_type' => 'study_programs',
                'title' => 'D4 Animasi & Pemodelan 3D',
                'description' => 'Mencetak profesional 3D Artist, Character Rigger, Environment Modeler, dan Animator dengan pipeline standar studio film animasi dan game global.',
                'status' => 'published',
                'metadata' => [
                    'degree' => 'D4 / Sarjana Terapan',
                    'faculty' => 'Fakultas Media Rekam & Animasi',
                    'accreditation' => 'Unggul (BAN-PT)',
                    'total_students' => 220,
                    'employment_rate' => '96.5%',
                    'head_of_program' => 'Budi Wicaksono, M.Sn.',
                    'featured_skills' => ['Maya', 'Blender', 'ZBrush', 'Character Rigging', 'Unreal Engine'],
                    'curriculum_type' => 'Production Pipeline Based Learning',
                ],
                'published_at' => Carbon::now()->subMonths(3),
            ],
            [
                'resource_type' => 'study_programs',
                'title' => 'D4 Rekayasa Perangkat Lunak Aplikasi (RPL)',
                'description' => 'Pengembangan software modern, mobile app multiplatform, web engineering, dan kecerdasan buatan terapan untuk ekosistem kreatif.',
                'status' => 'published',
                'metadata' => [
                    'degree' => 'D4 / Sarjana Terapan',
                    'faculty' => 'Fakultas Teknologi Informasi',
                    'accreditation' => 'A',
                    'total_students' => 280,
                    'employment_rate' => '92.8%',
                    'head_of_program' => 'Ahmad Fauzi, S.Kom., M.T.',
                    'featured_skills' => ['Flutter', 'Laravel', 'React/Next.js', 'REST API', 'DevOps'],
                    'curriculum_type' => 'Industry-Driven Project Based Learning',
                ],
                'published_at' => Carbon::now()->subMonths(3),
            ],
            [
                'resource_type' => 'study_programs',
                'title' => 'D3 Produksi Siaran Film & Televisi',
                'description' => 'Pendidikan vokasi bidang sinematografi, directing, sound recording lapangan, editing video profesional, dan manajemen produksi penyiaran digital.',
                'status' => 'published',
                'metadata' => [
                    'degree' => 'D3 / Ahli Madya',
                    'faculty' => 'Fakultas Media Rekam & Animasi',
                    'accreditation' => 'A',
                    'total_students' => 190,
                    'employment_rate' => '89.5%',
                    'head_of_program' => 'Dian Safitri, M.Sn.',
                    'featured_skills' => ['Sinematografi', 'DaVinci Resolve', 'Directing', 'Broadcast Audio'],
                    'curriculum_type' => 'Studio & Field Production Mentoring',
                ],
                'published_at' => Carbon::now()->subMonths(3),
            ],
            [
                'resource_type' => 'study_programs',
                'title' => 'D4 Tata Suara & Komposisi Musik Digital',
                'description' => 'Spesialisasi audio engineering, game sound design, foley artist, audio post-production 5.1/Dolby Atmos, dan komposisi musik scoring.',
                'status' => 'published',
                'metadata' => [
                    'degree' => 'D4 / Sarjana Terapan',
                    'faculty' => 'Fakultas Seni Pertunjukan & Musik',
                    'accreditation' => 'A',
                    'total_students' => 140,
                    'employment_rate' => '87.4%',
                    'head_of_program' => 'Bimo Setiawan, S.Sn.',
                    'featured_skills' => ['Logic Pro', 'Pro Tools', 'Sound Design', 'Foley', 'Dolby Atmos'],
                    'curriculum_type' => 'Masterclass & Studio Apprenticeship',
                ],
                'published_at' => Carbon::now()->subMonths(3),
            ],
        ];

        // ── FITUR 2: MANAJEMEN KEGIATAN, EVENT, DAN LOMBA ─────────────────────────
        $events = [
            [
                'resource_type' => 'events',
                'title' => 'Kreavana Annual Creative Showcase & Expo 2026',
                'description' => 'Pameran akbar 150+ portofolio karya tugas akhir mahasiswa, temu praktisi industri, dan pitching proyek kreatif ke calon investor & studio partner.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Pameran & Expo',
                    'event_date' => Carbon::now()->addDays(24)->format('Y-m-d'),
                    'location' => 'Grand Exhibition Hall Kampus Terpadu ISRK & Virtual Room',
                    'registered_participants' => 450,
                    'max_capacity' => 600,
                    'target_audience' => 'Mahasiswa, Industri, Siswa SMA/SMK, Publik',
                    'is_competition' => false,
                ],
                'published_at' => Carbon::now()->subDays(5),
            ],
            [
                'resource_type' => 'events',
                'title' => 'National Creative Hackathon & Game Jam 2026',
                'description' => 'Kompetisi 48 jam pembuatan prototipe game edukasi bertema kearifan lokal nusantara, kolaborasi tim developer, 3D artist, dan audio designer.',
                'status' => 'open',
                'metadata' => [
                    'category' => 'Kompetisi & Lomba',
                    'event_date' => Carbon::now()->addDays(38)->format('Y-m-d'),
                    'location' => 'Inkubator Kreatif Lantai 4 ISRK & Hybrid Online',
                    'registered_participants' => 78,
                    'max_capacity' => 120,
                    'total_prize' => 'Rp 50.000.000',
                    'target_audience' => 'Mahasiswa & Pelajar Nasional',
                    'is_competition' => true,
                ],
                'published_at' => Carbon::now()->subDays(7),
            ],
            [
                'resource_type' => 'events',
                'title' => 'Masterclass Industri: Standarisasi Pipeline 3D Studio Global',
                'description' => 'Kuliah tamu dan pelatihan intensif implementasi pipeline produksi film animasi 3D berstandar Hollywood bersama praktisi industri.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Workshop & Kuliah Tamu',
                    'event_date' => Carbon::now()->addDays(12)->format('Y-m-d'),
                    'location' => 'Auditorium Teater ISRK',
                    'registered_participants' => 180,
                    'max_capacity' => 200,
                    'speaker' => 'Senior Technical Director - Global Animation Studio',
                    'is_competition' => false,
                ],
                'published_at' => Carbon::now()->subDays(2),
            ],
            [
                'resource_type' => 'events',
                'title' => 'Sayembara Desain Identitas Brand & Kemasan UMKM Nusantara',
                'description' => 'Lomba desain kemasan dan logo UMKM binaan daerah guna meningkatkan daya saing produk lokal di pasar nasional dan ekspor.',
                'status' => 'in_progress',
                'metadata' => [
                    'category' => 'Lomba Desain',
                    'event_date' => Carbon::now()->addDays(18)->format('Y-m-d'),
                    'location' => 'Online Submission via Portal Kreavana',
                    'registered_participants' => 112,
                    'total_prize' => 'Rp 25.000.000',
                    'is_competition' => true,
                ],
                'published_at' => Carbon::now()->subDays(10),
            ],
            [
                'resource_type' => 'events',
                'title' => 'Career Fair Industri Kreatif & Walk-In Interview Magang 2026',
                'description' => 'Ajang rekrutmen langsung magang PKL/MBKM dan lowongan kerja fresh graduate bersama 25 perusahaan mitra industri kreatif ternama.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Job Fair & Rekrutmen',
                    'event_date' => Carbon::now()->addDays(30)->format('Y-m-d'),
                    'location' => 'Plaza Kreatif Kampus ISRK',
                    'registered_participants' => 380,
                    'participating_companies' => 25,
                    'is_competition' => false,
                ],
                'published_at' => Carbon::now()->subDays(4),
            ],
        ];

        // (Catatan: Pengadaan / Vendor / Tenders khusus untuk akun Corporate, tidak disediakan untuk institusi pendidikan)

        // ── FITUR 4: DIREKTORI MITRA DAN INDUSTRI (PARTNERS) ──────────────────────
        $partners = [
            [
                'resource_type' => 'partners',
                'title' => 'Google Indonesia (PT Google Cloud & Services)',
                'description' => 'Kerjasama strategis program sertifikasi talenta vokasi Google Career Certificates, beasiswa pengembangan AI & Cloud Computing, serta penyelarasan kurikulum teknologi.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Teknologi Cloud & AI',
                    'logo_asset' => 'assets/partners/google.png',
                    'mou_number' => '012/MoU-ISRK/I/2026',
                    'mou_period' => '2026 - 2029 (Aktif)',
                    'pic_name' => 'Jessica Wijaya',
                    'pic_role' => 'Education & Ecosystem Lead',
                    'contact' => 'kemitraan.id@google.com',
                    'phone' => '+62 21-5085-8000',
                    'website' => 'https://about.google',
                    'internship_quota_yearly' => 20,
                    'collaborative_projects' => 6,
                    'verified_badge' => true,
                ],
                'published_at' => Carbon::now()->subMonths(1),
            ],
            [
                'resource_type' => 'partners',
                'title' => 'PT Studio Animasi Nusantara',
                'description' => 'Studio animasi 3D spesialis feature film dan serial animasi internasional. Mitra strategis penyedia tempat magang PKL dan kurikulum vokasi.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Studio Animasi & Game',
                    'logo_asset' => 'assets/partners/animasi_nusantara.png',
                    'mou_number' => '042/MoU-ISRK/IV/2025',
                    'mou_period' => '2025 - 2028 (Aktif)',
                    'pic_name' => 'Hendra Gunawan, S.Sn.',
                    'pic_role' => 'Studio Director',
                    'contact' => 'kemitraan@animasinusantara.id',
                    'phone' => '+62 812-3456-7890',
                    'website' => 'https://animasinusantara.id',
                    'internship_quota_yearly' => 15,
                    'collaborative_projects' => 4,
                    'verified_badge' => true,
                ],
                'published_at' => Carbon::now()->subMonths(6),
            ],
            [
                'resource_type' => 'partners',
                'title' => 'Pixel Creative Agency',
                'description' => 'Digital agency terkemuka berfokus pada visual branding, UI/UX mobile apps, dan kampanye media interaktif korporat.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Creative & Digital Agency',
                    'logo_asset' => 'assets/partners/pixel_creative.png',
                    'mou_number' => '088/MoU-ISRK/VII/2025',
                    'mou_period' => '2025 - 2027 (Aktif)',
                    'pic_name' => 'Maya Angelia, M.Ds.',
                    'pic_role' => 'Head of Creative',
                    'contact' => 'partner@pixelcreatives.id',
                    'phone' => '+62 813-9876-5432',
                    'website' => 'https://pixelcreatives.id',
                    'internship_quota_yearly' => 10,
                    'collaborative_projects' => 3,
                    'verified_badge' => true,
                ],
                'published_at' => Carbon::now()->subMonths(5),
            ],
            [
                'resource_type' => 'partners',
                'title' => 'PT Svara Audio Solusindo',
                'description' => 'Penyedia solusi tata suara profesional, fasilitas mastering studio rekaman, dan sound library untuk media game & film.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Sound & Music Production',
                    'logo_asset' => 'assets/partners/svara_audio.png',
                    'mou_number' => '015/MoU-ISRK/I/2025',
                    'mou_period' => '2025 - 2028 (Aktif)',
                    'pic_name' => 'Bimo Setiawan',
                    'pic_role' => 'Lead Audio Engineer',
                    'contact' => 'bimo@svarasound.id',
                    'phone' => '+62 811-2233-4455',
                    'website' => 'https://svarasound.id',
                    'internship_quota_yearly' => 6,
                    'collaborative_projects' => 2,
                    'verified_badge' => true,
                ],
                'published_at' => Carbon::now()->subMonths(8),
            ],
            [
                'resource_type' => 'partners',
                'title' => 'PT Media Cakrawala Siber',
                'description' => 'Perusahaan penyiaran multimedia, live broadcast multi-camera, dan digital content production house skala nasional.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Broadcasting & Production House',
                    'logo_asset' => 'assets/partners/cakrawala_media.png',
                    'mou_number' => '102/MoU-ISRK/X/2024',
                    'mou_period' => '2024 - 2027 (Aktif)',
                    'pic_name' => 'Dian Safitri, S.I.Kom.',
                    'pic_role' => 'Executive Producer',
                    'contact' => 'production@cakrawalamedia.id',
                    'phone' => '+62 815-6677-8899',
                    'website' => 'https://cakrawalamedia.id',
                    'internship_quota_yearly' => 12,
                    'collaborative_projects' => 5,
                    'verified_badge' => true,
                ],
                'published_at' => Carbon::now()->subMonths(9),
            ],
            [
                'resource_type' => 'partners',
                'title' => 'Asosiasi Desainer Grafis Indonesia (ADGI)',
                'description' => 'Organisasi profesi desainer grafis resmi di Indonesia. Mitra sertifikasi kompetensi, kurasi portofolio, dan pembinaan standar etika profesi.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Organisasi & Asosiasi Profesi',
                    'logo_asset' => 'assets/partners/adgi.png',
                    'mou_number' => '029/MoU-ISRK/II/2025',
                    'mou_period' => '2025 - 2029 (Aktif)',
                    'pic_name' => 'Rian Santoso',
                    'pic_role' => 'Ketua Chapter Daerah',
                    'contact' => 'sekretariat@adgi.or.id',
                    'phone' => '+62 821-4455-6677',
                    'website' => 'https://adgi.or.id',
                    'internship_quota_yearly' => 8,
                    'collaborative_projects' => 6,
                    'verified_badge' => true,
                ],
                'published_at' => Carbon::now()->subMonths(7),
            ],
            [
                'resource_type' => 'partners',
                'title' => 'Nusantara Game Developer Guild',
                'description' => 'Komunitas pengembang game independen terbesar dengan jejaring 200+ indie studio di Jawa Timur dan Indonesia.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Komunitas Kreator & Game Dev',
                    'logo_asset' => 'assets/partners/game_guild.png',
                    'mou_number' => '054/MoU-ISRK/V/2025',
                    'mou_period' => '2025 - 2027 (Aktif)',
                    'pic_name' => 'Kevin Anggoro',
                    'pic_role' => 'Koordinator Komunitas',
                    'contact' => 'guild@nusantaragame.id',
                    'phone' => '+62 817-8899-0011',
                    'website' => 'https://nusantaragame.id',
                    'internship_quota_yearly' => 10,
                    'collaborative_projects' => 4,
                    'verified_badge' => true,
                ],
                'published_at' => Carbon::now()->subMonths(4),
            ],
        ];

        // ── FITUR 5: SISTEM REKRUTMEN DAN PENELUSURAN TALENTA (TALENTS) ───────────
        $talents = [
            [
                'resource_type' => 'talents',
                'title' => 'Arya Bagaskara',
                'description' => 'Mahasiswa Semester 6 S1 Animasi 3D berfokus pada Character Modeling, Hard Surface Asset, dan Texturing berstandar pipeline AAA Game.',
                'status' => 'published',
                'metadata' => [
                    'role_label' => 'Mahasiswa Tingkat Akhir',
                    'study_program' => 'D4 Animasi & Pemodelan 3D',
                    'nim' => '2141010045',
                    'gpa' => '3.88',
                    'status_talent' => 'Siap Magang / PKL',
                    'rating' => 4.9,
                    'portfolio_count' => 8,
                    'skills' => ['Blender', 'Autodesk Maya', 'ZBrush', 'Substance 3D', 'Unreal Engine'],
                    'email' => 'arya.bagaskara@student.isrk.ac.id',
                    'phone' => '+62 812-9988-7766',
                    'achievements' => 'Juara 1 Lomba 3D Character Design Nasional 2025',
                ],
                'published_at' => Carbon::now()->subDays(10),
            ],
            [
                'resource_type' => 'talents',
                'title' => 'Nadia Safitri',
                'description' => 'Mahasiswa Semester 7 D4 DKV dengan keahlian mendalam di bidang UI/UX Design, Figma Component System, Interactive Prototyping, dan Design Thinking.',
                'status' => 'published',
                'metadata' => [
                    'role_label' => 'Mahasiswa Tingkat Akhir',
                    'study_program' => 'S1 / D4 Desain Komunikasi Visual',
                    'nim' => '2141020088',
                    'gpa' => '3.92',
                    'status_talent' => 'Siap Magang / PKL',
                    'rating' => 5.0,
                    'portfolio_count' => 11,
                    'skills' => ['UI/UX Design', 'Figma', 'Design System', 'User Testing', 'Micro-Interactions'],
                    'email' => 'nadia.safitri@student.isrk.ac.id',
                    'phone' => '+62 813-2211-4433',
                    'achievements' => 'Best UI/UX Award Kreavana Student Showcase 2025',
                ],
                'published_at' => Carbon::now()->subDays(8),
            ],
            [
                'resource_type' => 'talents',
                'title' => 'Budi Wicaksono, M.Sn.',
                'description' => 'Dosen Pembimbing Riset & Praktisi Media Interaktif. Berpengalaman 12 tahun membimbing proyek animasi 3D, konservasi budaya digital, dan kurasi karya.',
                'status' => 'published',
                'metadata' => [
                    'role_label' => 'Dosen Pembimbing & Peneliti',
                    'study_program' => 'D4 Animasi & Pemodelan 3D',
                    'nidn' => '0714088201',
                    'status_talent' => 'Tersedia untuk Riset Kolaborasi',
                    'rating' => 5.0,
                    'publications_count' => 14,
                    'skills' => ['Research Methodology', '3D Pipeline', 'Heritage Archiving', 'Curatorial'],
                    'email' => 'budi.wicaksono@isrk.ac.id',
                    'phone' => '+62 811-3322-1100',
                    'achievements' => 'Penerima Hibah Riset Terapan Kemendikbudristek 2024 & 2025',
                ],
                'published_at' => Carbon::now()->subMonths(1),
            ],
            [
                'resource_type' => 'talents',
                'title' => 'Rian Pratama, S.Tr.Kom.',
                'description' => 'Alumni Lulusan D4 RPL berprestasi dengan keahlian Fullstack Mobile Developer Flutter & Laravel, siap direkrut secara profesional.',
                'status' => 'published',
                'metadata' => [
                    'role_label' => 'Alumni Fresh Graduate',
                    'study_program' => 'D4 Rekayasa Perangkat Lunak Aplikasi',
                    'nim' => '2041030012',
                    'gpa' => '3.85',
                    'status_talent' => 'Siap Kerja / Rekrutmen',
                    'rating' => 4.8,
                    'portfolio_count' => 12,
                    'skills' => ['Flutter', 'Dart', 'Laravel', 'REST API', 'MySQL/PostgreSQL', 'Git'],
                    'email' => 'rian.pratama@alumni.isrk.ac.id',
                    'phone' => '+62 856-7788-9900',
                    'achievements' => 'Certified Associate Mobile Developer & Juara Hackathon 2024',
                ],
                'published_at' => Carbon::now()->subDays(12),
            ],
            [
                'resource_type' => 'talents',
                'title' => 'Dewi Anggraini',
                'description' => 'Mahasiswa Semester 5 D3 Siaran Film dengan keahlian sinematografi, operasional kamera multi-angle, and Color Grading DaVinci Resolve.',
                'status' => 'published',
                'metadata' => [
                    'role_label' => 'Mahasiswa Aktif',
                    'study_program' => 'D3 Produksi Siaran Film & Televisi',
                    'nim' => '2231040033',
                    'gpa' => '3.79',
                    'status_talent' => 'Siap Magang / PKL',
                    'rating' => 4.9,
                    'portfolio_count' => 7,
                    'skills' => ['DaVinci Resolve', 'Sinematografi', 'Camera Operator', 'Lighting Setup'],
                    'email' => 'dewi.anggraini@student.isrk.ac.id',
                    'phone' => '+62 878-1122-3344',
                    'achievements' => 'Best Cinematography Festival Film Pendek Mahasiswa 2025',
                ],
                'published_at' => Carbon::now()->subDays(5),
            ],
            [
                'resource_type' => 'talents',
                'title' => 'Rendy Kurniawan',
                'description' => 'Mahasiswa Semester 6 D4 Tata Suara dengan spesialisasi Foley Artist, Game Audio Implementation (Wwise/FMOD), and Surround Sound Mixing.',
                'status' => 'published',
                'metadata' => [
                    'role_label' => 'Mahasiswa Aktif',
                    'study_program' => 'D4 Tata Suara & Komposisi Musik Digital',
                    'nim' => '2141050019',
                    'gpa' => '3.82',
                    'status_talent' => 'Siap Magang / PKL',
                    'rating' => 4.8,
                    'portfolio_count' => 9,
                    'skills' => ['Logic Pro X', 'Foley Recording', 'FMOD', 'Sound FX Design', 'Mixing 5.1'],
                    'email' => 'rendy.kurniawan@student.isrk.ac.id',
                    'phone' => '+62 822-4455-6677',
                    'achievements' => 'Lead Sound Designer Game Nusantara Heritage terpilih di Expo 2025',
                ],
                'published_at' => Carbon::now()->subDays(4),
            ],
        ];

        // ── FITUR 6: LAPORAN ANALITIK, MONITORING & EVALUASI ─────────────────────
        $reports = [
            [
                'resource_type' => 'reports',
                'title' => 'Laporan Akuntabilitas Kinerja Serapan Magang MBKM 2025/2026',
                'description' => 'Evaluasi capaian penempatan 168 mahasiswa pada 24 industri mitra dengan tingkat keberhasilan penyelesaian magang mencapai 98.2%.',
                'status' => 'published',
                'metadata' => [
                    'period' => 'Tahun Ajaran 2025/2026',
                    'category' => 'Laporan Evaluasi MBKM',
                    'total_interns' => 168,
                    'completion_rate' => '98.2%',
                    'partner_satisfaction' => '4.9 / 5.0',
                    'employment_offer_rate' => '42.5%',
                    'signatory' => 'Wakil Rektor Bidang Akademik & Kerjasama',
                ],
                'published_at' => Carbon::now()->subDays(14),
            ],
            [
                'resource_type' => 'reports',
                'title' => 'Survei Kepuasan Industri Terhadap Kualitas Lulusan & Talenta Vokasi',
                'description' => 'Hasil survei umpan balik dari 32 industri mitra yang mempekerjakan lulusan ISRK di bidang software, animasi, dan desain.',
                'status' => 'published',
                'metadata' => [
                    'period' => 'Semester Genap 2025',
                    'category' => 'Survei Kepuasan Pengguna',
                    'satisfaction_score' => 94.6,
                    'key_strengths' => 'Etos Kerja, Kesiapan Skill Teknis, Adaptabilitas Software',
                ],
                'published_at' => Carbon::now()->subDays(25),
            ],
            [
                'resource_type' => 'reports',
                'title' => 'Laporan Capaian Akreditasi Institusi & Kemitraan DUDI Berkelanjutan',
                'description' => 'Rangkuman pemenuhan 9 kriteria akreditasi unggul BAN-PT serta dampak kemitraan industri terhadap peningkatan kompetensi pendidik.',
                'status' => 'published',
                'metadata' => [
                    'period' => 'Triwulan III 2026',
                    'category' => 'Laporan Akreditasi & Mutu',
                    'criteria_met' => '9 dari 9 Kriteria',
                    'status_accreditation' => 'Unggul',
                ],
                'published_at' => Carbon::now()->subDays(6),
            ],
        ];

        // ── DOKUMEN & MOU KAMPUS ──────────────────────────────────────────────────
        $documents = [
            [
                'resource_type' => 'documents',
                'title' => 'Perjanjian Kerjasama (MoU) Induk Kemitraan Kampus - DUDI 2025-2028',
                'description' => 'Dokumen resmi legalitas kerjasama strategis pelaksanaan magang bersertifikat, kurikulum bersama, dan riset kolaborasi industri.',
                'status' => 'published',
                'metadata' => [
                    'document_number' => '001/MOU-ISRK/DIR/2025',
                    'valid_until' => '2028-12-31',
                    'file_format' => 'PDF',
                    'file_size' => '2.4 MB',
                    'verified' => true,
                ],
                'published_at' => Carbon::now()->subMonths(10),
            ],
            [
                'resource_type' => 'documents',
                'title' => 'Sertifikat Akreditasi Institusi Predikat Unggul (BAN-PT)',
                'description' => 'Surat Keputusan Badan Akreditasi Nasional Perguruan Tinggi Nomor 412/SK/BAN-PT/Ak/PT/2024.',
                'status' => 'published',
                'metadata' => [
                    'sk_number' => '412/SK/BAN-PT/Ak/PT/2024',
                    'valid_until' => '2029-08-15',
                    'grade' => 'Unggul',
                ],
                'published_at' => Carbon::now()->subMonths(12),
            ],
            [
                'resource_type' => 'documents',
                'title' => 'Pedoman Teknis Magang PKL & Skema Konversi 20 SKS MBKM',
                'description' => 'Buku panduan lengkap alur pendaftaran, pembimbingan dosen, logbook harian, dan evaluasi nilai industri untuk konversi SKS.',
                'status' => 'published',
                'metadata' => [
                    'edition' => 'Edisi Revisi 2026',
                    'pages' => 48,
                ],
                'published_at' => Carbon::now()->subMonths(2),
            ],
        ];

        // ── KARYA SISWA / SHOWCASES ───────────────────────────────────────────────
        $showcases = [
            [
                'resource_type' => 'showcases',
                'title' => 'Film Pendek Animasi 3D "Nusantara Heritage"',
                'description' => 'Karya tugas akhir siswa jurusan Animasi 3D bertema kekayaan folklore budaya nusantara berdurasi 7 menit dengan standar pipeline Unreal Engine 5.',
                'status' => 'published',
                'metadata' => [
                    'creator' => 'Arya Bagaskara & Tim Studio Animasi ISRK',
                    'category' => 'Animasi 3D',
                    'year' => '2026',
                    'award' => 'Best Animation Short Film Kreavana 2026',
                ],
                'published_at' => Carbon::now()->subDays(15),
            ],
            [
                'resource_type' => 'showcases',
                'title' => 'Desain Branding & Kemasan UMKM Rempah Nusantara',
                'description' => 'Portofolio redesign identitas visual menyeluruh, standarisasi kemasan ramah lingkungan, dan brand guidelines 40 halaman.',
                'status' => 'published',
                'metadata' => [
                    'creator' => 'Nadia Safitri (Prodi DKV)',
                    'category' => 'Visual Branding & UI/UX',
                    'year' => '2026',
                ],
                'published_at' => Carbon::now()->subDays(20),
            ],
            [
                'resource_type' => 'showcases',
                'title' => 'Aplikasi Mobile "KreasiBudaya" Berbasis Flutter',
                'description' => 'Aplikasi pencarian sanggar seni lokal, reservasi tiket pameran, dan kurasi karya seni digital nusantara dengan backend microservice.',
                'status' => 'published',
                'metadata' => [
                    'creator' => 'Rian Pratama (Prodi RPL)',
                    'category' => 'Mobile Engineering',
                    'year' => '2025',
                ],
                'published_at' => Carbon::now()->subDays(30),
            ],
        ];

        // ── TIM & HAK AKSES SEKOLAH (MEMBERS) ────────────────────────────────────
        $members = [
            [
                'resource_type' => 'members',
                'title' => 'Dra. Sri Wahyuni, M.Pd.',
                'description' => 'Kepala Pusat Kemitraan Industri & Urusan Karir Vokasi',
                'status' => 'published',
                'metadata' => [
                    'role' => 'Karyawan / Staf',
                    'role_access' => 'Administrator Kerjasama',
                    'nip' => '197205121998032001',
                    'email' => 'sri.wahyuni@isrk.ac.id',
                    'permissions' => ['mitra_industri', 'dokumen_institusi', 'laporan_kegiatan'],
                ],
                'published_at' => Carbon::now()->subMonths(10),
            ],
            [
                'resource_type' => 'members',
                'title' => 'Budi Santoso, S.T., M.Kom.',
                'description' => 'Koordinator Program MBKM & Magang Industri',
                'status' => 'published',
                'metadata' => [
                    'role' => 'Karyawan / Staf',
                    'role_access' => 'Koordinator Magang',
                    'nip' => '198103142006041002',
                    'email' => 'budi.santoso@isrk.ac.id',
                    'permissions' => ['program_magang', 'monitoring_evaluasi', 'laporan_kegiatan'],
                ],
                'published_at' => Carbon::now()->subMonths(8),
            ],
            [
                'resource_type' => 'members',
                'title' => 'Ahmad Fauzi, S.Kom., M.T.',
                'description' => 'Ketua Jurusan Teknologi Informasi & Rekayasa Perangkat Lunak',
                'status' => 'published',
                'metadata' => [
                    'role' => 'Karyawan / Staf',
                    'role_access' => 'Ketua Program Studi',
                    'nip' => '198509202010121003',
                    'email' => 'ahmad.fauzi@isrk.ac.id',
                    'permissions' => ['karya_siswa', 'kegiatan_event', 'pengumuman_institusi'],
                ],
                'published_at' => Carbon::now()->subMonths(6),
            ],
            [
                'resource_type' => 'members',
                'title' => 'Siti Rahmawati, S.Pd.',
                'description' => 'Staf Administrasi & Database Penelusuran Talenta',
                'status' => 'published',
                'metadata' => [
                    'role' => 'Karyawan / Staf',
                    'role_access' => 'Staf Database & Rekrutmen',
                    'nip' => '199201082019032014',
                    'email' => 'siti.rahmawati@isrk.ac.id',
                    'permissions' => ['kegiatan_event', 'pengumuman_institusi'],
                ],
                'published_at' => Carbon::now()->subMonths(4),
            ],
        ];

        // ── PENGUMUMAN PUBLIK SEKOLAH (ANNOUNCEMENTS) ────────────────────────────
        $announcements = [
            [
                'resource_type' => 'announcements',
                'title' => 'Pembukaan Pendaftaran Magang MBKM & Kemitraan Industri Batch Genap 2026',
                'description' => 'Pendaftaran program magang bersertifikat pada 24 studio dan agensi kreatif resmi dibuka bagi mahasiswa semester 5 ke atas dengan konversi 20 SKS.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Akademik & Magang',
                    'valid_until' => Carbon::now()->addMonths(2)->format('Y-m-d'),
                    'target_audience' => 'Mahasiswa Aktif Semester 5-8',
                    'author' => 'Pusat Karir & MBKM ISRK',
                ],
                'published_at' => Carbon::now()->subDays(2),
            ],
            [
                'resource_type' => 'announcements',
                'title' => 'Jadwal Pelaksanaan Sidang Terbuka & Showcase Karya Wisuda TA 2026',
                'description' => 'Seluruh karya tugas akhir animasi 3D, DKV, game, film pendek, dan audio mixing akan dipamerkan di hadapan kurator industri dan publik.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Agenda & Showcase',
                    'valid_until' => Carbon::now()->addMonths(3)->format('Y-m-d'),
                    'target_audience' => 'Sivitas Akademika & Mitra Industri',
                    'author' => 'Biro Akademik & Kemahasiswaan',
                ],
                'published_at' => Carbon::now()->subDays(5),
            ],
            [
                'resource_type' => 'announcements',
                'title' => 'Pengajuan Proposal Riset Terapan Kolaboratif DUDI Skema Kedaireka & Hibah Vokasi',
                'description' => 'Dosen dan mahasiswa diundang mengajukan usulan riset bersama studio animasi, pengembang software, dan agensi desain periklanan.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Riset & Hibah',
                    'valid_until' => Carbon::now()->addMonth()->format('Y-m-d'),
                    'target_audience' => 'Dosen & Kelompok Riset Mahasiswa',
                    'author' => 'LPPM ISRK',
                ],
                'published_at' => Carbon::now()->subDays(9),
            ],
            [
                'resource_type' => 'announcements',
                'title' => 'Pemberian Beasiswa Prestasi & Bebas Biaya Studio bagi Talenta Kreatif Berprestasi',
                'description' => 'Daftar nama 25 mahasiswa peraih penghargaan kompetisi tingkat nasional berhak menerima beasiswa bebas UKT dan akses lab workstation 24 jam.',
                'status' => 'published',
                'metadata' => [
                    'category' => 'Beasiswa & Prestasi',
                    'valid_until' => Carbon::now()->addMonths(4)->format('Y-m-d'),
                    'target_audience' => 'Mahasiswa Berprestasi',
                    'author' => 'Wakil Rektor Bidang Kemahasiswaan',
                ],
                'published_at' => Carbon::now()->subDays(12),
            ],
        ];

        // ── FASILITAS & SARANA KAMPUS (FACILITIES) ────────────────────────────────
        $facilities = [
            [
                'resource_type' => 'facilities',
                'title' => 'Studio Animasi 3D & Optical Motion Capture Laboratory',
                'description' => 'Fasilitas berstandar industri dengan 16 kamera Vicon Optical, 30 unit Workstation RTX 4090, dan lisensi Unreal Engine 5 Enterprise.',
                'status' => 'active',
                'metadata' => [
                    'facilities' => '16 Vicon Optic Cameras, MoCap Suits, 30x PC RTX 4090, Render Farm 64 Nodes',
                    'terms' => 'Pengajuan izin H-3 melalui Ketua Prodi Animasi, prioritas produksi karya MBKM & industri.',
                    'manager' => 'Kepala Lab Studio Animasi & Game ISRK',
                    'capacity' => '40 Mahasiswa',
                ],
                'published_at' => Carbon::now()->subMonths(6),
            ],
            [
                'resource_type' => 'facilities',
                'title' => 'Auditorium Pertunjukan & Screening Cinema 4K Dolby Atmos',
                'description' => 'Ruang screening film dan bioskop kampus dengan proyeksi 4K Laser Christie, tata suara Dolby Atmos 7.1.4, kapasitas 350 kursi ergonomis.',
                'status' => 'active',
                'metadata' => [
                    'facilities' => 'Laser Christie 4K Projector, Dolby Atmos Cinema Processor, Layar Akustik 12x6m, Tata Cahaya DMX',
                    'terms' => 'Peminjaman untuk pemutaran film, seminar industri, atau showcase karya mahasiswa.',
                    'manager' => 'UPT Sarana Pertunjukan & Acara Kampus',
                    'capacity' => '350 Tempat Duduk',
                ],
                'published_at' => Carbon::now()->subMonths(8),
            ],
            [
                'resource_type' => 'facilities',
                'title' => 'Laboratorium Desain Grafis & Mac Studio M2 Ultra Retina 5K',
                'description' => 'Lab komputasi visual dengan 36 unit Apple Mac Studio dan display Studio Display Retina 5K untuk editing resolusi tinggi, UI/UX, dan branding.',
                'status' => 'active',
                'metadata' => [
                    'facilities' => '36x Mac Studio M2 Ultra, 36x Studio Display 5K, Wacom Cintiq Pro 24, Adobe CC All Apps',
                    'terms' => 'Digunakan untuk perkuliahan praktikum DKV dan pengerjaan proyek desain komersial.',
                    'manager' => 'Laboran Fakultas Desain',
                    'capacity' => '36 Mahasiswa',
                ],
                'published_at' => Carbon::now()->subMonths(7),
            ],
            [
                'resource_type' => 'facilities',
                'title' => 'Sound Stage & Studio Recording Audio Digital',
                'description' => 'Studio rekaman musik, foley artis, dubbing film, dan sound design dengan ruang kedap suara akustik RT60 0.28s dan konsol SSL AWS 948.',
                'status' => 'active',
                'metadata' => [
                    'facilities' => 'SSL AWS 948 Console, Genelec 8351B Surround Monitor, Neumann U87 Microphone, Pro Tools HDX',
                    'terms' => 'Izin pemakaian terkoordinasi dengan pengampu matakuliah penataan suara & scoring film.',
                    'manager' => 'Kepala Lab Tata Suara & Musik',
                    'capacity' => '15 Mahasiswa',
                ],
                'published_at' => Carbon::now()->subMonths(5),
            ],
        ];

        // ── MONITORING & EVALUASI MUTU (MONITORING) ──────────────────────────────
        $monitoring = [
            [
                'resource_type' => 'monitoring',
                'title' => 'Tingkat Keterserapan Lulusan Vokasi dalam 3 Bulan Pasca Kelulusan',
                'description' => 'Pemantauan tracer study alumni yang bekerja di industri kreatif, berwirausaha digital, atau melanjutkan studi dengan gaji minimal 1.5x UMR.',
                'status' => 'in_progress',
                'metadata' => [
                    'indicator' => 'IKU 1: Lulusan Mendapat Pekerjaan Layak',
                    'progress' => 94,
                    'target_date' => '2026-12-31',
                    'category' => 'Indikator Kinerja Utama (IKU)',
                ],
                'published_at' => Carbon::now()->subMonths(3),
            ],
            [
                'resource_type' => 'monitoring',
                'title' => 'Realisasi Program Magang Bersertifikat Industri (MBKM Mandiri)',
                'description' => 'Monitoring mahasiswa peserta magang pada 24 industri mitra dengan laporan logbook mingguan dan pembimbingan dosen berkala.',
                'status' => 'in_progress',
                'metadata' => [
                    'indicator' => 'IKU 2: Mahasiswa Mendapat Pengalaman di Luar Kampus',
                    'progress' => 88,
                    'target_date' => '2026-11-30',
                    'category' => 'Program MBKM',
                ],
                'published_at' => Carbon::now()->subMonths(2),
            ],
            [
                'resource_type' => 'monitoring',
                'title' => 'Penyelarasan Kurikulum Vokasi dengan Kebutuhan Industri Kreatif (DUDI)',
                'description' => 'Penyusunan modul ajar bersama praktisi industri, evaluasi silabus tahunan, dan penerapan Project-Based Learning (PBL).',
                'status' => 'completed',
                'metadata' => [
                    'indicator' => 'IKU 7: Pembelajaran Kelas Kolaboratif & Partisipatif',
                    'progress' => 100,
                    'target_date' => '2026-09-30',
                    'category' => 'Kurikulum Vokasi',
                ],
                'published_at' => Carbon::now()->subMonths(4),
            ],
            [
                'resource_type' => 'monitoring',
                'title' => 'Sertifikasi Kompetensi BNSP / Skema Standar Industri bagi Mahasiswa Akhir',
                'description' => 'Uji kompetensi profesi untuk skema Desainer Grafis Madya, Animator 3D, dan Junior Mobile Developer bersama LSP P1 ISRK.',
                'status' => 'in_progress',
                'metadata' => [
                    'indicator' => 'IKU 4: Sertifikasi Keahlian Mahasiswa',
                    'progress' => 76,
                    'target_date' => '2027-01-20',
                    'category' => 'Sertifikasi Profesi',
                ],
                'published_at' => Carbon::now()->subMonth(),
            ],
        ];

        // ── ANGGARAN & DANA HIBAH KAMPUS (BUDGETS) ────────────────────────────────
        $budgets = [
            [
                'resource_type' => 'budgets',
                'title' => 'Hibah Program Revitalisasi Perguruan Tinggi Vokasi (Kemendikbudristek TA 2026)',
                'description' => 'Alokasi pengadaan peralatan laboratorium workstation animasi 3D, render farm, dan renovasi sound stage kampus.',
                'status' => 'in_progress',
                'metadata' => [
                    'period' => 'Tahun Anggaran 2026',
                    'allocation' => 2500000000,
                    'realization' => 1850000000,
                    'category' => 'Hibah Revitalisasi Sarana',
                ],
                'published_at' => Carbon::now()->subMonths(6),
            ],
            [
                'resource_type' => 'budgets',
                'title' => 'Dana Hibah Riset Terapan Kolaboratif Kedaireka (Matching Fund)',
                'description' => 'Pendanaan proyek riset fotogrametri digital cagar budaya nusantara bekerjasama dengan PT Studio Animasi Nusantara.',
                'status' => 'in_progress',
                'metadata' => [
                    'period' => 'Semester Gasal 2026',
                    'allocation' => 850000000,
                    'realization' => 720000000,
                    'category' => 'Matching Fund Kedaireka',
                ],
                'published_at' => Carbon::now()->subMonths(4),
            ],
            [
                'resource_type' => 'budgets',
                'title' => 'Dana Bantuan Subsidi Uang Saku & Transportasi Magang MBKM Mahasiswa',
                'description' => 'Bantuan operasional bagi 180 mahasiswa peserta magang pada industri kreatif luar kota dan luar daerah.',
                'status' => 'in_progress',
                'metadata' => [
                    'period' => 'TA 2025/2026',
                    'allocation' => 450000000,
                    'realization' => 380000000,
                    'category' => 'Subsidi MBKM Mahasiswa',
                ],
                'published_at' => Carbon::now()->subMonths(5),
            ],
        ];

        // Gabungkan semua resource dan simpan ke database
        $allResources = array_merge(
            $schoolProfileResource,
            $studyPrograms,
            $events,
            $partners,
            $talents,
            $reports,
            $documents,
            $showcases,
            $members,
            $announcements,
            $facilities,
            $monitoring,
            $budgets
        );

        foreach ($allResources as $item) {
            InstitutionResource::create([
                'user_id' => $school->id,
                'resource_type' => $item['resource_type'],
                'title' => $item['title'],
                'description' => $item['description'],
                'status' => $item['status'],
                'metadata' => $item['metadata'] ?? [],
                'published_at' => $item['published_at'] ?? Carbon::now(),
            ]);
        }

        // ── KONTRAK KERJASAMA / PROYEK SEKOLAH (JobContract) ─────────────────────
        $partnerUsers = User::where('role', RoleType::Creator)->where('id', '!=', $school->id)->get();
        $sampleCreator = $partnerUsers->firstWhere('username', 'videographer_demo') ?? $partnerUsers->first();

        if ($sampleCreator) {
            JobContract::where('client_id', $school->id)->delete();

            $contracts = [
                [
                    'title' => 'Program Magang MBKM 3D Modeler Batch I 2026',
                    'description' => 'Kerjasama penempatan 10 siswa vokasi magang pada produksi serial animasi nusantara.',
                    'agreed_price' => 35000000,
                    'contract_status' => ContractStatus::Active,
                    'work_status' => WorkStatus::InProgress,
                    'scheduled_start_date' => Carbon::now()->subDays(15),
                    'scheduled_end_date' => Carbon::now()->addDays(75),
                    'deadline' => Carbon::now()->addDays(75),
                ],
                [
                    'title' => 'Riset Kolaborasi Preservasi Budaya Digital',
                    'description' => 'Proyek riset terapan dosen dan industri dalam pembuatan arsip 3D photogrammetry.',
                    'agreed_price' => 65000000,
                    'contract_status' => ContractStatus::Active,
                    'work_status' => WorkStatus::InProgress,
                    'scheduled_start_date' => Carbon::now()->subDays(30),
                    'scheduled_end_date' => Carbon::now()->addDays(60),
                    'deadline' => Carbon::now()->addDays(60),
                ],
                [
                    'title' => 'Dokumentasi Video 4K Dies Natalis & Expo Seni ISRK',
                    'description' => 'Peliputan multi-kamera dan siaran live streaming expo pameran karya siswa.',
                    'agreed_price' => 18000000,
                    'contract_status' => ContractStatus::Completed,
                    'work_status' => WorkStatus::Completed,
                    'scheduled_start_date' => Carbon::now()->subDays(45),
                    'scheduled_end_date' => Carbon::now()->subDays(40),
                    'deadline' => Carbon::now()->subDays(40),
                ],
            ];

            foreach ($contracts as $c) {
                JobContract::create([
                    'creator_id' => $sampleCreator->id,
                    'client_id' => $school->id,
                    'title' => $c['title'],
                    'description' => $c['description'],
                    'agreed_price' => $c['agreed_price'],
                    'escrow_amount' => $c['agreed_price'],
                    'creator_approved' => true,
                    'client_approved' => true,
                    'contract_status' => $c['contract_status'],
                    'work_status' => $c['work_status'],
                    'scheduled_start_date' => $c['scheduled_start_date'],
                    'scheduled_end_date' => $c['scheduled_end_date'],
                    'deadline' => $c['deadline'],
                ]);
            }
        }
    }
}
