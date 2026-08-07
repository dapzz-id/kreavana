<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Services\MessageService;
use App\Http\Requests\SendMessageRequest;
use App\Traits\ApiResponse;
use App\Models\Chat;
use App\Models\Message;

class MessageController extends Controller
{
    use ApiResponse;

    protected MessageService $messageService;

    public function __construct(MessageService $messageService)
    {
        $this->messageService = $messageService;
    }

    public function index(Request $request, Chat $chat)
    {
        $userId = $request->user()->id;
        $messages = $this->messageService->getChatMessages($chat->id, $userId);

        return $this->successResponse('Pesan berhasil diambil', $messages);
    }

    public function store(SendMessageRequest $request, Chat $chat)
    {
        $userId = $request->user()->id;
        $messageData = $this->messageService->sendMessage(
            $chat,
            $userId,
            $request->message,
            $request->type ?? 'text',
            $request->media ?? null,
            $request->reply_to_id ?? null,
        );

        return $this->successResponse('Pesan berhasil dikirim', $messageData);
    }

    public function destroy(Request $request, Chat $chat, Message $message)
    {
        if ($message->chat_id !== $chat->id) {
            return $this->errorResponse('Pesan tidak ditemukan dalam chat ini.', 404);
        }

        $userId = $request->user()->id;
        $scope = $request->input('scope', 'me');
        $allowedScopes = ['me', 'everyone'];
        if (!in_array($scope, $allowedScopes, true)) {
            $scope = 'me';
        }

        $result = $this->messageService->deleteMessage($chat, $userId, $message, $scope);

        return $this->successResponse('Pesan berhasil dihapus', $result);
    }
}
