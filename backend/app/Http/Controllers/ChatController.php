<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Chat;

class ChatController extends Controller
{
    public function index(Request $request)
    {
        $userId = $request->user()->id;
        $chats = Chat::whereHas('participants', function ($q) use ($userId) {
            $q->where('user_id', $userId)->where('status', 'joined');
        })
        ->with(['participants.user', 'messages' => function($q) {
            $q->latest()->take(1);
        }])
        ->withCount(['messages as unread_count' => function ($query) use ($userId) {
            $query->where('user_id', '!=', $userId)
                  ->whereRaw('messages.created_at > COALESCE((SELECT last_read_at FROM chat_participants WHERE chat_participants.chat_id = messages.chat_id AND chat_participants.user_id = ? LIMIT 1), "2000-01-01 00:00:00")', [$userId]);
        }])
        ->orderBy('updated_at', 'desc')
        ->get();

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
                'user_id' => $chat->type === 'personal' && isset($otherParticipant) ? $otherParticipant->user_id : null,
                'isGroup' => $chat->type === 'group',
                'onlyAdminCanAdd' => (bool) $chat->only_admin_can_add,
                'lastMessage' => $lastMessage ? $lastMessage->message : 'Belum ada pesan',
                'time' => $lastMessage ? $lastMessage->created_at->format('H:i') : '',
                'unread' => $chat->unread_count > 0,
                'unread_count' => $chat->unread_count,
            ];
        });

        return response()->json($formatted);
    }

    public function startPersonalChat(Request $request)
    {
        $request->validate(['user_id' => 'required|exists:users,id']);
        
        $userId = $request->user()->id;
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
            'user_id' => $targetUser->id,
            'isGroup' => false,
            'onlyAdminCanAdd' => false,
            'lastMessage' => 'Belum ada pesan',
            'time' => '',
            'unread' => false,
            'unread_count' => 0,
        ]);
    }

    public function markAsRead(Request $request, Chat $chat)
    {
        $userId = $request->user()->id;
        $chat->participants()->where('user_id', $userId)->update(['last_read_at' => now()]);
        return response()->json(['message' => 'Chat marked as read']);
    }
}
