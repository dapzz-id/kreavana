<?php

namespace App\Http\Controllers\Auth;

use App\Models\AuthLog;
use App\Models\User;
use App\Services\JtiService;
use App\Services\RefreshTokenRepository;
use Illuminate\Support\Facades\Auth;
use Tymon\JWTAuth\Facades\JWTAuth;

trait AuthResponder
{
    /**
     * Generate a minimal access-token response and cookie-only refresh token.
     */
    protected function respondWithToken(string $token, ?User $user = null, ?string $refreshToken = null)
    {
        $user ??= Auth::guard('api')->user();
        $ttlSeconds = min(Auth::guard('api')->factory()->getTTL() * 60, (int) config('auth_tokens.access_ttl_minutes', 5) * 60);

        $payload = JWTAuth::setToken($token)->getPayload();
        $jti = $payload->get('jti');
        if ($jti) {
            JtiService::store($jti, $ttlSeconds);
        }

        if (!$refreshToken && $user) {
            $refreshToken = app(RefreshTokenRepository::class)->issue($user);
        }

        $response = response()->json([
            'status' => true,
            'data' => [
                'access_token' => $token,
                'token_type' => 'bearer',
                'expires_in' => $ttlSeconds,
            ]
        ]);

        return $response->cookie(
            config('auth_tokens.refresh.cookie'),
            (string) $refreshToken,
            (int) config('auth_tokens.refresh.ttl_minutes'),
            config('auth_tokens.refresh.path'),
            null,
            request()->secure() || app()->environment('production'), // secure
            true, // httpOnly
            false,
            config('auth_tokens.refresh.same_site')
        );
    }

    /**
     * Handle token refresh dengan session rotation.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\JsonResponse
     */
    protected function handleRefresh($request)
    {
        $refreshToken = $request->cookie(config('auth_tokens.refresh.cookie'));
        if (!$refreshToken) {
            return $this->genericUnauthorized();
        }

        $rotation = app(RefreshTokenRepository::class)->rotate($refreshToken);
        if (!$rotation) {
            AuthLog::create([
                'user_id' => null,
                'action' => 'refresh_failed',
                'ip_address' => $request->ip(),
                'user_agent' => substr((string) $request->userAgent(), 0, 255)
            ]);
            return $this->genericUnauthorized();
        }

        $this->revokeBearerJtiIfPresent();

        $user = User::find($rotation['user_id']);
        if (!$user) {
            return $this->genericUnauthorized();
        }

        $token = Auth::guard('api')->login($user);
        $newRefreshToken = app(RefreshTokenRepository::class)->issue($user, $rotation['family_id']);

        AuthLog::create([
            'user_id' => $user->id,
            'action' => 'refresh',
            'ip_address' => $request->ip(),
            'user_agent' => substr((string) $request->userAgent(), 0, 255)
        ]);

        return $this->respondWithToken($token, $user, $newRefreshToken);
    }

    /**
     * Handle logout dengan session cleanup.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\JsonResponse
     */
    protected function handleLogout($request)
    {
        app(RefreshTokenRepository::class)->revokeRaw($request->cookie(config('auth_tokens.refresh.cookie')));
        $this->revokeBearerJtiIfPresent();

        $user = Auth::guard('api')->user();
        if ($user) {
            AuthLog::create([
                'user_id' => $user->id,
                'action' => 'logout',
                'ip_address' => $request->ip(),
                'user_agent' => substr((string) $request->userAgent(), 0, 255)
            ]);
        }

        Auth::guard('api')->logout();

        return response()->json(['status' => true])
            ->withoutCookie(config('auth_tokens.refresh.cookie'), config('auth_tokens.refresh.path'));
    }

    protected function genericUnauthorized()
    {
        return response()->json(['status' => false, 'message' => 'Unauthorized'], 401);
    }

    private function revokeBearerJtiIfPresent(): void
    {
        $oldToken = JWTAuth::getToken();
        if (!$oldToken) {
            return;
        }

        try {
            $payload = JWTAuth::getPayload($oldToken);
            $oldJti = $payload->get('jti');
            $exp = $payload->get('exp');
            if ($oldJti) {
                JtiService::revoke($oldJti, $exp ? max(60, (int) $exp - time()) : null);
            }
        } catch (\Throwable) {
        }
    }
}
