<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class UserSubRole extends Model
{
    use HasUuids;

    protected $table = 'user_sub_roles';
    public $timestamps = false;

    protected $fillable = [
        'user_id',
        'sub_role_slug',
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
