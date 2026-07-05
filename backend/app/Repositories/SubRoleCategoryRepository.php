<?php

namespace App\Repositories;

use App\Models\SubRoleCategory;

class SubRoleCategoryRepository extends BaseRepository
{
    public function __construct(SubRoleCategory $model)
    {
        parent::__construct($model);
    }

    public function findBySlug(string $slug): ?SubRoleCategory
    {
        return $this->model->where('slug', $slug)->first();
    }
}
