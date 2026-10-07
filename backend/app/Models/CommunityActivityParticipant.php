<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class CommunityActivityParticipant extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'activity_id',
        'user_id',
        'status',
        'joined_at',
    ];

    protected $casts = [
        'joined_at' => 'datetime',
        'status' => 'string',
    ];

    public function activity()
    {
        return $this->belongsTo(CommunityActivity::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
