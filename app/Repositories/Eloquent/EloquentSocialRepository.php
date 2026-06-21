<?php

namespace App\Repositories\Eloquent;

use App\Models\Comment;
use App\Models\Like;
use App\Models\SavedPhoto;
use App\Repositories\Contracts\SocialRepositoryInterface;
use Illuminate\Database\Eloquent\Collection;

class EloquentSocialRepository implements SocialRepositoryInterface
{
    // ── Likes ────────────────────────────────────────────────────────────────

    public function findLike(int $userId, int $photoId): ?Like
    {
        return Like::where('user_id', $userId)->where('photo_id', $photoId)->first();
    }

    public function createLike(int $userId, int $photoId): Like
    {
        return Like::create(['user_id' => $userId, 'photo_id' => $photoId]);
    }

    public function deleteLike(Like $like): bool
    {
        return $like->delete();
    }

    public function countLikes(int $photoId): int
    {
        return Like::where('photo_id', $photoId)->count();
    }

    // ── Comments ─────────────────────────────────────────────────────────────

    public function createComment(int $userId, int $photoId, string $content): Comment
    {
        return Comment::create([
            'user_id'  => $userId,
            'photo_id' => $photoId,
            'content'  => $content,
        ]);
    }

    public function getCommentsForPhoto(int $photoId): Collection
    {
        return Comment::with('user')
            ->where('photo_id', $photoId)
            ->latest()
            ->get();
    }

    // ── Saves ─────────────────────────────────────────────────────────────────

    public function findSave(int $userId, int $photoId): ?SavedPhoto
    {
        return SavedPhoto::where('user_id', $userId)->where('photo_id', $photoId)->first();
    }

    public function createSave(int $userId, int $photoId): SavedPhoto
    {
        return SavedPhoto::create(['user_id' => $userId, 'photo_id' => $photoId]);
    }

    public function deleteSave(SavedPhoto $save): bool
    {
        return $save->delete();
    }

    public function getSavedPhotoIds(int $userId): array
    {
        return SavedPhoto::where('user_id', $userId)->pluck('photo_id')->toArray();
    }
}
