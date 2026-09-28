<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class OpportunityReview extends Model
{
    use HasUuids;

    protected $fillable = [
        'opportunity_id',
        'reviewer_id',
        'creator_id',
        'rating',
        'is_on_time',
        'delivery_days',
        'comment',
        'reviewer_role',
        'reviewer_company',
        'helpful_count',
    ];

    protected $casts = [
        'rating'        => 'decimal:2',
        'is_on_time'    => 'boolean',
        'delivery_days' => 'integer',
        'helpful_count' => 'integer',
    ];

    public function opportunity()
    {
        return $this->belongsTo(Opportunity::class);
    }

    public function reviewer()
    {
        return $this->belongsTo(User::class, 'reviewer_id');
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'creator_id');
    }
}
