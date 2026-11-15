<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class InstitutionSubAccount extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'user_id',
        'institution_id',
        'institution_resource_id',
        'password_hash',
        'is_active',
        'password_changed_at',
    ];

    protected $hidden = [
        'password_hash',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'password_changed_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function institution(): BelongsTo
    {
        return $this->belongsTo(User::class, 'institution_id');
    }

    public function institutionResource(): BelongsTo
    {
        return $this->belongsTo(InstitutionResource::class, 'institution_resource_id');
    }
}
