<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\User;
use App\Models\CreatorApplication;
use App\Models\UserPihak;
use App\Models\Notification;
use App\Models\PihakCategory;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class AdminController extends Controller
{
    public function getApplications(Request $request)
    {
        $user = Auth::guard('api')->user();

        if ($user->role !== 'admin') {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized. Admin access only.'
            ], 403);
        }

        $status = $request->query('status'); // optional filter: pending, approved, rejected

        $query = CreatorApplication::with('user');

        if ($status) {
            $query->where('status', $status);
        }

        $applications = $query->orderBy('applied_at', 'desc')->get();

        return response()->json([
            'success' => true,
            'data' => $applications
        ]);
    }

    public function approveApplication($id)
    {
        $adminUser = Auth::guard('api')->user();

        if ($adminUser->role !== 'admin') {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized. Admin access only.'
            ], 403);
        }

        $application = CreatorApplication::find($id);

        if (!$application) {
            return response()->json([
                'success' => false,
                'message' => 'Pengajuan tidak ditemukan.'
            ], 404);
        }

        if ($application->status !== 'pending') {
            return response()->json([
                'success' => false,
                'message' => 'Pengajuan sudah diproses sebelumnya.'
            ], 400);
        }

        try {
            DB::beginTransaction();

            // 1. Update application status
            $application->status = 'approved';
            $application->reviewed_at = now();
            $application->admin_note = 'Disetujui oleh Admin.';
            $application->save();

            // 2. Upgrade Applicant User
            $applicant = User::find($application->user_id);
            if ($applicant) {
                $applicant->role = 'creator';
                $applicant->is_creator_approved = true;
                $applicant->selected_pihak = $application->pihak_category;
                $applicant->save();

                // 3. Upsert UserPihak mappings for both roles
                UserPihak::updateOrCreate(
                    [
                        'user_id' => $applicant->id,
                        'pihak_slug' => $application->pihak_category,
                        'role_type' => 'creator',
                    ],
                    [
                        'is_active' => true,
                        'joined_at' => now(),
                    ]
                );

                UserPihak::updateOrCreate(
                    [
                        'user_id' => $applicant->id,
                        'pihak_slug' => $application->pihak_category,
                        'role_type' => 'user',
                    ],
                    [
                        'is_active' => true,
                        'joined_at' => now(),
                    ]
                );

                // Get category name for notification
                $cat = PihakCategory::where('slug', $application->pihak_category)->first();
                $pihakName = $cat ? $cat->name : ucfirst($application->pihak_category);

                // 4. Send Approval Notification
                Notification::create([
                    'user_id' => $applicant->id,
                    'title' => 'Pengajuan Kreator Disetujui!',
                    'message' => "Selamat! Pengajuan Anda sebagai Kreator di kategori {$pihakName} telah disetujui. Silakan switch peran ke Creator di dasbor Anda.",
                    'type' => 'creator_approved',
                    'is_read' => false,
                    'created_at' => now(),
                ]);
            }

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Pengajuan Kreator berhasil disetujui.'
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Gagal menyetujui pengajuan: ' . $e->getMessage()
            ], 500);
        }
    }

    public function rejectApplication(Request $request, $id)
    {
        $adminUser = Auth::guard('api')->user();

        if ($adminUser->role !== 'admin') {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized. Admin access only.'
            ], 403);
        }

        $request->validate([
            'admin_note' => 'required|string|max:500',
        ]);

        $application = CreatorApplication::find($id);

        if (!$application) {
            return response()->json([
                'success' => false,
                'message' => 'Pengajuan tidak ditemukan.'
            ], 404);
        }

        if ($application->status !== 'pending') {
            return response()->json([
                'success' => false,
                'message' => 'Pengajuan sudah diproses sebelumnya.'
            ], 400);
        }

        try {
            DB::beginTransaction();

            // 1. Update application status
            $application->status = 'rejected';
            $application->reviewed_at = now();
            $application->admin_note = $request->admin_note;
            $application->save();

            // 2. Send Rejection Notification
            Notification::create([
                'user_id' => $application->user_id,
                'title' => 'Pengajuan Kreator Ditolak',
                'message' => "Mohon maaf, pengajuan Anda ditolak dengan alasan: " . $request->admin_note,
                'type' => 'creator_rejected',
                'is_read' => false,
                'created_at' => now(),
            ]);

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Pengajuan Kreator berhasil ditolak.'
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Gagal menolak pengajuan: ' . $e->getMessage()
            ], 500);
        }
    }
}
