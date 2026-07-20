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
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
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
    }
}
