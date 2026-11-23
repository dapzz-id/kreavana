<?php

namespace App\Services;

use App\Enums\RoleType;
use App\Models\User;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class UsersApiClient
{
    /**
     * Check if the Universal Identity microservice proxy is enabled.
     */
    public static function isEnabled(): bool
    {
        return !empty(config('services.users_api.url'));
    }

    /**
     * Get the base URL of users_api.
     */
    public static function getBaseUrl(): string
    {
        return rtrim((string) config('services.users_api.url', 'https://auth-dev.kreavana.com'), '/');
    }

    /**
     * Get the configured Client ID for this application.
     */
    public static function getClientId(): string
    {
        return (string) config('services.users_api.client_id', 'kreavana_app');
    }

    /**
     * Get the configured Client Secret for this application (must come from .env, never hardcoded).
     */
    public static function getClientSecret(): string
    {
        return trim((string) config('services.users_api.client_secret', ''));
    }

    /**
     * Get timeout in seconds.
     */
    public static function getTimeout(): int
    {
        return (int) config('services.users_api.timeout', 10);
    }

    /**
     * Check whether SSL verification should be enabled.
     */
    public static function shouldVerifySsl(): bool
    {
        $configured = config('services.users_api.verify_ssl');
        if ($configured !== null) {
            return filter_var($configured, FILTER_VALIDATE_BOOLEAN);
        }

        // Default to true in production, false in local/testing environments (to support Windows/Laragon development)
        return app()->environment('production');
    }

    /**
     * Build base pending HTTP request with default headers, HMAC signature, and SSL options.
     */
    protected static function httpClient(?string $token = null, array $payload = [], ?string $correlationId = null): \Illuminate\Http\Client\PendingRequest
    {
        $clientId = self::getClientId();
        $secret = self::getClientSecret();
        if ($secret === '') {
            throw new \RuntimeException('USERS_API_CLIENT_SECRET is not configured.');
        }
        $timestamp = (string) time();
        $traceId = $correlationId ?: (string) \Illuminate\Support\Str::uuid();
        $rawPayload = !empty($payload) ? json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) : '';
        $signature = hash_hmac('sha256', $clientId . '.' . $timestamp . '.' . $rawPayload, $secret);

        $headers = [
            'Accept' => 'application/json',
            'X-Client-Id' => $clientId,
            'X-Timestamp' => $timestamp,
            'X-Correlation-Id' => $traceId,
            'X-Signature' => $signature,
        ];

        if ($token) {
            $headers['Authorization'] = 'Bearer ' . $token;
        }

        $request = Http::withHeaders($headers)->timeout(self::getTimeout());

        if (!self::shouldVerifySsl()) {
            $request = $request->withoutVerifying();
        }

        return $request;
    }

    /**
     * Proxy Universal Login to users_api.
     *
     * @param string $identifier Email or Username
     * @param string $password User password
     * @param array $deviceInfo Optional client/device details
     * @return array ['success' => bool, 'status' => int, 'message' => string, 'data' => ?array]
     */
    public static function login(string $identifier, string $password, array $deviceInfo = []): array
    {
        $url = self::getBaseUrl() . '/api/v1/auth/login';
        $correlationId = (string) \Illuminate\Support\Str::uuid();

        try {
            $payload = array_merge([
                'identifier' => $identifier,
                'password' => $password,
                'device_id' => $deviceInfo['device_id'] ?? null,
                'device_name' => $deviceInfo['device_name'] ?? null,
                'platform' => $deviceInfo['platform'] ?? 'web',
            ], $deviceInfo);

            $response = self::httpClient(null, $payload, $correlationId)->post($url, $payload);

            $statusCode = $response->status();
            $json = $response->json() ?? [];

            if ($response->successful() && !empty($json['data']['user'])) {
                return [
                    'success' => true,
                    'status' => $statusCode,
                    'message' => $json['message'] ?? 'Login universal berhasil.',
                    'data' => $json['data'],
                ];
            }

            return [
                'success' => false,
                'status' => $statusCode,
                'message' => $json['message'] ?? 'Kredensial tidak valid.',
                'error_code' => $json['error_code'] ?? null,
                'data' => $json['data'] ?? null,
                'errors' => $json['errors'] ?? null,
            ];
        } catch (\Throwable $e) {
            Log::error('UsersApiClient::login failed: ' . $e->getMessage(), [
                'url' => $url,
                'correlation_id' => $correlationId,
            ]);

            return [
                'success' => false,
                'status' => 503,
                'message' => 'Layanan Universal Identity sedang tidak dapat dijangkau.',
                'error' => env('APP_DEBUG') ? $e->getMessage() : null,
            ];
        }
    }

    /**
     * Proxy Universal Registration to users_api.
     */
    public static function register(array $data, array $deviceInfo = []): array
    {
        $url = self::getBaseUrl() . '/api/v1/auth/register';
        $correlationId = (string) \Illuminate\Support\Str::uuid();

        try {
            $payload = array_merge([
                'username' => $data['username'] ?? '',
                'email' => $data['email'] ?? '',
                'password' => $data['password'] ?? '',
                'full_name' => $data['name'] ?? $data['full_name'] ?? '',
                'device_id' => $deviceInfo['device_id'] ?? null,
                'device_name' => $deviceInfo['device_name'] ?? null,
                'platform' => $deviceInfo['platform'] ?? 'web',
            ], $deviceInfo);

            $response = self::httpClient(null, $payload, $correlationId)->post($url, $payload);

            $statusCode = $response->status();
            $json = $response->json() ?? [];

            if ($response->successful()) {
                return [
                    'success' => true,
                    'status' => $statusCode,
                    'message' => $json['message'] ?? 'Registrasi berhasil.',
                    'data' => $json['data'] ?? [],
                ];
            }

            return [
                'success' => false,
                'status' => $statusCode,
                'message' => $json['message'] ?? 'Registrasi gagal.',
                'errors' => $json['errors'] ?? null,
            ];
        } catch (\Throwable $e) {
            Log::error('UsersApiClient::register failed: ' . $e->getMessage(), [
                'url' => $url,
                'correlation_id' => $correlationId,
            ]);

            return [
                'success' => false,
                'status' => 503,
                'message' => 'Layanan Universal Identity sedang tidak dapat dijangkau.',
                'error' => env('APP_DEBUG') ? $e->getMessage() : null,
            ];
        }
    }

    /**
     * Proxy Google / Social Login to users_api.
     */
    public static function socialLogin(string $idToken, string $provider = 'google', array $deviceInfo = []): array
    {
        $url = self::getBaseUrl() . '/api/v1/auth/social';
        $correlationId = (string) \Illuminate\Support\Str::uuid();

        try {
            $payload = array_merge([
                'provider' => $provider,
                'id_token' => $idToken,
                'device_id' => $deviceInfo['device_id'] ?? null,
                'device_name' => $deviceInfo['device_name'] ?? null,
                'platform' => $deviceInfo['platform'] ?? 'web',
            ], $deviceInfo);

            $response = self::httpClient(null, $payload, $correlationId)->post($url, $payload);

            $statusCode = $response->status();
            $json = $response->json() ?? [];

            if ($response->successful() && !empty($json['data']['user'])) {
                return [
                    'success' => true,
                    'status' => $statusCode,
                    'message' => $json['message'] ?? 'Login sosial berhasil.',
                    'data' => $json['data'],
                ];
            }

            return [
                'success' => false,
                'status' => $statusCode,
                'message' => $json['message'] ?? 'Login sosial gagal.',
                'errors' => $json['errors'] ?? null,
            ];
        } catch (\Throwable $e) {
            Log::error('UsersApiClient::socialLogin failed: ' . $e->getMessage(), [
                'url' => $url,
                'correlation_id' => $correlationId,
            ]);

            return [
                'success' => false,
                'status' => 503,
                'message' => 'Layanan Universal Identity sedang tidak dapat dijangkau.',
                'error' => env('APP_DEBUG') ? $e->getMessage() : null,
            ];
        }
    }

    /**
     * Proxy Change Password to users_api.
     */
    public static function changePassword(User $user, string $currentPassword, string $newPassword): array
    {
        $loginResult = self::login($user->email ?? $user->username, $currentPassword);
        if (!$loginResult['success']) {
            return [
                'success' => false,
                'status' => 422,
                'message' => 'Kata sandi saat ini salah.',
            ];
        }

        $token = $loginResult['data']['tokens']['access_token'] ?? null;
        if (!$token) {
            return [
                'success' => false,
                'status' => 500,
                'message' => 'Gagal mengotentikasi sesi perubahan kata sandi.',
            ];
        }

        $url = self::getBaseUrl() . '/api/v1/profile/change-password';
        $payload = [
            'current_password' => $currentPassword,
            'new_password' => $newPassword,
        ];
        $correlationId = (string) \Illuminate\Support\Str::uuid();

        try {
            $response = self::httpClient($token, $payload, $correlationId)->post($url, $payload);

            $json = $response->json() ?? [];
            if ($response->successful()) {
                return [
                    'success' => true,
                    'status' => 200,
                    'message' => $json['message'] ?? 'Kata sandi berhasil diperbarui.',
                ];
            }

            return [
                'success' => false,
                'status' => $response->status(),
                'message' => $json['message'] ?? 'Gagal memperbarui kata sandi.',
                'errors' => $json['errors'] ?? null,
            ];
        } catch (\Throwable $e) {
            Log::error('UsersApiClient::changePassword failed: ' . $e->getMessage(), [
                'url' => $url,
                'correlation_id' => $correlationId,
            ]);

            return [
                'success' => false,
                'status' => 503,
                'message' => 'Layanan Universal Identity sedang tidak dapat dijangkau.',
            ];
        }
    }

    /**
     * Synchronize profile identity fields to users_api via authenticated S2S endpoint.
     *
     * @param User $user
     * @param array $identityUpdates Normalized fields (name, username, email, phone, avatar_url)
     * @param array $lookupContext Original identifiers captured prior to local mutation
     * @return array ['success' => bool, 'status' => int, 'message' => string, 'data' => ?array, 'errors' => ?array]
     */
    public static function updateProfile(User $user, array $identityUpdates, array $lookupContext = []): array
    {
        $url = self::getBaseUrl() . '/api/internal/v1/users/profile';
        $correlationId = (string) \Illuminate\Support\Str::uuid();

        $payload = [
            'user_id' => $lookupContext['user_id'] ?? $user->id,
            'current_email' => $lookupContext['current_email'] ?? $user->email,
            'current_username' => $lookupContext['current_username'] ?? $user->username,
        ];

        if (array_key_exists('name', $identityUpdates)) {
            $payload['full_name'] = $identityUpdates['name'];
            $payload['display_name'] = $identityUpdates['name'];
        }
        if (array_key_exists('username', $identityUpdates)) {
            $payload['username'] = $identityUpdates['username'];
        }
        if (array_key_exists('email', $identityUpdates)) {
            $payload['email'] = $identityUpdates['email'];
        }
        if (array_key_exists('phone', $identityUpdates)) {
            $payload['phone'] = $identityUpdates['phone'];
        }
        if (array_key_exists('avatar_url', $identityUpdates)) {
            $payload['avatar_url'] = $identityUpdates['avatar_url'];
        }

        try {
            $response = self::httpClient(null, $payload, $correlationId)->put($url, $payload);

            $statusCode = $response->status();
            $json = $response->json() ?? [];

            if ($response->successful()) {
                return [
                    'success' => true,
                    'status' => $statusCode,
                    'message' => $json['message'] ?? 'Profil universal berhasil diperbarui.',
                    'data' => $json['data'] ?? [],
                ];
            }

            $errors = is_array($json['errors'] ?? null)
                ? self::formatValidationErrors($json['errors'])
                : null;

            $message = $json['message'] ?? 'Gagal memperbarui identitas pada Universal Identity.';
            if (!empty($errors)) {
                $firstGroup = reset($errors);
                $firstMsg = is_array($firstGroup) ? reset($firstGroup) : (string) $firstGroup;
                if (is_string($firstMsg) && $firstMsg !== '') {
                    $message = $firstMsg;
                }
            }

            return [
                'success' => false,
                'status' => $statusCode,
                'message' => $message,
                'errors' => $errors,
            ];
        } catch (\Throwable $e) {
            Log::error('UsersApiClient::updateProfile failed: ' . $e->getMessage(), [
                'url' => $url,
                'correlation_id' => $correlationId,
            ]);

            return [
                'success' => false,
                'status' => 503,
                'message' => 'Layanan Universal Identity sedang tidak dapat dijangkau.',
                'error' => env('APP_DEBUG') ? $e->getMessage() : null,
            ];
        }
    }

    /**
     * Synchronize email verification status to users_api via authenticated S2S endpoint.
     */
    public static function markEmailVerified(User $user): array
    {
        return self::postInternal('/api/internal/v1/users/verify-email', [
            'user_id' => $user->id,
            'current_email' => $user->email,
            'current_username' => $user->username,
        ], 'UsersApiClient::markEmailVerified');
    }

    /**
     * Synchronize or set password in users_api UserCredential via authenticated S2S endpoint.
     */
    public static function setUserPassword(User $user, string $password): array
    {
        return self::postInternal('/api/internal/v1/users/set-password', [
            'user_id' => $user->id,
            'current_email' => $user->email,
            'current_username' => $user->username,
            'password' => $password,
        ], 'UsersApiClient::setUserPassword');
    }

    /**
     * Request a 6-digit password reset OTP from users_api via authenticated S2S endpoint.
     */
    public static function requestPasswordReset(string $email): array
    {
        return self::postInternal('/api/internal/v1/auth/password-reset/request', [
            'email' => strtolower(trim($email)),
        ], 'UsersApiClient::requestPasswordReset');
    }

    /**
     * Confirm 6-digit password reset OTP and persist new password in users_api.
     */
    public static function confirmPasswordReset(
        string $email,
        string $code,
        string $password,
        string $passwordConfirmation
    ): array {
        return self::postInternal('/api/internal/v1/auth/password-reset/confirm', [
            'email' => strtolower(trim($email)),
            'code' => $code,
            'password' => $password,
            'password_confirmation' => $passwordConfirmation,
        ], 'UsersApiClient::confirmPasswordReset');
    }

    /**
     * Shared authenticated S2S POST caller to users_api.
     */
    protected static function postInternal(string $path, array $payload, string $logLabel): array
    {
        $url = self::getBaseUrl() . $path;
        $correlationId = (string) \Illuminate\Support\Str::uuid();

        try {
            $response = self::httpClient(null, $payload, $correlationId)->post($url, $payload);
            $statusCode = $response->status();
            $json = $response->json() ?? [];

            if ($response->successful()) {
                return [
                    'success' => true,
                    'status' => $statusCode,
                    'message' => $json['message'] ?? 'Operasi berhasil.',
                    'data' => $json['data'] ?? [],
                ];
            }

            $errors = is_array($json['errors'] ?? null)
                ? self::formatValidationErrors($json['errors'])
                : null;

            return [
                'success' => false,
                'status' => $statusCode,
                'message' => $json['message'] ?? 'Permintaan ke Universal Identity gagal.',
                'error_code' => $json['error_code'] ?? null,
                'errors' => $errors,
                'data' => $json['data'] ?? null,
            ];
        } catch (\Throwable $e) {
            Log::error($logLabel . ' failed: ' . $e->getMessage(), [
                'url' => $url,
                'correlation_id' => $correlationId,
            ]);

            return [
                'success' => false,
                'status' => 503,
                'message' => 'Layanan Universal Identity sedang tidak dapat dijangkau.',
                'error_code' => 'service_unavailable',
                'error' => env('APP_DEBUG') ? $e->getMessage() : null,
            ];
        }
    }

    /**
     * Format raw validation errors returned by users_api into clear Indonesian messages.
     */
    public static function formatValidationErrors(array $errors): array
    {
        $formatted = [];
        foreach ($errors as $field => $messages) {
            $formatted[$field] = array_map(function ($msg) use ($field) {
                $strMsg = (string) $msg;
                if (str_contains($strMsg, 'validation.unique') || str_contains($strMsg, 'already been taken')) {
                    if ($field === 'email') {
                        return 'Alamat email ini sudah terdaftar. Silakan gunakan email lain atau masuk ke akun Anda.';
                    }
                    if ($field === 'phone') {
                        return 'Nomor telepon ini sudah digunakan oleh akun lain.';
                    }
                    return 'Username ini sudah digunakan. Silakan pilih username lain.';
                }
                if (str_contains($strMsg, 'validation.required')) {
                    $label = match ($field) {
                        'full_name', 'name' => 'Nama lengkap',
                        'phone' => 'Nomor telepon',
                        default => ucfirst($field),
                    };
                    return $label . ' wajib diisi.';
                }
                if (str_contains($strMsg, 'validation.min')) {
                    if ($field === 'password') {
                        return 'Kata sandi minimal 8 karakter.';
                    }
                    $label = match ($field) {
                        'full_name', 'name' => 'Nama lengkap',
                        default => ucfirst($field),
                    };
                    return $label . ' terlalu pendek.';
                }
                if (str_contains($strMsg, 'validation.email')) {
                    return 'Format alamat email tidak valid.';
                }
                return $strMsg;
            }, (array) $messages);
        }

        return $formatted;
    }

    /**
     * Synchronize or create shadow User record in backend database.
     * Keeps business domain properties (balance, role, creator approval) intact.
     *
     * @param array $userApiData User data payload returned by users_api
     * @return User
     */
    public static function syncShadowUser(array $userApiData): User
    {
        $id = $userApiData['id'] ?? null;
        $rawEmail = isset($userApiData['email']) ? strtolower(trim((string) $userApiData['email'])) : null;
        $email = $rawEmail !== '' ? $rawEmail : null;
        $rawUsername = isset($userApiData['username']) ? strtolower(trim((string) $userApiData['username'])) : null;
        $username = $rawUsername !== '' ? $rawUsername : null;
        $fullName = $userApiData['full_name'] ?? $userApiData['display_name'] ?? $username ?? 'User';
        $avatarUrl = $userApiData['avatar_url'] ?? null;
        $hasPhone = array_key_exists('phone', $userApiData);
        $phone = $hasPhone ? (trim((string) ($userApiData['phone'] ?? '')) ?: null) : null;

        $hasEmailVerifiedFlag = array_key_exists('is_email_verified', $userApiData);
        $isEmailVerified = $hasEmailVerifiedFlag
            ? filter_var($userApiData['is_email_verified'], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE)
            : null;

        // Find existing user by ID, Email, or Username (case-insensitive)
        $user = null;
        if ($id) {
            $user = User::find($id);
        }
        if (!$user && $email) {
            $user = User::whereRaw('LOWER(email) = ?', [$email])->first();
        }
        if (!$user && $username) {
            $user = User::whereRaw('LOWER(username) = ?', [$username])->first();
        }

        if (!$user) {
            // Create new shadow user
            $user = new User();
            if ($id) {
                $user->id = $id;
            }
            $user->name = $fullName;
            $user->username = $username ?: 'user_' . substr(md5($email ?? uniqid()), 0, 8);
            $user->email = $email;
            if ($hasPhone) {
                $user->phone = $phone;
            }
            $user->avatar_url = $avatarUrl;
            $user->role = RoleType::User;
            $user->is_creator_approved = 0;
            $user->email_verified_at = ($isEmailVerified === false) ? null : now();
            $user->balance = 0.00;
            $user->save();
        } else {
            // Update shadow user with latest IAM identity data
            $dirty = false;
            if ($fullName && $user->name !== $fullName) {
                $user->name = $fullName;
                $dirty = true;
            }
            if ($avatarUrl && $user->avatar_url !== $avatarUrl) {
                $user->avatar_url = $avatarUrl;
                $dirty = true;
            }
            if ($email && strtolower((string) $user->email) !== $email) {
                $emailConflict = User::whereRaw('LOWER(email) = ?', [$email])
                    ->where('id', '!=', $user->id)
                    ->exists();
                if (!$emailConflict) {
                    $user->email = $email;
                    $dirty = true;
                }
            }
            if ($username && strtolower((string) $user->username) !== $username) {
                $usernameConflict = User::whereRaw('LOWER(username) = ?', [$username])
                    ->where('id', '!=', $user->id)
                    ->exists();
                if (!$usernameConflict) {
                    $user->username = $username;
                    $dirty = true;
                }
            }
            if ($hasPhone && $user->phone !== $phone) {
                $user->phone = $phone;
                $dirty = true;
            }
            if ($isEmailVerified === false) {
                if ($user->email_verified_at !== null) {
                    $user->email_verified_at = null;
                    $dirty = true;
                }
            } elseif ($user->email_verified_at === null) {
                $user->email_verified_at = now();
                $dirty = true;
            }
            if ($dirty) {
                $user->save();
            }
        }

        return $user;
    }
}
