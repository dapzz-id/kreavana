<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Services\FollowService;
use Exception;

class FollowController extends Controller
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
            return response()->json([
                'status' => true,
                'message' => $result['message'],
                'data' => $result['data']
            ], 200);
        } catch (Exception $e) {
            return response()->json([
                'status' => false,
                'message' => $e->getMessage()
            ], $e->getCode() === 404 ? 404 : 422);
        }
    }

    public function unfollow(Request $request, string $userId)
    {
        try {
            $followerId = auth('api')->id();
            $result = $this->followService->unfollowUser($followerId, $userId);
            return response()->json([
                'status' => true,
                'message' => $result['message'],
                'data' => null
            ], 200);
        } catch (Exception $e) {
            return response()->json([
                'status' => false,
                'message' => $e->getMessage()
            ], $e->getCode() === 404 ? 404 : 422);
        }
    }

    public function followers(Request $request, string $userId)
    {
        try {
            $perPage = $request->query('per_page', 15);
            $followers = $this->followService->getFollowers($userId, $perPage);
            return response()->json([
                'status' => true,
                'message' => 'Berhasil mengambil daftar pengikut.',
                'data' => $followers
            ], 200);
        } catch (Exception $e) {
            return response()->json([
                'status' => false,
                'message' => 'Terjadi kesalahan.'
            ], 500);
        }
    }

    public function following(Request $request, string $userId)
    {
        try {
            $perPage = $request->query('per_page', 15);
            $following = $this->followService->getFollowing($userId, $perPage);
            return response()->json([
                'status' => true,
                'message' => 'Berhasil mengambil daftar diikuti.',
                'data' => $following
            ], 200);
        } catch (Exception $e) {
            return response()->json([
                'status' => false,
                'message' => 'Terjadi kesalahan.'
            ], 500);
        }
    }
}
