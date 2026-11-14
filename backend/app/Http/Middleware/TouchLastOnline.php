<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

class TouchLastOnline
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = auth('api')->user() ?? $request->user();
        if ($user) {
            // Update last_online if more than 10 seconds since last recorded online
            if (!$user->last_online || now()->diffInSeconds(\Carbon\Carbon::parse($user->last_online)) > 10) {
                $user->update(['last_online' => now()]);
            }
        }

        return $next($request);
    }
}
