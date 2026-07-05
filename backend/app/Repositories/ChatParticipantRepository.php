<?php

namespace App\Repositories;

use App\Models\ChatParticipant;

class ChatParticipantRepository extends BaseRepository
{
    public function __construct(ChatParticipant $model)
    {
        parent::__construct($model);
    }

    public function getPendingInvitations(string $userId)
    {
        return $this->model->where('user_id', $userId)
            ->where('status', 'pending')
            ->with('chat:id,name')
            ->get();
    }
}
