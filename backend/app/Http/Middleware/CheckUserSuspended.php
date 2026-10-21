<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CheckUserSuspended
{
    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user('api');

        if ($user && $user->isSuspended()) {
            $message = 'Akun Anda di Kreavana sedang ditangguhkan.';
            if ($user->suspended_until) {
                $message = 'Akun Anda di Kreavana sedang ditangguhkan hingga ' . $user->suspended_until->format('d M Y H:i') . '.';
            }

            return response()->json([
                'status' => false,
                'message' => $message,
                'data' => [
                    'is_suspended' => true,
                    'suspended_until' => $user->suspended_until?->toIso8601String(),
                    'reason' => $user->suspend_reason,
                ],
            ], 403);
        }

        return $next($request);
    }
}
