<?php

namespace App\Services;

use App\Repositories\OpportunityRepository;
use App\Repositories\ReportRepository;
use App\Repositories\NotificationRepository;
use Illuminate\Support\Facades\Cache;

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

    public function getList(string $subRoleSlug = 'all', ?string $type = null, int $limit = 50)
    {
        $opportunities = $this->opportunityRepo->getList($subRoleSlug, $type, $limit);
        
        return $opportunities->map(fn ($opp) => $this->formatOpportunity($opp, false));
    }

    public function getMapLocations(string $subRoleSlug = 'all')
    {
        $locations = $this->opportunityRepo->getMapLocations($subRoleSlug);
        
        return $locations->map(fn ($opp) => $this->formatOpportunity($opp, false));
    }

    public function findById(int $id)
    {
        $opp = $this->opportunityRepo->findWithUser($id);
        
        if (!$opp) return null;
        
        return $this->formatOpportunity($opp, true);
    }

    public function createOpportunity(string $userId, array $data)
    {
        $data['status'] = 'open';
        $data['posted_by'] = $userId;
        $data['created_at'] = now();

        $opp = $this->opportunityRepo->create($data);

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

        return $this->formatOpportunity($opp, false);
    }

    public function submitReport(string $userId, array $data)
    {
        $data['reporter_id'] = $userId;
        $data['status'] = 'pending';
        $data['created_at'] = now();

        return $this->reportRepo->create($data);
    }

    private function formatOpportunity($opp, bool $includePoster = false): array
    {
        $data = [
            'id' => $opp->id,
            'title' => $opp->title,
            'description' => $opp->description,
            'sub_role_slug' => $opp->sub_role_slug,
            'type' => $opp->type ?? 'project',
            'location' => $opp->location,
            'latitude' => $opp->latitude ? (float) $opp->latitude : null,
            'longitude' => $opp->longitude ? (float) $opp->longitude : null,
            'location_category' => $opp->location_category,
            'address' => $opp->address,
            'deadline' => $opp->deadline?->format('Y-m-d'),
            'budget_range' => $opp->budget_range,
            'status' => $opp->status,
            'posted_by' => $opp->posted_by,
            'created_at' => $opp->created_at?->toIso8601String(),
        ];

        // Include poster details if the user relation is loaded
        if ($opp->relationLoaded('user') && $opp->user) {
            $data['poster'] = [
                'id' => $opp->user->id,
                'name' => $opp->user->name,
                'username' => $opp->user->username,
                'phone' => $opp->user->phone,
                'email' => $opp->user->email,
                'avatar_url' => $opp->user->avatar_url,
                'selected_sub_role' => $opp->user->selected_sub_role ?? null,
            ];
        }

        return $data;
    }
}
