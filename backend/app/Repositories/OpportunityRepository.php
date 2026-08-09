<?php

namespace App\Repositories;

use App\Models\Opportunity;

class OpportunityRepository extends BaseRepository
{
    public function __construct(Opportunity $model)
    {
        parent::__construct($model);
    }

    public function getList(string $subRoleSlug = 'all', ?string $type = null, int $limit = 50)
    {
        $query = $this->model->with('user:id,name,username,phone,email,avatar_url,selected_sub_role');

        if ($subRoleSlug !== 'all') {
            $query->where('sub_role_slug', $subRoleSlug);
        }

        if ($type) {
            $query->where('type', $type);
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

    public function getMapLocations(string $subRoleSlug = 'all')
    {
        $query = $this->model->with('user:id,name,username,phone,email,avatar_url,selected_sub_role')
            ->where('status', 'open')
            ->where('type', 'location')
            ->whereNotNull('latitude')
            ->whereNotNull('longitude');

        if ($subRoleSlug !== 'all') {
            $query->where('sub_role_slug', $subRoleSlug);
        }

        return $query->get();
    }

    public function findWithUser(int $id)
    {
        return $this->model->with('user:id,name,username,phone,email,avatar_url,selected_sub_role')->find($id);
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
