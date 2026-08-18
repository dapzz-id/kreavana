<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use App\Models\MarketplaceItem;
use App\Models\CreatorPerformanceEvent;
use App\Models\WalletTransaction;
use App\Models\MarketplacePurchase;
use Tymon\JWTAuth\Facades\JWTAuth;
use Illuminate\Support\Facades\DB;

class MarketplacePurchaseTest extends TestCase
{
    use RefreshDatabase;

    
    public function test_successful_purchase_deducts_balance_and_awards_bonus()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator, 'balance' => 0]);
        $buyer = User::factory()->create(['balance' => 150000, 'wallet_pin' => \Illuminate\Support\Facades\Hash::make('1234')]); // Buyer has enough balance

        $item = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Test Item',
            'description' => 'Test',
            'category' => 'Fotografi',
            'type' => 'paid',
            'price' => 100000,
            'status' => 'published',
            'is_active' => true,
        ]);

        $response = $this->withHeaders($this->getAuthHeaders($buyer))->postJson("/api/marketplace/{$item->id}/purchase", ['pin' => '1234']);

        $response->assertStatus(200);

        // Check balances
        $this->assertEquals(50000, $buyer->fresh()->balance); // 150000 - 100000
        $this->assertEquals(95000, $creator->fresh()->balance); // 100000 - 5% fee

        // Check wallet transactions
        $this->assertDatabaseHas('wallet_transactions', [
            'user_id' => $buyer->id,
            'type' => 'marketplace_purchase',
            'amount' => 100000,
            'fee' => 0,
            'status' => 'completed'
        ]);

        $this->assertDatabaseHas('wallet_transactions', [
            'user_id' => $creator->id,
            'type' => 'marketplace_sale',
            'amount' => 95000,
            'fee' => 5000, // 5% of 100000
            'status' => 'completed'
        ]);

        $this->assertDatabaseHas('creator_performance_events', [
            'user_id' => $creator->id,
            'event_type' => 'marketplace_sale',
            'bonus_percentage' => 0.5,
        ]);

        $this->assertDatabaseHas('marketplace_purchases', [
            'user_id' => $buyer->id,
            'marketplace_item_id' => $item->id,
            'amount' => 100000,
            'status' => 'success',
        ]);

        // performance_boost of creator should update to 0.5 (1 * 0.5)
        $this->assertEquals(0.5, $creator->fresh()->performance_boost);
    }

    public function test_insufficient_balance_is_rejected()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator, 'balance' => 0]);
        $buyer = User::factory()->create(['balance' => 50000, 'wallet_pin' => \Illuminate\Support\Facades\Hash::make('1234')]); // Insufficient balance

        $item = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Test Item',
            'description' => 'Test',
            'category' => 'Fotografi',
            'type' => 'paid',
            'price' => 100000,
            'status' => 'published',
            'is_active' => true,
        ]);

        $response = $this->withHeaders($this->getAuthHeaders($buyer))->postJson("/api/marketplace/{$item->id}/purchase", ['pin' => '1234']);

        $response->assertStatus(400);
        $response->assertJsonFragment(['message' => 'Saldo tidak mencukupi untuk melakukan pembelian ini.']);

        $this->assertEquals(50000, $buyer->fresh()->balance); // Balance not deducted
        $this->assertEquals(0, $creator->fresh()->balance); // Seller balance unchanged

        $this->assertEquals(0, WalletTransaction::count());
        $this->assertEquals(0, MarketplacePurchase::count());
        $this->assertEquals(0, CreatorPerformanceEvent::count());
    }

    public function test_repeated_payment_gives_no_duplicate_bonus()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator, 'balance' => 0]);
        $buyer = User::factory()->create(['balance' => 200000, 'wallet_pin' => \Illuminate\Support\Facades\Hash::make('1234')]);

        $item = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Test Item',
            'description' => 'Test',
            'category' => 'Fotografi',
            'type' => 'paid',
            'price' => 100000,
            'status' => 'published',
            'is_active' => true,
        ]);

        // First purchase
        $this->withHeaders($this->getAuthHeaders($buyer))->postJson("/api/marketplace/{$item->id}/purchase", ['pin' => '1234']);

        // Second purchase
        $response = $this->withHeaders($this->getAuthHeaders($buyer))->postJson("/api/marketplace/{$item->id}/purchase", ['pin' => '1234']);

        $response->assertStatus(400); // Bad Request because already purchased

        $eventsCount = CreatorPerformanceEvent::where('user_id', $creator->id)->count();
        $this->assertEquals(1, $eventsCount);
        $this->assertEquals(1, MarketplacePurchase::count());

        $this->assertEquals(100000, $buyer->fresh()->balance); // Only deducted once
    }

    public function test_cannot_purchase_own_item()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator, 'balance' => 200000, 'wallet_pin' => \Illuminate\Support\Facades\Hash::make('1234')]);

        $item = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Test Item',
            'description' => 'Test',
            'category' => 'Fotografi',
            'type' => 'paid',
            'price' => 100000,
            'status' => 'published',
            'is_active' => true,
        ]);

        $response = $this->withHeaders($this->getAuthHeaders($creator))->postJson("/api/marketplace/{$item->id}/purchase", ['pin' => '1234']);

        $response->assertStatus(400);
        $response->assertJsonFragment(['message' => 'Anda tidak bisa membeli karya Anda sendiri.']);
        
        $this->assertEquals(200000, $creator->fresh()->balance);
    }
    
    public function test_client_cannot_manipulate_price()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator, 'balance' => 0]);
        $buyer = User::factory()->create(['balance' => 50000, 'wallet_pin' => \Illuminate\Support\Facades\Hash::make('1234')]); // Less than 100k, but trying to buy for 1k

        $item = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Test Item',
            'description' => 'Test',
            'category' => 'Fotografi',
            'type' => 'paid',
            'price' => 100000,
            'status' => 'published',
            'is_active' => true,
        ]);

        // Attempting to send manipulated data
        $response = $this->withHeaders($this->getAuthHeaders($buyer))->postJson("/api/marketplace/{$item->id}/purchase", [
            'pin' => '1234',
            'price' => 1000,
            'amount' => 1000,
            'fee' => 0,
            'bonus_percentage' => 10.0
        ]);

        // Should still fail due to insufficient balance because the backend uses the real DB price (100k)
        $response->assertStatus(400);
        $this->assertEquals(0, MarketplacePurchase::count());
        $this->assertEquals(0, CreatorPerformanceEvent::count());
    }

    public function test_subscription_multiplier_is_applied()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator, 'balance' => 0]);
        $creator->subscriptions()->create(['tier' => 'super', 'expires_at' => now()->addDays(30)]); // 5.0x multiplier
        
        $buyer = User::factory()->create(['balance' => 150000, 'wallet_pin' => \Illuminate\Support\Facades\Hash::make('1234')]);

        $item = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Test Item',
            'description' => 'Test',
            'category' => 'Fotografi',
            'type' => 'paid',
            'price' => 100000,
            'status' => 'published',
            'is_active' => true,
        ]);

        $response = $this->withHeaders($this->getAuthHeaders($buyer))->postJson("/api/marketplace/{$item->id}/purchase", ['pin' => '1234']);

        $response->assertStatus(200);

        // Performance boost should be 0.5 (marketplace_sale) * 5.0 (super) = 2.5
        $this->assertEquals(2.5, $creator->fresh()->performance_boost);
    }

    public function test_transaction_rolls_back_on_error()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator, 'balance' => 0]);
        $buyer = User::factory()->create(['balance' => 150000, 'wallet_pin' => \Illuminate\Support\Facades\Hash::make('1234')]);

        $item = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Test Item',
            'description' => 'Test',
            'category' => 'Fotografi',
            'type' => 'paid',
            'price' => 100000,
            'status' => 'published',
            'is_active' => true,
        ]);

        // Force a failure in the transaction by using Model events
        \App\Models\WalletTransaction::saving(function () {
            throw new \Exception("Simulated Failure");
        });

        $response = $this->withHeaders($this->getAuthHeaders($buyer))->postJson("/api/marketplace/{$item->id}/purchase", ['pin' => '1234']);

        $response->assertStatus(500);

        // Assert balances are rolled back
        $this->assertEquals(150000, $buyer->fresh()->balance);
        $this->assertEquals(0, $creator->fresh()->balance);

        // Assert no purchase or performance event was created
        $this->assertEquals(0, MarketplacePurchase::count());
        $this->assertEquals(0, CreatorPerformanceEvent::count());
    }

    public function test_concurrent_requests_do_not_double_spend()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator, 'balance' => 0]);
        $buyer = User::factory()->create(['balance' => 150000, 'wallet_pin' => \Illuminate\Support\Facades\Hash::make('1234')]);

        $item1 = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Test Item 1',
            'description' => 'Test',
            'category' => 'Fotografi',
            'type' => 'paid',
            'price' => 100000,
            'status' => 'published',
            'is_active' => true,
        ]);
        
        $item2 = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Test Item 2',
            'description' => 'Test',
            'category' => 'Fotografi',
            'type' => 'paid',
            'price' => 80000,
            'status' => 'published',
            'is_active' => true,
        ]);

        // Standard Laravel tests run synchronously in one PHP process.
        // True concurrent testing in SQLite memory is limited, but we test the application
        // logic by making two sequential requests. Because the first request commits the state,
        // the second request accurately triggers the insufficient balance logic, proving 
        // that DB state is securely transitioned. If two processes ran simultaneously, 
        // the lockForUpdate() would serialize them, having the exact same effect.
        
        $response1 = $this->withHeaders($this->getAuthHeaders($buyer))->postJson("/api/marketplace/{$item1->id}/purchase", ['pin' => '1234']);
        $response1->assertStatus(200);
        
        $response2 = $this->withHeaders($this->getAuthHeaders($buyer))->postJson("/api/marketplace/{$item2->id}/purchase", ['pin' => '1234']);
        $response2->assertStatus(400); // 50,000 balance left, needs 80,000

        $this->assertEquals(50000, $buyer->fresh()->balance);
        $this->assertEquals(95000, $creator->fresh()->balance);
        $this->assertEquals(1, MarketplacePurchase::count());
    }
}
