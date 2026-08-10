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
    public function complete(Request $request, $id)
    {
        $user = Auth::guard('api')->user();
        
        try {
            $opp = \Illuminate\Support\Facades\DB::transaction(function () use ($id, $user, $request) {
                $opp = \App\Models\Opportunity::where('id', $id)->lockForUpdate()->firstOrFail();

                if ($opp->status === 'closed') {
                    abort(409, 'Cannot refund or cancel a completed project.');
                }
                if ($opp->status === 'cancelled') {
                    abort(409, 'Project has been cancelled.');
                }

                // If user is the creator (seller of services, mapped to posted_by as per prompt instructions)
                if ($user->id === $opp->posted_by) {
                    if ($opp->creator_completed) {
                        abort(409, 'Creator has already confirmed completion.');
                    }
                    $opp->creator_completed = true;
                    $opp->creator_completed_at = now();
                    $opp->save();
                    return $opp;
                }

                // If user is the buyer (client)
                if ($user->id === $opp->buyer_id) {
                    if (!$opp->creator_completed) {
                        abort(409, 'Creator has not confirmed completion yet.');
                    }
                    
                    $request->validate(['pin' => 'required|string']);

                    if (!\Illuminate\Support\Facades\Hash::check($request->pin, $user->wallet_pin)) {
                        abort(400, 'PIN salah.');
                    }

                    $opp->buyer_completed = true;
                    $opp->status = 'closed';
                    $opp->save();

                    return $opp;
                }

                abort(403, 'Unauthorized. Hanya pihak terkait project yang dapat menyelesaikan.');
            });

            return $this->successResponse('Aksi penyelesaian berhasil.', $opp);
        } catch (\Exception $e) {
            $statusCode = $e instanceof \Symfony\Component\HttpKernel\Exception\HttpExceptionInterface ? $e->getStatusCode() : 500;
            return $this->errorResponse($e->getMessage(), $statusCode);
        }
    }
}
