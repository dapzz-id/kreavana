<?php

namespace App\Repositories\Contracts;

use App\Models\Like;
use App\Models\Comment;
use App\Models\SavedPhoto;

interface SocialRepositoryInterface
{
    // Likes
    public function findLike(int $userId, int $photoId): ?Like;
    public function createLike(int $userId, int $photoId): Like;
    public function deleteLike(Like $like): bool;
    public function countLikes(int $photoId): int;

    // Comments
    public function createComment(int $userId, int $photoId, string $content): Comment;
    public function getCommentsForPhoto(int $photoId);

    // Saves
    public function findSave(int $userId, int $photoId): ?SavedPhoto;
    public function createSave(int $userId, int $photoId): SavedPhoto;
    public function deleteSave(SavedPhoto $save): bool;
    public function getSavedPhotoIds(int $userId): array;
}
