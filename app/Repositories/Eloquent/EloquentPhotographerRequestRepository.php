<?php

namespace App\Repositories\Eloquent;

use App\Models\PhotographerRequest;
use App\Repositories\Contracts\PhotographerRequestRepositoryInterface;
use Illuminate\Database\Eloquent\Collection;

class EloquentPhotographerRequestRepository implements PhotographerRequestRepositoryInterface
{
    public function findById(int $id): ?PhotographerRequest
    {
        return PhotographerRequest::find($id);
    }

    public function allPending(): Collection
    {
        return PhotographerRequest::with('user')
            ->where('status', 'pending')
            ->latest()
            ->get();
    }

    public function getForUser(int $userId): ?PhotographerRequest
    {
        return PhotographerRequest::where('user_id', $userId)
            ->latest()
            ->first();
    }

    public function hasPendingRequest(int $userId): bool
    {
        return PhotographerRequest::where('user_id', $userId)
            ->where('status', 'pending')
            ->exists();
    }

    public function create(array $data): PhotographerRequest
    {
        return PhotographerRequest::create($data);
    }

    public function update(PhotographerRequest $request, array $data): bool
    {
        return $request->update($data);
    }
}
