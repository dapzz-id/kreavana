<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\User;
use App\Models\Subscription;
use App\Enums\RoleType;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;

class AiSubscriptionGatingTest extends TestCase
{
    use RefreshDatabase;

    public function test_guest_cannot_access_ai_assistant()
    {
        $response = $this->postJson('/api/ai/message-assistant', [
            'mode' => 'chat',
            'message' => 'Halo Kreavana AI',
        ]);

        // Unauthenticated request must be rejected (401 from auth:api or 403 pro_subscription_required)
        $this->assertTrue(in_array($response->status(), [401, 403]));
    }

    public function test_user_on_free_or_basic_tier_is_denied_with_pro_subscription_required()
    {
        $user = User::factory()->create([
            'email' => 'freeuser@test.com',
            'password' => Hash::make('password123'),
            'role' => RoleType::User,
        ]);

        $loginResponse = $this->postJson('/api/auth/login', [
            'email' => 'freeuser@test.com',
            'password' => 'password123',
        ]);
        $token = $loginResponse->json('data.access_token');

        $response = $this->withHeaders([
            'Authorization' => "Bearer {$token}",
        ])->postJson('/api/ai/message-assistant', [
            'mode' => 'chat',
            'message' => 'Halo Kreavana AI',
        ]);

        $response->assertStatus(403)
            ->assertJsonPath('status', false)
            ->assertJsonPath('error_code', 'pro_subscription_required');
    }

    public function test_user_with_plus_or_pro_subscription_can_access_ai_assistant()
    {
        $user = User::factory()->create([
            'email' => 'prouser@test.com',
            'password' => Hash::make('password123'),
            'role' => RoleType::User,
        ]);

        Subscription::create([
            'user_id' => $user->id,
            'tier' => 'pro',
            'expires_at' => now()->addMonth(),
        ]);

        $loginResponse = $this->postJson('/api/auth/login', [
            'email' => 'prouser@test.com',
            'password' => 'password123',
        ]);
        $token = $loginResponse->json('data.access_token');

        $response = $this->withHeaders([
            'Authorization' => "Bearer {$token}",
        ])->postJson('/api/ai/message-assistant', [
            'mode' => 'chat',
            'message' => 'Rekomendasi photographer di Bandung',
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('status', true);
    }
}
