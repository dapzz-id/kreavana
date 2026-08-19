<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\User;
use App\Models\MarketplaceItem;
use App\Models\CreatorService;
use App\Models\UserAddress;
use Illuminate\Foundation\Testing\RefreshDatabase;

class RecommendationProductionTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
    }

    public function test_default_pagination_works()
    {
        User::factory()->count(25)->create([
            'role' => \App\Enums\RoleType::Creator,
            'is_creator_approved' => true,
        ])->each(function ($creator) {
            CreatorService::create([
                'creator_id' => $creator->id,
                'title' => 'Test Service',
                'description' => 'A service',
                'price' => 1000,
                
                'status' => 'active',
                'category' => 'wedding'
            ]);
        });

        $response = $this->getJson('/api/creators/recommendations');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'status',
                'message',
                'data',
                'meta' => [
                    'current_page',
                    'per_page',
                    'total',
                    'last_page'
                ]
            ]);

        $this->assertCount(20, $response->json('data'));
        $this->assertEquals(1, $response->json('meta.current_page'));
        $this->assertEquals(20, $response->json('meta.per_page'));
    }

    public function test_custom_per_page_works()
    {
        $response = $this->getJson('/api/creators/recommendations?per_page=10');
        $response->assertStatus(200);
        $this->assertEquals(10, $response->json('meta.per_page'));
    }

    public function test_maximum_per_page_is_enforced()
    {
        $response = $this->getJson('/api/creators/recommendations?per_page=100');
        $response->assertStatus(422);
    }
}
