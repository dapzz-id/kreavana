<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class UserPihak extends Model
{
    protected $table = 'user_pihak';
    public $timestamps = false;

    protected $fillable = [
        'user_id',
        'pihak_slug',
        'role_type',
        'is_active',
        'joined_at'
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'joined_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
