<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        channels: __DIR__.'/../routes/channels.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->api(append: [
            \App\Http\Middleware\ApiPerformanceBudget::class,
            \App\Http\Middleware\EnsureHttpsForApi::class,
            \App\Http\Middleware\ValidateJti::class,
            \App\Http\Middleware\TouchLastOnline::class,
        ]);
        
        $middleware->alias([
            'role' => \App\Http\Middleware\RoleMiddleware::class,
            'permission' => \App\Http\Middleware\PermissionMiddleware::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*'),
        );
        $exceptions->render(function (\Illuminate\Auth\AuthenticationException $e, Request $request) {
            if ($request->is('api/*')) {
                return response()->json([
                    'status' => false,
                    'message' => 'Unauthorized'
                ], 401);
            }
        });

        // Tangkap exception umum dan DB exception agar tidak bocor
        $exceptions->render(function (\Throwable $e, Request $request) {
            if ($request->is('api/*')) {
                // Biarkan error validasi lewat seperti biasa
                if ($e instanceof \Illuminate\Validation\ValidationException) {
                    return null; 
                }
                
                return response()->json([
                    'status' => false,
                    'message' => 'Terjadi kesalahan internal pada server.',
                    // Optional: hapus baris di bawah jika tidak ingin error debug sama sekali
                    // 'debug' => env('APP_DEBUG') ? $e->getMessage() : null,
                ], 500);
            }
        });
    })->create();
