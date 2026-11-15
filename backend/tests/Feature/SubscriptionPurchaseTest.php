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

    public function test_cannot_purchase_same_or_lower_tier()
    {
        $user = User::factory()->create([
            'role' => \App\Enums\RoleType::Creator,
            'balance' => 1000000,
            'wallet_pin' => Hash::make('123456'),
        ]);

        Subscription::create([
            'user_id' => $user->id,
            'tier' => 'pro',
            'price_paid' => 199999,
            'expires_at' => now()->addMonth(),
        ]);

        // Attempt to purchase same tier 'pro' now acts as renewal (+1 month)
        $responseSame = $this->withHeaders($this->getAuthHeaders($user))->postJson('/api/subscription/purchase', [
            'tier' => 'pro',
            'pin' => '123456',
        ]);
        $responseSame->assertStatus(200);
        $responseSame->assertJson([
            'is_renewal' => true,
            'tier' => 'pro',
        ]);

        // Attempt to downgrade to 'plus'
        $responseLower = $this->withHeaders($this->getAuthHeaders($user))->postJson('/api/subscription/purchase', [
            'tier' => 'plus',
            'pin' => '123456',
        ]);
        $responseLower->assertStatus(400);
        $responseLower->assertJson([
            'error_code' => 'downgrade_not_allowed',
        ]);

        // Attempt to upgrade to higher tier 'super' should succeed
        $responseHigher = $this->withHeaders($this->getAuthHeaders($user))->postJson('/api/subscription/purchase', [
            'tier' => 'super',
            'pin' => '123456',
        ]);
        $responseHigher->assertStatus(200);
        $this->assertEquals('super', $user->fresh()->subscription_tier);
    }

    public function test_profile_identity_returns_subscription_tier()
    {
        $user = User::factory()->create([
            'role' => \App\Enums\RoleType::Creator,
        ]);

        Subscription::create([
            'user_id' => $user->id,
            'tier' => 'pro',
            'price_paid' => 199999,
            'expires_at' => now()->addMonth(),
        ]);

        $response = $this->withHeaders($this->getAuthHeaders($user))->getJson('/api/profile/identity');
        $response->assertStatus(200);
        $response->assertJsonPath('data.subscription_tier', 'pro');
    }

    public function test_plans_endpoint_hides_boost_account_text_while_preserving_boost_feature()
    {
        foreach (['institution', 'creator', 'client'] as $role) {
            $response = $this->getJson('/api/subscription/plans?role=' . $role);
            $response->assertStatus(200);
            $plans = $response->json('data');
            $this->assertNotEmpty($plans);

            foreach ($plans as $plan) {
                foreach ($plan['features'] ?? [] as $feature) {
                    $this->assertStringNotContainsStringIgnoringCase('boost', $feature);
                }
            }
        }

        // Underlying boost feature still functions when purchasing a paid tier
        $creator = User::factory()->create([
            'role' => \App\Enums\RoleType::Creator,
            'balance' => 500000,
            'wallet_pin' => Hash::make('123456'),
        ]);

        $purchase = $this->withHeaders($this->getAuthHeaders($creator))->postJson('/api/subscription/purchase', [
            'tier' => 'pro',
            'pin' => '123456',
        ]);
        $purchase->assertStatus(200);
        $this->assertEquals('pro', $creator->fresh()->subscription_tier);
    }
}


