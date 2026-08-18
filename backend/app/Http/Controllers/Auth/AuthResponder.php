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

        $isMobile = request()->header('X-Client-Type') === 'mobile';

        $data = [
            'access_token' => $token,
            'token_type' => 'bearer',
            'expires_in' => $ttlSeconds,
            'user' => $user ? [
                'id' => $user->id,
                'name' => $user->name,
                'username' => $user->username,
                'email' => $user->email,
                'role' => $user->role->value,
                'sub_role' => $user->sub_role instanceof \BackedEnum ? $user->sub_role->value : $user->sub_role,
                'avatar_url' => $user->avatar_url,
                'is_creator_approved' => (bool) $user->is_creator_approved,
                'balance' => $user->balance,
            ] : null,
        ];

        if ($isMobile) {
            $data['refresh_token'] = $refreshToken;
        }

        $response = response()->json([
            'status' => true,
            'data' => $data
        ]);

        if (!$isMobile) {
            $response->cookie(
                config('auth_tokens.refresh.cookie'),
                (string) $refreshToken,
                (int) config('auth_tokens.refresh.ttl_minutes'),
                config('auth_tokens.refresh.path'),
                null,
                request()->secure() || app()->environment('production', 'testing'), // secure
                true, // httpOnly
                false,
                config('auth_tokens.refresh.same_site')
            );
        }

        return $response;
    }

    /**
     * Handle token refresh dengan session rotation.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\JsonResponse
     */
    protected function handleRefresh($request)
    {
        // Fallback to cookie if not explicitly provided in the request body
        $refreshToken = $request->input('refresh_token') ?: $request->cookie(config('auth_tokens.refresh.cookie'));
        
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
        $refreshToken = $request->input('refresh_token') ?: $request->cookie(config('auth_tokens.refresh.cookie'));
        app(RefreshTokenRepository::class)->revokeRaw($refreshToken);
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

        $response = response()->json(['status' => true]);
        
        if ($request->header('X-Client-Type') !== 'mobile') {
            $response->withoutCookie(config('auth_tokens.refresh.cookie'), config('auth_tokens.refresh.path'));
        }

        return $response;
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
