<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\MarketplaceItem;
use App\Models\CreatorService;
use App\Models\JobContract;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ProductCatalogTest extends TestCase
{
    use RefreshDatabase;

    public function test_catalog_item_creation_defaults_to_draft()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);

        $response = $this->actingAs($creator, 'api')->postJson('/api/marketplace', [
            'title' => 'Test Digital Asset',
            'description' => 'A great asset',
            'category' => 'Fotografi',
            'type' => 'paid',
            'price' => 500000,
        ]);

        $response->assertStatus(201);
        
        $item = MarketplaceItem::first();
        $this->assertEquals('draft', $item->status);
        $this->assertFalse((bool)$item->is_active);
    }

    public function test_creator_can_publish_and_archive_catalog()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $item = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Test',
            'category' => 'Fotografi',
            'type' => 'paid',
            'price' => 100,
            'status' => 'draft',
            'is_active' => false,
        ]);

        $publishResponse = $this->actingAs($creator, 'api')->postJson("/api/marketplace/{$item->id}/publish");
        $publishResponse->assertStatus(200);
        $this->assertEquals('published', $item->fresh()->status);
        $this->assertTrue((bool)$item->fresh()->is_active);

        $archiveResponse = $this->actingAs($creator, 'api')->postJson("/api/marketplace/{$item->id}/archive");
        $archiveResponse->assertStatus(200);
        $this->assertEquals('archived', $item->fresh()->status);
        $this->assertFalse((bool)$item->fresh()->is_active);
    }

    public function test_public_catalog_only_shows_published_items()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        MarketplaceItem::create(['user_id' => $creator->id, 'title' => 'Pub', 'category' => 'Fotografi', 'type' => 'paid', 'price' => 100, 'status' => 'published', 'is_active' => true]);
        MarketplaceItem::create(['user_id' => $creator->id, 'title' => 'Dra', 'category' => 'Fotografi', 'type' => 'paid', 'price' => 100, 'status' => 'draft', 'is_active' => false]);
        MarketplaceItem::create(['user_id' => $creator->id, 'title' => 'Arc', 'category' => 'Fotografi', 'type' => 'paid', 'price' => 100, 'status' => 'archived', 'is_active' => false]);

        $response = $this->getJson('/api/marketplace');
        $response->assertStatus(200);
        $response->assertJsonCount(1, 'data.data');
        $response->assertJsonPath('data.data.0.title', 'Pub');
    }

    public function test_creator_cannot_modify_another_creators_catalog()
    {
        $creator1 = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $creator2 = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $item = MarketplaceItem::create([
            'user_id' => $creator1->id,
            'title' => 'Test',
            'category' => 'Fotografi',
            'type' => 'paid',
            'price' => 100,
        ]);

        $response = $this->actingAs($creator2, 'api')->putJson("/api/marketplace/{$item->id}", ['title' => 'Hacked']);
        $response->assertStatus(404);
        
        $responsePublish = $this->actingAs($creator2, 'api')->postJson("/api/marketplace/{$item->id}/publish");
        $responsePublish->assertStatus(404);
    }

    public function test_job_contract_integration_with_published_service()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        
        $service = CreatorService::create([
            'creator_id' => $creator->id,
            'title' => 'Wedding MC Package',
            'description' => 'MC for wedding',
            'category' => 'Konten',
            'price' => 5000000,
            'status' => 'active',
        ]);

        $response = $this->actingAs($client, 'api')->postJson('/api/contracts', [
            'partner_id' => $creator->id,
            'my_role' => 'client',
            'creator_service_id' => $service->id,
            'scheduled_start_date' => date('Y-m-d', strtotime('+1 day')),
            'scheduled_end_date' => date('Y-m-d', strtotime('+1 day')),
        ]);

        $response->assertStatus(201);
        $this->assertEquals($service->id, $response->json('data.creator_service_id'));
        $this->assertEquals('Wedding MC Package', $response->json('data.title'));
        $this->assertEquals('MC for wedding', $response->json('data.description'));
        $this->assertEquals('5000000.00', $response->json('data.agreed_price'));
    }

    public function test_job_contract_rejects_inactive_service()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        
        $inactiveService = CreatorService::create([
            'creator_id' => $creator->id,
            'title' => 'Draft Service', 'category' => 'Konten', 'price' => 500, 'status' => 'inactive',
        ]);

        $res1 = $this->actingAs($client, 'api')->postJson('/api/contracts', [
            'partner_id' => $creator->id, 'my_role' => 'client', 'creator_service_id' => $inactiveService->id, 'scheduled_start_date' => date('Y-m-d'), 'scheduled_end_date' => date('Y-m-d'),
        ]);
        $res1->assertStatus(400)->assertJsonPath('message', 'Layanan tidak tersedia.');
    }

    public function test_historical_integrity_of_contract_snapshot()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        
        $service = CreatorService::create([
            'creator_id' => $creator->id,
            'title' => 'Pre-Wedding Photo',
            'category' => 'Fotografi',
            'price' => 2000000,
            'status' => 'active',
        ]);

        $this->actingAs($client, 'api')->postJson('/api/contracts', [
            'partner_id' => $creator->id,
            'my_role' => 'client',
            'creator_service_id' => $service->id,
            'scheduled_start_date' => date('Y-m-d', strtotime('+1 day')),
            'scheduled_end_date' => date('Y-m-d', strtotime('+1 day')),
        ]);

        $contract = JobContract::first();
        $this->assertEquals(2000000, $contract->agreed_price);

        // Creator changes the price and title in service
        $this->actingAs($creator, 'api')->putJson("/api/creator-services/{$service->id}", [
            'title' => 'Pre-Wedding Photo (Premium)',
            'price' => 3500000
        ]);

        // Existing contract MUST remain unaffected
        $contract->refresh();
        $this->assertEquals(2000000, $contract->agreed_price);
        $this->assertEquals('Pre-Wedding Photo', $contract->title);
    }
}
