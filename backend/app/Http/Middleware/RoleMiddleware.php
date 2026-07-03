<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RoleMiddleware
{
    /**
     * Handle an incoming request.
     *
     * Validasi role user dari JWT custom claims.
     * Mendukung multiple roles (comma-separated), contoh: role:admin,creator
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     * @param  string  ...$roles  Role yang diizinkan (bisa lebih dari satu)
     */
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = auth('api')->user();

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthenticated.',
            ], 401);
        }

        // Ambil role dari JWT custom claims
        $payload = auth('api')->payload();
        $tokenRole = $payload->get('role');

        if (!$tokenRole) {
            return response()->json([
                'success' => false,
                'message' => 'Token tidak valid, silakan login ulang.',
            ], 401);
        }

        if (!in_array($tokenRole, $roles)) {
            return response()->json([
                'success' => false,
                'message' => 'Anda tidak memiliki akses untuk halaman ini.',
            ], 403);
        }

        return $next($request);
    }
}
