<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ClientApp extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'client_id',
        'client_name',
        'client_secret',
        'redirect_uris',
        'allowed_scopes',
        'is_active',
    ];

    protected $hidden = [
        'client_secret',
    ];

    protected $casts = [
        'allowed_scopes' => 'array',
        'is_active' => 'boolean',
    ];
}
