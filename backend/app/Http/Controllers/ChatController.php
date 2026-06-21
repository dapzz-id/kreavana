<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Chat;

class ChatController extends Controller
{
    // Hardcode user_id = 1 for prototyping
    public function index()
    {
        $userId = 1;
        $chats = Chat::whereHas('participants', function ($q) use ($userId) {
            $q->where('user_id', $userId)->where('status', 'joined');
        })->with(['participants.user', 'messages' => function($q) {
            $q->latest()->take(1);
        }])->get();

        $formatted = $chats->map(function ($chat) use ($userId) {
            $name = $chat->name;
            if ($chat->type === 'personal') {
                $otherParticipant = $chat->participants->firstWhere('user_id', '!=', $userId);
                $name = $otherParticipant ? $otherParticipant->user->name : 'Unknown';
            }

            $lastMessage = $chat->messages->first();
            $unread = false; 
            
            return [
                'id' => $chat->id,
                'name' => $name,
                'isGroup' => $chat->type === 'group',
                'onlyAdminCanAdd' => (bool) $chat->only_admin_can_add,
                'lastMessage' => $lastMessage ? $lastMessage->message : 'Belum ada pesan',
                'time' => $lastMessage ? $lastMessage->created_at->format('H:i') : '',
                'unread' => $unread,
            ];
        });

        return response()->json($formatted);
    }

    public function startPersonalChat(Request $request)
    {
        $request->validate(['user_id' => 'required|exists:users,id']);
        
        $userId = 1;
        $targetUserId = $request->user_id;

        if ($userId == $targetUserId) {
            return response()->json(['message' => 'Cannot chat with yourself'], 400);
        }

        // Check if chat already exists
        $chat = Chat::where('type', 'personal')
            ->whereHas('participants', function($q) use ($userId) {
                $q->where('user_id', $userId);
            })
            ->whereHas('participants', function($q) use ($targetUserId) {
                $q->where('user_id', $targetUserId);
            })
            ->first();

        if (!$chat) {
            $chat = Chat::create(['type' => 'personal']);
            \App\Models\ChatParticipant::create(['chat_id' => $chat->id, 'user_id' => $userId]);
            \App\Models\ChatParticipant::create(['chat_id' => $chat->id, 'user_id' => $targetUserId]);
        }

        $targetUser = \App\Models\User::find($targetUserId);

        return response()->json([
            'id' => $chat->id,
            'name' => $targetUser->name,
            'isGroup' => false,
            'onlyAdminCanAdd' => false,
            'lastMessage' => 'Belum ada pesan',
            'time' => '',
            'unread' => false,
        ]);
    }
}
