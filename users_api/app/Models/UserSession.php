<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class UserSession extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'user_id',
        'client_id',
        'refresh_token_id',
        'ip_address',
        'user_agent',
        'device_id',
        'is_revoked',
        'last_active_at',
        'expires_at',
    ];

    protected $casts = [
        'is_revoked' => 'boolean',
        'last_active_at' => 'datetime',
        'expires_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
