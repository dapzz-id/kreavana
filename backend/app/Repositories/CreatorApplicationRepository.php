<?php

namespace App\Repositories;

use App\Models\CreatorApplication;

class CreatorApplicationRepository extends BaseRepository
{
    public function __construct(CreatorApplication $model)
    {
        parent::__construct($model);
    }

    public function findLatestByUserId(string $userId): ?CreatorApplication
    {
        return $this->model->where('user_id', $userId)->orderBy('applied_at', 'desc')->first();
    }

    public function findPendingByUserId(string $userId): ?CreatorApplication
    {
        return $this->model->where('user_id', $userId)
            ->where('status', 'pending')
            ->first();
    }
}
