<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use App\Services\ProfileService;
use App\Repositories\WalletTransactionRepository;
use App\Http\Requests\UpdateProfileRequest;
use App\Http\Requests\ApplyCreatorRequest;
use App\Traits\ApiResponse;
use Exception;

class ProfileController extends Controller
{
    use ApiResponse;

    protected ProfileService $profileService;
    protected WalletTransactionRepository $walletRepo;

    public function __construct(ProfileService $profileService, WalletTransactionRepository $walletRepo)
    {
        $this->profileService = $profileService;
        $this->walletRepo = $walletRepo;
    }

    public function getProfile()
    {
        $user = Auth::guard('api')->user();
        $userData = $this->profileService->getProfileData($user->id);

        return $this->successResponse('Data profil berhasil diambil', $userData);
    }

    public function identity()
    {
        $user = Auth::guard('api')->user();
        $followRepo = app(\App\Repositories\FollowRepository::class);

        return response()->json([
            'status' => true,
            'data' => [
                'id' => $user->id,
                'name' => $user->name,
                'username' => $user->username,
                'email' => $user->email,
                'role' => $user->role,
                'sub_role' => $user->sub_role instanceof \BackedEnum ? $user->sub_role->value : $user->sub_role,
                'avatar_url' => $user->avatar_url,
                'is_creator_approved' => (bool) $user->is_creator_approved,
                'balance' => $user->balance,
                'followers_count' => $followRepo->getFollowersCount($user->id),
                'following_count' => $followRepo->getFollowingCount($user->id),
            ],
        ]);
    }

    public function permissions()
    {
        $user = Auth::guard('api')->user();

        return response()->json([
            'status' => true,
            'data' => [
                'role' => $user->role,
                'permissions' => config('permissions.' . $user->role, []),
            ],
        ]);
    }

    public function application()
    {
        $user = Auth::guard('api')->user();
        $repo = app(\App\Repositories\CreatorApplicationRepository::class);
        $application = $repo->findLatestByUserId($user->id);

        return response()->json([
            'status' => true,
            'data' => $application
        ]);
    }

    public function updateProfile(UpdateProfileRequest $request)
    {
        $user = Auth::guard('api')->user();
        $updatedUser = $this->profileService->updateProfile($user->id, $request->validated());

        return $this->successResponse('Profil berhasil diperbarui.', ['user' => $updatedUser]);
    }

    public function applyCreator(ApplyCreatorRequest $request)
    {
        $user = Auth::guard('api')->user();

        try {
            $updatedUser = $this->profileService->applyCreator($user->id, $request->validated());
            return $this->successResponse('Pengajuan Kreator berhasil dikirim.', ['user' => $updatedUser]);
        } catch (Exception $e) {
            return $this->errorResponse($e->getMessage(), $e->getCode() ?: 500);
        }
    }

    public function history(Request $request)
    {
        $user = Auth::guard('api')->user();
        $year = $request->has('year') ? (int) $request->year : null;
        
        $history = $this->walletRepo->getHistoryByUser($user->id, $year);

        return $this->successResponse('Riwayat transaksi berhasil diambil', ['history' => $history]);
    }
}
