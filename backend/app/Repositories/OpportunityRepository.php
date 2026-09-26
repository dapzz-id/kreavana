<?php

namespace App\Repositories;

use App\Models\Opportunity;

class OpportunityRepository extends BaseRepository
{
    public function __construct(Opportunity $model)
    {
        parent::__construct($model);
    }

    public function getList(string|array $subRole = 'all', ?string $type = null, int $limit = 50, ?string $search = null)
    {
        $query = $this->model->with([
            'user:id,name,username,avatar_url,sub_role',
            'requirements',
            'approvedApplications.creator:id,name,username,avatar_url,sub_role',
        ]);

        $subRoles = is_array($subRole) ? array_filter($subRole) : ($subRole !== 'all' ? [$subRole] : []);
        if (!empty($subRoles)) {
            $query->where(function ($q) use ($subRoles) {
                $q->whereIn('sub_role_slug', $subRoles)
                  ->orWhereHas('requirements', function ($rq) use ($subRoles) {
                      $rq->whereIn('sub_role_slug', $subRoles);
                  });
            });
        }

        if ($type) {
            $query->where('type', $type);
        }

        if ($search) {
            $searchTerm = '%' . strtolower($search) . '%';
            $query->where(function ($q) use ($searchTerm) {
                $q->whereRaw('LOWER(title) LIKE ?', [$searchTerm])
                  ->orWhereRaw('LOWER(description) LIKE ?', [$searchTerm])
                  ->orWhereRaw('LOWER(location) LIKE ?', [$searchTerm])
                  ->orWhereRaw('LOWER(COALESCE(address, \'\')) LIKE ?', [$searchTerm])
                  ->orWhereHas('requirements', function ($rq) use ($searchTerm) {
                      $rq->whereRaw('LOWER(COALESCE(notes, \'\')) LIKE ?', [$searchTerm])
                         ->orWhereRaw('LOWER(sub_role_slug) LIKE ?', [$searchTerm]);
                  });
            });
        }

        return $query->where('status', 'open')
            ->orderBy('created_at', 'desc')
            ->limit($limit)
            ->get();
    }

    public function countByUser(string $userId): int
    {
        return $this->model->where('posted_by', $userId)->count();
    }

    public function countActiveByUser(string $userId): int
    {
        return $this->model->where('posted_by', $userId)
            ->where('status', 'open')
            ->count();
    }

    public function getMapLocations(string|array $subRole = 'all', ?float $lat = null, ?float $lng = null, ?float $radiusKm = null)
    {
        $query = $this->model->with([
            'user:id,name,username,avatar_url,sub_role',
            'requirements',
        ])
            ->where('status', 'open')
            ->where('type', 'location')
            ->whereNotNull('latitude')
            ->whereNotNull('longitude');

        $subRoles = is_array($subRole) ? array_filter($subRole) : ($subRole !== 'all' ? [$subRole] : []);
        if (!empty($subRoles)) {
            $query->where(function ($q) use ($subRoles) {
                $q->whereIn('sub_role_slug', $subRoles)
                  ->orWhereHas('requirements', function ($rq) use ($subRoles) {
                      $rq->whereIn('sub_role_slug', $subRoles);
                  });
            });
        }

        if ($lat !== null && $lng !== null && $radiusKm !== null && $radiusKm > 0) {
            $latDelta = $radiusKm / 111.0;
            $cosLat = cos(deg2rad($lat));
            $lngDelta = $radiusKm / (111.0 * ($cosLat != 0 ? abs($cosLat) : 1.0));

            $query->whereBetween('latitude', [$lat - $latDelta, $lat + $latDelta])
                  ->whereBetween('longitude', [$lng - $lngDelta, $lng + $lngDelta]);
        }

        return $query->get();
    }

    public function findWithUser(string $id)
    {
        return $this->model->with([
            'user:id,name,username,avatar_url,sub_role',
            'requirements',
            'approvedApplications.creator:id,name,username,avatar_url,sub_role',
        ])->find($id);
    }

    public function getMyOpportunities(string $userId, int $limit = 50)
    {
        return $this->model->with([
            'requirements',
            'approvedApplications.creator:id,name,username,avatar_url,sub_role',
            'user:id,name,username,avatar_url,sub_role',
        ])
        ->withCount('applications')
        ->where('posted_by', $userId)
        ->orderBy('created_at', 'desc')
        ->limit($limit)
        ->get();
    }

    public function getByUser(string $userId, ?string $status = null, string $orderBy = 'created_at', string $direction = 'desc', int $limit = 5)
    {
        $query = $this->model->where('posted_by', $userId);

        if ($status) {
            $query->where('status', $status);
        }

        return $query->orderBy($orderBy, $direction)->limit($limit)->get();
    }

    public function getUpcomingByUser(string $userId, int $limit = 5)
    {
        return $this->model
            ->where('posted_by', $userId)
            ->whereNotNull('deadline')
            ->where('deadline', '>=', now())
            ->orderBy('deadline', 'asc')
            ->limit($limit)
            ->get();
    }
}
