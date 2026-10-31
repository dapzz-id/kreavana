<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use App\Models\Subscription;
use App\Models\WalletTransaction;
use Tymon\JWTAuth\Facades\JWTAuth;
use Illuminate\Support\Facades\Hash;
use Carbon\Carbon;

class SubscriptionRenewalTest extends TestCase
{
    use RefreshDatabase;

    protected function getAuthHeaders(User $user): array
    {
        $token = JWTAuth::fromUser($user);
        return ['Authorization' => "Bearer {$token}"];
    }

    public function test_renew_active_subscription_extends_expiry()
    {
        $user = User::factory()->create([
            'role' => \App\Enums\RoleType::Creator,
            'balance' => 500000,
            'wallet_pin' => Hash::make('123456'),
        ]);

        $initialExpiry = now()->addDays(15);
        $subscription = Subscription::create([
            'user_id' => $user->id,
            'tier' => 'pro',
            'price_paid' => 199999,
            'auto_renew' => false,
            'expires_at' => $initialExpiry,
        ]);

        $this->assertEquals('pro', $user->fresh()->subscription_tier);

        // User extends their Pro plan for +1 month
        $response = $this->withHeaders($this->getAuthHeaders($user))->postJson('/api/subscription/purchase', [
            'tier' => 'pro',
            'pin' => '123456',
        ]);

        $response->assertStatus(200);
        $response->assertJson([
            'is_renewal' => true,
            'tier' => 'pro',
        ]);

        // Expiry should now be extended by 1 month from initialExpiry
        $updatedSub = Subscription::find($subscription->id);
        $this->assertTrue(Carbon::parse($updatedSub->expires_at)->greaterThan($initialExpiry));
        $this->assertEquals(500000 - 199999, (int) $user->fresh()->balance);

        // Check wallet transaction
        $this->assertDatabaseHas('wallet_transactions', [
            'user_id' => $user->id,
            'type' => 'subscription_payment',
            'amount' => 199999,
            'description' => 'Perpanjangan Paket Pro (+1 Bulan)',
        ]);
    }

    public function test_downgrade_subscription_is_blocked()
    {
        $user = User::factory()->create([
            'role' => \App\Enums\RoleType::Creator,
            'balance' => 500000,
            'wallet_pin' => Hash::make('123456'),
        ]);

        Subscription::create([
            'user_id' => $user->id,
            'tier' => 'pro',
            'price_paid' => 199999,
            'expires_at' => now()->addMonth(),
        ]);

        // Attempting to downgrade to Plus is blocked
        $response = $this->withHeaders($this->getAuthHeaders($user))->postJson('/api/subscription/purchase', [
            'tier' => 'plus',
            'pin' => '123456',
        ]);

        $response->assertStatus(400);
        $response->assertJson([
            'error_code' => 'downgrade_not_allowed',
        ]);
    }

    public function test_toggle_auto_renew()
    {
        $user = User::factory()->create([
            'role' => \App\Enums\RoleType::Creator,
            'balance' => 500000,
            'wallet_pin' => Hash::make('123456'),
        ]);

        Subscription::create([
            'user_id' => $user->id,
            'tier' => 'pro',
            'price_paid' => 199999,
            'auto_renew' => false,
            'expires_at' => now()->addMonth(),
        ]);

        $response = $this->withHeaders($this->getAuthHeaders($user))->postJson('/api/subscription/toggle-auto-renew', [
            'auto_renew' => true,
        ]);

        $response->assertStatus(200);
        $response->assertJson([
            'status' => true,
            'auto_renew' => true,
        ]);

        $this->assertTrue((bool) $user->fresh()->activeSubscription->auto_renew);
    }

    public function test_process_renewals_command()
    {
        $user = User::factory()->create([
            'role' => \App\Enums\RoleType::Creator,
            'balance' => 300000,
        ]);

        // Subscription expired 1 hour ago with auto_renew=true
        $sub = Subscription::create([
            'user_id' => $user->id,
            'tier' => 'pro',
            'price_paid' => 199999,
            'auto_renew' => true,
            'expires_at' => now()->subHour(),
        ]);

        $this->artisan('subscription:process-renewals')
            ->assertExitCode(0);

        // Subscription should be renewed
        $freshSub = $sub->fresh();
        $this->assertTrue(Carbon::parse($freshSub->expires_at)->isFuture());
        $this->assertEquals(300000 - 199999, (int) $user->fresh()->balance);
    }
}
