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
}
