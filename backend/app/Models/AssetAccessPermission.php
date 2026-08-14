<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class AssetAccessPermission extends Model
{
    use HasUuids;

    protected $fillable = [
        'user_id',
        'marketplace_item_id',
        'can_download',
        'can_clone',
        'expires_at',
    ];

    protected function casts(): array
    {
        return [
            'can_download' => 'boolean',
            'can_clone' => 'boolean',
            'expires_at' => 'datetime',
        ];
    }
}
