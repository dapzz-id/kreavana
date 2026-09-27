<?php

namespace App\Http\Controllers;

use App\Models\CreatorService;
use Illuminate\Http\Request;

class AdminCreatorServiceController extends Controller
{
    use \App\Traits\ApiResponse;

    private const EO_PACKAGE_CATEGORY = 'eo_event_package';
    private const CREATOR_PACKAGE_CATEGORY = 'creator_package';

    public function index(Request $request)
    {
        $validated = $request->validate([
            'status' => 'nullable|in:pending,active,rejected',
            'package_type' => 'nullable|string|max:100',
        ]);

        $services = CreatorService::query()
            ->with('creator:id,name,username,email')
            ->whereIn('category', [self::EO_PACKAGE_CATEGORY, self::CREATOR_PACKAGE_CATEGORY])
            ->when($validated['status'] ?? null, fn ($query, $status) => $query->where('status', $status))
            ->when($validated['package_type'] ?? null, fn ($query, $packageType) => $query->where('package_type', $packageType))
            ->latest()
            ->get();

        return $this->successResponse('Daftar paket kreator berhasil diambil', $services->toArray());
    }

    public function approve(Request $request, string $id)
    {
        $service = CreatorService::query()
            ->whereIn('category', [self::EO_PACKAGE_CATEGORY, self::CREATOR_PACKAGE_CATEGORY])
            ->find($id);

        if (!$service) {
            return $this->errorResponse('Pengajuan paket tidak ditemukan.', 404);
        }

        if ($service->status !== 'pending') {
            return $this->errorResponse('Hanya pengajuan berstatus pending yang dapat disetujui.', 409);
        }

        $service->update([
            'status' => 'active',
            'reviewed_by' => $request->user()->id,
            'reviewed_at' => now(),
            'review_note' => null,
        ]);

        return $this->successResponse('Paket kreator berhasil disetujui dan kini tampil di publik.', $service->fresh()->toArray());
    }

    public function reject(Request $request, string $id)
    {
        $validated = $request->validate([
            'review_note' => 'required|string|min:3|max:1000',
        ]);

        $service = CreatorService::query()
            ->whereIn('category', [self::EO_PACKAGE_CATEGORY, self::CREATOR_PACKAGE_CATEGORY])
            ->find($id);

        if (!$service) {
            return $this->errorResponse('Pengajuan paket tidak ditemukan.', 404);
        }

        if ($service->status !== 'pending') {
            return $this->errorResponse('Hanya pengajuan berstatus pending yang dapat ditolak.', 409);
        }

        $service->update([
            'status' => 'rejected',
            'reviewed_by' => $request->user()->id,
            'reviewed_at' => now(),
            'review_note' => $validated['review_note'],
        ]);

        return $this->successResponse('Pengajuan paket kreator berhasil ditolak.', $service->fresh()->toArray());
    }
}
