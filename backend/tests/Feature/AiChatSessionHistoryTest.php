<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\User;
use App\Models\AiChatSession;
use App\Enums\RoleType;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;

class AiChatSessionHistoryTest extends TestCase
{
    use RefreshDatabase;

    public function test_guest_cannot_access_chat_sessions()
    {
        $response = $this->getJson('/api/ai/chat-sessions');
        $this->assertTrue(in_array($response->status(), [401, 403]));
    }

    public function test_authenticated_user_can_save_and_retrieve_chat_sessions()
    {
        $user = User::factory()->create([
            'email' => 'chatuser@test.com',
            'password' => Hash::make('password123'),
            'role' => RoleType::User,
        ]);

        $loginResponse = $this->postJson('/api/auth/login', [
            'email' => 'chatuser@test.com',
            'password' => 'password123',
        ]);
        $token = $loginResponse->json('data.access_token');

        $headers = ['Authorization' => "Bearer {$token}"];

        // 1. Sync / Save chat session
        $syncResponse = $this->withHeaders($headers)->postJson('/api/ai/chat-sessions', [
            'session_id' => 'sess_123',
            'title' => 'Diskusi Konsep Logo',
            'messages' => [
                ['sender' => 'user', 'text' => 'Bantu buatkan konsep logo kreatif'],
                ['sender' => 'ai', 'text' => 'Tentu, ini beberapa ide logo:'],
            ],
        ]);

        $syncResponse->assertStatus(200)
            ->assertJsonPath('status', true)
            ->assertJsonPath('data.id', 'sess_123')
            ->assertJsonPath('data.title', 'Diskusi Konsep Logo');

        // 2. Retrieve chat sessions
        $getResponse = $this->withHeaders($headers)->getJson('/api/ai/chat-sessions');
        $getResponse->assertStatus(200)
            ->assertJsonPath('status', true)
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', 'sess_123');

        // 3. User isolation check: Another user should not see this session
        $anotherUser = User::factory()->create([
            'email' => 'otheruser@test.com',
            'password' => Hash::make('password123'),
        ]);
        $loginOther = $this->postJson('/api/auth/login', [
            'email' => 'otheruser@test.com',
            'password' => 'password123',
        ]);
        $tokenOther = $loginOther->json('data.access_token');

        $otherGetResponse = $this->withHeaders(['Authorization' => "Bearer {$tokenOther}"])
            ->getJson('/api/ai/chat-sessions');
        $otherGetResponse->assertStatus(200)
            ->assertJsonCount(0, 'data');

        // 4. Delete session
        $deleteResponse = $this->withHeaders($headers)->deleteJson('/api/ai/chat-sessions/sess_123');
        $deleteResponse->assertStatus(200);

        $getAfterDelete = $this->withHeaders($headers)->getJson('/api/ai/chat-sessions');
        $getAfterDelete->assertStatus(200)
            ->assertJsonCount(0, 'data');
    }
}
