<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use App\Models\Subscription;
use App\Models\WalletTransaction;
use Tymon\JWTAuth\Facades\JWTAuth;
use Illuminate\Support\Facades\Hash;

class SubscriptionPurchaseTest extends TestCase
{
    use RefreshDatabase;

    protected function getAuthHeaders(User $user): array
    {
        $token = JWTAuth::fromUser($user);
        return ['Authorization' => "Bearer {$token}"];
    }

    public function test_purchase_subscription_successfully()
    {
        $user = User::factory()->create([
            'role' => \App\Enums\RoleType::Creator,
            'balance' => 200000,
            'wallet_pin' => Hash::make('123456'),
        ]);

        $response = $this->withHeaders($this->getAuthHeaders($user))->postJson('/api/subscription/purchase', [
            'tier' => 'pro',
            'pin' => '123456',
            'auto_renew' => true,
        ]);

        $response->assertStatus(200);
        $response->assertJson([
            'message' => 'Berhasil berlangganan paket Pro',
        ]);

        // Balance deducted: 200000 - 199999 = 1
        $this->assertEquals(1, (int) $user->fresh()->balance);

        // Subscription created
        $this->assertDatabaseHas('subscriptions', [
            'user_id' => $user->id,
            'tier' => 'pro',
            'price_paid' => 199999,
            'auto_renew' => true,
        ]);

        // Accessor returns 'pro'
        $this->assertEquals('pro', $user->fresh()->subscription_tier);

        // Wallet transaction created with positive amount
        $this->assertDatabaseHas('wallet_transactions', [
            'user_id' => $user->id,
            'type' => 'subscription_payment',
            'amount' => 199999,
            'status' => 'completed',
        ]);
    }

    public function test_purchase_fails_with_insufficient_balance()
    {
        $user = User::factory()->create([
            'role' => \App\Enums\RoleType::User,
            'balance' => 1000,
            'wallet_pin' => Hash::make('123456'),
        ]);

        $response = $this->withHeaders($this->getAuthHeaders($user))->postJson('/api/subscription/purchase', [
            'tier' => 'plus',
            'pin' => '123456',
        ]);

        $response->assertStatus(400);
        $response->assertJson([
            'error_code' => 'insufficient_balance',
        ]);
    }

    public function test_purchase_fails_with_wrong_pin()
    {
        $user = User::factory()->create([
            'role' => \App\Enums\RoleType::User,
            'balance' => 100000,
            'wallet_pin' => Hash::make('123456'),
        ]);

        $response = $this->withHeaders($this->getAuthHeaders($user))->postJson('/api/subscription/purchase', [
            'tier' => 'plus',
            'pin' => '999999',
        ]);

        $response->assertStatus(403);
        $response->assertJson([
            'message' => 'PIN Dompet salah.',
        ]);
    }
}

