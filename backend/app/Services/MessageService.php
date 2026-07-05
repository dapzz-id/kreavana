<?php

namespace App\Services;

use App\Repositories\MessageRepository;
use App\Models\Chat;
use App\Events\MessageSent;
use Illuminate\Support\Facades\Log;

class MessageService extends BaseService
{
    protected MessageRepository $messageRepo;

    public function __construct(MessageRepository $messageRepo)
    {
        $this->messageRepo = $messageRepo;
    }

    public function getChatMessages(int $chatId, string $userId): array
    {
        $messages = $this->messageRepo->getChatMessages($chatId);

        return $messages->map(function ($msg) use ($userId) {
            return [
                'id' => $msg->id,
                'text' => $msg->message,
                'isMe' => $msg->user_id === $userId,
                'time' => $msg->created_at->format('H:i'),
                'sender' => $msg->user->name,
            ];
        })->toArray();
    }

    public function sendMessage(Chat $chat, string $userId, string $messageText): array
    {
        $message = $this->messageRepo->create([
            'chat_id' => $chat->id,
            'user_id' => $userId,
            'message' => $messageText,
        ]);

        $message->load('user:id,name');
        $chat->touch();

        $messageData = [
            'id' => $message->id,
            'text' => $message->message,
            'isMe' => false,
            'time' => $message->created_at->format('H:i'),
            'sender' => $message->user->name,
            'user_id' => $message->user_id,
        ];

        Log::info('Broadcasting MessageSent on chat.' . $chat->id . ' by User ' . $userId);
        broadcast(new MessageSent($messageData, $chat->id));

        $messageData['isMe'] = true;
        return $messageData;
    }
}
