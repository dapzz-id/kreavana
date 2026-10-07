<?php

namespace App\Http\Controllers;

use App\Models\CommunityMember;
use App\Models\CommunityActivity;
use App\Models\CommunityActivityParticipant;
use App\Models\CommunityAnnouncement;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class CommunityController extends Controller
{
    /**
     * Get community members
     */
    public function getMembers(Request $request)
    {
        $userId = Auth::id();
        $communityId = $request->input('community_id', $userId);

        $members = CommunityMember::with(['user:id,name,avatar_url,username,sub_role'])
            ->where('community_id', $communityId)
            ->when($request->filled('status'), function ($q) use ($request) {
                $q->where('status', $request->status);
            })
            ->orderByDesc('joined_at')
            ->paginate($request->input('per_page', 50));

        return response()->json([
            'status' => true,
            'data' => $members->items(),
            'meta' => [
                'current_page' => $members->currentPage(),
                'total' => $members->total(),
            ],
        ]);
    }

    /**
     * Add member to community
     */
    public function addMember(Request $request)
    {
        $request->validate([
            'user_id' => 'required|uuid|exists:users,id',
            'role' => 'sometimes|string|max:100',
        ]);

        $communityId = Auth::id();
        $targetUserId = $request->user_id;

        // Check if already a member
        $existing = CommunityMember::where('community_id', $communityId)
            ->where('user_id', $targetUserId)
            ->first();

        if ($existing) {
            return response()->json([
                'status' => false,
                'message' => 'User sudah menjadi anggota komunitas ini.',
            ], 400);
        }

        $member = CommunityMember::create([
            'community_id' => $communityId,
            'user_id' => $targetUserId,
            'role' => $request->role ?? 'member',
            'status' => 'active',
            'joined_at' => now(),
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Anggota berhasil ditambahkan.',
            'data' => $member->load('user'),
        ], 201);
    }

    /**
     * Update member role/status
     */
    public function updateMember(Request $request, $id)
    {
        $request->validate([
            'role' => 'sometimes|string|max:100',
            'status' => 'sometimes|string|in:active,inactive,banned',
        ]);

        $member = CommunityMember::where('community_id', Auth::id())
            ->where('id', $id)
            ->firstOrFail();

        $member->update($request->only(['role', 'status']));

        return response()->json([
            'status' => true,
            'message' => 'Anggota berhasil diperbarui.',
            'data' => $member,
        ]);
    }

    /**
     * Remove member from community
     */
    public function removeMember($id)
    {
        $member = CommunityMember::where('community_id', Auth::id())
            ->where('id', $id)
            ->firstOrFail();

        $member->delete();

        return response()->json([
            'status' => true,
            'message' => 'Anggota berhasil dihapus dari komunitas.',
        ]);
    }

    /**
     * Get community activities
     */
    public function getActivities(Request $request)
    {
        $userId = Auth::id();
        $communityId = $request->input('community_id', $userId);

        $activities = CommunityActivity::with(['creator:id,name,avatar_url'])
            ->where('community_id', $communityId)
            ->when($request->filled('status'), function ($q) use ($request) {
                $q->where('status', $request->status);
            })
            ->orderByDesc('activity_date')
            ->paginate($request->input('per_page', 50));

        return response()->json([
            'status' => true,
            'data' => $activities->items(),
            'meta' => [
                'current_page' => $activities->currentPage(),
                'total' => $activities->total(),
            ],
        ]);
    }

    /**
     * Create community activity
     */
    public function createActivity(Request $request)
    {
        $request->validate([
            'title' => 'required|string|max:200',
            'description' => 'sometimes|string|max:2000',
            'activity_date' => 'sometimes|date|after_or_equal:today',
            'location' => 'sometimes|string|max:200',
            'max_participants' => 'sometimes|integer|min:1',
        ]);

        $activity = CommunityActivity::create([
            'community_id' => Auth::id(),
            'title' => $request->title,
            'description' => $request->description,
            'activity_date' => $request->activity_date,
            'location' => $request->location,
            'status' => 'pending',
            'max_participants' => $request->max_participants,
            'created_by' => Auth::id(),
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Kegiatan berhasil dibuat.',
            'data' => $activity->load('creator'),
        ], 201);
    }

    /**
     * Update activity
     */
    public function updateActivity(Request $request, $id)
    {
        $request->validate([
            'title' => 'sometimes|string|max:200',
            'description' => 'sometimes|string|max:2000',
            'activity_date' => 'sometimes|date',
            'location' => 'sometimes|string|max:200',
            'status' => 'sometimes|string|in:pending,active,completed,cancelled',
            'max_participants' => 'sometimes|integer|min:1',
        ]);

        $activity = CommunityActivity::where('community_id', Auth::id())
            ->where('id', $id)
            ->firstOrFail();

        $activity->update($request->only([
            'title', 'description', 'activity_date', 'location', 'status', 'max_participants'
        ]));

        return response()->json([
            'status' => true,
            'message' => 'Kegiatan berhasil diperbarui.',
            'data' => $activity,
        ]);
    }

    /**
     * Delete activity
     */
    public function deleteActivity($id)
    {
        $activity = CommunityActivity::where('community_id', Auth::id())
            ->where('id', $id)
            ->firstOrFail();

        $activity->delete();

        return response()->json([
            'status' => true,
            'message' => 'Kegiatan berhasil dihapus.',
        ]);
    }

    /**
     * Join activity
     */
    public function joinActivity(Request $request, $id)
    {
        $activity = CommunityActivity::findOrFail($id);
        $userId = Auth::id();

        // Check if already joined
        $existing = CommunityActivityParticipant::where('activity_id', $id)
            ->where('user_id', $userId)
            ->first();

        if ($existing) {
            return response()->json([
                'status' => false,
                'message' => 'Anda sudah terdaftar untuk kegiatan ini.',
            ], 400);
        }

        CommunityActivityParticipant::create([
            'activity_id' => $id,
            'user_id' => $userId,
            'status' => 'confirmed',
            'joined_at' => now(),
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Berhasil bergabung dengan kegiatan.',
        ]);
    }

    /**
     * Get community announcements
     */
    public function getAnnouncements(Request $request)
    {
        $userId = Auth::id();
        $communityId = $request->input('community_id', $userId);

        $announcements = CommunityAnnouncement::with(['creator:id,name,avatar_url'])
            ->where('community_id', $communityId)
            ->when($request->filled('status'), function ($q) use ($request) {
                $q->where('status', $request->status);
            })
            ->orderByDesc('published_at')
            ->paginate($request->input('per_page', 50));

        return response()->json([
            'status' => true,
            'data' => $announcements->items(),
            'meta' => [
                'current_page' => $announcements->currentPage(),
                'total' => $announcements->total(),
            ],
        ]);
    }

    /**
     * Create announcement
     */
    public function createAnnouncement(Request $request)
    {
        $request->validate([
            'title' => 'required|string|max:200',
            'content' => 'required|string|max:5000',
            'type' => 'sometimes|string|in:general,event,important,warning',
            'priority' => 'sometimes|string|in:low,normal,high,urgent',
            'published_at' => 'sometimes|date',
            'expires_at' => 'sometimes|date|after:published_at',
        ]);

        $announcement = CommunityAnnouncement::create([
            'community_id' => Auth::id(),
            'title' => $request->title,
            'content' => $request->content,
            'type' => $request->type ?? 'general',
            'priority' => $request->priority ?? 'normal',
            'published_at' => $request->published_at ?? now(),
            'expires_at' => $request->expires_at,
            'created_by' => Auth::id(),
            'status' => 'published',
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Pengumuman berhasil dibuat.',
            'data' => $announcement->load('creator'),
        ], 201);
    }

    /**
     * Update announcement
     */
    public function updateAnnouncement(Request $request, $id)
    {
        $request->validate([
            'title' => 'sometimes|string|max:200',
            'content' => 'sometimes|string|max:5000',
            'type' => 'sometimes|string|in:general,event,important,warning',
            'priority' => 'sometimes|string|in:low,normal,high,urgent',
            'published_at' => 'sometimes|date',
            'expires_at' => 'sometimes|date|after:published_at',
            'status' => 'sometimes|string|in:draft,published,archived',
        ]);

        $announcement = CommunityAnnouncement::where('community_id', Auth::id())
            ->where('id', $id)
            ->firstOrFail();

        $announcement->update($request->only([
            'title', 'content', 'type', 'priority', 'published_at', 'expires_at', 'status'
        ]));

        return response()->json([
            'status' => true,
            'message' => 'Pengumuman berhasil diperbarui.',
            'data' => $announcement,
        ]);
    }

    /**
     * Delete announcement
     */
    public function deleteAnnouncement($id)
    {
        $announcement = CommunityAnnouncement::where('community_id', Auth::id())
            ->where('id', $id)
            ->firstOrFail();

        $announcement->delete();

        return response()->json([
            'status' => true,
            'message' => 'Pengumuman berhasil dihapus.',
        ]);
    }
}
