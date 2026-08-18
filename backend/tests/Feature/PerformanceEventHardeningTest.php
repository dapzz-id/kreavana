<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use App\Models\CreatorPerformanceEvent;
use Illuminate\Support\Str;

class PerformanceEventHardeningTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
    }

    public function test_atomic_performance_boost_update()
    {
        $creator = User::create([
            'id' => Str::uuid(), 'name' => 'C1', 'email' => 'c1@ex.com', 'username' => 'c1', 'password' => bcrypt('123'),
            'role' => \App\Enums\RoleType::Creator, 'is_creator_approved' => true, 'performance_boost' => 0
        ]);

        CreatorPerformanceEvent::create(['user_id' => $creator->id, 'event_type' => 'project_rating', 'reference_id' => '1', 'bonus_percentage' => 1.0, 'is_active' => true]);
        CreatorPerformanceEvent::create(['user_id' => $creator->id, 'event_type' => 'project_rating', 'reference_id' => '2', 'bonus_percentage' => 1.5, 'is_active' => true]);

        $creator->updatePerformanceBoost();

        $this->assertEquals(2.5, $creator->fresh()->performance_boost);
    }
}
