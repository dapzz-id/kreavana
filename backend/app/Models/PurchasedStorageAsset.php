<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

use Illuminate\Database\Eloquent\Concerns\HasUuids;

class PurchasedStorageAsset extends Model
{
    use HasUuids;

    protected $fillable = [
        'buyer_id',
        'order_id',
        'marketplace_asset_id',
        'source_storage_file_id',
        'cloned_storage_file_id',
        'status',
        'clone_attempts',
        'last_clone_attempt_at',
    ];

    protected $casts = [
        'last_clone_attempt_at' => 'datetime',
    ];

    public function buyer()
    {
        return $this->belongsTo(User::class, 'buyer_id');
    }

    public function order()
    {
        return $this->belongsTo(MarketplacePurchase::class, 'order_id');
    }

    public function marketplaceAsset()
    {
        return $this->belongsTo(MarketplaceItem::class, 'marketplace_asset_id');
    }

    public function sourceFile()
    {
        return $this->belongsTo(StorageFile::class, 'source_storage_file_id');
    }

    public function clonedFile()
    {
        return $this->belongsTo(StorageFile::class, 'cloned_storage_file_id');
    }
}
