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

    public function getList(string|array $subRole = 'all', ?string $type = null, int $limit = 50, ?string $search = null)
    {
        $opportunities = $this->opportunityRepo->getList($subRole, $type, $limit, $search);
        
        return $opportunities->map(fn ($opp) => $this->formatOpportunity($opp, false));
    }

    public function getUserOpportunities(string $userId, int $limit = 50)
    {
        $opportunities = $this->opportunityRepo->getMyOpportunities($userId, $limit);

        return $opportunities->map(fn ($opp) => $this->formatOpportunity($opp, false));
    }

    public function getMapLocations(string|array $subRole = 'all', ?float $lat = null, ?float $lng = null, ?float $radiusKm = null)
    {
        $locations = $this->opportunityRepo->getMapLocations($subRole, $lat, $lng, $radiusKm);
        
        return $locations->map(fn ($opp) => $this->formatOpportunity($opp, false));
    }

    public function findById(string $id)
    {
        $opp = $this->opportunityRepo->findWithUser($id);
        
        if (!$opp) return null;
        
        return $this->formatOpportunity($opp, true);
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
                            'quantity' => (int) ($req['quantity'] ?? 1),
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

    public function applyToOpportunity(string $creatorId, string $opportunityId, array $data): array
    {
        return DB::transaction(function () use ($creatorId, $opportunityId, $data) {
            $creator = User::where('id', $creatorId)->firstOrFail();
            if ($creator->role !== RoleType::Creator && $creator->role !== RoleType::Admin) {
                abort(403, 'Hanya kreator terverifikasi yang dapat melamar proyek.');
            }

            $opp = Opportunity::where('id', $opportunityId)->lockForUpdate()->firstOrFail();
            if ($opp->status !== 'open') {
                abort(400, 'Peluang proyek ini sudah ditutup atau tidak menerima lamaran baru.');
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

            // Concurrency check: prevent duplicate application
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

            // Pelamar kerja WAJIB mengisi pengajuan tarif / nego fee
            if (empty($data['bid_price']) || (float) $data['bid_price'] <= 0) {
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
                'bid_price' => (float) $data['bid_price'],
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

        return $applications->map(function ($app) {
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
                'counter_offer_notes' => $app->counter_offer_notes,
                'counter_offer_status' => $app->counter_offer_status,
                'counter_offer_by' => $app->counter_offer_by ?? 'client',
                'payment_scheme' => $app->payment_scheme ?? 'full_at_end',
                'payment_terms' => $app->payment_terms ?? [],
                'paid_amount' => (float) ($app->paid_amount ?? 0),
                'payment_status' => $app->payment_status ?? 'unpaid',
                'worker_progress' => (int) ($app->worker_progress ?? 0),
                'worker_status' => $app->worker_status ?? 'assigned',
                'submitted_deliverables' => $app->submitted_deliverables ?? [],
                'grace_period_deadline' => $app->grace_period_deadline?->toIso8601String(),
                'auto_released_at' => $app->auto_released_at?->toIso8601String(),
                'creator_signature' => $app->creator_signature,
                'creator_signed_at' => $app->creator_signed_at?->toIso8601String(),
                'dynamic_terms' => $app->dynamic_terms ?? [],
                'status' => $app->status,
                'rejection_reason' => $app->rejection_reason,
                'reviewed_at' => $app->reviewed_at?->toIso8601String(),
                'created_at' => $app->created_at?->toIso8601String(),
            ];
        })->toArray();
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
     */
    public function signContract(string $opportunityId, string $userId, array $data): array
    {
        return DB::transaction(function () use ($opportunityId, $userId, $data) {
            $opp = Opportunity::where('id', $opportunityId)->lockForUpdate()->firstOrFail();
            $user = User::where('id', $userId)->firstOrFail();

            $isClient = ($opp->posted_by === $userId || $user->role === RoleType::Admin);

            // Cek apakah user adalah pekerja/kreator yang disetujui untuk acara ini (Pihak Kedua)
            $creatorApp = OpportunityApplication::where('opportunity_id', $opp->id)
                ->where('creator_id', $userId)
                ->where('status', 'approved')
                ->first();

            if (!$isClient && !$creatorApp) {
                abort(403, 'Hanya pihak bersepakat (pembuat acara atau pekerja kreatif yang disetujui) yang dapat menandatangani dokumen ini.');
            }

            $signature = $data['signature'] ?? $data['electronic_signature'] ?? null;
            if (empty($signature)) {
                abort(422, 'Data tanda tangan elektronik dynamic tidak boleh kosong.');
            }

            // Jika ada pembaruan ketentuan khusus dinamis (dynamic_terms)
            if (!empty($data['dynamic_terms'])) {
                $rawTerms = $data['dynamic_terms'];
                if (is_string($rawTerms)) {
                    $decoded = json_decode($rawTerms, true);
                    $rawTerms = is_array($decoded) ? $decoded : array_filter(array_map('trim', explode("\n", $rawTerms)));
                }
                if (is_array($rawTerms) && !empty($rawTerms)) {
                    $opp->dynamic_terms = array_values(array_filter(array_map('trim', $rawTerms)));
                }
            }

            if ($isClient) {
                $opp->signature_type = 'dynamic_electronic';
                $opp->client_signature = (string) $signature;
                $opp->client_signed_at = now();

                // Auto-input Pihak Ketiga: Admin Kreavana (Nama & Tanda Tangan Resmi)
                $adminName = SystemSetting::get('admin_contract_signer_name', 'Tim Legal & Penjamin Escrow Kreavana');
                $adminSignatureUrl = SystemSetting::get('admin_contract_signature_image', '/assets/images/kreavana_official_signature.png');
                $opp->admin_name = $adminName;
                $opp->admin_signature_url = $adminSignatureUrl;
                $opp->admin_signed_at = $opp->admin_signed_at ?: now();

                // Sinkronkan ke job_contracts jika sudah terbentuk
                JobContract::where('opportunity_id', $opp->id)->update([
                    'client_signature' => (string) $signature,
                    'client_signed_at' => now(),
                    'client_approved' => true,
                    'dynamic_terms' => $opp->dynamic_terms,
                    'admin_name' => $adminName,
                    'admin_signature_url' => $adminSignatureUrl,
                    'admin_signed_at' => $opp->admin_signed_at,
                ]);

                // Beritahu pekerja/kreator yang disetujui bahwa klien telah menandatangani kontrak
                $approvedApps = OpportunityApplication::where('opportunity_id', $opp->id)
                    ->where('status', 'approved')
                    ->get();
                foreach ($approvedApps as $app) {
                    $this->notificationRepo->create([
                        'user_id' => $app->creator_id,
                        'title' => 'Penyelenggara Telah Menandatangani Kontrak',
                        'message' => "Penyelenggara acara telah menandatangani Dokumen Kontrak Digital untuk proyek '{$opp->title}'. Silakan tinjau dan bubuhi tanda tangan Anda.",
                        'type' => 'project',
                        'data' => [
                            'opportunity_id' => $opp->id,
                        ],
                        'is_read' => false,
                        'created_at' => now(),
                    ]);
                }
            }

            if ($creatorApp) {
                $creatorApp->creator_signature = (string) $signature;
                $creatorApp->creator_signed_at = now();
                if (!empty($opp->dynamic_terms)) {
                    $creatorApp->dynamic_terms = $opp->dynamic_terms;
                }
                $creatorApp->save();

                // Sinkronkan ke job_contracts milik pekerja ini
                JobContract::where('opportunity_id', $opp->id)
                    ->where('creator_id', $userId)
                    ->update([
                        'creator_signature' => (string) $signature,
                        'creator_signed_at' => now(),
                        'creator_approved' => true,
                        'dynamic_terms' => $opp->dynamic_terms,
                    ]);

                // Beritahu pembuat event bahwa kreator telah menandatangani kontrak
                $this->notificationRepo->create([
                    'user_id' => $opp->posted_by,
                    'title' => 'Kontrak Digital Disetujui Pekerja',
                    'message' => "Pekerja kreatif ({$user->name}) telah menandatangani Dokumen Kontrak Digital untuk proyek '{$opp->title}'.",
                    'type' => 'project',
                    'data' => [
                        'opportunity_id' => $opp->id,
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
     */
    public function updateDynamicTerms(string $opportunityId, string $userId, array $dynamicTerms): array
    {
        return DB::transaction(function () use ($opportunityId, $userId, $dynamicTerms) {
            $opp = Opportunity::where('id', $opportunityId)->lockForUpdate()->firstOrFail();
            $user = User::where('id', $userId)->firstOrFail();

            $isClient = ($opp->posted_by === $userId || $user->role === RoleType::Admin);
            $isApprovedCreator = OpportunityApplication::where('opportunity_id', $opp->id)
                ->where('creator_id', $userId)
                ->where('status', 'approved')
                ->exists();

            if (!$isClient && !$isApprovedCreator) {
                abort(403, 'Hanya pihak bersepakat yang dapat memperbarui ketentuan khusus kontrak.');
            }

            $cleanedTerms = array_values(array_filter(array_map('trim', $dynamicTerms)));
            if (empty($cleanedTerms)) {
                abort(422, 'Ketentuan khusus tidak boleh kosong.');
            }

            $opp->dynamic_terms = $cleanedTerms;
            $opp->save();

            // Sinkronkan ke job_contracts jika ada
            JobContract::where('opportunity_id', $opp->id)->update([
                'dynamic_terms' => $cleanedTerms,
            ]);

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
                // Budget < 100jt: Wajib tanda tangan elektronik dynamic (Tripartite 3 Pihak)
                $dynamicSignature = $data['signature'] ?? $data['electronic_signature'] ?? $opp->client_signature ?? null;
                if (empty($dynamicSignature) && empty($opp->client_signed_at)) {
                    abort(422, 'Tidak dapat memulai acara: Dokumen kontrak digital belum ditandatangani oleh Pihak Pertama (Penyelenggara). Silakan tandatangani kontrak digital terlebih dahulu.');
                }

                // Cek apakah seluruh kreator yang disetujui telah menyetujui & menandatangani kontrak digital
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

                // Auto-input Pihak Ketiga: Admin Kreavana (Nama & Tanda Tangan Resmi)
                $adminName = SystemSetting::get('admin_contract_signer_name', 'Tim Legal & Penjamin Escrow Kreavana');
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

                $appDynamicTerms = $opp->dynamic_terms ?? [];
                if (!empty($app->counter_offer_notes)) {
                    $appDynamicTerms[] = 'Ketentuan Khusus Kesepakatan: ' . $app->counter_offer_notes;
                }
                if (!empty($app->questions_notes)) {
                    $appDynamicTerms[] = 'Catatan Fasilitas / Permintaan: ' . $app->questions_notes;
                }

                $contractNumber = 'KVN-CTR/' . date('Ymd') . '/' . strtoupper(substr($opp->id, 0, 4)) . '-' . strtoupper(substr($app->id, 0, 4));
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
        $app->save();

        // Sinkronisasi dengan JobContract
        JobContract::where('opportunity_id', $opp->id)
            ->where('creator_id', $app->creator_id)
            ->update([
                'worker_progress' => $clamped,
                'work_status' => $clamped >= 100 ? WorkStatus::Completed : WorkStatus::InProgress,
            ]);

        // Hitung rata-rata progress seluruh pekerja untuk event_progress
        $avgProgress = (int) OpportunityApplication::where('opportunity_id', $opp->id)
            ->where('status', 'approved')
            ->avg('worker_progress');
        $opp->event_progress = max($opp->event_progress, $avgProgress);
        if ($avgProgress >= 100) {
            $opp->status = 'completed';
        }
        $opp->save();

        // Kirim notifikasi ke lawan pihak
        $targetUserId = $isCreator ? $opp->posted_by : $app->creator_id;
        $updaterName = $user->name ?: 'Mitra';
        $this->notificationRepo->create([
            'user_id' => $targetUserId,
            'title' => 'Update Progress Pekerja (' . $clamped . '%)',
            'message' => $updaterName . ' telah memperbarui progress pengerjaan untuk posisi ' . ucwords(str_replace('_', ' ', $app->sub_role_slug)) . ' menjadi ' . $clamped . '%.' . ($notes ? ' Catatan: ' . $notes : ''),
            'type' => 'project',
            'data' => [
                'opportunity_id' => $opp->id,
                'application_id' => $app->id,
                'worker_progress' => $clamped,
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
        $app->save();

        // Sinkronisasi dengan JobContract
        JobContract::where('opportunity_id', $opp->id)
            ->where('creator_id', $app->creator_id)
            ->update([
                'deliverables' => $deliverables,
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

                $maxCapacity = $requirement ? (int) $requirement->quantity : 1;
                $approvedCount = OpportunityApplication::where('opportunity_id', $opp->id)
                    ->where('sub_role_slug', $application->sub_role_slug)
                    ->where('status', 'approved')
                    ->count();

                if ($approvedCount >= $maxCapacity) {
                    abort(422, "Kapasitas kebutuhan untuk posisi " . ucwords(str_replace('_', ' ', $application->sub_role_slug)) . " sudah terpenuhi ({$approvedCount}/{$maxCapacity}).");
                }

                $application->status = 'approved';
                if ($application->counter_offer_price && $application->counter_offer_status !== 'declined') {
                    $application->counter_offer_status = 'accepted';
                }
                $application->reviewed_at = now();
                $application->save();

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

        $contracts = JobContract::where('opportunity_id', $opportunityId)
            ->with(['client', 'creator'])
            ->get();

        $defaultTerms = [
            'Penyelenggara (Pihak Pertama) wajib menyediakan akses lokasi, jadwal rundown yang jelas, dan koordinasi teknis di venue.',
            'Penyediaan fasilitas dan alat kerja utama (seperti kamera, lensa, instrumen, dll) disepakati tertulis antara pembuat event dan pekerja.',
            'Pekerja (Pihak Kedua) berkewajiban hadir tepat waktu dan menyerahkan hasil kerja sesuai standar profesional yang disepakati.',
            'Honorarium kerja diamankan 100% pada sistem Escrow Rekber Kreavana (Pihak Ketiga) dan hanya dicairkan setelah hasil pekerjaan disetujui.',
        ];

        $adminName = $opp->admin_name ?: SystemSetting::get('admin_contract_signer_name', 'Tim Legal & Penjamin Escrow Kreavana');
        $adminTitle = SystemSetting::get('admin_contract_signer_title', 'Otoritas Penjamin Transaksi PT Kreavana Digital Indonesia');
        $adminSignatureUrl = $opp->admin_signature_url ?: SystemSetting::get('admin_contract_signature_image', '/assets/images/kreavana_official_signature.png');
        $adminSignedAt = $opp->admin_signed_at ?: now();

        return $contracts->map(function ($c) use ($opp, $defaultTerms, $adminName, $adminTitle, $adminSignatureUrl, $adminSignedAt) {
            $creator = $c->creator;
            $client = $c->client ?: $opp->user;

            return [
                'id' => $c->id,
                'contract_number' => $c->contract_number ?? ('KVN-CTR/' . date('Ymd') . '/' . strtoupper(substr($c->id, 0, 8))),
                'opportunity_id' => $opp->id,
                'title' => $c->title,
                'description' => $c->description,
                'agreed_price' => (float) $c->agreed_price,
                'escrow_amount' => (float) $c->escrow_amount,
                'contract_status' => is_string($c->contract_status) ? $c->contract_status : ($c->contract_status?->value ?? 'escrow_paid'),
                'work_status' => is_string($c->work_status) ? $c->work_status : ($c->work_status?->value ?? 'in_progress'),
                'dynamic_terms' => $c->dynamic_terms ?: ($opp->dynamic_terms ?: $defaultTerms),
                'payment_scheme' => $c->payment_scheme ?? 'full_at_end',
                'payment_terms' => $c->payment_terms ?? [],
                'paid_amount' => (float) ($c->paid_amount ?? 0),
                'payment_status' => $c->payment_status ?? 'unpaid',
                'worker_progress' => (int) ($c->worker_progress ?? 0),
                'deliverables' => $c->deliverables ?? [],
                'grace_period_deadline' => $c->grace_period_deadline?->toIso8601String(),
                'auto_released_at' => $c->auto_released_at?->toIso8601String(),
                
                // Pihak Pertama: Pembuat Event (Klien)
                'party_client' => [
                    'id' => $client?->id ?? $opp->posted_by,
                    'name' => $client?->name ?? 'Pembuat Event',
                    'username' => $client?->username ?? 'client',
                    'role' => is_string($client?->role) ? $client?->role : ($client?->role?->value ?? 'client'),
                    'signature' => $c->client_signature ?? $opp->client_signature,
                    'signed_at' => ($c->client_signed_at ?? $opp->client_signed_at)?->toIso8601String(),
                ],

                // Pihak Kedua: Pelamar / Pekerja (Kreator)
                'party_creator' => [
                    'id' => $creator?->id,
                    'name' => $creator?->name ?? 'Pekerja Kreator',
                    'username' => $creator?->username ?? 'creator',
                    'sub_role' => is_string($creator?->sub_role) ? $creator?->sub_role : ($creator?->sub_role?->value ?? $opp->sub_role_slug),
                    'signature' => $c->creator_signature ?: ('SIG-CREATOR-' . strtoupper(substr(md5(($creator?->id ?? '') . $opp->id), 0, 10))),
                    'signed_at' => ($c->creator_signed_at ?? $c->creator_approved_at ?? $opp->client_signed_at ?? now())->toIso8601String(),
                ],

                // Pihak Ketiga: Admin Kreavana (Penjamin Escrow & Legal Platform)
                'party_admin' => [
                    'name' => $c->admin_name ?: $adminName,
                    'title' => $adminTitle,
                    'signature_url' => $c->admin_signature_url ?: $adminSignatureUrl,
                    'signed_at' => ($c->admin_signed_at ?? $adminSignedAt)->toIso8601String(),
                    'official_stamp' => 'TERVERIFIKASI & TERJAMIN ESCROW KREAVANA',
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

    private function formatOpportunity($opp, bool $includeFull = false): array
    {
        $isAbove100Jt = self::isBudgetAbove100Jt($opp->budget_range, (float) ($opp->escrow_amount ?? 0));

        $data = [
            'id' => $opp->id,
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

        // Format public approved creators
        if ($opp->relationLoaded('approvedApplications')) {
            $data['approved_creators'] = $opp->approvedApplications->map(function ($app) {
                return [
                    'id' => $app->creator?->id,
                    'name' => $app->creator?->name,
                    'username' => $app->creator?->username,
                    'avatar_url' => $app->creator?->avatar_url,
                    'sub_role' => is_string($app->creator?->sub_role) ? $app->creator?->sub_role : $app->creator?->sub_role?->value,
                    'capability' => $app->sub_role_slug,
                    'creator_signature' => $app->creator_signature,
                    'creator_signed_at' => $app->creator_signed_at?->toIso8601String(),
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
