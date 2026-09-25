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

    public function approveApplication($applicationId): void
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
                if ($application->type === 'client_verification') {
                    // Verifikasi KTP Klien: Tidak ubah role jadi creator, beri centang biru
                    $this->userRepo->update($applicant->id, [
                        'is_verified' => true,
                        'verification_type' => 'client',
                        'verified_at' => now(),
                        'nik' => $application->nik,
                        'full_name_ktp' => $application->full_name_ktp,
                        'ktp_photo_url' => $application->ktp_photo_url,
                        'selfie_photo_url' => $application->selfie_photo_url,
                    ]);

                    $this->notificationRepo->create([
                        'user_id' => $applicant->id,
                        'title' => 'Verifikasi Klien Disetujui!',
                        'message' => 'Selamat! Verifikasi identitas KTP Anda berhasil disetujui oleh Admin. Akun Anda telah mendapatkan lencana Centang Biru dan Anda dapat mempublikasikan proyek.',
                        'type' => 'client_verified',
                        'is_read' => false,
                        'created_at' => now(),
                    ]);
                } else {
                    // Upgrade Creator: Ubah role jadi creator, beri centang hijau
                    $updateData = [
                        'role' => 'creator',
                        'is_creator_approved' => true,
                        'is_verified' => true,
                        'verification_type' => 'creator',
                        'verified_at' => now(),
                        'sub_role' => $application->sub_role_slug,
                    ];

                    if (!empty($application->nik)) $updateData['nik'] = $application->nik;
                    if (!empty($application->full_name_ktp)) $updateData['full_name_ktp'] = $application->full_name_ktp;
                    if (!empty($application->ktp_photo_url)) $updateData['ktp_photo_url'] = $application->ktp_photo_url;
                    if (!empty($application->selfie_photo_url)) $updateData['selfie_photo_url'] = $application->selfie_photo_url;
                    if (!empty($application->nib_number)) $updateData['nib_number'] = $application->nib_number;
                    if (!empty($application->nib_file_url)) $updateData['nib_file_url'] = $application->nib_file_url;

                    $this->userRepo->update($applicant->id, $updateData);

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
                        'message' => "Selamat! Pengajuan Anda sebagai Kreator di kategori {$pihakName} telah disetujui. Akun Anda kini memiliki lencana Centang Hijau.",
                        'type' => 'creator_approved',
                        'is_read' => false,
                        'created_at' => now(),
                    ]);
                }
            }

            DB::commit();
        } catch (Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }

    public function rejectApplication($applicationId, string $adminNote): void
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

            $isClient = $application->type === 'client_verification';
            $this->notificationRepo->create([
                'user_id' => $application->user_id,
                'title' => $isClient ? 'Verifikasi Klien Ditolak' : 'Pengajuan Kreator Ditolak',
                'message' => "Mohon maaf, pengajuan Anda ditolak dengan alasan: " . $adminNote,
                'type' => $isClient ? 'client_rejected' : 'creator_rejected',
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
