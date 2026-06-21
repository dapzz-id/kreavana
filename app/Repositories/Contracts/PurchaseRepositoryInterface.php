<?php

namespace App\Repositories\Contracts;

use App\Models\Purchase;
use Illuminate\Database\Eloquent\Collection;

interface PurchaseRepositoryInterface
{
    public function findById(int $id): ?Purchase;
    public function create(array $data): Purchase;
    public function update(Purchase $purchase, array $data): bool;
    public function getByUser(int $userId): Collection;
    public function getByPhotoIds(array $photoIds): Collection;
    public function userHasPurchased(int $userId, int $photoId): bool;
}
