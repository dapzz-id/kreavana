<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Collaboration extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'requester_id', 'project_title', 'description', 'project_location',
        'status', 'start_date', 'end_date', 'budget_min', 'budget_max',
        'notes', 'reject_reason', 'responded_at',
    ];

    protected function casts(): array
    {
        return [
            'start_date'    => 'date',
            'end_date'      => 'date',
            'budget_min'    => 'decimal:2',
            'budget_max'    => 'decimal:2',
            'responded_at'  => 'datetime',
        ];
    }

    public function requester(): BelongsTo
    {
        return $this->belongsTo(User::class, 'requester_id');
    }

    public function members(): HasMany
    {
        return $this->hasMany(CollaborationMember::class);
    }
}
