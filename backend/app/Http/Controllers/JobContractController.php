<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreJobContractRequest;
use App\Services\JobContractService;
use App\Models\JobContract;
use App\Models\JobStatusHistory;
use App\Enums\WorkStatus;
use Illuminate\Http\Request;
use Exception;

class JobContractController extends Controller
{
    use \App\Traits\ApiResponse;

    protected JobContractService $contractService;

    public function __construct(JobContractService $contractService)
    {
        $this->contractService = $contractService;
    }

    public function index(Request $request)
    {
        $user = $request->user();
        $limit = $request->input('limit', 50);
        
        $contracts = $this->contractService->getUserContracts($user, $limit);
        
        return $this->successResponse('Daftar kontrak berhasil diambil', $contracts->toArray());
    }

    public function show(Request $request, string $id)
    {
        try {
            $user = $request->user();
            $contract = $this->contractService->getContractForUser($id, $user);
            
            // Load relationships for API response
            $contract->load(['client:id,name,username,avatar_url', 'creator:id,name,username,avatar_url', 'opportunity']);
            
            return $this->successResponse('Detail kontrak berhasil diambil', $contract->toArray());
        } catch (Exception $e) {
            return $this->errorResponse($e->getMessage(), $e->getCode() ?: 400);
        }
    }

    public function store(StoreJobContractRequest $request)
    {
        try {
            $user = $request->user();
            $contract = $this->contractService->createContract($user, $request->validated());
            
            return $this->successResponse('Kontrak berhasil dibuat', $contract->toArray(), 201);
        } catch (Exception $e) {
            return $this->errorResponse($e->getMessage(), $e->getCode() ?: 400);
        }
    }

    public function confirmSchedule(Request $request, string $id)
    {
        try {
            $user = $request->user();
            $contract = JobContract::findOrFail($id);

            if ($contract->client_id !== $user->id && $contract->creator_id !== $user->id) {
                return $this->errorResponse('Anda tidak memiliki akses ke kontrak ini.', 403);
            }

            $fromWorkStatus = $contract->work_status?->value ?? (string) $contract->work_status;

            $contract->work_status = WorkStatus::InProgress;
            $contract->started_at = now();
            if (!$contract->scheduled_at) {
                $contract->scheduled_at = now();
            }
            $contract->save();

            JobStatusHistory::create([
                'job_contract_id' => $contract->id,
                'actor_id' => $user->id,
                'transition' => 'confirm_schedule',
                'from_work_status' => $fromWorkStatus,
                'to_work_status' => WorkStatus::InProgress->value,
                'from_contract_status' => $contract->contract_status?->value ?? (string) $contract->contract_status,
                'to_contract_status' => $contract->contract_status?->value ?? (string) $contract->contract_status,
                'metadata' => ['action' => 'confirm_schedule'],
                'created_at' => now(),
            ]);

            return $this->successResponse('Jadwal berhasil dikonfirmasi', $contract->toArray());
        } catch (Exception $e) {
            return $this->errorResponse($e->getMessage(), 400);
        }
    }
}

