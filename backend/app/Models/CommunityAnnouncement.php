<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class CommunityAnnouncement extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'community_id',
        'title',
        'content',
        'type',
        'priority',
        'published_at',
        'expires_at',
        'created_by',
        'status',
    ];

    protected $casts = [
        'published_at' => 'datetime',
        'expires_at' => 'datetime',
        'status' => 'string',
        'priority' => 'string',
    ];

    public function community()
    {
        return $this->belongsTo(User::class, 'community_id');
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
