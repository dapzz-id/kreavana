<?php

namespace App\Http\Controllers;

use App\Models\UserSession;
use Illuminate\Http\Request;
use Tymon\JWTAuth\Facades\JWTAuth;

class SessionController
{
    /**
     * List all active sessions across all devices and apps for current user.
     */
    public function listSessions(Request $request)
    {
        $payload = JWTAuth::parseToken()->getPayload();
        $currentSessionId = $payload->get('session_id');
        $userId = $payload->get('sub');

        $sessions = UserSession::where('user_id', $userId)
            ->where('is_revoked', false)
            ->where('expires_at', '>', now())
            ->orderByDesc('last_active_at')
            ->get()
            ->map(function ($s) use ($currentSessionId) {
                return [
                    'id' => $s->id,
                    'client_id' => $s->client_id,
                    'device_id' => $s->device_id,
                    'ip_address' => $s->ip_address,
                    'user_agent' => $s->user_agent,
                    'is_current' => $s->id === $currentSessionId,
                    'last_active_at' => $s->last_active_at,
                    'expires_at' => $s->expires_at,
                ];
            });

        return response()->json([
            'status' => true,
            'data' => $sessions,
        ]);
    }

    /**
     * Revoke a specific session.
     */
    public function revokeSession(Request $request, string $id)
    {
        $userId = JWTAuth::parseToken()->getPayload()->get('sub');

        $session = UserSession::where('id', $id)->where('user_id', $userId)->first();

        if (!$session) {
            return response()->json([
                'status' => false,
                'message' => 'Sesi tidak ditemukan.',
            ], 404);
        }

        $session->update(['is_revoked' => true]);

        return response()->json([
            'status' => true,
            'message' => 'Sesi perangkat berhasil dihentikan.',
        ]);
    }
}
