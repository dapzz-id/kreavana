<?php

namespace App\Http\Middleware;

use Closure;
use App\Services\JtiService;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RoleMiddleware
{
    /**
     * Handle an incoming request.
     *
     * Supports two usage modes:
     *   1. Role-only:    middleware('role:admin')        → any admin
     *   2. Role+SubRole: middleware('role:creator:government') → creator with sub_role = government
     *
     * Multiple values are comma-separated per segment:
     *   middleware('role:creator:government,institution') → creator who is government OR institution
     *   middleware('role:admin,creator')                → admin OR creator (any sub_role)
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     * @param  string  ...$params  Role checks passed from route middleware definition
     */
    public function handle(Request $request, Closure $next, string ...$params): Response
    {
        $user = auth('api')->user();

        if (!$user) {
            return response()->json([
                'status'  => false,
                'message' => 'Unauthorized',
            ], 401);
        }

        $payload   = auth('api')->payload();
        $jti = $payload->get('jti');
        if (!$jti || !JtiService::exists($jti)) {
            return response()->json([
                'status' => false,
                'message' => 'Unauthorized',
            ], 401);
        }

        $tokenRole = $payload->get('role');

        if (!$tokenRole) {
            return response()->json([
                'status'  => false,
                'message' => 'Unauthorized',
            ], 401);
        }

        // Each $param is one allowed access rule, e.g. "creator:pemerintah" or "admin"
        foreach ($params as $param) {
            $segments = explode(':', $param);
            $allowedRole    = $segments[0];          // e.g. "creator"
            $allowedSubRoles = isset($segments[1])   // e.g. "government,institution"
                ? explode(',', $segments[1])
                : [];

            // Check role match
            if ($tokenRole !== $allowedRole) {
                continue; // try next param
            }

            // If no sub_role restriction → role match is sufficient
            if (empty($allowedSubRoles)) {
                return $next($request);
            }

            // Sub-role check: fetch from the authenticated user model (not JWT to avoid stale cache)
            $userSubRole = $user->sub_role;

            if ($userSubRole && in_array($userSubRole, $allowedSubRoles)) {
                return $next($request);
            }

            // Role matched but sub_role did not — deny immediately (no point checking other params)
            return response()->json([
                'status'  => false,
                'message' => 'Forbidden',
            ], 403);
        }

        // None of the params matched the user's role at all
        return response()->json([
            'status'  => false,
            'message' => 'Forbidden',
        ], 403);
    }
}
