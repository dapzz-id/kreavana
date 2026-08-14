<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class Message extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'chat_id',
        'user_id',
        'message',
        'encryption_version',
        'ciphertext',
        'iv',
        'type',
        'media_url',
        'deleted_for',
        'reply_to_id',
    ];

    protected $casts = [
        'deleted_for' => 'array',
        'encryption_version' => 'integer',
    ];

    public function chat()
    {
        return $this->belongsTo(Chat::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function replyTo()
    {
        return $this->belongsTo(Message::class, 'reply_to_id');
    }

    public function messageKeys()
    {
        return $this->hasMany(MessageKey::class);
    }
}
