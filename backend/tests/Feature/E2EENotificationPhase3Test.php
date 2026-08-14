<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use App\Models\Chat;
use App\Models\Notification;
use App\Models\UserDevice;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\Log;

class E2EENotificationPhase3Test extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
    }

    public function test_plaintext_message_creates_plaintext_notifications()
    {
        $sender = User::factory()->create();
        $receiver = User::factory()->create();
        
        $receiver->fcm_token = 'legacy_token_123';
        $receiver->save();

        UserDevice::create([
            'user_id' => $receiver->id,
            'device_id' => \Illuminate\Support\Str::uuid(),
            'public_key' => 'dummy_pub_key',
            'fcm_token' => 'multi_device_token_456',
            'is_active' => true,
        ]);

        $chat = Chat::create(['type' => 'direct']);
        $chat->participants()->create(['user_id' => $sender->id, 'role' => 'member']);
        $chat->participants()->create(['user_id' => $receiver->id, 'role' => 'member']);

        // Mock FcmService
        $this->mock(\App\Services\FcmService::class, function ($mock) {
            $mock->shouldReceive('sendPushNotification')->twice()->andReturn(true);
        });

        $messageService = app(\App\Services\MessageService::class);
        $messageData = $messageService->sendMessage($chat, $sender->id, 'Halo, ini pesan rahasia', 'text', null, null, 0, null, null, []);

        $notification = Notification::where('user_id', $receiver->id)->first();
        $this->assertNotNull($notification);
        $this->assertEquals('Halo, ini pesan rahasia', $notification->message); // In-app is plaintext
    }

    public function test_encrypted_message_creates_generic_notifications_and_does_not_leak_plaintext()
    {
        $sender = User::factory()->create();
        $receiver = clone User::factory()->create();
        
        UserDevice::create([
            'user_id' => $receiver->id,
            'device_id' => \Illuminate\Support\Str::uuid(),
            'public_key' => 'dummy_pub_key',
            'fcm_token' => 'multi_device_token_789',
            'is_active' => true,
        ]);

        $chat = Chat::create(['type' => 'direct']);
        $chat->participants()->create(['user_id' => $sender->id, 'role' => 'member']);
        $chat->participants()->create(['user_id' => $receiver->id, 'role' => 'member']);

        // Assert FCM Service is called correctly
        $this->mock(\App\Services\FcmService::class, function ($mock) use ($chat, $sender) {
            $mock->shouldReceive('sendPushNotification')
                ->once()
                ->with(
                    'multi_device_token_789', 
                    'Pesan baru', 
                    'Pesan terenkripsi baru', 
                    \Mockery::on(function ($data) use ($chat, $sender) {
                        return $data['encryption_version'] === 1 && 
                               $data['chat_id'] === $chat->id && 
                               isset($data['message_id']) && 
                               !isset($data['ciphertext']) &&
                               !isset($data['encrypted_key']);
                    })
                )
                ->andReturn(true);
        });

        $messageService = app(\App\Services\MessageService::class);
        $messageService->sendMessage($chat, $sender->id, null, 'text', null, null, 1, 'ENCRYPTED_TEXT_NOT_LEAKED', 'IV_DATA', []);

        $notification = Notification::where('user_id', $receiver->id)->first();
        $this->assertNotNull($notification);
        $this->assertEquals('Pesan terenkripsi baru', $notification->message); // In-app is generic
    }
}
