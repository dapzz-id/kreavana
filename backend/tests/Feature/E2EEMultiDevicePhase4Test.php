<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\User;
use App\Models\Chat;
use App\Models\UserDevice;
use Illuminate\Foundation\Testing\RefreshDatabase;

class E2EEMultiDevicePhase4Test extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        // Setup FCM test credentials
        file_put_contents(storage_path('app/kreavana-com-firebase-adminsdk-fbsvc-d63b3f28f0.json'), json_encode([
            'type' => 'service_account',
            'project_id' => 'kreavana-test',
        ]));
    }

    public function test_authenticated_user_can_register_device()
    {
        $user = User::factory()->create();
        
        $request = new \Illuminate\Http\Request();
        $request->merge([
            'device_id' => 'device-123',
            'public_key' => 'PEM-KEY',
        ]);
        $request->setUserResolver(fn() => $user);

        $controller = new \App\Http\Controllers\UserController();
        $response = $controller->registerDevice($request);

        $this->assertEquals(200, $response->getStatusCode());
        $this->assertDatabaseHas('user_devices', [
            'user_id' => $user->id,
            'device_id' => 'device-123',
            'public_key' => 'PEM-KEY',
            'is_active' => true,
        ]);
    }

    public function test_message_version_1_does_not_store_plaintext_and_filters_keys_by_device()
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();

        $chat = Chat::create(['type' => 'personal']);
        $chat->participants()->create(['user_id' => $userA->id, 'status' => 'joined']);
        $chat->participants()->create(['user_id' => $userB->id, 'status' => 'joined']);

        UserDevice::create([
            'user_id' => $userB->id,
            'device_id' => 'device-B1',
            'public_key' => 'PUB-B1',
            'is_active' => true,
        ]);

        $messageService = app(\App\Services\MessageService::class);
        $messageData = $messageService->sendMessage(
            $chat,
            $userA->id,
            'should-be-null',
            'text',
            null,
            null,
            1,
            'enc-xyz',
            'iv-abc',
            [
                ['device_id' => 'device-B1', 'encrypted_key' => 'key-for-B1']
            ]
        );

        // Plaintext should not be stored
        $this->assertDatabaseHas('messages', [
            'chat_id' => $chat->id,
            'encryption_version' => 1,
            'ciphertext' => 'enc-xyz',
            'message' => '', // Enforced empty string for NOT NULL constraint
        ]);

        // Key should be stored
        $device = UserDevice::where('device_id', 'device-B1')->first();
        $this->assertDatabaseHas('message_keys', [
            'device_id' => $device->id,
            'encrypted_key' => 'key-for-B1',
        ]);

        // Fetch messages with correct device ID
        $fetchedB1 = $messageService->getChatMessages($chat->id, $userB->id, 'device-B1');
        $this->assertCount(1, $fetchedB1[0]['message_keys']);
        $this->assertEquals('device-B1', $fetchedB1[0]['message_keys'][0]['device_id']);
        $this->assertEquals('key-for-B1', $fetchedB1[0]['message_keys'][0]['encrypted_key']);

        // Fetch messages with WRONG device ID (should filter keys to [])
        $fetchedWrong = $messageService->getChatMessages($chat->id, $userB->id, 'wrong-device');
        $this->assertEmpty($fetchedWrong[0]['message_keys']);
    }

    public function test_get_devices_only_returns_participant_devices()
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $userC = User::factory()->create();

        $chat = Chat::create(['type' => 'personal']);
        $chat->participants()->create(['user_id' => $userA->id, 'status' => 'joined']);
        $chat->participants()->create(['user_id' => $userB->id, 'status' => 'joined']);

        UserDevice::create([
            'user_id' => $userA->id,
            'device_id' => 'device-A1',
            'public_key' => 'PUB-A1',
            'is_active' => true,
        ]);
        UserDevice::create([
            'user_id' => $userB->id,
            'device_id' => 'device-B1',
            'public_key' => 'PUB-B1',
            'is_active' => true,
        ]);
        UserDevice::create([ // Outsider
            'user_id' => $userC->id,
            'device_id' => 'device-C1',
            'public_key' => 'PUB-C1',
            'is_active' => true,
        ]);

        $request = new \Illuminate\Http\Request();
        $request->setUserResolver(fn() => $userA);

        $chatService = app(\App\Services\ChatService::class);
        $controller = new \App\Http\Controllers\ChatController($chatService);
        $response = $controller->devices($request, $chat);
        
        $this->assertEquals(200, $response->getStatusCode());
        $responseData = $response->getData(true);
        $devices = collect($responseData['data']);
        
        $this->assertCount(2, $devices);
        $this->assertContains('device-A1', $devices->pluck('device_id')->toArray());
        $this->assertContains('device-B1', $devices->pluck('device_id')->toArray());
        $this->assertNotContains('device-C1', $devices->pluck('device_id')->toArray());
    }
}
