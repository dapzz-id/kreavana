<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;

#[Fillable([
    'user_id',
    'type',
    'amount',
    'fee',
    'payment_method',
    'payment_provider',
    'status',
    'reference_number',
    'description',
    'ledger_hash',
])]
class WalletTransaction extends Model
{
    use HasUuids, HasFactory;

    /**
     * Hitung tanda tangan kriptografis HMAC-SHA256 untuk memastikan integritas mutasi ledger.
     */
    public function generateLedgerHash(): string
    {
        $payload = implode('|', [
            $this->id ?? '',
            $this->user_id,
            number_format((float) $this->amount, 2, '.', ''),
            $this->type,
            $this->reference_number,
            $this->status,
        ]);

        return hash_hmac('sha256', $payload, config('app.key') ?: 'kreavana_cryptographic_ledger_seed');
    }

    /**
     * Cek apakah hash ledger transaksi valid dan belum dimanipulasi di database.
     */
    public function isLedgerHashValid(): bool
    {
        if (empty($this->ledger_hash)) {
            return false;
        }

        return hash_equals($this->generateLedgerHash(), $this->ledger_hash);
    }

    /**
     * Get the user that owns the transaction.
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
