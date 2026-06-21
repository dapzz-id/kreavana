<?php

namespace App\Repositories\Eloquent;

use App\Models\Role;
use App\Repositories\Contracts\RoleRepositoryInterface;
use Illuminate\Database\Eloquent\Collection;

class EloquentRoleRepository implements RoleRepositoryInterface
{
    public function findBySlug(string $slug): ?Role
    {
        return Role::where('slug', $slug)->first();
    }

    public function all(): Collection
    {
        return Role::all();
    }
}
