<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class RefreshToken extends Model
{
    use HasUuids;

    protected $fillable = [
        'id', // The selector
        'user_session_id',
        'token_hash',
        'is_active',
        'expires_at',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'expires_at' => 'datetime',
    ];

    public function userSession()
    {
        return $this->belongsTo(UserSession::class);
    }
}
