<?php

namespace App\Repositories;

use App\Models\Message;

class MessageRepository extends BaseRepository
{
    public function __construct(Message $model)
    {
        parent::__construct($model);
    }

    public function getChatMessages(int $chatId)
    {
        return $this->model->where('chat_id', $chatId)
            ->with('user:id,name')
            ->orderBy('created_at', 'desc')
            ->get();
    }
}
