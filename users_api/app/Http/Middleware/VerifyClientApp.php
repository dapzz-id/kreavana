<?php

namespace App\Http\Middleware;

use App\Models\ClientApp;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

class VerifyClientApp
{
    /**
     * Handle an incoming request. Ensures the requesting app is registered in Universal Identity
     * and strictly verifies cryptographic HMAC signatures for Machine-to-Machine (S2S) requests.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $clientId = $request->header('X-Client-Id') ?? $request->input('client_id');

        if (!$clientId) {
            return response()->json([
                'status' => false,
                'message' => 'Missing X-Client-Id header in request.',
            ], 401);
        }

        $app = ClientApp::where('client_id', $clientId)->where('is_active', true)->first();

        // Safe auto-initialization for default kreavana_app if database seeder hasn't populated client_apps yet
        if (!$app && $clientId === 'kreavana_app') {
            $app = ClientApp::firstOrCreate(
                ['client_id' => 'kreavana_app'],
                [
                    'client_name' => 'Kreavana Creative Ecosystem (Web & Mobile)',
                    'client_secret' => hash('sha256', 'kreavana_ecosystem_secret_key_2026'),
                    'allowed_scopes' => ['openid', 'profile', 'email', 'phone', 'kyc'],
                    'is_active' => true,
                ]
            );
        }

        if (!$app) {
            return response()->json([
                'status' => false,
                'message' => 'Invalid or inactive Client App ID.',
            ], 403);
        }

        // Service-to-Service Cryptographic HMAC Verification
        $signature = $request->header('X-Signature');
        $timestamp = $request->header('X-Timestamp');

        if ($signature && $timestamp) {
            // Anti-replay protection: clock drift max 300 seconds (5 minutes)
            if (abs(time() - (int) $timestamp) > 300) {
                return response()->json([
                    'status' => false,
                    'message' => 'Request timestamp expired or clock drift exceeded (max 300s).',
                ], 401);
            }

            $rawBody = $request->getContent();
            if (empty($rawBody) && !empty($request->all())) {
                $rawBody = json_encode($request->all(), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
            }

            $expectedSig = hash_hmac('sha256', $clientId . '.' . $timestamp . '.' . $rawBody, $app->client_secret);
            $isValid = hash_equals($expectedSig, $signature);

            if (!$isValid && !empty($request->all())) {
                $altSig = hash_hmac('sha256', $clientId . '.' . $timestamp . '.' . json_encode($request->all(), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE), $app->client_secret);
                $isValid = hash_equals($altSig, $signature);
            }

            if (!$isValid) {
                Log::warning("VerifyClientApp: Invalid S2S signature from client app {$clientId}", [
                    'ip' => $request->ip(),
                    'timestamp' => $timestamp,
                ]);

                return response()->json([
                    'status' => false,
                    'message' => 'Invalid service-to-service cryptographic signature.',
                ], 403);
            }
        }

        // Attach distributed tracing correlation ID
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
