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

    private const CORPORATE_SUBROLES = [
        'corporate', 'company', 'business', 'perusahaan', 'bisnis', 'enterprise', 'b2b',
    ];

    private const INSTITUTION_SUBROLES = [
        'institution', 'school', 'sekolah', 'kampus', 'education', 'institusi', 'smk', 'universitas',
    ];

    private const GOVERNMENT_SUBROLES = [
        'government', 'pemerintah', 'instansi', 'dinas', 'bumn', 'kementerian',
    ];

    private function normalizedUserSubRole(?\App\Models\User $user): string
    {
        if (!$user) {
            return '';
        }
        $subRole = $user->sub_role instanceof \BackedEnum ? $user->sub_role->value : $user->sub_role;
        return strtolower(trim((string) ($subRole ?? '')));
    }

    private function isCorporateUser(?\App\Models\User $user): bool
    {
        return in_array($this->normalizedUserSubRole($user), self::CORPORATE_SUBROLES, true);
    }

    private function isInstitutionUser(?\App\Models\User $user): bool
    {
        return in_array($this->normalizedUserSubRole($user), self::INSTITUTION_SUBROLES, true);
    }

    private function isGovernmentUser(?\App\Models\User $user): bool
    {
        return in_array($this->normalizedUserSubRole($user), self::GOVERNMENT_SUBROLES, true);
    }

    public function searchCorporates(Request $request)
    {
        $rawQ = trim((string) $request->query('q', ''));
        $cleanQ = ltrim($rawQ, '@');

        $currentUser = $request->user();
        $ctx = $this->resolveInstitutionContext($request);
        $ownerId = $ctx['owner_id'] ?: $currentUser->id;
        $actorUser = (string) $ownerId === (string) $currentUser->id
            ? $currentUser
            : (\App\Models\User::find($ownerId) ?? $currentUser);

        $isCorporateCaller = $this->isCorporateUser($actorUser);
        $isInstitutionCaller = $this->isInstitutionUser($actorUser);

        $excludeIds = array_values(array_unique(array_filter([$currentUser->id, $ownerId])));

        $query = \App\Models\User::query()
            ->whereNotIn('id', $excludeIds)
            ->where(function ($sub) use ($isCorporateCaller, $isInstitutionCaller) {
                if ($isCorporateCaller) {
                    $sub->whereIn('sub_role', self::INSTITUTION_SUBROLES)
                        ->orWhereIn('role', self::INSTITUTION_SUBROLES)
                        ->orWhere('username', 'institution_demo')
                        ->orWhereRaw('LOWER(username) LIKE ?', ['institution%'])
                        ->orWhereRaw('LOWER(username) LIKE ?', ['smk%'])
                        ->orWhereRaw('LOWER(email) LIKE ?', ['institution%@%']);
                    return;
                }

                if ($isInstitutionCaller) {
                    $sub->whereIn('sub_role', self::CORPORATE_SUBROLES)
                        ->orWhereIn('role', self::CORPORATE_SUBROLES)
                        ->orWhere('username', 'corporate_demo')
                        ->orWhere('username', 'transforma_alam')
                        ->orWhereRaw('LOWER(email) LIKE ?', ['corporate%@%']);
                    return;
                }

                $combined = array_merge(self::CORPORATE_SUBROLES, self::INSTITUTION_SUBROLES);
                $sub->whereIn('sub_role', $combined)
                    ->orWhereIn('role', $combined);
            });

        if ($cleanQ !== '') {
            $pattern = '%' . mb_strtolower($cleanQ) . '%';
            $query->where(function ($filter) use ($pattern) {
                $filter->whereRaw('LOWER(name) LIKE ?', [$pattern])
                    ->orWhereRaw('LOWER(username) LIKE ?', [$pattern])
                    ->orWhereRaw('LOWER(email) LIKE ?', [$pattern]);
            });
        }

        $partners = $query->select([
            'id',
            'name',
            'username',
            'email',
            'phone',
            'avatar_url',
            'role',
            'sub_role',
            'is_verified',
            'verification_type',
        ])
        ->orderByDesc('is_verified')
        ->orderBy('name')
        ->limit(10)
        ->get();

        return $this->successResponse('Daftar akun mitra', $partners);
    }

    public function uploadMou(Request $request)
    {
        $request->validate([
            'mou_file' => 'required|file|mimes:pdf,doc,docx|max:15360',
        ]);

        $file = $request->file('mou_file');
        $ext = strtolower((string) $file->getClientOriginalExtension());
        if ($ext !== '' && !in_array($ext, ['pdf', 'doc', 'docx'], true)) {
            return $this->errorResponse('Format berkas kerjasama harus PDF, DOC, atau DOCX.', 422);
        }

        /** @var \App\Services\StorageService $storageService */
        $storageService = app(\App\Services\StorageService::class);
        $storageFile = $storageService->store($request->user(), $file, 'mou_documents', 'public');

        $bytes = $file->getSize() ?: 0;
        $formattedSize = $bytes >= 1048576
            ? round($bytes / 1048576, 1) . ' MB'
            : round($bytes / 1024, 0) . ' KB';

        return $this->successResponse('Berkas kerjasama berhasil diunggah.', [
            'url' => $storageFile->url,
            'filename' => $file->getClientOriginalName(),
            'filesize' => $formattedSize,
            'extension' => $ext ?: 'pdf',
        ]);
    }

    private function normalizeMouFiles(array $meta): array
    {
        $files = [];
        if (isset($meta['mou_files']) && is_array($meta['mou_files'])) {
            foreach ($meta['mou_files'] as $item) {
                if (!is_array($item)) {
                    continue;
                }
                $url = trim((string) ($item['url'] ?? ''));
                if ($url === '') {
                    continue;
                }
                $filename = trim((string) ($item['filename'] ?? ''));
                if ($filename === '') {
                    $pathPart = (string) parse_url($url, PHP_URL_PATH);
                    $filename = basename($pathPart) ?: 'Dokumen-Kerjasama.pdf';
                }
                $ext = strtolower(trim((string) ($item['extension'] ?? '')));
                if ($ext === '') {
                    $ext = strtolower((string) pathinfo($filename, PATHINFO_EXTENSION)) ?: 'pdf';
                }
                $files[] = [
                    'url' => $url,
                    'filename' => $filename,
                    'filesize' => trim((string) ($item['filesize'] ?? '')) ?: 'Dokumen Digital',
                    'extension' => $ext,
                ];
            }
        }

        if (empty($files) && !empty($meta['mou_url'])) {
            $url = trim((string) $meta['mou_url']);
            if ($url !== '') {
                $filename = trim((string) ($meta['mou_filename'] ?? '')) ?: 'Dokumen-MoU-Kemitraan.pdf';
                $ext = strtolower(trim((string) ($meta['mou_extension'] ?? '')));
                if ($ext === '') {
                    $ext = strtolower((string) pathinfo($filename, PATHINFO_EXTENSION)) ?: 'pdf';
                }
                $files[] = [
                    'url' => $url,
                    'filename' => $filename,
                    'filesize' => trim((string) ($meta['mou_filesize'] ?? '')) ?: 'Dokumen Digital',
                    'extension' => $ext,
                ];
            }
        }

        return array_values($files);
    }

    private function applyMouMetadata(array $meta, array $mouFiles): array
    {
        $normalized = array_values($mouFiles);
        $meta['mou_files'] = $normalized;
        if (!empty($normalized)) {
            $first = $normalized[0];
            $meta['mou_url'] = $first['url'];
            $meta['mou_filename'] = $first['filename'];
            $meta['mou_filesize'] = $first['filesize'];
            $meta['mou_extension'] = $first['extension'];
        } else {
            unset($meta['mou_url'], $meta['mou_filename'], $meta['mou_filesize'], $meta['mou_extension']);
        }
        return $meta;
    }

    private function isProposalSender(Request $request, InstitutionResource $resource, string|int $ownerId): bool
    {
        $user = $request->user();
        $meta = is_array($resource->metadata) ? $resource->metadata : [];
        $senderId = (string) ($meta['sender_user_id'] ?? $resource->user_id);

        return (string) $resource->user_id === (string) $ownerId
            || ($user && (string) $resource->user_id === (string) $user->id)
            || $senderId === (string) $ownerId
            || ($user && $senderId === (string) $user->id);
    }

    private function resolveAuthorizedPartnerAccess(Request $request, InstitutionResource $resource): bool
    {
        $user = $request->user();
        if (!$user) {
            return false;
        }
        $ctx = $this->resolveInstitutionContext($request);
        $ownerId = $ctx['owner_id'] ?: $user->id;

        if ($ctx['is_staff'] && !in_array('mitra_industri', $ctx['permissions'], true)) {
            return false;
        }

        // Sender must never approve or reject their own outgoing partnership proposal.
        if ($this->isProposalSender($request, $resource, $ownerId)) {
            return false;
        }

        $meta = is_array($resource->metadata) ? $resource->metadata : [];
        $senderId = (string) ($meta['sender_user_id'] ?? $resource->user_id);

        $targetIds = [];
        $targetUsernames = [];

        if (!empty($meta['target_user_id'])) {
            $targetIds[] = (string) $meta['target_user_id'];
        }
        if (!empty($meta['target_username'])) {
            $targetUsernames[] = strtolower(trim((string) $meta['target_username']));
        }

        // Legacy fallback when only corporate_* / institution_* were stored
        if (empty($targetIds) && empty($targetUsernames)) {
            $corpId = (string) ($meta['corporate_user_id'] ?? '');
            $instId = (string) ($meta['institution_user_id'] ?? '');
            if ($corpId !== '' && $corpId === $senderId) {
                if ($instId !== '') {
                    $targetIds[] = $instId;
                }
                if (!empty($meta['institution_username'])) {
                    $targetUsernames[] = strtolower(trim((string) $meta['institution_username']));
                }
            } else {
                if ($corpId !== '') {
                    $targetIds[] = $corpId;
                }
                if (!empty($meta['corporate_username'])) {
                    $targetUsernames[] = strtolower(trim((string) $meta['corporate_username']));
                }
            }
        }

        if (in_array((string) $ownerId, $targetIds, true) || in_array((string) $user->id, $targetIds, true)) {
            return true;
        }

        $ownerUser = (string) $ownerId === (string) $user->id
            ? $user
            : \App\Models\User::query()->select(['id', 'username'])->find($ownerId);
        $callerUsernames = array_filter([
            strtolower(trim((string) ($user->username ?? ''))),
            strtolower(trim((string) ($ownerUser?->username ?? ''))),
        ]);

        foreach ($callerUsernames as $uname) {
            if (in_array($uname, $targetUsernames, true)) {
                return true;
            }
        }

        return false;
    }

    private function isApprovedPartnerOrSyncedMou(InstitutionResource $resource): bool
    {
        $meta = is_array($resource->metadata) ? $resource->metadata : [];
        if ($resource->resource_type === 'partners') {
            return in_array(strtolower((string) $resource->status), ['active', 'approved'], true)
                || strtolower((string) ($meta['approval_status'] ?? '')) === 'approved';
        }
        if ($resource->resource_type === 'documents') {
            return !empty($meta['partner_resource_id']);
        }
        return false;
    }

    public function approve(Request $request, string $id)
    {
        $user = $request->user();
        $resource = InstitutionResource::where('resource_type', 'partners')->find($id);
        if (!$resource) {
            return $this->errorResponse('Data mitra tidak ditemukan.', 404);
        }

        $ctx = $this->resolveInstitutionContext($request);
        $ownerId = $ctx['owner_id'] ?: $user->id;
        if ($this->isProposalSender($request, $resource, $ownerId)) {
            return $this->errorResponse('Pengirim pengajuan tidak dapat menyetujui pengajuannya sendiri. Hanya pihak penerima yang dituju yang berhak meninjau.', 403);
        }

        if (!$this->resolveAuthorizedPartnerAccess($request, $resource)) {
            return $this->errorResponse('Anda tidak memiliki wewenang untuk menyetujui kemitraan ini.', 403);
        }

        if ($this->isApprovedPartnerOrSyncedMou($resource)) {
            return $this->errorResponse('Pengajuan kemitraan ini sudah disetujui sebelumnya.', 422);
        }

        $meta = is_array($resource->metadata) ? $resource->metadata : [];
        $meta['approval_status'] = 'approved';
        $meta['approved_at'] = now()->toIso8601String();
        $meta['approved_by'] = $user->name;
        $meta['approved_by_user_id'] = $ownerId;
        $meta['locked_after_approval'] = true;

        $resource->update([
            'status' => 'active',
            'metadata' => $meta,
        ]);

        // Automatically publish official MoU document for both sender & recipient
        $document = $this->syncMouDocument($resource->fresh(), $user->name);

        return $this->successResponse('Kemitraan berhasil disetujui dan dokumen MoU otomatis diterbitkan di menu Dokumen & MoU.', [
            'partner' => $resource->fresh(),
            'document' => $document,
        ]);
    }

    public function reject(Request $request, string $id)
    {
        $user = $request->user();
        $resource = InstitutionResource::where('resource_type', 'partners')->find($id);
        if (!$resource) {
            return $this->errorResponse('Data mitra tidak ditemukan.', 404);
        }

        $ctx = $this->resolveInstitutionContext($request);
        $ownerId = $ctx['owner_id'] ?: $user->id;
        if ($this->isProposalSender($request, $resource, $ownerId)) {
            return $this->errorResponse('Pengirim pengajuan tidak dapat menolak pengajuannya sendiri. Hanya pihak penerima yang dituju yang berhak meninjau.', 403);
        }

        if (!$this->resolveAuthorizedPartnerAccess($request, $resource)) {
            return $this->errorResponse('Anda tidak memiliki wewenang untuk menolak kemitraan ini.', 403);
        }

        if ($this->isApprovedPartnerOrSyncedMou($resource)) {
            return $this->errorResponse('Kemitraan yang telah disetujui tidak dapat ditolak atau diubah.', 422);
        }

        $meta = is_array($resource->metadata) ? $resource->metadata : [];
        $meta['approval_status'] = 'rejected';
        $meta['rejected_at'] = now()->toIso8601String();
        $meta['rejected_by'] = $user->name;

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
        $ownerUser = $user
            ? ((string) $ownerId === (string) $user->id
                ? $user
                : \App\Models\User::query()->select(['id', 'name', 'username', 'email', 'phone', 'sub_role', 'role'])->find($ownerId))
            : null;
        $actorUser = $ownerUser ?? $user;

        $isCorporate = $this->isCorporateUser($actorUser);
        $isGovernment = $this->isGovernmentUser($actorUser);
        $isSchool = $this->isInstitutionUser($actorUser);

        if ($user) {
            if ($isCorporate && InstitutionResource::where('user_id', $ownerId)->count() === 0) {
                \Database\Seeders\CorporateDummySeeder::seedForUser($user);
            } elseif ($isGovernment && InstitutionResource::where('user_id', $ownerId)->count() === 0) {
                \Database\Seeders\GovernmentDummySeeder::seedForUser($user);
            }
            // Institution role uses strict database records only (no dummy auto-seeding).

            if ($isSchool && $type === 'tenders') {
                return $this->errorResponse('Fitur Pengadaan & Vendor hanya tersedia untuk akun Corporate / Perusahaan.', 403);
            }
        }

        $query = InstitutionResource::query()->with('owner:id,name,username,email,phone,avatar_url,sub_role,role');

        if (in_array($type, ['partners', 'documents'], true)) {
            $matchIds = array_values(array_unique(array_filter([
                $ownerId,
                $user?->id,
            ], fn ($v) => $v !== null && $v !== '')));
            $matchUsernames = array_values(array_unique(array_filter([
                trim((string) ($ownerUser?->username ?? '')),
                trim((string) ($user?->username ?? '')),
            ], fn ($v) => $v !== '')));

            $query->where(function ($q) use ($ownerId, $matchIds, $matchUsernames) {
                $q->where('user_id', $ownerId);
                foreach ($matchIds as $mid) {
                    $q->orWhere('metadata->target_user_id', $mid)
                      ->orWhere('metadata->corporate_user_id', $mid)
                      ->orWhere('metadata->institution_user_id', $mid);
                }
                foreach ($matchUsernames as $uname) {
                    $q->orWhere('metadata->target_username', $uname)
                      ->orWhere('metadata->corporate_username', $uname)
                      ->orWhere('metadata->institution_username', $uname);
                }
            });
        } elseif (in_array($type, ['showcases', 'talents', 'announcements'], true) && ($isCorporate || $request->has('institution_id') || $request->has('user_id'))) {
            // Public/industry showcases and talents viewable across institutions or filtered by institution
            if ($request->has('institution_id')) {
                $query->where('user_id', $request->input('institution_id'));
            } elseif ($request->has('user_id')) {
                $query->where('user_id', $request->input('user_id'));
            }
            if ($isCorporate) {
                $query->whereIn('status', ['published', 'active']);
            }
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

        $linkedDocService = app(\App\Services\LinkedProjectDocumentService::class);
        if (in_array($type, ['documents', null], true)) {
            $resources = $linkedDocService->filterOrphanedPartnerDocuments($resources);
        }

        // Batch-hydrate counterpart user (with live DB phone) and viewer direction flags
        if (in_array($type, ['partners', 'documents', null], true) && $resources->isNotEmpty()) {
            $this->hydrateCounterpartyUsers($resources, $request, $ownerId, $ctx);
        }

        $canIncludeLinkedProjectDocs = $ownerId
            && ($type === 'documents' || (empty($type) && (!$isStaff || in_array('dokumen_institusi', $ctx['permissions'], true))));

        if ($canIncludeLinkedProjectDocs) {
            $linkedProjectDocs = $linkedDocService->collectForUser((string) $ownerId, $ownerUser);
            if ($linkedProjectDocs->isNotEmpty()) {
                $merged = collect($resources->toArray())
                    ->concat($linkedProjectDocs)
                    ->sortByDesc(fn (array $item) => $item['published_at'] ?? $item['created_at'] ?? '')
                    ->values();

                return $this->successResponse('Data instansi berhasil diambil.', $merged);
            }
        }

        return $this->successResponse('Data instansi berhasil diambil.', $resources);
    }

    private function resolveRecipientUserIdForResource(InstitutionResource $resource): ?string
    {
        $meta = is_array($resource->metadata) ? $resource->metadata : [];
        $senderId = (string) ($meta['sender_user_id'] ?? $resource->user_id);

        foreach (['target_user_id', 'corporate_user_id', 'institution_user_id'] as $key) {
            $candidate = isset($meta[$key]) ? (string) $meta[$key] : '';
            if ($candidate !== '' && $candidate !== $senderId && $candidate !== (string) $resource->user_id) {
                return $candidate;
            }
        }

        return null;
    }

    private function hydrateCounterpartyUsers(
        \Illuminate\Support\Collection $resources,
        ?Request $request = null,
        string|int|null $ownerId = null,
        ?array $ctx = null,
    ): void {
        $recipientIds = $resources
            ->filter(fn ($item) => in_array($item->resource_type, ['partners', 'documents'], true))
            ->map(fn ($item) => $this->resolveRecipientUserIdForResource($item))
            ->filter()
            ->unique()
            ->values();

        $recipientsById = $recipientIds->isEmpty()
            ? collect()
            : \App\Models\User::query()
                ->select(['id', 'name', 'username', 'email', 'phone', 'avatar_url', 'sub_role', 'role'])
                ->whereIn('id', $recipientIds->all())
                ->get()
                ->keyBy(fn ($u) => (string) $u->id);

        foreach ($resources as $item) {
            if (!in_array($item->resource_type, ['partners', 'documents'], true)) {
                continue;
            }

            $recId = $this->resolveRecipientUserIdForResource($item);
            $recipient = $recId ? ($recipientsById->get((string) $recId) ?? null) : null;
            $item->setAttribute('recipient', $recipient);

            $meta = is_array($item->metadata) ? $item->metadata : [];
            $owner = $item->owner;

            if ($owner && empty($meta['sender_phone']) && !empty($owner->phone)) {
                $meta['sender_phone'] = $owner->phone;
            }
            if ($recipient && empty($meta['target_phone']) && !empty($recipient->phone)) {
                $meta['target_phone'] = $recipient->phone;
            }

            if ($owner && $this->isCorporateUser($owner) && empty($meta['corporate_phone']) && !empty($owner->phone)) {
                $meta['corporate_phone'] = $owner->phone;
            } elseif ($recipient && $this->isCorporateUser($recipient) && empty($meta['corporate_phone']) && !empty($recipient->phone)) {
                $meta['corporate_phone'] = $recipient->phone;
            }

            if ($owner && $this->isInstitutionUser($owner) && empty($meta['institution_phone']) && !empty($owner->phone)) {
                $meta['institution_phone'] = $owner->phone;
            } elseif ($recipient && $this->isInstitutionUser($recipient) && empty($meta['institution_phone']) && !empty($recipient->phone)) {
                $meta['institution_phone'] = $recipient->phone;
            }

            $item->setAttribute('metadata', $meta);
            $item->syncOriginalAttribute('metadata');

            if ($request && $ownerId !== null && $item->resource_type === 'partners') {
                $isSender = $this->isProposalSender($request, $item, $ownerId);
                $canReview = $this->resolveAuthorizedPartnerAccess($request, $item);
                $hasPermissionOrOwner = !$ctx['is_staff'] || in_array('mitra_industri', $ctx['permissions'] ?? [], true);
                $isRecipient = !$isSender && ($canReview || !$hasPermissionOrOwner && $recId !== null && (string) $recId === (string) $ownerId);
                $item->setAttribute('viewer_is_sender', $isSender);
                $item->setAttribute('viewer_is_recipient', $isRecipient);
                $item->setAttribute('viewer_can_review', $canReview);
            }
        }
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
        $ownerUser = (string) $ownerId === (string) $user->id
            ? $user
            : (\App\Models\User::find($ownerId) ?? $user);

        $isSchool = $this->isInstitutionUser($ownerUser);
        $isCorporate = $this->isCorporateUser($ownerUser);

        if ($isSchool && $resType === 'tenders') {
            return $this->errorResponse('Fitur Pengadaan & Vendor hanya tersedia untuk akun Corporate / Perusahaan.', 403);
        }

        if ($isSchool && $resType === 'documents') {
            return $this->errorResponse('Dokumen MoU diterbitkan otomatis melalui proses persetujuan kemitraan industri.', 403);
        }

        $meta = $validated['metadata'] ?? [];

        $targetPartner = null;
        if ($resType === 'partners') {
            $description = trim((string) ($validated['description'] ?? ''));
            if ($description === '') {
                return $this->errorResponse('Deskripsi kerjasama wajib diisi.', 422);
            }
            $validated['description'] = $description;

            $metaArray = is_array($meta) ? $meta : [];
            $mouFiles = $this->normalizeMouFiles($metaArray);
            if (count($mouFiles) > 3) {
                return $this->errorResponse('Maksimal 3 berkas kerjasama yang dapat diunggah.', 422);
            }
            if (count($mouFiles) < 1) {
                return $this->errorResponse('Berkas kerjasama wajib diunggah (minimal 1, maksimal 3 berkas).', 422);
            }

            $meta = $this->applyMouMetadata($metaArray, $mouFiles);
            $targetPartner = $this->resolveTargetPartnerUser($meta, $ownerUser, $user);

            if ($targetPartner && ((string) $targetPartner->id === (string) $ownerId || (string) $targetPartner->id === (string) $user->id)) {
                return $this->errorResponse('Anda tidak dapat mengajukan kemitraan ke akun sendiri.', 422);
            }

            $senderRole = $isCorporate ? 'corporate' : ($isSchool ? 'institution' : 'other');
            $meta['sender_user_id'] = $ownerUser->id;
            $meta['sender_name'] = $ownerUser->name;
            $meta['sender_username'] = $ownerUser->username;
            $meta['sender_email'] = $ownerUser->email;
            $meta['sender_phone'] = $ownerUser->phone;
            $meta['sender_role'] = $senderRole;

            if ($targetPartner) {
                $targetRole = $this->isCorporateUser($targetPartner)
                    ? 'corporate'
                    : ($this->isInstitutionUser($targetPartner) ? 'institution' : 'other');

                $meta['target_user_id'] = $targetPartner->id;
                $meta['target_name'] = $targetPartner->name;
                $meta['target_username'] = $targetPartner->username;
                $meta['target_email'] = $targetPartner->email;
                $meta['target_phone'] = $targetPartner->phone;
                $meta['target_role'] = $targetRole;

                if (trim((string) ($validated['title'] ?? '')) === '') {
                    $validated['title'] = $targetPartner->name;
                }

                if ($isCorporate) {
                    $meta['corporate_user_id'] = $ownerUser->id;
                    $meta['corporate_name'] = $ownerUser->name;
                    $meta['corporate_username'] = $ownerUser->username;
                    $meta['corporate_email'] = $ownerUser->email;
                    $meta['corporate_phone'] = $ownerUser->phone;

                    $meta['institution_user_id'] = $targetPartner->id;
                    $meta['institution_name'] = $targetPartner->name;
                    $meta['institution_username'] = $targetPartner->username;
                    $meta['institution_email'] = $targetPartner->email;
                    $meta['institution_phone'] = $targetPartner->phone;
                } else {
                    $meta['institution_user_id'] = $ownerUser->id;
                    $meta['institution_name'] = $meta['institution_name'] ?? $ownerUser->name;
                    $meta['institution_username'] = $meta['institution_username'] ?? $ownerUser->username;
                    $meta['institution_email'] = $meta['institution_email'] ?? $ownerUser->email;
                    $meta['institution_phone'] = $ownerUser->phone;

                    $meta['corporate_user_id'] = $targetPartner->id;
                    $meta['corporate_name'] = $targetPartner->name;
                    $meta['corporate_username'] = $targetPartner->username;
                    $meta['corporate_email'] = $targetPartner->email;
                    $meta['corporate_phone'] = $targetPartner->phone;
                }

                if (!empty($targetPartner->phone) && empty($meta['phone'])) {
                    $meta['phone'] = $targetPartner->phone;
                }
            } elseif ($isSchool) {
                $meta['institution_user_id'] = $ownerUser->id;
                $meta['institution_name'] = $meta['institution_name'] ?? $ownerUser->name;
                $meta['institution_username'] = $meta['institution_username'] ?? $ownerUser->username;
                $meta['institution_email'] = $meta['institution_email'] ?? $ownerUser->email;
                $meta['institution_phone'] = $ownerUser->phone;
            }

            if ($isSchool || $isCorporate || $targetPartner !== null) {
                $validated['status'] = 'pending';
                $meta['approval_status'] = 'pending';
            }

            $validated['metadata'] = $meta;
        }

        // If creating a team member (app-local sub-account of this institution, managed in backend)
        $subAccountPasswordHash = null;
        $subAccountUser = null;

        if ($resType === 'members') {
            $memberEmail = strtolower(trim((string) ($meta['email'] ?? '')));
            $memberName = trim((string) ($validated['title'] ?? ''));
            $rawPassword = isset($meta['password']) ? trim((string) $meta['password']) : '';
            if ($rawPassword !== '' && strlen($rawPassword) < 6) {
                return $this->errorResponse('Kata sandi anggota tim minimal 6 karakter.', 422);
            }
            $memberPassword = $rawPassword !== '' ? $rawPassword : 'Kreavana123!';
            $memberRole = $meta['role'] ?? 'Karyawan / Staf';
            $memberDept = $meta['department'] ?? $validated['description'] ?? 'Staf Lembaga';
            $memberPerms = $meta['permissions'] ?? [];
            $requestedUsername = isset($meta['username']) ? strtolower(trim((string) $meta['username'])) : '';
            $memberPhone = isset($meta['phone']) && trim((string) $meta['phone']) !== ''
                ? trim((string) $meta['phone'])
                : null;

            if (empty($memberEmail) || empty($memberName)) {
                return $this->errorResponse('Nama lengkap dan email anggota tim wajib diisi.', 422);
            }

            if ($requestedUsername !== '' && !preg_match('/^[a-zA-Z0-9_.-]{3,50}$/', $requestedUsername)) {
                return $this->errorResponse('Username harus 3-50 karakter dan hanya boleh huruf, angka, titik, strip, atau underscore.', 422);
            }

            $existingUser = \App\Models\User::whereRaw('LOWER(email) = ?', [$memberEmail])->first();

            if ($existingUser) {
                $existingSub = $existingUser->institutionSubAccount;
                if (!$existingSub || $existingSub->institution_id !== $ownerId || $existingSub->is_active) {
                    return $this->errorResponse('Alamat email ini sudah digunakan oleh akun lain.', 422);
                }
            }

            if ($requestedUsername !== '') {
                $usernameTaken = \App\Models\User::whereRaw('LOWER(username) = ?', [$requestedUsername])
                    ->when($existingUser, fn ($q) => $q->where('id', '!=', $existingUser->id))
                    ->exists();
                if ($usernameTaken) {
                    return $this->errorResponse('Username ini sudah digunakan oleh akun lain.', 422);
                }
                $username = $requestedUsername;
            } elseif ($existingUser) {
                $username = $existingUser->username;
            } else {
                $cleanBase = preg_replace('/[^a-z0-9]/', '', strtolower(explode('@', $memberEmail)[0])) ?: 'staff';
                $prefix = substr($cleanBase, 0, 20);
                do {
                    $username = $prefix . '_' . random_int(100, 9999);
                } while (\App\Models\User::whereRaw('LOWER(username) = ?', [$username])->exists());
            }

            if ($existingUser) {
                $existingUser->update([
                    'name' => $memberName,
                    'username' => $username,
                    'email' => $memberEmail,
                    'phone' => $memberPhone ?? $existingUser->phone,
                    'role' => \App\Enums\RoleType::User,
                    'sub_role' => 'institution',
                    'is_verified' => true,
                    'verification_type' => 'institution',
                    'email_verified_at' => $existingUser->email_verified_at ?? now(),
                ]);
                $staffUser = $existingUser->fresh();
            } else {
                $staffUser = \App\Models\User::create([
                    'name' => $memberName,
                    'username' => $username,
                    'email' => $memberEmail,
                    'phone' => $memberPhone,
                    'role' => \App\Enums\RoleType::User,
                    'sub_role' => 'institution',
                    'is_verified' => true,
                    'verification_type' => 'institution',
                    'email_verified_at' => now(),
                ]);
            }

            $subAccountUser = $staffUser;
            $subAccountPasswordHash = \Illuminate\Support\Facades\Hash::make($memberPassword);

            $meta['user_id'] = $staffUser->id;
            $meta['username'] = $staffUser->username;
            $meta['email'] = $memberEmail;
            if ($staffUser->phone !== null) {
                $meta['phone'] = $staffUser->phone;
            }
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

        if ($resType === 'members' && $subAccountUser && $subAccountPasswordHash) {
            \App\Models\InstitutionSubAccount::updateOrCreate(
                ['user_id' => $subAccountUser->id],
                [
                    'institution_id' => $ownerId,
                    'institution_resource_id' => $resource->id,
                    'password_hash' => $subAccountPasswordHash,
                    'is_active' => true,
                    'password_changed_at' => now(),
                ]
            );
        }

        if ($resource->resource_type === 'partners' && in_array($resource->status, ['active', 'approved'])) {
            $this->syncMouDocument($resource);
        }

        $freshResource = $resource->fresh()->load('owner:id,name,username,email,phone,avatar_url,sub_role,role');
        if ($resType === 'partners') {
            $this->hydrateCounterpartyUsers(collect([$freshResource]));
        }

        return $this->successResponse('Data berhasil disimpan.', $freshResource, 201);
    }

    private function resolveTargetPartnerUser(array $meta, \App\Models\User $ownerUser, \App\Models\User $caller): ?\App\Models\User
    {
        $selfIds = [(string) $ownerUser->id, (string) $caller->id];
        $candidateKeys = $this->isCorporateUser($ownerUser)
            ? ['target_user_id', 'institution_user_id', 'corporate_user_id']
            : ['target_user_id', 'corporate_user_id', 'institution_user_id'];

        foreach ($candidateKeys as $key) {
            if (!empty($meta[$key]) && !in_array((string) $meta[$key], $selfIds, true)) {
                $found = \App\Models\User::query()
                    ->select(['id', 'name', 'username', 'email', 'phone', 'avatar_url', 'sub_role', 'role'])
                    ->find($meta[$key]);
                if ($found) {
                    return $found;
                }
            }
        }

        // Handle explicit self-target IDs cleanly so caller receives explicit validation error
        foreach (['target_user_id', 'corporate_user_id', 'institution_user_id'] as $key) {
            if (!empty($meta[$key]) && in_array((string) $meta[$key], $selfIds, true)) {
                if ($key === 'target_user_id'
                    || ($this->isCorporateUser($ownerUser) && $key === 'institution_user_id')
                    || (!$this->isCorporateUser($ownerUser) && $key === 'corporate_user_id')) {
                    return $ownerUser;
                }
            }
        }

        $usernameKeys = $this->isCorporateUser($ownerUser)
            ? ['target_username', 'institution_username']
            : ['target_username', 'corporate_username'];
        foreach ($usernameKeys as $uKey) {
            $uname = ltrim(strtolower(trim((string) ($meta[$uKey] ?? ''))), '@');
            if ($uname !== '') {
                $found = \App\Models\User::query()
                    ->select(['id', 'name', 'username', 'email', 'phone', 'avatar_url', 'sub_role', 'role'])
                    ->whereRaw('LOWER(username) = ?', [$uname])
                    ->first();
                if ($found) {
                    return $found;
                }
            }
        }

        return null;
    }

    public function update(Request $request, string $id)
    {
        $this->ensureInstitutionAccount($request);
        if (str_starts_with($id, 'project-')) {
            return $this->errorResponse('Dokumen yang terhubung dari Proyek Saya tidak dapat diubah dari menu ini. Silakan kelola melalui menu Proyek Saya.', 403);
        }
        $ctx = $this->resolveInstitutionContext($request);
        $ownerId = $ctx['owner_id'] ?: $request->user()->id;
        $isStaff = $ctx['is_staff'];

        $resource = InstitutionResource::query()
            ->where('user_id', $ownerId)
            ->find($id);

        if (!$resource) {
            $incomingResource = InstitutionResource::find($id);
            if ($incomingResource && $this->resolveAuthorizedPartnerAccess($request, $incomingResource)) {
                return $this->errorResponse('Pihak penerima pengajuan hanya dapat meninjau (setujui atau tolak) tanpa mengubah isi pengajuan.', 403);
            }
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

        if ($this->isApprovedPartnerOrSyncedMou($resource)) {
            return $this->errorResponse('Kemitraan dan berkas MoU yang telah disetujui tidak dapat diubah lagi.', 403);
        }

        $user = $request->user();
        $ownerUser = (string) $ownerId === (string) $user->id
            ? $user
            : (\App\Models\User::find($ownerId) ?? $user);
        $isSchool = $this->isInstitutionUser($ownerUser);

        $validated = $this->validateResource($request, partial: true);

        if ($isSchool && ($resource->resource_type === 'tenders' || ($validated['resource_type'] ?? null) === 'tenders')) {
            return $this->errorResponse('Fitur Pengadaan & Vendor hanya tersedia untuk akun Corporate / Perusahaan.', 403);
        }

        if ($resource->resource_type === 'partners'
            && isset($validated['status'])
            && in_array(strtolower((string) $validated['status']), ['active', 'approved'], true)
        ) {
            return $this->errorResponse('Status persetujuan kemitraan hanya dapat diaktifkan oleh pihak penerima pengajuan.', 403);
        }

        if (isset($validated['metadata']) && is_array($validated['metadata'])) {
            $oldMeta = is_array($resource->metadata) ? $resource->metadata : [];
            $newMeta = array_merge($oldMeta, $validated['metadata']);

            if ($resource->resource_type === 'members') {
                $staffPassword = $validated['metadata']['password'] ?? $request->input('metadata.password');
                if (isset($newMeta['password'])) {
                    unset($newMeta['password']);
                }
                if ($staffPassword !== null && trim((string) $staffPassword) !== '' && strlen((string) $staffPassword) < 6) {
                    return $this->errorResponse('Kata sandi anggota tim minimal 6 karakter.', 422);
                }
                if (isset($newMeta['permissions']) && is_array($newMeta['permissions'])) {
                    $newMeta['permissions'] = array_values($newMeta['permissions']);
                }

                // Resolve linked backend sub-account user
                $memberUserId = $newMeta['user_id'] ?? $oldMeta['user_id'] ?? null;
                $oldEmail = isset($oldMeta['email']) ? strtolower(trim((string) $oldMeta['email'])) : null;
                $targetUser = $memberUserId
                    ? \App\Models\User::find($memberUserId)
                    : ($oldEmail ? \App\Models\User::whereRaw('LOWER(email) = ?', [$oldEmail])->first() : null);

                if ($targetUser) {
                    $userUpdates = [];
                    if (!empty($validated['title']) && $targetUser->name !== $validated['title']) {
                        $userUpdates['name'] = trim((string) $validated['title']);
                    }
                    if (!empty($newMeta['email'])) {
                        $normalizedEmail = strtolower(trim((string) $newMeta['email']));
                        $newMeta['email'] = $normalizedEmail;
                        if (strtolower((string) $targetUser->email) !== $normalizedEmail) {
                            $emailConflict = \App\Models\User::whereRaw('LOWER(email) = ?', [$normalizedEmail])
                                ->where('id', '!=', $targetUser->id)
                                ->exists();
                            if ($emailConflict) {
                                return $this->errorResponse('Alamat email ini sudah digunakan oleh akun lain.', 422);
                            }
                            $userUpdates['email'] = $normalizedEmail;
                        }
                    }
                    if (!empty($newMeta['username'])) {
                        $normalizedUsername = strtolower(trim((string) $newMeta['username']));
                        if (!preg_match('/^[a-zA-Z0-9_.-]{3,50}$/', $normalizedUsername)) {
                            return $this->errorResponse('Username harus 3-50 karakter dan hanya boleh huruf, angka, titik, strip, atau underscore.', 422);
                        }
                        $newMeta['username'] = $normalizedUsername;
                        if (strtolower((string) $targetUser->username) !== $normalizedUsername) {
                            $usernameConflict = \App\Models\User::whereRaw('LOWER(username) = ?', [$normalizedUsername])
                                ->where('id', '!=', $targetUser->id)
                                ->exists();
                            if ($usernameConflict) {
                                return $this->errorResponse('Username ini sudah digunakan oleh akun lain.', 422);
                            }
                            $userUpdates['username'] = $normalizedUsername;
                        }
                    }
                    if (array_key_exists('phone', $validated['metadata'])) {
                        $trimmedPhone = trim((string) ($validated['metadata']['phone'] ?? ''));
                        $userUpdates['phone'] = $trimmedPhone !== '' ? $trimmedPhone : null;
                        $newMeta['phone'] = $userUpdates['phone'];
                    }

                    if (!empty($userUpdates)) {
                        $targetUser->update($userUpdates);
                    }

                    $newMeta['user_id'] = $targetUser->id;
                    $newMeta['username'] = $userUpdates['username'] ?? $targetUser->username;
                    $newMeta['email'] = $userUpdates['email'] ?? $targetUser->email;

                    if (!empty($staffPassword) && strlen((string) $staffPassword) >= 6) {
                        \App\Models\InstitutionSubAccount::updateOrCreate(
                            ['user_id' => $targetUser->id],
                            [
                                'institution_id' => $ownerId,
                                'institution_resource_id' => $resource->id,
                                'password_hash' => \Illuminate\Support\Facades\Hash::make((string) $staffPassword),
                                'is_active' => true,
                                'password_changed_at' => now(),
                            ]
                        );
                    }
                }

                $validated['metadata'] = $newMeta;
            } else {
                if ($resource->resource_type === 'partners') {
                    $mouFiles = $this->normalizeMouFiles($newMeta);
                    if (count($mouFiles) > 3) {
                        return $this->errorResponse('Maksimal 3 berkas kerjasama yang dapat diunggah.', 422);
                    }
                    if ((array_key_exists('mou_files', $validated['metadata']) || array_key_exists('mou_url', $validated['metadata'])) && count($mouFiles) < 1) {
                        return $this->errorResponse('Berkas kerjasama wajib diunggah (minimal 1, maksimal 3 berkas).', 422);
                    }
                    $newMeta = $this->applyMouMetadata($newMeta, $mouFiles);
                }
                $validated['metadata'] = $newMeta;
            }
        }

        if ($resource->resource_type === 'partners' && $request->has('description') && trim((string) ($validated['description'] ?? '')) === '') {
            return $this->errorResponse('Deskripsi kerjasama wajib diisi.', 422);
        }

        $status = $validated['status'] ?? $resource->status;
        if ($status === 'published' && !$resource->published_at) {
            $validated['published_at'] = now();
        } elseif ($status !== 'published') {
            $validated['published_at'] = null;
        }

        $resource->update($validated);

        if ($resource->resource_type === 'partners' && in_array($resource->status, ['active', 'approved'])) {
            $this->syncMouDocument($resource->fresh());
        }

        return $this->successResponse('Data berhasil diperbarui.', $resource->fresh());
    }

    private function syncMouDocument(InstitutionResource $resource, ?string $approvedBy = null): ?InstitutionResource
    {
        $meta = is_array($resource->metadata) ? $resource->metadata : [];
        $mouFiles = $this->normalizeMouFiles($meta);
        $primaryFile = $mouFiles[0] ?? null;
        $mouUrl = $primaryFile['url'] ?? ($meta['mou_url'] ?? null);
        $partnerName = $resource->title;
        $docTitle = "Perjanjian Kerjasama (MoU) - {$partnerName}";
        $ownerUser = $resource->owner;
        $institutionName = $meta['institution_name'] ?? $ownerUser?->name;
        $institutionUsername = $meta['institution_username'] ?? $ownerUser?->username;

        $document = InstitutionResource::updateOrCreate(
            [
                'user_id' => $resource->user_id,
                'resource_type' => 'documents',
                'title' => $docTitle,
            ],
            [
                'description' => "Dokumen resmi legalitas Perjanjian Kerjasama (MoU) kemitraan industri yang telah disetujui bersama {$partnerName}."
                    . (trim((string) $resource->description) !== '' ? "\n\nRuang Lingkup: " . trim((string) $resource->description) : ''),
                'status' => 'published',
                'published_at' => now(),
                'metadata' => [
                    'document_number' => 'MOU-' . strtoupper(substr(md5($resource->id), 0, 8)) . '/' . date('Y'),
                    'category' => 'MoU Kemitraan',
                    'valid_until' => now()->addYears(3)->format('Y-m-d'),
                    'url' => $mouUrl ?: null,
                    'file_url' => $mouUrl ?: null,
                    'file_name' => $primaryFile['filename'] ?? ($meta['mou_filename'] ?? null),
                    'file_format' => strtoupper($primaryFile['extension'] ?? ($meta['mou_extension'] ?? 'PDF')),
                    'file_size' => $primaryFile['filesize'] ?? ($meta['mou_filesize'] ?? 'Dokumen Digital'),
                    'mou_files' => $mouFiles,
                    'partner_name' => $partnerName,
                    'partner_resource_id' => $resource->id,
                    'sender_user_id' => $meta['sender_user_id'] ?? $resource->user_id,
                    'sender_name' => $meta['sender_name'] ?? $ownerUser?->name,
                    'sender_username' => $meta['sender_username'] ?? $ownerUser?->username,
                    'sender_phone' => $meta['sender_phone'] ?? $ownerUser?->phone,
                    'sender_role' => $meta['sender_role'] ?? null,
                    'target_user_id' => $meta['target_user_id'] ?? null,
                    'target_name' => $meta['target_name'] ?? $partnerName,
                    'target_username' => $meta['target_username'] ?? null,
                    'target_phone' => $meta['target_phone'] ?? null,
                    'target_role' => $meta['target_role'] ?? null,
                    'corporate_user_id' => $meta['corporate_user_id'] ?? null,
                    'corporate_username' => $meta['corporate_username'] ?? null,
                    'corporate_name' => $meta['corporate_name'] ?? $partnerName,
                    'corporate_phone' => $meta['corporate_phone'] ?? null,
                    'institution_user_id' => $meta['institution_user_id'] ?? $resource->user_id,
                    'institution_name' => $institutionName,
                    'institution_username' => $institutionUsername,
                    'institution_phone' => $meta['institution_phone'] ?? $ownerUser?->phone,
                    'approved_by' => $approvedBy ?? ($meta['approved_by'] ?? null),
                    'verified' => true,
                    'locked_after_approval' => true,
                    'approved_at' => $meta['approved_at'] ?? now()->toIso8601String(),
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
        if (str_starts_with($id, 'project-')) {
            return $this->errorResponse('Dokumen yang terhubung dari Proyek Saya mengikuti data proyek terkait. Hapus atau ubah langsung dari menu Proyek Saya.', 403);
        }
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

        if ($resource->resource_type === 'members') {
            $meta = is_array($resource->metadata) ? $resource->metadata : [];
            $subQuery = \App\Models\InstitutionSubAccount::where('institution_resource_id', $resource->id);
            if (!empty($meta['user_id'])) {
                $subQuery->orWhere('user_id', $meta['user_id']);
            }
            $subAccounts = $subQuery->get();
            foreach ($subAccounts as $subAccount) {
                $subAccount->update([
                    'is_active' => false,
                    'institution_resource_id' => null,
                ]);
                app(\App\Services\RefreshTokenRepository::class)->revokeAllForUser($subAccount->user_id);
            }
        }

        if ($resource->resource_type === 'partners') {
            $partnerMeta = is_array($resource->metadata) ? $resource->metadata : [];
            $linkedDocId = $partnerMeta['linked_document_id'] ?? null;

            InstitutionResource::query()
                ->where('resource_type', 'documents')
                ->where(function ($q) use ($resource, $linkedDocId) {
                    $q->where('metadata->partner_resource_id', $resource->id);
                    if (!empty($linkedDocId)) {
                        $q->orWhere('id', $linkedDocId);
                    }
                })
                ->delete();
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
