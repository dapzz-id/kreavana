<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class ChatParticipant extends Model
{
    use HasFactory, HasUuids;
    
    protected $fillable = ['chat_id', 'user_id', 'is_admin', 'status'];
    
    protected $casts = [
        'is_admin' => 'boolean',
    ];
    
    public function chat()
    {
        return $this->belongsTo(Chat::class);
    }
    
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
