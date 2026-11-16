<?php

namespace App\Contracts;

use App\Models\User;

interface AuthServiceInterface
{
    /**
     * Register a new user.
     *
     * @param array $data
     * @return User
     */
    public function register(array $data): User;

    /**
     * Attempt to login.
     *
     * @param array $credentials
     * @param string $ip
     * @param string $userAgent
     * @param string|null $requiredRole
     * @return string|null (Token or null if failed, 'forbidden' if wrong role)
     */
    public function attemptLogin(array $credentials, string $ip, string $userAgent, ?\App\Enums\RoleType $requiredRole = null): ?string;

    /**
     * Verify email using OTP code.
     *
     * @param string $email
     * @param string $code
     * @return string 'success' | error identifier
     */
    public function verifyEmail(string $email, string $code): string;

    /**
     * Resend email verification code.
     *
     * @param string $email
     * @return string 'success' | error identifier
     */
    public function resendVerificationCode(string $email): string;

    /**
     * Request a 6-digit password reset code via email queue.
     *
     * @param string $email
     * @return array{status: int, outcome: string}
     */
    public function requestPasswordReset(string $email): array;

    /**
     * Confirm password reset with 6-digit OTP code via users_api.
     *
     * @param string $email
     * @param string $code
     * @param string $password
     * @param string $passwordConfirmation
     * @param string $ip
     * @param string $userAgent
     * @return array
     */
    public function confirmPasswordReset(
        string $email,
        string $code,
        string $password,
        string $passwordConfirmation,
        string $ip = '',
        string $userAgent = ''
    ): array;
}
