<?php

namespace App\Http\Controllers;

use App\Models\InstitutionResource;
use Illuminate\Http\Request;

class InstitutionResourceController extends Controller
{
    use \App\Traits\ApiResponse;

    private const TYPES = [
        'profile',
        'tenders',
        'partners',
        'reports',
        'budgets',
        'monitoring',
        'documents',
        'announcements',
        'facilities',
        'showcases',
        'members',
        'team',
        'study_programs',
        'programs',
        'events',
        'competitions',
        'internships',
        'research',
        'talents',
        'students',
    ];

    private const STATUSES = [
        'draft',
        'published',
        'open',
        'in_progress',
        'completed',
        'closed',
        'active',
        'inactive',
        'pending',
        'approved',
        'rejected',
    ];

    public function searchCorporates(Request $request)
    {
        $q = trim((string) $request->query('q', ''));
        $currentUserId = $request->user()->id;

        $corporateKeywords = ['corporate', 'company', 'business', 'perusahaan', 'bisnis', 'enterprise', 'b2b'];

        $query = \App\Models\User::query()
            ->where('id', '!=', $currentUserId)
            ->where(function ($sub) use ($corporateKeywords) {
                $sub->whereIn('sub_role', $corporateKeywords)
                    ->orWhereIn('role', $corporateKeywords)
                    ->orWhere('username', 'corporate_demo')
                    ->orWhere('email', 'like', 'corporate%@%');
            });

        if (!empty($q)) {
            $query->where(function ($filter) use ($q) {
                $filter->where('name', 'like', '%' . $q . '%')
                    ->orWhere('username', 'like', '%' . $q . '%')
                    ->orWhere('email', 'like', '%' . $q . '%');
            });
        }

        $corporates = $query->select([
            'id',
            'name',
            'username',
            'email',
            'avatar_url',
            'phone',
            'role',
            'sub_role as selected_sub_role',
            'is_verified',
            'verification_type',
        ])
        ->limit(15)
        ->get();

        if ($corporates->isEmpty() && empty($q)) {
            $demo = \App\Models\User::where('username', 'corporate_demo')->first();
            if ($demo) {
                $corporates = collect([$demo]);
            }
        }

        return $this->successResponse('Daftar akun corporate mitra', $corporates);
    }

    public function uploadMou(Request $request)
    {
        $request->validate([
            'mou_file' => 'required|file|max:15360',
        ]);

        $file = $request->file('mou_file');
        /** @var \App\Services\StorageService $storageService */
        $storageService = app(\App\Services\StorageService::class);
        $storageFile = $storageService->store($request->user(), $file, 'mou_documents', 'public');

        $bytes = $file->getSize() ?: 0;
        $formattedSize = $bytes >= 1048576 
            ? round($bytes / 1048576, 1) . ' MB' 
            : round($bytes / 1024, 0) . ' KB';

        return $this->successResponse('Dokumen MoU berhasil diunggah.', [
            'url' => $storageFile->url,
            'filename' => $file->getClientOriginalName(),
            'filesize' => $formattedSize,
            'extension' => $file->getClientOriginalExtension() ?: 'pdf',
        ]);
    }

    public function approve(Request $request, string $id)
    {
        $user = $request->user();
        $resource = InstitutionResource::find($id);
        if (!$resource) {
            return $this->errorResponse('Data mitra tidak ditemukan.', 404);
        }

        $meta = is_array($resource->metadata) ? $resource->metadata : [];
        $meta['approval_status'] = 'approved';
        $meta['approved_at'] = now()->toIso8601String();
        $meta['approved_by'] = $user->name;

        $resource->update([
            'status' => 'active',
            'metadata' => $meta,
        ]);

        // CRITICAL: Automatically create/sync into "Dokumen & MoU" for the school
        $mouUrl = $meta['mou_url'] ?? null;
        $partnerName = $resource->title;
        $docTitle = "Perjanjian Kerjasama (MoU) - {$partnerName}";

        $document = InstitutionResource::updateOrCreate(
            [
                'user_id' => $resource->user_id,
                'resource_type' => 'documents',
                'title' => $docTitle,
            ],
            [
                'description' => "Dokumen resmi legalitas Perjanjian Kerjasama (MoU) kemitraan industri yang telah disetujui bersama {$partnerName}.",
                'status' => 'published',
                'published_at' => now(),
                'metadata' => [
                    'document_number' => 'MOU-' . strtoupper(substr(md5($resource->id), 0, 8)) . '/' . date('Y'),
                    'category' => 'MoU Kemitraan',
                    'valid_until' => now()->addYears(3)->format('Y-m-d'),
                    'url' => $mouUrl ?: 'https://docs.kreavana.id/mou/' . $resource->id,
                    'file_format' => strtoupper($meta['mou_extension'] ?? 'PDF'),
                    'file_size' => $meta['mou_filesize'] ?? 'Dokumen Digital',
                    'partner_name' => $partnerName,
                    'partner_resource_id' => $resource->id,
                    'corporate_user_id' => $meta['corporate_user_id'] ?? null,
                    'verified' => true,
                    'approved_at' => now()->toIso8601String(),
                ],
            ]
        );

        $meta['linked_document_id'] = $document->id;
        $resource->update(['metadata' => $meta]);

        return $this->successResponse('Kemitraan berhasil disetujui dan dokumen MoU otomatis diterbitkan di menu Dokumen & MoU.', [
            'partner' => $resource->fresh(),
            'document' => $document,
        ]);
    }

    public function reject(Request $request, string $id)
    {
        $resource = InstitutionResource::find($id);
        if (!$resource) {
            return $this->errorResponse('Data mitra tidak ditemukan.', 404);
        }

        $meta = is_array($resource->metadata) ? $resource->metadata : [];
        $meta['approval_status'] = 'rejected';
        $meta['rejected_at'] = now()->toIso8601String();
        $meta['rejected_by'] = $request->user()->name;

        $resource->update([
            'status' => 'rejected',
            'metadata' => $meta,
        ]);

        return $this->successResponse('Pengajuan kemitraan telah ditolak.', $resource->fresh());
    }

    public function index(Request $request)
    {
        $validated = $request->validate([
            'type' => 'nullable|string|in:' . implode(',', self::TYPES),
        ]);

        $user = $request->user();
        if ($user) {
            $subRole = $user->sub_role instanceof \BackedEnum ? $user->sub_role->value : $user->sub_role;
            $subRoleLower = strtolower((string) ($subRole ?? ''));

            $isCorporate = in_array($subRoleLower, [
                'corporate', 'company', 'business', 'perusahaan', 'bisnis'
            ], true);

            $isGovernment = in_array($subRoleLower, [
                'government', 'pemerintah', 'instansi', 'dinas', 'bumn', 'kementerian'
            ], true);

            $isSchool = in_array($subRoleLower, [
                'institution', 'school', 'sekolah', 'kampus', 'education', 'institusi', 'smk', 'universitas'
            ], true);

            if ($isCorporate && InstitutionResource::where('user_id', $user->id)->count() === 0) {
                \Database\Seeders\CorporateDummySeeder::seedForUser($user);
            } elseif ($isGovernment && InstitutionResource::where('user_id', $user->id)->count() === 0) {
                \Database\Seeders\GovernmentDummySeeder::seedForUser($user);
            } elseif ($isSchool && InstitutionResource::where('user_id', $user->id)->count() === 0) {
                \Database\Seeders\SchoolDummySeeder::seedForUser($user);
            }

            if ($isSchool && ($validated['type'] ?? null) === 'tenders') {
                return $this->errorResponse('Fitur Pengadaan & Vendor hanya tersedia untuk akun Corporate / Perusahaan.', 403);
            }
        }

        $type = $validated['type'] ?? null;
        $isCorporate = isset($subRoleLower) && in_array($subRoleLower, [
            'corporate', 'company', 'business', 'perusahaan', 'bisnis'
        ], true);

        $query = InstitutionResource::query();

        if ($type === 'partners' && $isCorporate) {
            $query->where(function ($q) use ($request) {
                $q->where('user_id', $request->user()->id)
                  ->orWhere('metadata->corporate_user_id', $request->user()->id)
                  ->orWhere('metadata->corporate_username', $request->user()->username);
            });
        } else {
            $query->where('user_id', $request->user()->id);
        }

        if ($type) {
            $query->where('resource_type', $type);
        }

        $resources = $query->latest()->get();

        return $this->successResponse('Data instansi berhasil diambil.', $resources);
    }

    public function store(Request $request)
    {
        $this->ensureInstitutionAccount($request);
        $user = $request->user();
        $subRole = $user?->sub_role instanceof \BackedEnum ? $user->sub_role->value : $user?->sub_role;
        $subRoleLower = strtolower((string) ($subRole ?? ''));
        $isSchool = in_array($subRoleLower, [
            'institution', 'school', 'sekolah', 'kampus', 'education', 'institusi', 'smk', 'universitas'
        ], true);

        $validated = $this->validateResource($request);

        if ($isSchool && ($validated['resource_type'] ?? null) === 'tenders') {
            return $this->errorResponse('Fitur Pengadaan & Vendor hanya tersedia untuk akun Corporate / Perusahaan.', 403);
        }

        if ($isSchool && ($validated['resource_type'] ?? null) === 'partners') {
            if (empty($validated['status'])) {
                $validated['status'] = 'pending';
            }
        }

        $resource = InstitutionResource::create([
            ...$validated,
            'user_id' => $request->user()->id,
            'published_at' => ($validated['status'] ?? 'draft') === 'published' ? now() : null,
        ]);

        if ($resource->resource_type === 'partners' && in_array($resource->status, ['active', 'approved'])) {
            $this->syncMouDocument($resource);
        }

        return $this->successResponse('Data berhasil disimpan.', $resource->fresh(), 201);
    }

    public function update(Request $request, string $id)
    {
        $this->ensureInstitutionAccount($request);
        $resource = InstitutionResource::query()
            ->where(function ($q) use ($request) {
                $q->where('user_id', $request->user()->id)
                  ->orWhere('metadata->corporate_user_id', $request->user()->id);
            })
            ->find($id);

        if (!$resource) {
            return $this->errorResponse('Data tidak ditemukan.', 404);
        }

        $user = $request->user();
        $subRole = $user?->sub_role instanceof \BackedEnum ? $user->sub_role->value : $user?->sub_role;
        $subRoleLower = strtolower((string) ($subRole ?? ''));
        $isSchool = in_array($subRoleLower, [
            'institution', 'school', 'sekolah', 'kampus', 'education', 'institusi', 'smk', 'universitas'
        ], true);

        $validated = $this->validateResource($request, partial: true);

        if ($isSchool && ($resource->resource_type === 'tenders' || ($validated['resource_type'] ?? null) === 'tenders')) {
            return $this->errorResponse('Fitur Pengadaan & Vendor hanya tersedia untuk akun Corporate / Perusahaan.', 403);
        }
        $status = $validated['status'] ?? $resource->status;
        if ($status === 'published' && !$resource->published_at) {
            $validated['published_at'] = now();
        } elseif ($status !== 'published') {
            $validated['published_at'] = null;
        }

        $resource->update($validated);

        if ($resource->resource_type === 'partners' && in_array($resource->status, ['active', 'approved'])) {
            $this->syncMouDocument($resource);
        }

        return $this->successResponse('Data berhasil diperbarui.', $resource->fresh());
    }

    private function syncMouDocument(InstitutionResource $resource): ?InstitutionResource
    {
        $meta = is_array($resource->metadata) ? $resource->metadata : [];
        $mouUrl = $meta['mou_url'] ?? null;
        $partnerName = $resource->title;
        $docTitle = "Perjanjian Kerjasama (MoU) - {$partnerName}";

        $document = InstitutionResource::updateOrCreate(
            [
                'user_id' => $resource->user_id,
                'resource_type' => 'documents',
                'title' => $docTitle,
            ],
            [
                'description' => "Dokumen resmi legalitas Perjanjian Kerjasama (MoU) kemitraan industri yang telah disetujui bersama {$partnerName}.",
                'status' => 'published',
                'published_at' => now(),
                'metadata' => [
                    'document_number' => 'MOU-' . strtoupper(substr(md5($resource->id), 0, 8)) . '/' . date('Y'),
                    'category' => 'MoU Kemitraan',
                    'valid_until' => now()->addYears(3)->format('Y-m-d'),
                    'url' => $mouUrl ?: 'https://docs.kreavana.id/mou/' . $resource->id,
                    'file_format' => strtoupper($meta['mou_extension'] ?? 'PDF'),
                    'file_size' => $meta['mou_filesize'] ?? '2.4 MB',
                    'partner_name' => $partnerName,
                    'partner_resource_id' => $resource->id,
                    'corporate_user_id' => $meta['corporate_user_id'] ?? null,
                    'verified' => true,
                    'approved_at' => now()->toIso8601String(),
                ],
            ]
        );

        $meta['linked_document_id'] = $document->id;
        $resource->update(['metadata' => $meta]);

        return $document;
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
        $subRole = $user?->sub_role instanceof \BackedEnum ? $user->sub_role->value : $user?->sub_role;
        abort_unless(
            $user && in_array($subRole, [
                'institution', 'government', 'pemerintah', 'instansi', 'school', 'sekolah',
                'corporate', 'company', 'business', 'perusahaan', 'bisnis',
            ], true),
            403,
            'Fitur ini hanya tersedia untuk akun instansi atau perusahaan.',
        );
    }
}
