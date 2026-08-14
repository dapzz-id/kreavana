<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class UserDevice extends Model
{
    use HasUuids;

    protected $fillable = [
        'user_id',
        'device_id',
        'public_key',
        'fcm_token',
        'is_active',
        'revoked_at',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'revoked_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
