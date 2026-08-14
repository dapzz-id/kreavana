<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class UserSession extends Model
{
    use HasUuids;

    protected $fillable = [
        'user_id',
        'device_id',
        'device_name',
        'platform',
        'ip_address',
        'user_agent',
        'revoked_at',
        'expires_at',
        'last_used_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'revoked_at' => 'datetime',
        'last_used_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function refreshTokens()
    {
        return $this->hasMany(RefreshToken::class);
    }
}
