<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use App\Models\MarketplaceItem;
use App\Models\MarketplacePurchase;
use App\Models\Opportunity;
use App\Models\DisputeCase;
use App\Models\WalletTransaction;
use App\Models\CreatorPerformanceEvent;
use Illuminate\Support\Str;

class DisputeCaseTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        // Create an admin
        User::factory()->create([
            'role' => 'admin',
            'is_creator_approved' => true
        ]);
    }

    protected function getAuthHeaders($user)
    {
        $token = \Tymon\JWTAuth\Facades\JWTAuth::fromUser($user);
        $payload = \Tymon\JWTAuth\Facades\JWTAuth::setToken($token)->getPayload();
        $jti = $payload->get('jti');
        if ($jti) {
            \App\Services\JtiService::store($jti, 3600);
        }
        return [
            'Authorization' => "Bearer $token",
            'Accept' => 'application/json'
        ];
    }

    public function test_buyer_can_request_refund_and_case_is_created()
    {
        $seller = User::factory()->create(['balance' => 95000]);
        $buyer = User::factory()->create(['balance' => 0]);
        $admin = User::where('role', 'admin')->first();

        $item = MarketplaceItem::create([
            'id' => Str::uuid(),
            'user_id' => $seller->id,
            'title' => 'Test Item',
            'category' => 'Test',
            'description' => 'Desc',
            'price' => 100000,
            'file_url' => 'test.zip'
        ]);
        
        $purchase = MarketplacePurchase::create([
            'id' => Str::uuid(),
            'user_id' => $buyer->id,
            'marketplace_item_id' => $item->id,
            'amount' => 100000,
            'status' => 'completed'
        ]);

        $response = $this->withHeaders($this->getAuthHeaders($buyer))
                         ->postJson('/api/disputes/marketplace-refund', [
                             'marketplace_purchase_id' => $purchase->id,
                             'reason' => 'Item not as described'
                         ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('dispute_cases', [
            'marketplace_purchase_id' => $purchase->id,
            'requester_id' => $buyer->id,
            'other_party_id' => $seller->id,
            'status' => 'pending',
            'assigned_admin_id' => $admin->id
        ]);

        // Check if chat was created
        $dispute = DisputeCase::where('marketplace_purchase_id', $purchase->id)->first();
        $this->assertNotNull($dispute->chat_id);
        
        $this->assertDatabaseHas('chat_participants', [
            'chat_id' => $dispute->chat_id,
            'user_id' => $buyer->id
        ]);
        $this->assertDatabaseHas('chat_participants', [
            'chat_id' => $dispute->chat_id,
            'user_id' => $seller->id
        ]);
        $this->assertDatabaseHas('chat_participants', [
            'chat_id' => $dispute->chat_id,
            'user_id' => $admin->id
        ]);
    }

    public function test_admin_approval_atomically_reverses_wallets_and_boost()
    {
        $seller = User::factory()->create(['balance' => 95000]);
        $buyer = User::factory()->create(['balance' => 0]);
        $admin = User::where('role', 'admin')->first();

        $item = MarketplaceItem::create([
            'id' => Str::uuid(),
            'user_id' => $seller->id,
            'title' => 'Test Item',
            'category' => 'Test',
            'description' => 'Desc',
            'price' => 100000,
            'file_url' => 'test.zip'
        ]);
        
        $purchase = MarketplacePurchase::create([
            'id' => Str::uuid(),
            'user_id' => $buyer->id,
            'marketplace_item_id' => $item->id,
            'amount' => 100000,
            'status' => 'completed'
        ]);

        $perfEvent = CreatorPerformanceEvent::create([
            'user_id' => $seller->id,
            'event_type' => 'marketplace_sale',
            'reference_id' => $purchase->id,
            'bonus_percentage' => 0.50,
            'is_active' => true
        ]);
        $seller->updatePerformanceBoost();
        $this->assertEquals(0.50, $seller->fresh()->performance_boost);

        $dispute = DisputeCase::create([
            'case_type' => 'marketplace_refund',
            'requester_id' => $buyer->id,
            'other_party_id' => $seller->id,
            'assigned_admin_id' => $admin->id,
            'marketplace_purchase_id' => $purchase->id,
            'reason' => 'Defective',
            'status' => 'under_review'
        ]);

        $response = $this->withHeaders($this->getAuthHeaders($admin))
                         ->postJson("/api/admin/disputes/{$dispute->id}/decision-refund", [
                             'decision' => 'approve',
                             'resolution' => 'Approved after review.'
                         ]);

        $response->assertStatus(200);

        // Assert Wallets
        $this->assertEquals(100000, $buyer->fresh()->balance);
        $this->assertEquals(0, $seller->fresh()->balance);

        // Assert Purchase Status
        $this->assertEquals('refunded', $purchase->fresh()->status);

        // Assert Performance Boost Reversal
        $this->assertFalse((bool) $perfEvent->fresh()->is_active);
        $this->assertEquals(0.00, $seller->fresh()->performance_boost);

        // Assert Case Status
        $this->assertEquals('approved', $dispute->fresh()->status);
    }

    public function test_opportunity_cancellation_dispute()
    {
        $owner = User::factory()->create();

        $opportunity = Opportunity::create([
            'id' => Str::uuid(),
            'posted_by' => $owner->id,
            'title' => 'Test',
            'sub_role_slug' => 'test',
            'type' => 'project',
            'status' => 'open'
        ]);

        $response = $this->withHeaders($this->getAuthHeaders($owner))
                         ->postJson('/api/disputes/opportunity-cancellation', [
                             'opportunity_id' => $opportunity->id,
                             'reason' => 'Need to cancel'
                         ]);

        $response->assertStatus(201);
        
        $dispute = DisputeCase::where('opportunity_id', $opportunity->id)->first();
        $this->assertNotNull($dispute);
    }

    public function test_admin_can_approve_opportunity_cancellation()
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $owner = User::factory()->create();

        $opportunity = Opportunity::create([
            'id' => Str::uuid(),
            'posted_by' => $owner->id,
            'title' => 'Test',
            'sub_role_slug' => 'test',
            'type' => 'project',
            'status' => 'open'
        ]);

        $dispute = DisputeCase::create([
            'case_type' => 'opportunity_cancellation',
            'requester_id' => $owner->id,
            'other_party_id' => $owner->id,
            'assigned_admin_id' => $admin->id,
            'opportunity_id' => $opportunity->id,
            'reason' => 'Need to cancel',
            'status' => 'under_review'
        ]);

        $adminResponse = $this->withHeaders($this->getAuthHeaders($admin))
                         ->postJson("/api/admin/disputes/{$dispute->id}/decision-cancellation", [
                             'decision' => 'approve'
                         ]);
                         
        $adminResponse->assertStatus(200);
        $this->assertEquals('cancelled', $opportunity->fresh()->status);
        $this->assertEquals('approved', $dispute->fresh()->status);
    }
}
