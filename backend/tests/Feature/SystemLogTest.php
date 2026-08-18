<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use App\Models\SystemLog;
use Laravel\Sanctum\Sanctum;

class SystemLogTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_get_system_logs()
    {
        $admin = User::factory()->create(['role' => \App\Enums\RoleType::Admin]);
        $loginResponse = $this->postJson('/api/auth/admin/login', [
            'email' => $admin->email,
            'password' => 'password'
        ]);
        $token = $loginResponse->json('data.access_token');
        
        SystemLog::create([
            'action' => 'test_action',
            'title' => 'Test Log',
            'description' => 'Test Desc',
            'type' => 'info',
        ]);

        $response = $this->withHeader('Authorization', 'Bearer ' . $token)->getJson('/api/admin/system-logs');

        $response->assertStatus(200)
                 ->assertJsonStructure([
                     'data' => [
                         '*' => ['id', 'action', 'title', 'type', 'created_at']
                     ]
                 ]);
    }

    public function test_non_admin_cannot_get_system_logs()
    {
        $user = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $loginResponse = $this->postJson('/api/auth/user/login', [
            'email' => $user->email,
            'password' => 'password'
        ]);
        $token = $loginResponse->json('data.access_token');

        $response = $this->withHeader('Authorization', 'Bearer ' . $token)->getJson('/api/admin/system-logs');

        $response->assertStatus(403);
    }
}
