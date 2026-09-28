<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Services\AdminService;
use App\Http\Requests\RejectApplicationRequest;
use App\Traits\ApiResponse;
use Exception;

class AdminController extends Controller
{
    use ApiResponse;

    protected AdminService $adminService;

    public function __construct(AdminService $adminService)
    {
        $this->adminService = $adminService;
    }

    public function getApplications(Request $request)
    {
        $status = $request->query('status');
        $applications = $this->adminService->getApplications($status);

        return $this->successResponse('Data pengajuan berhasil diambil', $applications->toArray());
    }

    public function approveApplication($id)
    {
        try {
            $this->adminService->approveApplication($id);
            return $this->successResponse('Pengajuan berhasil disetujui.', [
                'id' => $id,
                'status' => 'approved',
            ]);
        } catch (Exception $e) {
            return $this->errorResponse($e->getMessage(), $e->getCode() ?: 500);
        }
    }

    public function rejectApplication(RejectApplicationRequest $request, $id)
    {
        try {
            $this->adminService->rejectApplication($id, $request->admin_note);
            return $this->successResponse('Pengajuan berhasil ditolak.', [
                'id' => $id,
                'status' => 'rejected',
            ]);
        } catch (Exception $e) {
            return $this->errorResponse($e->getMessage(), $e->getCode() ?: 500);
        }
    }

    public function getSystemLogs()
    {
        $logs = \App\Models\SystemLog::orderBy('created_at', 'desc')->take(10)->get();
        return $this->successResponse('System logs berhasil diambil', $logs->toArray());
    }

    public function getDashboardSummary()
    {
        try {
            $totalUsers = \App\Models\User::count();
            $totalCreators = \App\Models\User::where('role', 'creator')
                ->where('is_creator_approved', true)
                ->count();
            $completedProjects = \App\Models\JobContract::whereIn('contract_status', ['completed'])
                ->count();
            $pendingApplications = \App\Models\CreatorApplication::where('status', 'pending')
                ->count();
            $activeOpportunities = \App\Models\Opportunity::where('status', 'open')
                ->count();
            $totalDisputes = \App\Models\DisputeCase::where('status', '!=', 'resolved')
                ->count();
            $walletVolume = (float) \App\Models\WalletTransaction::whereIn('type', ['topup', 'transfer', 'payment'])
                ->whereIn('status', ['completed', 'success'])
                ->sum('amount');
            $newUsersThisWeek = \App\Models\User::where('created_at', '>=', now()->subDays(7))
                ->count();

            return $this->successResponse('Dashboard summary berhasil diambil', [
                'total_users'              => $totalUsers,
                'active_creators'          => $totalCreators,
                'completed_projects'       => $completedProjects,
                'pending_applications'     => $pendingApplications,
                'active_opportunities'     => $activeOpportunities,
                'open_disputes'            => $totalDisputes,
                'wallet_volume_idr'        => $walletVolume,
                'new_users_this_week'      => $newUsersThisWeek,
            ]);
        } catch (Exception $e) {
            return $this->errorResponse($e->getMessage(), 500);
        }
    }
}
