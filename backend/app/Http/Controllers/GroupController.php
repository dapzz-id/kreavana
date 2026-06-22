<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Chat;
use App\Models\ChatParticipant;

class GroupController extends Controller
{
    public function store(Request $request)
    {
        $request->validate(['name' => 'required|string']);
        
        $chat = Chat::create([
            'type' => 'group',
            'name' => $request->name,
            'only_admin_can_add' => false
        ]);
        
        ChatParticipant::create([
            'chat_id' => $chat->id,
            'user_id' => 1,
            'is_admin' => true
        ]);
        
        return response()->json([
            'id' => $chat->id,
            'name' => $chat->name,
            'isGroup' => true,
            'onlyAdminCanAdd' => false,
            'lastMessage' => 'Grup dibuat',
            'time' => 'Baru saja',
            'unread' => false,
        ]);
    }

    public function members(Chat $chat)
    {
        $members = $chat->participants()->with('user')->where('status', 'joined')->get();
        $formatted = $members->map(function($m) {
            return [
                'id' => $m->user->id,
                'name' => $m->user_id === 1 ? 'Anda' : $m->user->name,
                'isAdmin' => (bool) $m->is_admin,
                'status' => $m->status
            ];
        });
        
        return response()->json($formatted);
    }
    
    public function addMember(Request $request, Chat $chat)
    {
        $request->validate(['user_id' => 'required|exists:users,id']);
        
        $participant = ChatParticipant::firstOrCreate(
            ['chat_id' => $chat->id, 'user_id' => $request->user_id],
            ['status' => 'pending']
        );

        if ($participant->wasRecentlyCreated) {
            $notification = \App\Models\Notification::create([
                'user_id' => $request->user_id,
                'title' => 'Undangan Grup',
                'message' => 'Anda diundang ke grup "' . $chat->name . '"',
                'type' => 'group_invite',
                'data' => ['chat_id' => $chat->id],
                'is_read' => false,
                'created_at' => now(),
            ]);

            broadcast(new \App\Events\NotificationSent($notification));
        }
        
        return response()->json(['message' => 'Undangan berhasil dikirim']);
    }
    
    public function updateSettings(Request $request, Chat $chat)
    {
        $request->validate(['only_admin_can_add' => 'required|boolean']);
        $chat->update(['only_admin_can_add' => $request->only_admin_can_add]);
        return response()->json(['message' => 'Pengaturan berhasil diperbarui']);
    }

    public function kickMember(Chat $chat, $userId)
    {
        $chat->participants()->where('user_id', $userId)->delete();
        return response()->json(['message' => 'Anggota dikeluarkan']);
    }

    public function makeAdmin(Chat $chat, $userId)
    {
        $chat->participants()->where('user_id', $userId)->update(['is_admin' => true]);
        return response()->json(['message' => 'Anggota dijadikan admin']);
    }

    public function leaveGroup(Chat $chat)
    {
        $userId = 1;
        $chat->participants()->where('user_id', $userId)->delete();
        return response()->json(['message' => 'Keluar dari grup']);
    }

    public function getInvitations()
    {
        $userId = 1;
        $invitations = ChatParticipant::where('user_id', $userId)
            ->where('status', 'pending')
            ->with('chat')
            ->get();
            
        $formatted = $invitations->map(function($inv) {
            return [
                'chat_id' => $inv->chat_id,
                'group_name' => $inv->chat->name,
            ];
        });
        return response()->json($formatted);
    }

    public function respondInvitation(Request $request, Chat $chat)
    {
        $userId = 1;
        $request->validate(['accept' => 'required|boolean']);
        
        if ($request->accept) {
            $chat->participants()->where('user_id', $userId)->update(['status' => 'joined']);
            return response()->json(['message' => 'Undangan diterima']);
        } else {
            $chat->participants()->where('user_id', $userId)->delete();
            return response()->json(['message' => 'Undangan ditolak']);
        }
    }
}
