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
        if (Auth::check()) {
            $user = Auth::user();
            // Update last_online every 5 seconds for real-time presence
            if (!$user->last_online || now()->diffInSeconds(\Carbon\Carbon::parse($user->last_online)) > 5) {
                $user->update(['last_online' => now()]);
            }
        }

        return $next($request);
    }
}
