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
        $admin = User::factory()->create(['role' => 'admin']);
        $token = auth()->login($admin);
        
        SystemLog::create([
            'action' => 'test_action',
            'title' => 'Test Log',
            'description' => 'Test Desc',
            'type' => 'info',
        ]);

        $response = $this->withHeader('Authorization', 'Bearer ' . $token)->getJson('/api/admin/system-logs');

        $response->assertStatus(200)
                 ->assertJsonStructure([
                     'logs' => [
                         '*' => ['id', 'action', 'title', 'type', 'created_at']
                     ]
                 ]);
    }

    public function test_non_admin_cannot_get_system_logs()
    {
        $user = User::factory()->create(['role' => 'user']);
        $token = auth()->login($user);

        $response = $this->withHeader('Authorization', 'Bearer ' . $token)->getJson('/api/admin/system-logs');

        $response->assertStatus(403);
    }
}
