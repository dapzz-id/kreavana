<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withCommands([
        __DIR__.'/../app/Console/Commands',
    ])
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->trustHosts(at: fn () => array_values(array_filter(array_merge(
            [
                '^(.+\.)?kreavana\.com$',
                '^(localhost|127\.0\.0\.1|\[::1\])$',
            ],
            array_map(
                static fn (string $h) => '^(.+\.)?' . preg_quote(trim($h)) . '$',
                array_filter(explode(',', (string) env('TRUSTED_HOSTS', '')))
            )
        ))));

        $middleware->prepend(\App\Http\Middleware\EnforceJsonSecurity::class);
        $middleware->append(\App\Http\Middleware\SecurityHeaders::class);

        $middleware->alias([
            'client.app' => \App\Http\Middleware\VerifyClientApp::class,
            'auth.jwt' => \App\Http\Middleware\AuthenticateJwt::class,
            'internal.s2s' => \App\Http\Middleware\VerifyInternalServiceSignature::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => true,
        );

        $exceptions->render(function (\Illuminate\Auth\AuthenticationException $e, Request $request) {
            return response()->json([
                'status' => false,
                'message' => 'Unauthenticated or invalid token'
            ], 401);
        });

        $exceptions->render(function (\Throwable $e, Request $request) {
            if ($e instanceof \Illuminate\Validation\ValidationException) {
                return response()->json([
                    'status' => false,
                    'message' => 'Validasi gagal.',
                    'errors' => $e->errors(),
                ], 422);
            }

            if ($e instanceof \Symfony\Component\HttpKernel\Exception\HttpExceptionInterface) {
                return response()->json([
                    'status' => false,
                    'message' => $e->getMessage() ?: 'HTTP Error',
                ], $e->getStatusCode());
            }

            $debugMessage = env('APP_DEBUG') ? $e->getMessage() : null;

            return response()->json([
                'status' => false,
                'message' => 'Terjadi kesalahan pada layanan Universal Identity.',
                'debug' => $debugMessage,
            ], 500);
        });
    })->create();
