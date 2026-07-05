<?php

namespace App\Repositories;

use App\Models\Chat;
use App\Models\ChatParticipant;

class ChatRepository extends BaseRepository
{
    public function __construct(Chat $model)
    {
        parent::__construct($model);
    }

    public function getUserChats(string $userId)
    {
        return $this->model->whereHas('participants', function ($q) use ($userId) {
            $q->where('user_id', $userId)->where('status', 'joined');
        })
        ->with(['participants.user:id,name,username,avatar_url', 'messages' => function($q) {
            $q->latest()->take(1);
        }])
        ->withCount(['messages as unread_count' => function ($query) use ($userId) {
            $query->where('user_id', '!=', $userId)
                  ->whereRaw('messages.created_at > COALESCE((SELECT last_read_at FROM chat_participants WHERE chat_participants.chat_id = messages.chat_id AND chat_participants.user_id = ? LIMIT 1), "2000-01-01 00:00:00")', [$userId]);
        }])
        ->orderBy('updated_at', 'desc')
        ->get();
    }

    public function findExistingPersonalChat(string $userId, string $targetUserId)
    {
        return $this->model->where('type', 'personal')
            ->whereHas('participants', function($q) use ($userId) {
                $q->where('user_id', $userId);
            })
            ->whereHas('participants', function($q) use ($targetUserId) {
                $q->where('user_id', $targetUserId);
            })
            ->first();
    }
}
