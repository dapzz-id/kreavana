<?php

namespace App\Http\Controllers;

use App\Models\InstitutionResource;
use Illuminate\Http\Request;

class InstitutionResourceController extends Controller
{
    use \App\Traits\ApiResponse;

    private const TYPES = [
        'tenders',
        'partners',
        'reports',
        'budgets',
        'monitoring',
        'documents',
        'announcements',
    ];

    private const STATUSES = [
        'draft',
        'published',
        'open',
        'in_progress',
        'completed',
        'closed',
    ];

    public function index(Request $request)
    {
        $validated = $request->validate([
            'type' => 'nullable|string|in:' . implode(',', self::TYPES),
        ]);

        $resources = InstitutionResource::query()
            ->where('user_id', $request->user()->id)
            ->when($validated['type'] ?? null, fn ($query, $type) => $query->where('resource_type', $type))
            ->latest()
            ->get();

        return $this->successResponse('Data instansi berhasil diambil.', $resources);
    }

    public function store(Request $request)
    {
        $this->ensureInstitutionAccount($request);
        $validated = $this->validateResource($request);

        $resource = InstitutionResource::create([
            ...$validated,
            'user_id' => $request->user()->id,
            'published_at' => ($validated['status'] ?? 'draft') === 'published' ? now() : null,
        ]);

        return $this->successResponse('Data berhasil disimpan.', $resource, 201);
    }

    public function update(Request $request, string $id)
    {
        $this->ensureInstitutionAccount($request);
        $resource = InstitutionResource::query()
            ->where('user_id', $request->user()->id)
            ->find($id);

        if (!$resource) {
            return $this->errorResponse('Data tidak ditemukan.', 404);
        }

        $validated = $this->validateResource($request, partial: true);
        $status = $validated['status'] ?? $resource->status;
        if ($status === 'published' && !$resource->published_at) {
            $validated['published_at'] = now();
        } elseif ($status !== 'published') {
            $validated['published_at'] = null;
        }

        $resource->update($validated);

        return $this->successResponse('Data berhasil diperbarui.', $resource->fresh());
    }

    public function destroy(Request $request, string $id)
    {
        $this->ensureInstitutionAccount($request);
        $resource = InstitutionResource::query()
            ->where('user_id', $request->user()->id)
            ->find($id);

        if (!$resource) {
            return $this->errorResponse('Data tidak ditemukan.', 404);
        }

        $resource->delete();
        return $this->successResponse('Data berhasil dihapus.');
    }

    public function publicAnnouncements()
    {
        $announcements = InstitutionResource::query()
            ->with('owner:id,name,username')
            ->where('resource_type', 'announcements')
            ->where('status', 'published')
            ->whereNotNull('published_at')
            ->latest('published_at')
            ->paginate(20);

        return $this->successResponse('Pengumuman publik berhasil diambil.', $announcements);
    }

    private function validateResource(Request $request, bool $partial = false): array
    {
        $rules = [
            'resource_type' => ($partial ? 'sometimes|' : 'required|') . 'string|in:' . implode(',', self::TYPES),
            'title' => ($partial ? 'sometimes|' : 'required|') . 'string|max:200',
            'description' => 'nullable|string|max:10000',
            'status' => 'sometimes|string|in:' . implode(',', self::STATUSES),
            'metadata' => 'nullable|array',
        ];

        return $request->validate($rules);
    }

    private function ensureInstitutionAccount(Request $request): void
    {
        $user = $request->user();
        $subRole = $user?->getRawOriginal('sub_role');
        abort_unless(
            $user && in_array($subRole, ['institution', 'government', 'pemerintah', 'instansi'], true),
            403,
            'Fitur ini hanya tersedia untuk akun instansi.',
        );
    }
}
