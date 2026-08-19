<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\WithFaker;
use Tests\TestCase;
use App\Models\User;
use App\Models\UserAddress;
use App\Models\MarketplaceItem;
use App\Models\CreatorService;
use App\Models\MarketplacePurchase;
use App\Models\MarketplaceReview;
use App\Models\Opportunity;
use App\Models\JobContract;
use App\Models\OpportunityReview;
use Carbon\Carbon;
use App\Enums\CreatorSubRole;

class RecommendationFiltersTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
    }

    private function createCreator($overrides = [])
    {
        return User::factory()->create(array_merge([
            'role' => \App\Enums\RoleType::Creator,
            'is_creator_approved' => true,
            'sub_role' => CreatorSubRole::EVENT_ORGANIZER->value,
            'max_work_capacity' => 5,
        ], $overrides));
    }

    private function createServiceItem($creator, $status = 'active', $category = 'wedding')
    {
        return CreatorService::create([
            'creator_id' => $creator->id,
            'title' => 'Test Service',
            'description' => 'A service',
            'price' => 1000,
            
            'status' => $status,
            'category' => $category,
        ]);
    }

    private function createDigitalItem($creator, $status = 'active')
    {
        return MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Test Digital',
            'description' => 'A digital item',
            'price' => 100,
            'status' => 'published',
            'category' => 'digital',
            'type' => 'paid',
            'is_active' => true,
        ]);
    }

    public function test_creator_eligibility()
    {
        $approvedCreator = $this->createCreator();
        $this->createServiceItem($approvedCreator);

        $unapprovedCreator = $this->createCreator(['is_creator_approved' => false]);
        $this->createServiceItem($unapprovedCreator);

        $nonCreator = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $this->createServiceItem($nonCreator);

        $response = $this->getJson('/api/creators/recommendations');
        $response->assertStatus(200);
        $data = $response->json('data');

        $this->assertCount(1, $data);
        $this->assertEquals($approvedCreator->id, $data[0]['id']);
    }

    public function test_service_catalog_filters()
    {
        // 1. Published service -> included
        $creatorWithPublished = $this->createCreator();
        $this->createServiceItem($creatorWithPublished, 'active');

        // 2. Draft service -> excluded
        $creatorWithDraft = $this->createCreator();
        $this->createServiceItem($creatorWithDraft, 'inactive');

        // 3. Archived service -> excluded
        $creatorWithArchived = $this->createCreator();
        $this->createServiceItem($creatorWithArchived, 'inactive');

        // 5. Creator without catalog -> excluded
        $creatorWithoutCatalog = $this->createCreator();

        $response = $this->getJson('/api/creators/recommendations');
        $data = $response->json('data');

        $this->assertCount(1, $data);
        $this->assertEquals($creatorWithPublished->id, $data[0]['id']);
    }

    public function test_region_filter()
    {
        $bekasiCreator = $this->createCreator();
        $this->createServiceItem($bekasiCreator);
        UserAddress::create([
            'user_id' => $bekasiCreator->id,
            'label' => 'Home',
            'recipient_name' => 'Name',
            'phone' => '123456',
            'address' => 'Street',
            'city' => 'Bekasi',
            'province' => 'Jawa Barat',
            'postal_code' => '12345',
            'is_default' => true,
        ]);

        $jakartaCreator = $this->createCreator();
        $this->createServiceItem($jakartaCreator);
        UserAddress::create([
            'user_id' => $jakartaCreator->id,
            'label' => 'Home',
            'recipient_name' => 'Name',
            'phone' => '123456',
            'address' => 'Street',
            'city' => 'Jakarta',
            'province' => 'DKI',
            'postal_code' => '12345',
            'is_default' => true,
        ]);

        $response = $this->getJson('/api/creators/recommendations?region=Bekasi');
        $data = $response->json('data');

        $this->assertCount(1, $data);
        $this->assertEquals($bekasiCreator->id, $data[0]['id']);
    }

    public function test_sub_role_and_category_filter()
    {
        $woCreator = $this->createCreator(['sub_role' => CreatorSubRole::WEDDING_ORGANIZER->value]);
        $this->createServiceItem($woCreator, 'active', 'wedding');

        $eoCreator = $this->createCreator(['sub_role' => CreatorSubRole::EVENT_ORGANIZER->value]);
        $this->createServiceItem($eoCreator, 'active', 'corporate');

        $response = $this->getJson('/api/creators/recommendations?sub_role=wedding_organizer&category=wedding');
        $data = $response->json('data');

        $this->assertCount(1, $data);
        $this->assertEquals($woCreator->id, $data[0]['id']);
    }

    public function test_ranking_hierarchy()
    {
        // Setup creators with various performance metrics
        $creator1 = $this->createCreator(['performance_boost' => 10.0]); // Winner
        $this->createServiceItem($creator1);

        $creator2 = $this->createCreator(['performance_boost' => 5.0]); 
        $this->createServiceItem($creator2);

        $creator3 = $this->createCreator(['performance_boost' => 5.0]); 
        $this->createServiceItem($creator3);

        $creator4 = $this->createCreator(['performance_boost' => 5.0]); 
        $this->createServiceItem($creator4);

        // Add Marketplace reviews for tie breaking
        $digitalItem2 = $this->createDigitalItem($creator2);
        $purchase2 = MarketplacePurchase::create(['marketplace_item_id' => $digitalItem2->id, 'user_id' => $creator1->id, 'amount' => 100, 'status' => 'success', 'order_id' => 'ORD-TEST-1']);
        MarketplaceReview::create(['marketplace_purchase_id' => $purchase2->id, 'marketplace_item_id' => $digitalItem2->id, 'user_id' => $creator1->id, 'rating' => 5, 'comment' => 'Great']);

        $digitalItem3 = $this->createDigitalItem($creator3); // Has same boost, but less marketplace reviews than 2

        // Add Contract reviews
        $opportunity = Opportunity::factory()->create();
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        JobContract::create([
            'creator_id' => $creator3->id, 
            'client_id' => $client->id,
            'opportunity_id' => $opportunity->id, 
            'title' => 'Job',
            'agreed_price' => 100,
            'work_status' => 'completed',
            'contract_status' => 'approved'
        ]);
        OpportunityReview::create(['creator_id' => $creator3->id, 'reviewer_id' => $client->id, 'opportunity_id' => $opportunity->id, 'rating' => 5, 'comment' => 'Great']);

        $response = $this->getJson('/api/creators/recommendations');
        $data = $response->json('data');

        $this->assertCount(4, $data);
        $this->assertEquals($creator1->id, $data[0]['id']); // Highest boost
        $this->assertEquals($creator2->id, $data[1]['id']); // Tie breaker 1: Marketplace review
        $this->assertEquals($creator3->id, $data[2]['id']); // Tie breaker 2: Contract review
        // $creator4 is last among equals
    }

    public function test_availability_filter()
    {
        $creator = $this->createCreator(['max_work_capacity' => 1]);
        $this->createServiceItem($creator);
        
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);

        // Book them on a specific date
        $contract = JobContract::create([
            'creator_id' => $creator->id,
            'client_id' => $client->id,
            'title' => 'Job',
            'agreed_price' => 100,
            'contract_status' => 'approved',
            'scheduled_start_date' => '2026-09-20',
            'scheduled_end_date' => '2026-09-20',
        ]);

        $response = $this->getJson('/api/creators/recommendations?start_date=2026-09-20&end_date=2026-09-20');
        $data = $response->json('data');

        $this->assertCount(0, $data); // Should be full
    }

    public function test_spoofing_metrics_is_ignored()
    {
        $creator = $this->createCreator();
        $this->createServiceItem($creator);

        // Client attempts to spoof performance metrics
        $response = $this->getJson('/api/creators/recommendations?performance_boost=999&positive_marketplace_reviews_count=999');
        $response->assertStatus(200);

        // Does not crash, and ignores spoofed queries (since they are not defined in the allowed list)
        $data = $response->json('data');
        $this->assertCount(1, $data);
        $this->assertEquals(0, $data[0]['performance_boost']);
    }
}
