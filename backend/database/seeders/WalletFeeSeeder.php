<?php

namespace Database\Seeders;

use App\Models\WalletFee;
use Illuminate\Database\Seeder;

class WalletFeeSeeder extends Seeder
{
    public function run(): void
    {
        $fees = [
            [
                'transaction_type'     => 'withdraw',
                'payment_provider_code' => null,
                'fee_percent'          => 5.00,
                'fee_flat_amount'      => 0,
                'min_fee'              => 1000,
                'max_fee'              => null,
                'min_transaction_amount' => 10000,
                'max_transaction_amount' => 500000000,
                'effective_from'       => now(),
                'is_active'            => true,
            ],
            [
                'transaction_type'     => 'topup',
                'payment_provider_code' => null,
                'fee_percent'          => 0.00,
                'fee_flat_amount'      => 0,
                'min_fee'              => 0,
                'max_fee'              => null,
                'min_transaction_amount' => 10000,
                'max_transaction_amount' => 500000000,
                'effective_from'       => now(),
                'is_active'            => true,
            ],
            [
                'transaction_type'     => 'transfer',
                'payment_provider_code' => null,
                'fee_percent'          => 0.50,
                'fee_flat_amount'      => 500,
                'min_fee'              => 1000,
                'max_fee'              => 25000,
                'min_transaction_amount' => 1000,
                'max_transaction_amount' => 100000000,
                'effective_from'       => now(),
                'is_active'            => true,
            ],
            [
                'transaction_type'     => 'escrow',
                'payment_provider_code' => null,
                'fee_percent'          => 3.00,
                'fee_flat_amount'      => 0,
                'min_fee'              => 5000,
                'max_fee'              => null,
                'min_transaction_amount' => 50000,
                'max_transaction_amount' => 1000000000,
                'effective_from'       => now(),
                'is_active'            => true,
            ],
        ];

        foreach ($fees as $f) {
            WalletFee::updateOrCreate(
                [
                    'transaction_type'      => $f['transaction_type'],
                    'payment_provider_code' => $f['payment_provider_code'],
                ],
                $f
            );
        }
    }
}
