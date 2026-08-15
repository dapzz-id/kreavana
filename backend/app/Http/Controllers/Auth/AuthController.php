<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\User;
use App\Models\AuthLog;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use App\Jobs\SendSocialLoginPasswordJob;
use App\Contracts\AuthServiceInterface;
use Illuminate\Support\Facades\Http;

class AuthController extends Controller
{
    use AuthResponder;

    protected AuthServiceInterface $authService;

    public function __construct(AuthServiceInterface $authService)
    {
        $this->authService = $authService;
    }

    /**
     * Register user baru (public).
     */
    public function register(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:100',
            'username' => 'required|string|max:50|unique:users',
            'email' => 'required|string|email|max:150|unique:users',
            'password' => 'required|string|min:6',
        ]);

        $user = $this->authService->register([
            'name' => $request->name,
            'username' => $request->username,
            'email' => $request->email,
            'password' => $request->password,
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Pendaftaran berhasil. Silakan verifikasi email Anda.',
            'data' => [
                'email' => $user->email,
                'requires_verification' => true,
            ],
        ], 201);
    }

    /**
     * Login user.
     */
    public function login(Request $request)
    {
        return $this->attemptLogin($request);
    }

    public function userLogin(Request $request)
    {
        return $this->attemptLogin($request, 'user');
    }

    public function creatorLogin(Request $request)
    {
        return $this->attemptLogin($request, 'creator');
    }

    public function adminLogin(Request $request)
    {
        return $this->attemptLogin($request, 'admin');
    }

    private function attemptLogin(Request $request, ?string $requiredRole = null)
    {
        $request->validate([
            'email' => 'required|string',
            'password' => 'required|string',
        ]);

        $loginField = filter_var($request->email, FILTER_VALIDATE_EMAIL) ? 'email' : 'username';
        $credentials = [
            $loginField => $request->email,
            'password' => $request->password
        ];

        $token = $this->authService->attemptLogin(
            $credentials,
            $request->ip(),
            substr((string) $request->userAgent(), 0, 255),
            $requiredRole
        );

        if ($token === null) {
            return response()->json(['status' => false, 'message' => 'Email atau kata sandi salah.'], 401);
        }

        if ($token === 'email_not_verified') {
            return response()->json([
                'status' => false,
                'message' => 'Email Anda belum diverifikasi.',
                'error_code' => 'email_not_verified',
                'data' => [
                    'email' => $request->email,
                ],
            ], 403);
        }

        if ($token === 'forbidden') {
            return response()->json(['status' => false, 'message' => 'Forbidden'], 403);
        }

        return $this->respondWithToken($token, Auth::guard('api')->user());
    }

    /**
     * Logout user.
     */
    public function logout(Request $request)
    {
        return $this->handleLogout($request);
    }

    /**
     * Get active sessions for the current user.
     */
    public function getSessions(Request $request)
    {
        $user = Auth::guard('api')->user();
        
        $sessions = \App\Models\UserSession::where('user_id', $user->id)
            ->whereNull('revoked_at')
            ->where('expires_at', '>', now())
            ->orderBy('last_used_at', 'desc')
            ->get(['id', 'device_name', 'platform', 'ip_address', 'user_agent', 'last_used_at', 'expires_at']);

        return response()->json([
            'status' => true,
            'data' => $sessions
        ]);
    }

    /**
     * Revoke a specific session.
     */
    public function revokeSession(Request $request, $id)
    {
        $user = Auth::guard('api')->user();
        
        $session = \App\Models\UserSession::where('id', $id)
            ->where('user_id', $user->id) // Prevent IDOR
            ->first();

        if (!$session) {
            return response()->json(['status' => false, 'message' => 'Session not found'], 404);
        }

        app(\App\Services\RefreshTokenRepository::class)->revokeSession($session->id);

        return response()->json(['status' => true, 'message' => 'Session revoked']);
    }

    /**
     * Logout from all sessions.
     */
    public function logoutAll(Request $request)
    {
        $user = Auth::guard('api')->user();
        
        app(\App\Services\RefreshTokenRepository::class)->revokeAllForUser($user->id);

        $this->revokeBearerJtiIfPresent();
        
        AuthLog::create([
            'user_id' => $user->id,
            'action' => 'logout_all',
            'ip_address' => $request->ip(),
            'user_agent' => substr((string) $request->userAgent(), 0, 255)
        ]);
        
        Auth::guard('api')->logout();

        return response()->json(['status' => true, 'message' => 'Berhasil logout dari semua perangkat.'])
            ->withoutCookie(config('auth_tokens.refresh.cookie'), config('auth_tokens.refresh.path'));
    }

    /**
     * Refresh token user.
     */
    public function refresh(Request $request)
    {
        return $this->handleRefresh($request);
    }

    /**
     * Ubah kata sandi user yang sedang login.
     */
    public function changePassword(Request $request)
    {
        $request->validate([
            'current_password' => 'required|string',
            'new_password' => 'required|string|min:6|different:current_password',
        ]);

        $user = Auth::guard('api')->user();

        if (! Hash::check($request->current_password, $user->password)) {
            return response()->json([
                'status' => false,
                'message' => 'Kata sandi saat ini salah.',
            ], 422);
        }

        $user->update([
            'password' => Hash::make($request->new_password),
        ]);

        AuthLog::create([
            'user_id' => $user->id,
            'action' => 'password_changed',
            'ip_address' => $request->ip(),
            'user_agent' => substr((string) $request->userAgent(), 0, 255),
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Kata sandi berhasil diperbarui.',
        ]);
    }

    /**
     * Tetapkan kata sandi awal (untuk user baru dari social login).
     */
    public function setInitialPassword(Request $request)
    {
        $request->validate([
            'password' => 'required|string|min:6',
        ]);

        $user = Auth::guard('api')->user();

        $user->update([
            'password' => \Illuminate\Support\Facades\Hash::make($request->password),
        ]);

        AuthLog::create([
            'user_id' => $user->id,
            'action' => 'initial_password_set',
            'ip_address' => $request->ip(),
            'user_agent' => substr((string) $request->userAgent(), 0, 255),
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Kata sandi berhasil disimpan. Anda kini bisa login menggunakan email.',
        ]);
    }

    /**
     * Get current user data.
     */
    public function me()
    {
        $user = Auth::guard('api')->user();

        return response()->json([
            'status' => true,
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'uid' => $user->id,
                    'name' => $user->name,
                    'username' => $user->username,
                    'email' => $user->email,
                    'role' => $user->role,
                    'sub_role' => $user->sub_role,
                    'is_creator_approved' => (bool) $user->is_creator_approved,
                    'permissions' => config('permissions.' . $user->role, []),
                ],
            ]
        ]);
    }

    /**
     * Social Login (Google, Apple, etc.)
     * 
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function socialLogin(Request $request)
    {
        $request->validate([
            'provider' => 'required|string|in:google,apple',
            'id_token' => 'required|string',
            'email' => 'nullable|email',
            'name' => 'nullable|string',
            'photo_url' => 'nullable|url',
        ]);

        $provider = $request->provider;
        $idToken = $request->id_token;

        try {
            // Verify token based on provider
            if ($provider === 'google') {
                $googleUser = $this->verifyGoogleToken($idToken);
                if (!$googleUser) {
                    return response()->json([
                        'status' => false,
                        'message' => 'Token Google tidak valid.',
                    ], 401);
                }

                $email = $googleUser['email'];
                $name = $googleUser['name'] ?? $request->name;
                $photoUrl = $googleUser['picture'] ?? $request->photo_url;
                $providerId = $googleUser['sub'];
            } elseif ($provider === 'apple') {
                // TODO: Implement Apple Sign-In verification
                $email = $request->email;
                $name = $request->name;
                $photoUrl = $request->photo_url;
                $providerId = null;
            } else {
                return response()->json([
                    'status' => false,
                    'message' => 'Provider tidak didukung.',
                ], 400);
            }

            // Find or create user
            $user = User::where('email', $email)->first();
            $isNewUser = false;

            if (!$user) {
                // Create new user
                $username = $this->generateUsername($email);
                $plainPassword = Str::random(10);
                
                $user = User::create([
                    'name' => $name ?? 'User',
                    'username' => $username,
                    'email' => $email,
                    'password' => \Illuminate\Support\Facades\Hash::make($plainPassword),
                    'avatar_url' => $photoUrl,
                    'role' => 'user',
                    'email_verified_at' => now(), // Auto-verify for social login
                ]);
                
                // Dispatch job to send email in the background
                SendSocialLoginPasswordJob::dispatch($email, $plainPassword);

                $isNewUser = true;
            } else {
                // Auto-verify existing user's email if not yet verified
                if ($user->email_verified_at === null) {
                    $user->update([
                        'email_verified_at' => now(),
                        'email_verification_code_hash' => null,
                        'email_verification_expires_at' => null,
                        'email_verification_attempts' => 0,
                    ]);
                }
            }

            // Log successful login
            AuthLog::create([
                'user_id' => $user->id,
                'action' => 'login_social_' . $provider,
                'ip_address' => $request->ip(),
                'user_agent' => substr((string) $request->userAgent(), 0, 255)
            ]);

            // Generate JWT token
            $token = Auth::guard('api')->login($user);

            $response = $this->respondWithToken($token, $user);
            $data = $response->getData(true);
            $data['data']['is_new_user'] = $isNewUser;
            $response->setData($data);

            return $response;
        } catch (\Exception $e) {
            return response()->json([
                'status' => false,
                'message' => 'Terjadi kesalahan saat login.',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Verify Google ID Token.
     *
     * Mendukung dua jenis token:
     * - Token langsung dari google_sign_in (mobile): audience = Google Client ID
     * - Token dari Firebase signInWithPopup (web): audience = Firebase Project ID
     *
     * @param string $idToken
     * @return array|null
     */
    private function verifyGoogleToken($idToken)
    {
        try {
            // Coba validasi sebagai Firebase ID Token terlebih dahulu
            // Firebase token menggunakan JWKS endpoint yang berbeda
            $firebaseResult = $this->verifyFirebaseToken($idToken);
            if ($firebaseResult) {
                return $firebaseResult;
            }

            // Fallback: validasi sebagai Google ID Token biasa (untuk mobile)
            $response = Http::withoutVerifying()->get('https://oauth2.googleapis.com/tokeninfo', [
                'id_token' => $idToken,
            ]);

            if ($response->failed()) {
                return null;
            }

            $payload = $response->json();

            if (!isset($payload['email'])) {
                return null;
            }

            // Verify audience: bisa berupa Google Client ID atau Firebase Project ID
            $googleClientId = env('GOOGLE_CLIENT_ID');
            $firebaseProjectId = env('FIREBASE_PROJECT_ID', 'kreavana-com');
            $tokenAud = $payload['aud'] ?? '';

            if ($googleClientId && $tokenAud !== $googleClientId && $tokenAud !== $firebaseProjectId) {
                \Log::warning('Google token audience mismatch', [
                    'expected_google' => $googleClientId,
                    'expected_firebase' => $firebaseProjectId,
                    'got' => $tokenAud,
                ]);
                // Jangan reject — mungkin token dari Firebase multi-tenant
            }

            // Verify token hasn't expired
            if (isset($payload['exp']) && $payload['exp'] < time()) {
                return null;
            }

            return [
                'sub' => $payload['sub'] ?? '',
                'email' => $payload['email'],
                'name' => $payload['name'] ?? '',
                'picture' => $payload['picture'] ?? null,
                'email_verified' => $payload['email_verified'] ?? false,
            ];
        } catch (\Exception $e) {
            \Log::error('Google token verification failed: ' . $e->getMessage());
            return null;
        }
    }

    /**
     * Verify Firebase ID Token menggunakan Google Public Keys (JWKS).
     * Token ini diterbitkan oleh Firebase saat signInWithPopup di Web.
     *
     * @param string $idToken
     * @return array|null
     */
    private function verifyFirebaseToken($idToken)
    {
        try {
            // Ambil public keys Firebase
            $keysResponse = Http::timeout(10)->withoutVerifying()->get('https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com');
            if ($keysResponse->failed()) {
                \Log::warning('Firebase: failed to fetch public keys', ['status' => $keysResponse->status()]);
                return null;
            }

            $publicKeys = $keysResponse->json();

            // Decode header JWT untuk mendapatkan kid (key ID)
            $parts = explode('.', $idToken);
            if (count($parts) !== 3) {
                \Log::warning('Firebase: token bukan JWT valid', ['parts_count' => count($parts)]);
                return null;
            }

            $headerB64 = str_replace(['-', '_'], ['+', '/'], $parts[0]);
            $headerB64 .= str_repeat('=', (4 - strlen($headerB64) % 4) % 4);
            $header = json_decode(base64_decode($headerB64), true);
            $kid = $header['kid'] ?? null;

            if (!$kid) {
                \Log::warning('Firebase: kid not found in header', ['header' => $header]);
                return null;
            }
            if (!isset($publicKeys[$kid])) {
                \Log::warning('Firebase: kid not found in public keys', ['kid' => $kid, 'available_keys' => array_keys($publicKeys)]);
                return null;
            }

            // Decode payload JWT
            $payloadB64 = str_replace(['-', '_'], ['+', '/'], $parts[1]);
            $payloadB64 .= str_repeat('=', (4 - strlen($payloadB64) % 4) % 4);
            $payloadJson = base64_decode($payloadB64);
            $payload = json_decode($payloadJson, true);

            if (!$payload || !isset($payload['email'])) {
                \Log::warning('Firebase: email not found in payload', ['payload' => $payload]);
                return null;
            }

            // Validasi issuer
            $projectId = env('FIREBASE_PROJECT_ID', 'kreavana-com');
            $expectedIssuer = 'https://securetoken.google.com/' . $projectId;
            if (($payload['iss'] ?? '') !== $expectedIssuer) {
                \Log::warning('Firebase: issuer mismatch', ['expected' => $expectedIssuer, 'got' => $payload['iss'] ?? 'null']);
                return null;
            }

            // Validasi audience — terima project ID atau web client ID
            $aud = $payload['aud'] ?? '';
            $webClientId = env('GOOGLE_CLIENT_ID');
            if ($aud !== $projectId && ($webClientId && $aud !== $webClientId)) {
                \Log::warning('Firebase: audience mismatch', ['expected_project' => $projectId, 'expected_client' => $webClientId, 'got' => $aud]);
                return null;
            }

            // Validasi exp
            if (($payload['exp'] ?? 0) < time()) {
                \Log::warning('Firebase: token expired', ['exp' => $payload['exp'], 'now' => time()]);
                return null;
            }

            return [
                'sub' => $payload['sub'] ?? $payload['user_id'] ?? '',
                'email' => $payload['email'],
                'name' => $payload['name'] ?? '',
                'picture' => $payload['picture'] ?? null,
                'email_verified' => $payload['email_verified'] ?? false,
            ];
        } catch (\Exception $e) {
            \Log::error('Firebase token verification error: ' . $e->getMessage());
            return null;
        }
    }

    /**
     * Generate unique username from email
     * 
     * @param string $email
     * @return string
     */
    private function generateUsername($email)
    {
        $base = explode('@', $email)[0];
        $base = preg_replace('/[^a-zA-Z0-9_]/', '', $base);
        $username = strtolower($base);
        
        // Check if username exists, add number suffix
        $counter = 1;
        $original = $username;
        while (User::where('username', $username)->exists()) {
            $username = $original . $counter;
            $counter++;
        }
        
        return $username;
    }

    /**
     * Verify email with OTP code.
     */
    public function verifyEmail(Request $request)
    {
        $request->validate([
            'email' => 'required|string|email',
            'code' => 'required|string|size:6|regex:/^[0-9]{6}$/',
        ]);

        $result = $this->authService->verifyEmail($request->email, $request->code);

        return match ($result) {
            'success' => response()->json([
                'status' => true,
                'message' => 'Email berhasil diverifikasi.',
            ]),
            'verification_code_expired' => response()->json([
                'status' => false,
                'message' => 'Kode verifikasi sudah kedaluwarsa. Silakan minta kode baru.',
                'error_code' => 'verification_code_expired',
            ], 422),
            'verification_attempts_exceeded' => response()->json([
                'status' => false,
                'message' => 'Terlalu banyak percobaan. Silakan minta kode verifikasi baru.',
                'error_code' => 'verification_attempts_exceeded',
            ], 422),
            default => response()->json([
                'status' => false,
                'message' => 'Kode verifikasi tidak valid.',
                'error_code' => 'invalid_verification_code',
            ], 422),
        };
    }

    /**
     * Resend email verification OTP.
     */
    public function resendVerificationCode(Request $request)
    {
        $request->validate([
            'email' => 'required|string|email',
        ]);

        $result = $this->authService->resendVerificationCode($request->email);

        return match ($result) {
            'success' => response()->json([
                'status' => true,
                'message' => 'Kode verifikasi baru telah dikirim ke email Anda.',
            ]),
            'email_already_verified' => response()->json([
                'status' => true,
                'message' => 'Email sudah terverifikasi.',
                'error_code' => 'email_already_verified',
            ]),
            'verification_resend_rate_limited' => response()->json([
                'status' => false,
                'message' => 'Mohon tunggu sebelum meminta kode verifikasi baru.',
                'error_code' => 'verification_resend_rate_limited',
            ], 429),
            default => response()->json([
                'status' => false,
                'message' => 'Gagal mengirim kode verifikasi.',
            ], 400),
        };
    }
}
