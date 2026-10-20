<?php

namespace Database\Seeders;

use App\Models\ClientApp;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class ClientAppSeeder extends Seeder
{
    public function run(): void
    {
        $apps = [
            [
                'client_id' => 'kreavana_app',
                'client_name' => 'Kreavana Creative Ecosystem (Web & Mobile)',
                'client_secret' => hash('sha256', 'kreavana_ecosystem_secret_key_2026'),
                'allowed_scopes' => ['openid', 'profile', 'email', 'phone', 'kyc'],
                'is_active' => true,
            ],
            [
                'client_id' => 'ecosystem_edutech',
                'client_name' => 'Future Edutech Platform',
                'client_secret' => hash('sha256', 'edutech_secret_key_2026'),
                'allowed_scopes' => ['openid', 'profile', 'email'],
                'is_active' => true,
            ],
            [
                'client_id' => 'ecosystem_b2b_market',
                'client_name' => 'Future B2B Creative Marketplace',
                'client_secret' => hash('sha256', 'b2b_secret_key_2026'),
                'allowed_scopes' => ['openid', 'profile', 'email', 'kyc'],
                'is_active' => true,
            ],
        ];

        foreach ($apps as $app) {
            ClientApp::firstOrCreate(['client_id' => $app['client_id']], $app);
        }
    }
}
