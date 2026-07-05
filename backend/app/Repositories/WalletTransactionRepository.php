<?php

namespace App\Repositories;

use App\Models\WalletTransaction;
use Illuminate\Pagination\LengthAwarePaginator;

class WalletTransactionRepository extends BaseRepository
{
    public function __construct(WalletTransaction $model)
    {
        parent::__construct($model);
    }

    public function getHistoryByUser(string $userId, ?int $year = null, int $perPage = 15): LengthAwarePaginator
    {
        $query = $this->model->where('user_id', $userId)
            ->orderBy('created_at', 'desc');

        if ($year) {
            $query->whereYear('created_at', $year);
        }

        return $query->paginate($perPage);
    }
}
