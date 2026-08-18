<?php

namespace App\Repositories;

use App\Models\User;

class UserRepository extends BaseRepository
{
    public function __construct(User $model)
    {
        parent::__construct($model);
    }

    public function findByEmailOrUsername(string $identifier): ?User
    {
        $field = filter_var($identifier, FILTER_VALIDATE_EMAIL) ? 'email' : 'username';
        return $this->model->where($field, $identifier)->first();
    }

    public function getRecommendedCreators(int $limit = 5)
    {
        return $this->model
            ->where('role', \App\Enums\RoleType::Creator)
            ->where('is_creator_approved', true)
            ->orderBy('performance_boost', 'desc')
            ->orderBy('created_at', 'desc')
            ->limit($limit)
            ->get();
    }
}
