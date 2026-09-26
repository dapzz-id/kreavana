<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use App\Models\SystemSetting;
use Symfony\Component\HttpFoundation\Response;

class CheckModuleEnabled
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next, string $module): Response
    {
        // Admin users can always access
        $user = $request->user();
        if ($user && ($user->role === 'admin' || (method_exists($user, 'hasRole') && $user->hasRole('admin')))) {
            return $next($request);
        }

        $isEnabled = SystemSetting::get($module, true);

        if (!$isEnabled) {
            return response()->json([
                'status' => false,
                'message' => 'Fitur ini sedang dinonaktifkan oleh administrator.',
                'code' => 'MODULE_DISABLED',
                'module' => $module,
            ], 403);
        }

        return $next($request);
    }
}
