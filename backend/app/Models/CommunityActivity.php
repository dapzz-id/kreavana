<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class CommunityActivity extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'community_id',
        'title',
        'description',
        'activity_date',
        'location',
        'status',
        'max_participants',
        'created_by',
    ];

    protected $casts = [
        'activity_date' => 'datetime',
        'status' => 'string',
        'max_participants' => 'integer',
    ];

    public function community()
    {
        return $this->belongsTo(User::class, 'community_id');
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function participants()
    {
        return $this->hasMany(CommunityActivityParticipant::class);
    }
}
