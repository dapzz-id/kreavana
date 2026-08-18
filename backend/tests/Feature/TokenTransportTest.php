<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class TokenTransportTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        User::factory()->create([
            'name' => 'Test',
            'username' => 'test',
            'email' => 'test@test.com',
            'password' => Hash::make('password123'),
            'role' => \App\Enums\RoleType::User,
        ]);
    }

    public function test_web_transport_uses_the_configured_secure_cookie(): void
    {
        $response = $this->postJson('/api/auth/login', [
            'email' => 'test@test.com',
            'password' => 'password123',
        ]);

        $response->assertOk();
        $response->assertJsonMissingPath('data.refresh_token');
        $response->assertCookie(config('auth_tokens.refresh.cookie'));
    }

    public function test_mobile_transport_returns_refresh_token_in_json(): void
    {
        $response = $this->withHeaders(['X-Client-Type' => 'mobile'])
            ->postJson('/api/auth/login', [
                'email' => 'test@test.com',
                'password' => 'password123',
            ]);

        $response->assertOk();
        $response->assertJsonPath('data.refresh_token', fn ($val) => is_string($val) && $val !== '');
        
        // Assert cookie is NOT sent
        $cookies = $response->headers->getCookies();
        $hasRefreshCookie = false;
        foreach ($cookies as $cookie) {
            if ($cookie->getName() === config('auth_tokens.refresh.cookie')) {
                $hasRefreshCookie = true;
            }
        }
        $this->assertFalse($hasRefreshCookie);
    }

    public function test_x_client_type_cannot_bypass_authentication_or_authorization(): void
    {
        $response = $this->withHeaders(['X-Client-Type' => 'mobile'])
            ->postJson('/api/auth/login', [
                'email' => 'test@test.com',
                'password' => 'wrongpassword',
            ]);

        $response->assertUnauthorized();
    }
}
