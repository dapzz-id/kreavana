<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class UserFile extends Model
{
    protected $fillable = ['user_id', 'file_path', 'file_size_bytes', 'type'];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
