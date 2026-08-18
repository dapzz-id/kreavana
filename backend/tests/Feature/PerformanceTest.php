<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

class PerformanceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        User::factory()->create([
            'name' => 'Test User',
            'username' => 'testuser',
            'email' => 'user@test.com',
            'password' => Hash::make('password123'),
            'role' => \App\Enums\RoleType::User
        ]);
    }

    public function test_normal_json_routes_have_latency_instrumentation()
    {
        $response = $this->postJson('/api/auth/user/login', [
            'email' => 'user@test.com',
            'password' => 'password123'
        ]);

        $response->assertStatus(200);
        $response->assertHeader('X-Response-Time-Ms');
        // We can't strictly assert < 250ms in a test environment reliably without flake,
        // but we assert the header is present and the middleware works.
        $this->assertTrue(is_numeric($response->headers->get('X-Response-Time-Ms')));
    }
}
