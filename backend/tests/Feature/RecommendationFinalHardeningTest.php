<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use App\Models\MarketplaceItem;
use App\Models\CreatorService;
use App\Models\JobContract;
use App\Models\OpportunityReview;
use App\Models\UserAddress;
use Carbon\Carbon;

class RecommendationFinalHardeningTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->creator1 = User::factory()->create([
            'id' => \Illuminate\Support\Str::uuid(),
            'name' => 'Creator 1',
            'email' => 'creator1@example.com',
            'username' => 'creator1',
            'password' => bcrypt('password'),
            'role' => \App\Enums\RoleType::Creator,
            'is_creator_approved' => true,
            'max_work_capacity' => 1,
            'sub_role' => 'event_organizer',
            'performance_boost' => 10,
        ]);
        CreatorService::create([
            'creator_id' => $this->creator1->id,
            'title' => 'Wedding Service',
            'description' => 'Desc',
            'price' => 1000,
            
            'status' => 'active',
            'category' => 'wedding',
        ]);
        UserAddress::create([
            'user_id' => $this->creator1->id,
            'city' => 'Jakarta',
            'label' => 'Home',
            'phone' => '123',
            'recipient_name' => 'Name',
            'address' => 'Line',
            'province' => 'DKI Jakarta',
            'postal_code' => '12345',
            'is_default' => true,
        ]);

        $this->creator2 = User::factory()->create([
            'id' => \Illuminate\Support\Str::uuid(),
            'name' => 'Creator 2',
            'email' => 'creator2@example.com',
            'username' => 'creator2',
            'password' => bcrypt('password'),
            'role' => \App\Enums\RoleType::Creator,
            'is_creator_approved' => true,
            'max_work_capacity' => 1,
            'sub_role' => 'mc',
            'performance_boost' => 5,
        ]);
        CreatorService::create([
            'creator_id' => $this->creator2->id,
            'title' => 'MC Service',
            'description' => 'Desc',
            'price' => 1000,
            
            'status' => 'active',
            'category' => 'corporate',
        ]);
        UserAddress::create([
            'user_id' => $this->creator2->id,
            'city' => 'Bekasi',
            'label' => 'Home',
            'phone' => '123',
            'recipient_name' => 'Name',
            'address' => 'Line',
            'province' => 'DKI Jakarta',
            'postal_code' => '12345',
            'is_default' => true,
        ]);
    }

    public function test_categories_endpoint_returns_unique_published_service_categories()
    {
        // Should ignore draft
        CreatorService::create([
            'creator_id' => $this->creator1->id,
            'title' => 'Draft',
            'description' => 'Desc',
            'price' => 1000,
            
            'status' => 'inactive',
            'category' => 'ignored_draft',
        ]);
        $response = $this->getJson('/api/creators/recommendations/categories');
        $response->assertStatus(200);
        $data = $response->json('data');

        $this->assertContains('wedding', $data);
        $this->assertContains('corporate', $data);
        $this->assertNotContains('ignored_draft', $data);
    }

    public function test_availability_pagination_nullifies_total_and_uses_has_more()
    {
        // 2 creators total.
        $response = $this->getJson('/api/creators/recommendations?start_date=' . now()->format('Y-m-d') . '&end_date=' . now()->addDays(2)->format('Y-m-d') . '&per_page=1');
        
        $response->assertStatus(200);
        $this->assertNull($response->json('meta.total'));
        $this->assertNull($response->json('meta.last_page'));
        $this->assertTrue($response->json('meta.has_more'));
        
        // Page 2
        $response2 = $this->getJson('/api/creators/recommendations?start_date=' . now()->format('Y-m-d') . '&end_date=' . now()->addDays(2)->format('Y-m-d') . '&per_page=1&page=3');
        $this->assertFalse($response2->json('meta.has_more'));
    }

    public function test_security_ignores_spoofed_ranking_parameters()
    {
        // Try to spoof recommendation_score and performance_boost sorting
        $response = $this->getJson('/api/creators/recommendations?performance_boost=999&recommendation_score=999&sort=id&order=desc');
        
        $response->assertStatus(200);
        // Ensure deterministic ranking applies (creator1 boost 10 > creator2 boost 5)
        $data = $response->json('data');
        $this->assertEquals($this->creator1->id, $data[0]['id']);
        $this->assertEquals($this->creator2->id, $data[1]['id']);
    }

    public function test_invalid_date_ranges_returns_422()
    {
        $response1 = $this->getJson('/api/creators/recommendations?start_date=2026-01-01');
        $response1->assertStatus(422);

        $response2 = $this->getJson('/api/creators/recommendations?end_date=2026-01-01');
        $response2->assertStatus(422);

        $response3 = $this->getJson('/api/creators/recommendations?start_date=2026-02-01&end_date=2026-01-01');
        $response3->assertStatus(422);
    }

    public function test_category_filtering_works()
    {
        $response = $this->getJson('/api/creators/recommendations?category=wedding');
        $response->assertStatus(200);
        $this->assertCount(1, $response->json('data'));
        $this->assertEquals($this->creator1->id, $response->json('data')[0]['id']);
    }
}
