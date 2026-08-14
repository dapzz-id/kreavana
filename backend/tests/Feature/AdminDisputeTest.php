<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use Laravel\Sanctum\Sanctum;

class AdminDisputeTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_get_assigned_disputes()
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $token = auth()->login($admin);

        $response = $this->withHeader('Authorization', 'Bearer ' . $token)->getJson('/api/admin/assigned-disputes');

        $response->assertStatus(200)
                 ->assertJsonStructure([
                     'disputes' => []
                 ]);
    }

    public function test_non_admin_cannot_get_assigned_disputes()
    {
        $user = User::factory()->create(['role' => 'user']);
        $token = auth()->login($user);

        $response = $this->withHeader('Authorization', 'Bearer ' . $token)->getJson('/api/admin/assigned-disputes');

        $response->assertStatus(403);
    }
}
