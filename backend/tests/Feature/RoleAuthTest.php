<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

class RoleAuthTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        // Create test users
        User::factory()->create([
            'name' => 'Test User',
            'username' => 'testuser',
            'email' => 'user@test.com',
            'password' => Hash::make('password123'),
            'role' => \App\Enums\RoleType::User
        ]);

        User::factory()->create([
            'name' => 'Test Creator',
            'username' => 'testcreator',
            'email' => 'creator@test.com',
            'password' => Hash::make('password123'),
            'role' => \App\Enums\RoleType::Creator
        ]);

        User::factory()->create([
            'name' => 'Test Admin',
            'username' => 'testadmin',
            'email' => 'admin@test.com',
            'password' => Hash::make('password123'),
            'role' => \App\Enums\RoleType::Admin
        ]);
    }

    public function test_user_login()
    {
        $response = $this->postJson('/api/auth/user/login', [
            'email' => 'user@test.com',
            'password' => 'password123'
        ]);

        $response->assertStatus(200);
        $response->assertJsonStructure(['data' => ['access_token', 'token_type']]);
    }

    public function test_creator_login_success()
    {
        $response = $this->postJson('/api/auth/creator/login', [
            'email' => 'creator@test.com',
            'password' => 'password123'
        ]);

        $response->assertStatus(200);
    }

    public function test_creator_login_fails_for_user()
    {
        $response = $this->postJson('/api/auth/creator/login', [
            'email' => 'user@test.com',
            'password' => 'password123'
        ]);

        $response->assertStatus(403);
    }

    public function test_admin_login_success()
    {
        $response = $this->postJson('/api/auth/admin/login', [
            'email' => 'admin@test.com',
            'password' => 'password123'
        ]);

        $response->assertStatus(200);
    }

    public function test_admin_login_fails_for_creator()
    {
        $response = $this->postJson('/api/auth/admin/login', [
            'email' => 'creator@test.com',
            'password' => 'password123'
        ]);

        $response->assertStatus(403);
    }
}
