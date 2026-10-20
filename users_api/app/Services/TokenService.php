<?php

namespace App\Services;

use App\Models\User;
use App\Models\UserSession;
use Illuminate\Support\Str;
use Tymon\JWTAuth\Facades\JWTAuth;

class TokenService
{
    /**
     * Create a new session with Access Token and Refresh Token for a client app.
     */
    public function createTokensForUser(User $user, string $clientId, ?string $deviceId = null, ?string $ip = null, ?string $userAgent = null): array
    {
        $refreshTokenId = Str::random(64);
        $expiresAt = now()->addDays(30);

        // Record or update user session
        $session = UserSession::create([
            'user_id' => $user->id,
            'client_id' => $clientId,
            'refresh_token_id' => hash('sha256', $refreshTokenId),
            'ip_address' => $ip,
            'user_agent' => $userAgent,
            'device_id' => $deviceId,
            'last_active_at' => now(),
            'expires_at' => $expiresAt,
            'is_revoked' => false,
        ]);

        // Generate Access Token with custom claims
        $customClaims = [
            'client_id' => $clientId,
            'session_id' => $session->id,
            'device_id' => $deviceId,
        ];

        $accessToken = JWTAuth::claims($customClaims)->fromUser($user);

        return [
            'access_token' => $accessToken,
            'refresh_token' => $refreshTokenId,
            'token_type' => 'Bearer',
            'expires_in' => config('jwt.ttl', 60) * 60, // in seconds
            'session_id' => $session->id,
        ];
    }

    /**
     * Refresh tokens using a valid refresh token.
     */
    public function refreshSession(string $refreshToken, string $clientId, ?string $ip = null): ?array
    {
        $hash = hash('sha256', $refreshToken);

        $session = UserSession::where('refresh_token_id', $hash)
            ->where('client_id', $clientId)
            ->where('is_revoked', false)
            ->where('expires_at', '>', now())
            ->first();

        if (!$session) {
            return null;
        }

        $user = $session->user;
        if (!$user || !$user->is_active || $user->is_suspended) {
            $session->update(['is_revoked' => true]);
            return null;
        }

        // Token rotation: generate new refresh token id
        $newRefreshTokenId = Str::random(64);
        $newExpiresAt = now()->addDays(30);

        $session->update([
            'refresh_token_id' => hash('sha256', $newRefreshTokenId),
            'last_active_at' => now(),
            'expires_at' => $newExpiresAt,
            'ip_address' => $ip ?? $session->ip_address,
        ]);

        $customClaims = [
            'client_id' => $clientId,
            'session_id' => $session->id,
            'device_id' => $session->device_id,
        ];

        $accessToken = JWTAuth::claims($customClaims)->fromUser($user);

        return [
            'access_token' => $accessToken,
            'refresh_token' => $newRefreshTokenId,
            'token_type' => 'Bearer',
            'expires_in' => config('jwt.ttl', 60) * 60,
            'session_id' => $session->id,
        ];
    }

    /**
     * Revoke a single session (Local Logout).
     */
    public function revokeSession(string $sessionId, string $userId): bool
    {
        return (bool) UserSession::where('id', $sessionId)
            ->where('user_id', $userId)
            ->update(['is_revoked' => true]);
    }

    /**
     * Revoke all sessions for a user across all apps and devices (Global Logout).
     */
    public function revokeAllSessionsForUser(string $userId): int
    {
        return UserSession::where('user_id', $userId)
            ->where('is_revoked', false)
            ->update(['is_revoked' => true]);
    }
}
