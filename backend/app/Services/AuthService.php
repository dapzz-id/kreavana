<?php

namespace App\Services;

use App\Contracts\AuthServiceInterface;
use App\Models\User;
use App\Models\AuthLog;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;

class AuthService implements AuthServiceInterface
{
    public function register(array $data): User
    {
        return DB::transaction(function () use ($data) {
            return User::create([
                'name' => $data['name'],
                'username' => $data['username'],
                'email' => $data['email'],
                'password' => Hash::make($data['password']),
                'role' => 'user',
                'is_creator_approved' => 0,
            ]);
        });
    }

    public function attemptLogin(array $credentials, string $ip, string $userAgent, ?string $requiredRole = null): ?string
    {
        if (! $token = Auth::guard('api')->attempt($credentials)) {
            AuthLog::create([
                'user_id' => null,
                'action' => 'login_failed',
                'ip_address' => $ip,
                'user_agent' => substr($userAgent, 0, 255)
            ]);
            return null;
        }

        $user = Auth::guard('api')->user();
        if ($requiredRole && $user->role !== $requiredRole) {
            Auth::guard('api')->logout();
            AuthLog::create([
                'user_id' => $user->id,
                'action' => 'login_forbidden',
                'ip_address' => $ip,
                'user_agent' => substr($userAgent, 0, 255)
            ]);
            return 'forbidden';
        }

        AuthLog::create([
            'user_id' => $user->id,
            'action' => 'login',
            'ip_address' => $ip,
            'user_agent' => substr($userAgent, 0, 255)
        ]);

        return $token;
    }
}
