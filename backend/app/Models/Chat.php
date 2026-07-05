<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class Chat extends Model
{
    use HasFactory, HasUuids;
    
    protected $fillable = ['type', 'name', 'description', 'only_admin_can_add'];
    
    protected $casts = [
        'only_admin_can_add' => 'boolean',
    ];
    
    public function participants()
    {
        return $this->hasMany(ChatParticipant::class);
    }
    
    public function messages()
    {
        return $this->hasMany(Message::class);
    }
}
