<?php

namespace App\Http\Middleware;

use App\Services\UsersApiClient;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Response;

class VerifyInternalServiceSignature
{
    /**
     * Handle incoming Machine-to-Machine (S2S) requests from users_api / IAM microservice.
     * Enforces HMAC-SHA256 signature verification and anti-replay window.
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

        // Verify client ID matches our IAM trust configuration
        if ($clientId !== UsersApiClient::getClientId()) {
            return response()->json([
                'status' => false,
                'message' => 'Unauthorized Client ID for internal service calls.',
            ], 403);
        }

        // Anti-replay check: strictly numeric UNIX epoch with max 300s clock drift
        if (!ctype_digit((string) $timestamp) || abs(time() - (int) $timestamp) > 300) {
            return response()->json([
                'status' => false,
                'message' => 'S2S request timestamp invalid, expired, or clock drift exceeded (max 300s).',
            ], 401);
        }

        $rawBody = $request->getContent();
        if (empty($rawBody) && !empty($request->all())) {
            $rawBody = json_encode($request->all(), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        }

        $secret = UsersApiClient::getClientSecret();
        if ($secret === '') {
            Log::error('VerifyInternalServiceSignature: USERS_API_CLIENT_SECRET is not configured.');
            return response()->json([
                'status' => false,
                'message' => 'Internal service authentication is not configured.',
            ], 503);
        }
        $expectedSig = hash_hmac('sha256', $clientId . '.' . $timestamp . '.' . $rawBody, $secret);

        $isValid = hash_equals($expectedSig, $signature);
        if (!$isValid && !empty($request->all())) {
            $altSig = hash_hmac('sha256', $clientId . '.' . $timestamp . '.' . json_encode($request->all(), JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE), $secret);
            $isValid = hash_equals($altSig, $signature);
        }

        if (!$isValid) {
            Log::warning('VerifyInternalServiceSignature: Invalid HMAC signature on internal endpoint', [
                'ip' => $request->ip(),
                'client_id' => $clientId,
                'timestamp' => $timestamp,
            ]);

            return response()->json([
                'status' => false,
                'message' => 'Invalid internal service HMAC cryptographic signature.',
            ], 403);
        }

        $correlationId = $request->header('X-Correlation-Id') ?: (string) \Illuminate\Support\Str::uuid();
        $request->merge(['correlation_id' => $correlationId]);

        $response = $next($request);
        $response->headers->set('X-Correlation-Id', $correlationId);

        return $response;
    }
}

