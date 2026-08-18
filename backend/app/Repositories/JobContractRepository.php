<?php

namespace App\Repositories;

use App\Models\JobContract;

class JobContractRepository extends BaseRepository
{
    public function __construct(JobContract $model)
    {
        parent::__construct($model);
    }

    public function getByUserId(string $userId, int $limit = 50)
    {
        return $this->model
            ->where(function ($query) use ($userId) {
                $query->where('client_id', $userId)
                      ->orWhere('creator_id', $userId);
            })
            ->with(['client:id,name,username,avatar_url', 'creator:id,name,username,avatar_url'])
            ->orderBy('created_at', 'desc')
            ->limit($limit)
            ->get();
    }
}
