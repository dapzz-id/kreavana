<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class MarketplaceItemMedia extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'marketplace_item_id',
        'file_path',
        'watermarked_file_path',
        'file_type',
    ];

    public function item()
    {
        return $this->belongsTo(MarketplaceItem::class, 'marketplace_item_id');
    }
}
