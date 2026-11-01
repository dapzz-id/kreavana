<?php

namespace App\Services;

use App\Models\ClientApp;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class BackchannelService
{
    /**
     * Broadcast session revocation to registered client applications.
     */
    public static function notifySessionRevocation(string $userId, ?string $email = null, ?string $reason = 'universal_logout'): void
    {
        $payload = [
            'user_id' => $userId,
            'email' => $email,
            'reason' => $reason,
        ];

        self::dispatchToKreavana('/api/internal/v1/sessions/revoke', $payload);
    }

    /**
     * Broadcast user suspension state to registered client applications.
     */
    public static function notifyUserSuspension(string $userId, ?string $email, bool $isSuspended, ?string $suspendedUntil = null, ?string $reason = null): void
    {
        $payload = [
            'user_id' => $userId,
            'email' => $email,
            'is_suspended' => $isSuspended,
            'suspended_until' => $suspendedUntil,
            'reason' => $reason,
        ];

        self::dispatchToKreavana('/api/internal/v1/users/suspend', $payload);
    }

    /**
     * Send authenticated S2S Machine-to-Machine POST request to Kreavana backend.
     */
    protected static function dispatchToKreavana(string $path, array $payload): void
    {
        $baseUrl = rtrim((string) env('KREAVANA_BACKEND_URL', 'https://dev.kreavana.com'), '/');
        $url = $baseUrl . $path;

        $clientId = 'kreavana_app';
        $clientApp = ClientApp::where('client_id', $clientId)->first();
        $secret = $clientApp?->client_secret ?? hash('sha256', 'kreavana_ecosystem_secret_key_2026');

        $timestamp = (string) time();
        $correlationId = (string) Str::uuid();
        $rawPayload = json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        $signature = hash_hmac('sha256', $clientId . '.' . $timestamp . '.' . $rawPayload, $secret);

        try {
            Http::withHeaders([
                'Accept' => 'application/json',
                'X-Client-Id' => $clientId,
                'X-Timestamp' => $timestamp,
                'X-Correlation-Id' => $correlationId,
                'X-Signature' => $signature,
            ])
            ->timeout(5)
            ->withoutVerifying() // Allows internal/dev environments without CA cert errors
            ->post($url, $payload);
        } catch (\Throwable $e) {
            // Log but do not block primary IAM transaction
            Log::warning('BackchannelService::dispatchToKreavana failed: ' . $e->getMessage(), [
                'url' => $url,
                'correlation_id' => $correlationId,
            ]);
        }
    }
}

