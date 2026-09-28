<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class WalletFee extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'transaction_type',
        'payment_provider_code',
        'fee_percent',
        'fee_flat_amount',
        'min_fee',
        'max_fee',
        'min_transaction_amount',
        'max_transaction_amount',
        'effective_from',
        'effective_to',
        'is_active',
        'meta',
    ];

    protected $casts = [
        'fee_percent'            => 'float',
        'fee_flat_amount'       => 'decimal:2',
        'min_fee'               => 'decimal:2',
        'max_fee'               => 'decimal:2',
        'min_transaction_amount' => 'decimal:2',
        'max_transaction_amount' => 'decimal:2',
        'effective_from'        => 'datetime',
        'effective_to'          => 'datetime',
        'is_active'             => 'boolean',
        'meta'                  => 'array',
    ];

    public function scopeActive($query)
    {
        return $query
            ->where('is_active', true)
            ->where(function ($q) {
                $q->whereNull('effective_from')->orWhere('effective_from', '<=', now());
            })
            ->where(function ($q) {
                $q->whereNull('effective_to')->orWhere('effective_to', '>=', now());
            });
    }

    public function scopeForType($query, string $type, ?string $providerCode = null)
    {
        $query->where('transaction_type', $type);

        if ($providerCode) {
            $query->where('payment_provider_code', $providerCode)
                ->orWhereNull('payment_provider_code');
        }

        return $query;
    }

    public function calculateFee(float $amount): array
    {
        $percentFee = $amount * ((float) $this->fee_percent / 100);
        $flatFee = (float) $this->fee_flat_amount;
        $totalFee = $percentFee + $flatFee;

        $minFee = (float) $this->min_fee;
        $maxFee = $this->max_fee !== null ? (float) $this->max_fee : null;

        if ($totalFee < $minFee) {
            $totalFee = $minFee;
        }
        if ($maxFee !== null && $totalFee > $maxFee) {
            $totalFee = $maxFee;
        }

        return [
            'fee_percent_amount' => round($percentFee, 2),
            'fee_flat_amount'    => round($flatFee, 2),
            'fee_total'          => round($totalFee, 2),
            'net_amount'         => round($amount - $totalFee, 2),
            'min_amount'         => (float) $this->min_transaction_amount,
            'max_amount'         => (float) $this->max_transaction_amount,
            'within_limits'      => $amount >= (float) $this->min_transaction_amount
                && $amount <= (float) $this->max_transaction_amount,
        ];
    }
}
