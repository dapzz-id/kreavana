<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class JobContract extends Model
{
    use HasUuids, HasFactory;

    protected $fillable = [
        'client_id',
        'creator_id',
        'opportunity_id',
        'creator_service_id',
        'title',
        'description',
        'terms',
        'agreed_price',
        'escrow_amount',
        'contract_status',
        'work_status',
        'scheduled_start_date',
        'scheduled_end_date',
        'deadline',
        'creator_approved',
        'client_approved',
        'dispute_group_id',
        'cancel_reason',
        'scheduled_at',
        'started_at',
        'submitted_at',
        'completed_at',
        'cancelled_at',
        'client_approved_at',
        'creator_approved_at',
    ];

    protected $casts = [
        'contract_status' => \App\Enums\ContractStatus::class,
        'work_status' => \App\Enums\WorkStatus::class,
        'agreed_price' => 'decimal:2',
        'escrow_amount' => 'decimal:2',
        'deadline' => 'date',
        'scheduled_start_date' => 'date',
        'scheduled_end_date' => 'date',
        'creator_approved' => 'boolean',
        'client_approved' => 'boolean',
        'scheduled_at' => 'datetime',
        'started_at' => 'datetime',
        'submitted_at' => 'datetime',
        'completed_at' => 'datetime',
        'cancelled_at' => 'datetime',
        'client_approved_at' => 'datetime',
        'creator_approved_at' => 'datetime',
    ];

    public function client(): BelongsTo
    {
        return $this->belongsTo(User::class, 'client_id');
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'creator_id');
    }

    public function opportunity(): BelongsTo
    {
        return $this->belongsTo(Opportunity::class, 'opportunity_id');
    }

    public function statusHistories(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(JobStatusHistory::class, 'job_contract_id');
    }

    public function creatorService(): BelongsTo
    {
        return $this->belongsTo(CreatorService::class, 'creator_service_id');
    }
}
