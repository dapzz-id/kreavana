<?php

namespace App\Services;

use App\Repositories\MessageRepository;
use App\Events\MessageDeleted;
use App\Events\MessageSent;
use App\Models\Chat;
use App\Repositories\NotificationRepository;
use Illuminate\Support\Facades\Log;

class MessageService extends BaseService
{
    protected MessageRepository $messageRepo;
    protected NotificationRepository $notificationRepo;

    public function __construct(MessageRepository $messageRepo, NotificationRepository $notificationRepo)
    {
        $this->messageRepo = $messageRepo;
        $this->notificationRepo = $notificationRepo;
    }

    public function getChatMessages(string $chatId, string $userId): array
    {
        $messages = $this->messageRepo->getChatMessages($chatId)
            ->filter(function ($msg) use ($userId) {
                return !collect($msg->deleted_for)->contains($userId);
            });

        // Get last_read_at of the OTHER participant for read receipts
        $chat = \App\Models\Chat::find($chatId);
        $otherParticipant = $chat->participants()->where('user_id', '!=', $userId)->first();
        $otherLastReadAt = $otherParticipant?->last_read_at;

        return $messages->map(function ($msg) use ($userId, $otherLastReadAt) {
            $isMe = $msg->user_id === $userId;
            // For messages I sent: read if other participant read after I sent it
            // For messages others sent: always "read" (I'm viewing them)
            $isRead = $isMe ? ($otherLastReadAt && $msg->created_at->lte($otherLastReadAt)) : true;

            $replyToData = null;
            if ($msg->replyTo) {
                $replyToData = [
                    'id' => $msg->replyTo->id,
                    'text' => $msg->replyTo->message,
                    'type' => $msg->replyTo->type,
                    'sender' => $msg->replyTo->user->name ?? 'Pengguna',
                ];
            }

            return [
                'id' => $msg->id,
                'text' => $msg->message,
                'type' => $msg->type,
                'media_url' => $msg->media_url,
                'isMe' => $isMe,
                'time' => $this->formatMessageTime($msg->created_at),
                'raw_time' => $msg->created_at->format('H:i'),
                'sender' => $msg->user->name,
                'avatar_url' => $msg->user->avatar_url ?? null,
                'isRead' => $isRead,
                'reply_to' => $replyToData,
            ];
        })->toArray();
    }

    protected function formatMessageTime($time): string
    {
        if (!$time) return '';
        $now = now();
        if ($time->isToday()) return $time->format('H:i');
        if ($time->isYesterday()) return 'Kemarin, ' . $time->format('H:i');
        return $time->format('d M, H:i');
    }

    public function sendMessage(Chat $chat, string $userId, ?string $messageText, string $type = 'text', ?string $media = null, ?string $replyToId = null): array
    {
        $messageText = trim((string)($messageText ?? ''));

        if ($type === 'audio' && $media !== null) {
            $mediaUrl = $this->saveAudioMedia($media, $userId);
            if ($messageText === '') {
                $messageText = 'Voice note';
            }
        } else {
            $mediaUrl = null;
            if ($messageText === '') {
                throw new \Exception('Pesan tidak boleh kosong.', 422);
            }
        }

        $message = $this->messageRepo->create([
            'chat_id' => $chat->id,
            'user_id' => $userId,
            'message' => $messageText,
            'type' => $type,
            'media_url' => $mediaUrl,
            'reply_to_id' => $replyToId,
        ]);

        $message->load(['user:id,name,avatar_url', 'replyTo.user:id,name']);
        $chat->touch();

        $replyToData = null;
        if ($message->replyTo) {
            $replyToData = [
                'id' => $message->replyTo->id,
                'text' => $message->replyTo->message,
                'type' => $message->replyTo->type,
                'sender' => $message->replyTo->user->name ?? 'Pengguna',
            ];
        }

        $messageData = [
            'id' => $message->id,
            'text' => $message->message,
            'type' => $message->type,
            'media_url' => $message->media_url,
            'isMe' => false,
            'time' => $this->formatMessageTime($message->created_at),
            'raw_time' => $message->created_at->format('H:i'),
            'sender' => $message->user->name,
            'user_id' => $message->user_id,
            'avatar_url' => $message->user->avatar_url ?? null,
            'reply_to' => $replyToData,
        ];

        Log::info('Broadcasting MessageSent on chat.' . $chat->id . ' by User ' . $userId);
        broadcast(new MessageSent($messageData, $chat->id));

        $this->createMessageNotification($chat, $userId, $messageText, $type);

        $messageData['isMe'] = true;
        return $messageData;
    }

    public function deleteMessage(Chat $chat, string $userId, \App\Models\Message $message, string $scope = 'me'): array
    {
        if ($message->chat_id !== $chat->id) {
            throw new \Exception('Pesan tidak ditemukan dalam chat ini.', 404);
        }

        $participantIds = $chat->participants()->pluck('user_id')->toArray();
        if (!in_array($userId, $participantIds, true)) {
            throw new \Exception('Anda tidak memiliki akses untuk menghapus pesan ini.', 403);
        }

        $deletedFor = $message->deleted_for ?? [];
        if (!is_array($deletedFor)) {
            $deletedFor = [];
        }

        if ($scope === 'everyone') {
            $deletedFor = array_values(array_unique($participantIds));
            broadcast(new MessageDeleted(['id' => $message->id, 'scope' => 'everyone'], $chat->id));
        } else {
            $deletedFor[] = $userId;
            $deletedFor = array_values(array_unique($deletedFor));
        }

        $message->deleted_for = $deletedFor;
        $message->save();

        return [
            'id' => $message->id,
            'deleted_for' => $deletedFor,
            'scope' => $scope,
        ];
    }

    protected function saveAudioMedia(string $mediaData, string $userId): string
    {
        if (!preg_match('/^data:(audio\/[^;]+);base64,(.+)$/', $mediaData, $matches)) {
            throw new \Exception('Format audio tidak dikenal.', 422);
        }

        $mimeType = strtolower($matches[1]);
        $base64 = $matches[2];
        $decoded = base64_decode($base64);
        if ($decoded === false) {
            throw new \Exception('Gagal mendekode audio.', 422);
        }

        $extension = match (true) {
            str_contains($mimeType, 'webm') => 'webm',
            str_contains($mimeType, 'ogg') => 'ogg',
            str_contains($mimeType, 'mp4') => 'mp4',
            str_contains($mimeType, 'wav') => 'wav',
            str_contains($mimeType, 'mpeg') || str_contains($mimeType, 'mp3') => 'mp3',
            str_contains($mimeType, 'm4a') => 'm4a',
            str_contains($mimeType, 'aac') => 'aac',
            default => 'webm',
        };

        $dirPath = public_path('uploads/chat_audio');
        if (!file_exists($dirPath)) {
            mkdir($dirPath, 0755, true);
        }

        $fileName = 'voice_' . $userId . '_' . time() . '.' . $extension;
        $fullPath = $dirPath . '/' . $fileName;
        file_put_contents($fullPath, $decoded);

        return url('uploads/chat_audio/' . $fileName);
    }

    protected function createMessageNotification(Chat $chat, string $senderId, ?string $messageText, string $type): void
    {
        try {
            $sender = \App\Models\User::find($senderId);
            $participantIds = $chat->participants()->pluck('user_id')->toArray();
            $recipientIds = array_filter($participantIds, fn($id) => $id !== $senderId);

            $preview = $messageText;
            if ($type === 'audio') $preview = '🎤 Voice note';
            elseif ($type === 'image') $preview = '📷 Foto';
            elseif ($type === 'video') $preview = '🎥 Video';
            if (strlen($preview) > 80) $preview = substr($preview, 0, 80) . '...';

            foreach ($recipientIds as $recipientId) {
                $this->notificationRepo->create([
                    'user_id' => $recipientId,
                    'title' => 'Pesan baru dari ' . ($sender->name ?? 'Pengguna'),
                    'message' => $preview,
                    'type' => 'message',
                    'data' => ['chat_id' => $chat->id, 'sender_id' => $senderId],
                    'is_read' => false,
                    'created_at' => now(),
                ]);
            }
        } catch (\Exception $e) {
            Log::warning('Failed to create message notification: ' . $e->getMessage());
        }
    }
}
