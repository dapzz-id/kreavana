<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LargeTransactionReview extends Model
{
    use HasUuids;

    protected $fillable = [
        'job_contract_id',
        'threshold_amount',
        'contract_amount',
        'assigned_marketing_id',
        'status',
        'verification_notes',
        'document_url',
        'client_verified_at',
        'creator_verified_at',
        'approved_at',
    ];

    protected $casts = [
        'threshold_amount' => 'decimal:2',
        'contract_amount' => 'decimal:2',
        'client_verified_at' => 'datetime',
        'creator_verified_at' => 'datetime',
        'approved_at' => 'datetime',
    ];

    public function jobContract(): BelongsTo
    {
        return $this->belongsTo(JobContract::class);
    }

    public function marketing(): BelongsTo
    {
        return $this->belongsTo(User::class, 'assigned_marketing_id');
    }
}
