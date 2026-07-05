<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Services\MessageService;
use App\Http\Requests\SendMessageRequest;
use App\Traits\ApiResponse;
use App\Models\Chat;

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
        $messageData = $this->messageService->sendMessage($chat, $userId, $request->message);

        return $this->successResponse('Pesan berhasil dikirim', $messageData);
    }
}
