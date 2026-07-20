<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Services\DashboardService;
use App\Services\OpportunityService;
use App\Traits\ApiResponse;

class DashboardController extends Controller
{
    use ApiResponse;

    protected DashboardService $dashboardService;
    protected OpportunityService $opportunityService;

    public function __construct(DashboardService $dashboardService, OpportunityService $opportunityService)
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
        if (!$user) {
            return $this->errorResponse('User tidak ditemukan.', 401);
        }

        $roleType = $request->query('role_type', $user->role ?? 'user');
        $overview = $this->dashboardService->getClientDashboardOverview($user->id, $roleType);

        return $this->successResponse('Ringkasan dashboard klien berhasil diambil', $overview);
    }
}
