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

            $reuseKtp = filter_var($data['reuse_ktp'] ?? false, FILTER_VALIDATE_BOOLEAN);
            $ktpPhotoUrl = null;
            $selfiePhotoUrl = null;
            $nik = $data['nik'] ?? null;
            $fullNameKtp = $data['full_name_ktp'] ?? null;
            $birthPlace = $data['birth_place'] ?? null;
            $birthDate = $data['birth_date'] ?? null;
            $addressKtp = $data['address_ktp'] ?? null;

            if ($reuseKtp) {
                // Gunakan riwayat KTP yang sudah pernah diverifikasi
                $latest = $this->creatorAppRepo->findLatestByUserId($userId);
                $nik = $user->nik ?? $latest?->nik;
                $fullNameKtp = $user->full_name_ktp ?? $latest?->full_name_ktp;
                $birthPlace = $data['birth_place'] ?? $latest?->birth_place;
                $birthDate = $data['birth_date'] ?? $latest?->birth_date;
                $addressKtp = $data['address_ktp'] ?? $latest?->address_ktp;
                $ktpPhotoUrl = $user->ktp_photo_url ?? $latest?->ktp_photo_url;
                $selfiePhotoUrl = $user->selfie_photo_url ?? $latest?->selfie_photo_url;

                if (empty($ktpPhotoUrl) || empty($nik)) {
                    throw new Exception('Data KTP riwayat tidak ditemukan. Silakan upload KTP baru.', 422);
                }
            } else {
                if (empty($data['ktp_photo_url'])) {
                    throw new Exception('Foto KTP wajib diupload.', 422);
                }
                $ktpPhotoUrl = $this->savePhoto($user->id, $data['ktp_photo_url'], 'ktp');
                $selfiePhotoUrl = !empty($data['selfie_photo_url']) ? $this->savePhoto($user->id, $data['selfie_photo_url'], 'selfie') : null;

                if (!$ktpPhotoUrl) {
                    throw new Exception('Foto KTP gagal diupload. Pastikan format JPG/PNG dan ukuran tidak terlalu besar.', 422);
                }
            }

            // Simpan NIB jika dilampirkan (untuk EO / Agensi / Studio / Lembaga)
            $nibFileUrl = null;
            if (!empty($data['nib_file_url'])) {
                $nibFileUrl = $this->savePhoto($user->id, $data['nib_file_url'], 'nib');
            }

            $this->creatorAppRepo->create([
                'user_id' => $user->id,
                'type' => 'creator_upgrade',
                'sub_role_slug' => $data['sub_role_category'],
                'skill_description' => $data['skill_description'],
                'portfolio_link' => $data['portfolio_link'],
                'experience' => $data['experience'] ?? null,
                'ktp_photo_url' => $ktpPhotoUrl,
                'selfie_photo_url' => $selfiePhotoUrl,
                'nik' => $nik,
                'full_name_ktp' => $fullNameKtp,
                'birth_place' => $birthPlace,
                'birth_date' => $birthDate,
                'address_ktp' => $addressKtp,
                'nib_number' => $data['nib_number'] ?? null,
                'nib_file_url' => $nibFileUrl,
                'reused_ktp' => $reuseKtp,
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

    public function applyClientVerification(string $userId, array $data): \App\Models\CreatorApplication
    {
        $user = $this->userRepo->find($userId);

        $existing = $this->creatorAppRepo->findPendingByUserId($userId);
        if ($existing) {
            throw new Exception('Anda sudah memiliki pengajuan verifikasi yang sedang diproses.', 422);
        }

        try {
            DB::beginTransaction();

            $ktpPhotoUrl = $this->savePhoto($user->id, $data['ktp_photo_url'], 'ktp');
            $selfiePhotoUrl = !empty($data['selfie_photo_url']) ? $this->savePhoto($user->id, $data['selfie_photo_url'], 'selfie') : null;

            if (!$ktpPhotoUrl) {
                throw new Exception('Foto KTP gagal diupload. Pastikan format JPG/PNG.', 422);
            }

            $app = $this->creatorAppRepo->create([
                'user_id' => $user->id,
                'type' => 'client_verification',
                'sub_role_slug' => 'client',
                'skill_description' => 'Verifikasi Identitas Klien / Pemilik Proyek (KTP)',
                'portfolio_link' => null,
                'experience' => null,
                'ktp_photo_url' => $ktpPhotoUrl,
                'selfie_photo_url' => $selfiePhotoUrl,
                'nik' => $data['nik'],
                'full_name_ktp' => $data['full_name_ktp'],
                'birth_place' => $data['birth_place'] ?? null,
                'birth_date' => $data['birth_date'] ?? null,
                'address_ktp' => $data['address_ktp'] ?? null,
                'status' => 'pending',
                'applied_at' => now(),
            ]);

            $this->notificationRepo->create([
                'user_id' => $user->id,
                'title' => 'Pengajuan Verifikasi Klien Dikirim',
                'message' => 'Pengajuan verifikasi KTP Anda berhasil dikirim dan sedang ditinjau oleh Admin. Setelah disetujui, Anda akan mendapatkan centang biru dan dapat membuat proyek.',
                'type' => 'client_verification_applied',
                'is_read' => false,
                'created_at' => now(),
            ]);

            DB::commit();

            return $app;

        } catch (Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }

    public function getVerificationStatus(string $userId): array
    {
        $user = $this->userRepo->find($userId);
        $latest = $this->creatorAppRepo->findLatestByUserId($userId);
        $pending = $this->creatorAppRepo->findPendingByUserId($userId);

        $canReuseKtp = false;
        $reusableKtp = null;

        if ($user->is_verified && !empty($user->nik) && !empty($user->ktp_photo_url)) {
            $canReuseKtp = true;
            $reusableKtp = [
                'nik' => $user->nik,
                'full_name_ktp' => $user->full_name_ktp,
                'birth_place' => $user->birth_place,
                'birth_date' => $user->birth_date ? (is_string($user->birth_date) ? $user->birth_date : $user->birth_date->format('Y-m-d')) : null,
                'address_ktp' => $user->address_ktp,
                'ktp_photo_url' => $user->ktp_photo_url,
                'selfie_photo_url' => $user->selfie_photo_url,
            ];
        } elseif ($latest && $latest->status === 'approved' && !empty($latest->nik)) {
            $canReuseKtp = true;
            $reusableKtp = [
                'nik' => $latest->nik,
                'full_name_ktp' => $latest->full_name_ktp,
                'birth_place' => $latest->birth_place,
                'birth_date' => $latest->birth_date ? (is_string($latest->birth_date) ? $latest->birth_date : $latest->birth_date->format('Y-m-d')) : null,
                'address_ktp' => $latest->address_ktp,
                'ktp_photo_url' => $latest->ktp_photo_url,
                'selfie_photo_url' => $latest->selfie_photo_url,
            ];
        }

        return [
            'is_verified' => (bool) $user->is_verified,
            'verification_type' => $user->verification_type,
            'verified_at' => $user->verified_at?->toISOString(),
            'has_pending' => $pending !== null,
            'pending_application' => $pending,
            'latest_application' => $latest,
            'can_reuse_ktp' => $canReuseKtp,
            'reusable_ktp' => $reusableKtp,
        ];
    }

    public function getPublicProfile(string $userId): array
    {
        $user = $this->userRepo->find($userId);
        if (!$user) {
            throw new Exception('Pengguna tidak ditemukan.', 404);
        }

        $isCreator = $user->role->value === 'creator';
        $authUser = auth('api')->user();

        $data = [
            'id' => $user->id,
            'name' => $user->name,
            'username' => $user->username,
            'avatar_url' => $user->avatar_url,
            'role' => $user->role->value,
            'sub_role' => $user->sub_role instanceof \BackedEnum ? $user->sub_role->value : $user->sub_role,
            'sub_role_label' => $user->sub_role_label,
            'is_verified' => (bool) $user->is_verified,
            'verification_type' => $user->verification_type,
            'bio' => $user->bio,
            'location' => $user->location,
            'created_at' => $user->created_at?->toISOString(),
            'followers_count' => $this->followRepo->getFollowersCount($userId),
            'following_count' => $this->followRepo->getFollowingCount($userId),
            'is_following' => $authUser ? $this->followRepo->isFollowing($authUser->id, $userId) : false,
        ];

        if ($isCreator) {
            // 1. Portofolio Pribadi (Karya dan item portofolio)
            $portfolio = \App\Models\PortfolioItem::where('user_id', $userId)
                ->where(function ($q) {
                    $q->where('source', '!=', 'external')->orWhereNull('source');
                })
                ->orderBy('sort_order')
                ->orderBy('created_at', 'desc')
                ->get();
            $data['portfolio_pribadi'] = $portfolio->toArray();

            // 2. Proyek di App Ini (Internal): Kontrak pekerjaan di Kreavana
            $contracts = \App\Models\JobContract::where('creator_id', $userId)
                ->with('client:id,name,username,avatar_url')
                ->orderBy('created_at', 'desc')
                ->get()
                ->map(function ($c) {
                    return [
                        'id' => $c->id,
                        'title' => $c->title,
                        'description' => $c->description,
                        'client_name' => $c->client?->name ?? 'Klien Kreavana',
                        'client_avatar' => $c->client?->avatar_url,
                        'agreed_price' => $c->agreed_price,
                        'status' => $c->contract_status?->value ?? $c->contract_status,
                        'work_status' => $c->work_status?->value ?? $c->work_status,
                        'completed_at' => $c->completed_at?->toISOString(),
                        'created_at' => $c->created_at?->toISOString(),
                    ];
                });
            $data['proyek_internal'] = $contracts->toArray();

            // 3. Proyek di Luar App (Eksternal): Pengalaman atau portofolio eksternal
            $external = \App\Models\PortfolioItem::where('user_id', $userId)
                ->where('source', 'external')
                ->orderBy('sort_order')
                ->orderBy('created_at', 'desc')
                ->get();
            
            $app = $this->creatorAppRepo->findLatestByUserId($userId);
            $data['proyek_eksternal'] = $external->toArray();
            $data['external_experience_text'] = $app?->experience;
            $data['role_label'] = 'Kreator' . ($user->sub_role_label ? ' - ' . $user->sub_role_label : '');
        } else {
            // Klien: Proyek yang pernah dibuat/dipublikasikan di Kreavana
            $opps = \App\Models\Opportunity::where('posted_by', $userId)
                ->orderBy('created_at', 'desc')
                ->get(['id', 'title', 'description', 'budget_range', 'status', 'created_at', 'sub_role_slug']);
            $data['proyek_klien'] = $opps->toArray();
            $data['role_label'] = 'Klien / Pemilik Proyek';
        }

        return $data;
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
