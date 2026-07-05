<?php

namespace App\Repositories;

use App\Models\UserSubRole;

class UserSubRoleRepository extends BaseRepository
{
    public function __construct(UserSubRole $model)
    {
        parent::__construct($model);
    }
}
