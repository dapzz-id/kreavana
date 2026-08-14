<?php

namespace App\Jobs;

use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use App\Models\User;
use App\Models\MarketplacePurchase;
use App\Models\StorageFile;
use App\Services\StorageService;

class ClonePurchasedAssetsJob implements ShouldQueue, ShouldBeUnique
{
    use Queueable, InteractsWithQueue, SerializesModels;

    public $orderId;
    public $buyerId;
    public $marketplaceItemId;
    public $sourceFileIds;

    public $uniqueFor = 3600;

    public function uniqueId(): string
    {
        return $this->orderId;
    }

    /**
     * Create a new job instance.
     */
    public function __construct(string $orderId, string $buyerId, string $marketplaceItemId, array $sourceFileIds)
    {
        $this->orderId = $orderId;
        $this->buyerId = $buyerId;
        $this->marketplaceItemId = $marketplaceItemId;
        $this->sourceFileIds = $sourceFileIds;
    }

    /**
     * Execute the job.
     */
    public function handle(StorageService $storageService): void
    {
        $buyer = User::find($this->buyerId);
        $order = MarketplacePurchase::find($this->orderId);
        
        if (!$buyer || !$order) return;

        // Idempotency check: filter out already cloned
        $alreadyClonedIds = \App\Models\PurchasedStorageAsset::where('order_id', $order->id)
            ->where('status', 'cloned')
            ->pluck('source_storage_file_id')->toArray();

        $sourceFileIdsToProcess = array_diff($this->sourceFileIds, $alreadyClonedIds);
        if (empty($sourceFileIdsToProcess)) {
            $order->update(['storage_sync_status' => 'completed']);
            return;
        }

        $sourceFiles = StorageFile::whereIn('id', $sourceFileIdsToProcess)->get();
        if ($sourceFiles->isEmpty()) return;

        // Chunking by size (max 10GB per chunk)
        $maxSize = 10 * 1024 * 1024 * 1024; // 10GB
        $currentChunkSize = 0;
        $currentChunkIds = [];
        $remainingIds = [];

        foreach ($sourceFiles as $file) {
            if ($currentChunkSize + $file->size <= $maxSize) {
                $currentChunkIds[] = $file->id;
                $currentChunkSize += $file->size;
            } else {
                $remainingIds[] = $file->id;
            }
        }

        $filesToClone = $sourceFiles->whereIn('id', $currentChunkIds);

        $cloneResult = $storageService->cloneManyToUser($filesToClone, $buyer);
        
        $bulkAssets = [];
        $now = now();
        
        foreach ($cloneResult['cloned'] as $clonedItem) {
            $bulkAssets[] = [
                'id' => \Illuminate\Support\Str::uuid()->toString(),
                'buyer_id' => $buyer->id,
                'order_id' => $order->id,
                'marketplace_asset_id' => $this->marketplaceItemId,
                'source_storage_file_id' => $clonedItem->source_storage_file_id,
                'cloned_storage_file_id' => $clonedItem->id,
                'status' => 'cloned',
                'clone_attempts' => 1,
                'last_clone_attempt_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        foreach ($cloneResult['pending'] as $pendingItem) {
            $bulkAssets[] = [
                'id' => \Illuminate\Support\Str::uuid()->toString(),
                'buyer_id' => $buyer->id,
                'order_id' => $order->id,
                'marketplace_asset_id' => $this->marketplaceItemId,
                'source_storage_file_id' => $pendingItem->id,
                'cloned_storage_file_id' => null,
                'status' => 'pending_storage',
                'clone_attempts' => 1,
                'last_clone_attempt_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        foreach (array_chunk($bulkAssets, 100) as $chunk) {
            \App\Models\PurchasedStorageAsset::insertOrIgnore($chunk);
        }

        $totalSuccess = count($cloneResult['cloned']);
        $totalPending = count($cloneResult['pending']);

        // Check if there are remaining files to process in a new Job
        if (!empty($remainingIds)) {
            // Dispatch next chunk
            self::dispatch($this->orderId, $this->buyerId, $this->marketplaceItemId, $remainingIds);
            
            // Mark as partial for now
            $order->update(['storage_sync_status' => 'partial']);
        } else {
            // Finalize order sync status
            $pendingInDB = \App\Models\PurchasedStorageAsset::where('order_id', $order->id)->where('status', 'pending_storage')->exists();
            if ($pendingInDB) {
                // Check if any success
                $successInDB = \App\Models\PurchasedStorageAsset::where('order_id', $order->id)->where('status', 'cloned')->exists();
                $order->update(['storage_sync_status' => $successInDB ? 'partial' : 'pending']);
            } else {
                $order->update(['storage_sync_status' => 'completed']);
            }

            \App\Models\SystemLog::create([
                'id' => \Illuminate\Support\Str::uuid()->toString(),
                'user_id' => $this->buyerId,
                'action' => 'bulk_clone_completed',
                'title' => 'Bulk Clone Completed (Job)',
                'description' => 'Successfully finished background clone for order ' . $order->id,
                'type' => 'info',
                'metadata' => json_encode(['order_id' => $order->id]),
            ]);
        }
    }
}
