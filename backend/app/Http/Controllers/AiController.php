<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Contracts\AiServiceInterface;
use App\Models\AiChatSession;
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
     * Internal entitlement check: AI Recommendations require Plus, Pro, or Super subscription tier.
     */
    private function checkSubscriptionTier(Request $request): ?\Illuminate\Http\JsonResponse
    {
        $user = $request->user('api') ?? $request->user();

        if (!$user) {
            return response()->json([
                'status' => false,
                'message' => 'Fitur Kreavana AI Assistant tersedia untuk pengguna Paket Plus, Pro, dan Super. Silakan login dan tingkatkan paket Anda.',
                'error_code' => 'pro_subscription_required',
                'current_tier' => 'guest',
            ], 403);
        }

        $tier = strtolower($user->subscription_tier ?? 'basic');

        if (!in_array($tier, ['plus', 'pro', 'super'])) {
            return response()->json([
                'status' => false,
                'message' => 'Fitur Kreavana AI Assistant tersedia untuk pengguna Paket Plus, Pro, dan Super. Silakan tingkatkan paket Anda.',
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
            'sub_role' => 'nullable|string',
            'location' => 'nullable|string',
            'lat' => 'nullable|numeric',
            'lng' => 'nullable|numeric',
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
            'mode' => 'nullable|string|in:smart_reply,polish,summarize,chat,ask',
            'message' => 'nullable|string',
            'category' => 'nullable|string',
            'include_data_kreavana' => 'nullable|boolean',
            'context' => 'nullable|string',
        ]);

        try {
            $result = $this->aiService->messageAssistant($payload);
            return $this->successResponse('AI Assistant berhasil merespons.', $result);
        } catch (Exception $e) {
            return $this->errorResponse('Gagal memproses AI Message Assistant: ' . $e->getMessage(), 500);
        }
    }

    /**
     * GET /api/ai/chat-sessions
     * Retrieve all saved chat sessions for the authenticated user.
     */
    public function getChatSessions(Request $request)
    {
        $user = $request->user('api') ?? $request->user();
        if (!$user) {
            return $this->errorResponse('Silakan login untuk melihat riwayat obrolan AI.', 401);
        }

        $sessions = AiChatSession::where('user_id', $user->id)
            ->orderBy('updated_at', 'desc')
            ->get()
            ->map(function ($s) {
                return [
                    'id' => $s->session_id,
                    'title' => $s->title,
                    'created_at' => $s->created_at?->toIso8601String(),
                    'updated_at' => $s->updated_at?->toIso8601String(),
                    'messages' => is_array($s->messages) ? $s->messages : json_decode($s->messages, true) ?? [],
                ];
            });

        return $this->successResponse('Riwayat obrolan berhasil dimuat.', $sessions);
    }

    /**
     * POST /api/ai/chat-sessions
     * Create or update a saved chat session for the authenticated user.
     */
    public function syncChatSession(Request $request)
    {
        $user = $request->user('api') ?? $request->user();
        if (!$user) {
            return $this->errorResponse('Silakan login untuk menyimpan riwayat obrolan AI.', 401);
        }

        $payload = $request->validate([
            'session_id' => 'required|string|max:100',
            'title' => 'required|string|max:255',
            'messages' => 'required|array',
        ]);

        $session = AiChatSession::updateOrCreate(
            [
                'user_id' => $user->id,
                'session_id' => $payload['session_id'],
            ],
            [
                'title' => $payload['title'],
                'messages' => $payload['messages'],
            ]
        );

        return $this->successResponse('Riwayat sesi obrolan berhasil disimpan.', [
            'id' => $session->session_id,
            'title' => $session->title,
            'created_at' => $session->created_at?->toIso8601String(),
            'updated_at' => $session->updated_at?->toIso8601String(),
            'messages' => $session->messages,
        ]);
    }

    /**
     * DELETE /api/ai/chat-sessions/{sessionId}
     * Delete a specific chat session for the authenticated user.
     */
    public function deleteChatSession(Request $request, string $sessionId)
    {
        $user = $request->user('api') ?? $request->user();
        if (!$user) {
            return $this->errorResponse('Silakan login untuk menghapus sesi obrolan.', 401);
        }

        AiChatSession::where('user_id', $user->id)
            ->where('session_id', $sessionId)
            ->delete();

        return $this->successResponse('Sesi obrolan berhasil dihapus.');
    }

    /**
     * DELETE /api/ai/chat-sessions
     * Clear all chat sessions for the authenticated user.
     */
    public function clearChatSessions(Request $request)
    {
        $user = $request->user('api') ?? $request->user();
        if (!$user) {
            return $this->errorResponse('Silakan login untuk menghapus riwayat obrolan.', 401);
        }

        AiChatSession::where('user_id', $user->id)->delete();

        return $this->successResponse('Semua riwayat obrolan berhasil dihapus.');
    }
}
