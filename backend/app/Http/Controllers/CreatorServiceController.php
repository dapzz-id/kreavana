<?php

namespace App\Http\Controllers;

use App\Models\CreatorService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class CreatorServiceController extends Controller
{
    use \App\Traits\ApiResponse;

    public function index(Request $request)
    {
        $query = CreatorService::query()->where('status', 'active');
        
        if ($request->has('creator_id')) {
            $query->where('creator_id', $request->creator_id);
        }

        $services = $query->latest()->get();

        return $this->successResponse('Daftar layanan berhasil diambil', $services->toArray());
    }

    public function show($id)
    {
        $service = CreatorService::find($id);

        if (!$service) {
            return $this->errorResponse('Layanan tidak ditemukan.', 404);
        }

        return $this->successResponse('Detail layanan berhasil diambil', $service->toArray());
    }

    public function store(Request $request)
    {
        $user = Auth::guard('api')->user();

        if ($user->role !== \App\Enums\RoleType::Creator) {
            return $this->errorResponse('Hanya kreator yang dapat membuat layanan.', 403);
        }

        $validated = $request->validate([
            'title' => 'required|string|max:200',
            'description' => 'nullable|string',
            'category' => 'nullable|string|max:100',
            'price' => 'required|numeric|min:0',
            'duration_info' => 'nullable|string|max:100',
        ]);

        $validated['creator_id'] = $user->id;
        $validated['status'] = 'active';

        $service = CreatorService::create($validated);

        return $this->successResponse('Layanan berhasil dibuat', $service->toArray(), 201);
    }

    public function update(Request $request, $id)
    {
        $user = Auth::guard('api')->user();
        $service = CreatorService::find($id);

        if (!$service) {
            return $this->errorResponse('Layanan tidak ditemukan.', 404);
        }

        // IDOR protection
        if ($service->creator_id !== $user->id) {
            return $this->errorResponse('Anda tidak memiliki akses untuk mengubah layanan ini.', 403);
        }

        $validated = $request->validate([
            'title' => 'sometimes|required|string|max:200',
            'description' => 'nullable|string',
            'category' => 'nullable|string|max:100',
            'price' => 'sometimes|required|numeric|min:0',
            'duration_info' => 'nullable|string|max:100',
            'status' => 'sometimes|required|in:active,inactive',
        ]);

        $service->update($validated);

        return $this->successResponse('Layanan berhasil diperbarui', $service->toArray());
    }

    public function destroy($id)
    {
        $user = Auth::guard('api')->user();
        $service = CreatorService::find($id);

        if (!$service) {
            return $this->errorResponse('Layanan tidak ditemukan.', 404);
        }

        // IDOR protection
        if ($service->creator_id !== $user->id) {
            return $this->errorResponse('Anda tidak memiliki akses untuk menghapus layanan ini.', 403);
        }

        // Soft delete / change status instead of actual delete if there are job contracts
        if ($service->jobContracts()->exists()) {
            $service->update(['status' => 'inactive']);
            return $this->successResponse('Layanan dinonaktifkan karena sudah memiliki kontrak.', $service->toArray());
        }

        $service->delete();

        return $this->successResponse('Layanan berhasil dihapus', []);
    }
}
