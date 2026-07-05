<?php

namespace App\Repositories;

use App\Models\UserFollow;
use Illuminate\Database\Eloquent\Collection;

class FollowRepository extends BaseRepository
{
    public function __construct(UserFollow $model)
    {
        parent::__construct($model);
    }

    public function follow(string $followerId, string $followingId): UserFollow
    {
        return $this->model->firstOrCreate([
            'follower_id' => $followerId,
            'following_id' => $followingId,
        ]);
    }

    public function unfollow(string $followerId, string $followingId): bool
    {
        return (bool) $this->model->where('follower_id', $followerId)
            ->where('following_id', $followingId)
            ->delete();
    }

    public function isFollowing(string $followerId, string $followingId): bool
    {
        return $this->model->where('follower_id', $followerId)
            ->where('following_id', $followingId)
            ->exists();
    }

    public function getFollowers(string $userId, int $perPage = 15)
    {
        return $this->model->with('follower:id,name,username,avatar_url,role,sub_role,is_creator_approved')
            ->where('following_id', $userId)
            ->orderBy('created_at', 'desc')
            ->paginate($perPage);
    }

    public function getFollowing(string $userId, int $perPage = 15)
    {
        return $this->model->with('following:id,name,username,avatar_url,role,sub_role,is_creator_approved')
            ->where('follower_id', $userId)
            ->orderBy('created_at', 'desc')
            ->paginate($perPage);
    }

    public function getFollowersCount(string $userId): int
    {
        return $this->model->where('following_id', $userId)->count();
    }

    public function getFollowingCount(string $userId): int
    {
        return $this->model->where('follower_id', $userId)->count();
    }
}
