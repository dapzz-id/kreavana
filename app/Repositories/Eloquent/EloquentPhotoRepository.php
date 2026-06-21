<?php

namespace App\Repositories\Eloquent;

use App\Models\Photo;
use App\Repositories\Contracts\PhotoRepositoryInterface;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Pagination\LengthAwarePaginator;

class EloquentPhotoRepository implements PhotoRepositoryInterface
{
    public function findById(int $id): ?Photo
    {
        return Photo::find($id);
    }

    public function findByIdWithRelations(int $id, array $relations = []): ?Photo
    {
        return Photo::with($relations)->withCount('likes')->findOrFail($id);
    }

    public function latestFeed(int $perPage = 15): LengthAwarePaginator
    {
        return Photo::with('photographer')
            ->withCount('likes')
            ->latest()
            ->paginate($perPage);
    }

    public function getByPhotographer(int $userId): Collection
    {
        return Photo::where('user_id', $userId)
            ->withCount('likes')
            ->latest()
            ->get();
    }

    public function create(array $data): Photo
    {
        return Photo::create($data);
    }

    public function update(Photo $photo, array $data): bool
    {
        return $photo->update($data);
    }

    public function delete(Photo $photo): bool
    {
        return $photo->delete();
    }

    public function searchByTags(string $query): Collection
    {
        return Photo::with('photographer')
            ->withCount('likes')
            ->where(function ($q) use ($query) {
                $q->where('title', 'LIKE', "%{$query}%")
                  ->orWhere('description', 'LIKE', "%{$query}%")
                  ->orWhere('tags', 'LIKE', "%{$query}%");
            })
            ->latest()
            ->get();
    }
}
