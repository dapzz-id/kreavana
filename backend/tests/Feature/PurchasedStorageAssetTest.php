<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\WithFaker;
use Tests\TestCase;
use App\Models\User;
use App\Models\StorageFile;
use App\Models\MarketplaceItem;
use App\Models\MarketplacePurchase;
use App\Models\PurchasedStorageAsset;
use Illuminate\Support\Facades\Storage;
use App\Services\StorageService;
use Illuminate\Http\UploadedFile;

class PurchasedStorageAssetTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('private');
    }

    public function test_double_retry_spam()
    {
        $buyer = User::factory()->create(['used_storage_bytes' => 0]);
        $creator = User::factory()->create();

        $sourceFile = StorageFile::create([
            'user_id' => $creator->id,
            'original_name' => 'test.jpg',
            'stored_name' => 'test.jpg',
            'disk' => 'private',
            'path' => 'marketplace_original/test.jpg',
            'category' => 'marketplace_original',
            'size' => 1024,
        ]);

        $item = MarketplaceItem::create([
            'user_id' => $creator->id,
            'title' => 'Test Item',
            'slug' => 'test-item',
            'description' => 'Test description',
            'price' => 10000,
            'category' => 'photo',
            'status' => 'published',
        ]);
        $order = MarketplacePurchase::create([
            'user_id' => $buyer->id,
            'marketplace_item_id' => $item->id,
            'amount' => 10000,
            'status' => 'success'
        ]);

        $asset = PurchasedStorageAsset::create([
            'buyer_id' => $buyer->id,
            'order_id' => $order->id,
            'marketplace_asset_id' => $item->id,
            'source_storage_file_id' => $sourceFile->id,
            'status' => 'pending_storage',
        ]);

        // Simulate concurrent requests
        $response1 = $this->actingAs($buyer, 'api')->postJson("/api/storage/purchased/{$asset->id}/retry");
        $response1->assertStatus(200);

        // Second should fail because it is already cloned
        $response2 = $this->actingAs($buyer, 'api')->postJson("/api/storage/purchased/{$asset->id}/retry");
        $response2->assertStatus(400);

        $this->assertEquals(1, StorageFile::where('category', 'purchased_asset')->count());
    }

    public function test_creator_delete_physical_survival()
    {
        $buyer = User::factory()->create(['used_storage_bytes' => 0]);
        $creator = User::factory()->create();

        $fakeFile = UploadedFile::fake()->image('photo.jpg');
        $path = $fakeFile->store('marketplace_original', 'private');

        $sourceFile = StorageFile::create([
            'user_id' => $creator->id,
            'original_name' => 'photo.jpg',
            'stored_name' => 'photo.jpg',
            'disk' => 'private',
            'path' => $path,
            'category' => 'marketplace_original',
            'size' => 1024,
        ]);

        $storageService = app(StorageService::class);
        $clonedFile = $storageService->cloneToUser($sourceFile, $buyer);

        $this->assertTrue(Storage::disk('private')->exists($path));

        // Creator deletes original
        $storageService->delete($sourceFile, $creator, 'Test delete', '127.0.0.1', 'test');

        // Physical file MUST survive because buyer cloned file still exists
        $this->assertTrue(Storage::disk('private')->exists($path));
        $this->assertSoftDeleted($sourceFile);
        
        // Buyer deletes clone
        $storageService->delete($clonedFile, $buyer, 'Test delete clone', '127.0.0.1', 'test');

        // Now physical file should be deleted
        $this->assertFalse(Storage::disk('private')->exists($path));
    }
}
