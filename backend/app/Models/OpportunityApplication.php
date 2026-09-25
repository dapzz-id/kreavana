<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class OpportunityApplication extends Model
{
    use HasUuids;

    protected $fillable = [
        'opportunity_id',
        'creator_id',
        'sub_role_slug',
        'pitch_message',
        'questions_notes',
        'submitted_documents',
        'bid_price',
        'status',
        'rejection_reason',
        'reviewed_at',
    ];

    protected $casts = [
        'bid_price' => 'decimal:2',
        'submitted_documents' => 'array',
        'reviewed_at' => 'datetime',
    ];

    public function opportunity(): BelongsTo
    {
        return $this->belongsTo(Opportunity::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'creator_id');
    }
}
