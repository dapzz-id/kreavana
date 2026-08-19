<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class CreatorService extends Model
{
    use HasUuids, HasFactory;

    protected $fillable = [
        'creator_id',
        'title',
        'description',
        'category',
        'price',
        'duration_info',
        'status',
    ];

    protected $casts = [
        'price' => 'decimal:2',
    ];

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'creator_id');
    }

    public function jobContracts(): HasMany
    {
        return $this->hasMany(JobContract::class, 'creator_service_id');
    }
}
