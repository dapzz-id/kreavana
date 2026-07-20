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
        'sub_role_slug',
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
