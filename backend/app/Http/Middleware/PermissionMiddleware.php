<?php

namespace App\Http\Middleware;

use Closure;
use App\Services\JtiService;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class PermissionMiddleware
{
    /**
     * Handle an incoming request.
     *
     * Validasi permission user dari JWT custom claims.
     * Menggunakan AND logic — semua permission yang diminta harus dimiliki.
     * Contoh: permission:manage_applications,manage_users
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     * @param  string  ...$permissions  Permission yang diperlukan (AND logic)
     */
    public function handle(Request $request, Closure $next, string ...$permissions): Response
    {
        $user = auth('api')->user();

        if (!$user) {
            return response()->json([
                'status' => false,
                'message' => 'Unauthorized',
            ], 401);
        }

        $payload = auth('api')->payload();
        $jti = $payload->get('jti');
        if (!$jti || !JtiService::exists($jti)) {
            return response()->json([
                'status' => false,
                'message' => 'Unauthorized',
            ], 401);
        }

        $tokenPermissions = $payload->get('permissions', []);

        if (!is_array($tokenPermissions)) {
            $tokenPermissions = [];
        }

        // AND logic: semua permission yang diminta harus ada
        foreach ($permissions as $permission) {
            if (!in_array($permission, $tokenPermissions)) {
                return response()->json([
                    'status' => false,
                    'message' => 'Forbidden',
                ], 403);
            }
        }

        return $next($request);
    }
}
