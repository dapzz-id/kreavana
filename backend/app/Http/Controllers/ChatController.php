<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Services\ChatService;
use App\Http\Requests\StartPersonalChatRequest;
use App\Traits\ApiResponse;
use App\Models\Chat;
use Exception;

class ChatController extends Controller
{
    use ApiResponse;

    protected ChatService $chatService;

    public function __construct(ChatService $chatService)
    {
        $this->chatService = $chatService;
    }

    public function index(Request $request)
    {
        $userId = $request->user()->id;
        $chats = $this->chatService->getUserChats($userId);

        return $this->successResponse('Daftar chat berhasil diambil', $chats);
    }

    public function startPersonalChat(StartPersonalChatRequest $request)
    {
        $userId = $request->user()->id;

        try {
            $chat = $this->chatService->startPersonalChat($userId, $request->user_id);
            return $this->successResponse('Chat personal berhasil dibuat', $chat);
        } catch (Exception $e) {
            return $this->errorResponse($e->getMessage(), $e->getCode() ?: 400);
        }
    }

    public function markAsRead(Request $request, Chat $chat)
    {
        $userId = $request->user()->id;
        $this->chatService->markAsRead($userId, $chat);

        return $this->successResponse('Chat berhasil ditandai sudah dibaca');
    }

    public function markAllAsRead(Request $request)
    {
        $userId = $request->user()->id;
        \App\Models\ChatParticipant::where('user_id', $userId)
            ->where('status', 'joined')
            ->update(['last_read_at' => now()]);

        return $this->successResponse('Semua chat berhasil ditandai sudah dibaca');
    }

    /**
     * Lightweight presence ping - updates last_online without full middleware
     */
    public function presencePing(Request $request)
    {
        $user = $request->user();
        $user->update(['last_online' => now()]);

        return $this->successResponse('Presence updated', [
            'last_online' => now()->toISOString(),
        ]);
    }

    public function unreadCount(Request $request)
    {
        $userId = $request->user()->id;

        $count = \App\Models\ChatParticipant::where('chat_participants.user_id', $userId)
            ->where('chat_participants.status', 'joined')
            ->join('messages', function ($join) use ($userId) {
                $join->on('messages.chat_id', '=', 'chat_participants.chat_id')
                     ->where('messages.user_id', '!=', $userId)
                     ->whereRaw('messages.created_at > COALESCE(chat_participants.last_read_at, chat_participants.created_at, "2000-01-01 00:00:00")');
            })
            ->count();

        return $this->successResponse('Jumlah pesan belum dibaca', ['count' => $count]);
    }

    public function devices(Request $request, Chat $chat)
    {
        $userId = $request->user()->id;
        
        // Ensure user is participant
        $isParticipant = $chat->participants()->where('user_id', $userId)->exists();
        if (!$isParticipant) {
            return $this->errorResponse('Unauthorized', 403);
        }

        $participantIds = $chat->participants()->pluck('user_id')->toArray();
        
        // Get all active devices of all participants
        $devices = \App\Models\UserDevice::whereIn('user_id', $participantIds)
            ->where('is_active', true)
            ->whereNull('revoked_at')
            ->whereNotNull('public_key')
            ->get(['user_id', 'device_id', 'public_key'])
            ->toArray();

        return $this->successResponse('Devices fetched', $devices);
    }
}
