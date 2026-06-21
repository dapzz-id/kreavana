<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Repositories\Contracts\PhotographerRequestRepositoryInterface;
use App\Repositories\Contracts\UserRepositoryInterface;
use App\Repositories\Contracts\RoleRepositoryInterface;
use App\Services\LedgerService;
use App\Notifications\SystemNotification;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * AdminController — Superadmin Operations
 *
 * SRP : Only handles admin-facing actions (request approvals, user overview, audit).
 * DIP : Depends on repository interfaces and service abstractions, not Eloquent directly.
 */
class AdminController extends Controller
{
    public function __construct(
        private readonly LedgerService                          $ledgerService,
        private readonly PhotographerRequestRepositoryInterface $photographerRequestRepository,
        private readonly UserRepositoryInterface                $userRepository,
        private readonly RoleRepositoryInterface                $roleRepository,
    ) {}

    /**
     * Show Superadmin dashboard: photographer requests, user list, ledger audit.
     */
    public function dashboard()
    {
        $requests    = $this->photographerRequestRepository->allPending();
        $users       = $this->userRepository->all();
        $auditReport = $this->ledgerService->auditAllUsers();

        return view('admin.dashboard', compact('requests', 'users', 'auditReport'));
    }

    /**
     * Approve a photographer verification request and promote the user.
     */
    public function approveRequest(Request $request, int $id)
    {
        $verification = $this->photographerRequestRepository->findById($id);

        if (!$verification || $verification->status !== 'pending') {
            return redirect()->back()->with('error', 'Permintaan ini sudah diproses atau tidak ditemukan.');
        }

        $photographerRole = $this->roleRepository->findBySlug('photographer');
        if (!$photographerRole) {
            return redirect()->back()->with('error', 'Peran Photographer tidak ditemukan di sistem.');
        }

        $this->photographerRequestRepository->update($verification, [
            'status'      => 'approved',
            'admin_notes' => $request->admin_notes ?? 'Dokumen KTP & NPWP valid dan disetujui.',
        ]);

        $user = $this->userRepository->findById($verification->user_id);
        $this->userRepository->update($user, ['role_id' => $photographerRole->id]);

        Log::info("User #{$user->id} promoted to Photographer by admin approval.");

        // Trigger notification
        $user->notify(new SystemNotification(
            'Pengajuan Fotografer Disetujui',
            'Selamat! Pengajuan Anda untuk menjadi fotografer telah disetujui oleh admin.',
            route('photographer.dashboard'),
            'approval'
        ));

        return redirect()->route('admin.dashboard')
            ->with('success', 'Pengajuan fotografer untuk ' . $user->name . ' telah disetujui.');
    }

    /**
     * Reject a photographer verification request with admin notes.
     */
    public function rejectRequest(Request $request, int $id)
    {
        $verification = $this->photographerRequestRepository->findById($id);

        if (!$verification || $verification->status !== 'pending') {
            return redirect()->back()->with('error', 'Permintaan ini sudah diproses atau tidak ditemukan.');
        }

        $request->validate(['admin_notes' => 'required|string|max:500']);

        $this->photographerRequestRepository->update($verification, [
            'status'      => 'rejected',
            'admin_notes' => $request->admin_notes,
        ]);

        $user = $this->userRepository->findById($verification->user_id);
        Log::info("User #{$user->id} photographer request rejected. Notes: {$request->admin_notes}");

        // Trigger notification
        $user->notify(new SystemNotification(
            'Pengajuan Fotografer Ditolak',
            'Maaf, pengajuan fotografer Anda ditolak. Catatan admin: "' . $request->admin_notes . '"',
            route('profile.edit'),
            'rejection'
        ));

        return redirect()->route('admin.dashboard')
            ->with('success', 'Pengajuan fotografer untuk ' . $user->name . ' telah ditolak.');
    }

    /**
     * Serve a private KTP or NPWP document for admin review.
     */
    public function viewDocument(int $id, string $type)
    {
        $verification = $this->photographerRequestRepository->findById($id);

        if (!$verification) {
            abort(404, 'Permintaan tidak ditemukan.');
        }

        $filePath = match ($type) {
            'ktp'  => storage_path('app/' . $verification->ktp_path),
            'npwp' => storage_path('app/' . $verification->npwp_path),
            default => abort(404),
        };

        if (!file_exists($filePath)) {
            abort(404, 'Berkas dokumen tidak ditemukan di server.');
        }

        return response()->file($filePath);
    }
}
