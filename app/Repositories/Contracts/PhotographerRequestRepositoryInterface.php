<?php

namespace App\Repositories\Contracts;

use App\Models\PhotographerRequest;
use Illuminate\Database\Eloquent\Collection;

interface PhotographerRequestRepositoryInterface
{
    public function findById(int $id): ?PhotographerRequest;
    public function allPending(): Collection;
    public function getForUser(int $userId): ?PhotographerRequest;
    public function hasPendingRequest(int $userId): bool;
    public function create(array $data): PhotographerRequest;
    public function update(PhotographerRequest $request, array $data): bool;
}
