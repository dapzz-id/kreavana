<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Message;
use App\Models\Chat;

class MessageController extends Controller
{
    public function index(Chat $chat)
    {
        $messages = $chat->messages()->with('user')->orderBy('created_at', 'desc')->get();
        
        $formatted = $messages->map(function($msg) {
            return [
                'id' => $msg->id,
                'text' => $msg->message,
                'isMe' => $msg->user_id === 1,
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
            'user_id' => 1,
            'message' => $request->message
        ]);
        
        $message->load('user');
        
        return response()->json([
            'id' => $message->id,
            'text' => $message->message,
            'isMe' => true,
            'time' => $message->created_at->format('H:i'),
            'sender' => $message->user->name
        ]);
    }
}
