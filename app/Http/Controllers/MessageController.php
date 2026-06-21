<?php

namespace App\Http\Controllers;

use App\Models\Message;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class MessageController extends Controller
{
    /**
     * Show the inbox: list of unique conversation threads
     */
    public function inbox()
    {
        $user = Auth::user();

        // Get all unique conversation partners
        $partnerIds = Message::where('sender_id', $user->id)
            ->orWhere('receiver_id', $user->id)
            ->get()
            ->map(fn ($m) => $m->sender_id === $user->id ? $m->receiver_id : $m->sender_id)
            ->unique()
            ->values();

        $conversations = User::whereIn('id', $partnerIds)
            ->get()
            ->map(function ($partner) use ($user) {
                $lastMsg = Message::conversation($user->id, $partner->id)
                    ->latest()
                    ->first();

                $unread = Message::where('sender_id', $partner->id)
                    ->where('receiver_id', $user->id)
                    ->whereNull('read_at')
                    ->count();

                return [
                    'user'     => $partner,
                    'last_msg' => $lastMsg,
                    'unread'   => $unread,
                ];
            })
            ->sortByDesc(fn ($c) => optional($c['last_msg'])->created_at)
            ->values();

        return view('messages.inbox', compact('conversations'));
    }

    /**
     * Show a specific conversation thread with another user
     */
    public function show(User $user)
    {
        $me = Auth::user();

        if ($me->id === $user->id) {
            return redirect()->route('messages.inbox');
        }

        $messages = Message::conversation($me->id, $user->id)->get();

        // Mark all incoming messages as read
        Message::where('sender_id', $user->id)
            ->where('receiver_id', $me->id)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        return view('messages.show', [
            'partner'  => $user,
            'messages' => $messages,
        ]);
    }

    /**
     * Send a new message (AJAX or form POST)
     */
    public function send(Request $request, User $user)
    {
        $me = Auth::user();

        if ($me->id === $user->id) {
            return response()->json(['error' => 'Cannot message yourself'], 422);
        }

        $request->validate([
            'body'       => 'nullable|string|max:2000',
            'attachment' => 'nullable|file|mimes:jpg,jpeg,png,gif,mp4,pdf|max:20480',
        ]);

        if (!$request->body && !$request->hasFile('attachment')) {
            return response()->json(['error' => 'Message cannot be empty'], 422);
        }

        $attachmentPath = null;
        $attachmentType = null;

        if ($request->hasFile('attachment')) {
            $file = $request->file('attachment');
            $attachmentPath = $file->store("messages/" . $me->id, 'public');
            $attachmentType = in_array(strtolower($file->getClientOriginalExtension()), ['mp4']) ? 'video' : 'image';
        }

        $message = Message::create([
            'sender_id'       => $me->id,
            'receiver_id'     => $user->id,
            'body'            => $request->body,
            'attachment_path' => $attachmentPath,
            'attachment_type' => $attachmentType,
        ]);

        // Load relationships for JSON response
        $message->load('sender');

        return response()->json([
            'success' => true,
            'message' => [
                'id'              => $message->id,
                'body'            => $message->body,
                'attachment_path' => $attachmentPath ? \Storage::url($attachmentPath) : null,
                'attachment_type' => $attachmentType,
                'sender_name'     => $me->name,
                'sender_avatar'   => $me->profile_photo_url,
                'is_mine'         => true,
                'created_at'      => $message->created_at->diffForHumans(),
                'time'            => $message->created_at->format('H:i'),
            ],
        ]);
    }

    /**
     * Poll for new messages since a given ID (lightweight long-poll alternative)
     */
    public function poll(Request $request, User $user)
    {
        $me = Auth::user();
        $since = $request->integer('since', 0);

        $messages = Message::where('sender_id', $user->id)
            ->where('receiver_id', $me->id)
            ->where('id', '>', $since)
            ->get()
            ->map(fn ($m) => [
                'id'              => $m->id,
                'body'            => $m->body,
                'attachment_path' => $m->attachment_path ? \Storage::url($m->attachment_path) : null,
                'attachment_type' => $m->attachment_type,
                'sender_name'     => $user->name,
                'sender_avatar'   => $user->profile_photo_url,
                'is_mine'         => false,
                'created_at'      => $m->created_at->diffForHumans(),
                'time'            => $m->created_at->format('H:i'),
            ]);

        // Mark as read
        Message::where('sender_id', $user->id)
            ->where('receiver_id', $me->id)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        return response()->json(['messages' => $messages]);
    }
}
