<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use App\Models\MarketplaceItem;
use App\Models\MarketplacePurchase;
use App\Models\Opportunity;
use App\Models\DisputeCase;
use App\Models\CreatorPerformanceEvent;
use Illuminate\Support\Str;

class DisputeCaseComprehensiveTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        User::factory()->create(['role' => 'admin', 'is_creator_approved' => true]);
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

    public function test_insufficient_seller_balance_parks_dispute_as_awaiting_settlement()
    {
        $seller = User::factory()->create(['balance' => 0]); // Insufficient balance!
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
                             'resolution' => 'Approved'
                         ]);

        $response->assertStatus(200);
        
        // Assert parked status
        $this->assertEquals('awaiting_settlement', $dispute->fresh()->status);
        // Assert balances unchanged
        $this->assertEquals(0, $seller->fresh()->balance);
        $this->assertEquals(0, $buyer->fresh()->balance);
        // Assert purchase not refunded
        $this->assertEquals('completed', $purchase->fresh()->status);
    }

    public function test_admin_can_settle_refund_when_balance_becomes_sufficient()
    {
        $seller = User::factory()->create(['balance' => 100000]); // Sufficient balance
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

        $dispute = DisputeCase::create([
            'case_type' => 'marketplace_refund',
            'requester_id' => $buyer->id,
            'other_party_id' => $seller->id,
            'assigned_admin_id' => $admin->id,
            'marketplace_purchase_id' => $purchase->id,
            'reason' => 'Defective',
            'status' => 'awaiting_settlement'
        ]);

        $response = $this->withHeaders($this->getAuthHeaders($admin))
                         ->postJson("/api/admin/disputes/{$dispute->id}/settle-refund");

        $response->assertStatus(200);
        $this->assertEquals('refunded', $dispute->fresh()->status);
        $this->assertEquals('refunded', $purchase->fresh()->status);
        $this->assertEquals(5000, $seller->fresh()->balance); // 100k - 95k deduction
        $this->assertEquals(100000, $buyer->fresh()->balance);
    }

    public function test_cannot_review_cancelled_opportunity()
    {
        $owner = User::factory()->create();
        $creator = User::factory()->create();

        $opportunity = Opportunity::create([
            'id' => Str::uuid(),
            'posted_by' => $owner->id,
            'title' => 'Test',
            'sub_role_slug' => 'test',
            'type' => 'project',
            'status' => 'cancelled' // Cancelled!
        ]);

        $response = $this->withHeaders($this->getAuthHeaders($owner))
                         ->postJson("/api/opportunities/{$opportunity->id}/review", [
                             'creator_id' => $creator->id,
                             'rating' => 5,
                             'comment' => 'Great job'
                         ]);

        $response->assertStatus(400); // Because it's not closed
    }
}
