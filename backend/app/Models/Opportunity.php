<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Opportunity extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'title',
        'description',
        'pihak_slug',
        'type',
        'location',
        'latitude',
        'longitude',
        'location_category',
        'address',
        'deadline',
        'budget_range',
        'status',
        'posted_by',
        'created_at',
    ];

    protected $casts = [
        'deadline' => 'date',
        'created_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class, 'posted_by');
    }
}
