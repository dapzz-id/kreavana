<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use App\Models\MarketplaceItem;
use App\Models\MarketplacePurchase;
use App\Models\MarketplaceReview;
use App\Models\Opportunity;
use App\Models\JobContract;
use App\Models\OpportunityReview;
use App\Models\UserAddress;
use App\Models\CreatorCapacitySchedule;

class RecommendationPostProductionAuditTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        // Valid Creator Base
        $this->creator = User::create([
            'id' => \Illuminate\Support\Str::uuid(),
            'name' => 'Valid Creator',
            'email' => 'valid@example.com',
            'username' => 'valid',
            'password' => bcrypt('password'),
            'role' => \App\Enums\RoleType::Creator,
            'is_creator_approved' => true,
            'sub_role' => 'event_organizer',
            'performance_boost' => 10,
        ]);
        UserAddress::create([
            'user_id' => $this->creator->id,
            'city' => 'Jakarta',
            'province' => 'DKI Jakarta',
            'postal_code' => '12345',
            'label' => 'Home',
            'phone' => '123',
            'recipient_name' => 'Name',
            'address' => 'Line',
            'is_default' => true,
        ]);
        MarketplaceItem::create([
            'user_id' => $this->creator->id,
            'title' => 'Wedding Service',
            'description' => 'Desc',
            'price' => 1000,
            'delivery_type' => 'service',
            'status' => 'published',
            'category' => 'wedding',
        ]);
    }

    public function test_endpoints_exist()
    {
        $this->getJson('/api/creators/recommendations')->assertStatus(200);
        $this->getJson('/api/creators/recommendations/categories')->assertStatus(200);
    }

    public function test_eligibility_unapproved_excluded()
    {
        $unapproved = User::create([
            'id' => \Illuminate\Support\Str::uuid(),
            'name' => 'Unapproved',
            'email' => 'u@example.com',
            'username' => 'unapproved',
            'password' => bcrypt('password'),
            'role' => \App\Enums\RoleType::Creator,
            'is_creator_approved' => false,
        ]);
        MarketplaceItem::create([
            'user_id' => $unapproved->id,
            'title' => 'Test', 'description' => 'Test', 'price' => 100,
            'delivery_type' => 'service', 'status' => 'published', 'category' => 'wedding'
        ]);

        $response = $this->getJson('/api/creators/recommendations');
        $ids = collect($response->json('data'))->pluck('id')->toArray();
        $this->assertNotContains($unapproved->id, $ids);
    }

    public function test_domain_separation_digital_not_service()
    {
        $digitalOnly = User::create([
            'id' => \Illuminate\Support\Str::uuid(),
            'name' => 'Digital Only',
            'email' => 'd@example.com',
            'username' => 'digital_only',
            'password' => bcrypt('password'),
            'role' => \App\Enums\RoleType::Creator,
            'is_creator_approved' => true,
        ]);
        MarketplaceItem::create([
            'user_id' => $digitalOnly->id,
            'title' => 'Ebook', 'description' => 'Test', 'price' => 100,
            'delivery_type' => 'digital_download', 'status' => 'published', 'category' => 'ebook'
        ]);

        $response = $this->getJson('/api/creators/recommendations');
        $ids = collect($response->json('data'))->pluck('id')->toArray();
        $this->assertNotContains($digitalOnly->id, $ids);
    }

    public function test_performance_rating_exactly_4_ignored()
    {
        $dummyBuyer1 = User::factory()->create();
        $dummyBuyer2 = User::factory()->create();
        
        $digitalItem = MarketplaceItem::create([
            'user_id' => $this->creator->id,
            'title' => 'Ebook', 'description' => 'Test', 'price' => 100,
            'delivery_type' => 'digital_download', 'status' => 'published', 'category' => 'ebook'
        ]);
        $purchase = MarketplacePurchase::create([
            'marketplace_item_id' => $digitalItem->id,
            'user_id' => $dummyBuyer1->id, // buyer
            'amount' => 100,
            'status' => 'success',
            'order_id' => 'ORD-123'
        ]);
        MarketplaceReview::create([
            'marketplace_purchase_id' => $purchase->id,
            'marketplace_item_id' => $digitalItem->id,
            'user_id' => $dummyBuyer1->id,
            'rating' => 4.0, // Exactly 4 should NOT count as positive marketplace review
            'comment' => 'Good',
        ]);
        MarketplaceReview::create([
            'marketplace_purchase_id' => MarketplacePurchase::create([
                'marketplace_item_id' => $digitalItem->id, 'user_id' => $dummyBuyer2->id, 'amount' => 100, 'status' => 'success', 'order_id' => 'ORD-124'
            ])->id,
            'marketplace_item_id' => $digitalItem->id,
            'user_id' => $dummyBuyer2->id,
            'rating' => 4.5, // > 4 should count
            'comment' => 'Great',
        ]);

        $response = $this->getJson('/api/creators/recommendations');
        $creatorData = collect($response->json('data'))->firstWhere('id', $this->creator->id);
        $this->assertEquals(1, $creatorData['positive_marketplace_reviews_count']);
    }

    public function test_performance_opportunity_review_requires_completed_contract()
    {
        $opp = Opportunity::create(['title' => 'Opp', 'description' => 'desc', 'budget' => 1000, 'posted_by' => $this->creator->id, 'status' => 'open', 'sub_role_slug' => 'event_organizer', 'location' => 'Jakarta']);
        
        // Incomplete contract
        JobContract::create([
            'opportunity_id' => $opp->id,
            'creator_id' => $this->creator->id,
            'client_id' => $this->creator->id,
            'title' => 'Job Title',
            'description' => 'Job Desc',
            'amount' => 1000,
            'work_status' => 'in_progress',
        ]);
        OpportunityReview::create([
            'opportunity_id' => $opp->id,
            'creator_id' => $this->creator->id,
            'reviewer_id' => $this->creator->id,
            'rating' => 5.0,
            'comment' => 'Excellent',
        ]);

        $response = $this->getJson('/api/creators/recommendations');
        $creatorData = collect($response->json('data'))->firstWhere('id', $this->creator->id);
        $this->assertEquals(0, $creatorData['positive_contract_reviews_count']); // Ignored because in_progress
    }
}
