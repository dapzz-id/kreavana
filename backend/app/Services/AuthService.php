<?php

namespace App\Services;

use App\Contracts\AuthServiceInterface;
use App\Models\User;
use App\Models\AuthLog;
use App\Jobs\SendEmailVerificationJob;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;

class AuthService implements AuthServiceInterface
{
    public function register(array $data): User
    {
        return DB::transaction(function () use ($data) {
            $otp = $this->generateOtp();

            $user = User::create([
                'name' => $data['name'],
                'username' => $data['username'],
                'email' => $data['email'],
                'password' => Hash::make($data['password']),
                'role' => 'user',
                'is_creator_approved' => 0,
                'email_verification_code_hash' => Hash::make($otp),
                'email_verification_expires_at' => now()->addMinutes(15),
                'email_verification_attempts' => 0,
            ]);

            SendEmailVerificationJob::dispatch($data['email'], $otp);

            return $user;
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

        // Check email verification before granting access
        if ($user->email_verified_at === null) {
            Auth::guard('api')->logout();
            AuthLog::create([
                'user_id' => $user->id,
                'action' => 'login_email_not_verified',
                'ip_address' => $ip,
                'user_agent' => substr($userAgent, 0, 255)
            ]);
            return 'email_not_verified';
        }

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

    public function verifyEmail(string $email, string $code): string
    {
        return DB::transaction(function () use ($email, $code) {
            $user = User::where('email', $email)->lockForUpdate()->first();

            if (!$user) {
                // Generic error to prevent user enumeration
                return 'invalid_verification_code';
            }

            // Already verified — idempotent success
            if ($user->email_verified_at !== null) {
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

            return 'success';
        });
    }

    public function resendVerificationCode(string $email): string
    {
        // Backend rate limit: 1 resend per 180 seconds (3 minutes) per email
        $rateLimitKey = 'email-verification-resend:' . sha1(strtolower($email));
        if (RateLimiter::tooManyAttempts($rateLimitKey, 1)) {
            return 'verification_resend_rate_limited';
        }

        $user = User::where('email', $email)->first();

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

        SendEmailVerificationJob::dispatch($email, $otp);

        RateLimiter::hit($rateLimitKey, 180);

        return 'success';
    }

    /**
     * Generate a cryptographically secure 6-digit OTP.
     */
    private function generateOtp(): string
    {
        return str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    }
}
