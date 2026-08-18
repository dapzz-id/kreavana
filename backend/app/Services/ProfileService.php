<?php

namespace App\Services;

use App\Repositories\UserRepository;
use App\Repositories\CreatorApplicationRepository;
use App\Repositories\SubRoleCategoryRepository;
use App\Repositories\NotificationRepository;
use App\Repositories\FollowRepository;
use Illuminate\Support\Facades\DB;
use Exception;

class ProfileService extends BaseService
{
    protected UserRepository $userRepo;
    protected CreatorApplicationRepository $creatorAppRepo;
    protected SubRoleCategoryRepository $subRoleCategoryRepo;
    protected NotificationRepository $notificationRepo;
    protected FollowRepository $followRepo;

    public function __construct(
        UserRepository $userRepo,
        CreatorApplicationRepository $creatorAppRepo,
        SubRoleCategoryRepository $subRoleCategoryRepo,
        NotificationRepository $notificationRepo,
        FollowRepository $followRepo
    ) {
        $this->userRepo = $userRepo;
        $this->creatorAppRepo = $creatorAppRepo;
        $this->subRoleCategoryRepo = $subRoleCategoryRepo;
        $this->notificationRepo = $notificationRepo;
        $this->followRepo = $followRepo;
    }

    public function getProfileData(string $userId): array
    {
        $user = $this->userRepo->find($userId);
        $application = $this->creatorAppRepo->findLatestByUserId($userId);

        $userData = $user->toArray();
        if ($application) {
            $userData['application'] = $application;
        }

        $userData['followers_count'] = $this->followRepo->getFollowersCount($userId);
        $userData['following_count'] = $this->followRepo->getFollowingCount($userId);
        
        $authUser = auth('api')->user();
        if ($authUser && $authUser->id !== $userId) {
            $userData['is_following'] = $this->followRepo->isFollowing($authUser->id, $userId);
        }

        return $userData;
    }

    public function updateProfile(string $userId, array $data): \App\Models\User
    {
        $user = $this->userRepo->find($userId);

        if (isset($data['name'])) $user->name = $data['name'];
        if (isset($data['phone'])) $user->phone = $data['phone'];
        if (isset($data['sub_role'])) $user->sub_role = $data['sub_role'];
        if (array_key_exists('max_work_capacity', $data)) $user->max_work_capacity = $data['max_work_capacity'];

        if (isset($data['avatar_url'])) {
            $avatarUrl = $data['avatar_url'];
            if (str_starts_with($avatarUrl, 'data:image')) {
                if (preg_match('/^data:image\/([a-zA-Z0-9\+\-]+);base64,/', $avatarUrl, $type)) {
                    $imageData = substr($avatarUrl, strpos($avatarUrl, ',') + 1);
                    $ext = strtolower($type[1]);
                    if ($ext === 'jpeg') $ext = 'jpg';
                    if ($ext === 'svg+xml') $ext = 'svg';

                    $imageData = str_replace(' ', '+', $imageData);
                    $decoded = base64_decode($imageData);
                    if ($decoded !== false) {
                        $fileName = 'avatar_' . $user->id . '_' . time() . '.' . $ext;
                        $tempPath = sys_get_temp_dir() . '/' . $fileName;
                        file_put_contents($tempPath, $decoded);
                        
                        $uploadedFile = new \Illuminate\Http\UploadedFile($tempPath, $fileName, 'image/' . $ext, null, true);
                        
                        /** @var \App\Services\StorageService $storageService */
                        $storageService = app(\App\Services\StorageService::class);
                        $storageFile = $storageService->store($user, $uploadedFile, 'avatar', 'public');
                        
                        $user->avatar_url = url('storage/' . $storageFile->path);
                        @unlink($tempPath);
                    }
                }
            } else {
                $user->avatar_url = $avatarUrl;
            }
        }

        $user->save();
        return $user;
    }

    public function applyCreator(string $userId, array $data): \App\Models\User
    {
        $user = $this->userRepo->find($userId);

        $existing = $this->creatorAppRepo->findPendingByUserId($userId);
        if ($existing) {
            throw new Exception('Anda sudah memiliki pengajuan kreator yang sedang diproses.', 422);
        }

        try {
            DB::beginTransaction();

            $ktpPhotoUrl = $this->savePhoto($user->id, $data['ktp_photo_url'], 'ktp');
            $selfiePhotoUrl = $this->savePhoto($user->id, $data['selfie_photo_url'], 'selfie');

            if (!$ktpPhotoUrl) {
                throw new Exception('Foto KTP gagal diupload. Pastikan format JPG/PNG dan ukuran tidak terlalu besar.', 422);
            }
            if (!$selfiePhotoUrl) {
                throw new Exception('Foto selfie gagal diupload. Pastikan format JPG/PNG dan ukuran tidak terlalu besar.', 422);
            }

            $this->creatorAppRepo->create([
                'user_id' => $user->id,
                'sub_role_slug' => $data['sub_role_category'], // We accept sub_role_category from frontend
                'skill_description' => $data['skill_description'],
                'portfolio_link' => $data['portfolio_link'],
                'experience' => $data['experience'] ?? null,
                'ktp_photo_url' => $ktpPhotoUrl,
                'selfie_photo_url' => $selfiePhotoUrl,
                'nik' => $data['nik'],
                'full_name_ktp' => $data['full_name_ktp'],
                'birth_place' => $data['birth_place'],
                'birth_date' => $data['birth_date'],
                'address_ktp' => $data['address_ktp'],
                'status' => 'pending',
                'applied_at' => now(),
            ]);

            $cat = $this->subRoleCategoryRepo->findBySlug($data['sub_role_category']);
            $pihakName = $cat ? $cat->name : ucfirst($data['sub_role_category']);

            $this->notificationRepo->create([
                'user_id' => $user->id,
                'title' => 'Pengajuan Kreator Dikirim',
                'message' => "Pengajuan Anda sebagai Kreator kategori {$pihakName} berhasil dikirim dan sedang ditinjau oleh Admin.",
                'type' => 'creator_applied',
                'is_read' => false,
                'created_at' => now(),
            ]);

            DB::commit();

            return $user;

        } catch (Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }

    private function savePhoto(string $userId, string $photoUrl, string $prefix): ?string
    {
        if (!str_starts_with($photoUrl, 'data:image')) {
            return $photoUrl;
        }

        if (preg_match('/^data:image\/(\w+);base64,/', $photoUrl, $type)) {
            $data = substr($photoUrl, strpos($photoUrl, ',') + 1);
            $ext = strtolower($type[1]);
            if (in_array($ext, ['jpg', 'jpeg', 'gif', 'png'])) {
                $data = str_replace(' ', '+', $data);
                $decoded = base64_decode($data);
                if ($decoded !== false) {
                    $fileName = $prefix . '_' . $userId . '_' . time() . '.' . $ext;
                    $tempPath = sys_get_temp_dir() . '/' . $fileName;
                    file_put_contents($tempPath, $decoded);
                    
                    $uploadedFile = new \Illuminate\Http\UploadedFile($tempPath, $fileName, 'image/' . $ext, null, true);
                    
                    $user = \App\Models\User::find($userId);
                    /** @var \App\Services\StorageService $storageService */
                    $storageService = app(\App\Services\StorageService::class);
                    $storageFile = $storageService->store($user, $uploadedFile, $prefix, 'public');
                    
                    @unlink($tempPath);
                    return url('storage/' . $storageFile->path);
                }
            }
        }

        return null;
    }
}
