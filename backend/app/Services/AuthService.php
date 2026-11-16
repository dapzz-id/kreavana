<?php

namespace App\Services;

use App\Contracts\AuthServiceInterface;
use App\Models\User;
use App\Models\AuthLog;
use App\Jobs\SendEmailVerificationJob;
use App\Jobs\SendPasswordResetJob;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;

class AuthService implements AuthServiceInterface
{
    public function register(array $data): User
    {
        if (!UsersApiClient::isEnabled()) {
            throw new \RuntimeException('Layanan Universal Identity belum dikonfigurasi pada sistem.');
        }

        $regResult = UsersApiClient::register($data);
        if ($regResult['success']) {
            $userApiData = $regResult['data']['user'] ?? [
                'username' => $data['username'],
                'email' => $data['email'],
                'full_name' => $data['name'],
            ];
            $userApiData['is_email_verified'] = $userApiData['is_email_verified'] ?? false;
            $user = UsersApiClient::syncShadowUser($userApiData);

            if ($user->email_verified_at === null) {
                $otp = $this->generateOtp();
                $user->update([
                    'email_verification_code_hash' => Hash::make($otp),
                    'email_verification_expires_at' => now()->addMinutes(15),
                    'email_verification_attempts' => 0,
                ]);
                SendEmailVerificationJob::dispatch($user->email, $otp);
            }

            return $user;
        }

        if (!empty($regResult['errors'])) {
            throw \Illuminate\Validation\ValidationException::withMessages(
                UsersApiClient::formatValidationErrors($regResult['errors'])
            );
        }

        throw new \Exception($regResult['message'] ?? 'Pendaftaran pada Universal Identity gagal.');
    }

    public function attemptLogin(array $credentials, string $ip, string $userAgent, ?\App\Enums\RoleType $requiredRole = null): ?string
    {
        $rawIdentifier = trim((string) ($credentials['email'] ?? $credentials['username'] ?? ''));
        $identifier = strtolower($rawIdentifier);
        $password = (string) ($credentials['password'] ?? '');

        // Institution sub-accounts are Kreavana-only accounts managed exclusively in backend
        $subAccountUser = $identifier !== ''
            ? User::whereHas('institutionSubAccount')
                ->where(function ($q) use ($identifier, $rawIdentifier) {
                    $q->whereRaw('LOWER(email) = ?', [$identifier])
                      ->orWhereRaw('LOWER(username) = ?', [$identifier]);
                    if ($rawIdentifier !== '') {
                        $q->orWhere('phone', $rawIdentifier);
                    }
                })
                ->with('institutionSubAccount')
                ->first()
            : null;

        if ($subAccountUser && $subAccountUser->institutionSubAccount) {
            $subAccount = $subAccountUser->institutionSubAccount;

            if (!$subAccount->is_active || !Hash::check($password, $subAccount->password_hash)) {
                AuthLog::create([
                    'user_id' => $subAccountUser->id,
                    'action' => 'login_sub_account_failed',
                    'ip_address' => $ip,
                    'user_agent' => substr($userAgent, 0, 255),
                ]);
                return null;
            }

            if ($subAccountUser->isSuspended()) {
                AuthLog::create([
                    'user_id' => $subAccountUser->id,
                    'action' => 'login_suspended',
                    'ip_address' => $ip,
                    'user_agent' => substr($userAgent, 0, 255),
                ]);
                return 'suspended';
            }

            if ($requiredRole && $subAccountUser->role !== $requiredRole) {
                AuthLog::create([
                    'user_id' => $subAccountUser->id,
                    'action' => 'login_forbidden',
                    'ip_address' => $ip,
                    'user_agent' => substr($userAgent, 0, 255),
                ]);
                return 'forbidden';
            }

            $token = Auth::guard('api')->login($subAccountUser);

            AuthLog::create([
                'user_id' => $subAccountUser->id,
                'action' => 'login_institution_sub_account',
                'ip_address' => $ip,
                'user_agent' => substr($userAgent, 0, 255),
            ]);

            return $token;
        }

        if (!UsersApiClient::isEnabled()) {
            \Illuminate\Support\Facades\Log::critical('AuthService::attemptLogin: Universal Identity service is disabled or unconfigured.');
            return 'service_unavailable';
        }

        $proxyResult = UsersApiClient::login($identifier, $password, [
            'ip' => $ip,
            'user_agent' => $userAgent,
        ]);

        if (!$proxyResult['success']) {
            if (($proxyResult['error_code'] ?? null) === 'email_not_verified') {
                $unverifiedUser = $proxyResult['data']['user'] ?? null;
                if (is_array($unverifiedUser) && !empty($unverifiedUser['email'])) {
                    UsersApiClient::syncShadowUser(array_merge($unverifiedUser, ['is_email_verified' => false]));
                }
                AuthLog::create([
                    'user_id' => null,
                    'action' => 'login_email_not_verified',
                    'ip_address' => $ip,
                    'user_agent' => substr($userAgent, 0, 255),
                ]);

                return 'email_not_verified';
            }

            AuthLog::create([
                'user_id' => null,
                'action' => 'login_failed',
                'ip_address' => $ip,
                'user_agent' => substr($userAgent, 0, 255),
            ]);

            if (($proxyResult['status'] ?? 0) === 503) {
                return 'service_unavailable';
            }

            return null;
        }

        $userApiData = $proxyResult['data']['user'] ?? [];
        if (!array_key_exists('is_email_verified', $userApiData)) {
            $userApiData['is_email_verified'] = true;
        }
        $user = UsersApiClient::syncShadowUser($userApiData);

        if ($user->isSuspended()) {
            AuthLog::create([
                'user_id' => $user->id,
                'action' => 'login_suspended',
                'ip_address' => $ip,
                'user_agent' => substr($userAgent, 0, 255),
            ]);
            return 'suspended';
        }

        if ($requiredRole && $user->role !== $requiredRole) {
            AuthLog::create([
                'user_id' => $user->id,
                'action' => 'login_forbidden',
                'ip_address' => $ip,
                'user_agent' => substr($userAgent, 0, 255),
            ]);
            return 'forbidden';
        }

        $token = Auth::guard('api')->login($user);

        AuthLog::create([
            'user_id' => $user->id,
            'action' => 'login_via_users_api',
            'ip_address' => $ip,
            'user_agent' => substr($userAgent, 0, 255),
        ]);

        return $token;
    }

    public function verifyEmail(string $email, string $code): string
    {
        $normalizedEmail = strtolower(trim($email));
        $verifiedUser = null;

        $result = DB::transaction(function () use ($normalizedEmail, $code, &$verifiedUser) {
            $user = User::whereRaw('LOWER(email) = ?', [$normalizedEmail])->lockForUpdate()->first();

            if (!$user) {
                // Generic error to prevent user enumeration
                return 'invalid_verification_code';
            }

            // Already verified — idempotent success
            if ($user->email_verified_at !== null) {
                $verifiedUser = $user;
                return 'success';
            }

            // No pending OTP
            if (!$user->email_verification_code_hash) {
                return 'invalid_verification_code';
            }

            // Expired
            if ($user->email_verification_expires_at && $user->email_verification_expires_at->isPast()) {
                return 'verification_code_expired';
            }

            // Too many attempts
            if ($user->email_verification_attempts >= 5) {
                return 'verification_attempts_exceeded';
            }

            // Check OTP
            if (!Hash::check($code, $user->email_verification_code_hash)) {
                $user->increment('email_verification_attempts');
                return 'invalid_verification_code';
            }

            // Success — verify and clear OTP fields
            $user->update([
                'email_verified_at' => now(),
                'email_verification_code_hash' => null,
                'email_verification_expires_at' => null,
                'email_verification_attempts' => 0,
            ]);

            $verifiedUser = $user;
            return 'success';
        });

        if ($result === 'success' && $verifiedUser instanceof User && UsersApiClient::isEnabled()) {
            UsersApiClient::markEmailVerified($verifiedUser);
        }

        return $result;
    }

    public function resendVerificationCode(string $email): string
    {
        $normalizedEmail = strtolower(trim($email));

        // Backend rate limit: 1 resend per 180 seconds (3 minutes) per email
        $rateLimitKey = 'email-verification-resend:' . sha1($normalizedEmail);
        if (RateLimiter::tooManyAttempts($rateLimitKey, 1)) {
            return 'verification_resend_rate_limited';
        }

        $user = User::whereRaw('LOWER(email) = ?', [$normalizedEmail])->first();

        if (!$user) {
            // Don't reveal whether email exists — consume rate limit and return success
            RateLimiter::hit($rateLimitKey, 180);
            return 'success';
        }

        // Already verified
        if ($user->email_verified_at !== null) {
            return 'email_already_verified';
        }

        $otp = $this->generateOtp();

        $user->update([
            'email_verification_code_hash' => Hash::make($otp),
            'email_verification_expires_at' => now()->addMinutes(15),
            'email_verification_attempts' => 0,
        ]);

        SendEmailVerificationJob::dispatch($user->email, $otp);

        RateLimiter::hit($rateLimitKey, 180);

        return 'success';
    }

    public function requestPasswordReset(string $email): array
    {
        $normalizedEmail = strtolower(trim($email));

        if (!UsersApiClient::isEnabled()) {
            return ['status' => 503, 'outcome' => 'service_unavailable'];
        }

        $rateLimitKey = 'password-reset-request:' . sha1($normalizedEmail);
        if (RateLimiter::tooManyAttempts($rateLimitKey, 1)) {
            return ['status' => 429, 'outcome' => 'rate_limited'];
        }

        $result = UsersApiClient::requestPasswordReset($normalizedEmail);
        if (!$result['success']) {
            if (($result['status'] ?? 0) === 503) {
                return ['status' => 503, 'outcome' => 'service_unavailable'];
            }
            return [
                'status' => $result['status'] ?? 422,
                'outcome' => 'error',
                'message' => $result['message'] ?? 'Gagal memproses permintaan reset kata sandi.',
            ];
        }

        $data = $result['data'] ?? [];
        if (($data['found'] ?? false) === true && !empty($data['otp']) && !empty($data['email'])) {
            SendPasswordResetJob::dispatch(
                (string) $data['email'],
                (string) $data['otp'],
                isset($data['name']) ? (string) $data['name'] : null
            );
        }

        RateLimiter::hit($rateLimitKey, 60);

        return ['status' => 200, 'outcome' => 'success'];
    }

    public function confirmPasswordReset(
        string $email,
        string $code,
        string $password,
        string $passwordConfirmation,
        string $ip = '',
        string $userAgent = ''
    ): array {
        if (!UsersApiClient::isEnabled()) {
            return [
                'success' => false,
                'status' => 503,
                'message' => 'Layanan autentikasi sedang tidak dapat dijangkau. Silakan coba beberapa saat lagi.',
                'error_code' => 'service_unavailable',
            ];
        }

        $normalizedEmail = strtolower(trim($email));
        $result = UsersApiClient::confirmPasswordReset($normalizedEmail, $code, $password, $passwordConfirmation);

        if ($result['success']) {
            RateLimiter::clear('password-reset-request:' . sha1($normalizedEmail));

            $shadow = User::whereRaw('LOWER(email) = ?', [$normalizedEmail])->first();
            if ($shadow) {
                if ($shadow->email_verified_at === null) {
                    $shadow->update(['email_verified_at' => now()]);
                }
                app(RefreshTokenRepository::class)->revokeAllForUser($shadow->id);

                AuthLog::create([
                    'user_id' => $shadow->id,
                    'action' => 'password_reset_via_email',
                    'ip_address' => $ip ?: '0.0.0.0',
                    'user_agent' => substr($userAgent, 0, 255),
                ]);
            }
        }

        return $result;
    }

    /**
     * Generate a cryptographically secure 6-digit OTP.
     */
    private function generateOtp(): string
    {
        return str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    }
}
