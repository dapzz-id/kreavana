<?php

namespace App\Repositories\Contracts;

use App\Models\Ledger;
use Illuminate\Database\Eloquent\Collection;

interface LedgerRepositoryInterface
{
    public function getLastEntryForUser(int $userId): ?Ledger;
    public function create(array $data): Ledger;
    public function getAllForUser(int $userId): Collection;
    public function countForUser(int $userId): int;
}
