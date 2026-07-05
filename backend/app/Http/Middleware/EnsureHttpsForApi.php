<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureHttpsForApi
{
    public function handle(Request $request, Closure $next): Response
    {
        if ($request->is('api/*') && ! app()->environment(['local', 'testing']) && ! $request->isSecure()) {
            return response()->json([
                'status' => false,
                'message' => 'HTTPS required',
            ], 403);
        }

        return $next($request);
    }
}
