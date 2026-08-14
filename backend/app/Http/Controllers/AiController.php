<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Contracts\AiServiceInterface;
use App\Traits\ApiResponse;
use Exception;

class AiController extends Controller
{
    use ApiResponse;

    protected AiServiceInterface $aiService;

    public function __construct(AiServiceInterface $aiService)
    {
        $this->aiService = $aiService;
    }

    /**
     * Internal entitlement check: AI Features require Pro or Super subscription tier.
     */
    private function checkSubscriptionTier(Request $request): ?\Illuminate\Http\JsonResponse
    {
        $user = $request->user();
        $tier = strtolower($user->subscription_tier ?? 'basic');

        if (!in_array($tier, ['pro', 'super'])) {
            return response()->json([
                'status' => false,
                'message' => 'Fitur AI Service hanya tersedia untuk pengguna Paket Pro dan Super.',
                'error_code' => 'pro_subscription_required',
                'current_tier' => $tier,
            ], 403);
        }

        return null;
    }

    /**
     * POST /api/ai/summarize-report
     */
    public function summarizeReport(Request $request)
    {
        if ($denyResponse = $this->checkSubscriptionTier($request)) {
            return $denyResponse;
        }

        $payload = $request->validate([
            'title' => 'nullable|string|max:255',
            'content' => 'nullable|string',
            'description' => 'nullable|string',
            'context' => 'nullable|string',
        ]);

        try {
            $result = $this->aiService->summarizeReport($payload);
            return $this->successResponse('Ringkasan AI berhasil dibuat.', $result);
        } catch (Exception $e) {
            return $this->errorResponse('Gagal memproses ringkasan AI: ' . $e->getMessage(), 500);
        }
    }

    /**
     * POST /api/ai/recommendations
     */
    public function getRecommendations(Request $request)
    {
        if ($denyResponse = $this->checkSubscriptionTier($request)) {
            return $denyResponse;
        }

        $payload = $request->validate([
            'role' => 'nullable|string',
            'niche' => 'nullable|string',
            'budget' => 'nullable|string',
        ]);

        try {
            $result = $this->aiService->getRecommendations($payload);
            return $this->successResponse('Rekomendasi AI berhasil dibuat.', $result);
        } catch (Exception $e) {
            return $this->errorResponse('Gagal memproses rekomendasi AI: ' . $e->getMessage(), 500);
        }
    }

    /**
     * POST /api/ai/message-assistant
     */
    public function messageAssistant(Request $request)
    {
        if ($denyResponse = $this->checkSubscriptionTier($request)) {
            return $denyResponse;
        }

        $payload = $request->validate([
            'mode' => 'nullable|string|in:smart_reply,polish,summarize',
            'message' => 'nullable|string',
        ]);

        try {
            $result = $this->aiService->messageAssistant($payload);
            return $this->successResponse('AI Assistant berhasil merespons.', $result);
        } catch (Exception $e) {
            return $this->errorResponse('Gagal memproses AI Message Assistant: ' . $e->getMessage(), 500);
        }
    }
}
