<?php

namespace App\Services;

use App\Models\User;
use App\Models\UserSession;
use App\Models\RefreshToken;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\DB;
use App\Models\AuthLog;

class RefreshTokenRepository
{
    /**
     * Issues a new refresh token for a user.
     * If $sessionId is provided, it attaches the new token to the existing session.
     * Otherwise, it creates a new session.
     */
    public function issue(User $user, ?string $sessionId = null): string
    {
        $selector = (string) Str::uuid();
        $secret = $this->randomToken();
        $ttl = $this->ttlSeconds();
        $expiresAt = now()->addSeconds($ttl);
        
        $request = request();
        $ip = $request ? $request->ip() : null;
        $userAgent = $request ? substr((string) $request->userAgent(), 0, 255) : null;

        DB::transaction(function () use ($user, $sessionId, $selector, $secret, $expiresAt, $ip, $userAgent) {
            if (!$sessionId) {
                // Create new session
                $session = UserSession::create([
                    'user_id' => $user->id,
                    'ip_address' => $ip,
                    'user_agent' => $userAgent,
                    'expires_at' => $expiresAt,
                    'last_used_at' => now(),
                ]);
                $sessionId = $session->id;
            } else {
                // Update existing session's last_used_at
                UserSession::where('id', $sessionId)->update([
                    'last_used_at' => now(),
                    'ip_address' => $ip,
                    'user_agent' => $userAgent,
                ]);
            }

            RefreshToken::create([
                'id' => $selector,
                'user_session_id' => $sessionId,
                'token_hash' => $this->hash($secret),
                'is_active' => true,
                'expires_at' => $expiresAt,
            ]);
        });

        return "{$selector}.{$secret}";
    }

    /**
     * Atomically rotates a refresh token.
     * Prevents concurrent reuse.
     * Revokes session on reuse detection.
     */
    public function rotate(string $rawToken): ?array
    {
        [$selector, $secret] = $this->parse($rawToken);
        if (!$selector || !$secret) {
            return null;
        }

        try {
            return DB::transaction(function () use ($selector, $secret) {
                // Use row lock to prevent race conditions during concurrent refresh
                $token = RefreshToken::where('id', $selector)->lockForUpdate()->first();

                if (!$token) {
                    return null;
                }

                $session = UserSession::where('id', $token->user_session_id)->lockForUpdate()->first();

                if (!$session || $session->revoked_at || $session->expires_at < now()) {
                    return null;
                }

                // Verify the hash
                if (!hash_equals($token->token_hash, $this->hash($secret))) {
                    return null;
                }

                // Reuse detection
                if (!$token->is_active) {
                    // Revoke the entire session
                    $session->update(['revoked_at' => now()]);
                    
                    // Log security event
                    AuthLog::create([
                        'user_id' => $session->user_id,
                        'action' => 'refresh_reuse_detected',
                        'ip_address' => request() ? request()->ip() : null,
                        'user_agent' => request() ? substr((string) request()->userAgent(), 0, 255) : null,
                    ]);

                    return null;
                }

                // Valid token, rotate it by invalidating the current one
                $token->update(['is_active' => false]);

                return [
                    'user_id' => $session->user_id,
                    'family_id' => $session->id, // session_id acts as family_id
                ];
            });
        } catch (\Throwable $e) {
            return null;
        }
    }

    /**
     * Revokes a session given a raw token.
     */
    public function revokeRaw(?string $rawToken): void
    {
        if (!$rawToken) {
            return;
        }

        [$selector] = $this->parse($rawToken);
        if ($selector) {
            $token = RefreshToken::find($selector);
            if ($token) {
                $this->revokeSession($token->user_session_id);
            }
        }
    }

    /**
     * Revokes a specific session.
     */
    public function revokeSession(string $sessionId): void
    {
        UserSession::where('id', $sessionId)
            ->whereNull('revoked_at')
            ->update(['revoked_at' => now()]);
    }

    /**
     * Revokes all sessions for a user.
     */
    public function revokeAllForUser(string $userId): void
    {
        UserSession::where('user_id', $userId)
            ->whereNull('revoked_at')
            ->update(['revoked_at' => now()]);
    }

    private function parse(string $rawToken): array
    {
        $parts = explode('.', $rawToken, 2);
        return count($parts) === 2 ? $parts : [null, null];
    }

    private function randomToken(): string
    {
        return rtrim(strtr(base64_encode(random_bytes(48)), '+/', '-_'), '=');
    }

    private function hash(string $secret): string
    {
        return hash_hmac('sha256', $secret, (string) config('app.key'));
    }

    private function ttlSeconds(): int
    {
        return max(60, (int) config('auth_tokens.refresh.ttl_minutes') * 60);
    }
}
