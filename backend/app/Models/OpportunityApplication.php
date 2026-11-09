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
        'counter_offer_price',
        'counter_offer_notes',
        'counter_offer_status',
        'counter_offer_by',
        'dynamic_terms',
        'creator_signature',
        'creator_signed_at',
        'payment_scheme',
        'payment_terms',
        'paid_amount',
        'payment_status',
        'worker_progress',
        'worker_status',
        'revision_notes',
        'submitted_deliverables',
        'grace_period_deadline',
        'auto_released_at',
        'status',
        'rejection_reason',
        'reviewed_at',
    ];

    protected $casts = [
        'bid_price' => 'decimal:2',
        'counter_offer_price' => 'decimal:2',
        'submitted_documents' => 'array',
        'submitted_deliverables' => 'array',
        'dynamic_terms' => 'array',
        'payment_terms' => 'array',
        'paid_amount' => 'decimal:2',
        'worker_progress' => 'integer',
        'reviewed_at' => 'datetime',
        'creator_signed_at' => 'datetime',
        'grace_period_deadline' => 'datetime',
        'auto_released_at' => 'datetime',
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
