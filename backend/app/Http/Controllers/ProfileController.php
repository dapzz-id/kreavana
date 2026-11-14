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

        $rawSubRole = $user->sub_role instanceof \BackedEnum ? $user->sub_role->value : $user->sub_role;
        $uname = strtolower($user->username ?? '');
        $email = strtolower($user->email ?? '');
        $isInst = in_array(strtolower((string)$rawSubRole), ['institution', 'school', 'sekolah', 'kampus', 'smk', 'universitas', 'education', 'institusi'])
            || in_array(strtolower((string)($user->role->value ?? '')), ['institution', 'school', 'institusi'])
            || $user->verification_type === 'institution'
            || str_contains($uname, 'institution')
            || str_contains($uname, 'sekolah')
            || str_contains($uname, 'smk')
            || str_starts_with($email, 'institution@')
            || str_starts_with($email, 'smk@')
            || str_starts_with($email, 'sekolah@');

        $effectiveSubRole = $rawSubRole;
        if (empty($effectiveSubRole) && $isInst) {
            $effectiveSubRole = 'institution';
        }
        $effectiveVerifType = $user->verification_type;
        if (empty($effectiveVerifType) && $isInst) {
            $effectiveVerifType = 'institution';
        }

        $data = [
            'id' => $user->id,
            'name' => $user->name,
            'username' => $user->username,
            'email' => $user->email,
            'phone' => $user->phone,
            'role' => $user->role->value,
            'sub_role' => $effectiveSubRole,
            'avatar_url' => $user->avatar_url,
            'is_creator_approved' => (bool) $user->is_creator_approved,
            'is_verified' => (bool) ($user->is_verified || $isInst),
            'verification_type' => $effectiveVerifType,
            'max_work_capacity' => $user->max_work_capacity,
            'balance' => $user->balance,
            'followers_count' => $followRepo->getFollowersCount($user->id),
            'following_count' => $followRepo->getFollowingCount($user->id),
            'subscription_tier' => $user->subscription_tier,
            'storage_limit_bytes' => $user->storage_limit_bytes,
            'max_voice_call_duration_seconds' => $user->max_voice_call_duration_seconds,
            'max_video_call_duration_seconds' => $user->max_video_call_duration_seconds,
            'performance_boost' => $user->performance_boost,
            'created_at' => $user->created_at?->toISOString(),
        ];

        $subRoleLower = strtolower((string) ($effectiveSubRole ?? ''));
        if ($isInst || in_array($subRoleLower, ['institution', 'school', 'sekolah', 'kampus', 'smk', 'universitas', 'education', 'institusi'])) {
            $profileResource = \App\Models\InstitutionResource::where('user_id', $user->id)
                ->where('resource_type', 'profile')
                ->first();
            if ($profileResource) {
                $data['institution_profile'] = [
                    'id' => $profileResource->id,
                    'title' => $profileResource->title,
                    'description' => $profileResource->description,
                    'metadata' => $profileResource->metadata,
                ];
            }
        }

        return response()->json([
            'status' => true,
            'data' => $data,
        ]);
    }

    public function permissions()
    {
        $user = Auth::guard('api')->user();

        return response()->json([
            'status' => true,
            'data' => [
                'role' => $user->role->value,
                'permissions' => config('permissions.' . $user->role->value, []),
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

    public function getPublicProfile(string $id)
    {
        try {
            $data = $this->profileService->getPublicProfile($id);
            return $this->successResponse('Profil pengguna berhasil diambil.', $data);
        } catch (Exception $e) {
            return $this->errorResponse($e->getMessage(), $e->getCode() ?: 404);
        }
    }

    public function getVerificationStatus()
    {
        $user = Auth::guard('api')->user();
        $status = $this->profileService->getVerificationStatus($user->id);
        return $this->successResponse('Status verifikasi berhasil diambil.', $status);
    }

    public function applyClientVerification(Request $request)
    {
        $request->validate([
            'nik' => 'required|regex:/^\d{16}$/',
            'full_name_ktp' => 'required|string|min:3|max:150',
            'birth_place' => 'nullable|string|max:100',
            'birth_date' => 'nullable|date|date_format:Y-m-d|before:today',
            'address_ktp' => 'nullable|string|max:500',
            'ktp_photo_url' => 'required|string',
            'selfie_photo_url' => 'required|string',
        ]);

        $user = Auth::guard('api')->user();

        try {
            $app = $this->profileService->applyClientVerification($user->id, $request->all());
            return $this->successResponse('Pengajuan verifikasi KTP klien berhasil dikirim.', ['application' => $app]);
        } catch (Exception $e) {
            $code = $e->getCode();
            $statusCode = (is_int($code) && $code >= 400 && $code <= 599) ? $code : 422;
            return $this->errorResponse($e->getMessage(), $statusCode);
        }
    }

    public function history(Request $request)
    {
        $user = Auth::guard('api')->user();
        $year = $request->has('year') ? (int) $request->year : null;
        
        $history = $this->walletRepo->getHistoryByUser($user->id, $year);

        return $this->successResponse('Riwayat transaksi berhasil diambil', ['history' => $history]);
    }

    public function updatePublicKey(Request $request)
    {
        $request->validate([
            'public_key' => 'required|string|max:2048',
        ]);

        $publicKey = trim($request->public_key);

        // Simple validation to ensure it's a valid PEM public key format and not a private key
        if (!(str_starts_with($publicKey, '-----BEGIN PUBLIC KEY-----') || str_starts_with($publicKey, '-----BEGIN RSA PUBLIC KEY-----')) || 
            !(str_ends_with($publicKey, '-----END PUBLIC KEY-----') || str_ends_with($publicKey, '-----END RSA PUBLIC KEY-----'))) {
            return $this->errorResponse('Format public key tidak valid.', 422);
        }

        if (str_contains($publicKey, 'PRIVATE KEY')) {
            return $this->errorResponse('Private key tidak diizinkan.', 422);
        }

        $user = Auth::guard('api')->user();
        $user->public_key = $publicKey;
        $user->save();

        return $this->successResponse('Public key berhasil diperbarui.', ['public_key' => $user->public_key]);
    }

    /**
     * Serve verification documents (KTP, Selfie, NIB) with CORS headers for Flutter Web.
     */
    public function showVerificationAsset(Request $request, string $type, string $file)
    {
        if (!in_array($type, ['ktp', 'selfie', 'nib'])) {
            abort(404);
        }

        if (!preg_match('/^[a-zA-Z0-9_\-\.]+\.(jpg|jpeg|png|gif|webp|pdf)$/i', $file)) {
            abort(404);
        }

        $possiblePaths = [
            storage_path("app/public/{$type}/" . $file),
            public_path("storage/{$type}/" . $file),
            public_path("{$type}/" . $file),
        ];

        $path = null;
        foreach ($possiblePaths as $p) {
            if (file_exists($p)) {
                $path = $p;
                break;
            }
        }

        if (!$path) {
            abort(404);
        }

        $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
        $mime = match ($ext) {
            'png' => 'image/png',
            'gif' => 'image/gif',
            'webp' => 'image/webp',
            'pdf' => 'application/pdf',
            default => 'image/jpeg',
        };

        return response()->file($path, [
            'Content-Type' => $mime,
            'Cache-Control' => 'public, max-age=86400',
        ]);
    }
}
