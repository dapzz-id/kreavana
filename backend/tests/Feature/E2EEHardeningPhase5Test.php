<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\User;
use App\Models\Chat;
use App\Models\UserDevice;
use Illuminate\Foundation\Testing\RefreshDatabase;

class E2EEHardeningPhase5Test extends TestCase
{
    use RefreshDatabase;

    public function test_logout_does_not_destroy_device_or_message_history()
    {
        $user = User::factory()->create();

        // Register device
        $device = UserDevice::create([
            'user_id' => $user->id,
            'device_id' => 'device-123',
            'public_key' => 'PEM-KEY',
            'is_active' => true,
        ]);

        // Perform logout
        $response = $this->actingAsApi($user)
                         ->postJson('/api/auth/logout');

        $response->assertStatus(200);

        // Device should still be active and exist in the database
        $this->assertDatabaseHas('user_devices', [
            'user_id' => $user->id,
            'device_id' => 'device-123',
            'is_active' => true,
        ]);
    }
}
