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
    public function attemptLogin(array $credentials, string $ip, string $userAgent, ?string $requiredRole = null): ?string;
}
