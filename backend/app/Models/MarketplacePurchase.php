<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class MarketplacePurchase extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'user_id',
        'marketplace_item_id',
        'amount',
        'status',
        'storage_sync_status',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function item()
    {
        return $this->belongsTo(MarketplaceItem::class, 'marketplace_item_id');
    }
}
