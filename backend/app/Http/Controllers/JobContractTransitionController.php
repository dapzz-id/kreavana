<?php

namespace App\Http\Controllers;

use App\Models\JobContract;
use App\Services\JobContractTransitionService;
use App\Http\Requests\StoreJobContractTransitionRequest;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Exception;

class JobContractTransitionController extends Controller
{
    protected JobContractTransitionService $transitionService;

    public function __construct(JobContractTransitionService $transitionService)
    {
        $this->transitionService = $transitionService;
    }

    public function store(StoreJobContractTransitionRequest $request, string $id)
    {
        // We use lockForUpdate inside the transition service to safely lock the row
        // But we must fetch the contract first to ensure it exists and to pass it to the service
        $contract = JobContract::findOrFail($id);
        
        $actor = $request->user();
        
        try {
            $updatedContract = $this->transitionService->transition(
                $contract,
                $actor,
                $request->input('transition'),
                $request->input('metadata', [])
            );

            return response()->json([
                'status' => true,
                'message' => 'Transition successful',
                'data' => $updatedContract->load('statusHistories') // Include histories in response
            ]);
            
        } catch (Exception $e) {
            $code = $e->getCode();
            if ($code < 400 || $code >= 600) {
                $code = 400; // default client error for business logic exceptions
            }
            $message = $e->getMessage();
            $decoded = json_decode($message, true);
            
            if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
                return response()->json(array_merge(['status' => false], $decoded), $code);
            }

            return response()->json([
                'status' => false,
                'message' => $message
            ], $code);
        }
    }
}
