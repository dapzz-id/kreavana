<?php

namespace App\Repositories;

use App\Models\DashboardStat;

class DashboardStatRepository extends BaseRepository
{
    public function __construct(DashboardStat $model)
    {
        parent::__construct($model);
    }

    public function getStats(string $subRoleSlug, string $roleType)
    {
        return $this->model->where('sub_role_slug', $subRoleSlug)
            ->where('role_type', $roleType)
            ->orderBy('display_order')
            ->get();
    }
}
