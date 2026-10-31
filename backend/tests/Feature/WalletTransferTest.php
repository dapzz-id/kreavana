<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\User;
use App\Models\WalletTransaction;
use App\Models\Notification;
use App\Services\WalletService;
use App\Enums\RoleType;
use Database\Seeders\UserSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;

class WalletTransferTest extends TestCase
{
    use RefreshDatabase;

    protected WalletService $walletService;

    protected function setUp(): void
    {
        parent::setUp();
        $this->walletService = app(WalletService::class);
    }

    public function test_transfer_deducts_sender_and_credits_receiver_with_fee_and_notification(): void
    {
        $sender = User::factory()->create([
            'role' => RoleType::User,
            'balance' => 100000000.0, // 100 million
            'username' => 'sender_user',
        ]);

        $receiver = User::factory()->create([
            'role' => RoleType::User,
            'balance' => 5000000.0, // 5 million
            'username' => 'receiver_user',
        ]);

        $result = $this->walletService->transfer($sender->id, [
            'receiver_username' => 'receiver_user',
            'amount' => 100000000.0,
            'description' => 'Transfer 100M untuk proyek',
        ]);

        $sender->refresh();
        $receiver->refresh();

        // Sender deducted by 100M -> 0
        $this->assertEquals(0.0, $sender->balance);
        $this->assertEquals(0.0, $result['sender_balance']);

        // Fee is 5% -> 5M, Net -> 95M. Receiver had 5M + 95M = 100M
        $this->assertEquals(5000000.0, $result['fee']);
        $this->assertEquals(95000000.0, $result['net_amount']);
        $this->assertEquals(100000000.0, $receiver->balance);

        // Verify transactions
        $this->assertDatabaseHas('wallet_transactions', [
            'user_id' => $sender->id,
            'type' => 'transfer_send',
            'amount' => 100000000.0,
            'fee' => 5000000.0,
            'status' => 'completed',
        ]);

        $this->assertDatabaseHas('wallet_transactions', [
            'user_id' => $receiver->id,
            'type' => 'transfer_receive',
            'amount' => 95000000.0,
            'fee' => 5000000.0,
            'status' => 'completed',
        ]);

        // Verify receiver notification
        $this->assertDatabaseHas('notifications', [
            'user_id' => $receiver->id,
            'title' => 'Saldo Masuk',
        ]);
    }

    public function test_transfer_fails_if_insufficient_balance(): void
    {
        $this->expectException(\Exception::class);
        $this->expectExceptionMessage('Saldo tidak mencukupi untuk transfer.');

        $sender = User::factory()->create([
            'role' => RoleType::User,
            'balance' => 1000000.0,
            'username' => 'poor_sender',
        ]);

        $receiver = User::factory()->create([
            'role' => RoleType::User,
            'balance' => 0.0,
            'username' => 'rich_receiver',
        ]);

        $this->walletService->transfer($sender->id, [
            'receiver_username' => 'rich_receiver',
            'amount' => 50000000.0,
        ]);
    }

    public function test_user_seeder_does_not_wipe_out_client_demo_balance_if_already_present(): void
    {
        // 1. Run seeder first time
        $this->seed(UserSeeder::class);

        $client = User::where('email', 'client@kreavana.id')->first();
        $this->assertNotNull($client);

        // 2. Client receives 95M transfer
        $client->balance = 99015002.0;
        $client->save();

        // 3. Re-run UserSeeder (e.g. during updates or tests)
        $this->seed(UserSeeder::class);

        $client->refresh();

        // 4. Balance must NOT be clobbered back to 5.000.000
        $this->assertEquals(99015002.0, $client->balance);
    }
}
