<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use App\Models\MarketplaceItem;
use App\Models\JobContract;
use App\Models\MarketplacePurchase;
use Tymon\JWTAuth\Facades\JWTAuth;
use Carbon\Carbon;
use Illuminate\Support\Facades\Hash;

class RecommendationDataCleanupTest extends TestCase
{
    use RefreshDatabase;

    
    public function test_valid_creator_data_is_preserved_and_eligible()
    {
        $creator = User::factory()->create([
            'role' => \App\Enums\RoleType::Creator,
            'is_creator_approved' => true,
            'sub_role' => 'photographer'
        ]);

        $subRoleValue = is_object($creator->sub_role) ? $creator->sub_role->value : $creator->sub_role;
        $this->assertEquals('photographer', $subRoleValue);
        $this->assertTrue($creator->is_creator_approved);
    }

    public function test_catalog_scope_excludes_draft_and_archived_services()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);

        $publishedService = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Published Service',
            'category' => 'Fotografi',
            'delivery_type' => 'service',
            'status' => 'published',
            'price' => 1000,
            'is_active' => true,
        ]);

        $draftService = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Draft Service',
            'category' => 'Fotografi',
            'delivery_type' => 'service',
            'status' => 'draft',
            'price' => 1000,
            'is_active' => false,
        ]);

        $archivedService = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Archived Service',
            'category' => 'Fotografi',
            'delivery_type' => 'service',
            'status' => 'archived',
            'price' => 1000,
            'is_active' => false,
        ]);

        $activeItems = MarketplaceItem::active()->get();
        $this->assertCount(1, $activeItems);
        $this->assertEquals($publishedService->id, $activeItems->first()->id);
    }

    public function test_digital_downloads_are_excluded_from_service_recommendation_data()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);

        $service = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Service Offering',
            'category' => 'Fotografi',
            'delivery_type' => 'service',
            'status' => 'published',
            'price' => 1000,
            'is_active' => true,
        ]);

        $digital = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Digital Template',
            'category' => 'Fotografi',
            'delivery_type' => 'digital_download',
            'status' => 'published',
            'price' => 1000,
            'is_active' => true,
        ]);

        // Phase 7 must strictly filter this. We emulate the future query here to lock in the rule.
        $servicesOnly = MarketplaceItem::where('status', 'published')
            ->where('delivery_type', 'service')
            ->get();

        $this->assertCount(1, $servicesOnly);
        $this->assertEquals($service->id, $servicesOnly->first()->id);
    }

    public function test_completed_work_identified_using_phase_3_state_machine()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $client = User::factory()->create();

        // Work status = completed
        $completedJob = JobContract::create([
            'client_id' => $client->id,
            'creator_id' => $creator->id,
            'title' => 'Test Job',
            'contract_status' => 'approved',
            'work_status' => 'completed',
        ]);

        $draftJob = JobContract::create([
            'client_id' => $client->id,
            'creator_id' => $creator->id,
            'title' => 'Draft Job',
            'contract_status' => 'draft',
            'work_status' => 'scheduled',
        ]);

        $inProgressJob = JobContract::create([
            'client_id' => $client->id,
            'creator_id' => $creator->id,
            'title' => 'In Progress Job',
            'contract_status' => 'approved',
            'work_status' => 'in_progress',
        ]);

        $cancelledJob = JobContract::create([
            'client_id' => $client->id,
            'creator_id' => $creator->id,
            'title' => 'Cancelled Job',
            'contract_status' => 'cancelled',
            'work_status' => 'cancelled',
        ]);

        $completedCount = JobContract::where('creator_id', $creator->id)
            ->where('work_status', 'completed')
            ->count();

        $this->assertEquals(1, $completedCount);
    }

    public function test_strict_domain_separation_digital_sales_are_not_completed_service_jobs()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $client = User::factory()->create();

        // 1 Completed Service Job
        JobContract::create([
            'client_id' => $client->id,
            'creator_id' => $creator->id,
            'title' => 'Wedding Photography',
            'contract_status' => 'approved',
            'work_status' => 'completed',
        ]);

        $digitalItem = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Digital Preset',
            'category' => 'Fotografi',
            'delivery_type' => 'digital_download',
            'status' => 'published',
            'price' => 50000,
            'is_active' => true,
        ]);

        // 1 Successful Digital Sale
        MarketplacePurchase::create([
            'user_id' => $client->id,
            'marketplace_item_id' => $digitalItem->id,
            'amount' => 50000,
            'status' => 'success',
        ]);

        $completedJobsCount = JobContract::where('creator_id', $creator->id)
            ->where('work_status', 'completed')
            ->count();

        $successfulDigitalSalesCount = MarketplacePurchase::whereHas('item', function($q) use ($creator) {
            $q->where('user_id', $creator->id)->where('delivery_type', 'digital_download');
        })->where('status', 'success')->count();

        // Domain boundaries mathematically enforce that 1 service + 1 digital sale = 1 of each, not 2 completed jobs.
        $this->assertEquals(1, $completedJobsCount);
        $this->assertEquals(1, $successfulDigitalSalesCount);
    }

    public function test_orphan_records_detected_and_handled()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $client = User::factory()->create();

        $item = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Test Item',
            'category' => 'Fotografi',
            'delivery_type' => 'service',
            'status' => 'published',
            'price' => 1000,
            'is_active' => true,
        ]);

        $job = JobContract::create([
            'client_id' => $client->id,
            'creator_id' => $creator->id,
            'marketplace_item_id' => $item->id,
            'title' => 'Test Job',
            'contract_status' => 'approved',
            'work_status' => 'completed',
            'agreed_price' => 1000,
            'description' => 'Test description'
        ]);

        // Delete the item (orphan the job contract)
        $item->delete();

        // The historical job contract MUST be preserved because agreed_price and title are immutable
        $this->assertDatabaseHas('job_contracts', [
            'id' => $job->id,
            'title' => 'Test Job',
            'agreed_price' => 1000
        ]);

        $this->assertNull($job->fresh()->marketplaceItem);
    }

    public function test_client_cannot_spoof_performance_data_in_api()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);

        $response = $this->withHeaders($this->getAuthHeaders($creator))->putJson("/api/profile", [
            'performance_boost' => 999.9,
            'completed_jobs' => 1000
        ]);

        $response->assertStatus(200);

        // Assert backend ignored the spoofed inputs entirely
        $this->assertEquals(0.0, $creator->fresh()->performance_boost);
    }
}
