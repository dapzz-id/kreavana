<?php

namespace App\Services;

use App\Repositories\OpportunityRepository;
use App\Repositories\ReportRepository;
use App\Repositories\NotificationRepository;
use App\Models\Opportunity;
use App\Models\OpportunityRequirement;
use App\Models\OpportunityApplication;
use App\Models\User;
use App\Models\JobContract;
use App\Models\SystemSetting;
use App\Models\WalletTransaction;
use App\Enums\RoleType;
use App\Enums\ContractStatus;
use App\Enums\WorkStatus;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Exception;

class OpportunityService extends BaseService
{
    protected OpportunityRepository $opportunityRepo;
    protected ReportRepository $reportRepo;
    protected NotificationRepository $notificationRepo;

    public function __construct(OpportunityRepository $opportunityRepo, ReportRepository $reportRepo, NotificationRepository $notificationRepo)
    {
        $this->opportunityRepo = $opportunityRepo;
        $this->reportRepo = $reportRepo;
        $this->notificationRepo = $notificationRepo;
    }

    private function resolveAppliedOpportunityLookup(?string $userId, $opportunities): ?array
    {
        if (empty($userId) || $opportunities->isEmpty()) {
            return $userId ? [] : null;
        }

        $oppIds = $opportunities->pluck('id')->filter()->values()->all();
        if (empty($oppIds)) {
            return [];
        }

        return OpportunityApplication::where('creator_id', $userId)
            ->whereIn('opportunity_id', $oppIds)
            ->pluck('opportunity_id')
            ->flip()
            ->all();
    }

    public function getList(string|array $subRole = 'all', ?string $type = null, int $limit = 50, ?string $search = null)
    {
        $opportunities = $this->opportunityRepo->getList($subRole, $type, $limit, $search);
        $appliedLookup = $this->resolveAppliedOpportunityLookup(Auth::guard('api')->id(), $opportunities);

        return $opportunities->map(fn ($opp) => $this->formatOpportunity($opp, false, $appliedLookup));
    }

    public function getUserOpportunities(string $userId, int $limit = 50)
    {
        $opportunities = $this->opportunityRepo->getMyOpportunities($userId, $limit);
        $appliedLookup = $this->resolveAppliedOpportunityLookup($userId, $opportunities);

        return $opportunities->map(fn ($opp) => $this->formatOpportunity($opp, false, $appliedLookup));
    }

    public function getMapLocations(string|array $subRole = 'all', ?float $lat = null, ?float $lng = null, ?float $radiusKm = null)
    {
        $locations = $this->opportunityRepo->getMapLocations($subRole, $lat, $lng, $radiusKm);
        $appliedLookup = $this->resolveAppliedOpportunityLookup(Auth::guard('api')->id(), $locations);

        return $locations->map(fn ($opp) => $this->formatOpportunity($opp, false, $appliedLookup));
    }

    public function findById(string $id)
    {
        $opp = $this->opportunityRepo->findWithUser($id);
        
        if (!$opp) return null;

        $authId = Auth::guard('api')->id();
        $appliedLookup = $this->resolveAppliedOpportunityLookup($authId, collect([$opp]));

        return $this->formatOpportunity($opp, true, $appliedLookup);
    }

    public function createOpportunity(string $userId, array $data, $posterFile = null)
    {
        return DB::transaction(function () use ($userId, $data, $posterFile) {
            $isAbove100Jt = self::isBudgetAbove100Jt($data['budget_range'] ?? '');
            $data['signature_type'] = $isAbove100Jt ? 'wet_signature' : 'dynamic_electronic';
            $data['escrow_status'] = 'none';
            $data['status'] = 'open';
            $data['posted_by'] = $userId;
            $data['created_at'] = now();

            // Handle poster image upload securely
            if ($posterFile && $posterFile->isValid()) {
                $user = User::find($userId);
                /** @var \App\Services\StorageService $storageService */
                $storageService = app(\App\Services\StorageService::class);
                $storageFile = $storageService->store($user, $posterFile, 'posters', 'public');
                $data['poster_url'] = $storageFile->url;
            }

            // Extract requirements if provided
            $requirements = $data['requirements'] ?? [];
            unset($data['requirements']);

            // Set primary sub_role_slug if not set but requirements exist
            if (empty($data['sub_role_slug']) && !empty($requirements)) {
                $data['sub_role_slug'] = $requirements[0]['sub_role_slug'] ?? 'general';
            }

            $opp = $this->opportunityRepo->create($data);

            // Create normalized requirements
            if (!empty($requirements) && is_array($requirements)) {
                foreach ($requirements as $req) {
                    if (!empty($req['sub_role_slug'])) {
                        OpportunityRequirement::create([
                            'opportunity_id' => $opp->id,
                            'sub_role_slug' => $req['sub_role_slug'],
                            'quantity' => isset($req['quantity']) ? (int) $req['quantity'] : ($req['sub_role_slug'] === 'kualifikasi' ? 0 : 1),
                            'notes' => $req['notes'] ?? null,
                            'payment_scheme' => $req['payment_scheme'] ?? 'full_at_end',
                            'payment_terms' => $req['payment_terms'] ?? null,
                        ]);
                    }
                }
            } else if (!empty($opp->sub_role_slug)) {
                // Ensure at least 1 requirement row for consistency
                OpportunityRequirement::create([
                    'opportunity_id' => $opp->id,
                    'sub_role_slug' => $opp->sub_role_slug,
                    'quantity' => 1,
                    'notes' => null,
                    'payment_scheme' => 'full_at_end',
                    'payment_terms' => null,
                ]);
            }

            $this->notificationRepo->create([
                'user_id' => $userId,
                'title' => 'Peluang Proyek Dipublikasikan',
                'message' => '"' . ($data['title'] ?? 'Peluang baru') . '" telah berhasil dipublikasikan.',
                'type' => 'project',
                'data' => ['opportunity_id' => $opp->id],
                'is_read' => false,
                'created_at' => now(),
            ]);

            Cache::increment('opportunities_version');

            return $this->formatOpportunity($this->opportunityRepo->findWithUser($opp->id), true);
        });
    }

    public function updateOpportunity(string $opportunityId, string $userId, array $data, $userRole = null): array
    {
        return DB::transaction(function () use ($opportunityId, $userId, $data, $userRole) {
            $opp = Opportunity::where('id', $opportunityId)->lockForUpdate()->firstOrFail();

            if ($opp->posted_by !== $userId && $userRole !== 'admin') {
                abort(403, 'Anda tidak memiliki hak untuk mengubah lowongan ini.');
            }

            $fillable = [
                'title', 'description', 'sub_role_slug', 'location', 'address',
                'deadline', 'budget_range', 'status'
            ];

            foreach ($fillable as $field) {
                if (array_key_exists($field, $data)) {
                    $opp->{$field} = $data[$field];
                }
            }
            $opp->save();

            if (isset($data['requirements']) && is_array($data['requirements'])) {
                $opp->requirements()->delete();
                foreach ($data['requirements'] as $req) {
                    if (!empty($req['sub_role_slug'])) {
                        OpportunityRequirement::create([
                            'opportunity_id' => $opp->id,
                            'sub_role_slug' => $req['sub_role_slug'],
                            'quantity' => isset($req['quantity']) ? (int) $req['quantity'] : ($req['sub_role_slug'] === 'kualifikasi' ? 0 : 1),
                            'notes' => $req['notes'] ?? null,
                            'payment_scheme' => $req['payment_scheme'] ?? 'full_at_end',
                        ]);
                    }
                }
            }

            Cache::increment('opportunities_version');

            return $this->formatOpportunity($this->opportunityRepo->findWithUser($opp->id), true);
        });
    }

    public function updateStatus(string $opportunityId, string $userId, string $status, $userRole = null): array
    {
        return DB::transaction(function () use ($opportunityId, $userId, $status, $userRole) {
            $opp = Opportunity::where('id', $opportunityId)->lockForUpdate()->firstOrFail();

            if ($opp->posted_by !== $userId && $userRole !== 'admin') {
                abort(403, 'Anda tidak memiliki hak untuk mengubah status lowongan ini.');
            }

            $validStatuses = ['open', 'closed', 'in_progress', 'cancelled'];
            if (!in_array($status, $validStatuses)) {
                abort(422, 'Status tidak valid.');
            }

            $opp->status = $status;
            $opp->save();

            Cache::increment('opportunities_version');

            return $this->formatOpportunity($this->opportunityRepo->findWithUser($opp->id), true);
        });
    }

    public function deleteOpportunity(string $opportunityId, string $userId, $userRole = null): bool
    {
        return DB::transaction(function () use ($opportunityId, $userId, $userRole) {
            $opp = Opportunity::where('id', $opportunityId)->firstOrFail();

            if ($opp->posted_by !== $userId && $userRole !== 'admin') {
                abort(403, 'Anda tidak memiliki hak untuk menghapus lowongan ini.');
            }

            $opp->requirements()->delete();
            $opp->delete();

            Cache::increment('opportunities_version');

            return true;
        });
    }

    public function applyToOpportunity(string $creatorId, string $opportunityId, array $data): array
    {
        return DB::transaction(function () use ($creatorId, $opportunityId, $data) {
            $creator = User::where('id', $creatorId)->firstOrFail();
            $isInstitution = $creator->isInstitution();
            if ($creator->role !== RoleType::Creator && $creator->role !== RoleType::Admin && !$isInstitution) {
                abort(403, 'Hanya kreator terverifikasi yang dapat melamar proyek.');
            }

            $opp = Opportunity::with(['user:id,role,sub_role', 'requirements'])
                ->where('id', $opportunityId)
                ->lockForUpdate()
                ->firstOrFail();

            if ($isInstitution && $creator->role !== RoleType::Creator && $creator->role !== RoleType::Admin) {
                $isInternshipTarget = ($opp->user?->isCorporate() ?? false)
                    || str_contains(strtolower((string) $opp->sub_role_slug), 'magang')
                    || str_contains(strtolower((string) $opp->title), 'magang')
                    || str_contains(strtolower((string) $opp->title), 'intern')
                    || str_contains(strtolower((string) $opp->description), 'magang')
                    || str_contains(strtolower((string) $opp->description), 'intern');
                if (!$isInternshipTarget) {
                    abort(403, 'Akun institusi hanya dapat melamar pada program atau lowongan magang corporate.');
                }
            }

            if ($opp->status !== 'open') {
                abort(400, 'Peluang proyek ini sudah ditutup atau tidak menerima lamaran baru.');
            }

            // Guard: check if opportunity capacity / quota is already fulfilled
            $requirements = OpportunityRequirement::where('opportunity_id', $opportunityId)->get();
            $totalCapacity = 0;
            foreach ($requirements as $req) {
                $q = (int) $req->quantity;
                if ($q <= 0 && !empty($req->notes)) {
                    if (preg_match('/\((\d+)\s+kuota\)/i', $req->notes, $matches)) {
                        $q = (int) $matches[1];
                    }
                }
                $totalCapacity += max(0, $q);
            }
            if ($totalCapacity > 0) {
                $totalApproved = OpportunityApplication::where('opportunity_id', $opportunityId)
                    ->where('status', 'approved')
                    ->count();
                if ($totalApproved >= $totalCapacity) {
                    if ($opp->status !== 'closed') {
                        $opp->status = 'closed';
                        $opp->save();
                    }
                    abort(400, 'Pendaftaran untuk program ini telah ditutup karena kuota posisi telah terpenuhi.');
                }
            }

            // Guard: if event is already running or past start date, cannot apply
            $eventDate = $opp->event_start_date ?? $opp->event_date;
            $isEventStarted = false;
            if ($eventDate) {
                $parsedDate = \Carbon\Carbon::parse($eventDate)->startOfDay();
                if ($parsedDate->isPast() && !$parsedDate->isToday()) {
                    $isEventStarted = true;
                }
            }
            if ($opp->event_progress > 0 || $isEventStarted) {
                abort(400, 'Acara atau event untuk proyek ini sudah berjalan atau telah dimulai, pendaftaran lamaran sudah ditutup.');
            }

            if ($opp->posted_by === $creatorId) {
                abort(400, 'Anda tidak dapat melamar proyek yang Anda buat sendiri.');
            }

            $subRoleSlug = $data['sub_role_slug'] ?? $opp->sub_role_slug;
            $submittedDocuments = $data['submitted_documents'] ?? null;

            if ($isInstitution) {
                $studentName = '';
                if (is_array($submittedDocuments)) {
                    if (isset($submittedDocuments[0]) && is_array($submittedDocuments[0])) {
                        $studentName = trim((string) ($submittedDocuments[0]['participant_name'] ?? $submittedDocuments[0]['student_name'] ?? $submittedDocuments[0]['name'] ?? ''));
                    } else {
                        $studentName = trim((string) ($submittedDocuments['participant_name'] ?? $submittedDocuments['student_name'] ?? $submittedDocuments['name'] ?? ''));
                    }
                }

                if ($studentName !== '') {
                    $normalizedCandidate = mb_strtolower($studentName);
                    $existingApps = OpportunityApplication::where('opportunity_id', $opportunityId)
                        ->where('creator_id', $creatorId)
                        ->whereIn('status', ['pending', 'approved'])
                        ->get();

                    foreach ($existingApps as $existingApp) {
                        $docs = is_array($existingApp->submitted_documents) ? $existingApp->submitted_documents : [];
                        $existingName = '';
                        if (isset($docs[0]) && is_array($docs[0])) {
                            $existingName = trim((string) ($docs[0]['participant_name'] ?? $docs[0]['student_name'] ?? $docs[0]['name'] ?? ''));
                        } elseif (isset($docs['participant_name']) || isset($docs['student_name']) || isset($docs['name'])) {
                            $existingName = trim((string) ($docs['participant_name'] ?? $docs['student_name'] ?? $docs['name'] ?? ''));
                        }
                        if ($existingName !== '' && mb_strtolower($existingName) === $normalizedCandidate) {
                            abort(409, "Peserta {$studentName} sudah terdaftar pada program ini.");
                        }
                    }
                }
            } else {
                // Concurrency check: prevent duplicate application for non-institution applicants
                $existing = OpportunityApplication::where('opportunity_id', $opportunityId)
                    ->where('creator_id', $creatorId)
                    ->where('sub_role_slug', $subRoleSlug)
                    ->first();

                if ($existing) {
                    if ($existing->status === 'pending') {
                        abort(409, 'Anda sudah mengajukan lamaran untuk keahlian ini dan sedang menunggu persetujuan.');
                    } elseif ($existing->status === 'approved') {
                        abort(409, 'Lamaran Anda sudah disetujui untuk proyek ini.');
                    }
                }
            }

            // Pelamar kerja non-institusi WAJIB mengisi pengajuan tarif / nego fee
            $bidPrice = isset($data['bid_price']) ? (float) $data['bid_price'] : 0.0;
            if (!$isInstitution && $bidPrice <= 0) {
                abort(422, 'Pengajuan penawaran tarif / nego fee wajib diisi oleh pelamar kerja.');
            }

            // Dapatkan skema pembayaran dari requirement jika ada
            $req = OpportunityRequirement::where('opportunity_id', $opportunityId)
                ->where('sub_role_slug', $subRoleSlug)
                ->first();

            $paymentScheme = $req?->payment_scheme ?? 'full_at_end';
            $paymentTerms = $req?->payment_terms;

            $application = OpportunityApplication::create([
                'opportunity_id' => $opportunityId,
                'creator_id' => $creatorId,
                'sub_role_slug' => $subRoleSlug,
                'pitch_message' => $data['pitch_message'],
                'questions_notes' => $data['questions_notes'] ?? null,
                'submitted_documents' => $submittedDocuments,
                'bid_price' => $bidPrice,
                'payment_scheme' => $paymentScheme,
                'payment_terms' => $paymentTerms,
                'paid_amount' => 0.00,
                'payment_status' => 'unpaid',
                'worker_progress' => 0,
                'worker_status' => 'assigned',
                'status' => 'pending',
            ]);

            // Notify project owner
            $this->notificationRepo->create([
                'user_id' => $opp->posted_by,
                'title' => 'Lamaran Proyek Baru',
                'message' => $creator->name . ' telah mengajukan diri untuk proyek: "' . $opp->title . '" sebagai ' . ucwords(str_replace('_', ' ', $subRoleSlug)) . '.',
                'type' => 'project',
                'data' => [
                    'opportunity_id' => $opp->id,
                    'application_id' => $application->id,
                ],
                'is_read' => false,
                'created_at' => now(),
            ]);

            return [
                'id' => $application->id,
                'opportunity_id' => $application->opportunity_id,
                'creator_id' => $application->creator_id,
                'sub_role_slug' => $application->sub_role_slug,
                'pitch_message' => $application->pitch_message,
                'questions_notes' => $application->questions_notes,
                'submitted_documents' => $application->submitted_documents ?? [],
                'bid_price' => $application->bid_price,
                'status' => $application->status,
                'created_at' => $application->created_at?->toIso8601String(),
            ];
        });
    }

    public function getOpportunityApplications(string $opportunityId, string $userId): array
    {
        $opp = Opportunity::where('id', $opportunityId)->firstOrFail();
        $user = User::where('id', $userId)->firstOrFail();

        $isOwnerOrStaff = ($opp->posted_by === $userId || $user->role === RoleType::Admin || $user->role === RoleType::Marketing);

        $query = OpportunityApplication::with([
            'creator.activeSubscription'
        ])->where('opportunity_id', $opportunityId);

        // Jika bukan pemilik proyek atau staf, pelamar hanya dapat melihat lamarannya sendiri
        if (!$isOwnerOrStaff) {
            $hasApplication = OpportunityApplication::where('opportunity_id', $opportunityId)
                ->where('creator_id', $userId)
                ->exists();

            if (!$hasApplication) {
                abort(403, 'Akses ditolak. Anda bukan pemilik proyek atau pelamar pada proyek ini.');
            }

            $query->where('creator_id', $userId);
        }

        $applications = $query->orderBy('created_at', 'desc')->get();
        $opp = Opportunity::where('id', $opportunityId)->first();
        $approvedCount = max(1, $applications->where('status', 'approved')->count());

        return $applications->map(function ($app) use ($opp, $approvedCount) {
            $clientSig = $app->client_signature ?? $opp?->client_signature;
            $clientSignedAt = $app->client_signed_at ?? $opp?->client_signed_at;
            $creatorSig = $app->creator_signature;
            $creatorSignedAt = $app->creator_signed_at;
            $contractNumber = $app->contract_number ?: self::generateContractNumber($app->opportunity_id, $app->id, $app->reviewed_at ?? $app->created_at);
            $agreedPrice = self::resolveIndividualAgreedPrice($opp, $app, $approvedCount);
            $resolvedTerms = !empty($app->dynamic_terms)
                ? $app->dynamic_terms
                : ($opp ? self::buildIndividualDefaultTerms($opp, $app, $agreedPrice) : []);

            return [
                'id' => $app->id,
                'opportunity_id' => $app->opportunity_id,
                'creator_id' => $app->creator_id,
                'creator' => $app->creator ? [
                    'id' => $app->creator->id,
                    'name' => $app->creator->name,
                    'username' => $app->creator->username,
                    'avatar_url' => $app->creator->avatar_url,
                    'sub_role' => is_string($app->creator->sub_role) ? $app->creator->sub_role : $app->creator->sub_role?->value,
                    'rating' => round($app->creator->rating ?? 5.0, 1),
                    'subscription_tier' => $app->creator->subscription_tier ?? 'free',
                    'is_verified' => (bool) ($app->creator->is_verified ?? false),
                    'completed_projects_count' => (int) ($app->creator->completed_projects_count ?? 0),
                ] : null,
                'sub_role_slug' => $app->sub_role_slug,
                'pitch_message' => $app->pitch_message,
                'questions_notes' => $app->questions_notes,
                'submitted_documents' => $app->submitted_documents ?? [],
                'bid_price' => $app->bid_price ? (float) $app->bid_price : null,
                'counter_offer_price' => $app->counter_offer_price ? (float) $app->counter_offer_price : null,
                'agreed_price' => $agreedPrice,
                'counter_offer_notes' => $app->counter_offer_notes,
                'counter_offer_status' => $app->counter_offer_status,
                'counter_offer_by' => $app->counter_offer_by ?? 'client',
                'payment_scheme' => $app->payment_scheme ?? 'full_at_end',
                'payment_terms' => $app->payment_terms ?? [],
                'paid_amount' => (float) ($app->paid_amount ?? 0),
                'payment_status' => $app->payment_status ?? 'unpaid',
                'worker_progress' => (int) ($app->worker_progress ?? 0),
                'worker_status' => $app->worker_status ?? 'assigned',
                'revision_notes' => $app->revision_notes ?? null,
                'submitted_deliverables' => $app->submitted_deliverables ?? [],
                'grace_period_deadline' => $app->grace_period_deadline?->toIso8601String(),
                'auto_released_at' => $app->auto_released_at?->toIso8601String(),
                'contract_number' => $contractNumber,
                'client_signature' => $clientSig,
                'client_signed_at' => $clientSignedAt?->toIso8601String(),
                'creator_signature' => $creatorSig,
                'creator_signed_at' => $creatorSignedAt?->toIso8601String(),
                'is_contract_final' => !empty($clientSig) && !empty($clientSignedAt) && !empty($creatorSig) && !empty($creatorSignedAt),
                'dynamic_terms' => $resolvedTerms,
                'status' => $app->status,
                'rejection_reason' => $app->rejection_reason,
                'reviewed_at' => $app->reviewed_at?->toIso8601String(),
                'created_at' => $app->created_at?->toIso8601String(),
            ];
        })->toArray();
    }

    /**
     * Format nomor kontrak resmi (CV Transforma Alam Kreasi — Aplikasi Kreavana).
     */
    public static function generateContractNumber(string $oppId, string $appId, $date = null): string
    {
        $dateStr = $date ? \Carbon\Carbon::parse($date)->format('Ymd') : date('Ymd');
        return 'KVN/TAK/CTR/' . $dateStr . '/' . strtoupper(substr($oppId, 0, 4)) . '-' . strtoupper(substr($appId, 0, 4));
    }

    /**
     * Hitung nominal kesepakatan kontrak individu per pelamar (fallback proporsional dari escrow/budget jika belum ada bid_price).
     */
    public static function resolveIndividualAgreedPrice($opp, $app, int $approvedCount = 1): float
    {
        $explicit = (float) ($app->counter_offer_price ?: $app->bid_price ?: 0);
        if ($explicit > 0) {
            return $explicit;
        }
        $divider = max(1, $approvedCount);
        $escrow = (float) ($opp?->escrow_amount ?? 0);
        if ($escrow > 0) {
            return round($escrow / $divider, 0);
        }
        if (!empty($opp?->budget_range) && preg_match('/(\d[\d\.\,]*)/', (string) $opp->budget_range, $matches)) {
            $cleaned = (float) str_replace(['.', ','], '', $matches[1]);
            if ($cleaned > 0) {
                return round($cleaned / $divider, 0);
            }
        }
        return 0.0;
    }

    /**
     * Susun klausul dinamis default yang berbeda untuk setiap individu & posisi/sub-role.
     */
    public static function buildIndividualDefaultTerms($opp, $app, float $agreedPrice): array
    {
        $creatorName = $app->creator?->name ?? 'Pekerja Kreatif';
        $rawRole = $app->sub_role_slug
            ?: (is_string($app->creator?->sub_role) ? $app->creator?->sub_role : ($app->creator?->sub_role?->value ?? ($opp->sub_role_slug ?? 'Kreator')));
        $roleLabels = [
            'videographer' => 'Videografer',
            'videografi' => 'Videografer',
            'photographer' => 'Fotografer',
            'fotografi' => 'Fotografer',
            'editor' => 'Video Editor',
            'animator' => 'Animator & Motion Artist',
            'desain_grafis' => 'Desainer Grafis',
            'designer' => 'Desainer Kreatif',
            'illustrator' => 'Ilustrator',
            'mc' => 'Master of Ceremony (MC)',
            'singer' => 'Penyanyi / Vokalis',
            'tukang_kendang' => 'Musisi / Pengrawit Kendang',
            'makeup_artist' => 'Make Up Artist (MUA)',
            'model' => 'Model & Talent',
            'drone' => 'Pilot Drone / Aerial',
            'event_organizer' => 'Event Organizer (EO)',
            'wedding_organizer' => 'Wedding Organizer (WO)',
        ];
        $slugKey = strtolower(trim((string) $rawRole));
        $roleLabel = $roleLabels[$slugKey] ?? ucwords(str_replace('_', ' ', $slugKey));
        $oppTitle = $opp->title ?? 'Proyek Kreavana';
        $formattedPrice = 'Rp ' . number_format(max(0, $agreedPrice), 0, ',', '.');
        $schemeLabel = ($app->payment_scheme ?? 'full_at_end') === 'termin'
            ? 'Bertahap (Termin Progress)'
            : 'Penuh di Akhir Acara (100% Lunas via Escrow)';

        $terms = [
            "Lingkup Tugas Individu: Pihak Kedua ({$creatorName}) bertugas khusus sebagai {$roleLabel} pada proyek '{$oppTitle}' dan bertanggung jawab penuh atas target kerja posisi {$roleLabel} sesuai jadwal penyelenggara.",
        ];

        if (in_array($slugKey, ['videographer', 'videografi', 'photographer', 'fotografi', 'drone'])) {
            $terms[] = "Spesifikasi Teknis & Perangkat ({$roleLabel}): Penyediaan unit kamera utama, lensa, memori, baterai cadangan, serta penyerahan file mentah (RAW/Footage) dan hasil akhir kurasi untuk posisi {$roleLabel} ({$creatorName}) disepakati bersama Penyelenggara.";
        } elseif (in_array($slugKey, ['editor', 'animator', 'desain_grafis', 'designer', 'illustrator'])) {
            $terms[] = "Spesifikasi Produksi & Revisi ({$roleLabel}): Pihak Kedua ({$creatorName}) wajib menyerahkan preview draf tepat waktu, mengakomodasi revisi sesuai kesepakatan kerja, dan menyerahkan master file resolusi penuh.";
        } elseif (in_array($slugKey, ['mc', 'singer', 'tukang_kendang', 'model'])) {
            $terms[] = "Kesiapan Panggung & Gladi Bersih ({$roleLabel}): Pihak Kedua ({$creatorName}) wajib mengikuti sesi briefing/gladi bersih (soundcheck), mematuhi ketentuan kostum/wardrobe acara, dan tampil tepat waktu sesuai rundown.";
        } elseif ($slugKey === 'makeup_artist') {
            $terms[] = "Standar Perlengkapan & Higienitas ({$roleLabel}): Pihak Kedua ({$creatorName}) wajib menyediakan perlengkapan kosmetik berstandar profesional yang higienis dan hadir sesuai jadwal persiapan talent.";
        } else {
            $terms[] = "Fasilitas & Koordinasi Teknis ({$roleLabel}): Penyediaan peralatan kerja utama, akses lokasi, konsumsi, dan koordinasi teknis di lapangan untuk {$creatorName} ({$roleLabel}) disepakati tertulis bersama Penyelenggara.";
        }

        $terms[] = "Honorarium Individu & Proteksi Escrow: Nilai kontrak individu untuk {$creatorName} ({$roleLabel}) disepakati sebesar {$formattedPrice} dengan skema pembayaran {$schemeLabel}, dijamin melalui Rekening Bersama CV Transforma Alam Kreasi (Aplikasi Kreavana).";

        if (!empty($app->counter_offer_notes)) {
            $terms[] = "Catatan Kesepakatan Negosiasi ({$creatorName}): " . trim((string) $app->counter_offer_notes);
        } elseif (!empty($app->questions_notes)) {
            $terms[] = "Catatan Teknis & Fasilitas Pelamar ({$creatorName}): " . trim((string) $app->questions_notes);
        } else {
            $terms[] = "Pengesahan 2 Arah & Finalitas: Kontrak individu ini mengikat secara sah dan terkunci permanen (Kontrak Fix) setelah disetujui serta ditandatangani secara elektronik oleh Pembuat Acara dan {$creatorName}.";
        }

        return $terms;
    }

    /**
     * Cek apakah budget bernilai Rp 100 Juta ke atas (membutuhkan Tanda Tangan Basah)
     */
    public static function isBudgetAbove100Jt(?string $budgetRange, float $calculatedAmount = 0.0): bool
    {
        if ($calculatedAmount >= 100000000) {
            return true;
        }

        if (empty($budgetRange)) {
            return false;
        }

        $lower = strtolower($budgetRange);
        if (str_contains($lower, '100.000.000') || str_contains($lower, '100jt') || str_contains($lower, '100 jt')) {
            return true;
        }

        if (preg_match('/100[\s\.\,]*000[\s\.\,]*000/i', $budgetRange)) {
            return true;
        }

        return false;
    }

    /**
     * Tanda tangani kontrak perjanjian acara secara elektronik dinamis (3 Pihak: Klien, Kreator, Admin).
     * Mendukung skema 1 orang = 1 kontrak digital individu (per application_id maupun sign_all).
     */
    public function signContract(string $opportunityId, string $userId, array $data): array
    {
        return DB::transaction(function () use ($opportunityId, $userId, $data) {
            $opp = Opportunity::where('id', $opportunityId)->lockForUpdate()->firstOrFail();
            $user = User::where('id', $userId)->firstOrFail();

            $isClient = ($opp->posted_by === $userId || $user->role === RoleType::Admin);
            $requestedAppId = !empty($data['application_id']) ? (string) $data['application_id'] : null;
            $signAll = filter_var($data['sign_all'] ?? false, FILTER_VALIDATE_BOOLEAN);

            // Cek apakah user adalah pekerja/kreator yang disetujui untuk acara ini (Pihak Kedua)
            $creatorAppQuery = OpportunityApplication::where('opportunity_id', $opp->id)
                ->where('creator_id', $userId)
                ->where('status', 'approved');
            if ($requestedAppId && !$isClient) {
                $creatorAppQuery->where('id', $requestedAppId);
            }
            $creatorApp = $creatorAppQuery->first();

            if (!$isClient && !$creatorApp) {
                abort(403, 'Hanya pihak bersepakat (pembuat acara atau pekerja kreatif yang disetujui) yang dapat menandatangani dokumen ini.');
            }

            $signature = $data['signature'] ?? $data['electronic_signature'] ?? null;
            if (empty($signature)) {
                abort(422, 'Data tanda tangan elektronik dynamic tidak boleh kosong.');
            }

            $parsedTerms = null;
            if (!empty($data['dynamic_terms'])) {
                $rawTerms = $data['dynamic_terms'];
                if (is_string($rawTerms)) {
                    $decoded = json_decode($rawTerms, true);
                    $rawTerms = is_array($decoded) ? $decoded : array_filter(array_map('trim', explode("\n", $rawTerms)));
                }
                if (is_array($rawTerms) && !empty($rawTerms)) {
                    $parsedTerms = array_values(array_filter(array_map('trim', $rawTerms)));
                }
            }

            // Auto-input Pihak Ketiga: CV Transforma Alam Kreasi — Aplikasi Kreavana
            $adminName = SystemSetting::get('admin_contract_signer_name', 'CV Transforma Alam Kreasi — Otoritas Legal & Escrow Aplikasi Kreavana');
            $adminSignatureUrl = SystemSetting::get('admin_contract_signature_image', '/assets/images/kreavana_official_signature.png');
            $opp->admin_name = $adminName;
            $opp->admin_signature_url = $adminSignatureUrl;
            $opp->admin_signed_at = $opp->admin_signed_at ?: now();

            if ($isClient) {
                $opp->signature_type = 'dynamic_electronic';
                if ($parsedTerms && (!$requestedAppId || $signAll)) {
                    $opp->dynamic_terms = $parsedTerms;
                }

                $targetAppsQuery = OpportunityApplication::where('opportunity_id', $opp->id)
                    ->where('status', 'approved');
                if ($requestedAppId && !$signAll) {
                    $targetAppsQuery->where('id', $requestedAppId);
                }
                $targetApps = $targetAppsQuery->get();

                foreach ($targetApps as $app) {
                    $alreadyFinal = !empty($app->client_signature) && !empty($app->client_signed_at)
                        && !empty($app->creator_signature) && !empty($app->creator_signed_at);

                    if (empty($app->contract_number)) {
                        $app->contract_number = self::generateContractNumber($opp->id, $app->id, $app->reviewed_at ?? $app->created_at);
                    }
                    $app->client_signature = (string) $signature;
                    $app->client_signed_at = $app->client_signed_at ?: now();
                    if (!$alreadyFinal) {
                        if ($parsedTerms) {
                            $app->dynamic_terms = $parsedTerms;
                        } elseif (empty($app->dynamic_terms) && !empty($opp->dynamic_terms)) {
                            $app->dynamic_terms = $opp->dynamic_terms;
                        }
                    }
                    $app->save();

                    JobContract::where('opportunity_id', $opp->id)
                        ->where('creator_id', $app->creator_id)
                        ->update([
                            'contract_number' => $app->contract_number,
                            'client_signature' => (string) $signature,
                            'client_signed_at' => $app->client_signed_at,
                            'client_approved' => true,
                            'dynamic_terms' => !empty($app->dynamic_terms) ? $app->dynamic_terms : $opp->dynamic_terms,
                            'admin_name' => $adminName,
                            'admin_signature_url' => $adminSignatureUrl,
                            'admin_signed_at' => $opp->admin_signed_at,
                        ]);

                    $this->notificationRepo->create([
                        'user_id' => $app->creator_id,
                        'title' => 'Penyelenggara Telah Menandatangani Kontrak Anda',
                        'message' => "Penyelenggara acara telah menandatangani Dokumen Kontrak Digital individu ({$app->contract_number}) untuk proyek '{$opp->title}'. Silakan tinjau dan bubuhi tanda tangan Anda.",
                        'type' => 'project',
                        'data' => [
                            'opportunity_id' => $opp->id,
                            'application_id' => $app->id,
                        ],
                        'is_read' => false,
                        'created_at' => now(),
                    ]);
                }

                // Jika menandatangani semua atau seluruh lamaran approved sudah memiliki client_signature, simpan di level opportunity juga
                $allApproved = OpportunityApplication::where('opportunity_id', $opp->id)->where('status', 'approved')->get();
                $allClientSigned = $allApproved->isEmpty() || $allApproved->every(fn ($a) => !empty($a->client_signature) && !empty($a->client_signed_at));
                if (!$requestedAppId || $signAll || $allClientSigned) {
                    $opp->client_signature = (string) $signature;
                    $opp->client_signed_at = $opp->client_signed_at ?: now();
                }
            }

            if ($creatorApp) {
                $alreadyFinal = (!empty($creatorApp->client_signature) || !empty($opp->client_signature))
                    && (!empty($creatorApp->client_signed_at) || !empty($opp->client_signed_at))
                    && !empty($creatorApp->creator_signature) && !empty($creatorApp->creator_signed_at);

                if (empty($creatorApp->contract_number)) {
                    $creatorApp->contract_number = self::generateContractNumber($opp->id, $creatorApp->id, $creatorApp->reviewed_at ?? $creatorApp->created_at);
                }
                if (empty($creatorApp->client_signature) && !empty($opp->client_signature)) {
                    $creatorApp->client_signature = $opp->client_signature;
                    $creatorApp->client_signed_at = $opp->client_signed_at ?: now();
                }
                $creatorApp->creator_signature = (string) $signature;
                $creatorApp->creator_signed_at = $creatorApp->creator_signed_at ?: now();
                if (!$alreadyFinal) {
                    if ($parsedTerms) {
                        $creatorApp->dynamic_terms = $parsedTerms;
                    } elseif (empty($creatorApp->dynamic_terms) && !empty($opp->dynamic_terms)) {
                        $creatorApp->dynamic_terms = $opp->dynamic_terms;
                    }
                }
                $creatorApp->save();

                // Sinkronkan ke job_contracts milik pekerja ini
                JobContract::where('opportunity_id', $opp->id)
                    ->where('creator_id', $userId)
                    ->update([
                        'contract_number' => $creatorApp->contract_number,
                        'creator_signature' => (string) $signature,
                        'creator_signed_at' => $creatorApp->creator_signed_at,
                        'creator_approved' => true,
                        'dynamic_terms' => !empty($creatorApp->dynamic_terms) ? $creatorApp->dynamic_terms : $opp->dynamic_terms,
                    ]);

                // Beritahu pembuat event bahwa kreator telah menandatangani kontrak
                $this->notificationRepo->create([
                    'user_id' => $opp->posted_by,
                    'title' => 'Kontrak Digital Disetujui Pekerja',
                    'message' => "Pekerja kreatif ({$user->name}) telah menandatangani Dokumen Kontrak Digital ({$creatorApp->contract_number}) untuk proyek '{$opp->title}'.",
                    'type' => 'project',
                    'data' => [
                        'opportunity_id' => $opp->id,
                        'application_id' => $creatorApp->id,
                        'creator_id' => $userId,
                    ],
                    'is_read' => false,
                    'created_at' => now(),
                ]);
            }

            $opp->save();

            return $this->formatOpportunity($opp->fresh(['approvedApplications.creator', 'user']), true);
        });
    }

    /**
     * Perbarui butir-butir ketentuan khusus / klausul dinamis kontrak oleh Klien atau Kreator.
     * Jika kontrak sudah disetujui dan ditandatangani kedua belah pihak (Final / Kontrak Fix), tidak dapat diedit lagi.
     */
    public function updateDynamicTerms(string $opportunityId, string $userId, array $dynamicTerms, ?string $applicationId = null): array
    {
        return DB::transaction(function () use ($opportunityId, $userId, $dynamicTerms, $applicationId) {
            $opp = Opportunity::where('id', $opportunityId)->lockForUpdate()->firstOrFail();
            $user = User::where('id', $userId)->firstOrFail();

            if ($opp->status !== 'open') {
                abort(422, 'Kontrak telah terkunci (Final / Kontrak Fix) karena acara telah berjalan atau selesai, sehingga tidak dapat diubah lagi.');
            }

            $isClient = ($opp->posted_by === $userId || $user->role === RoleType::Admin);
            $creatorApp = OpportunityApplication::where('opportunity_id', $opp->id)
                ->where('creator_id', $userId)
                ->where('status', 'approved')
                ->first();

            if (!$isClient && !$creatorApp) {
                abort(403, 'Hanya pihak bersepakat yang dapat memperbarui ketentuan khusus kontrak.');
            }

            $cleanedTerms = array_values(array_filter(array_map('trim', $dynamicTerms)));
            if (empty($cleanedTerms)) {
                abort(422, 'Ketentuan khusus tidak boleh kosong.');
            }

            $targetApp = null;
            if (!empty($applicationId)) {
                $targetApp = OpportunityApplication::where('opportunity_id', $opp->id)
                    ->where('id', $applicationId)
                    ->where('status', 'approved')
                    ->firstOrFail();
                if (!$isClient && $targetApp->creator_id !== $userId) {
                    abort(403, 'Anda hanya dapat memperbarui klausul pada kontrak milik Anda sendiri.');
                }
            } elseif (!$isClient && $creatorApp) {
                $targetApp = $creatorApp;
            }

            if ($targetApp) {
                $hasClientSig = !empty($targetApp->client_signature) || !empty($opp->client_signature);
                $hasClientSignedAt = !empty($targetApp->client_signed_at) || !empty($opp->client_signed_at);
                $hasCreatorSig = !empty($targetApp->creator_signature) && !empty($targetApp->creator_signed_at);

                if ($hasClientSig && $hasClientSignedAt && $hasCreatorSig) {
                    abort(422, 'Kontrak ini telah disetujui dan ditandatangani oleh kedua belah pihak (Kontrak Fix & Final) sehingga tidak dapat diedit lagi.');
                }

                // Jika salah satu pihak mengubah klausul sebelum kontrak final, reset tanda tangan sementara pada kontrak ini
                // agar kedua belah pihak wajib menyetujui & menandatangani versi klausul yang sama (Mutual Approval).
                $targetApp->dynamic_terms = $cleanedTerms;
                $targetApp->client_signature = null;
                $targetApp->client_signed_at = null;
                $targetApp->creator_signature = null;
                $targetApp->creator_signed_at = null;
                $targetApp->save();

                JobContract::where('opportunity_id', $opp->id)
                    ->where('creator_id', $targetApp->creator_id)
                    ->update([
                        'dynamic_terms' => $cleanedTerms,
                        'client_signature' => null,
                        'client_signed_at' => null,
                        'creator_signature' => null,
                        'creator_signed_at' => null,
                        'creator_approved' => false,
                    ]);
            } else {
                $approvedApps = OpportunityApplication::where('opportunity_id', $opp->id)
                    ->where('status', 'approved')
                    ->get();

                $editableApps = $approvedApps->filter(function ($app) use ($opp) {
                    $hasClientSig = !empty($app->client_signature) || !empty($opp->client_signature);
                    $hasClientSignedAt = !empty($app->client_signed_at) || !empty($opp->client_signed_at);
                    $hasCreatorSig = !empty($app->creator_signature) && !empty($app->creator_signed_at);
                    return !($hasClientSig && $hasClientSignedAt && $hasCreatorSig);
                });

                if ($approvedApps->isNotEmpty() && $editableApps->isEmpty()) {
                    abort(422, 'Seluruh kontrak telah disetujui dan ditandatangani kedua belah pihak (Kontrak Fix & Final) sehingga tidak dapat diedit lagi.');
                }

                $opp->dynamic_terms = $cleanedTerms;
                $opp->save();

                foreach ($editableApps as $app) {
                    $app->dynamic_terms = $cleanedTerms;
                    $app->save();

                    JobContract::where('opportunity_id', $opp->id)
                        ->where('creator_id', $app->creator_id)
                        ->update(['dynamic_terms' => $cleanedTerms]);
                }
            }

            return $this->formatOpportunity($opp->fresh(['approvedApplications.creator', 'user']), true);
        });
    }

    public function startEvent(string $opportunityId, string $userId, array $data = []): array
    {
        return DB::transaction(function () use ($opportunityId, $userId, $data) {
            $opp = Opportunity::where('id', $opportunityId)->lockForUpdate()->firstOrFail();
            $user = User::where('id', $userId)->lockForUpdate()->firstOrFail();

            if ($opp->posted_by !== $userId && $user->role !== RoleType::Admin) {
                abort(403, 'Hanya pembuat proyek yang dapat memulai acara.');
            }

            if ($opp->status === 'in_progress') {
                abort(400, 'Acara sudah dimulai dan sedang berlangsung.');
            }

            // Must have at least 1 approved creator to start event
            $approvedApps = OpportunityApplication::where('opportunity_id', $opp->id)
                ->where('status', 'approved')
                ->with('creator')
                ->get();

            if ($approvedApps->isEmpty()) {
                abort(422, 'Tidak dapat memulai acara: Belum ada kreator yang disetujui (minimal 1 kreator).');
            }

            // Hitung total nilai kontrak dari kreator yang disetujui
            $totalEscrow = 0.0;
            foreach ($approvedApps as $app) {
                $price = (float) ($app->counter_offer_price ?: $app->bid_price ?: 0);
                $totalEscrow += $price;
            }

            // Fallback parse dari budget range jika tidak ada penawaran nominal khusus
            if ($totalEscrow <= 0 && !empty($opp->budget_range)) {
                if (preg_match('/(\d[\d\.\,]*)/', $opp->budget_range, $matches)) {
                    $cleaned = (float) str_replace(['.', ','], '', $matches[1]);
                    if ($cleaned > 0) {
                        $totalEscrow = $cleaned;
                    }
                }
            }

            // Revisi 2: Cek Tanda Tangan (Budget >= 100jt -> Tanda Tangan Basah, < 100jt -> Tanda Tangan Elektronik Dynamic)
            $isWetSignatureRequired = self::isBudgetAbove100Jt($opp->budget_range, $totalEscrow);

            if ($isWetSignatureRequired) {
                $isAdmin = ($user->role === RoleType::Admin || $user->role === RoleType::Marketing || !empty($data['is_admin_override']));
                $hasWetSignature = !empty($opp->wet_signature_document_url) || !empty($opp->wet_signature_verified_at) || in_array($opp->meeting_status, ['verified_completed', 'verified_paid']);
                if (!$hasWetSignature) {
                    abort(422, 'Budget acara mencapai Rp 100 Juta ke atas. Sesuai regulasi hukum dan standar keamanan, wajib menandatangani dokumen perjanjian fisik (Tanda Tangan Basah) dan diverifikasi oleh Admin sebelum acara dapat dimulai.');
                }
                if (!$isAdmin && empty($opp->admin_started_at)) {
                    abort(422, 'Acara dengan anggaran >= Rp 100 Juta yang telah diverifikasi dokumen fisik basahnya akan dimulai secara resmi oleh Admin Kreavana.');
                }
                $opp->signature_type = 'wet_signature';
                if (empty($opp->admin_started_at)) {
                    $opp->admin_started_at = now();
                }
            } else {
                // Budget < 100jt: Wajib tanda tangan elektronik dynamic (Tripartite 3 Pihak — 1 Orang 1 Kontrak)
                $dynamicSignature = $data['signature'] ?? $data['electronic_signature'] ?? $opp->client_signature ?? null;

                $unsignedClientApps = $approvedApps->filter(function ($app) use ($dynamicSignature, $opp) {
                    $cSig = $app->client_signature ?? $dynamicSignature ?? $opp->client_signature;
                    $cSignedAt = $app->client_signed_at ?? $opp->client_signed_at;
                    return empty($cSig) && empty($cSignedAt);
                });

                if ($unsignedClientApps->isNotEmpty()) {
                    $creatorNames = $unsignedClientApps->map(fn($a) => $a->creator->name ?? 'Kreator')->implode(', ');
                    abort(422, "Tidak dapat memulai acara: Dokumen kontrak digital individu belum ditandatangani oleh Pihak Pertama (Penyelenggara) untuk: {$creatorNames}. Silakan tandatangani seluruh kontrak digital terlebih dahulu.");
                }

                // Cek apakah seluruh kreator yang disetujui telah menyetujui & menandatangani kontrak digital masing-masing
                $unsignedCreators = $approvedApps->filter(function ($app) {
                    return empty($app->creator_signature) || empty($app->creator_signed_at);
                });

                if ($unsignedCreators->isNotEmpty()) {
                    $creatorNames = $unsignedCreators->map(fn($a) => $a->creator->name ?? 'Kreator')->implode(', ');
                    abort(422, "Tidak dapat memulai acara: Dokumen kontrak digital wajib disetujui dan ditandatangani oleh kedua belah pihak sebelum acara dimulai. Menunggu pengesahan/tanda tangan digital dari pekerja kreatif: {$creatorNames}.");
                }

                $opp->signature_type = 'dynamic_electronic';
                if (!empty($dynamicSignature)) {
                    $opp->client_signature = (string) $dynamicSignature;
                } elseif (empty($opp->client_signature)) {
                    $opp->client_signature = $approvedApps->first()?->client_signature;
                }
                if (empty($opp->client_signed_at)) {
                    $opp->client_signed_at = now();
                }

                // Ketentuan Khusus Dinamis (Dynamic Terms)
                $rawDynamicTerms = $data['dynamic_terms'] ?? $opp->dynamic_terms ?? [];
                if (is_string($rawDynamicTerms)) {
                    $decoded = json_decode($rawDynamicTerms, true);
                    $rawDynamicTerms = is_array($decoded) ? $decoded : array_filter(array_map('trim', explode("\n", $rawDynamicTerms)));
                }
                if (empty($rawDynamicTerms) || !is_array($rawDynamicTerms)) {
                    $rawDynamicTerms = [
                        'Penyelenggara (Pihak Pertama) wajib menyediakan akses venue, rundown, dan koordinasi teknis pelaksanaan acara.',
                        'Penyediaan fasilitas dan alat kerja utama (seperti kamera, lensa, mikrofon, atau perlengkapan pendukung) disepakati tertulis antara pembuat event dan pekerja.',
                        'Pekerja / Kreator (Pihak Kedua) berkewajiban hadir tepat waktu serta menyerahkan hasil pekerjaan sesuai standar profesional yang disepakati.',
                        'Honorarium kerja diamankan 100% pada sistem Escrow Rekening Bersama Kreavana (Pihak Ketiga) dan hanya dicairkan setelah hasil pekerjaan disetujui.',
                    ];
                }
                $opp->dynamic_terms = $rawDynamicTerms;

                // Auto-input Pihak Ketiga: CV Transforma Alam Kreasi — Aplikasi Kreavana
                $adminName = SystemSetting::get('admin_contract_signer_name', 'CV Transforma Alam Kreasi — Otoritas Legal & Escrow Aplikasi Kreavana');
                $adminSignatureUrl = SystemSetting::get('admin_contract_signature_image', '/assets/images/kreavana_official_signature.png');
                $opp->admin_name = $adminName;
                $opp->admin_signature_url = $adminSignatureUrl;
                $opp->admin_signed_at = now();
            }

            // Revisi 3: Saldo harus mencukupi dan ditahan menjadi Escrow
            if ($user->balance < $totalEscrow) {
                abort(422, 'Saldo dompet Anda tidak mencukupi untuk memulai acara. Saldo saat ini: Rp ' . number_format($user->balance, 0, ',', '.') . ', Saldo Escrow yang dibutuhkan: Rp ' . number_format($totalEscrow, 0, ',', '.') . '. Silakan isi saldo (top up) terlebih dahulu.');
            }

            if ($totalEscrow > 0) {
                $user->balance -= $totalEscrow;
                $user->save();

                $refNumber = 'ESCROW-' . strtoupper(Str::random(8)) . '-' . time();
                $walletTx = WalletTransaction::create([
                    'user_id' => $user->id,
                    'type' => 'escrow_hold',
                    'amount' => $totalEscrow,
                    'fee' => 0.00,
                    'payment_method' => 'wallet',
                    'payment_provider' => 'Kreavana Escrow',
                    'status' => 'completed',
                    'reference_number' => $refNumber,
                    'description' => "Penahanan saldo escrow untuk acara '{$opp->title}' (" . $approvedApps->count() . " kreator disetujui).",
                ]);
                $walletTx->ledger_hash = $walletTx->generateLedgerHash();
                $walletTx->save();
            }

            $opp->escrow_status = 'held';
            $opp->escrow_amount = $totalEscrow;
            $opp->status = 'in_progress';
            if ($opp->event_progress == 0) {
                $opp->event_progress = 30; // Start at 30% (Persiapan Selesai, Acara Dimulai)
            }
            $opp->save();

            // Pihak Ketiga: Data Admin Kreavana untuk auto-input ke kontrak
            $adminName = $opp->admin_name ?: SystemSetting::get('admin_contract_signer_name', 'Tim Legal & Penjamin Escrow Kreavana');
            $adminSignatureUrl = $opp->admin_signature_url ?: SystemSetting::get('admin_contract_signature_image', '/assets/images/kreavana_official_signature.png');

            // Tentukan masa tenggang pembayaran: 1 bulan setelah tanggal acara
            $eventEnd = $opp->event_end_date ?? $opp->event_date ?? now();
            $graceDeadline = \Carbon\Carbon::parse($eventEnd)->addMonth();

            // Sinkronisasi pembuatan / update JobContract resmi 3 Pihak untuk setiap kreator yang disetujui
            foreach ($approvedApps as $app) {
                $appPrice = (float) ($app->counter_offer_price ?: $app->bid_price ?: ($totalEscrow / max(1, $approvedApps->count())));

                // Bangun skema termin / pembayaran per-pekerja
                $scheme = $app->payment_scheme ?: 'full_at_end';
                $terms = $app->payment_terms;
                if ($scheme === 'term') {
                    if (empty($terms) || !is_array($terms)) {
                        $terms = [
                            ['title' => 'Termin 1 (DP & Persiapan)', 'percentage' => 30, 'amount' => round($appPrice * 0.30, 2), 'status' => 'unpaid', 'paid_at' => null],
                            ['title' => 'Termin 2 (Hari H Acara / Progres)', 'percentage' => 40, 'amount' => round($appPrice * 0.40, 2), 'status' => 'unpaid', 'paid_at' => null],
                            ['title' => 'Termin 3 (Pelunasan & Serah Terima)', 'percentage' => 30, 'amount' => round($appPrice * 0.30, 2), 'status' => 'unpaid', 'paid_at' => null],
                        ];
                    }
                } else {
                    $terms = [
                        ['title' => 'Pembayaran Sekaligus (Pelunasan Akhir)', 'percentage' => 100, 'amount' => $appPrice, 'status' => 'unpaid', 'paid_at' => null],
                    ];
                }

                $app->payment_scheme = $scheme;
                $app->payment_terms = $terms;
                $app->paid_amount = $app->paid_amount ?: 0.00;
                $app->payment_status = $app->paid_amount >= $appPrice ? 'paid' : ($app->paid_amount > 0 ? 'partially_paid' : 'unpaid');
                $app->worker_progress = $app->worker_progress ?: 0;
                $app->worker_status = 'in_progress';
                $app->grace_period_deadline = $graceDeadline;
                $app->save();

                $appDynamicTerms = !empty($app->dynamic_terms) ? $app->dynamic_terms : ($opp->dynamic_terms ?? []);
                if (!empty($app->counter_offer_notes)) {
                    $noteTerm = 'Ketentuan Khusus Kesepakatan: ' . $app->counter_offer_notes;
                    if (!in_array($noteTerm, $appDynamicTerms, true)) {
                        $appDynamicTerms[] = $noteTerm;
                    }
                }
                if (!empty($app->questions_notes)) {
                    $questionTerm = 'Catatan Fasilitas / Permintaan: ' . $app->questions_notes;
                    if (!in_array($questionTerm, $appDynamicTerms, true)) {
                        $appDynamicTerms[] = $questionTerm;
                    }
                }

                $contractNumber = $app->contract_number ?: self::generateContractNumber($opp->id, $app->id, $app->reviewed_at ?? $app->created_at);
                $app->contract_number = $contractNumber;
                if (empty($app->client_signature) && !empty($opp->client_signature)) {
                    $app->client_signature = $opp->client_signature;
                }
                if (empty($app->client_signed_at) && !empty($opp->client_signed_at)) {
                    $app->client_signed_at = $opp->client_signed_at;
                }
                $app->dynamic_terms = $appDynamicTerms;
                $app->save();

                $creatorSig = $app->creator_signature;
                $creatorSignedAt = $app->creator_signed_at ?: now();

                JobContract::updateOrCreate(
                    [
                        'opportunity_id' => $opp->id,
                        'creator_id' => $app->creator_id,
                    ],
                    [
                        'contract_number' => $contractNumber,
                        'client_id' => $userId,
                        'title' => $opp->title,
                        'description' => $opp->description,
                        'agreed_price' => $appPrice,
                        'escrow_amount' => $appPrice,
                        'dynamic_terms' => $appDynamicTerms,
                        'payment_scheme' => $scheme,
                        'payment_terms' => $terms,
                        'paid_amount' => $app->paid_amount,
                        'payment_status' => $app->payment_status,
                        'worker_progress' => $app->worker_progress,
                        'grace_period_deadline' => $graceDeadline,
                        'creator_signature' => $creatorSig,
                        'creator_signed_at' => $creatorSignedAt,
                        'creator_approved' => true,
                        'client_signature' => $opp->client_signature,
                        'client_signed_at' => $opp->client_signed_at,
                        'client_approved' => true,
                        'admin_name' => $adminName,
                        'admin_signature_url' => $adminSignatureUrl,
                        'admin_signed_at' => now(),
                        'contract_status' => ContractStatus::EscrowPaid,
                        'work_status' => WorkStatus::InProgress,
                        'started_at' => now(),
                        'creator_approved' => true,
                        'client_approved' => true,
                        'client_approved_at' => now(),
                        'creator_approved_at' => $app->reviewed_at ?? now(),
                    ]
                );
            }

            // Notify all approved creators that the event has started and funds are secured in escrow!
            foreach ($approvedApps as $app) {
                $this->notificationRepo->create([
                    'user_id' => $app->creator_id,
                    'title' => 'Acara Telah Dimulai & Dana Escrow Diamankan!',
                    'message' => 'Acara "' . $opp->title . '" resmi dimulai. Dana kontrak sebesar Rp ' . number_format($totalEscrow, 0, ',', '.') . ' telah diamankan dalam Escrow Kreavana.',
                    'type' => 'project',
                    'data' => ['opportunity_id' => $opp->id],
                    'is_read' => false,
                    'created_at' => now(),
                ]);
            }

            return $this->formatOpportunity($opp->fresh(['approvedApplications.creator', 'user']), true);
        });
    }

    public function updateProgress(string $opportunityId, string $userId, int $progress): array
    {
        $opp = Opportunity::where('id', $opportunityId)->firstOrFail();
        $user = User::where('id', $userId)->firstOrFail();

        if ($opp->posted_by !== $userId && $user->role !== RoleType::Admin) {
            abort(403, 'Hanya pembuat proyek yang dapat memperbarui progress.');
        }

        $clampedProgress = max(0, min(100, $progress));
        $opp->event_progress = $clampedProgress;
        $isCompleted = false;
        if ($clampedProgress >= 100) {
            $opp->status = 'completed';
            $isCompleted = true;
        }
        $opp->save();

        // Notify approved creators about progress
        $approvedCreators = OpportunityApplication::where('opportunity_id', $opp->id)
            ->where('status', 'approved')
            ->pluck('creator_id');

        foreach ($approvedCreators as $creatorId) {
            $this->notificationRepo->create([
                'user_id' => $creatorId,
                'title' => $isCompleted ? 'Proyek Selesai!' : 'Update Progress Proyek',
                'message' => $isCompleted
                    ? 'Proyek "' . $opp->title . '" telah selesai 100%. Terima kasih atas kontribusi Anda!'
                    : 'Pemilik proyek memperbarui progress "' . $opp->title . '" menjadi ' . $clampedProgress . '%.',
                'type' => 'project',
                'data' => [
                    'opportunity_id' => $opp->id,
                    'event_progress' => $clampedProgress,
                ],
                'is_read' => false,
                'created_at' => now(),
            ]);
        }

        return $this->formatOpportunity($opp->fresh(['approvedApplications.creator', 'user']), true);
    }

    public function submitDocuments(string $applicationId, string $userId, array $documents): array
    {
        $application = OpportunityApplication::where('id', $applicationId)->firstOrFail();
        $opp = Opportunity::where('id', $application->opportunity_id)->firstOrFail();

        if ($application->creator_id !== $userId && $opp->posted_by !== $userId) {
            abort(403, 'Akses ditolak.');
        }

        if ($application->status !== 'approved') {
            abort(422, 'Hanya pelamar yang telah disetujui yang dapat mengirimkan dokumen atau tautan hasil kerja.');
        }

        $currentDocs = $application->submitted_documents ?? [];
        $merged = array_merge($currentDocs, $documents);
        $application->submitted_documents = $merged;
        $application->save();

        // Notify project owner
        $creator = User::find($userId);
        $creatorName = $creator ? $creator->name : 'Kreator';
        if ($opp->posted_by && $opp->posted_by !== $userId) {
            $this->notificationRepo->create([
                'user_id' => $opp->posted_by,
                'title' => 'Dokumen Hasil Kerja Dikirim',
                'message' => $creatorName . ' telah mengunggah dokumen / tautan hasil kerja untuk proyek "' . $opp->title . '".',
                'type' => 'project',
                'data' => [
                    'opportunity_id' => $opp->id,
                    'application_id' => $application->id,
                ],
                'is_read' => false,
                'created_at' => now(),
            ]);
        }

        return [
            'application_id' => $application->id,
            'submitted_documents' => $application->submitted_documents,
            'message' => 'Dokumen berhasil dikirimkan.',
        ];
    }

    public function scheduleMeeting(string $opportunityId, string $userId, array $data): array
    {
        $opp = Opportunity::where('id', $opportunityId)->firstOrFail();
        $user = User::where('id', $userId)->firstOrFail();

        if ($opp->posted_by !== $userId && $user->role !== RoleType::Admin) {
            abort(403, 'Hanya pembuat proyek yang dapat mengatur jadwal pertemuan.');
        }

        $opp->meeting_date = $data['meeting_date'] ?? $opp->meeting_date;
        $opp->meeting_time = $data['meeting_time'] ?? $opp->meeting_time;
        $opp->meeting_location = $data['meeting_location'] ?? $opp->meeting_location;
        $opp->meeting_lat = $data['meeting_lat'] ?? $opp->meeting_lat;
        $opp->meeting_lng = $data['meeting_lng'] ?? $opp->meeting_lng;
        $opp->meeting_notes = $data['meeting_notes'] ?? $opp->meeting_notes;
        $opp->meeting_status = 'pending'; // Status Pending menunggu review Admin Kreavana
        $opp->meeting_counter_by = 'client';
        $opp->meeting_counter_status = 'pending';
        $opp->save();

        // Notify approved creators
        $approvedCreators = OpportunityApplication::where('opportunity_id', $opp->id)
            ->where('status', 'approved')
            ->pluck('creator_id');

        $meetingDateStr = $opp->meeting_date ? \Carbon\Carbon::parse($opp->meeting_date)->format('d M Y') : '';
        $meetingLocStr = $opp->meeting_location ?? 'Lokasi Ditentukan';

        foreach ($approvedCreators as $creatorId) {
            $this->notificationRepo->create([
                'user_id' => $creatorId,
                'title' => 'Jadwal Temu Tanda Tangan Basah Diajukan',
                'message' => 'Penyelenggara proyek "' . $opp->title . '" telah mengajukan jadwal pertemuan tanda tangan basah dokumen fisik 3 Pihak pada ' . $meetingDateStr . ' ' . ($opp->meeting_time ?? '') . ' di ' . $meetingLocStr . '. Menunggu persetujuan Admin Kreavana.',
                'type' => 'project',
                'data' => [
                    'opportunity_id' => $opp->id,
                    'meeting_date' => $opp->meeting_date,
                    'meeting_time' => $opp->meeting_time,
                    'meeting_status' => 'pending',
                ],
                'is_read' => false,
                'created_at' => now(),
            ]);
        }

        // Notify Admin Kreavana
        $admins = User::where('role', RoleType::Admin)->get();
        foreach ($admins as $admin) {
            $this->notificationRepo->create([
                'user_id' => $admin->id,
                'title' => 'Pengajuan Jadwal Tanda Tangan Basah (>= 100 Jt)',
                'message' => 'Proyek "' . $opp->title . '" mengajukan jadwal temu fisik tanda tangan basah pada ' . $meetingDateStr . ' di ' . $meetingLocStr . '. Silakan tinjau dan setujui atau tawarkan jadwal alternatif.',
                'type' => 'project',
                'data' => [
                    'opportunity_id' => $opp->id,
                    'meeting_status' => 'pending',
                ],
                'is_read' => false,
                'created_at' => now(),
            ]);
        }

        return $this->formatOpportunity($opp->fresh(['approvedApplications.creator', 'user']), true);
    }

    /**
     * Admin menyetujui / menolak / menegosiasi jadwal pertemuan fisik.
     * - approve: status meeting menjadi 'diproses'.
     * - counter: admin menawarkan tanggal, jam, dan lokasi alternatif (status tetap 'pending', counter_by 'admin').
     * - reject: status meeting menjadi 'rejected'.
     */
    public function reviewMeeting(string $opportunityId, string $adminId, string $decision, ?string $notes = null, array $counterData = []): array
    {
        $opp = Opportunity::where('id', $opportunityId)->firstOrFail();
        $admin = User::where('id', $adminId)->firstOrFail();

        if ($admin->role !== RoleType::Admin && $admin->role !== RoleType::Marketing) {
            abort(403, 'Akses ditolak. Hanya Admin atau Tim Legal Kreavana yang dapat meninjau jadwal pertemuan.');
        }

        if ($decision === 'approve') {
            $opp->meeting_status = 'diproses'; // Status menjadi diproses jika disetujui Admin
            $opp->meeting_counter_status = 'accepted';
            if ($notes) {
                $opp->meeting_notes = ($opp->meeting_notes ? $opp->meeting_notes . "\n" : '') . "[Persetujuan Admin " . $admin->name . "]: " . $notes;
            }
            $opp->save();

            // Notifikasi ke Penyelenggara
            $this->notificationRepo->create([
                'user_id' => $opp->posted_by,
                'title' => 'Jadwal Tanda Tangan Basah Disetujui Admin!',
                'message' => 'Admin Kreavana telah menyetujui jadwal temu fisik untuk proyek "' . $opp->title . '". Status saat ini: Diproses. Mohon hadir sesuai tanggal dan lokasi.',
                'type' => 'project',
                'data' => [
                    'opportunity_id' => $opp->id,
                    'meeting_status' => 'diproses',
                ],
                'is_read' => false,
                'created_at' => now(),
            ]);

            // Notifikasi ke seluruh pekerja yang disetujui
            $approvedCreators = OpportunityApplication::where('opportunity_id', $opp->id)
                ->where('status', 'approved')
                ->pluck('creator_id');

            foreach ($approvedCreators as $creatorId) {
                $this->notificationRepo->create([
                    'user_id' => $creatorId,
                    'title' => 'Jadwal Tanda Tangan Basah Disetujui Admin!',
                    'message' => 'Jadwal pertemuan fisik tanda tangan basah dokumen MoU untuk proyek "' . $opp->title . '" telah disetujui Admin Kreavana. Status saat ini: Diproses.',
                    'type' => 'project',
                    'data' => [
                        'opportunity_id' => $opp->id,
                        'meeting_status' => 'diproses',
                    ],
                    'is_read' => false,
                    'created_at' => now(),
                ]);
            }
        } elseif ($decision === 'counter') {
            // Admin mengajukan alternatif waktu/tempat (Nego Jadwal & Lokasi)
            $cDate = $counterData['counter_date'] ?? $counterData['meeting_date'] ?? null;
            $cTime = $counterData['counter_time'] ?? $counterData['meeting_time'] ?? null;
            $cLoc = $counterData['counter_location'] ?? $counterData['meeting_location'] ?? null;
            $cLat = $counterData['counter_lat'] ?? $counterData['meeting_lat'] ?? null;
            $cLng = $counterData['counter_lng'] ?? $counterData['meeting_lng'] ?? null;
            $cNotes = $counterData['counter_notes'] ?? $notes;

            if (empty($cDate) && empty($cTime) && empty($cLoc)) {
                abort(422, 'Mohon tentukan tanggal, waktu, atau lokasi alternatif yang diusulkan.');
            }

            $opp->meeting_counter_by = 'admin';
            $opp->meeting_counter_date = $cDate ?: $opp->meeting_date;
            $opp->meeting_counter_time = $cTime ?: $opp->meeting_time;
            $opp->meeting_counter_location = $cLoc ?: $opp->meeting_location;
            $opp->meeting_counter_lat = $cLat ?: $opp->meeting_lat;
            $opp->meeting_counter_lng = $cLng ?: $opp->meeting_lng;
            $opp->meeting_counter_notes = $cNotes;
            $opp->meeting_counter_status = 'pending';
            $opp->meeting_status = 'pending';
            $opp->save();

            // Notifikasi ke Penyelenggara bahwa Admin mengajukan tawaran balik jadwal/lokasi
            $cDateStr = $opp->meeting_counter_date ? \Carbon\Carbon::parse($opp->meeting_counter_date)->format('d M Y') : '';
            $this->notificationRepo->create([
                'user_id' => $opp->posted_by,
                'title' => 'Admin Mengajukan Nego Jadwal & Lokasi Temu',
                'message' => 'Admin Kreavana (' . $admin->name . ') mengusulkan jadwal / lokasi alternatif untuk proyek "' . $opp->title . '": ' . $cDateStr . ' ' . ($opp->meeting_counter_time ?? '') . ' di ' . ($opp->meeting_counter_location ?? '') . ($cNotes ? " (Catatan: $cNotes)" : '') . '. Silakan setujui atau ajukan tawaran ulang.',
                'type' => 'project',
                'data' => [
                    'opportunity_id' => $opp->id,
                    'meeting_counter_by' => 'admin',
                    'meeting_counter_date' => $opp->meeting_counter_date,
                    'meeting_counter_time' => $opp->meeting_counter_time,
                    'meeting_counter_location' => $opp->meeting_counter_location,
                ],
                'is_read' => false,
                'created_at' => now(),
            ]);
        } else {
            $opp->meeting_status = 'rejected';
            $opp->meeting_counter_status = 'declined';
            if ($notes) {
                $opp->meeting_notes = ($opp->meeting_notes ? $opp->meeting_notes . "\n" : '') . "[Penolakan Admin " . $admin->name . "]: " . $notes;
            }
            $opp->save();

            $this->notificationRepo->create([
                'user_id' => $opp->posted_by,
                'title' => 'Jadwal Pertemuan Fisik Ditolak Admin',
                'message' => 'Jadwal pertemuan fisik proyek "' . $opp->title . '" ditolak oleh Admin Kreavana. Silakan koordinasikan dan ajukan jadwal baru.',
                'type' => 'project',
                'data' => [
                    'opportunity_id' => $opp->id,
                    'meeting_status' => 'rejected',
                ],
                'is_read' => false,
                'created_at' => now(),
            ]);
        }

        return $this->formatOpportunity($opp->fresh(['approvedApplications.creator', 'user']), true);
    }

    /**
     * Pembuat acara menanggapi tawaran nego jadwal & lokasi dari Admin.
     * - accept: Pembuat acara menyetujui usulan admin (jadwal diperbarui dan status menjadi 'diproses').
     * - counter: Pembuat acara mengajukan tawaran balik (status tetap 'pending', counter_by 'client').
     * - decline: Pembuat acara menolak usulan.
     */
    public function respondMeetingCounter(string $opportunityId, string $userId, string $action, array $data = []): array
    {
        $opp = Opportunity::where('id', $opportunityId)->firstOrFail();
        $user = User::where('id', $userId)->firstOrFail();

        if ($opp->posted_by !== $userId && $user->role !== RoleType::Admin) {
            abort(403, 'Hanya pembuat proyek yang dapat menanggapi tawaran jadwal pertemuan.');
        }

        if ($action === 'accept') {
            // Menerima jadwal usulan Admin
            if (!empty($opp->meeting_counter_date)) {
                $opp->meeting_date = $opp->meeting_counter_date;
            }
            if (!empty($opp->meeting_counter_time)) {
                $opp->meeting_time = $opp->meeting_counter_time;
            }
            if (!empty($opp->meeting_counter_location)) {
                $opp->meeting_location = $opp->meeting_counter_location;
            }
            if (!empty($opp->meeting_counter_lat)) {
                $opp->meeting_lat = $opp->meeting_counter_lat;
            }
            if (!empty($opp->meeting_counter_lng)) {
                $opp->meeting_lng = $opp->meeting_counter_lng;
            }
            if (!empty($opp->meeting_counter_notes)) {
                $opp->meeting_notes = ($opp->meeting_notes ? $opp->meeting_notes . "\n" : '') . "[Kesepakatan Nego Jadwal]: " . $opp->meeting_counter_notes;
            }

            $opp->meeting_status = 'diproses';
            $opp->meeting_counter_status = 'accepted';
            $opp->save();

            // Notify Admin Kreavana
            $admins = User::where('role', RoleType::Admin)->get();
            foreach ($admins as $admin) {
                $this->notificationRepo->create([
                    'user_id' => $admin->id,
                    'title' => 'Nego Jadwal & Lokasi Disetujui Penyelenggara',
                    'message' => 'Penyelenggara proyek "' . $opp->title . '" telah menyetujui usulan jadwal temu fisik Anda. Status saat ini: Diproses.',
                    'type' => 'project',
                    'data' => [
                        'opportunity_id' => $opp->id,
                        'meeting_status' => 'diproses',
                    ],
                    'is_read' => false,
                    'created_at' => now(),
                ]);
            }

            // Notify all approved creators
            $approvedCreators = OpportunityApplication::where('opportunity_id', $opp->id)
                ->where('status', 'approved')
                ->pluck('creator_id');

            foreach ($approvedCreators as $creatorId) {
                $this->notificationRepo->create([
                    'user_id' => $creatorId,
                    'title' => 'Jadwal Temu Tanda Tangan Basah Telah Disepakati',
                    'message' => 'Jadwal pertemuan fisik tanda tangan basah untuk proyek "' . $opp->title . '" telah disepakati antara Penyelenggara dan Admin Kreavana. Status: Diproses.',
                    'type' => 'project',
                    'data' => [
                        'opportunity_id' => $opp->id,
                        'meeting_status' => 'diproses',
                    ],
                    'is_read' => false,
                    'created_at' => now(),
                ]);
            }
        } elseif ($action === 'counter') {
            // Pembuat acara tawar balik
            $opp->meeting_date = $data['meeting_date'] ?? $opp->meeting_date;
            $opp->meeting_time = $data['meeting_time'] ?? $opp->meeting_time;
            $opp->meeting_location = $data['meeting_location'] ?? $opp->meeting_location;
            $opp->meeting_lat = $data['meeting_lat'] ?? $opp->meeting_lat;
            $opp->meeting_lng = $data['meeting_lng'] ?? $opp->meeting_lng;
            $opp->meeting_notes = $data['meeting_notes'] ?? $opp->meeting_notes;
            $opp->meeting_counter_by = 'client';
            $opp->meeting_counter_status = 'pending';
            $opp->meeting_status = 'pending';
            $opp->save();

            // Notify Admin
            $admins = User::where('role', RoleType::Admin)->get();
            foreach ($admins as $admin) {
                $this->notificationRepo->create([
                    'user_id' => $admin->id,
                    'title' => 'Penyelenggara Menawar Balik Jadwal & Lokasi Temu',
                    'message' => 'Penyelenggara proyek "' . $opp->title . '" mengajukan tawaran balik jadwal / lokasi baru. Silakan tinjau kembali.',
                    'type' => 'project',
                    'data' => [
                        'opportunity_id' => $opp->id,
                        'meeting_status' => 'pending',
                        'meeting_counter_by' => 'client',
                    ],
                    'is_read' => false,
                    'created_at' => now(),
                ]);
            }
        } else {
            $opp->meeting_counter_status = 'declined';
            $opp->save();
        }

        return $this->formatOpportunity($opp->fresh(['approvedApplications.creator', 'user']), true);
    }

    /**
     * Memulai Acara oleh Admin setelah tanda tangan basah fisik selesai diverifikasi.
     */
    public function adminStartEvent(string $opportunityId, string $adminId, array $data = []): array
    {
        $admin = User::where('id', $adminId)->firstOrFail();
        if ($admin->role !== RoleType::Admin && $admin->role !== RoleType::Marketing) {
            abort(403, 'Akses ditolak. Hanya Admin yang dapat mengaktifkan acara dengan tanda tangan basah.');
        }

        $opp = Opportunity::where('id', $opportunityId)->firstOrFail();

        if (!empty($data['document_mou_url'])) {
            $opp->wet_signature_document_url = $data['document_mou_url'];
        }
        $opp->wet_signature_verified_at = now();
        $opp->meeting_status = 'verified_completed';
        $opp->admin_started_at = now();
        $opp->signature_type = 'wet_signature';
        $opp->save();

        // Panggil startEvent resmi
        return $this->startEvent($opportunityId, $opp->posted_by, array_merge($data, [
            'is_admin_override' => true,
        ]));
    }

    /**
     * Update progress pekerjaan per-kreator di dalam event yang sedang berlangsung.
     */
    public function updateWorkerProgress(string $applicationId, string $userId, int $progress, ?string $notes = null, ?string $workerStatus = null): array
    {
        $app = OpportunityApplication::where('id', $applicationId)->firstOrFail();
        $opp = Opportunity::where('id', $app->opportunity_id)->firstOrFail();
        $user = User::where('id', $userId)->firstOrFail();

        $isCreator = ($app->creator_id === $userId);
        $isOwner = ($opp->posted_by === $userId);
        $isAdmin = ($user->role === RoleType::Admin);

        if (!$isCreator && !$isOwner && !$isAdmin) {
            abort(403, 'Akses ditolak. Hanya pekerja terkait, pembuat acara, atau Admin yang dapat memperbarui progress pekerjaan ini.');
        }

        $clamped = max(0, min(100, $progress));
        $app->worker_progress = $clamped;
        if ($workerStatus) {
            $app->worker_status = $workerStatus;
        } else {
            if ($clamped >= 100) {
                $app->worker_status = 'completed';
            } elseif ($clamped > 0) {
                $app->worker_status = 'in_progress';
            }
        }

        // Simpan catatan revisi jika status revision atau ada notes
        if ($notes) {
            if (Schema::hasColumn('opportunity_applications', 'revision_notes')) {
                $app->revision_notes = $notes;
            }
            if ($app->worker_status === 'revision') {
                $deliverables = $app->submitted_deliverables ?? [];
                $deliverables[] = [
                    'id' => (string) Str::uuid(),
                    'type' => 'revision_request',
                    'title' => 'Permintaan Catatan Revisi',
                    'notes' => $notes,
                    'uploaded_by' => $user->name,
                    'uploaded_at' => now()->toIso8601String(),
                ];
                $app->submitted_deliverables = $deliverables;
            }
        }
        $app->save();

        // Tentukan mapping WorkStatus untuk JobContract
        $targetWorkStatus = WorkStatus::InProgress;
        if ($app->worker_status === 'completed' || $clamped >= 100) {
            $targetWorkStatus = WorkStatus::Completed;
        } elseif ($app->worker_status === 'revision') {
            $targetWorkStatus = WorkStatus::Revision;
        } elseif ($app->worker_status === 'review') {
            $targetWorkStatus = WorkStatus::Review;
        }

        $contractUpdates = [
            'worker_progress' => $clamped,
            'work_status' => $targetWorkStatus,
        ];
        if (isset($deliverables)) {
            $contractUpdates['deliverables'] = $deliverables;
        }
        if ($notes && Schema::hasColumn('job_contracts', 'revision_notes')) {
            $contractUpdates['revision_notes'] = $notes;
        }

        // Sinkronisasi dengan JobContract
        JobContract::where('opportunity_id', $opp->id)
            ->where('creator_id', $app->creator_id)
            ->update($contractUpdates);

        // Hitung rata-rata progress seluruh pekerja untuk event_progress
        $avgProgress = (int) OpportunityApplication::where('opportunity_id', $opp->id)
            ->where('status', 'approved')
            ->avg('worker_progress');
        $opp->event_progress = max($opp->event_progress, $avgProgress);
        if ($avgProgress >= 100) {
            $opp->status = 'completed';
        }
        $opp->save();

        // Judul & pesan notifikasi
        $targetUserId = $isCreator ? $opp->posted_by : $app->creator_id;
        $updaterName = $user->name ?: 'Mitra';
        $notifTitle = 'Update Progress Pekerja (' . $clamped . '%)';
        if ($app->worker_status === 'revision') {
            $notifTitle = 'Permintaan Revisi Hasil Kerja';
        } elseif ($app->worker_status === 'review') {
            $notifTitle = 'Hasil Kerja Siap Ditinjau';
        } elseif ($app->worker_status === 'completed') {
            $notifTitle = 'Hasil Kerja Disetujui (Selesai 100%)';
        }

        $this->notificationRepo->create([
            'user_id' => $targetUserId,
            'title' => $notifTitle,
            'message' => $updaterName . ' telah memperbarui progress pengerjaan untuk posisi ' . ucwords(str_replace('_', ' ', $app->sub_role_slug)) . ' menjadi ' . $clamped . '% (Status: ' . $app->worker_status . ').' . ($notes ? ' Catatan: ' . $notes : ''),
            'type' => 'project',
            'data' => [
                'opportunity_id' => $opp->id,
                'application_id' => $app->id,
                'worker_progress' => $clamped,
                'worker_status' => $app->worker_status,
                'revision_notes' => $notes,
            ],
            'is_read' => false,
            'created_at' => now(),
        ]);

        return [
            'application_id' => $app->id,
            'worker_progress' => $app->worker_progress,
            'worker_status' => $app->worker_status,
            'event_progress' => $opp->event_progress,
            'message' => 'Progress pekerja berhasil diperbarui ke ' . $clamped . '%.',
        ];
    }

    /**
     * Unggah hasil kerja / deliverables (Link, Gambar, Video, Dokumen).
     */
    public function submitWorkerDeliverable(string $applicationId, string $userId, array $deliverableData, $file = null): array
    {
        $app = OpportunityApplication::where('id', $applicationId)->firstOrFail();
        $opp = Opportunity::where('id', $app->opportunity_id)->firstOrFail();
        $user = User::where('id', $userId)->firstOrFail();

        if ($app->creator_id !== $userId && $opp->posted_by !== $userId && $user->role !== RoleType::Admin) {
            abort(403, 'Akses ditolak.');
        }

        $type = $deliverableData['type'] ?? 'link'; // link, image, video, document
        $url = $deliverableData['url'] ?? '';
        $title = $deliverableData['title'] ?? 'Hasil Kerja';
        $notes = $deliverableData['notes'] ?? null;

        // Tangani unggah file langsung jika ada
        if ($file && $file->isValid()) {
            /** @var \App\Services\StorageService $storageService */
            $storageService = app(\App\Services\StorageService::class);
            $storageFile = $storageService->store($user, $file, 'deliverables', 'public');
            $url = $storageFile->url;
        }

        if (empty($url)) {
            abort(422, 'Tautan URL atau file hasil kerja wajib diisi.');
        }

        $newDeliverable = [
            'id' => (string) Str::uuid(),
            'type' => $type,
            'url' => $url,
            'title' => $title,
            'notes' => $notes,
            'uploaded_by' => $user->name,
            'uploaded_at' => now()->toIso8601String(),
        ];

        $deliverables = $app->submitted_deliverables ?? [];
        $deliverables[] = $newDeliverable;
        $app->submitted_deliverables = $deliverables;
        if ($app->worker_status === 'revision') {
            $app->worker_status = 'review';
        }
        $app->save();

        // Sinkronisasi dengan JobContract
        $contractWorkStatus = ($app->worker_progress >= 100) ? WorkStatus::Completed : WorkStatus::Review;
        JobContract::where('opportunity_id', $opp->id)
            ->where('creator_id', $app->creator_id)
            ->update([
                'deliverables' => $deliverables,
                'work_status' => $contractWorkStatus,
            ]);

        // Notifikasi ke pembuat acara
        if ($opp->posted_by && $opp->posted_by !== $userId) {
            $this->notificationRepo->create([
                'user_id' => $opp->posted_by,
                'title' => 'Hasil Kerja Baru Diunggah (' . strtoupper($type) . ')',
                'message' => $user->name . ' telah mengunggah hasil kerja: "' . $title . '" untuk proyek "' . $opp->title . '".',
                'type' => 'project',
                'data' => [
                    'opportunity_id' => $opp->id,
                    'application_id' => $app->id,
                    'deliverable' => $newDeliverable,
                ],
                'is_read' => false,
                'created_at' => now(),
            ]);
        }

        return [
            'application_id' => $app->id,
            'deliverable' => $newDeliverable,
            'submitted_deliverables' => $app->submitted_deliverables,
            'message' => 'Hasil kerja (' . strtoupper($type) . ') berhasil diunggah.',
        ];
    }

    /**
     * Bayar termin / pelunasan honor pekerja dari dana Escrow.
     */
    public function payWorkerTerm(string $applicationId, string $userId, ?int $milestoneIndex = null, ?float $customAmount = null): array
    {
        return DB::transaction(function () use ($applicationId, $userId, $milestoneIndex, $customAmount) {
            $app = OpportunityApplication::where('id', $applicationId)->lockForUpdate()->firstOrFail();
            $opp = Opportunity::where('id', $app->opportunity_id)->lockForUpdate()->firstOrFail();
            $client = User::where('id', $userId)->firstOrFail();

            if ($opp->posted_by !== $userId && $client->role !== RoleType::Admin) {
                abort(403, 'Hanya pembuat acara atau Admin yang berwenang melakukan pembayaran honor ke pekerja.');
            }

            if (!in_array($opp->status, ['in_progress', 'completed'])) {
                abort(422, 'Pembayaran termin hanya dapat dicairkan saat acara berlangsung atau telah selesai.');
            }

            $totalAgreed = (float) ($app->counter_offer_price ?: $app->bid_price ?: 0);
            if ($totalAgreed <= 0) {
                abort(422, 'Nominal kesepakatan honor pekerja tidak valid.');
            }

            $alreadyPaid = (float) ($app->paid_amount ?? 0);
            $terms = $app->payment_terms ?? [];
            $payoutAmount = 0.0;
            $milestoneTitle = 'Pembayaran Honor';

            if ($milestoneIndex !== null && isset($terms[$milestoneIndex])) {
                $milestone = $terms[$milestoneIndex];
                if (($milestone['status'] ?? 'unpaid') === 'paid') {
                    abort(422, 'Termin "' . ($milestone['title'] ?? ('Termin ' . ($milestoneIndex + 1))) . '" sudah dibayarkan sebelumnya.');
                }

                $payoutAmount = (float) ($milestone['amount'] ?? round($totalAgreed * (($milestone['percentage'] ?? 100) / 100), 2));
                $milestoneTitle = $milestone['title'] ?? ('Termin ' . ($milestoneIndex + 1));

                $terms[$milestoneIndex]['status'] = 'paid';
                $terms[$milestoneIndex]['paid_at'] = now()->toIso8601String();
            } else {
                $payoutAmount = $customAmount ?: max(0, $totalAgreed - $alreadyPaid);
                $milestoneTitle = 'Pelunasan Penuh';

                if (!empty($terms)) {
                    foreach ($terms as $idx => $t) {
                        $terms[$idx]['status'] = 'paid';
                        if (empty($terms[$idx]['paid_at'])) {
                            $terms[$idx]['paid_at'] = now()->toIso8601String();
                        }
                    }
                }
            }

            if ($payoutAmount <= 0) {
                abort(422, 'Tidak ada sisa nominal honor yang perlu dicairkan.');
            }

            $newPaidTotal = $alreadyPaid + $payoutAmount;
            $app->paid_amount = $newPaidTotal;
            $app->payment_terms = $terms;
            $app->payment_status = ($newPaidTotal >= ($totalAgreed - 100)) ? 'paid' : 'partially_paid';
            $app->save();

            // Masukkan dana ke saldo dompet kreator
            $creator = User::lockForUpdate()->where('id', $app->creator_id)->firstOrFail();
            $creator->balance += $payoutAmount;
            $creator->save();

            $refNumber = 'ESCROW-PAY-' . strtoupper(Str::random(8)) . '-' . time();
            $walletTx = WalletTransaction::create([
                'user_id' => $creator->id,
                'type' => 'escrow_release',
                'amount' => $payoutAmount,
                'fee' => 0.00,
                'payment_method' => 'wallet',
                'payment_provider' => 'Kreavana Escrow',
                'status' => 'completed',
                'reference_number' => $refNumber,
                'description' => "Pencairan dana Escrow untuk acara '{$opp->title}' ({$milestoneTitle}) kepada {$creator->name}.",
            ]);
            $walletTx->ledger_hash = $walletTx->generateLedgerHash();
            $walletTx->save();

            // Sinkronisasi dengan JobContract
            JobContract::where('opportunity_id', $opp->id)
                ->where('creator_id', $app->creator_id)
                ->update([
                    'paid_amount' => $newPaidTotal,
                    'payment_status' => $app->payment_status,
                    'payment_terms' => $terms,
                    'work_status' => ($app->payment_status === 'paid' && $app->worker_progress >= 100) ? WorkStatus::Completed : WorkStatus::InProgress,
                ]);

            // Notifikasi ke Kreator
            $this->notificationRepo->create([
                'user_id' => $creator->id,
                'title' => 'Honorarium Pekerjaan Dicairkan!',
                'message' => 'Pembayaran sebesar Rp ' . number_format($payoutAmount, 0, ',', '.') . ' (' . $milestoneTitle . ') untuk proyek "' . $opp->title . '" telah dicairkan ke saldo dompet Anda.',
                'type' => 'wallet',
                'data' => [
                    'opportunity_id' => $opp->id,
                    'application_id' => $app->id,
                    'amount' => $payoutAmount,
                    'reference_number' => $refNumber,
                ],
                'is_read' => false,
                'created_at' => now(),
            ]);

            return [
                'application_id' => $app->id,
                'paid_amount' => (float) $app->paid_amount,
                'payment_status' => $app->payment_status,
                'payment_terms' => $app->payment_terms,
                'payout_amount' => $payoutAmount,
                'message' => 'Pembayaran sebesar Rp ' . number_format($payoutAmount, 0, ',', '.') . ' (' . $milestoneTitle . ') berhasil dicairkan ke saldo pekerja.',
            ];
        });
    }

    /**
     * Auto-release dana Escrow jika melewati batas waktu 1 bulan dari tanggal acara yang ditentukan.
     */
    public function checkAndAutoReleaseEscrow(string $opportunityId, ?string $userId = null): array
    {
        return DB::transaction(function () use ($opportunityId, $userId) {
            $opp = Opportunity::where('id', $opportunityId)->lockForUpdate()->firstOrFail();

            $eventEnd = $opp->event_end_date ?? $opp->event_date;
            if (!$eventEnd) {
                return ['status' => false, 'message' => 'Tanggal acara belum ditentukan.'];
            }

            $endDate = \Carbon\Carbon::parse($eventEnd)->endOfDay();
            $graceDeadline = $endDate->copy()->addMonth();

            if (now()->isBefore($graceDeadline)) {
                $daysRemaining = max(0, (int) now()->diffInDays($graceDeadline, false));
                return [
                    'status' => false,
                    'is_expired' => false,
                    'days_remaining' => $daysRemaining,
                    'grace_period_deadline' => $graceDeadline->toIso8601String(),
                    'message' => "Masa tenggang 1 bulan belum lewat. Tersisa {$daysRemaining} hari sebelum auto-release dana ke pekerja diaktifkan.",
                ];
            }

            // Sudah lewat 1 bulan pasca acara: lepas sisa dana ke seluruh pekerja
            $approvedApps = OpportunityApplication::where('opportunity_id', $opp->id)
                ->where('status', 'approved')
                ->lockForUpdate()
                ->get();

            $releasedCount = 0;
            $totalReleased = 0.0;

            foreach ($approvedApps as $app) {
                $totalAgreed = (float) ($app->counter_offer_price ?: $app->bid_price ?: 0);
                $paid = (float) ($app->paid_amount ?? 0);
                $unpaid = max(0, $totalAgreed - $paid);

                if ($unpaid > 0) {
                    $creator = User::lockForUpdate()->where('id', $app->creator_id)->first();
                    if ($creator) {
                        $creator->balance += $unpaid;
                        $creator->save();

                        $refNumber = 'AUTO-ESCROW-' . strtoupper(Str::random(8)) . '-' . time();
                        $walletTx = WalletTransaction::create([
                            'user_id' => $creator->id,
                            'type' => 'escrow_release',
                            'amount' => $unpaid,
                            'fee' => 0.00,
                            'payment_method' => 'wallet',
                            'payment_provider' => 'Kreavana Escrow',
                            'status' => 'completed',
                            'reference_number' => $refNumber,
                            'description' => "Pencairan otomatis (Auto-Release) sisa dana Escrow untuk acara '{$opp->title}' karena telah melewati masa tenggang 1 bulan pasca acara.",
                        ]);
                        $walletTx->ledger_hash = $walletTx->generateLedgerHash();
                        $walletTx->save();

                        $app->paid_amount = $totalAgreed;
                        $app->payment_status = 'paid';
                        $app->auto_released_at = now();

                        $terms = $app->payment_terms ?? [];
                        if (!empty($terms)) {
                            foreach ($terms as $idx => $t) {
                                $terms[$idx]['status'] = 'paid';
                                $terms[$idx]['paid_at'] = now()->toIso8601String();
                            }
                            $app->payment_terms = $terms;
                        }
                        $app->save();

                        JobContract::where('opportunity_id', $opp->id)
                            ->where('creator_id', $app->creator_id)
                            ->update([
                                'paid_amount' => $totalAgreed,
                                'payment_status' => 'paid',
                                'auto_released_at' => now(),
                                'work_status' => WorkStatus::Completed,
                            ]);

                        $this->notificationRepo->create([
                            'user_id' => $creator->id,
                            'title' => 'Dana Escrow Otomatis Dicairkan (Auto-Release)',
                            'message' => 'Sisa honor sebesar Rp ' . number_format($unpaid, 0, ',', '.') . ' untuk proyek "' . $opp->title . '" telah otomatis dicairkan ke saldo Anda sesuai kesepakatan karena melewati masa tenggang 1 bulan pasca acara.',
                            'type' => 'wallet',
                            'data' => [
                                'opportunity_id' => $opp->id,
                                'application_id' => $app->id,
                                'amount' => $unpaid,
                            ],
                            'is_read' => false,
                            'created_at' => now(),
                        ]);

                        $releasedCount++;
                        $totalReleased += $unpaid;
                    }
                }
            }

            $opp->auto_release_triggered_at = now();
            $opp->save();

            if ($opp->posted_by) {
                $this->notificationRepo->create([
                    'user_id' => $opp->posted_by,
                    'title' => 'Dana Escrow Acara Telah Dilepas ke Pekerja',
                    'message' => 'Karena telah melewati masa tenggang 1 bulan dari tanggal acara, total sisa dana sebesar Rp ' . number_format($totalReleased, 0, ',', '.') . ' telah dilepaskan otomatis ke pekerja proyek "' . $opp->title . '" sesuai kesepakatan nego.',
                    'type' => 'project',
                    'data' => [
                        'opportunity_id' => $opp->id,
                        'total_released' => $totalReleased,
                    ],
                    'is_read' => false,
                    'created_at' => now(),
                ]);
            }

            return [
                'status' => true,
                'is_expired' => true,
                'released_count' => $releasedCount,
                'total_released' => $totalReleased,
                'message' => "Auto-release berhasil dijalankan. Dana sebesar Rp " . number_format($totalReleased, 0, ',', '.') . " telah dilepas ke {$releasedCount} pekerja.",
            ];
        });
    }

    public function reviewApplication(
        string $applicationId,
        string $userId,
        string $decision,
        ?string $reason = null,
        ?float $counterOfferPrice = null,
        ?string $counterOfferNotes = null
    ): array {
        return DB::transaction(function () use ($applicationId, $userId, $decision, $reason, $counterOfferPrice, $counterOfferNotes) {
            $application = OpportunityApplication::where('id', $applicationId)->lockForUpdate()->firstOrFail();
            $opp = Opportunity::where('id', $application->opportunity_id)->lockForUpdate()->firstOrFail();
            $user = User::where('id', $userId)->firstOrFail();

            if ($opp->posted_by !== $userId && $user->role !== RoleType::Admin) {
                abort(403, 'Akses ditolak. Anda tidak memiliki wewenang untuk meninjau lamaran ini.');
            }

            if (!in_array($application->status, ['pending', 'under_consideration'])) {
                abort(400, 'Lamaran ini sudah diproses sebelumnya dengan status: ' . $application->status);
            }

            if ($decision === 'approve') {
                // Enforce requirement capacity under lock to prevent race conditions
                $requirement = OpportunityRequirement::where('opportunity_id', $opp->id)
                    ->where('sub_role_slug', $application->sub_role_slug)
                    ->lockForUpdate()
                    ->first();

                if ($requirement) {
                    $maxCapacity = (int) $requirement->quantity;
                    $approvedCount = OpportunityApplication::where('opportunity_id', $opp->id)
                        ->where('sub_role_slug', $application->sub_role_slug)
                        ->where('status', 'approved')
                        ->count();
                } else {
                    $totalRequirementQuota = (int) OpportunityRequirement::where('opportunity_id', $opp->id)->sum('quantity');
                    $maxCapacity = $totalRequirementQuota > 0 ? $totalRequirementQuota : 1;
                    $approvedCount = $totalRequirementQuota > 0
                        ? OpportunityApplication::where('opportunity_id', $opp->id)->where('status', 'approved')->count()
                        : OpportunityApplication::where('opportunity_id', $opp->id)
                            ->where('sub_role_slug', $application->sub_role_slug)
                            ->where('status', 'approved')
                            ->count();
                }

                if ($approvedCount >= $maxCapacity) {
                    abort(422, "Kapasitas kebutuhan untuk posisi " . ucwords(str_replace('_', ' ', $application->sub_role_slug)) . " sudah terpenuhi ({$approvedCount}/{$maxCapacity}).");
                }

                $application->status = 'approved';
                if ($application->counter_offer_price && $application->counter_offer_status !== 'declined') {
                    $application->counter_offer_status = 'accepted';
                }
                $application->reviewed_at = now();
                if (empty($application->contract_number)) {
                    $application->contract_number = self::generateContractNumber($opp->id, $application->id, $application->reviewed_at);
                }
                if (empty($application->dynamic_terms)) {
                    $application->loadMissing('creator');
                    $agreedPrice = self::resolveIndividualAgreedPrice($opp, $application, max(1, (int) $approvedCount + 1));
                    $application->dynamic_terms = self::buildIndividualDefaultTerms($opp, $application, $agreedPrice);
                }
                $application->save();

                // Auto-close opportunity if all position quotas are now fulfilled
                $allReqs = OpportunityRequirement::where('opportunity_id', $opp->id)->get();
                $totalOppCapacity = 0;
                foreach ($allReqs as $r) {
                    $q = (int) $r->quantity;
                    if ($q <= 0 && !empty($r->notes)) {
                        if (preg_match('/\((\d+)\s+kuota\)/i', $r->notes, $matches)) {
                            $q = (int) $matches[1];
                        }
                    }
                    $totalOppCapacity += max(0, $q);
                }
                if ($totalOppCapacity > 0) {
                    $totalApprovedAfter = OpportunityApplication::where('opportunity_id', $opp->id)
                        ->where('status', 'approved')
                        ->count();
                    if ($totalApprovedAfter >= $totalOppCapacity) {
                        $opp->status = 'closed';
                        $opp->save();
                    }
                }

                // Notify creator
                $priceInfo = $application->counter_offer_status === 'accepted' && $application->counter_offer_price
                    ? ' dengan kesepakatan dana Rp ' . number_format($application->counter_offer_price, 0, ',', '.')
                    : '';

                $this->notificationRepo->create([
                    'user_id' => $application->creator_id,
                    'title' => 'Lamaran Disetujui — Lengkapi Kontrak Digital',
                    'message' => 'Selamat! Lamaran Anda untuk proyek "' . $opp->title . '" telah disetujui' . $priceInfo . '. Silakan tinjau ketentuan dan bubuhi tanda tangan pada Dokumen Kontrak Digital sebelum acara dimulai.',
                    'type' => 'project',
                    'data' => [
                        'opportunity_id' => $opp->id,
                        'application_id' => $application->id,
                    ],
                    'is_read' => false,
                    'created_at' => now(),
                ]);
            } elseif ($decision === 'reject') {
                $application->status = 'rejected';
                $application->rejection_reason = $reason;
                $application->reviewed_at = now();
                $application->save();

                // Notify creator
                $this->notificationRepo->create([
                    'user_id' => $application->creator_id,
                    'title' => 'Status Lamaran Proyek',
                    'message' => 'Lamaran Anda untuk proyek "' . $opp->title . '" belum dapat diterima kali ini.',
                    'type' => 'project',
                    'data' => [
                        'opportunity_id' => $opp->id,
                        'application_id' => $application->id,
                    ],
                    'is_read' => false,
                    'created_at' => now(),
                ]);
            } elseif ($decision === 'consider') {
                if ($application->counter_offer_status === 'accepted') {
                    abort(422, 'Pelamar telah menyetujui tawaran negosiasi dana. Anda tidak dapat melakukan negosiasi ulang, silakan pilih Setujui Lamaran (Deal) atau Tolak.');
                }

                if (!$counterOfferPrice || $counterOfferPrice <= 0) {
                    abort(422, 'Nominal tawaran dana pertimbangan harus diisi dan lebih dari 0.');
                }

                $application->status = 'under_consideration';
                $application->counter_offer_price = $counterOfferPrice;
                $application->counter_offer_notes = $counterOfferNotes ?? $reason;
                $application->counter_offer_status = 'pending';
                if (\Illuminate\Support\Facades\Schema::hasColumn('opportunity_applications', 'counter_offer_by')) {
                    $application->counter_offer_by = 'client';
                }
                $application->reviewed_at = now();
                $application->save();

                // Notify creator about counter-offer
                $this->notificationRepo->create([
                    'user_id' => $application->creator_id,
                    'title' => 'Tawaran Nego Dana dari Pemilik Proyek',
                    'message' => 'Pemilik proyek "' . $opp->title . '" memperbarui tawaran dana menjadi Rp ' . number_format($counterOfferPrice, 0, ',', '.') . '. Silakan tinjau dan respon tawaran ini.',
                    'type' => 'project',
                    'data' => [
                        'opportunity_id' => $opp->id,
                        'application_id' => $application->id,
                        'counter_offer_price' => $counterOfferPrice,
                    ],
                    'is_read' => false,
                    'created_at' => now(),
                ]);
            } else {
                abort(422, 'Keputusan tidak valid. Pilihan: approve, reject, atau consider.');
            }

            return [
                'id' => $application->id,
                'status' => $application->status,
                'counter_offer_price' => $application->counter_offer_price ? (float) $application->counter_offer_price : null,
                'counter_offer_notes' => $application->counter_offer_notes,
                'counter_offer_status' => $application->counter_offer_status,
                'counter_offer_by' => $application->counter_offer_by ?? 'client',
                'reviewed_at' => $application->reviewed_at?->toIso8601String(),
                'rejection_reason' => $application->rejection_reason,
            ];
        });
    }

    public function respondCounterOffer(
        string $applicationId,
        string $userId,
        string $action,
        ?float $counterOfferPrice = null,
        ?string $counterOfferNotes = null
    ): array {
        return DB::transaction(function () use ($applicationId, $userId, $action, $counterOfferPrice, $counterOfferNotes) {
            $application = OpportunityApplication::where('id', $applicationId)->lockForUpdate()->firstOrFail();
            $opp = Opportunity::where('id', $application->opportunity_id)->lockForUpdate()->firstOrFail();

            if ($application->creator_id !== $userId) {
                abort(403, 'Akses ditolak. Hanya pelamar terkait yang dapat menanggapi tawaran ini.');
            }

            if ($application->status !== 'under_consideration') {
                abort(400, 'Lamaran ini tidak sedang dalam status pertimbangan tawaran.');
            }

            if (!in_array($action, ['accept', 'decline', 'counter'])) {
                abort(422, 'Tindakan tidak valid. Pilihan: accept, decline, atau counter.');
            }

            if ($action === 'counter') {
                if (!$counterOfferPrice || $counterOfferPrice <= 0) {
                    abort(422, 'Nominal tawaran balik harus diisi dan lebih dari 0.');
                }

                $application->counter_offer_price = $counterOfferPrice;
                $application->counter_offer_notes = $counterOfferNotes;
                $application->counter_offer_status = 'pending';
                if (\Illuminate\Support\Facades\Schema::hasColumn('opportunity_applications', 'counter_offer_by')) {
                    $application->counter_offer_by = 'creator';
                }
                $application->save();

                // Notify project owner
                $creator = User::find($userId);
                $creatorName = $creator ? $creator->name : 'Pelamar';

                $this->notificationRepo->create([
                    'user_id' => $opp->posted_by,
                    'title' => 'Pelamar Mengajukan Tawaran Nego Baru!',
                    'message' => "{$creatorName} mengajukan tawaran nego balik Rp " . number_format($counterOfferPrice, 0, ',', '.') . " untuk proyek \"{$opp->title}\". Silakan buka detail proyek untuk meninjau atau menyetujui.",
                    'type' => 'project',
                    'data' => [
                        'opportunity_id' => $opp->id,
                        'application_id' => $application->id,
                        'counter_offer_price' => $counterOfferPrice,
                    ],
                    'is_read' => false,
                    'created_at' => now(),
                ]);
            } elseif ($action === 'accept') {
                $application->counter_offer_status = 'accepted';
                $application->save();

                // Notify project owner
                $this->notificationRepo->create([
                    'user_id' => $opp->posted_by,
                    'title' => 'Pelamar Menyetujui Tawaran Dana!',
                    'message' => 'Pelamar telah menyetujui tawaran dana Rp ' . number_format($application->counter_offer_price, 0, ',', '.') . ' untuk proyek "' . $opp->title . '". Anda dapat menyetujui lamaran sekarang.',
                    'type' => 'project',
                    'data' => [
                        'opportunity_id' => $opp->id,
                        'application_id' => $application->id,
                        'counter_offer_price' => $application->counter_offer_price,
                    ],
                    'is_read' => false,
                    'created_at' => now(),
                ]);
            } else { // decline
                $application->counter_offer_status = 'declined';
                $application->save();

                $this->notificationRepo->create([
                    'user_id' => $opp->posted_by,
                    'title' => 'Pelamar Belum Menyetujui Tawaran Dana',
                    'message' => 'Pelamar menolak tawaran dana Rp ' . number_format($application->counter_offer_price, 0, ',', '.') . ' untuk proyek "' . $opp->title . '". Anda masih dapat memperbarui tawaran nego.',
                    'type' => 'project',
                    'data' => [
                        'opportunity_id' => $opp->id,
                        'application_id' => $application->id,
                    ],
                    'is_read' => false,
                    'created_at' => now(),
                ]);
            }

            return [
                'id' => $application->id,
                'status' => $application->status,
                'counter_offer_price' => (float) $application->counter_offer_price,
                'counter_offer_status' => $application->counter_offer_status,
                'counter_offer_notes' => $application->counter_offer_notes,
                'counter_offer_by' => $application->counter_offer_by ?? ($action === 'counter' ? 'creator' : 'client'),
            ];
        });
    }

    /**
     * Dapatkan rincian seluruh kontrak digital 3 pihak untuk suatu peluang acara.
     */
    public function getOpportunityContracts(string $opportunityId, string $userId): array
    {
        $opp = Opportunity::where('id', $opportunityId)->with(['user', 'approvedApplications.creator'])->firstOrFail();

        $contractsByCreator = JobContract::where('opportunity_id', $opportunityId)
            ->with(['client', 'creator'])
            ->get()
            ->keyBy('creator_id');

        $defaultTerms = [
            'Penyelenggara (Pihak Pertama) wajib menyediakan akses lokasi, jadwal rundown yang jelas, dan koordinasi teknis di venue.',
            'Penyediaan fasilitas dan alat kerja utama (seperti kamera, lensa, instrumen, dll) disepakati tertulis antara pembuat event dan pekerja.',
            'Pekerja (Pihak Kedua) berkewajiban hadir tepat waktu dan menyerahkan hasil kerja sesuai standar profesional yang disepakati.',
            'Honorarium kerja diamankan 100% pada sistem Escrow Rekber Kreavana (Pihak Ketiga) dan hanya dicairkan setelah hasil pekerjaan disetujui.',
        ];

        $adminName = $opp->admin_name ?: SystemSetting::get('admin_contract_signer_name', 'CV Transforma Alam Kreasi — Otoritas Legal & Escrow Aplikasi Kreavana');
        $adminTitle = SystemSetting::get('admin_contract_signer_title', 'Otoritas Penjamin Transaksi CV Transforma Alam Kreasi (Aplikasi Kreavana)');
        $adminSignatureUrl = $opp->admin_signature_url ?: SystemSetting::get('admin_contract_signature_image', '/assets/images/kreavana_official_signature.png');
        $adminSignedAt = $opp->admin_signed_at ?: now();

        $approvedApps = $opp->approvedApplications;
                if ($approvedApps->isNotEmpty()) {
            $approvedCount = max(1, $approvedApps->count());
            return $approvedApps->map(function ($app) use ($opp, $contractsByCreator, $approvedCount, $adminName, $adminTitle, $adminSignatureUrl, $adminSignedAt) {
                $c = $contractsByCreator->get($app->creator_id);
                $creator = $app->creator ?: $c?->creator;
                $client = $c?->client ?: $opp->user;

                $contractNumber = $c?->contract_number
                    ?: $app->contract_number
                    ?: self::generateContractNumber($opp->id, $app->id, $app->reviewed_at ?? $app->created_at);

                $agreedPrice = (float) ($c?->agreed_price ?: self::resolveIndividualAgreedPrice($opp, $app, $approvedCount));
                $clientSig = $c?->client_signature ?? $app->client_signature ?? $opp->client_signature;
                $clientSignedAt = $c?->client_signed_at ?? $app->client_signed_at ?? $opp->client_signed_at;
                $creatorSig = $c?->creator_signature ?? $app->creator_signature;
                $creatorSignedAt = $c?->creator_signed_at ?? $app->creator_signed_at;
                $isFinal = !empty($clientSig) && !empty($clientSignedAt) && !empty($creatorSig) && !empty($creatorSignedAt);

                $terms = !empty($c?->dynamic_terms)
                    ? $c->dynamic_terms
                    : (!empty($app->dynamic_terms) ? $app->dynamic_terms : self::buildIndividualDefaultTerms($opp, $app, $agreedPrice));

                return [
                    'id' => $c?->id ?? $app->id,
                    'application_id' => $app->id,
                    'contract_number' => $contractNumber,
                    'company_header' => 'CV Transforma Alam Kreasi',
                    'platform_source' => 'Aplikasi Kreavana',
                    'opportunity_id' => $opp->id,
                    'title' => $c?->title ?? $opp->title,
                    'description' => $c?->description ?? $opp->description,
                    'agreed_price' => $agreedPrice,
                    'escrow_amount' => (float) ($c?->escrow_amount ?? $agreedPrice),
                    'contract_status' => $c
                        ? (is_string($c->contract_status) ? $c->contract_status : ($c->contract_status?->value ?? 'escrow_paid'))
                        : ($isFinal ? 'signed_final' : 'pending_signature'),
                    'work_status' => $c
                        ? (is_string($c->work_status) ? $c->work_status : ($c->work_status?->value ?? 'in_progress'))
                        : ($app->worker_status ?? 'assigned'),
                    'is_final' => $isFinal,
                    'dynamic_terms' => $terms,
                    'payment_scheme' => $c?->payment_scheme ?? $app->payment_scheme ?? 'full_at_end',
                    'payment_terms' => $c?->payment_terms ?? $app->payment_terms ?? [],
                    'paid_amount' => (float) ($c?->paid_amount ?? $app->paid_amount ?? 0),
                    'payment_status' => $c?->payment_status ?? $app->payment_status ?? 'unpaid',
                    'worker_progress' => (int) ($c?->worker_progress ?? $app->worker_progress ?? 0),
                    'deliverables' => $c?->deliverables ?? $app->submitted_deliverables ?? [],
                    'grace_period_deadline' => ($c?->grace_period_deadline ?? $app->grace_period_deadline)?->toIso8601String(),
                    'auto_released_at' => ($c?->auto_released_at ?? $app->auto_released_at)?->toIso8601String(),

                    // Pihak Pertama: Pembuat Event (Klien)
                    'party_client' => [
                        'id' => $client?->id ?? $opp->posted_by,
                        'name' => $client?->name ?? 'Pembuat Event',
                        'username' => $client?->username ?? 'client',
                        'role' => is_string($client?->role) ? $client?->role : ($client?->role?->value ?? 'client'),
                        'signature' => $clientSig,
                        'signed_at' => $clientSignedAt?->toIso8601String(),
                    ],

                    // Pihak Kedua: Pelamar / Pekerja Individu (1 Orang 1 Kontrak)
                    'party_creator' => [
                        'id' => $creator?->id ?? $app->creator_id,
                        'name' => $creator?->name ?? 'Pekerja Kreator',
                        'username' => $creator?->username ?? 'creator',
                        'sub_role' => $app->sub_role_slug ?: (is_string($creator?->sub_role) ? $creator?->sub_role : ($creator?->sub_role?->value ?? $opp->sub_role_slug)),
                        'signature' => $creatorSig,
                        'signed_at' => $creatorSignedAt?->toIso8601String(),
                    ],

                    // Pihak Ketiga: CV Transforma Alam Kreasi (Penjamin Escrow & Legal Platform Aplikasi Kreavana)
                    'party_admin' => [
                        'name' => $c?->admin_name ?: $adminName,
                        'title' => $adminTitle,
                        'company' => 'CV Transforma Alam Kreasi',
                        'source' => 'Aplikasi Kreavana',
                        'signature_url' => $c?->admin_signature_url ?: $adminSignatureUrl,
                        'signed_at' => ($c?->admin_signed_at ?? $adminSignedAt)->toIso8601String(),
                        'official_stamp' => 'TERVERIFIKASI CV TRANSFORMA ALAM KREASI — APLIKASI KREAVANA',
                    ],

                    'created_at' => ($c?->created_at ?? $app->reviewed_at ?? $app->created_at)?->toIso8601String(),
                ];
            })->values()->toArray();
        }

        return $contractsByCreator->values()->map(function ($c) use ($opp, $defaultTerms, $adminName, $adminTitle, $adminSignatureUrl, $adminSignedAt) {
            $creator = $c->creator;
            $client = $c->client ?: $opp->user;
            $clientSig = $c->client_signature ?? $opp->client_signature;
            $clientSignedAt = $c->client_signed_at ?? $opp->client_signed_at;
            $creatorSig = $c->creator_signature;
            $creatorSignedAt = $c->creator_signed_at ?? $c->creator_approved_at;

            return [
                'id' => $c->id,
                'application_id' => null,
                'contract_number' => $c->contract_number ?? self::generateContractNumber($opp->id, $c->id, $c->created_at),
                'company_header' => 'CV Transforma Alam Kreasi',
                'platform_source' => 'Aplikasi Kreavana',
                'opportunity_id' => $opp->id,
                'title' => $c->title,
                'description' => $c->description,
                'agreed_price' => (float) $c->agreed_price,
                'escrow_amount' => (float) $c->escrow_amount,
                'contract_status' => is_string($c->contract_status) ? $c->contract_status : ($c->contract_status?->value ?? 'escrow_paid'),
                'work_status' => is_string($c->work_status) ? $c->work_status : ($c->work_status?->value ?? 'in_progress'),
                'is_final' => !empty($clientSig) && !empty($clientSignedAt) && !empty($creatorSig) && !empty($creatorSignedAt),
                'dynamic_terms' => $c->dynamic_terms ?: ($opp->dynamic_terms ?: $defaultTerms),
                'payment_scheme' => $c->payment_scheme ?? 'full_at_end',
                'payment_terms' => $c->payment_terms ?? [],
                'paid_amount' => (float) ($c->paid_amount ?? 0),
                'payment_status' => $c->payment_status ?? 'unpaid',
                'worker_progress' => (int) ($c->worker_progress ?? 0),
                'deliverables' => $c->deliverables ?? [],
                'grace_period_deadline' => $c->grace_period_deadline?->toIso8601String(),
                'auto_released_at' => $c->auto_released_at?->toIso8601String(),

                'party_client' => [
                    'id' => $client?->id ?? $opp->posted_by,
                    'name' => $client?->name ?? 'Pembuat Event',
                    'username' => $client?->username ?? 'client',
                    'role' => is_string($client?->role) ? $client?->role : ($client?->role?->value ?? 'client'),
                    'signature' => $clientSig,
                    'signed_at' => $clientSignedAt?->toIso8601String(),
                ],

                'party_creator' => [
                    'id' => $creator?->id,
                    'name' => $creator?->name ?? 'Pekerja Kreator',
                    'username' => $creator?->username ?? 'creator',
                    'sub_role' => is_string($creator?->sub_role) ? $creator?->sub_role : ($creator?->sub_role?->value ?? $opp->sub_role_slug),
                    'signature' => $creatorSig,
                    'signed_at' => $creatorSignedAt?->toIso8601String(),
                ],

                'party_admin' => [
                    'name' => $c->admin_name ?: $adminName,
                    'title' => $adminTitle,
                    'company' => 'CV Transforma Alam Kreasi',
                    'source' => 'Aplikasi Kreavana',
                    'signature_url' => $c->admin_signature_url ?: $adminSignatureUrl,
                    'signed_at' => ($c->admin_signed_at ?? $adminSignedAt)->toIso8601String(),
                    'official_stamp' => 'TERVERIFIKASI CV TRANSFORMA ALAM KREASI — APLIKASI KREAVANA',
                ],

                'created_at' => $c->created_at?->toIso8601String(),
            ];
        })->values()->toArray();
    }

    public function submitReport(string $userId, array $data)
    {
        $data['reporter_id'] = $userId;
        $data['status'] = 'pending';
        $data['created_at'] = now();

        return $this->reportRepo->create($data);
    }

    private function formatOpportunity($opp, bool $includeFull = false, ?array $appliedLookup = null): array
    {
        $isAbove100Jt = self::isBudgetAbove100Jt($opp->budget_range, (float) ($opp->escrow_amount ?? 0));

        $data = [
            'id' => $opp->id,
            'has_applied' => $appliedLookup !== null ? isset($appliedLookup[$opp->id]) : false,
            'title' => $opp->title,
            'description' => $opp->description,
            'poster_url' => $opp->poster_url,
            'banner_url' => $opp->banner_url,
            'sub_role_slug' => $opp->sub_role_slug,
            'type' => $opp->type ?? 'project',
            'location' => $opp->location,
            'latitude' => $opp->latitude ? (float) $opp->latitude : null,
            'longitude' => $opp->longitude ? (float) $opp->longitude : null,
            'location_category' => $opp->location_category,
            'address' => $opp->address,
            'deadline' => $opp->deadline?->format('Y-m-d'),
            'event_date' => $opp->event_date?->format('Y-m-d'),
            'event_start_date' => $opp->event_start_date?->format('Y-m-d'),
            'event_end_date' => $opp->event_end_date?->format('Y-m-d'),
            'event_start_time' => $opp->event_start_time,
            'event_end_time' => $opp->event_end_time,
            'budget_range' => $opp->budget_range,
            'external_rating' => $opp->external_rating ? (float) $opp->external_rating : null,
            'external_rating_source' => $opp->external_rating_source,
            'external_proof_url' => $opp->external_proof_url,
            'status' => $opp->status,
            'meeting_date' => $opp->meeting_date?->format('Y-m-d'),
            'meeting_time' => $opp->meeting_time,
            'meeting_location' => $opp->meeting_location,
            'meeting_lat' => $opp->meeting_lat ? (float) $opp->meeting_lat : null,
            'meeting_lng' => $opp->meeting_lng ? (float) $opp->meeting_lng : null,
            'meeting_notes' => $opp->meeting_notes,
            'meeting_status' => $opp->meeting_status ?? 'not_required',
            'meeting_counter_by' => $opp->meeting_counter_by,
            'meeting_counter_date' => $opp->meeting_counter_date?->format('Y-m-d'),
            'meeting_counter_time' => $opp->meeting_counter_time,
            'meeting_counter_location' => $opp->meeting_counter_location,
            'meeting_counter_lat' => $opp->meeting_counter_lat ? (float) $opp->meeting_counter_lat : null,
            'meeting_counter_lng' => $opp->meeting_counter_lng ? (float) $opp->meeting_counter_lng : null,
            'meeting_counter_notes' => $opp->meeting_counter_notes,
            'meeting_counter_status' => $opp->meeting_counter_status,
            'escrow_status' => $opp->escrow_status ?? 'none',
            'signature_type' => $opp->signature_type ?? ($isAbove100Jt ? 'wet_signature' : 'dynamic_electronic'),
            'client_signature' => $opp->client_signature,
            'client_signed_at' => $opp->client_signed_at?->toIso8601String(),
            'wet_signature_document_url' => $opp->wet_signature_document_url,
            'wet_signature_verified_at' => $opp->wet_signature_verified_at?->toIso8601String(),
            'admin_started_at' => $opp->admin_started_at?->toIso8601String(),
            'auto_release_triggered_at' => $opp->auto_release_triggered_at?->toIso8601String(),
            'grace_period_deadline' => ($opp->event_end_date ?? $opp->event_date) ? \Carbon\Carbon::parse($opp->event_end_date ?? $opp->event_date)->addMonth()->toIso8601String() : null,
            'is_grace_period_active' => ($opp->event_end_date ?? $opp->event_date) ? \Carbon\Carbon::parse($opp->event_end_date ?? $opp->event_date)->isPast() && in_array($opp->status, ['in_progress', 'completed']) : false,
            'grace_period_days_left' => ($opp->event_end_date ?? $opp->event_date) ? max(0, (int) now()->diffInDays(\Carbon\Carbon::parse($opp->event_end_date ?? $opp->event_date)->addMonth(), false)) : 0,
            'escrow_amount' => (float) ($opp->escrow_amount ?? 0),
            'dynamic_terms' => $opp->dynamic_terms ?? [],
            'admin_name' => $opp->admin_name,
            'admin_signature_url' => $opp->admin_signature_url,
            'admin_signed_at' => $opp->admin_signed_at?->toIso8601String(),
            'is_wet_signature_required' => $isAbove100Jt,
            'is_dynamic_signature_required' => !$isAbove100Jt,
            'event_progress' => (int) ($opp->event_progress ?? 0),
            'posted_by' => $opp->posted_by,
            'created_at' => $opp->created_at?->toIso8601String(),
            'applications_count' => (int) ($opp->applications_count ?? ($opp->relationLoaded('applications') ? $opp->applications->count() : 0)),
        ];

        // Format required capabilities
        if ($opp->relationLoaded('requirements')) {
            $data['requirements'] = $opp->requirements->map(fn ($r) => [
                'id' => $r->id,
                'sub_role_slug' => $r->sub_role_slug,
                'quantity' => (int) $r->quantity,
                'notes' => $r->notes,
                'payment_scheme' => $r->payment_scheme ?? 'full_at_end',
                'payment_terms' => $r->payment_terms ?? [],
            ])->toArray();
        } else {
            $data['requirements'] = [
                [
                    'id' => null,
                    'sub_role_slug' => $opp->sub_role_slug,
                    'quantity' => 1,
                    'notes' => null,
                ]
            ];
        }

        // Format public approved creators (1 orang = 1 kontrak digital individu)
        if ($opp->relationLoaded('approvedApplications')) {
            $approvedCount = max(1, $opp->approvedApplications->count());
            $data['approved_creators'] = $opp->approvedApplications->map(function ($app) use ($opp, $approvedCount) {
                $clientSig = $app->client_signature ?? $opp->client_signature;
                $clientSignedAt = $app->client_signed_at ?? $opp->client_signed_at;
                $creatorSig = $app->creator_signature;
                $creatorSignedAt = $app->creator_signed_at;
                $contractNumber = $app->contract_number ?: self::generateContractNumber($opp->id, $app->id, $app->reviewed_at ?? $app->created_at);
                $agreedPrice = self::resolveIndividualAgreedPrice($opp, $app, $approvedCount);
                $resolvedTerms = !empty($app->dynamic_terms)
                    ? $app->dynamic_terms
                    : self::buildIndividualDefaultTerms($opp, $app, $agreedPrice);

                $studentName = '';
                $major = '';
                $docs = is_array($app->submitted_documents) ? $app->submitted_documents : [];
                if (isset($docs[0]) && is_array($docs[0])) {
                    $studentName = trim((string) ($docs[0]['participant_name'] ?? $docs[0]['student_name'] ?? $docs[0]['name'] ?? ''));
                    $major = trim((string) ($docs[0]['major_class'] ?? $docs[0]['major'] ?? $docs[0]['jurusan'] ?? ''));
                } elseif (isset($docs['participant_name']) || isset($docs['student_name']) || isset($docs['name'])) {
                    $studentName = trim((string) ($docs['participant_name'] ?? $docs['student_name'] ?? $docs['name'] ?? ''));
                    $major = trim((string) ($docs['major_class'] ?? $docs['major'] ?? $docs['jurusan'] ?? ''));
                }
                if ($studentName === '' && !empty($app->pitch_message) && (str_starts_with($app->pitch_message, 'Peserta:') || str_starts_with($app->pitch_message, 'Siswa:'))) {
                    $parts = array_map('trim', explode('|', $app->pitch_message));
                    $rawPrefix = str_starts_with($parts[0] ?? '', 'Peserta:') ? 'Peserta:' : 'Siswa:';
                    $head = trim(str_replace($rawPrefix, '', $parts[0] ?? ''));
                    if (preg_match('/^(.*?)\s*\((.*?)\)$/', $head, $pm)) {
                        $studentName = trim($pm[1]);
                        if ($major === '') $major = trim($pm[2]);
                    } else {
                        $studentName = $head;
                    }
                }

                return [
                    'id' => $app->creator?->id,
                    'application_id' => $app->id,
                    'name' => $app->creator?->name,
                    'student_name' => $studentName,
                    'student_major' => $major,
                    'submitted_documents' => $app->submitted_documents,
                    'pitch_message' => $app->pitch_message,
                    'username' => $app->creator?->username,
                    'avatar_url' => $app->creator?->avatar_url,
                    'sub_role' => is_string($app->creator?->sub_role) ? $app->creator?->sub_role : $app->creator?->sub_role?->value,
                    'capability' => $app->sub_role_slug,
                    'agreed_price' => $agreedPrice,
                    'contract_number' => $contractNumber,
                    'client_signature' => $clientSig,
                    'client_signed_at' => $clientSignedAt?->toIso8601String(),
                    'creator_signature' => $creatorSig,
                    'creator_signed_at' => $creatorSignedAt?->toIso8601String(),
                    'is_contract_final' => !empty($clientSig) && !empty($clientSignedAt) && !empty($creatorSig) && !empty($creatorSignedAt),
                    'dynamic_terms' => $resolvedTerms,
                ];
            })->filter(fn ($c) => !empty($c['id']))->values()->toArray();
        }

        // Include poster (posted_by) details without private phone/email
        if ($opp->relationLoaded('user') && $opp->user) {
            $data['poster'] = [
                'id' => $opp->user->id,
                'name' => $opp->user->name,
                'username' => $opp->user->username,
                'avatar_url' => $opp->user->avatar_url,
                'role' => is_string($opp->user->role) ? $opp->user->role : $opp->user->role?->value,
                'selected_sub_role' => is_string($opp->user->sub_role) ? $opp->user->sub_role : $opp->user->sub_role?->value,
                'is_verified' => (bool) $opp->user->is_verified,
                'verification_type' => $opp->user->verification_type,
            ];
        }

        return $data;
    }
}
