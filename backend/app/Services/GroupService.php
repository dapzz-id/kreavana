<?php

namespace App\Services;

use App\Repositories\ChatRepository;
use App\Repositories\ChatParticipantRepository;
use App\Repositories\NotificationRepository;
use App\Models\Chat;
use App\Models\ChatParticipant;
use App\Events\NotificationSent;

class GroupService extends BaseService
{
    protected ChatRepository $chatRepo;
    protected ChatParticipantRepository $participantRepo;
    protected NotificationRepository $notificationRepo;

    public function __construct(
        ChatRepository $chatRepo,
        ChatParticipantRepository $participantRepo,
        NotificationRepository $notificationRepo
    ) {
        $this->chatRepo = $chatRepo;
        $this->participantRepo = $participantRepo;
        $this->notificationRepo = $notificationRepo;
    }

    public function createGroup(string $userId, array $data): array
    {
        $chat = $this->chatRepo->create([
            'type' => 'group',
            'name' => $data['name'],
            'description' => $data['description'] ?? null,
            'only_admin_can_add' => false,
        ]);

        ChatParticipant::create([
            'chat_id' => $chat->id,
            'user_id' => $userId,
            'is_admin' => true,
        ]);

        return [
            'id' => $chat->id,
            'name' => $chat->name,
            'description' => $chat->description,
            'isGroup' => true,
            'onlyAdminCanAdd' => false,
            'lastMessage' => 'Grup dibuat',
            'time' => 'Baru saja',
            'unread' => false,
        ];
    }

    public function getMembers(Chat $chat): array
    {
        $members = $chat->participants()->with('user:id,name')->where('status', 'joined')->get();

        return $members->map(function ($m) {
            return [
                'id' => $m->user->id,
                'name' => $m->user->name,
                'isAdmin' => (bool) $m->is_admin,
                'status' => $m->status,
            ];
        })->toArray();
    }

    public function addMember(Chat $chat, string $targetUserId): void
    {
        $participant = ChatParticipant::firstOrCreate(
            ['chat_id' => $chat->id, 'user_id' => $targetUserId],
            ['status' => 'pending']
        );

        if ($participant->wasRecentlyCreated) {
            $notification = $this->notificationRepo->create([
                'user_id' => $targetUserId,
                'title' => 'Undangan Grup',
                'message' => 'Anda diundang ke grup "' . $chat->name . '"',
                'type' => 'group_invite',
                'data' => ['chat_id' => $chat->id],
                'is_read' => false,
                'created_at' => now(),
            ]);

            broadcast(new NotificationSent($notification));
        }
    }

    public function updateSettings(Chat $chat, array $data): void
    {
        $chat->update(['only_admin_can_add' => $data['only_admin_can_add']]);
    }

    public function updateDetails(Chat $chat, array $data): array
    {
        $chat->update([
            'name' => $data['name'],
            'description' => $data['description'] ?? null,
        ]);

        return [
            'id' => $chat->id,
            'name' => $chat->name,
            'description' => $chat->description,
        ];
    }

    public function kickMember(Chat $chat, string $userId): void
    {
        $chat->participants()->where('user_id', $userId)->delete();
    }

    public function makeAdmin(Chat $chat, string $userId): void
    {
        $chat->participants()->where('user_id', $userId)->update(['is_admin' => true]);
    }

    public function leaveGroup(Chat $chat, string $userId): void
    {
        $chat->participants()->where('user_id', $userId)->delete();
    }

    public function getInvitations(string $userId): array
    {
        $invitations = $this->participantRepo->getPendingInvitations($userId);

        return $invitations->map(function ($inv) {
            return [
                'chat_id' => $inv->chat_id,
                'group_name' => $inv->chat->name,
            ];
        })->toArray();
    }

    public function respondInvitation(Chat $chat, string $userId, bool $accept): void
    {
        if ($accept) {
            $chat->participants()->where('user_id', $userId)->update(['status' => 'joined']);
        } else {
            $chat->participants()->where('user_id', $userId)->delete();
        }
    }
}
