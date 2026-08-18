<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\MarketplaceItem;
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
            'title' => 'Test Service Package',
            'description' => 'A great service package',
            'category' => 'Fotografi',
            'type' => 'paid',
            'delivery_type' => 'service',
            'duration_info' => '2 Hari',
            'price' => 500000,
        ]);

        $response->assertStatus(201);
        
        $item = MarketplaceItem::first();
        $this->assertEquals('draft', $item->status);
        $this->assertEquals('service', $item->delivery_type);
        $this->assertEquals('2 Hari', $item->duration_info);
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
        
        $item = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Wedding MC Package',
            'description' => 'MC for wedding',
            'category' => 'Konten',
            'type' => 'paid',
            'delivery_type' => 'service',
            'price' => 5000000,
            'status' => 'published',
            'is_active' => true,
        ]);

        $response = $this->actingAs($client, 'api')->postJson('/api/contracts', [
            'partner_id' => $creator->id,
            'my_role' => 'client',
            'marketplace_item_id' => $item->id,
            'scheduled_start_date' => date('Y-m-d', strtotime('+1 day')),
            'scheduled_end_date' => date('Y-m-d', strtotime('+1 day')),
        ]);

        $response->assertStatus(201);
        $this->assertEquals($item->id, $response->json('data.marketplace_item_id'));
        $this->assertEquals('Wedding MC Package', $response->json('data.title'));
        $this->assertEquals('MC for wedding', $response->json('data.description'));
        $this->assertEquals('5000000.00', $response->json('data.agreed_price'));
    }

    public function test_job_contract_rejects_draft_or_archived_or_digital_download()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        
        $draftItem = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Draft Service', 'category' => 'Konten', 'type' => 'paid', 'delivery_type' => 'service', 'price' => 500, 'status' => 'draft', 'is_active' => false,
        ]);
        
        $digitalItem = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Digital Logo', 'category' => 'Desain', 'type' => 'paid', 'delivery_type' => 'digital_download', 'price' => 500, 'status' => 'published', 'is_active' => true,
        ]);

        // Draft should fail
        $res1 = $this->actingAs($client, 'api')->postJson('/api/contracts', [
            'partner_id' => $creator->id, 'my_role' => 'client', 'marketplace_item_id' => $draftItem->id, 'scheduled_start_date' => date('Y-m-d'), 'scheduled_end_date' => date('Y-m-d'),
        ]);
        $res1->assertStatus(400)->assertJsonPath('message', 'Katalog item tidak tersedia (draft/archived).');

        // Digital should fail
        $res2 = $this->actingAs($client, 'api')->postJson('/api/contracts', [
            'partner_id' => $creator->id, 'my_role' => 'client', 'marketplace_item_id' => $digitalItem->id, 'scheduled_start_date' => date('Y-m-d'), 'scheduled_end_date' => date('Y-m-d'),
        ]);
        $res2->assertStatus(400)->assertJsonPath('message', 'Hanya item dengan tipe layanan (service) yang dapat dijadikan kontrak.');
    }

    public function test_historical_integrity_of_contract_snapshot()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        
        $item = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Pre-Wedding Photo',
            'category' => 'Fotografi',
            'type' => 'paid',
            'delivery_type' => 'service',
            'price' => 2000000,
            'status' => 'published',
            'is_active' => true,
        ]);

        $this->actingAs($client, 'api')->postJson('/api/contracts', [
            'partner_id' => $creator->id,
            'my_role' => 'client',
            'marketplace_item_id' => $item->id,
            'scheduled_start_date' => date('Y-m-d', strtotime('+1 day')),
            'scheduled_end_date' => date('Y-m-d', strtotime('+1 day')),
        ]);

        $contract = JobContract::first();
        $this->assertEquals(2000000, $contract->agreed_price);

        // Creator changes the price and title in catalog
        $this->actingAs($creator, 'api')->putJson("/api/marketplace/{$item->id}", [
            'title' => 'Pre-Wedding Photo (Premium)',
            'price' => 3500000
        ]);

        // Existing contract MUST remain unaffected
        $contract->refresh();
        $this->assertEquals(2000000, $contract->agreed_price);
        $this->assertEquals('Pre-Wedding Photo', $contract->title);
    }
}
