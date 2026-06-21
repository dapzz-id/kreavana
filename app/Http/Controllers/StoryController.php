<?php

namespace App\Http\Controllers;

use App\Models\Story;
use App\Models\StoryView;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;

class StoryController extends Controller
{
    /**
     * Upload a new story (photo or video, 24-hour lifetime)
     */
    public function store(Request $request)
    {
        $request->validate([
            'file'    => 'required|file|mimes:jpg,jpeg,png,gif,mp4,mov,webm|max:51200', // 50MB max
            'caption' => 'nullable|string|max:300',
        ]);

        $file = $request->file('file');
        $type = in_array(strtolower($file->getClientOriginalExtension()), ['mp4', 'mov', 'webm']) ? 'video' : 'photo';
        $path = $file->store("stories/" . Auth::id(), 'public');

        Story::create([
            'user_id'    => Auth::id(),
            'file_path'  => $path,
            'type'       => $type,
            'caption'    => $request->caption,
            'expires_at' => now()->addHours(24),
        ]);

        return back()->with('success', 'Story berhasil diunggah! Akan hilang dalam 24 jam.');
    }

    /**
     * View a story and mark it as viewed
     */
    public function view(Story $story)
    {
        if ($story->isExpired()) {
            abort(404, 'Story sudah kedaluwarsa.');
        }

        // Record view (ignore duplicates)
        StoryView::firstOrCreate([
            'story_id' => $story->id,
            'user_id'  => Auth::id(),
        ]);

        return response()->json([
            'id'         => $story->id,
            'type'       => $story->type,
            'file_url'   => Storage::url($story->file_path),
            'caption'    => $story->caption,
            'author'     => $story->user->name,
            'views'      => $story->views()->count(),
            'expires_at' => $story->expires_at->toISOString(),
        ]);
    }

    /**
     * Delete own story
     */
    public function destroy(Story $story)
    {
        if ($story->user_id !== Auth::id()) {
            abort(403);
        }

        Storage::disk('public')->delete($story->file_path);
        $story->delete();

        return back()->with('success', 'Story dihapus.');
    }

    /**
     * Cleanup expired stories (called by scheduler)
     */
    public static function pruneExpired(): int
    {
        $expired = Story::where('expires_at', '<', now())->get();

        foreach ($expired as $story) {
            Storage::disk('public')->delete($story->file_path);
        }

        return Story::where('expires_at', '<', now())->delete();
    }
}
