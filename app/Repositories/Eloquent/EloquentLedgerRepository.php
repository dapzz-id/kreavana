<?php

namespace App\Repositories\Eloquent;

use App\Models\Ledger;
use App\Repositories\Contracts\LedgerRepositoryInterface;
use Illuminate\Database\Eloquent\Collection;

class EloquentLedgerRepository implements LedgerRepositoryInterface
{
    public function getLastEntryForUser(int $userId): ?Ledger
    {
        return Ledger::where('user_id', $userId)->latest()->first();
    }

    public function create(array $data): Ledger
    {
        return Ledger::create($data);
    }

    public function getAllForUser(int $userId): Collection
    {
        return Ledger::where('user_id', $userId)->latest()->get();
    }

    public function countForUser(int $userId): int
    {
        return Ledger::where('user_id', $userId)->count();
    }
}
