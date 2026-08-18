<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreJobContractRequest;
use App\Services\JobContractService;
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
}
