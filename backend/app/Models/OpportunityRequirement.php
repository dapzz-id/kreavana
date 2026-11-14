<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class OpportunityRequirement extends Model
{
    use HasUuids;

    protected $fillable = [
        'opportunity_id',
        'sub_role_slug',
        'quantity',
        'notes',
        'payment_scheme',
        'payment_terms',
    ];

    protected $casts = [
        'quantity' => 'integer',
        'payment_terms' => 'array',
    ];

    public function opportunity(): BelongsTo
    {
        return $this->belongsTo(Opportunity::class);
    }
}
