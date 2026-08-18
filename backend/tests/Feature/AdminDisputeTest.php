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
        $admin = User::factory()->create(['role' => \App\Enums\RoleType::Admin]);
        $response = $this->actingAsApi($admin)->getJson('/api/admin/assigned-disputes');

        $response->assertStatus(200)
                 ->assertJsonStructure([
                     'data' => []
                 ]);
    }

    public function test_non_admin_cannot_get_assigned_disputes()
    {
        $user = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $response = $this->actingAsApi($user)->getJson('/api/admin/assigned-disputes');

        $response->assertStatus(403);
    }
}
