<?php

namespace App\Services;

use App\Repositories\CreatorApplicationRepository;
use App\Repositories\UserRepository;
use App\Repositories\UserSubRoleRepository;
use App\Repositories\SubRoleCategoryRepository;
use App\Repositories\NotificationRepository;
use Illuminate\Support\Facades\DB;
use Exception;

class AdminService extends BaseService
{
    protected CreatorApplicationRepository $appRepo;
    protected UserRepository $userRepo;
    protected UserSubRoleRepository $userSubRoleRepo;
    protected SubRoleCategoryRepository $subRoleCategoryRepo;
    protected NotificationRepository $notificationRepo;

    public function __construct(
        CreatorApplicationRepository $appRepo,
        UserRepository $userRepo,
        UserSubRoleRepository $userSubRoleRepo,
        SubRoleCategoryRepository $subRoleCategoryRepo,
        NotificationRepository $notificationRepo
    ) {
        $this->appRepo = $appRepo;
        $this->userRepo = $userRepo;
        $this->userSubRoleRepo = $userSubRoleRepo;
        $this->subRoleCategoryRepo = $subRoleCategoryRepo;
        $this->notificationRepo = $notificationRepo;
    }

    public function getApplications(?string $status = null)
    {
        $query = \App\Models\CreatorApplication::with('user:id,name,username,email');

        if ($status) {
            $query->where('status', $status);
        }

        return $query->orderBy('applied_at', 'desc')->get();
    }

    public function approveApplication(int $applicationId): void
    {
        $application = $this->appRepo->find($applicationId);

        if (!$application) {
            throw new Exception('Pengajuan tidak ditemukan.', 404);
        }

        if ($application->status !== 'pending') {
            throw new Exception('Pengajuan sudah diproses sebelumnya.', 400);
        }

        try {
            DB::beginTransaction();

            $this->appRepo->update($applicationId, [
                'status' => 'approved',
                'reviewed_at' => now(),
                'admin_note' => 'Disetujui oleh Admin.',
            ]);

            $applicant = $this->userRepo->find($application->user_id);
            if ($applicant) {
                $this->userRepo->update($applicant->id, [
                    'role' => 'creator',
                    'is_creator_approved' => true,
                    'sub_role' => $application->sub_role_slug,
                ]);

                \App\Models\UserSubRole::updateOrCreate(
                    ['user_id' => $applicant->id, 'sub_role_slug' => $application->sub_role_slug, 'role_type' => 'creator'],
                    ['is_active' => true, 'joined_at' => now()]
                );

                \App\Models\UserSubRole::updateOrCreate(
                    ['user_id' => $applicant->id, 'sub_role_slug' => $application->sub_role_slug, 'role_type' => 'user'],
                    ['is_active' => true, 'joined_at' => now()]
                );

                $cat = $this->subRoleCategoryRepo->findBySlug($application->sub_role_slug);
                $pihakName = $cat ? $cat->name : ucfirst($application->sub_role_slug);

                $this->notificationRepo->create([
                    'user_id' => $applicant->id,
                    'title' => 'Pengajuan Kreator Disetujui!',
                    'message' => "Selamat! Pengajuan Anda sebagai Kreator di kategori {$pihakName} telah disetujui. Silakan switch peran ke Creator di dasbor Anda.",
                    'type' => 'creator_approved',
                    'is_read' => false,
                    'created_at' => now(),
                ]);
            }

            DB::commit();
        } catch (Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }

    public function rejectApplication(int $applicationId, string $adminNote): void
    {
        $application = $this->appRepo->find($applicationId);

        if (!$application) {
            throw new Exception('Pengajuan tidak ditemukan.', 404);
        }

        if ($application->status !== 'pending') {
            throw new Exception('Pengajuan sudah diproses sebelumnya.', 400);
        }

        try {
            DB::beginTransaction();

            $this->appRepo->update($applicationId, [
                'status' => 'rejected',
                'reviewed_at' => now(),
                'admin_note' => $adminNote,
            ]);

            $this->notificationRepo->create([
                'user_id' => $application->user_id,
                'title' => 'Pengajuan Kreator Ditolak',
                'message' => "Mohon maaf, pengajuan Anda ditolak dengan alasan: " . $adminNote,
                'type' => 'creator_rejected',
                'is_read' => false,
                'created_at' => now(),
            ]);

            DB::commit();
        } catch (Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }
}
