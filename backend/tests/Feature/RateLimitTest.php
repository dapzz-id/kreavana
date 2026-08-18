<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;

class RateLimitTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        
        // Clear rate limiter for tests
        RateLimiter::clear('auth-login:127.0.0.1');

        User::create([
            'name' => 'Test User',
            'username' => 'testuser',
            'email' => 'ratelimit@test.com',
            'password' => Hash::make('password123'),
            'role' => \App\Enums\RoleType::User
        ]);
    }

    public function test_auth_rate_limiting_returns_generic_responses()
    {
        // Hit the login endpoint 5 times (the limit is 5 per minute)
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/auth/user/login', [
                'email' => 'ratelimit@test.com',
                'password' => 'wrongpassword'
            ]);
        }

        // 6th attempt should be rate limited
        $response = $this->postJson('/api/auth/user/login', [
            'email' => 'ratelimit@test.com',
            'password' => 'wrongpassword'
        ]);

        $response->assertStatus(429);
        $response->assertJson([
            'message' => 'Too Many Attempts.'
        ]);
    }
}
