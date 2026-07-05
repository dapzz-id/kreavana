<?php

namespace App\Services;

use App\Repositories\ChatRepository;
use App\Repositories\ChatParticipantRepository;
use App\Repositories\UserRepository;
use App\Repositories\NotificationRepository;
use App\Models\ChatParticipant;
use Exception;

class ChatService extends BaseService
{
    protected ChatRepository $chatRepo;
    protected ChatParticipantRepository $participantRepo;
    protected UserRepository $userRepo;
    protected NotificationRepository $notificationRepo;

    public function __construct(
        ChatRepository $chatRepo,
        ChatParticipantRepository $participantRepo,
        UserRepository $userRepo,
        NotificationRepository $notificationRepo
    ) {
        $this->chatRepo = $chatRepo;
        $this->participantRepo = $participantRepo;
        $this->userRepo = $userRepo;
        $this->notificationRepo = $notificationRepo;
    }

    public function getUserChats(string $userId): array
    {
        $chats = $this->chatRepo->getUserChats($userId);

        return $chats->map(function ($chat) use ($userId) {
            $name = $chat->name;
            $otherUserId = null;
            $otherUsername = null;

            if ($chat->type === 'personal') {
                $otherParticipant = $chat->participants->firstWhere('user_id', '!=', $userId);
                $name = $otherParticipant ? $otherParticipant->user->name : 'Unknown';
                $otherUserId = $otherParticipant ? $otherParticipant->user_id : null;
                $otherUsername = $otherParticipant ? $otherParticipant->user->username : null;
            }

            $lastMessage = $chat->messages->first();

            return [
                'id' => $chat->id,
                'name' => $name,
                'description' => $chat->description,
                'user_id' => $otherUserId,
                'username' => $otherUsername,
                'isGroup' => $chat->type === 'group',
                'onlyAdminCanAdd' => (bool) $chat->only_admin_can_add,
                'lastMessage' => $lastMessage ? $lastMessage->message : 'Belum ada pesan',
                'time' => $lastMessage ? $lastMessage->created_at->format('H:i') : '',
                'unread' => $chat->unread_count > 0,
                'unread_count' => $chat->unread_count,
            ];
        })->toArray();
    }

    public function startPersonalChat(string $userId, string $targetUserId): array
    {
        if ($userId == $targetUserId) {
            throw new Exception('Tidak dapat chat dengan diri sendiri.', 400);
        }

        $chat = $this->chatRepo->findExistingPersonalChat($userId, $targetUserId);

        if (!$chat) {
            $chat = $this->chatRepo->create(['type' => 'personal']);
            ChatParticipant::create(['chat_id' => $chat->id, 'user_id' => $userId]);
            ChatParticipant::create(['chat_id' => $chat->id, 'user_id' => $targetUserId]);
        }

        $targetUser = $this->userRepo->find($targetUserId);

        return [
            'id' => $chat->id,
            'name' => $targetUser->name,
            'user_id' => $targetUser->id,
            'username' => $targetUser->username,
            'isGroup' => false,
            'onlyAdminCanAdd' => false,
            'lastMessage' => 'Belum ada pesan',
            'time' => '',
            'unread' => false,
            'unread_count' => 0,
        ];
    }

    public function markAsRead(string $userId, $chat): void
    {
        $chat->participants()->where('user_id', $userId)->update(['last_read_at' => now()]);
    }
}
