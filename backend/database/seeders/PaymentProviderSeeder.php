<?php

namespace Database\Seeders;

use App\Models\PaymentProvider;
use Illuminate\Database\Seeder;

class PaymentProviderSeeder extends Seeder
{
    public function run(): void
    {
        $providers = [
            [
                'code'        => 'bca',
                'name'        => 'BCA (Bank Central Asia)',
                'type'        => 'bank',
                'brand_color' => '#005EAA',
                'logo_url'    => null,
                'fee_percent' => 0,
                'fee_flat'    => 0,
                'min_amount'  => 10000,
                'max_amount'  => 500000000,
                'sort_order'  => 1,
            ],
            [
                'code'        => 'mandiri',
                'name'        => 'Bank Mandiri',
                'type'        => 'bank',
                'brand_color' => '#003B7F',
                'logo_url'    => null,
                'fee_percent' => 0,
                'fee_flat'    => 0,
                'min_amount'  => 10000,
                'max_amount'  => 500000000,
                'sort_order'  => 2,
            ],
            [
                'code'        => 'bni',
                'name'        => 'BNI (Bank Negara Indonesia)',
                'type'        => 'bank',
                'brand_color' => '#D71920',
                'logo_url'    => null,
                'fee_percent' => 0,
                'fee_flat'    => 0,
                'min_amount'  => 10000,
                'max_amount'  => 500000000,
                'sort_order'  => 3,
            ],
            [
                'code'        => 'bri',
                'name'        => 'BRI (Bank Rakyat Indonesia)',
                'type'        => 'bank',
                'brand_color' => '#00529C',
                'logo_url'    => null,
                'fee_percent' => 0,
                'fee_flat'    => 0,
                'min_amount'  => 10000,
                'max_amount'  => 500000000,
                'sort_order'  => 4,
            ],
            [
                'code'        => 'gopay',
                'name'        => 'GoPay',
                'type'        => 'ewallet',
                'brand_color' => '#00AA13',
                'logo_url'    => null,
                'fee_percent' => 0,
                'fee_flat'    => 0,
                'min_amount'  => 10000,
                'max_amount'  => 10000000,
                'sort_order'  => 10,
            ],
            [
                'code'        => 'ovo',
                'name'        => 'OVO',
                'type'        => 'ewallet',
                'brand_color' => '#4C2DA6',
                'logo_url'    => null,
                'fee_percent' => 0,
                'fee_flat'    => 0,
                'min_amount'  => 10000,
                'max_amount'  => 10000000,
                'sort_order'  => 11,
            ],
            [
                'code'        => 'dana',
                'name'        => 'DANA',
                'type'        => 'ewallet',
                'brand_color' => '#108EE9',
                'logo_url'    => null,
                'fee_percent' => 0,
                'fee_flat'    => 0,
                'min_amount'  => 10000,
                'max_amount'  => 10000000,
                'sort_order'  => 12,
            ],
            [
                'code'        => 'shopeepay',
                'name'        => 'ShopeePay',
                'type'        => 'ewallet',
                'brand_color' => '#EE4D2D',
                'logo_url'    => null,
                'fee_percent' => 0,
                'fee_flat'    => 0,
                'min_amount'  => 10000,
                'max_amount'  => 10000000,
                'sort_order'  => 13,
            ],
        ];

        foreach ($providers as $p) {
            PaymentProvider::updateOrCreate(
                ['code' => $p['code']],
                $p
            );
        }
    }
}
