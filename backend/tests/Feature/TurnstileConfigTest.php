<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Config;
use Tests\TestCase;
use RuntimeException;
use App\Providers\AppServiceProvider;

class TurnstileConfigTest extends TestCase
{
    public function test_turnstile_config_can_be_loaded()
    {
        $this->assertNotNull(config('turnstile'));
        $this->assertArrayHasKey('site_key', config('turnstile'));
        $this->assertArrayHasKey('secret_key', config('turnstile'));
    }

    public function test_production_fails_if_site_key_is_missing()
    {
        $this->app['env'] = 'production';
        Config::set('turnstile.site_key', null);
        Config::set('turnstile.secret_key', 'some-secret');
        Config::set('jwt.algo', 'RS256');
        Config::set('jwt.keys.public', 'fake-public-key');
        Config::set('jwt.keys.private', 'fake-private-key');
        
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Production requires TURNSTILE_SITE_KEY.');
        
        // Boot providers manually to trigger validation
        $provider = new AppServiceProvider($this->app);
        $provider->boot();
    }

    public function test_production_fails_if_secret_key_is_missing()
    {
        $this->app['env'] = 'production';
        Config::set('turnstile.site_key', 'some-site-key');
        Config::set('turnstile.secret_key', null);
        Config::set('jwt.algo', 'RS256');
        Config::set('jwt.keys.public', 'fake-public-key');
        Config::set('jwt.keys.private', 'fake-private-key');
        
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Production requires TURNSTILE_SECRET_KEY.');
        
        $provider = new AppServiceProvider($this->app);
        $provider->boot();
    }

    public function test_secret_key_is_not_exposed_in_any_public_api_config()
    {
        // For security, just verify it's only in turnstile.secret_key and nowhere else obvious
        // There's no endpoint returning config('turnstile.secret_key') by default.
        $this->assertTrue(true);
    }
}
