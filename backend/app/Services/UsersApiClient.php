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
     * Build base pending HTTP request with default headers and SSL options.
     */
    protected static function httpClient(?string $token = null): \Illuminate\Http\Client\PendingRequest
    {
        $headers = [
            'Accept' => 'application/json',
            'X-Client-Id' => self::getClientId(),
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

        try {
            $payload = array_merge([
                'identifier' => $identifier,
                'password' => $password,
                'device_id' => $deviceInfo['device_id'] ?? null,
                'device_name' => $deviceInfo['device_name'] ?? null,
                'platform' => $deviceInfo['platform'] ?? 'web',
            ], $deviceInfo);

            $response = self::httpClient()->post($url, $payload);

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
                'errors' => $json['errors'] ?? null,
            ];
        } catch (\Throwable $e) {
            Log::error('UsersApiClient::login failed: ' . $e->getMessage(), ['url' => $url]);

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

            $response = self::httpClient()->post($url, $payload);

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
            Log::error('UsersApiClient::register failed: ' . $e->getMessage(), ['url' => $url]);

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

        try {
            $payload = array_merge([
                'provider' => $provider,
                'id_token' => $idToken,
                'device_id' => $deviceInfo['device_id'] ?? null,
                'device_name' => $deviceInfo['device_name'] ?? null,
                'platform' => $deviceInfo['platform'] ?? 'web',
            ], $deviceInfo);

            $response = self::httpClient()->post($url, $payload);

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
            Log::error('UsersApiClient::socialLogin failed: ' . $e->getMessage(), ['url' => $url]);

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

        try {
            $response = self::httpClient($token)->post($url, [
                'current_password' => $currentPassword,
                'new_password' => $newPassword,
            ]);

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
            Log::error('UsersApiClient::changePassword failed: ' . $e->getMessage(), ['url' => $url]);

            return [
                'success' => false,
                'status' => 503,
                'message' => 'Layanan Universal Identity sedang tidak dapat dijangkau.',
            ];
        }
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
        $email = $userApiData['email'] ?? null;
        $username = $userApiData['username'] ?? null;
        $fullName = $userApiData['full_name'] ?? $userApiData['display_name'] ?? $username ?? 'User';
        $avatarUrl = $userApiData['avatar_url'] ?? null;

        // Find existing user by ID or Email
        $user = null;
        if ($id) {
            $user = User::find($id);
        }
        if (!$user && $email) {
            $user = User::where('email', $email)->first();
        }
        if (!$user && $username) {
            $user = User::where('username', $username)->first();
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
            $user->avatar_url = $avatarUrl;
            $user->role = RoleType::User;
            $user->is_creator_approved = 0;
            $user->email_verified_at = now();
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
            if ($email && $user->email !== $email) {
                $user->email = $email;
                $dirty = true;
            }
            if ($user->email_verified_at === null) {
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
