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
        return \Illuminate\Support\Facades\DB::transaction(function () use ($userId, $data) {
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
                'status' => 'joined',
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
        });
    }

    public function getMembers(Chat $chat): array
    {
        $members = $chat->participants()
            ->with(['user:id,name,username,email,avatar_url,sub_role'])
            ->where('status', 'joined')
            ->get();

        return $members->map(function ($m) {
            return [
                'id' => $m->user->id ?? '',
                'name' => $m->user->name ?? 'Pengguna',
                'username' => $m->user->username ?? '',
                'email' => $m->user->email ?? '',
                'avatarUrl' => $m->user->avatar_url ?? null,
                'subRole' => $m->user->sub_role ?? null,
                'isAdmin' => (bool) $m->is_admin,
                'status' => $m->status,
            ];
        })->toArray();
    }

    public function addMember(Chat $chat, string $targetUserId): void
    {
        \Illuminate\Support\Facades\DB::transaction(function () use ($chat, $targetUserId) {
            $targetEmail = str_replace('email:', '', $targetUserId);
            $user = \App\Models\User::where('id', $targetUserId)
                ->orWhere('email', strtolower($targetEmail))
                ->first();

            if (!$user) {
                $rawEmail = strtolower($targetEmail);
                $usernameBase = strtolower(explode('@', $rawEmail)[0]);
                $usernameBase = preg_replace('/[^a-z0-9_]/', '', $usernameBase);
                if (empty($usernameBase)) $usernameBase = 'user';
                $username = $usernameBase . '_' . rand(100, 999);

                $user = \App\Models\User::create([
                    'name' => ucwords(str_replace(['.', '_', '-'], ' ', explode('@', $rawEmail)[0])),
                    'username' => $username,
                    'email' => $rawEmail,
                    'password' => \Illuminate\Support\Facades\Hash::make(\Illuminate\Support\Str::random(16)),
                    'role' => 'user',
                ]);
            }

            $userId = $user->id;

            $participant = ChatParticipant::firstOrCreate(
                ['chat_id' => $chat->id, 'user_id' => $userId],
                ['status' => 'pending']
            );

            if ($participant->wasRecentlyCreated) {
                $notification = $this->notificationRepo->create([
                    'user_id' => $userId,
                    'title' => 'Undangan Grup',
                    'message' => 'Anda ditambahkan ke grup "' . $chat->name . '"',
                    'type' => 'group_invite',
                    'data' => ['chat_id' => $chat->id],
                    'is_read' => false,
                    'created_at' => now(),
                ]);

                broadcast(new NotificationSent($notification));
            }
        });
    }

    public function updateSettings(Chat $chat, array $data): void
    {
        $chat->update(['only_admin_can_add' => $data['only_admin_can_add']]);
    }

    public function updateDetails(Chat $chat, array $data): array
    {
        $payload = [
            'name' => $data['name'],
            'description' => $data['description'] ?? null,
        ];

        if (isset($data['avatar_url']) && !empty($data['avatar_url'])) {
            $avatarUrl = $data['avatar_url'];
            if (str_starts_with($avatarUrl, 'data:image')) {
                if (preg_match('/^data:image\/([a-zA-Z0-9\+\-]+);base64,/', $avatarUrl, $type)) {
                    $imageData = substr($avatarUrl, strpos($avatarUrl, ',') + 1);
                    $ext = strtolower($type[1]);
                    if ($ext === 'jpeg') $ext = 'jpg';
                    if ($ext === 'svg+xml') $ext = 'svg';
                    
                    $imageData = str_replace(' ', '+', $imageData);
                    $decoded = base64_decode($imageData);
                    if ($decoded !== false) {
                        $fileName = 'group_avatar_' . $chat->id . '_' . time() . '.' . $ext;
                        $tempPath = sys_get_temp_dir() . '/' . $fileName;
                        file_put_contents($tempPath, $decoded);
                        
                        $uploadedFile = new \Illuminate\Http\UploadedFile($tempPath, $fileName, 'image/' . $ext, null, true);
                        
                        $user = auth()->user() ?? request()->user() ?? \App\Models\User::where('id', $chat->participants()->where('is_admin', true)->value('user_id'))->first() ?? \App\Models\User::first();
                        
                        /** @var \App\Services\StorageService $storageService */
                        $storageService = app(\App\Services\StorageService::class);
                        $storageFile = $storageService->store($user, $uploadedFile, 'avatar', 'public');
                        
                        $payload['avatar_url'] = url('storage/' . $storageFile->path);
                        @unlink($tempPath);
                    }
                }
            } else {
                $payload['avatar_url'] = $avatarUrl;
            }
        }

        $chat->update($payload);

        return [
            'id' => $chat->id,
            'name' => $chat->name,
            'description' => $chat->description,
            'avatar_url' => $chat->avatar_url,
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
