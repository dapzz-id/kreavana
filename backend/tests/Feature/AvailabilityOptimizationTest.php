<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use App\Models\MarketplaceItem;
use App\Models\CreatorCapacitySchedule;
use Illuminate\Support\Str;

class AvailabilityOptimizationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
    }

    public function test_baseline_equivalence()
    {
        // Creator with 0 capacity, no override -> SHOULD BE PRE-FILTERED OUT
        $unavailableCreator = User::create([
            'id' => Str::uuid(), 'name' => 'C1', 'email' => 'c1@ex.com', 'username' => 'c1', 'password' => bcrypt('123'),
            'role' => \App\Enums\RoleType::Creator, 'is_creator_approved' => true, 'max_work_capacity' => 0
        ]);
        MarketplaceItem::create(['user_id' => $unavailableCreator->id, 'title' => 'T1', 'description' => 'D', 'price' => 10, 'delivery_type' => 'service', 'status' => 'published', 'category' => 'wedding']);

        // Creator with 0 capacity BUT has positive override -> SHOULD NOT BE PRE-FILTERED
        $availableCreator = User::create([
            'id' => Str::uuid(), 'name' => 'C2', 'email' => 'c2@ex.com', 'username' => 'c2', 'password' => bcrypt('123'),
            'role' => \App\Enums\RoleType::Creator, 'is_creator_approved' => true, 'max_work_capacity' => 0
        ]);
        MarketplaceItem::create(['user_id' => $availableCreator->id, 'title' => 'T2', 'description' => 'D', 'price' => 10, 'delivery_type' => 'service', 'status' => 'published', 'category' => 'wedding']);
        CreatorCapacitySchedule::create([
            'creator_id' => $availableCreator->id, 'date' => '2026-10-05', 'max_capacity' => 1, 'is_unavailable' => false
        ]);

        $this->withoutExceptionHandling();
        $response = $this->getJson('/api/creators/recommendations?start_date=2026-10-05&end_date=2026-10-05');
        $ids = collect($response->json('data'))->pluck('id')->toArray();

        $this->assertNotContains($unavailableCreator->id, $ids);
        $this->assertContains($availableCreator->id, $ids);
    }
}
