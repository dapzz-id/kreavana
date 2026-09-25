<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Opportunity extends Model
{
    use HasUuids, HasFactory;

    public $timestamps = false;

    protected $fillable = [
        'title',
        'description',
        'poster_url',
        'sub_role_slug',
        'type',
        'location',
        'latitude',
        'longitude',
        'location_category',
        'address',
        'deadline',
        'event_date',
        'event_start_date',
        'event_end_date',
        'event_start_time',
        'event_end_time',
        'budget_range',
        'status',
        'banner_url',
        'meeting_date',
        'meeting_time',
        'meeting_location',
        'meeting_lat',
        'meeting_lng',
        'meeting_notes',
        'meeting_status',
        'escrow_status',
        'event_progress',
        'posted_by',
        'created_at',
    ];

    protected $casts = [
        'deadline' => 'date',
        'event_date' => 'date',
        'event_start_date' => 'date',
        'event_end_date' => 'date',
        'meeting_date' => 'date',
        'meeting_lat' => 'decimal:7',
        'meeting_lng' => 'decimal:7',
        'event_progress' => 'integer',
        'created_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class, 'posted_by');
    }

    public function requirements(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(OpportunityRequirement::class);
    }

    public function applications(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(OpportunityApplication::class);
    }

    public function approvedApplications(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(OpportunityApplication::class)->where('status', 'approved');
    }
}
