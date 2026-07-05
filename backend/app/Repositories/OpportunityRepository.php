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
        $query = $this->model->where('status', 'open');

        if ($subRoleSlug !== 'all') {
            $query->where('sub_role_slug', $subRoleSlug);
        }

        if ($type) {
            $query->where('type', $type);
        }

        return $query->orderBy('created_at', 'desc')->limit($limit)->get();
    }

    public function getMapLocations(string $subRoleSlug = 'all')
    {
        $query = $this->model->where('status', 'open')
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
}
