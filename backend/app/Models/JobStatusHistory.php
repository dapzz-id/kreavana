<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class JobStatusHistory extends Model
{
    use HasUuids;

    public $timestamps = false; // we only use created_at, handled via model events or DB default

    protected $fillable = [
        'job_contract_id',
        'actor_id',
        'transition',
        'from_contract_status',
        'to_contract_status',
        'from_work_status',
        'to_work_status',
        'metadata',
        'created_at',
    ];

    protected $casts = [
        'from_contract_status' => \App\Enums\ContractStatus::class,
        'to_contract_status' => \App\Enums\ContractStatus::class,
        'from_work_status' => \App\Enums\WorkStatus::class,
        'to_work_status' => \App\Enums\WorkStatus::class,
        'metadata' => 'array',
        'created_at' => 'datetime',
    ];

    public function contract(): BelongsTo
    {
        return $this->belongsTo(JobContract::class, 'job_contract_id');
    }

    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_id');
    }
}
