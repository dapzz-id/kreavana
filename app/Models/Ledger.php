<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Attributes\Fillable;

#[Fillable(['user_id', 'amount_encrypted', 'hash_signature', 'previous_hash', 'transaction_type', 'reference_id'])]
class Ledger extends Model
{
    use HasFactory;

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Decrypted display amount — uses LedgerService to decrypt.
     * Safe for display only; do NOT use for balance arithmetic.
     */
    public function getDisplayAmountAttribute(): float
    {
        return app(\App\Services\LedgerService::class)->decryptForDisplay($this->amount_encrypted);
    }

    /**
     * Human-readable transaction type label (Bahasa Indonesia)
     */
    public function getTypeLabelAttribute(): string
    {
        return match ($this->transaction_type) {
            'deposit'    => 'Top Up',
            'purchase'   => 'Pembelian Foto',
            'earning'    => 'Pendapatan Penjualan',
            'withdrawal' => 'Penarikan Dana',
            default      => ucfirst($this->transaction_type),
        };
    }

    /**
     * Whether this is a credit (positive) transaction
     */
    public function getIsCreditAttribute(): bool
    {
        return in_array($this->transaction_type, ['deposit', 'earning']);
    }
}
