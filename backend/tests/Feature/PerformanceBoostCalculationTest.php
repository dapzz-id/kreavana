<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use App\Models\CreatorPerformanceEvent;

class PerformanceBoostCalculationTest extends TestCase
{
    use RefreshDatabase;

    public function test_basic_plus_project()
    {
        $user = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        CreatorPerformanceEvent::create(['user_id' => $user->id, 'event_type' => 'project', 'reference_id' => '1', 'bonus_percentage' => 1.0]);
        $user->refresh();
        $user->updatePerformanceBoost();
        $this->assertEquals(1.0, $user->fresh()->performance_boost);
    }

    public function test_plus_plus_project()
    {
        $user = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $user->subscriptions()->create(['tier' => 'plus', 'expires_at' => now()->addDays(30)]);
        CreatorPerformanceEvent::create(['user_id' => $user->id, 'event_type' => 'project', 'reference_id' => '1', 'bonus_percentage' => 1.0]);
        $user->refresh();
        $user->updatePerformanceBoost();
        $this->assertEquals(1.5, $user->fresh()->performance_boost);
    }

    public function test_pro_plus_project()
    {
        $user = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $user->subscriptions()->create(['tier' => 'pro', 'expires_at' => now()->addDays(30)]);
        CreatorPerformanceEvent::create(['user_id' => $user->id, 'event_type' => 'project', 'reference_id' => '1', 'bonus_percentage' => 1.0]);
        $user->refresh();
        $user->updatePerformanceBoost();
        $this->assertEquals(2.0, $user->fresh()->performance_boost);
    }

    public function test_super_plus_project()
    {
        $user = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $user->subscriptions()->create(['tier' => 'super', 'expires_at' => now()->addDays(30)]);
        CreatorPerformanceEvent::create(['user_id' => $user->id, 'event_type' => 'project', 'reference_id' => '1', 'bonus_percentage' => 1.0]);
        $user->refresh();
        $user->updatePerformanceBoost();
        $this->assertEquals(5.0, $user->fresh()->performance_boost);
    }

    public function test_super_plus_marketplace()
    {
        $user = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $user->subscriptions()->create(['tier' => 'super', 'expires_at' => now()->addDays(30)]);
        CreatorPerformanceEvent::create(['user_id' => $user->id, 'event_type' => 'marketplace', 'reference_id' => '1', 'bonus_percentage' => 0.5]);
        $user->refresh();
        $user->updatePerformanceBoost();
        $this->assertEquals(2.5, $user->fresh()->performance_boost);
    }

    public function test_super_plus_project_plus_marketplace()
    {
        $user = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $user->subscriptions()->create(['tier' => 'super', 'expires_at' => now()->addDays(30)]);
        CreatorPerformanceEvent::create(['user_id' => $user->id, 'event_type' => 'project', 'reference_id' => '1', 'bonus_percentage' => 1.0]);
        CreatorPerformanceEvent::create(['user_id' => $user->id, 'event_type' => 'marketplace', 'reference_id' => '2', 'bonus_percentage' => 0.5]);
        $user->refresh();
        $user->updatePerformanceBoost();
        $this->assertEquals(7.5, $user->fresh()->performance_boost);
    }

    public function test_super_plus_2_projects_plus_3_marketplace_sales()
    {
        $user = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $user->subscriptions()->create(['tier' => 'super', 'expires_at' => now()->addDays(30)]);
        CreatorPerformanceEvent::create(['user_id' => $user->id, 'event_type' => 'project', 'reference_id' => '1', 'bonus_percentage' => 1.0]);
        CreatorPerformanceEvent::create(['user_id' => $user->id, 'event_type' => 'project', 'reference_id' => '2', 'bonus_percentage' => 1.0]);
        CreatorPerformanceEvent::create(['user_id' => $user->id, 'event_type' => 'marketplace', 'reference_id' => '3', 'bonus_percentage' => 0.5]);
        CreatorPerformanceEvent::create(['user_id' => $user->id, 'event_type' => 'marketplace', 'reference_id' => '4', 'bonus_percentage' => 0.5]);
        CreatorPerformanceEvent::create(['user_id' => $user->id, 'event_type' => 'marketplace', 'reference_id' => '5', 'bonus_percentage' => 0.5]);
        $user->refresh();
        $user->updatePerformanceBoost();
        
        $this->assertEquals(17.5, $user->fresh()->performance_boost);
    }

    public function test_subscription_upgrade_recalculation()
    {
        $user = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        CreatorPerformanceEvent::create(['user_id' => $user->id, 'event_type' => 'project', 'reference_id' => '1', 'bonus_percentage' => 1.0]);
        $user->refresh();
        $user->updatePerformanceBoost();
        
        $this->assertEquals(1.0, $user->fresh()->performance_boost);
        
        $user->subscriptions()->create(['tier' => 'plus', 'expires_at' => now()->addDays(30)]);
        $user->refresh();
        $user->updatePerformanceBoost();
        
        $this->assertEquals(1.5, $user->fresh()->performance_boost);
    }
}
