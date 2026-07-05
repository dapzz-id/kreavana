<?php

namespace App\Services;

use App\Repositories\FollowRepository;
use App\Repositories\UserRepository;
use Illuminate\Support\Facades\DB;
use Exception;

class FollowService
{
    protected FollowRepository $followRepo;
    protected UserRepository $userRepo;

    public function __construct(FollowRepository $followRepo, UserRepository $userRepo)
    {
        $this->followRepo = $followRepo;
        $this->userRepo = $userRepo;
    }

    public function followUser(string $followerId, string $followingId)
    {
        if ($followerId === $followingId) {
            throw new Exception("Anda tidak dapat mengikuti diri sendiri.");
        }

        $targetUser = $this->userRepo->find($followingId);
        if (!$targetUser) {
            throw new Exception("Pengguna tidak ditemukan.");
        }

        try {
            DB::beginTransaction();

            $follow = $this->followRepo->follow($followerId, $followingId);

            DB::commit();
            
            return [
                'status' => true,
                'message' => 'Berhasil mengikuti pengguna.',
                'data' => $follow
            ];
        } catch (Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }

    public function unfollowUser(string $followerId, string $followingId)
    {
        if ($followerId === $followingId) {
            throw new Exception("Anda tidak dapat berhenti mengikuti diri sendiri.");
        }

        $targetUser = $this->userRepo->find($followingId);
        if (!$targetUser) {
            throw new Exception("Pengguna tidak ditemukan.");
        }

        try {
            DB::beginTransaction();

            $this->followRepo->unfollow($followerId, $followingId);

            DB::commit();
            
            return [
                'status' => true,
                'message' => 'Berhasil berhenti mengikuti pengguna.',
            ];
        } catch (Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }

    public function getFollowers(string $userId, int $perPage = 15)
    {
        return $this->followRepo->getFollowers($userId, $perPage);
    }

    public function getFollowing(string $userId, int $perPage = 15)
    {
        return $this->followRepo->getFollowing($userId, $perPage);
    }
}
