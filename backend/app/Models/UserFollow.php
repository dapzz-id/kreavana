<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Models\User;

class UserFollow extends Model
{
    use Illuminate\Database\Eloquent\Concerns\HasUuids;

    public $timestamps = false;
    
    protected $fillable = [
        'follower_id',
        'following_id',
        'created_at',
    ];

    protected $casts = [
        'created_at' => 'datetime',
    ];

    public function follower()
    {
        return $this->belongsTo(User::class, 'follower_id');
    }

    public function following()
    {
        return $this->belongsTo(User::class, 'following_id');
    }
}
