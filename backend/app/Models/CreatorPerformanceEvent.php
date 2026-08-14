<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class CreatorPerformanceEvent extends Model
{
    use HasUuids;

    protected $fillable = [
        'user_id',
        'event_type',
        'reference_id',
        'bonus_percentage',
        'is_active',
    ];

    protected $casts = [
        'bonus_percentage' => 'decimal:2',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
