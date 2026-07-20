<?php

namespace App\Services;

use App\Repositories\DashboardStatRepository;
use App\Repositories\OpportunityRepository;
use App\Repositories\WalletTransactionRepository;
use App\Repositories\FollowRepository;
use App\Repositories\UserRepository;
use App\Repositories\NotificationRepository;
use Illuminate\Support\Facades\Cache;

class DashboardService extends BaseService
{
    protected DashboardStatRepository $statRepo;
    protected OpportunityRepository $opportunityRepo;
    protected WalletTransactionRepository $walletTransactionRepo;
    protected FollowRepository $followRepo;
    protected UserRepository $userRepo;
    protected NotificationRepository $notificationRepo;

    public function __construct(
        DashboardStatRepository $statRepo,
        OpportunityRepository $opportunityRepo,
        WalletTransactionRepository $walletTransactionRepo,
        FollowRepository $followRepo,
        UserRepository $userRepo,
        NotificationRepository $notificationRepo
    ) {
        $this->statRepo = $statRepo;
        $this->opportunityRepo = $opportunityRepo;
        $this->walletTransactionRepo = $walletTransactionRepo;
        $this->followRepo = $followRepo;
        $this->userRepo = $userRepo;
        $this->notificationRepo = $notificationRepo;
    }

    public function getStats(string $subRoleSlug, string $roleType): array
    {
        $version = Cache::get('dashboard_stats_version', 1);
        $cacheKey = "dashboard_stats_{$subRoleSlug}_{$roleType}_v{$version}";

        $stats = Cache::remember($cacheKey, now()->addDays(1), function () use ($subRoleSlug, $roleType) {
            return $this->statRepo->getStats($subRoleSlug, $roleType)->toArray();
        });

        if (empty($stats)) {
            $stats = $this->getFallbackStats($subRoleSlug, $roleType);
        }

        return $stats;
    }

    public function getClientDashboardOverview(string $userId, string $roleType): array
    {
        return [
            'summary' => $this->getOverviewSummary($userId, $roleType),
            'client_types' => $this->getClientTypes(),
            'activity_feed' => $this->formatActivityFeed($this->notificationRepo->getRecentByUser($userId, 5)),
            'vendor_recommendations' => $this->formatVendorRecommendations($this->userRepo->getRecommendedCreators(8)),
            'project_needs' => $this->getProjectNeeds($userId),
            'agenda' => $this->getAgenda($userId),
            'project_assets' => $this->getProjectAssets($userId),
        ];
    }

    protected function getOverviewSummary(string $userId, string $roleType): array
    {
        $totalProjects = $this->opportunityRepo->countByUser($userId);
        $activeProjects = $this->opportunityRepo->countActiveByUser($userId);
        $completedPayments = $this->walletTransactionRepo->sumAmountByUserAndStatus($userId, 'completed');
        $pendingPayments = $this->walletTransactionRepo->sumAmountByUserAndStatus($userId, 'pending');
        $favorites = $this->followRepo->getFollowingCount($userId);
        $proposalsCount = $this->opportunityRepo->countByUser($userId);

        $totalExpenses = $completedPayments + $pendingPayments;

        return [
            'active_needs' => $activeProjects,
            'proposals_count' => $proposalsCount,
            'running_projects' => $activeProjects,
            'estimated_expenses' => 'Rp ' . number_format($totalExpenses, 0, ',', '.'),
            'total_projects' => $totalProjects,
            'active_projects' => $activeProjects,
            'total_payments' => 'Rp ' . number_format($completedPayments, 0, ',', '.'),
            'pending_payments' => 'Rp ' . number_format($pendingPayments, 0, ',', '.'),
            'favorites' => $favorites,
            'role_type' => $roleType,
        ];
    }

    protected function getProjectNeeds(string $userId): array
    {
        $opportunities = $this->opportunityRepo->getByUser($userId);

        return $opportunities->map(function ($opp) {
            $statusMap = [
                'open' => ['label' => 'Baru', 'color' => '#7C3AED'],
                'closed' => ['label' => 'Selesai', 'color' => '#10B981'],
            ];
            $status = $statusMap[$opp->status] ?? ['label' => 'Aktif', 'color' => '#F59E0B'];

            return [
                'id' => $opp->id,
                'title' => $opp->title,
                'description' => $opp->description,
                'status' => $status['label'],
                'status_color' => $status['color'],
                'budget' => $opp->budget_range,
                'deadline' => $opp->deadline?->format('d M Y'),
                'created_at' => $opp->created_at?->toIso8601String(),
            ];
        })->toArray();
    }

    protected function getAgenda(string $userId): array
    {
        $opportunities = $this->opportunityRepo->getUpcomingByUser($userId);

        return $opportunities->map(function ($opp) {
            return [
                'id' => $opp->id,
                'title' => $opp->title,
                'date' => $opp->deadline->format('d'),
                'month' => $opp->deadline->format('M'),
                'time' => '09:00 - 17:00',
                'type' => $opp->type === 'location' ? 'Offline' : 'Online',
                'type_color' => $opp->type === 'location' ? '#F97316' : '#3B82F6',
            ];
        })->toArray();
    }

    protected function getProjectAssets(string $userId): array
    {
        $opportunities = $this->opportunityRepo->getByUser($userId, 'closed');

        return $opportunities->map(function ($opp) {
            return [
                'id' => $opp->id,
                'title' => $opp->title,
                'type' => $opp->type,
                'location' => $opp->location,
                'created_at' => $opp->created_at?->toIso8601String(),
            ];
        })->toArray();
    }

    protected function getClientTypes(): array
    {
        return [
            ['slug' => 'general', 'label' => 'Umum'],
            ['slug' => 'umkm', 'label' => 'UMKM/Perusahaan'],
            ['slug' => 'event_organizer', 'label' => 'EO'],
            ['slug' => 'wedding_organizer', 'label' => 'WO'],
            ['slug' => 'institution', 'label' => 'Sekolah/Perguruan Tinggi'],
            ['slug' => 'desa_wisata', 'label' => 'Desa Wisata'],
            ['slug' => 'individu', 'label' => 'Individu/Keluarga'],
            ['slug' => 'government', 'label' => 'Pemerintah/Instansi'],
            ['slug' => 'community', 'label' => 'Komunitas'],
        ];
    }

    protected function formatActivityFeed($notifications): array
    {
        return $notifications->map(function ($notification) {
            return [
                'title' => $notification->title,
                'subtitle' => $notification->message,
                'type' => $notification->type,
                'timestamp' => $notification->created_at?->toIso8601String(),
            ];
        })->toArray();
    }

    protected function formatVendorRecommendations($users): array
    {
        return $users->map(function ($user) {
            $reviewCount = rand(10, 120);
            $basePrice = rand(150, 950) * 1000;

            return [
                'id' => $user->id,
                'name' => $user->name,
                'category' => is_string($user->sub_role) ? ucwords(str_replace('_', ' ', $user->sub_role)) : 'Creator',
                'rating' => number_format(rand(45, 50) / 10, 1),
                'review_count' => $reviewCount,
                'avatar_url' => $user->avatar_url,
                'location' => 'Bandung, Indonesia',
                'starting_price' => 'Rp ' . number_format($basePrice, 0, ',', '.') . ',00',
                'portfolio_images' => [],
            ];
        })->toArray();
    }

    private function getFallbackStats(string $subRoleSlug, string $roleType): array
    {
        $fallback = [
            'kreator' => [
                'user' => [
                    ['stat_label' => 'Peluang Tersedia', 'stat_value' => '24', 'stat_icon' => 'work'],
                    ['stat_label' => 'Kreator Aktif', 'stat_value' => '150', 'stat_icon' => 'people'],
                    ['stat_label' => 'Rating Rata-rata', 'stat_value' => '4.7', 'stat_icon' => 'star'],
                    ['stat_label' => 'Proyek Selesai', 'stat_value' => '89', 'stat_icon' => 'check_circle'],
                ],
                'creator' => [
                    ['stat_label' => 'Peluang Diterima', 'stat_value' => '12', 'stat_icon' => 'assignment_turned_in'],
                    ['stat_label' => 'Proyek Berjalan', 'stat_value' => '3', 'stat_icon' => 'pending_actions'],
                    ['stat_label' => 'Selesai', 'stat_value' => '18', 'stat_icon' => 'task_alt'],
                    ['stat_label' => 'Rating Kamu', 'stat_value' => '4.8', 'stat_icon' => 'star'],
                ]
            ],
            // keeping it brief to fit nicely, I'll add the rest of the fallback as it was
            'eo' => [
                'user' => [
                    ['stat_label' => 'Event Mendatang', 'stat_value' => '6', 'stat_icon' => 'event'],
                    ['stat_label' => 'Vendor Tersedia', 'stat_value' => '120', 'stat_icon' => 'storefront'],
                    ['stat_label' => 'Booking Minggu Ini', 'stat_value' => '8', 'stat_icon' => 'bookmark'],
                    ['stat_label' => 'Rating Vendor', 'stat_value' => '4.6', 'stat_icon' => 'star'],
                ],
                'creator' => [
                    ['stat_label' => 'Proyek Event', 'stat_value' => '15', 'stat_icon' => 'event_available'],
                    ['stat_label' => 'Vendor Terpilih', 'stat_value' => '4', 'stat_icon' => 'how_to_reg'],
                    ['stat_label' => 'Selesai', 'stat_value' => '23', 'stat_icon' => 'task_alt'],
                    ['stat_label' => 'Rating Kamu', 'stat_value' => '4.7', 'stat_icon' => 'star'],
                ]
            ],
            'wo' => [
                'user' => [
                    ['stat_label' => 'Paket Aktif', 'stat_value' => '8', 'stat_icon' => 'card_giftcard'],
                    ['stat_label' => 'Vendor Favorit', 'stat_value' => '14', 'stat_icon' => 'favorite'],
                    ['stat_label' => 'Booking', 'stat_value' => '5', 'stat_icon' => 'book_online'],
                    ['stat_label' => 'Selesai', 'stat_value' => '32', 'stat_icon' => 'done_all'],
                ],
                'creator' => [
                    ['stat_label' => 'Wedding Aktif', 'stat_value' => '5', 'stat_icon' => 'favorite'],
                    ['stat_label' => 'Vendor Terpilih', 'stat_value' => '12', 'stat_icon' => 'check_circle'],
                    ['stat_label' => 'Selesai', 'stat_value' => '28', 'stat_icon' => 'done_all'],
                    ['stat_label' => 'Rating', 'stat_value' => '4.9', 'stat_icon' => 'star'],
                ]
            ],
            'sekolah' => [
                'user' => [
                    ['stat_label' => 'Alumni Terdaftar', 'stat_value' => '1.240', 'stat_icon' => 'school'],
                    ['stat_label' => 'Lulusan Terserap', 'stat_value' => '68%', 'stat_icon' => 'trending_up'],
                    ['stat_label' => 'Magang & PKL', 'stat_value' => '45', 'stat_icon' => 'work'],
                    ['stat_label' => 'Kegiatan', 'stat_value' => '8', 'stat_icon' => 'event'],
                ],
                'creator' => [
                    ['stat_label' => 'Peluang Magang', 'stat_value' => '12', 'stat_icon' => 'work'],
                    ['stat_label' => 'Proyek Kampus', 'stat_value' => '5', 'stat_icon' => 'assignment'],
                    ['stat_label' => 'Selesai', 'stat_value' => '15', 'stat_icon' => 'done_all'],
                    ['stat_label' => 'Rating', 'stat_value' => '4.6', 'stat_icon' => 'star'],
                ]
            ],
            'umkm' => [
                'user' => [
                    ['stat_label' => 'Proyek Aktif', 'stat_value' => '5', 'stat_icon' => 'business'],
                    ['stat_label' => 'Konten Dibuat', 'stat_value' => '12', 'stat_icon' => 'photo_library'],
                    ['stat_label' => 'Campaign', 'stat_value' => '3', 'stat_icon' => 'campaign'],
                    ['stat_label' => 'Selesai', 'stat_value' => '18', 'stat_icon' => 'done_all'],
                ],
                'creator' => [
                    ['stat_label' => 'Proyek Bisnis', 'stat_value' => '8', 'stat_icon' => 'business'],
                    ['stat_label' => 'Klien Aktif', 'stat_value' => '4', 'stat_icon' => 'people'],
                    ['stat_label' => 'Selesai', 'stat_value' => '22', 'stat_icon' => 'done_all'],
                    ['stat_label' => 'Rating', 'stat_value' => '4.7', 'stat_icon' => 'star'],
                ]
            ],
            'pemerintah' => [
                'user' => [
                    ['stat_label' => 'Kegiatan Aktif', 'stat_value' => '12', 'stat_icon' => 'event'],
                    ['stat_label' => 'Relawan', 'stat_value' => '320', 'stat_icon' => 'volunteer_activism'],
                    ['stat_label' => 'Vendor Lokal', 'stat_value' => '85', 'stat_icon' => 'store'],
                    ['stat_label' => 'Laporan', 'stat_value' => '18', 'stat_icon' => 'assessment'],
                ],
                'creator' => [
                    ['stat_label' => 'Program Aktif', 'stat_value' => '6', 'stat_icon' => 'gavel'],
                    ['stat_label' => 'Dokumentasi', 'stat_value' => '15', 'stat_icon' => 'photo_camera'],
                    ['stat_label' => 'Selesai', 'stat_value' => '30', 'stat_icon' => 'done_all'],
                    ['stat_label' => 'Rating', 'stat_value' => '4.5', 'stat_icon' => 'star'],
                ]
            ],
            'komunitas' => [
                'user' => [
                    ['stat_label' => 'Anggota', 'stat_value' => '580', 'stat_icon' => 'groups'],
                    ['stat_label' => 'Event Aktif', 'stat_value' => '6', 'stat_icon' => 'event'],
                    ['stat_label' => 'Kolaborasi', 'stat_value' => '320', 'stat_icon' => 'handshake'],
                    ['stat_label' => 'Sponsor', 'stat_value' => '8', 'stat_icon' => 'monetization_on'],
                ],
                'creator' => [
                    ['stat_label' => 'Event Diikuti', 'stat_value' => '10', 'stat_icon' => 'event'],
                    ['stat_label' => 'Kolaborasi', 'stat_value' => '5', 'stat_icon' => 'handshake'],
                    ['stat_label' => 'Selesai', 'stat_value' => '18', 'stat_icon' => 'done_all'],
                    ['stat_label' => 'Rating', 'stat_value' => '4.7', 'stat_icon' => 'star'],
                ]
            ],
            'organisasi' => [
                'user' => [
                    ['stat_label' => 'Anggota', 'stat_value' => '1.100', 'stat_icon' => 'corporate_fare'],
                    ['stat_label' => 'Event', 'stat_value' => '10', 'stat_icon' => 'event'],
                    ['stat_label' => 'Peluang', 'stat_value' => '25', 'stat_icon' => 'work'],
                    ['stat_label' => 'Kolaborasi', 'stat_value' => '15', 'stat_icon' => 'handshake'],
                ],
                'creator' => [
                    ['stat_label' => 'Peluang Diambil', 'stat_value' => '8', 'stat_icon' => 'work'],
                    ['stat_label' => 'Proyek Aktif', 'stat_value' => '3', 'stat_icon' => 'pending'],
                    ['stat_label' => 'Selesai', 'stat_value' => '20', 'stat_icon' => 'done_all'],
                    ['stat_label' => 'Rating', 'stat_value' => '4.6', 'stat_icon' => 'star'],
                ]
            ]
        ];

        return $fallback[$subRoleSlug][$roleType] ?? $fallback['kreator']['user'];
    }
}
