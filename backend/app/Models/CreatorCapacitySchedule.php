<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CreatorCapacitySchedule extends Model
{
    use HasUuids;

    protected $fillable = [
        'creator_id',
        'date',
        'max_capacity',
        'is_unavailable',
        'notes',
    ];

    protected $casts = [
        'date' => 'date',
        'max_capacity' => 'integer',
        'is_unavailable' => 'boolean',
    ];

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'creator_id');
    }
}
