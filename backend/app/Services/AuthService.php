<?php

namespace App\Services;

use App\Repositories\UserRepository;
use App\Repositories\UserSessionRepository;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AuthService extends BaseService
{
    protected UserRepository $userRepository;
    protected UserSessionRepository $sessionRepository;

    public function __construct(UserRepository $userRepository, UserSessionRepository $sessionRepository)
    {
        $this->userRepository = $userRepository;
        $this->sessionRepository = $sessionRepository;
    }

    public function register(array $data)
    {
        $data['password'] = Hash::make($data['password']);
        $data['role'] = 'user';
        $data['is_creator_approved'] = 0;

        return $this->userRepository->create($data);
    }

    public function login(string $identifier, string $password): ?array
    {
        $loginField = filter_var($identifier, FILTER_VALIDATE_EMAIL) ? 'email' : 'username';
        $credentials = [
            $loginField => $identifier,
            'password' => $password
        ];

        if (! $token = Auth::guard('api')->attempt($credentials)) {
            return null; // Auth failed
        }

        return $this->generateTokenPayload($token);
    }

    public function logout(?string $sessionToken): bool
    {
        if ($sessionToken) {
            $this->sessionRepository->deleteByToken($sessionToken);
        }
        
        Auth::guard('api')->logout();
        return true;
    }

    public function refresh(string $sessionToken, string $refreshToken): ?array
    {
        $session = $this->sessionRepository->findBySessionAndRefresh($sessionToken, $refreshToken);

        if (!$session || $session->expires_at < now()) {
            if ($session) $this->sessionRepository->delete($session->id);
            return null;
        }

        $user = $session->user;
        if (!$user) {
            return null;
        }

        $token = Auth::guard('api')->login($user);
        $newRefreshToken = Str::random(60);
        $this->sessionRepository->update($session->id, ['refresh_token' => $newRefreshToken]);

        return $this->generateTokenPayload($token, $session->session_token, $newRefreshToken, $user);
    }

    protected function generateTokenPayload($token, $sessionToken = null, $refreshToken = null, $user = null): array
    {
        $user = $user ?? Auth::guard('api')->user();
        
        $ttlSeconds = Auth::guard('api')->factory()->getTTL() * 60;
        
        // Extract JTI and store in Redis
        $payload = \Tymon\JWTAuth\Facades\JWTAuth::setToken($token)->getPayload();
        $jti = $payload->get('jti');
        if ($jti) {
            JtiService::store($jti, $ttlSeconds);
        }

        if (!$sessionToken || !$refreshToken) {
            $sessionToken = Str::random(60);
            $refreshToken = Str::random(60);

            $this->sessionRepository->create([
                'user_id' => $user->id,
                'session_token' => $sessionToken,
                'refresh_token' => $refreshToken,
                'expires_at' => now()->addDays(7),
            ]);
        }

        return [
            'token' => $token,
            'access_token' => $token,
            'refresh_token' => $refreshToken,
            'session_token' => $sessionToken,
            'token_type' => 'bearer',
            'expires_in' => $ttlSeconds,
            'user' => [
                'id' => $user->id,
                'role' => $user->role,
            ]
        ];
    }
}
