<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\WithFaker;
use Tests\TestCase;
use App\Models\User;
use App\Models\Chat;
use App\Models\UserDevice;
use Tymon\JWTAuth\Facades\JWTAuth;

class E2EEMessagePhase2Test extends TestCase
{
    use RefreshDatabase;

    private function getAuthHeaders(User $user)
    {
        $token = JWTAuth::fromUser($user);
        $payload = JWTAuth::setToken($token)->getPayload();
        $jti = $payload->get('jti');
        if ($jti) {
            \App\Services\JtiService::store($jti, 3600);
        }
        return ['Authorization' => "Bearer $token"];
    }

    public function test_legacy_plaintext_message_still_works()
    {
        $user1 = User::factory()->create();
        $user2 = User::factory()->create();
        $chat = Chat::create(['type' => 'personal', 'created_by' => $user1->id]);
        $chat->participants()->create(['user_id' => $user1->id, 'status' => 'joined']);
        $chat->participants()->create(['user_id' => $user2->id, 'status' => 'joined']);

        $response = $this->withHeaders($this->getAuthHeaders($user1))->postJson("/api/chats/{$chat->id}/messages", [
            'type' => 'text',
            'message' => 'Halo ini plaintext',
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseHas('messages', [
            'message' => 'Halo ini plaintext',
            'encryption_version' => 0,
        ]);
    }

    public function test_version_1_requires_ciphertext_and_envelope()
    {
        $user1 = User::factory()->create();
        $chat = Chat::create(['type' => 'personal', 'created_by' => $user1->id]);
        $chat->participants()->create(['user_id' => $user1->id, 'status' => 'joined']);

        $response = $this->withHeaders($this->getAuthHeaders($user1))->postJson("/api/chats/{$chat->id}/messages", [
            'type' => 'text',
            'encryption_version' => 1,
            // missing ciphertext and keys
        ]);

        $response->assertStatus(422);
    }

    public function test_version_1_rejects_plaintext_message()
    {
        $user1 = User::factory()->create();
        $chat = Chat::create(['type' => 'personal', 'created_by' => $user1->id]);
        $chat->participants()->create(['user_id' => $user1->id, 'status' => 'joined']);

        $response = $this->withHeaders($this->getAuthHeaders($user1))->postJson("/api/chats/{$chat->id}/messages", [
            'type' => 'text',
            'encryption_version' => 1,
            'message' => 'Plaintext bocor',
            'ciphertext' => 'encrypted',
            'iv' => '12345',
            'message_keys' => [],
        ]);

        $response->assertStatus(422);
    }

    public function test_version_1_saves_valid_envelopes()
    {
        $user1 = User::factory()->create();
        $user2 = User::factory()->create();
        $chat = Chat::create(['type' => 'personal', 'created_by' => $user1->id]);
        $chat->participants()->create(['user_id' => $user1->id, 'status' => 'joined']);
        $chat->participants()->create(['user_id' => $user2->id, 'status' => 'joined']);

        $device1 = UserDevice::create(['user_id' => $user1->id, 'device_id' => 'dev1', 'public_key' => 'pub1', 'is_active' => true]);
        $device2 = UserDevice::create(['user_id' => $user2->id, 'device_id' => 'dev2', 'public_key' => 'pub2', 'is_active' => true]);
        
        $response = $this->withHeaders($this->getAuthHeaders($user1))->postJson("/api/chats/{$chat->id}/messages", [
            'type' => 'text',
            'encryption_version' => 1,
            'ciphertext' => 'Base64Ciphertext',
            'iv' => 'Base64IV',
            'message_keys' => [
                ['device_id' => $device1->id, 'encrypted_key' => 'KeyForDev1'],
                ['device_id' => $device2->id, 'encrypted_key' => 'KeyForDev2'],
            ],
        ]);

        $response->assertStatus(200);
        $messageId = $response->json('data.id');
        $this->assertNotNull($messageId);

        $this->assertDatabaseHas('message_keys', [
            'message_id' => $messageId,
            'device_id' => $device1->id,
            'encrypted_key' => 'KeyForDev1',
        ]);
        $this->assertDatabaseHas('message_keys', [
            'message_id' => $messageId,
            'device_id' => $device2->id,
            'encrypted_key' => 'KeyForDev2',
        ]);
    }

    public function test_version_1_ignores_envelopes_for_invalid_devices()
    {
        $user1 = User::factory()->create();
        $chat = Chat::create(['type' => 'personal', 'created_by' => $user1->id]);
        $chat->participants()->create(['user_id' => $user1->id, 'status' => 'joined']);

        // User 3 is NOT in chat
        $user3 = User::factory()->create();
        $device3 = UserDevice::create(['user_id' => $user3->id, 'device_id' => 'dev3', 'public_key' => 'pub3', 'is_active' => true]);
        
        $response = $this->withHeaders($this->getAuthHeaders($user1))->postJson("/api/chats/{$chat->id}/messages", [
            'type' => 'text',
            'encryption_version' => 1,
            'ciphertext' => 'Base64Ciphertext',
            'iv' => 'Base64IV',
            'message_keys' => [
                ['device_id' => $device3->id, 'encrypted_key' => 'KeyForDev3'],
            ],
        ]);

        $response->assertStatus(200);
        $messageId = $response->json('data.id');
        
        $this->assertDatabaseMissing('message_keys', [
            'message_id' => $messageId,
            'device_id' => $device3->id,
        ]);
    }
}
