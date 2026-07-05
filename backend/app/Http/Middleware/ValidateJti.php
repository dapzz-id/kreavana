<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Tymon\JWTAuth\Facades\JWTAuth;
use App\Services\JtiService;
use Exception;

class ValidateJti
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        try {
            if ($token = JWTAuth::getToken()) {
                $payload = JWTAuth::getPayload($token);
                $jti = $payload->get('jti');

                if (!$jti || !JtiService::exists($jti)) {
                    return response()->json([
                        'status' => false,
                        'message' => 'Unauthorized'
                    ], 401);
                }
            }
        } catch (Exception $e) {
            // Biarkan middleware auth yang sebenarnya (Tymon\JWTAuth) menangani invalid token format dll.
        }

        return $next($request);
    }
}
