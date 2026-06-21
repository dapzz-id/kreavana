<?php

namespace App\Http\Controllers;

use App\Models\Photo;
use App\Models\Story;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class DashboardController extends Controller
{
    public function index()
    {
        $user = Auth::user();

        // Active stories from people the user follows + own stories
        $followingIds = $user->following()->pluck('users.id')->toArray();
        $storyUserIds = array_merge([$user->id], $followingIds);

        $storiesRaw = Story::active()
            ->whereIn('user_id', $storyUserIds)
            ->with('user')
            ->orderBy('created_at', 'desc')
            ->get()
            ->groupBy('user_id');

        // Feed: photos from people followed
        $feedPhotos = Photo::whereIn('user_id', $followingIds)
            ->with(['photographer', 'likes', 'comments.user'])
            ->withCount('likes')
            ->latest()
            ->take(20)
            ->get();

        $isFeedRecommended = $feedPhotos->isEmpty();
        if ($isFeedRecommended) {
            // Load recommended / latest public photos
            $feedPhotos = Photo::with(['photographer', 'likes', 'comments.user'])
                ->withCount('likes')
                ->latest()
                ->take(15)
                ->get();
        }

        // Suggested photographers to follow (excluding self and already followed)
        $suggestedPhotographers = User::whereHas('role', fn ($q) => $q->where('slug', 'photographer'))
            ->where('id', '!=', $user->id)
            ->whereNotIn('id', $followingIds)
            ->withCount('followers')
            ->orderBy('followers_count', 'desc')
            ->take(5)
            ->get();

        $unreadMessages = $user->unreadMessageCount();

        return view('dashboard', compact(
            'user',
            'storiesRaw',
            'feedPhotos',
            'isFeedRecommended',
            'suggestedPhotographers',
            'unreadMessages'
        ));
    }
}
