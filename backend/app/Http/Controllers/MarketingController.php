<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\LargeTransactionReview;
use App\Models\JobContract;
use App\Models\User;
use App\Enums\RoleType;
use App\Traits\ApiResponse;
use Illuminate\Support\Facades\DB;
use Exception;

class MarketingController extends Controller
{
    use ApiResponse;

    public function index(Request $request)
    {
        $status = $request->query('status');

        $query = LargeTransactionReview::with([
            'jobContract.client:id,name,username,avatar_url',
            'jobContract.creator:id,name,username,avatar_url',
            'marketing:id,name,username,avatar_url'
        ])->orderBy('created_at', 'desc');

        if ($status) {
            $query->where('status', $status);
        }

        $reviews = $query->paginate((int) $request->query('per_page', 20));

        return $this->successResponse('Data review transaksi bernilai besar berhasil diambil.', $reviews->toArray());
    }

    public function show(string $id)
    {
        $review = LargeTransactionReview::with([
            'jobContract.client:id,name,username,avatar_url',
            'jobContract.creator:id,name,username,avatar_url',
            'marketing:id,name,username,avatar_url'
        ])->findOrFail($id);

        return $this->successResponse('Detail review transaksi berhasil diambil.', $review->toArray());
    }

    public function assign(Request $request, string $id)
    {
        $actor = $request->user();
        if ($actor->role !== RoleType::Marketing && $actor->role !== RoleType::Admin) {
            return $this->errorResponse('Akses ditolak. Hanya Marketing atau Admin yang dapat ditugaskan.', 403);
        }

        $review = LargeTransactionReview::findOrFail($id);
        $review->assigned_marketing_id = $request->input('marketing_id', $actor->id);
        $review->status = 'assigned';
        $review->save();

        return $this->successResponse('Transaksi berhasil ditugaskan ke Marketing.', $review->toArray());
    }

    public function verify(Request $request, string $id)
    {
        $actor = $request->user();
        if ($actor->role !== RoleType::Marketing && $actor->role !== RoleType::Admin) {
            return $this->errorResponse('Akses ditolak.', 403);
        }

        $validated = $request->validate([
            'verification_notes' => 'required|string|min:10',
            'document_url' => 'nullable|string|max:500',
            'client_verified' => 'required|boolean',
            'creator_verified' => 'required|boolean',
        ]);

        $review = LargeTransactionReview::findOrFail($id);
        $review->verification_notes = $validated['verification_notes'];
        if (!empty($validated['document_url'])) {
            $review->document_url = $validated['document_url'];
        }

        if ($validated['client_verified'] && !$review->client_verified_at) {
            $review->client_verified_at = now();
        }
        if ($validated['creator_verified'] && !$review->creator_verified_at) {
            $review->creator_verified_at = now();
        }

        $review->status = 'document_verified';
        $review->save();

        return $this->successResponse('Verifikasi transaksi berhasil dicatat.', $review->toArray());
    }

    public function approve(Request $request, string $id)
    {
        $actor = $request->user();
        if ($actor->role !== RoleType::Marketing && $actor->role !== RoleType::Admin) {
            return $this->errorResponse('Akses ditolak.', 403);
        }

        return DB::transaction(function () use ($id, $actor, $request) {
            $review = LargeTransactionReview::where('id', $id)->lockForUpdate()->firstOrFail();

            if (!$review->client_verified_at || !$review->creator_verified_at) {
                return $this->errorResponse('Kedua belah pihak (klien & kreator) harus diverifikasi terlebih dahulu.', 400);
            }

            $review->status = 'approved';
            $review->approved_at = now();
            if ($request->filled('notes')) {
                $review->verification_notes = ($review->verification_notes ? $review->verification_notes . "\n\n" : '') . "Approval note: " . $request->input('notes');
            }
            $review->save();

            return $this->successResponse('Transaksi bernilai besar telah disetujui oleh Marketing.', $review->toArray());
        });
    }

    public function reject(Request $request, string $id)
    {
        $actor = $request->user();
        if ($actor->role !== RoleType::Marketing && $actor->role !== RoleType::Admin) {
            return $this->errorResponse('Akses ditolak.', 403);
        }

        $validated = $request->validate([
            'reason' => 'required|string|min:5',
        ]);

        $review = LargeTransactionReview::findOrFail($id);
        $review->status = 'rejected';
        $review->verification_notes = ($review->verification_notes ? $review->verification_notes . "\n\n" : '') . "Alasan Penolakan: " . $validated['reason'];
        $review->save();

        return $this->successResponse('Transaksi bernilai besar ditolak oleh Marketing.', $review->toArray());
    }
}
