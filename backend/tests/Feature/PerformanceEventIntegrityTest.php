<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use App\Models\CreatorPerformanceEvent;
use App\Models\Opportunity;
use App\Models\OpportunityReview;
use App\Models\JobContract;
use App\Models\MarketplaceItem;
use App\Models\CreatorService;
use App\Models\MarketplacePurchase;
use App\Models\MarketplaceReview;
use App\Models\Subscription;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\DB;
use Illuminate\Database\QueryException;

class PerformanceEventIntegrityTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
    }

    public function test_database_idempotency_enforces_unique_events()
    {
        $creator = User::create([
            'id' => Str::uuid(), 'name' => 'C1', 'email' => 'c1@ex.com', 'username' => 'c1', 'password' => bcrypt('1'), 'role' => \App\Enums\RoleType::Creator
        ]);

        CreatorPerformanceEvent::create([
            'creator_id' => $creator->id,
            'event_type' => 'project_rating',
            'reference_id' => 'ref-1',
            'bonus_percentage' => 1.0,
        ]);

        $this->expectException(QueryException::class);

        // Attempt duplicate insertion
        CreatorPerformanceEvent::create([
            'creator_id' => $creator->id,
            'event_type' => 'project_rating',
            'reference_id' => 'ref-1',
            'bonus_percentage' => 1.0,
        ]);
    }

    public function test_aggregate_determinism_and_subscription_multipliers()
    {
        $creator = User::create([
            'id' => Str::uuid(), 'name' => 'C1', 'email' => 'c1@ex.com', 'username' => 'c1', 'password' => bcrypt('1'), 'role' => \App\Enums\RoleType::Creator
        ]);

        CreatorPerformanceEvent::create(['creator_id' => $creator->id, 'event_type' => 'marketplace_sale', 'reference_id' => '1', 'bonus_percentage' => 0.5, ]);
        CreatorPerformanceEvent::create(['creator_id' => $creator->id, 'event_type' => 'project_rating', 'reference_id' => '2', 'bonus_percentage' => 1.0, ]);
        CreatorPerformanceEvent::create(['creator_id' => $creator->id, 'event_type' => 'marketplace_sale', 'reference_id' => '3', 'bonus_percentage' => 0.5, ]); // Inactive

        // 1.5 total active bonus
        $creator->updatePerformanceBoost();
        $this->assertEquals(1.5, $creator->fresh()->performance_boost);

        // Add Plus Subscription (1.5x)
        Subscription::create(['creator_id' => $creator->id, 'tier' => 'plus', 'expires_at' => now()->addMonth()]);
        $creator->updatePerformanceBoost();
        $this->assertEquals(2.25, $creator->fresh()->performance_boost); // 1.5 * 1.5

        // Add Super Subscription (5.0x) - active takes precedence
        Subscription::where('user_id', $creator->id)->update(['expires_at' => now()->subDay()]);
        Subscription::create(['creator_id' => $creator->id, 'tier' => 'super', 'expires_at' => now()->addMonth()]);
        
        $creator->updatePerformanceBoost();
        $this->assertEquals(7.5, $creator->fresh()->performance_boost); // 1.5 * 5.0
    }

    public function test_opportunity_review_idempotency_and_transaction_rollback()
    {
        $creator = User::create([
            'id' => Str::uuid(), 'name' => 'C1', 'email' => 'c1@ex.com', 'username' => 'c1', 'password' => bcrypt('1'), 'role' => \App\Enums\RoleType::Creator
        ]);
        $client = User::create([
            'id' => Str::uuid(), 'name' => 'B1', 'email' => 'b1@ex.com', 'username' => 'b1', 'password' => bcrypt('1'), 'role' => \App\Enums\RoleType::User
        ]);

        $opportunity = Opportunity::create([
            'id' => Str::uuid(),
            'posted_by' => $client->id,
            'title' => 'Test',
            'status' => 'closed',
            'required_role' => 'creator',
            'sub_role_slug' => 'test-slug',
            'description' => 'Test',
            'budget' => 100
        ]);

        JobContract::create([
            'id' => Str::uuid(),
            'opportunity_id' => $opportunity->id,
            'creator_id' => $creator->id,
            'client_id' => $client->id,
            'title' => 'Test Contract',
            'work_status' => 'completed',
            'contract_status' => 'approved',
            'payment_status' => 'released',
            'price' => 100
        ]);

        $this->actingAs($client);

        // First successful review
        $response1 = $this->postJson("/api/opportunities/{$opportunity->id}/reviews", [
            'creator_id' => $creator->id,
            'rating' => 4.5,
            'comment' => 'Great job'
        ]);
        $response1->assertStatus(200);
        $this->assertEquals(1.0, $creator->fresh()->performance_boost);
        $this->assertCount(1, CreatorPerformanceEvent::all());

        // Duplicate review attempt
        $response2 = $this->postJson("/api/opportunities/{$opportunity->id}/reviews", [
            'creator_id' => $creator->id,
            'rating' => 5.0,
            'comment' => 'Duplicate attempt'
        ]);
        $response2->assertStatus(400); // Controller returns 400 for existing review

        // Boost and events should remain unchanged
        $this->assertEquals(1.0, $creator->fresh()->performance_boost);
        $this->assertCount(1, CreatorPerformanceEvent::all());
    }

    public function test_rating_boundary_strict_enforcement()
    {
        $creator = User::create([
            'id' => Str::uuid(), 'name' => 'C1', 'email' => 'c1@ex.com', 'username' => 'c1', 'password' => bcrypt('1'), 'role' => \App\Enums\RoleType::Creator
        ]);
        $client = User::create([
            'id' => Str::uuid(), 'name' => 'B1', 'email' => 'b1@ex.com', 'username' => 'b1', 'password' => bcrypt('1'), 'role' => \App\Enums\RoleType::User
        ]);
        $this->actingAs($client);

        $testCases = [
            ['rating' => 3.9, 'expectedBoost' => 0.0],
            ['rating' => 4.0, 'expectedBoost' => 0.0],
            ['rating' => 4.1, 'expectedBoost' => 1.0],
            ['rating' => 5.0, 'expectedBoost' => 2.0], // Cumulative because we use different opps
        ];

        foreach ($testCases as $case) {
            $opp = Opportunity::create([
                'id' => Str::uuid(), 'posted_by' => $client->id, 'title' => 'Test', 'status' => 'closed', 'required_role' => 'creator', 'sub_role_slug' => 'test-slug', 'description' => 'Test', 'budget' => 100
            ]);
            
            JobContract::create([
                'id' => Str::uuid(),
                'opportunity_id' => $opp->id,
                'creator_id' => $creator->id,
                'client_id' => $client->id,
                'title' => 'Test Contract',
                'work_status' => 'completed',
                'contract_status' => 'approved',
                'payment_status' => 'released',
                'price' => 100
            ]);

            $resp = $this->postJson("/api/opportunities/{$opp->id}/reviews", [
                'creator_id' => $creator->id, 'rating' => $case['rating'], 'comment' => 'Test'
            ]);
            
            if ($resp->status() !== 200) {
                dump($resp->json());
            }
            
            $this->assertEquals($case['expectedBoost'], $creator->fresh()->performance_boost);
        }
    }

    public function test_marketplace_domain_separation()
    {
        $creator = User::create([
            'id' => Str::uuid(), 'name' => 'C1', 'email' => 'c1@ex.com', 'username' => 'c1', 'password' => bcrypt('1'), 'role' => \App\Enums\RoleType::Creator, 'is_creator_approved' => true
        ]);
        $client = User::create([
            'id' => Str::uuid(), 'name' => 'B1', 'email' => 'b1@ex.com', 'username' => 'b1', 'password' => bcrypt('1'), 'role' => \App\Enums\RoleType::User
        ]);
        $this->actingAs($client);

        $itemService = CreatorService::create([
            'id' => Str::uuid(), 'creator_id' => $creator->id, 'title' => 'S1',  'status' => 'active', 'price' => 10, 'category' => 'other', 'description' => 'T'
        ]);
        $purchaseService = MarketplacePurchase::create([
            'id' => Str::uuid(), 'marketplace_item_id' => $itemService->id, 'creator_id' => $client->id, 'amount' => 10, 'status' => 'success'
        ]);
        MarketplaceReview::create(['marketplace_item_id' => $itemService->id, 'creator_id' => $client->id, 'rating' => 5, 'review' => 'Good']);

        $itemDigital = CreatorService::create([
            'id' => Str::uuid(), 'creator_id' => $creator->id, 'title' => 'D1', 'delivery_type' => 'digital_download', 'status' => 'active', 'price' => 10, 'category' => 'other', 'description' => 'T'
        ]);
        $purchaseDigital = MarketplacePurchase::create([
            'id' => Str::uuid(), 'marketplace_item_id' => $itemDigital->id, 'creator_id' => $client->id, 'amount' => 10, 'status' => 'success'
        ]);
        MarketplaceReview::create(['marketplace_item_id' => $itemDigital->id, 'creator_id' => $client->id, 'rating' => 5, 'review' => 'Good']);

        $response = $this->getJson('/api/creators/recommendations');
        $data = collect($response->json('data'))->firstWhere('id', $creator->id);

        $this->assertEquals(1, $data['positive_marketplace_reviews_count']);
    }
}
