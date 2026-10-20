<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\UserCredential;
use App\Models\UserDevice;
use App\Services\TokenService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Tymon\JWTAuth\Facades\JWTAuth;

class AuthController
{
    protected TokenService $tokenService;

    public function __construct(TokenService $tokenService)
    {
        $this->tokenService = $tokenService;
    }

    /**
     * Universal Registration.
     */
    public function register(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'username' => 'required|string|alpha_dash|min:3|max:50|unique:users,username',
            'email' => 'required|string|email|max:255|unique:users,email',
            'password' => 'required|string|min:8',
            'full_name' => 'required|string|max:255',
            'phone' => 'nullable|string|max:30|unique:users,phone',
            'device_id' => 'nullable|string',
            'device_name' => 'nullable|string',
            'platform' => 'nullable|string|in:ios,android,web,windows,macos,linux',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'Validasi pendaftaran gagal.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $clientId = $request->get('resolved_client_id', 'kreavana_app');

        // Create User
        $user = User::create([
            'username' => strtolower($request->username),
            'email' => strtolower($request->email),
            'phone' => $request->phone,
            'full_name' => $request->full_name,
            'display_name' => $request->display_name ?? $request->full_name,
            'locale' => $request->locale ?? 'id',
            'timezone' => $request->timezone ?? 'Asia/Jakarta',
            'last_login_at' => now(),
        ]);

        // Create Credential
        UserCredential::create([
            'user_id' => $user->id,
            'password_hash' => Hash::make($request->password),
            'is_email_verified' => false,
            'password_changed_at' => now(),
        ]);

        // Register Device if provided
        if ($request->device_id) {
            UserDevice::updateOrCreate(
                ['user_id' => $user->id, 'device_id' => $request->device_id],
                [
                    'device_name' => $request->device_name,
                    'platform' => $request->platform ?? 'web',
                    'last_active_at' => now(),
                ]
            );
        }

        // Issue tokens
        $tokens = $this->tokenService->createTokensForUser(
            $user,
            $clientId,
            $request->device_id,
            $request->ip(),
            $request->userAgent()
        );

        return response()->json([
            'status' => true,
            'message' => 'Registrasi identitas universal berhasil.',
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'username' => $user->username,
                    'email' => $user->email,
                    'full_name' => $user->full_name,
                    'avatar_url' => $user->avatar_url,
                ],
                'tokens' => $tokens,
            ],
        ], 201);
    }

    /**
     * Universal Login.
     */
    public function login(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'identifier' => 'required_without:email|string',
            'email' => 'required_without:identifier|string',
            'password' => 'required|string',
            'device_id' => 'nullable|string',
            'device_name' => 'nullable|string',
            'platform' => 'nullable|string|in:ios,android,web,windows,macos,linux',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'Parameter login tidak lengkap.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $identifier = strtolower($request->input('identifier') ?? $request->input('email'));
        $clientId = $request->get('resolved_client_id', 'kreavana_app');

        // Find user by email or username
        $user = User::where('email', $identifier)
            ->orWhere('username', $identifier)
            ->first();

        if (!$user) {
            return response()->json([
                'status' => false,
                'message' => 'Kredensial tidak valid.',
            ], 401);
        }

        if (!$user->is_active || $user->is_suspended) {
            return response()->json([
                'status' => false,
                'message' => 'Akun dinonaktifkan atau ditangguhkan.',
            ], 403);
        }

        $credential = $user->credential;
        if (!$credential || !Hash::check($request->password, $credential->password_hash)) {
            // Increment failed attempts
            if ($credential) {
                $credential->increment('failed_login_attempts');
            }
            return response()->json([
                'status' => false,
                'message' => 'Kredensial tidak valid.',
            ], 401);
        }

        // Reset failed login attempts & update last login
        $credential->update(['failed_login_attempts' => 0]);
        $user->update(['last_login_at' => now()]);

        // Register Device
        if ($request->device_id) {
            UserDevice::updateOrCreate(
                ['user_id' => $user->id, 'device_id' => $request->device_id],
                [
                    'device_name' => $request->device_name,
                    'platform' => $request->platform ?? 'web',
                    'last_active_at' => now(),
                ]
            );
        }

        // Issue tokens
        $tokens = $this->tokenService->createTokensForUser(
            $user,
            $clientId,
            $request->device_id,
            $request->ip(),
            $request->userAgent()
        );

        return response()->json([
            'status' => true,
            'message' => 'Login identitas universal berhasil.',
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'username' => $user->username,
                    'email' => $user->email,
                    'full_name' => $user->full_name,
                    'display_name' => $user->display_name,
                    'avatar_url' => $user->avatar_url,
                    'is_kyc_verified' => $user->kyc?->status === 'approved',
                ],
                'tokens' => $tokens,
            ],
        ]);
    }

    /**
     * Refresh Token (Session Continuity without logout).
     */
    public function refresh(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'refresh_token' => 'required|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'Refresh token diperlukan.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $clientId = $request->get('resolved_client_id', 'kreavana_app');

        $tokens = $this->tokenService->refreshSession(
            $request->refresh_token,
            $clientId,
            $request->ip()
        );

        if (!$tokens) {
            return response()->json([
                'status' => false,
                'message' => 'Sesi tidak valid atau telah kedaluwarsa. Silakan login kembali.',
            ], 401);
        }

        return response()->json([
            'status' => true,
            'message' => 'Token berhasil diperbarui.',
            'data' => $tokens,
        ]);
    }

    /**
     * Get Current Authenticated User (Profile & KYC Status).
     */
    public function me(Request $request)
    {
        $user = JWTAuth::parseToken()->authenticate();
        $user->load(['kyc', 'addresses']);

        return response()->json([
            'status' => true,
            'data' => [
                'id' => $user->id,
                'username' => $user->username,
                'email' => $user->email,
                'phone' => $user->phone,
                'full_name' => $user->full_name,
                'display_name' => $user->display_name,
                'avatar_url' => $user->avatar_url,
                'locale' => $user->locale,
                'timezone' => $user->timezone,
                'kyc' => $user->kyc ? [
                    'status' => $user->kyc->status,
                    'verification_type' => $user->kyc->verification_type,
                    'verified_at' => $user->kyc->verified_at,
                ] : null,
                'addresses' => $user->addresses,
            ],
        ]);
    }

    /**
     * Local Logout (Revoke only current session).
     */
    public function logout(Request $request)
    {
        $payload = JWTAuth::parseToken()->getPayload();
        $sessionId = $payload->get('session_id');
        $userId = $payload->get('sub');

        if ($sessionId && $userId) {
            $this->tokenService->revokeSession($sessionId, $userId);
        }

        return response()->json([
            'status' => true,
            'message' => 'Berhasil logout dari sesi ini.',
        ]);
    }

    /**
     * Global Logout (Revoke ALL sessions across ALL apps and devices).
     */
    public function logoutAllDevices(Request $request)
    {
        $userId = JWTAuth::parseToken()->getPayload()->get('sub');

        $count = $this->tokenService->revokeAllSessionsForUser($userId);

        return response()->json([
            'status' => true,
            'message' => "Berhasil logout dari semua perangkat ($count sesi dicabut).",
        ]);
    }

    /**
     * Universal Social Login (Google & Federated Providers).
     */
    public function socialLogin(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'provider' => 'required|string|in:google,apple',
            'id_token' => 'required|string',
            'device_id' => 'nullable|string',
            'device_name' => 'nullable|string',
            'platform' => 'nullable|string|in:ios,android,web,windows,macos,linux',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'Parameter social login tidak valid.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $clientId = $request->get('resolved_client_id', 'kreavana_app');
        $provider = $request->provider;
        $idToken = $request->id_token;

        try {
            if ($provider === 'google') {
                $googleData = $this->verifyGoogleToken($idToken);
                if (!$googleData) {
                    return response()->json([
                        'status' => false,
                        'message' => 'Token Google tidak valid atau kedaluwarsa.',
                    ], 401);
                }

                $email = strtolower($googleData['email']);
                $name = $googleData['name'] ?? $request->name ?? 'User';
                $avatar = $googleData['picture'] ?? null;
            } else {
                return response()->json([
                    'status' => false,
                    'message' => 'Provider belum didukung.',
                ], 400);
            }

            // Find or create Universal User
            $user = User::where('email', $email)->first();
            $isNewUser = false;

            if (!$user) {
                // Generate a unique username
                $baseUsername = strtolower(preg_replace('/[^a-zA-Z0-9_]/', '', explode('@', $email)[0]));
                $username = $baseUsername;
                $counter = 1;
                while (User::where('username', $username)->exists()) {
                    $username = $baseUsername . $counter++;
                }

                $user = User::create([
                    'username' => $username,
                    'email' => $email,
                    'full_name' => $name,
                    'display_name' => $name,
                    'avatar_url' => $avatar,
                    'locale' => 'id',
                    'timezone' => 'Asia/Jakarta',
                    'last_login_at' => now(),
                ]);

                UserCredential::create([
                    'user_id' => $user->id,
                    'password_hash' => Hash::make(\Illuminate\Support\Str::random(16)),
                    'is_email_verified' => true,
                    'email_verified_at' => now(),
                    'password_changed_at' => now(),
                ]);

                $isNewUser = true;
            } else {
                $user->update([
                    'last_login_at' => now(),
                    'avatar_url' => $user->avatar_url ?? $avatar,
                ]);

                // Ensure email verified
                if ($user->credential && !$user->credential->is_email_verified) {
                    $user->credential->update([
                        'is_email_verified' => true,
                        'email_verified_at' => now(),
                    ]);
                }
            }

            // Register Device if provided
            if ($request->device_id) {
                UserDevice::updateOrCreate(
                    ['user_id' => $user->id, 'device_id' => $request->device_id],
                    [
                        'device_name' => $request->device_name,
                        'platform' => $request->platform ?? 'web',
                        'last_active_at' => now(),
                    ]
                );
            }

            // Issue tokens
            $tokens = $this->tokenService->createTokensForUser(
                $user,
                $clientId,
                $request->device_id,
                $request->ip(),
                $request->userAgent()
            );

            return response()->json([
                'status' => true,
                'message' => 'Login Google berhasil.',
                'data' => [
                    'is_new_user' => $isNewUser,
                    'user' => [
                        'id' => $user->id,
                        'username' => $user->username,
                        'email' => $user->email,
                        'full_name' => $user->full_name,
                        'avatar_url' => $user->avatar_url,
                        'is_kyc_verified' => $user->kyc?->status === 'approved',
                    ],
                    'tokens' => $tokens,
                ],
            ]);
        } catch (\Throwable $e) {
            return response()->json([
                'status' => false,
                'message' => 'Terjadi kesalahan saat memproses login sosial.',
                'error' => env('APP_DEBUG') ? $e->getMessage() : null,
            ], 500);
        }
    }

    /**
     * Verify Google ID Token via Google's tokeninfo API.
     */
    private function verifyGoogleToken(string $idToken): ?array
    {
        try {
            $response = \Illuminate\Support\Facades\Http::withOptions([
                'verify' => false,
                'timeout' => 15,
            ])->get('https://oauth2.googleapis.com/tokeninfo', [
                'id_token' => $idToken,
            ]);

            if ($response->successful()) {
                $payload = $response->json();
                if (!empty($payload['email'])) {
                    return $payload;
                }
            }
        } catch (\Throwable) {
            // Ignore error
        }

        return null;
    }
}
