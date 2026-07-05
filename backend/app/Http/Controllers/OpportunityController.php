<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use App\Services\OpportunityService;
use App\Http\Requests\StoreOpportunityRequest;
use App\Http\Requests\SubmitReportRequest;
use App\Traits\ApiResponse;
use App\Models\User;

class OpportunityController extends Controller
{
    use ApiResponse;

    protected OpportunityService $opportunityService;

    public function __construct(OpportunityService $opportunityService)
    {
        $this->opportunityService = $opportunityService;
    }

    public function index(Request $request)
    {
        $subRoleSlug = $request->query('sub_role_slug', 'all');
        $type = $request->query('type');
        $limit = (int) $request->query('limit', 50);

        $opportunities = $this->opportunityService->getList($subRoleSlug, $type, $limit);

        return $this->successResponse('Data peluang berhasil diambil', $opportunities->toArray());
    }

    public function mapLocations(Request $request)
    {
        $subRoleSlug = $request->query('sub_role_slug', 'all');

        $locations = $this->opportunityService->getMapLocations($subRoleSlug);

        return $this->successResponse('Data lokasi peluang berhasil diambil', $locations->toArray());
    }

    public function show($id)
    {
        $opp = $this->opportunityService->findById($id);

        if (!$opp) {
            return $this->errorResponse('Peluang tidak ditemukan.', 404);
        }

        return $this->successResponse('Detail peluang berhasil diambil', $opp);
    }

    public function store(StoreOpportunityRequest $request)
    {
        $user = Auth::guard('api')->user();
        
        $opp = $this->opportunityService->createOpportunity($user->id, $request->validated());

        return $this->successResponse('Peluang berhasil dibuat.', $opp, 201);
    }

    public function submitReport(SubmitReportRequest $request)
    {
        $user = Auth::guard('api')->user();

        $this->opportunityService->submitReport($user->id, $request->validated());

        return $this->successResponse('Laporan berhasil dikirim. Tim kami akan meninjau segera.');
    }

    // New Endpoint to fetch poster information to avoid heavy payload in main list
    public function getPoster($id)
    {
        // Get the opportunity's posted_by
        $opp = \App\Models\Opportunity::select('posted_by')->find($id);
        
        if (!$opp) {
            return $this->errorResponse('Peluang tidak ditemukan.', 404);
        }

        $user = User::select('id', 'name', 'username', 'avatar_url', 'selected_sub_role')->find($opp->posted_by);
        
        if (!$user) {
            return $this->errorResponse('Pembuat peluang tidak ditemukan.', 404);
        }

        return $this->successResponse('Data pembuat peluang berhasil diambil', $user->toArray());
    }
}
