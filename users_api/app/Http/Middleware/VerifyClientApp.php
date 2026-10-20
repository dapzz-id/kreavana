<?php

namespace App\Http\Middleware;

use App\Models\ClientApp;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class VerifyClientApp
{
    /**
     * Handle an incoming request. Ensures the requesting app is registered in Universal Identity.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $clientId = $request->header('X-Client-Id') ?? $request->input('client_id');

        if (!$clientId) {
            // Default to kreavana_app if header not sent for backwards compatibility
            $clientId = config('app.default_client_id', 'kreavana_app');
        }

        $app = ClientApp::where('client_id', $clientId)->where('is_active', true)->first();

        if (!$app && $clientId !== 'kreavana_app') {
            return response()->json([
                'status' => false,
                'message' => 'Invalid or inactive Client App ID.',
            ], 403);
        }

        $request->merge(['resolved_client_id' => $clientId]);

        return $next($request);
    }
}
