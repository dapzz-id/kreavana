<?php

namespace App\Repositories\Eloquent;

use App\Models\Purchase;
use App\Repositories\Contracts\PurchaseRepositoryInterface;
use Illuminate\Database\Eloquent\Collection;

class EloquentPurchaseRepository implements PurchaseRepositoryInterface
{
    public function findById(int $id): ?Purchase
    {
        return Purchase::find($id);
    }

    public function create(array $data): Purchase
    {
        return Purchase::create($data);
    }

    public function update(Purchase $purchase, array $data): bool
    {
        return $purchase->update($data);
    }

    public function getByUser(int $userId): Collection
    {
        return Purchase::where('user_id', $userId)
            ->where('payment_status', 'completed')
            ->with('photo.photographer')
            ->latest()
            ->get();
    }

    public function getByPhotoIds(array $photoIds): Collection
    {
        return Purchase::whereIn('photo_id', $photoIds)
            ->where('payment_status', 'completed')
            ->get();
    }

    public function userHasPurchased(int $userId, int $photoId): bool
    {
        return Purchase::where('user_id', $userId)
            ->where('photo_id', $photoId)
            ->where('payment_status', 'completed')
            ->exists();
    }
}
