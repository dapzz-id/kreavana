<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use App\Models\Chat;
use App\Models\ChatParticipant;
use App\Events\MessageSent;
use Illuminate\Support\Facades\Event;
use Tymon\JWTAuth\Facades\JWTAuth;
use Illuminate\Support\Str;

class MessageRealtimeBroadcastTest extends TestCase
{
    use RefreshDatabase;

    protected function getAuthHeaders(User $user): array
    {
        $token = JWTAuth::fromUser($user);
        return ['Authorization' => "Bearer {$token}"];
    }

    public function test_message_sent_broadcasts_on_chat_and_user_channels_with_message_keys()
    {
        Event::fake([MessageSent::class]);

        $sender = User::factory()->create();
        $receiver = User::factory()->create();

        $chat = Chat::create(['id' => Str::uuid(), 'type' => 'personal']);
        ChatParticipant::create(['chat_id' => $chat->id, 'user_id' => $sender->id]);
        ChatParticipant::create(['chat_id' => $chat->id, 'user_id' => $receiver->id]);

        $payload = [
            'type' => 'text',
            'encryption_version' => 1,
            'ciphertext' => 'encrypted_ciphertext_sample',
            'iv' => 'sample_iv',
            'message_keys' => [
                [
                    'device_id' => 'receiver-device-123',
                    'encrypted_key' => 'sample_encrypted_key',
                ]
            ],
        ];

        $response = $this->withHeaders($this->getAuthHeaders($sender))
            ->postJson("/api/chats/{$chat->id}/messages", $payload);

        $response->assertStatus(200);

        Event::assertDispatched(MessageSent::class, function ($event) use ($chat, $sender, $receiver) {
            $channels = array_map(fn($c) => $c->name, $event->broadcastOn());

            // Must broadcast to chat channel AND receiver's personal user channel
            $this->assertContains('chat.' . $chat->id, $channels);
            $this->assertContains('user.' . $receiver->id, $channels);

            // Must include chat_id and message_keys in message data for realtime client decryption
            $this->assertEquals($chat->id, $event->message['chat_id']);
            $this->assertNotEmpty($event->message['message_keys']);
            $this->assertEquals('receiver-device-123', $event->message['message_keys'][0]['device_id']);

            return true;
        });
    }
}
