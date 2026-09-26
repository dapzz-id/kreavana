<?php

namespace App\Services;

use App\Repositories\OpportunityRepository;
use App\Repositories\ReportRepository;
use App\Repositories\NotificationRepository;
use App\Models\Opportunity;
use App\Models\OpportunityRequirement;
use App\Models\OpportunityApplication;
use App\Models\User;
use App\Enums\RoleType;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
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
            $data['status'] = 'open';
            $data['posted_by'] = $userId;
            $data['created_at'] = now();

            // Handle poster image upload securely
            if ($posterFile && $posterFile->isValid()) {
                $user = User::find($userId);
                /** @var \App\Services\StorageService $storageService */
                $storageService = app(\App\Services\StorageService::class);
                $storageFile = $storageService->store($user, $posterFile, 'posters', 'public');
                $data['poster_url'] = '/storage/' . $storageFile->path;
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

            $application = OpportunityApplication::create([
                'opportunity_id' => $opportunityId,
                'creator_id' => $creatorId,
                'sub_role_slug' => $subRoleSlug,
                'pitch_message' => $data['pitch_message'],
                'questions_notes' => $data['questions_notes'] ?? null,
                'bid_price' => $data['bid_price'] ?? null,
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

        // Only owner, admin, or marketing can view all applicants
        if ($opp->posted_by !== $userId && $user->role !== RoleType::Admin && $user->role !== RoleType::Marketing) {
            abort(403, 'Akses ditolak. Anda bukan pemilik proyek ini.');
        }

        $applications = OpportunityApplication::with([
            'creator:id,name,username,avatar_url,sub_role,rating,subscription_tier,is_verified,completed_projects_count'
        ])
            ->where('opportunity_id', $opportunityId)
            ->orderBy('created_at', 'desc')
            ->get();

        return $applications->map(function ($app) {
            return [
                'id' => $app->id,
                'opportunity_id' => $app->opportunity_id,
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
                'bid_price' => $app->bid_price,
                'status' => $app->status,
                'rejection_reason' => $app->rejection_reason,
                'reviewed_at' => $app->reviewed_at?->toIso8601String(),
                'created_at' => $app->created_at?->toIso8601String(),
            ];
        })->toArray();
    }

    public function startEvent(string $opportunityId, string $userId): array
    {
        return DB::transaction(function () use ($opportunityId, $userId) {
            $opp = Opportunity::where('id', $opportunityId)->lockForUpdate()->firstOrFail();
            $user = User::where('id', $userId)->firstOrFail();

            if ($opp->posted_by !== $userId && $user->role !== RoleType::Admin) {
                abort(403, 'Hanya pembuat proyek yang dapat memulai acara.');
            }

            if ($opp->status === 'in_progress') {
                abort(400, 'Acara sudah dimulai dan sedang berlangsung.');
            }

            // Must have at least 1 approved creator to start event
            $approvedCount = OpportunityApplication::where('opportunity_id', $opp->id)
                ->where('status', 'approved')
                ->count();

            if ($approvedCount === 0) {
                abort(422, 'Tidak dapat memulai acara: Belum ada kreator yang disetujui (minimal 1 kreator).');
            }

            $opp->status = 'in_progress';
            if ($opp->event_progress == 0) {
                $opp->event_progress = 30; // Start at 30% (Persiapan Selesai, Acara Dimulai)
            }
            $opp->save();

            // Notify all approved creators that the event has started!
            $approvedCreators = OpportunityApplication::where('opportunity_id', $opp->id)
                ->where('status', 'approved')
                ->pluck('creator_id');

            foreach ($approvedCreators as $creatorId) {
                $this->notificationRepo->create([
                    'user_id' => $creatorId,
                    'title' => 'Acara Telah Dimulai!',
                    'message' => 'Acara "' . $opp->title . '" resmi dimulai. Silakan mulai koordinasi dan serahkan dokumen/hasil karya.',
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
        if ($clampedProgress >= 100) {
            $opp->status = 'completed';
        }
        $opp->save();

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
        $opp->meeting_status = 'pending_marketing_review';
        $opp->save();

        return $this->formatOpportunity($opp->fresh(['approvedApplications.creator', 'user']), true);
    }

    public function reviewApplication(string $applicationId, string $userId, string $decision, ?string $reason = null): array
    {
        return DB::transaction(function () use ($applicationId, $userId, $decision, $reason) {
            $application = OpportunityApplication::where('id', $applicationId)->lockForUpdate()->firstOrFail();
            $opp = Opportunity::where('id', $application->opportunity_id)->lockForUpdate()->firstOrFail();
            $user = User::where('id', $userId)->firstOrFail();

            if ($opp->posted_by !== $userId && $user->role !== RoleType::Admin) {
                abort(403, 'Akses ditolak. Anda tidak memiliki wewenang untuk meninjau lamaran ini.');
            }

            if ($application->status !== 'pending') {
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
                    ->lockForUpdate()
                    ->count();

                if ($approvedCount >= $maxCapacity) {
                    abort(422, "Kapasitas kebutuhan untuk posisi " . ucwords(str_replace('_', ' ', $application->sub_role_slug)) . " sudah terpenuhi ({$approvedCount}/{$maxCapacity}).");
                }

                $application->status = 'approved';
                $application->reviewed_at = now();
                $application->save();

                // Notify creator
                $this->notificationRepo->create([
                    'user_id' => $application->creator_id,
                    'title' => 'Lamaran Proyek Disetujui!',
                    'message' => 'Selamat! Lamaran Anda untuk proyek "' . $opp->title . '" telah disetujui oleh pemilik proyek.',
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
            } else {
                abort(422, 'Keputusan tidak valid. Pilihan: approve atau reject.');
            }

            return [
                'id' => $application->id,
                'status' => $application->status,
                'reviewed_at' => $application->reviewed_at?->toIso8601String(),
                'rejection_reason' => $application->rejection_reason,
            ];
        });
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
            'status' => $opp->status,
            'meeting_date' => $opp->meeting_date?->format('Y-m-d'),
            'meeting_time' => $opp->meeting_time,
            'meeting_location' => $opp->meeting_location,
            'meeting_lat' => $opp->meeting_lat ? (float) $opp->meeting_lat : null,
            'meeting_lng' => $opp->meeting_lng ? (float) $opp->meeting_lng : null,
            'meeting_notes' => $opp->meeting_notes,
            'meeting_status' => $opp->meeting_status ?? 'not_required',
            'escrow_status' => $opp->escrow_status ?? 'none',
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
