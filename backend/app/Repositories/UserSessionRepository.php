<?php

namespace App\Repositories;

use App\Models\UserSession;

class UserSessionRepository extends BaseRepository
{
    public function __construct(UserSession $model)
    {
        parent::__construct($model);
    }

    public function deleteByToken(string $sessionToken): bool
    {
        return $this->model->where('session_token', $sessionToken)->delete() > 0;
    }

    public function findBySessionAndRefresh(string $sessionToken, string $refreshToken): ?UserSession
    {
        return $this->model->where('session_token', $sessionToken)
                           ->where('refresh_token', $refreshToken)
                           ->first();
    }
}
