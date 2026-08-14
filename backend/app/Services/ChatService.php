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
            $otherAvatar = null;
            $lastOnline = null;

            if ($chat->type === 'personal') {
                $otherParticipant = $chat->participants->firstWhere('user_id', '!=', $userId);
                if ($otherParticipant && $otherParticipant->user) {
                    $name = $otherParticipant->user->name;
                    $otherUserId = $otherParticipant->user_id;
                    $otherUsername = $otherParticipant->user->username;
                    $otherAvatar = $otherParticipant->user->avatar_url;
                    $lastOnline = $otherParticipant->user->last_online;
                } else {
                    $name = 'Unknown';
                }
            }

            $lastMessage = $chat->messages->first();

            return [
                'id' => $chat->id,
                'name' => $name,
                'description' => $chat->description,
                'user_id' => $otherUserId,
                'username' => $otherUsername,
                'avatar_url' => $chat->type === 'group' ? $chat->avatar_url : $otherAvatar,
                'isOnline' => $lastOnline ? \Carbon\Carbon::parse($lastOnline)->diffInSeconds(now()) < 10 : false,
                'last_online' => $lastOnline ? \Carbon\Carbon::parse($lastOnline)->diffForHumans() : null,
                'last_online_raw' => $lastOnline,
                'isGroup' => $chat->type === 'group',
                'onlyAdminCanAdd' => (bool) $chat->only_admin_can_add,
                'lastMessage' => $lastMessage ? $lastMessage->message : 'Belum ada pesan',
                'time' => $lastMessage ? $this->formatChatTime($lastMessage->created_at) : '',
                'raw_time' => $lastMessage ? $lastMessage->created_at->format('H:i') : '',
                'unread' => $chat->unread_count > 0,
                'unread_count' => $chat->unread_count,
            ];
        })->toArray();
    }

    protected function formatChatTime($time): string
    {
        if (!$time) return '';
        $now = now();
        if ($time->isToday()) return $time->format('H:i');
        if ($time->isYesterday()) return 'Kemarin';
        if ($time->isCurrentWeek()) return $time->translatedFormat('l');
        return $time->format('d/m');
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
            'avatar_url' => $targetUser->avatar_url,
            'isOnline' => $targetUser->last_online ? \Carbon\Carbon::parse($targetUser->last_online)->diffInSeconds(now()) < 10 : false,
            'last_online' => $targetUser->last_online ? \Carbon\Carbon::parse($targetUser->last_online)->diffForHumans() : null,
            'last_online_raw' => $targetUser->last_online,
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
