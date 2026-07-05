<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CorsConfigurationTest extends TestCase
{
    use RefreshDatabase;

    public function test_auth_login_preflight_allows_localhost_origin_with_credentials(): void
    {
        $origin = 'http://localhost:62275';

        $response = $this->withHeaders([
            'Origin' => $origin,
            'Access-Control-Request-Method' => 'POST',
        ])->optionsJson('/api/auth/login');

        $response->assertSuccessful();
        $response->assertHeader('Access-Control-Allow-Origin', $origin);
        $response->assertHeader('Access-Control-Allow-Credentials', 'true');
    }
}