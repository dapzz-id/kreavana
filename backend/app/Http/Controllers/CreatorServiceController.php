<?php
namespace App\Http\Controllers;

use App\Models\CreatorService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;

class CreatorServiceController extends Controller
{
    use \App\Traits\ApiResponse;
    private const EO_PACKAGE_CATEGORY = 'eo_event_package';
    private const CREATOR_PACKAGE_CATEGORY = 'creator_package';

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
        $service = CreatorService::query()
            ->where('status', 'active')
            ->find($id);

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

        $isCreatorPackage = in_array($request->input('category'), [
            self::EO_PACKAGE_CATEGORY,
            self::CREATOR_PACKAGE_CATEGORY,
        ], true);
        if ($isCreatorPackage && !$request->filled('package_type')) {
            return $this->errorResponse('Jenis paket wajib dipilih.', 422);
        }
        if (
            $request->input('category') === self::EO_PACKAGE_CATEGORY &&
            $user->getRawOriginal('sub_role') !== 'event_organizer'
        ) {
            return $this->errorResponse('Kategori paket EO hanya dapat diajukan oleh Event Organizer.', 403);
        }

        $validated = $request->validate([
            'title' => 'required|string|max:200',
            'description' => 'nullable|string',
            'category' => 'nullable|string|max:100',
            'price' => 'required|numeric|min:0',
            'duration_info' => 'nullable|string|max:100',
            'package_type' => 'nullable|string|max:100',
            'thumbnail' => ($isCreatorPackage ? 'required' : 'nullable') . '|image|mimes:jpeg,jpg,png,webp|max:5120',
        ]);

        if ($request->hasFile('thumbnail')) {
            $storageFile = app(\App\Services\StorageService::class)->store(
                $user,
                $request->file('thumbnail'),
                'creator_service_thumbnails',
                'public',
            );
                $validated['thumbnail_url'] = url('/api/creator-service-thumbnails/' . $storageFile->stored_name);
            unset($validated['thumbnail']);
        }

        $validated['creator_id'] = $user->id;
        $validated['status'] = $isCreatorPackage ? 'pending' : 'active';

        $service = CreatorService::create($validated);

        $message = $isCreatorPackage
            ? 'Paket berhasil diajukan dan menunggu review admin.'
            : 'Layanan berhasil dibuat';

        return $this->successResponse($message, $service->toArray(), 201);
    }

    public function mine(Request $request)
    {
        $packageType = $request->query('package_type');
        $services = CreatorService::query()
            ->where('creator_id', $request->user()->id)
            ->when(
                $request->query('category'),
                function ($query, $category) use ($packageType) {
                    if ($category === self::CREATOR_PACKAGE_CATEGORY) {
                        $query->whereIn('category', [
                            self::CREATOR_PACKAGE_CATEGORY,
                            self::EO_PACKAGE_CATEGORY,
                        ]);
                    } else {
                        $query->where('category', $category);
                    }

                    if ($packageType) {
                        $query->where('package_type', $packageType);
                    }
                },
            )
            ->latest()
            ->get();

        return $this->successResponse('Daftar layanan Anda berhasil diambil', $services->toArray());
    }

    public function showThumbnail(string $filename)
    {
        $path = 'creator_service_thumbnails/' . basename($filename);
        $disk = Storage::disk('public');
        if (!$disk->exists($path)) {
            return $this->errorResponse('Thumbnail tidak ditemukan.', 404);
        }

        return response($disk->get($path), 200, [
            'Content-Type' => $disk->mimeType($path) ?? 'application/octet-stream',
            'Cache-Control' => 'public, max-age=86400',
        ]);
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

        $isCreatorPackage = in_array($service->category, [
            self::EO_PACKAGE_CATEGORY,
            self::CREATOR_PACKAGE_CATEGORY,
        ], true) || in_array($request->input('category'), [
            self::EO_PACKAGE_CATEGORY,
            self::CREATOR_PACKAGE_CATEGORY,
        ], true);
        if (
            ($service->category === self::EO_PACKAGE_CATEGORY ||
                $request->input('category') === self::EO_PACKAGE_CATEGORY) &&
            $user->getRawOriginal('sub_role') !== 'event_organizer'
        ) {
            return $this->errorResponse('Hanya Event Organizer yang dapat mengelola paket event.', 403);
        }

        $validated = $request->validate([
            'title' => 'sometimes|required|string|max:200',
            'description' => 'nullable|string',
            'category' => 'nullable|string|max:100',
            'package_type' => 'nullable|string|max:100',
            'price' => 'sometimes|required|numeric|min:0',
            'duration_info' => 'nullable|string|max:100',
            'thumbnail' => 'nullable|image|mimes:jpeg,jpg,png,webp|max:5120',
            ...($isCreatorPackage ? [] : ['status' => 'sometimes|required|in:active,inactive']),
        ]);

        if ($request->hasFile('thumbnail')) {
            $storageFile = app(\App\Services\StorageService::class)->store(
                $user,
                $request->file('thumbnail'),
                'creator_service_thumbnails',
                'public',
            );
            $validated['thumbnail_url'] = url('/api/creator-service-thumbnails/' . $storageFile->stored_name);
            unset($validated['thumbnail']);
        }

        if ($isCreatorPackage) {
            $validated['status'] = 'pending';
            $validated['reviewed_by'] = null;
            $validated['reviewed_at'] = null;
            $validated['review_note'] = null;
        }

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
