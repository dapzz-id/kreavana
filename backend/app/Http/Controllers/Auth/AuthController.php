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
use App\Services\UsersApiClient;

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
            'username' => 'required|string|max:50|unique:users,username',
            'email' => 'required|string|email|max:150|unique:users,email',
            'password' => 'required|string|min:8',
        ], [
            'name.required' => 'Nama lengkap wajib diisi.',
            'username.required' => 'Username wajib diisi.',
            'username.unique' => 'Username ini sudah digunakan. Silakan pilih username lain.',
            'email.required' => 'Alamat email wajib diisi.',
            'email.email' => 'Format email tidak valid.',
            'email.unique' => 'Alamat email ini sudah terdaftar. Silakan gunakan email lain atau masuk ke akun Anda.',
            'password.required' => 'Kata sandi wajib diisi.',
            'password.min' => 'Kata sandi minimal 8 karakter.',
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
        return $this->attemptLogin($request, \App\Enums\RoleType::User);
    }

    public function creatorLogin(Request $request)
    {
        return $this->attemptLogin($request, \App\Enums\RoleType::Creator);
    }

    public function adminLogin(Request $request)
    {
        return $this->attemptLogin($request, \App\Enums\RoleType::Admin);
    }

    private function attemptLogin(Request $request, ?\App\Enums\RoleType $requiredRole = null)
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

        if ($token === 'service_unavailable') {
            return response()->json([
                'status' => false,
                'message' => 'Layanan autentikasi sedang tidak dapat dijangkau. Silakan coba beberapa saat lagi.',
            ], 503);
        }

        if ($token === 'email_not_verified') {
            $rawIdentifier = trim((string) $request->email);
            $identifier = strtolower($rawIdentifier);
            $user = User::whereRaw('LOWER(email) = ?', [$identifier])
                ->orWhereRaw('LOWER(username) = ?', [$identifier])
                ->when($rawIdentifier !== '', fn ($q) => $q->orWhere('phone', $rawIdentifier))
                ->first();

            return response()->json([
                'status' => false,
                'message' => 'Email Anda belum diverifikasi.',
                'error_code' => 'email_not_verified',
                'data' => [
                    'email' => $user?->email ?? $request->email,
                ],
            ], 403);
        }

        if ($token === 'forbidden') {
            return response()->json(['status' => false, 'message' => 'Forbidden'], 403);
        }

        if ($token === 'suspended') {
            $user = User::where('email', $request->email)->orWhere('username', $request->email)->first();
            $until = $user?->suspended_until ? ' hingga ' . $user->suspended_until->format('d M Y H:i') : '';
            return response()->json([
                'status' => false,
                'message' => 'Akun Anda di Kreavana sedang ditangguhkan' . $until . '.',
                'reason' => $user?->suspend_reason,
                'suspended_until' => $user?->suspended_until?->toIso8601String(),
            ], 403);
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

        if ($user->isInstitutionSubAccount()) {
            $subAccount = $user->institutionSubAccount;
            if (!$subAccount || !$subAccount->is_active) {
                return response()->json([
                    'status' => false,
                    'message' => 'Sub-akun institusi tidak aktif.',
                ], 403);
            }

            if (!Hash::check($request->current_password, $subAccount->password_hash)) {
                return response()->json([
                    'status' => false,
                    'message' => 'Kata sandi saat ini salah.',
                ], 422);
            }

            $subAccount->update([
                'password_hash' => Hash::make($request->new_password),
                'password_changed_at' => now(),
            ]);

            AuthLog::create([
                'user_id' => $user->id,
                'action' => 'password_changed_sub_account',
                'ip_address' => $request->ip(),
                'user_agent' => substr((string) $request->userAgent(), 0, 255),
            ]);

            return response()->json([
                'status' => true,
                'message' => 'Kata sandi berhasil diperbarui.',
            ]);
        }

        if (!UsersApiClient::isEnabled()) {
            return response()->json([
                'status' => false,
                'message' => 'Layanan autentikasi sedang tidak dapat dijangkau.',
            ], 503);
        }

        $proxyResult = UsersApiClient::changePassword($user, $request->current_password, $request->new_password);
        if (!$proxyResult['success']) {
            return response()->json([
                'status' => false,
                'message' => $proxyResult['message'] ?? 'Gagal memperbarui kata sandi.',
            ], $proxyResult['status'] ?? 422);
        }

        AuthLog::create([
            'user_id' => $user->id,
            'action' => 'password_changed_via_users_api',
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
            'password' => 'required|string|min:8',
        ], [
            'password.required' => 'Kata sandi wajib diisi.',
            'password.min' => 'Kata sandi minimal 8 karakter.',
        ]);

        $user = Auth::guard('api')->user();

        if ($user->isInstitutionSubAccount()) {
            $subAccount = $user->institutionSubAccount;
            if (!$subAccount || !$subAccount->is_active) {
                return response()->json([
                    'status' => false,
                    'message' => 'Sub-akun institusi tidak aktif.',
                ], 403);
            }
            $subAccount->update([
                'password_hash' => Hash::make($request->password),
                'password_changed_at' => now(),
            ]);
        } else {
            if (!UsersApiClient::isEnabled()) {
                return response()->json([
                    'status' => false,
                    'message' => 'Layanan autentikasi sedang tidak dapat dijangkau.',
                ], 503);
            }

            $sync = UsersApiClient::setUserPassword($user, $request->password);
            if (!$sync['success']) {
                return response()->json([
                    'status' => false,
                    'message' => $sync['message'] ?? 'Gagal menyimpan kata sandi awal.',
                ], $sync['status'] ?? 503);
            }
        }

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

        $institutionRole = 'admin';
        $allInstitutionPermissions = [
            'program_magang',
            'kegiatan_event',
            'mitra_industri',
            'karya_siswa',
            'laporan_kegiatan',
            'monitoring_evaluasi',
            'dokumen_institusi',
        ];
        $institutionPermissions = $allInstitutionPermissions;
        $parentInstitutionId = $user->id;

        $memberRecord = \App\Models\InstitutionResource::where('resource_type', 'members')
            ->where(function ($q) use ($user) {
                $q->where('metadata->email', $user->email)
                  ->orWhere('metadata->user_id', $user->id)
                  ->orWhere('metadata->username', $user->username);
            })->first();

        if ($memberRecord && $memberRecord->user_id !== $user->id) {
            $meta = is_array($memberRecord->metadata) ? $memberRecord->metadata : [];
            $rawRole = strtolower((string) ($meta['role'] ?? 'Karyawan / Staf'));
            $parentInstitutionId = $memberRecord->user_id;
            if ($rawRole === 'admin') {
                $institutionRole = 'admin';
                $institutionPermissions = $allInstitutionPermissions;
            } else {
                $institutionRole = 'staff';
                $rawPerms = $meta['permissions'] ?? [];
                $institutionPermissions = is_array($rawPerms) ? array_values($rawPerms) : [];
            }
        }

        return response()->json([
            'status' => true,
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'uid' => $user->id,
                    'name' => $user->name,
                    'username' => $user->username,
                    'email' => $user->email,
                    'phone' => $user->phone,
                    'role' => $user->role->value,
                    'sub_role' => $user->sub_role,
                    'is_creator_approved' => (bool) $user->is_creator_approved,
                    'is_institution_sub_account' => $user->isInstitutionSubAccount(),
                    'permissions' => config('permissions.' . $user->role->value, []),
                    'institution_role' => $institutionRole,
                    'institution_permissions' => $institutionPermissions,
                    'parent_institution_id' => $parentInstitutionId,
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

        if ($provider === 'google') {
            if (!UsersApiClient::isEnabled()) {
                return response()->json([
                    'status' => false,
                    'message' => 'Layanan autentikasi sedang tidak dapat dijangkau. Silakan coba beberapa saat lagi.',
                ], 503);
            }

            $proxyResult = UsersApiClient::socialLogin($idToken, 'google');
            if ($proxyResult['success']) {
                $userApiData = $proxyResult['data']['user'] ?? [];
                $userApiData['is_email_verified'] = true;
                $isNewUser = (bool) ($proxyResult['data']['is_new_user'] ?? false);

                $user = UsersApiClient::syncShadowUser($userApiData);

                if ($isNewUser && !empty($user->email)) {
                    $tempPassword = Str::random(12);
                    $pwdSync = UsersApiClient::setUserPassword($user, $tempPassword);
                    if ($pwdSync['success']) {
                        SendSocialLoginPasswordJob::dispatch($user->email, $tempPassword);
                    }
                }

                AuthLog::create([
                    'user_id' => $user->id,
                    'action' => 'login_social_' . $provider,
                    'ip_address' => $request->ip(),
                    'user_agent' => substr((string) $request->userAgent(), 0, 255),
                ]);

                $token = Auth::guard('api')->login($user);
                $response = $this->respondWithToken($token, $user);
                $data = $response->getData(true);
                $data['data']['is_new_user'] = $isNewUser;
                $response->setData($data);

                return $response;
            }

            $status = ($proxyResult['status'] ?? 0) === 503
                ? 503
                : ($proxyResult['status'] >= 400 && $proxyResult['status'] < 500 ? $proxyResult['status'] : 401);

            return response()->json([
                'status' => false,
                'message' => $proxyResult['message'] ?? 'Login Google gagal.',
            ], $status);
        }

        return response()->json([
            'status' => false,
            'message' => 'Provider belum didukung.',
        ], 400);
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

    /**
     * Request a 6-digit password reset code sent asynchronously via Queue/Job.
     */
    public function forgotPassword(Request $request)
    {
        $request->validate([
            'email' => 'required|string|email',
        ], [
            'email.required' => 'Alamat email wajib diisi.',
            'email.email' => 'Format alamat email tidak valid.',
        ]);

        $result = $this->authService->requestPasswordReset((string) $request->email);

        return match ($result['outcome'] ?? 'error') {
            'success' => response()->json([
                'status' => true,
                'message' => 'Jika alamat email terdaftar, kode reset kata sandi telah dikirim ke email Anda.',
            ]),
            'rate_limited' => response()->json([
                'status' => false,
                'message' => 'Mohon tunggu sebentar sebelum meminta kode reset kata sandi baru.',
                'error_code' => 'password_reset_rate_limited',
            ], 429),
            'service_unavailable' => response()->json([
                'status' => false,
                'message' => 'Layanan autentikasi sedang tidak dapat dijangkau. Silakan coba beberapa saat lagi.',
            ], 503),
            default => response()->json([
                'status' => false,
                'message' => $result['message'] ?? 'Gagal memproses permintaan reset kata sandi.',
            ], $result['status'] ?? 422),
        };
    }

    /**
     * Confirm password reset with 6-digit OTP code and update credentials in users_api.
     */
    public function resetPassword(Request $request)
    {
        $request->validate([
            'email' => 'required|string|email',
            'code' => 'required|string|size:6|regex:/^[0-9]{6}$/',
            'password' => 'required|string|min:8|confirmed',
        ], [
            'email.required' => 'Alamat email wajib diisi.',
            'email.email' => 'Format alamat email tidak valid.',
            'code.required' => 'Kode reset kata sandi wajib diisi.',
            'code.size' => 'Kode reset kata sandi harus 6 digit angka.',
            'code.regex' => 'Kode reset kata sandi harus berupa 6 digit angka.',
            'password.required' => 'Kata sandi baru wajib diisi.',
            'password.min' => 'Kata sandi baru minimal 8 karakter.',
            'password.confirmed' => 'Konfirmasi kata sandi tidak cocok.',
        ]);

        $result = $this->authService->confirmPasswordReset(
            (string) $request->email,
            (string) $request->code,
            (string) $request->password,
            (string) $request->password_confirmation,
            (string) $request->ip(),
            (string) $request->userAgent()
        );

        if ($result['success']) {
            return response()->json([
                'status' => true,
                'message' => $result['message'] ?? 'Kata sandi berhasil diatur ulang. Silakan masuk dengan kata sandi baru Anda.',
            ]);
        }

        return response()->json([
            'status' => false,
            'message' => $result['message'] ?? 'Gagal mengatur ulang kata sandi.',
            'error_code' => $result['error_code'] ?? 'reset_password_failed',
            'errors' => $result['errors'] ?? null,
        ], $result['status'] ?? 422);
    }
}
