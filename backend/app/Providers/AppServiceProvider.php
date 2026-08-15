<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use RuntimeException;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->bind(
            \App\Contracts\AuthServiceInterface::class,
            \App\Services\AuthService::class
        );
        $this->app->bind(
            \App\Contracts\DashboardServiceInterface::class,
            \App\Services\DashboardService::class
        );
        $this->app->bind(
            \App\Contracts\AiServiceInterface::class,
            \App\Services\AiService::class
        );
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        \Carbon\Carbon::setLocale(config('app.locale', 'id'));
        $this->validateAuthConfiguration();
        $this->configureRateLimiters();
    }

    private function validateAuthConfiguration(): void
    {
        if (! in_array(config('database.redis.client'), ['phpredis', 'predis'], true)) {
            throw new RuntimeException('Authentication requires REDIS_CLIENT=phpredis or REDIS_CLIENT=predis.');
        }

        if (! app()->environment('production')) {
            return;
        }

        if (config('jwt.algo') !== 'RS256') {
            throw new RuntimeException('Production JWT signing must use RS256.');
        }

        if (! config('jwt.keys.public') || ! config('jwt.keys.private')) {
            throw new RuntimeException('Production RS256 JWT keys are required.');
        }
    }

    private function configureRateLimiters(): void
    {
        RateLimiter::for('auth-login', function (Request $request) {
            $identifier = (string) $request->input('email', $request->input('username', 'anonymous'));

            return Limit::perMinute(5)->by('login:'.$request->ip().':'.sha1(strtolower($identifier)));
        });

        RateLimiter::for('auth-register', fn (Request $request) => Limit::perMinute(5)->by('register:'.$request->ip()));
        RateLimiter::for('auth-refresh', fn (Request $request) => Limit::perMinute(10)->by('refresh:'.$request->ip()));

        RateLimiter::for('auth-verify-email', function (Request $request) {
            $identifier = strtolower((string) $request->input('email', 'anonymous'));
            return Limit::perMinute(10)->by('verify-email:'.$request->ip().':'.sha1($identifier));
        });

        RateLimiter::for('auth-resend-verification', function (Request $request) {
            $identifier = strtolower((string) $request->input('email', 'anonymous'));
            return Limit::perMinute(2)->by('resend-verification:'.$request->ip().':'.sha1($identifier));
        });
    }
}
