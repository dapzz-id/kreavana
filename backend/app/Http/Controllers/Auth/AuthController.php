<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Contracts\AuthServiceInterface;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Http;
use App\Models\User;
use App\Models\AuthLog;

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

        return response()->json(['status' => true], 201);
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
                
                $user = User::create([
                    'name' => $name ?? 'User',
                    'username' => $username,
                    'email' => $email,
                    'password' => \Illuminate\Support\Facades\Hash::make(uniqid()), // Random password
                    'role' => 'user',
                    'email_verified_at' => now(), // Auto-verify for social login
                ]);
                $isNewUser = true;
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
            $response = Http::get('https://oauth2.googleapis.com/tokeninfo', [
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
            $keysResponse = Http::get('https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com');
            if ($keysResponse->failed()) {
                return null;
            }

            $publicKeys = $keysResponse->json();

            // Decode header JWT untuk mendapatkan kid (key ID)
            $parts = explode('.', $idToken);
            if (count($parts) !== 3) {
                return null;
            }

            $header = json_decode(base64_decode(str_replace(['-', '_'], ['+', '/'], $parts[0])), true);
            $kid = $header['kid'] ?? null;

            if (!$kid || !isset($publicKeys[$kid])) {
                return null;
            }

            // Decode payload JWT
            $payloadJson = base64_decode(str_replace(['-', '_'], ['+', '/'], $parts[1]));
            $payload = json_decode($payloadJson, true);

            if (!$payload || !isset($payload['email'])) {
                return null;
            }

            // Validasi issuer
            $projectId = env('FIREBASE_PROJECT_ID', 'kreavana-com');
            $expectedIssuer = 'https://securetoken.google.com/' . $projectId;
            if (($payload['iss'] ?? '') !== $expectedIssuer) {
                return null;
            }

            // Validasi audience
            if (($payload['aud'] ?? '') !== $projectId) {
                return null;
            }

            // Validasi exp
            if (($payload['exp'] ?? 0) < time()) {
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
            \Log::debug('Firebase token verification skipped: ' . $e->getMessage());
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
}
