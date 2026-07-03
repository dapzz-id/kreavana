<?php

namespace App\Http\Controllers\Auth;

use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Str;
use App\Models\UserSession;

trait AuthResponder
{
    /**
     * Generate token response dengan session management.
     *
     * @param  string  $token  JWT access token
     * @param  string|null  $sessionToken  Existing session token (untuk refresh)
     * @param  string|null  $refreshToken  Existing refresh token (untuk refresh)
     * @return \Illuminate\Http\JsonResponse
     */
    protected function respondWithToken($token, $sessionToken = null, $refreshToken = null)
    {
        $user = Auth::guard('api')->user();
        $user->id = (int)$user->id;
        $user->is_creator_approved = (int)$user->is_creator_approved;

        if (!$sessionToken || !$refreshToken) {
            $sessionToken = Str::random(60);
            $refreshToken = Str::random(60);

            // Create new session
            UserSession::create([
                'user_id' => $user->id,
                'session_token' => $sessionToken,
                'refresh_token' => $refreshToken,
                'expires_at' => now()->addDays(7),
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Login berhasil.',
            'data' => [
                'token' => $token, // Backward compatibility with old api
                'access_token' => $token,
                'refresh_token' => $refreshToken,
                'session_token' => $sessionToken,
                'token_type' => 'bearer',
                'expires_in' => Auth::guard('api')->factory()->getTTL() * 60,
                'user' => $user
            ]
        ]);
    }

    /**
     * Handle token refresh dengan session rotation.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\JsonResponse
     */
    protected function handleRefresh($request)
    {
        $sessionToken = $request->input('session_token');
        $refreshToken = $request->input('refresh_token');

        if (!$sessionToken || !$refreshToken) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi tidak valid.'
            ], 401);
        }

        $session = UserSession::where('session_token', $sessionToken)
            ->where('refresh_token', $refreshToken)
            ->first();

        if (!$session || $session->expires_at < now()) {
            if ($session) $session->delete();
            return response()->json([
                'success' => false,
                'message' => 'Sesi telah habis, silakan login kembali.'
            ], 401);
        }

        $user = $session->user;
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'User tidak ditemukan.'
            ], 401);
        }

        // Generate new JWT access token (claims will be refreshed from current DB state)
        $token = Auth::guard('api')->login($user);

        // Rotate refresh token
        $newRefreshToken = Str::random(60);
        $session->update([
            'refresh_token' => $newRefreshToken
        ]);

        return $this->respondWithToken($token, $session->session_token, $newRefreshToken);
    }

    /**
     * Handle logout dengan session cleanup.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\JsonResponse
     */
    protected function handleLogout($request)
    {
        $sessionToken = $request->input('session_token');
        if ($sessionToken) {
            UserSession::where('session_token', $sessionToken)->delete();
        }

        Auth::guard('api')->logout();

        return response()->json(['success' => true, 'message' => 'Successfully logged out']);
    }
}
