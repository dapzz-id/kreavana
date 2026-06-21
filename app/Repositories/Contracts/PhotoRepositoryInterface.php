<?php

namespace App\Repositories\Contracts;

use App\Models\Photo;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Pagination\LengthAwarePaginator;

interface PhotoRepositoryInterface
{
    public function findById(int $id): ?Photo;
    public function findByIdWithRelations(int $id, array $relations = []): ?Photo;
    public function latestFeed(int $perPage = 15): LengthAwarePaginator;
    public function getByPhotographer(int $userId): Collection;
    public function create(array $data): Photo;
    public function update(Photo $photo, array $data): bool;
    public function delete(Photo $photo): bool;
    public function searchByTags(string $query): Collection;
}
