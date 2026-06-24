<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use App\Models\Message;
use App\Models\Chat;
use App\Events\MessageSent;

class MessageController extends Controller
{
    public function index(Request $request, Chat $chat)
    {
        $userId = $request->user()->id;
        $messages = $chat->messages()->with('user')->orderBy('created_at', 'desc')->get();
        
        $formatted = $messages->map(function($msg) use ($userId) {
            return [
                'id' => $msg->id,
                'text' => $msg->message,
                'isMe' => $msg->user_id === $userId,
                'time' => $msg->created_at->format('H:i'),
                'sender' => $msg->user->name
            ];
        });
        
        return response()->json($formatted);
    }

    public function store(Request $request, Chat $chat)
    {
        $request->validate(['message' => 'required|string']);
        
        $message = Message::create([
            'chat_id' => $chat->id,
            'user_id' => $request->user()->id,
            'message' => $request->message
        ]);
        
        $message->load('user');
        
        $chat->touch(); // Perbarui updated_at untuk sorting

        $messageData = [
            'id' => $message->id,
            'text' => $message->message,
            'isMe' => false, // Default untuk penerima
            'time' => $message->created_at->format('H:i'),
            'sender' => $message->user->name,
            'user_id' => $message->user_id
        ];

        Log::info('Broadcasting MessageSent on chat.' . $chat->id . ' by User ' . $request->user()->id);
        broadcast(new MessageSent($messageData, $chat->id));
        
        $messageData['isMe'] = true; // Untuk pengirim
        return response()->json($messageData);
    }
}
