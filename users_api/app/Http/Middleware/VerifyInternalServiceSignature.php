<?php

namespace App\Http\Middleware;

use App\Models\ClientApp;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

class VerifyInternalServiceSignature
{
    /**
     * Handle incoming Machine-to-Machine (S2S) requests from trusted internal services (e.g. backend).
     * Unlike VerifyClientApp, cryptographic HMAC signature and timestamp are strictly mandatory here.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $clientId = $request->header('X-Client-Id');
        $timestamp = $request->header('X-Timestamp');
        $signature = $request->header('X-Signature');

        if (!$clientId || !$timestamp || !$signature) {
            return response()->json([
                'status' => false,
                'message' => 'Missing required S2S authentication headers (X-Client-Id, X-Timestamp, X-Signature).',
            ], 401);
        }

        if (abs(time() - (int) $timestamp) > 300) {
            return response()->json([
                'status' => false,
                'message' => 'S2S request timestamp expired or clock drift exceeded (max 300s).',
            ], 401);
        }

        $app = ClientApp::where('client_id', $clientId)->where('is_active', true)->first();

        if (!$app && $clientId === 'kreavana_app') {
            $app = ClientApp::firstOrCreate(
                ['client_id' => 'kreavana_app'],
                [
                    'client_name' => 'Kreavana Creative Ecosystem (Web & Mobile)',
                    'client_secret' => hash('sha256', env('DEFAULT_CLIENT_SECRET', 'kreavana_ecosystem_secret_key_2026')),
                    'allowed_scopes' => ['openid', 'profile', 'email', 'phone', 'kyc'],
                    'is_active' => true,
                ]
            );
        }

        if (!$app) {
            return response()->json([
                'status' => false,
                'message' => 'Unauthorized or inactive Client App ID for internal service calls.',
            ], 403);
        }

        $rawBody = $request->getContent();
        if (empty($rawBody) && !empty($request->all())) {
            $rawBody = json_encode($request->all(), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        }

        $expectedSig = hash_hmac('sha256', $clientId . '.' . $timestamp . '.' . $rawBody, $app->client_secret);
        $isValid = hash_equals($expectedSig, $signature);

        if (!$isValid && !empty($rawBody)) {
            $decodedRaw = json_decode($rawBody, true);
            if (is_array($decodedRaw)) {
                $decodedSig = hash_hmac(
                    'sha256',
                    $clientId . '.' . $timestamp . '.' . json_encode($decodedRaw, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE),
                    $app->client_secret
                );
                $isValid = hash_equals($decodedSig, $signature);
            }
        }

        if (!$isValid && !empty($request->all())) {
            $altSig = hash_hmac('sha256', $clientId . '.' . $timestamp . '.' . json_encode($request->all(), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE), $app->client_secret);
            $isValid = hash_equals($altSig, $signature);
        }

        if (!$isValid) {
            Log::warning("VerifyInternalServiceSignature: Invalid S2S signature from client app {$clientId}", [
                'ip' => $request->ip(),
                'timestamp' => $timestamp,
            ]);

            return response()->json([
                'status' => false,
                'message' => 'Invalid internal service cryptographic HMAC signature.',
            ], 403);
        }

        $correlationId = $request->header('X-Correlation-Id') ?: (string) Str::uuid();
        $request->merge([
            'resolved_client_id' => $clientId,
            'correlation_id' => $correlationId,
        ]);

        $response = $next($request);
        $response->headers->set('X-Correlation-Id', $correlationId);

        return $response;
    }
}
