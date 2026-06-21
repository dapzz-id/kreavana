<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Attributes\Fillable;

#[Fillable(['sender_id', 'receiver_id', 'body', 'attachment_path', 'attachment_type', 'read_at'])]
class Message extends Model
{
    protected function casts(): array
    {
        return [
            'read_at' => 'datetime',
        ];
    }

    public function sender()
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    public function receiver()
    {
        return $this->belongsTo(User::class, 'receiver_id');
    }

    public function isRead(): bool
    {
        return $this->read_at !== null;
    }

    /**
     * Get the conversation thread between two users (ordered)
     */
    public static function conversation(int $userA, int $userB)
    {
        return static::where(function ($q) use ($userA, $userB) {
            $q->where('sender_id', $userA)->where('receiver_id', $userB);
        })->orWhere(function ($q) use ($userA, $userB) {
            $q->where('sender_id', $userB)->where('receiver_id', $userA);
        })->orderBy('created_at', 'asc');
    }
}
