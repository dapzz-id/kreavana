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
        'talents',
        'programs',
        'events',
        'competitions',
        'internships',
        'research',
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

    public const ALL_INSTITUTION_PERMISSIONS = [
        'program_magang',
        'kegiatan_event',
        'mitra_industri',
        'karya_siswa',
        'dokumen_institusi',
        'pengumuman_institusi',
    ];

    private const TYPE_TO_PERMISSION = [
        'tenders' => 'program_magang',
        'programs' => 'program_magang',
        'internships' => 'program_magang',
        'events' => 'kegiatan_event',
        'partners' => 'mitra_industri',
        'showcases' => 'karya_siswa',
        'reports' => 'laporan_kegiatan',
        'monitoring' => 'monitoring_evaluasi',
        'documents' => 'dokumen_institusi',
        'announcements' => 'pengumuman_institusi',
    ];

    /**
     * Resolve the institution multi-tenant context for the authenticated user.
     * Prevents data leakage: a staff user operates exclusively within their parent institution.
     */
    private function resolveInstitutionContext(Request $request): array
    {
        $user = $request->user();
        if (!$user) {
            return [
                'owner_id' => null,
                'is_staff' => false,
                'role' => 'admin',
                'permissions' => self::ALL_INSTITUTION_PERMISSIONS,
            ];
        }

        $ownerId = $user->id;
        $isStaff = false;
        $role = 'admin';
        $permissions = self::ALL_INSTITUTION_PERMISSIONS;

        $memberRecord = InstitutionResource::where('resource_type', 'members')
            ->where(function ($q) use ($user) {
                $q->where('metadata->email', $user->email)
                  ->orWhere('metadata->user_id', $user->id)
                  ->orWhere('metadata->username', $user->username);
            })->first();

        if ($memberRecord && $memberRecord->user_id !== $user->id) {
            $meta = is_array($memberRecord->metadata) ? $memberRecord->metadata : [];
            $rawRole = strtolower(trim((string) ($meta['role'] ?? 'karyawan / staf')));
            $ownerId = $memberRecord->user_id;

            if ($rawRole === 'admin') {
                $role = 'admin';
                $isStaff = false;
                $permissions = self::ALL_INSTITUTION_PERMISSIONS;
            } else {
                $isStaff = true;
                $role = 'staff';
                $rawPerms = $meta['permissions'] ?? [];
                $permissions = is_array($rawPerms) ? array_values($rawPerms) : [];
            }
        }

        return [
            'owner_id' => $ownerId,
            'is_staff' => $isStaff,
            'role' => $role,
            'permissions' => $permissions,
        ];
    }

    public function searchCorporates(Request $request)
    {
        $q = trim((string) $request->query('q', ''));
        if (empty($q)) {
            return $this->successResponse('Daftar akun corporate mitra', []);
        }

        $currentUserId = $request->user()->id;
        $corporateKeywords = ['corporate', 'company', 'business', 'perusahaan', 'bisnis', 'enterprise', 'b2b'];

        $query = \App\Models\User::query()
            ->where('id', '!=', $currentUserId)
            ->where(function ($sub) use ($corporateKeywords) {
                $sub->whereIn('sub_role', $corporateKeywords)
                    ->orWhereIn('role', $corporateKeywords)
                    ->orWhere('username', 'corporate_demo')
                    ->orWhere('email', 'like', 'corporate%@%');
            })
            ->where(function ($filter) use ($q) {
                $filter->where('name', 'like', '%' . $q . '%')
                    ->orWhere('username', 'like', '%' . $q . '%')
                    ->orWhere('email', 'like', '%' . $q . '%');
            });

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
        ->limit(6)
        ->get();

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
                    'url' => $mouUrl ?: null,
                    'file_url' => $mouUrl ?: null,
                    'file_name' => $meta['mou_filename'] ?? null,
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

        $ctx = $this->resolveInstitutionContext($request);
        $ownerId = $ctx['owner_id'] ?: $request->user()->id;
        $isStaff = $ctx['is_staff'];
        $type = $validated['type'] ?? null;

        // Strict RBAC: Staff cannot access members (Tim & Hak Akses) or profile (Profil Institusi)
        if ($isStaff && in_array($type, ['members', 'team', 'profile'], true)) {
            return $this->errorResponse('Akses ditolak. Fitur Tim & Hak Akses dan Profil Institusi hanya dapat dikelola oleh Admin Institusi.', 403);
        }

        // Strict RBAC: Staff can only access features present in their granted permissions
        if ($isStaff && $type && isset(self::TYPE_TO_PERMISSION[$type])) {
            $requiredPerm = self::TYPE_TO_PERMISSION[$type];
            if (!in_array($requiredPerm, $ctx['permissions'], true)) {
                return $this->errorResponse('Akses ditolak. Anda tidak memiliki izin untuk mengakses fitur ini.', 403);
            }
        }

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

            if ($isCorporate && InstitutionResource::where('user_id', $ownerId)->count() === 0) {
                \Database\Seeders\CorporateDummySeeder::seedForUser($user);
            } elseif ($isGovernment && InstitutionResource::where('user_id', $ownerId)->count() === 0) {
                \Database\Seeders\GovernmentDummySeeder::seedForUser($user);
            } elseif ($isSchool && InstitutionResource::where('user_id', $ownerId)->count() === 0) {
                \Database\Seeders\SchoolDummySeeder::seedForUser($user);
            }

            if ($isSchool && $type === 'tenders') {
                return $this->errorResponse('Fitur Pengadaan & Vendor hanya tersedia untuk akun Corporate / Perusahaan.', 403);
            }
        }

        $isCorporate = isset($subRoleLower) && in_array($subRoleLower, [
            'corporate', 'company', 'business', 'perusahaan', 'bisnis'
        ], true);

        $query = InstitutionResource::query();

        if ($type === 'partners' && $isCorporate) {
            $query->where(function ($q) use ($ownerId, $request) {
                $q->where('user_id', $ownerId)
                  ->orWhere('metadata->corporate_user_id', $request->user()->id)
                  ->orWhere('metadata->corporate_username', $request->user()->username);
            });
        } else {
            // CRITICAL: Scope strictly to the parent institution owner to prevent data leak!
            $query->where('user_id', $ownerId);
        }

        if ($type) {
            $query->where('resource_type', $type);
        }

        $resources = $query->latest()->get();

        // If staff requests without type filter, filter out unpermitted resources
        if ($isStaff && empty($type)) {
            $resources = $resources->filter(function ($item) use ($ctx) {
                if (in_array($item->resource_type, ['members', 'team', 'profile'], true)) {
                    return false;
                }
                $requiredPerm = self::TYPE_TO_PERMISSION[$item->resource_type] ?? null;
                return $requiredPerm === null || in_array($requiredPerm, $ctx['permissions'], true);
            })->values();
        }

        return $this->successResponse('Data instansi berhasil diambil.', $resources);
    }

    public function store(Request $request)
    {
        $this->ensureInstitutionAccount($request);
        $ctx = $this->resolveInstitutionContext($request);
        $ownerId = $ctx['owner_id'] ?: $request->user()->id;
        $isStaff = $ctx['is_staff'];

        $validated = $this->validateResource($request);
        $resType = $validated['resource_type'];

        // Strict RBAC checks for Staff
        if ($isStaff) {
            if (in_array($resType, ['members', 'team', 'profile'], true)) {
                return $this->errorResponse('Akses ditolak. Fitur ini hanya dapat dikelola oleh Admin Institusi.', 403);
            }
            $requiredPerm = self::TYPE_TO_PERMISSION[$resType] ?? null;
            if ($requiredPerm && !in_array($requiredPerm, $ctx['permissions'], true)) {
                return $this->errorResponse('Akses ditolak. Anda tidak memiliki izin untuk menambah data fitur ini.', 403);
            }
        }

        $user = $request->user();
        $subRole = $user?->sub_role instanceof \BackedEnum ? $user->sub_role->value : $user?->sub_role;
        $subRoleLower = strtolower((string) ($subRole ?? ''));
        $isSchool = in_array($subRoleLower, [
            'institution', 'school', 'sekolah', 'kampus', 'education', 'institusi', 'smk', 'universitas'
        ], true);

        if ($isSchool && $resType === 'tenders') {
            return $this->errorResponse('Fitur Pengadaan & Vendor hanya tersedia untuk akun Corporate / Perusahaan.', 403);
        }

        if ($isSchool && $resType === 'documents') {
            return $this->errorResponse('Dokumen MoU diterbitkan otomatis melalui proses persetujuan kemitraan industri.', 403);
        }

        if ($isSchool && $resType === 'partners') {
            if (empty($validated['status'])) {
                $validated['status'] = 'pending';
            }
        }

        $meta = $validated['metadata'] ?? [];

        // If creating a team member (staff or co-admin)
        if ($resType === 'members') {
            $memberEmail = strtolower(trim((string) ($meta['email'] ?? '')));
            $memberName = trim((string) ($validated['title'] ?? ''));
            $memberPassword = $meta['password'] ?? 'Kreavana123!';
            $memberRole = $meta['role'] ?? 'Karyawan / Staf';
            $memberDept = $meta['department'] ?? $validated['description'] ?? 'Staf Lembaga';
            $memberPerms = $meta['permissions'] ?? [];

            if (empty($memberEmail) || empty($memberName)) {
                return $this->errorResponse('Nama lengkap dan email anggota tim wajib diisi.', 422);
            }

            // Sync or create user account so they can log in
            $staffUser = \App\Models\User::where('email', $memberEmail)->first();
            if (!$staffUser) {
                $cleanBase = preg_replace('/[^a-zA-Z0-9]/', '', strtolower(explode('@', $memberEmail)[0]));
                $username = substr($cleanBase, 0, 20) . '_' . rand(100, 999);

                if (\App\Services\UsersApiClient::isEnabled()) {
                    try {
                        \App\Services\UsersApiClient::register([
                            'name' => $memberName,
                            'username' => $username,
                            'email' => $memberEmail,
                            'password' => $memberPassword,
                        ]);
                    } catch (\Throwable $e) {
                        \Illuminate\Support\Facades\Log::warning('UsersApiClient register staff error: ' . $e->getMessage());
                    }
                }

                $staffUser = \App\Models\User::create([
                    'name' => $memberName,
                    'username' => $username,
                    'email' => $memberEmail,
                    'role' => \App\Enums\RoleType::User,
                    'sub_role' => 'institution',
                    'is_verified' => true,
                    'verification_type' => 'institution',
                    'email_verified_at' => now(),
                ]);
            }

            $meta['user_id'] = $staffUser->id;
            $meta['username'] = $staffUser->username;
            $meta['email'] = $memberEmail;
            $meta['role'] = $memberRole;
            $meta['permissions'] = is_array($memberPerms) ? array_values($memberPerms) : [];
            $meta['department'] = $memberDept;
            $meta['joined_at'] = now()->format('d M Y');
            $meta['created_by'] = $user->id;
            $meta['is_online'] = false;
            unset($meta['password']);

            $validated['metadata'] = $meta;
        }

        $resource = InstitutionResource::create([
            ...$validated,
            'user_id' => $ownerId,
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
        $ctx = $this->resolveInstitutionContext($request);
        $ownerId = $ctx['owner_id'] ?: $request->user()->id;
        $isStaff = $ctx['is_staff'];

        $resource = InstitutionResource::query()
            ->where(function ($q) use ($ownerId, $request) {
                $q->where('user_id', $ownerId)
                  ->orWhere('metadata->corporate_user_id', $request->user()->id);
            })
            ->find($id);

        if (!$resource) {
            return $this->errorResponse('Data tidak ditemukan.', 404);
        }

        if ($isStaff) {
            if (in_array($resource->resource_type, ['members', 'team', 'profile'], true)) {
                return $this->errorResponse('Akses ditolak. Fitur ini hanya dapat dikelola oleh Admin Institusi.', 403);
            }
            $requiredPerm = self::TYPE_TO_PERMISSION[$resource->resource_type] ?? null;
            if ($requiredPerm && !in_array($requiredPerm, $ctx['permissions'], true)) {
                return $this->errorResponse('Akses ditolak. Anda tidak memiliki izin untuk mengubah data fitur ini.', 403);
            }
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

        if (isset($validated['metadata']) && is_array($validated['metadata'])) {
            $oldMeta = is_array($resource->metadata) ? $resource->metadata : [];
            $newMeta = array_merge($oldMeta, $validated['metadata']);

            if ($resource->resource_type === 'members') {
                $staffPassword = $validated['metadata']['password'] ?? $request->input('metadata.password');
                if (isset($newMeta['password'])) {
                    unset($newMeta['password']);
                }
                if (isset($newMeta['permissions']) && is_array($newMeta['permissions'])) {
                    $newMeta['permissions'] = array_values($newMeta['permissions']);
                }
                $validated['metadata'] = $newMeta;

                // Sync with User table if user exists
                $memberUserId = $newMeta['user_id'] ?? null;
                $memberEmail = $newMeta['email'] ?? null;
                $targetUser = $memberUserId
                    ? \App\Models\User::find($memberUserId)
                    : ($memberEmail ? \App\Models\User::where('email', $memberEmail)->first() : null);

                if ($targetUser) {
                    $userUpdates = [];
                    if (!empty($validated['title']) && $targetUser->name !== $validated['title']) {
                        $userUpdates['name'] = $validated['title'];
                    }
                    if (!empty($staffPassword) && strlen((string) $staffPassword) >= 6) {
                        $userUpdates['password'] = \Illuminate\Support\Facades\Hash::make($staffPassword);
                    }
                    if (!empty($userUpdates)) {
                        $targetUser->update($userUpdates);
                    }
                }
            } else {
                $validated['metadata'] = $newMeta;
            }
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
                    'url' => $mouUrl ?: null,
                    'file_url' => $mouUrl ?: null,
                    'file_name' => $meta['mou_filename'] ?? null,
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

        return $document;
    }

    public function destroy(Request $request, string $id)
    {
        $this->ensureInstitutionAccount($request);
        $ctx = $this->resolveInstitutionContext($request);
        $ownerId = $ctx['owner_id'] ?: $request->user()->id;
        $isStaff = $ctx['is_staff'];

        $resource = InstitutionResource::query()
            ->where('user_id', $ownerId)
            ->find($id);

        if (!$resource) {
            return $this->errorResponse('Data tidak ditemukan.', 404);
        }

        if ($isStaff) {
            if (in_array($resource->resource_type, ['members', 'team', 'profile'], true)) {
                return $this->errorResponse('Akses ditolak. Fitur ini hanya dapat dikelola oleh Admin Institusi.', 403);
            }
            $requiredPerm = self::TYPE_TO_PERMISSION[$resource->resource_type] ?? null;
            if ($requiredPerm && !in_array($requiredPerm, $ctx['permissions'], true)) {
                return $this->errorResponse('Akses ditolak. Anda tidak memiliki izin untuk menghapus data fitur ini.', 403);
            }
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
        if (!$user) {
            abort(401, 'Unauthenticated.');
        }

        $ctx = $this->resolveInstitutionContext($request);
        if ($ctx['is_staff'] || ($ctx['owner_id'] && $ctx['owner_id'] !== $user->id)) {
            return;
        }

        $subRole = $user->sub_role instanceof \BackedEnum ? $user->sub_role->value : $user->sub_role;
        abort_unless(
            in_array($subRole, [
                'institution', 'government', 'pemerintah', 'instansi', 'school', 'sekolah',
                'corporate', 'company', 'business', 'perusahaan', 'bisnis',
            ], true),
            403,
            'Fitur ini hanya tersedia untuk akun instansi atau perusahaan.',
        );
    }
}
