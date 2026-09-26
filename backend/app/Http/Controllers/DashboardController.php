<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Contracts\DashboardServiceInterface;
use App\Services\OpportunityService;
use App\Traits\ApiResponse;

class DashboardController extends Controller
{
    use ApiResponse;

    protected DashboardServiceInterface $dashboardService;
    protected OpportunityService $opportunityService;

    public function __construct(DashboardServiceInterface $dashboardService, OpportunityService $opportunityService)
    {
        $this->dashboardService = $dashboardService;
        $this->opportunityService = $opportunityService;
    }

    public function stats(Request $request)
    {
        $subRoleSlug = $request->query('sub_role_slug');
        $roleType = $request->query('role_type');

        if (!$subRoleSlug || !$roleType) {
            return $this->errorResponse('Parameter sub_role_slug dan role_type wajib diisi.', 400);
        }

        $stats = $this->dashboardService->getStats($subRoleSlug, $roleType);

        return $this->successResponse('Statistik berhasil diambil', $stats);
    }

    public function opportunities(Request $request)
    {
        $subRoleSlug = $request->query('sub_role_slug', 'all');
        $type = $request->query('type');
        $limit = (int) $request->query('limit', 50);

        // Uses the same service to fetch the lightweight list without eager loading full users
        $opportunities = $this->opportunityService->getList($subRoleSlug, $type, $limit);

        return $this->successResponse('Peluang berhasil diambil', $opportunities->toArray());
    }

    public function overview(Request $request)
    {
        $user = auth('api')->user();
        $userId = $user ? $user->id : 'guest';
        $roleType = $user ? ($request->query('role_type', $user->role->value ?? 'user')) : 'guest';

        $overview = $this->dashboardService->getClientDashboardOverview($userId, $roleType);

        return $this->successResponse('Ringkasan dashboard klien berhasil diambil', $overview);
    }

    public function collaborations(Request $request)
    {
        $users = \App\Models\User::whereIn('email', [
            'dimas.arya@kreavana.id',
            'sarah.putri@kreavana.id',
            'kevin.jonathan@kreavana.id',
            'aditya.pratama@kreavana.id',
            'nabila.zahra@kreavana.id',
        ])->get()->keyBy('email');

        $collabs = [
            [
                'id' => 'collab-1',
                'user_id' => $users['dimas.arya@kreavana.id']->id ?? null,
                'name' => 'Dimas Arya',
                'email' => 'dimas.arya@kreavana.id',
                'username' => 'dimas_arya',
                'role' => 'Director & Produser',
                'avatar' => 'videocam',
                'project' => 'Produksi Video Iklan Pariwisata Wonderful Indonesia 2026',
                'desc' => 'Membutuhkan drone pilot bersertifikat FPV dan colorist DaVinci untuk shooting di Labuan Bajo & Bali selama 4 hari penuh.',
                'neededRoles' => ['Drone Pilot FPV', 'Colorist DaVinci', 'Audio Recordist'],
                'budget' => 'Rp 18.500.000',
                'compensationType' => 'Bagi Hasil & Fee Tetap',
                'status' => 'Aktif',
                'membersCount' => 4,
                'maxMembers' => 6,
                'date' => '25 Sep - 10 Okt 2026',
                'location' => 'Bali & Labuan Bajo',
                'tags' => ['Cinematic', 'Travel', 'Commercial'],
            ],
            [
                'id' => 'collab-2',
                'user_id' => $users['sarah.putri@kreavana.id']->id ?? null,
                'name' => 'Sarah Putri',
                'email' => 'sarah.putri@kreavana.id',
                'username' => 'sarah_putri',
                'role' => 'Brand Strategist',
                'avatar' => 'palette',
                'project' => 'Rebranding & Desain Kemasan UMKM Kopi Kintamani',
                'desc' => 'Mencari packaging illustrator dan 3D visualizer mockup produk untuk persiapan ekspor pasar Jepang & Australia.',
                'neededRoles' => ['Packaging Designer', '3D Artist', 'Copywriter'],
                'budget' => 'Rp 8.500.000',
                'compensationType' => 'Escrow Kreavana',
                'status' => 'Menunggu',
                'membersCount' => 2,
                'maxMembers' => 3,
                'date' => '30 Sep 2026',
                'location' => 'Remote / Bali',
                'tags' => ['Branding', 'Packaging', 'Export'],
            ],
            [
                'id' => 'collab-3',
                'user_id' => $users['kevin.jonathan@kreavana.id']->id ?? null,
                'name' => 'Kevin Jonathan',
                'email' => 'kevin.jonathan@kreavana.id',
                'username' => 'kevin_jonathan',
                'role' => 'Fashion Photographer',
                'avatar' => 'camera',
                'project' => 'Photoshoot Editorial Fashion Raya Collection 2026',
                'desc' => 'Kolaborasi photoshoot lookbook busana muslim modern bersama brand lokal terkemuka di studio profesional.',
                'neededRoles' => ['MUA Editorial', 'Fashion Stylist', 'Lighting Assistant'],
                'budget' => 'Rp 14.000.000',
                'compensationType' => 'Kontrak Terproteksi',
                'status' => 'Aktif',
                'membersCount' => 5,
                'maxMembers' => 5,
                'date' => '05 Okt 2026',
                'location' => 'Studio Kreavana Jakarta',
                'tags' => ['Fashion', 'Editorial', 'Lookbook'],
            ],
            [
                'id' => 'collab-4',
                'user_id' => $users['aditya.pratama@kreavana.id']->id ?? null,
                'name' => 'Aditya Pratama',
                'email' => 'aditya.pratama@kreavana.id',
                'username' => 'aditya_pratama',
                'role' => 'Sound Designer & Composer',
                'avatar' => 'music',
                'project' => 'Original Score & Sound Design Film Pendek "Suara Pesisir"',
                'desc' => 'Proyek film pendek festival internasional. Membutuhkan pengisi instrumen tradisional dan mixing surround 5.1.',
                'neededRoles' => ['Mixing Engineer', 'Foley Artist'],
                'budget' => 'Rp 7.500.000',
                'compensationType' => 'Royalti & Fee',
                'status' => 'Menunggu',
                'membersCount' => 2,
                'maxMembers' => 4,
                'date' => '15 Okt 2026',
                'location' => 'Remote / Yogyakarta',
                'tags' => ['FilmScore', 'Festival', 'Audio'],
            ],
            [
                'id' => 'collab-5',
                'user_id' => $users['nabila.zahra@kreavana.id']->id ?? null,
                'name' => 'Nabila Zahra',
                'email' => 'nabila.zahra@kreavana.id',
                'username' => 'nabila_zahra',
                'role' => 'Social Media Specialist',
                'avatar' => 'campaign',
                'project' => 'Campaign Konten Tiktok & Reels Kuliner Nusantara',
                'desc' => 'Produksi 30 video konten pendek review kuliner khas nusantara untuk sponsor e-commerce terkemuka.',
                'neededRoles' => ['Content Creator', 'Video Editor CapCut'],
                'budget' => 'Rp 12.000.000',
                'compensationType' => 'Selesai Dibayarkan',
                'status' => 'Selesai',
                'membersCount' => 4,
                'maxMembers' => 4,
                'date' => 'Selesai 10 Sep 2026',
                'location' => 'Jakarta & Bandung',
                'tags' => ['TikTok', 'Culinary', 'ViralContent'],
            ],
        ];

        return $this->successResponse('Kolaborasi berhasil diambil', $collabs);
    }
}
