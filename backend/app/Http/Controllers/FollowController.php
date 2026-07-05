<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Services\FollowService;
use Exception;

class FollowController extends BaseController
{
    protected FollowService $followService;

    public function __construct(FollowService $followService)
    {
        $this->followService = $followService;
    }

    public function follow(Request $request, string $userId)
    {
        try {
            $followerId = auth('api')->id();
            $result = $this->followService->followUser($followerId, $userId);
            return $this->successResponse($result['data'], $result['message']);
        } catch (Exception $e) {
            return $this->errorResponse($e->getMessage(), $e->getCode() === 404 ? 404 : 422);
        }
    }

    public function unfollow(Request $request, string $userId)
    {
        try {
            $followerId = auth('api')->id();
            $result = $this->followService->unfollowUser($followerId, $userId);
            return $this->successResponse(null, $result['message']);
        } catch (Exception $e) {
            return $this->errorResponse($e->getMessage(), $e->getCode() === 404 ? 404 : 422);
        }
    }

    public function followers(Request $request, string $userId)
    {
        try {
            $perPage = $request->query('per_page', 15);
            $followers = $this->followService->getFollowers($userId, $perPage);
            return $this->successResponse($followers, 'Berhasil mengambil daftar pengikut.');
        } catch (Exception $e) {
            return $this->errorResponse('Terjadi kesalahan.', 500);
        }
    }

    public function following(Request $request, string $userId)
    {
        try {
            $perPage = $request->query('per_page', 15);
            $following = $this->followService->getFollowing($userId, $perPage);
            return $this->successResponse($following, 'Berhasil mengambil daftar diikuti.');
        } catch (Exception $e) {
            return $this->errorResponse('Terjadi kesalahan.', 500);
        }
    }
}
