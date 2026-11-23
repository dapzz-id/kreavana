<?php

namespace Database\Seeders;

use App\Models\ClientApp;
use Illuminate\Database\Seeder;

class ClientAppSeeder extends Seeder
{
    public function run(): void
    {
        $explicitKreavanaSecret = trim((string) env('USERS_API_CLIENT_SECRET', ''));
        $rawDefaultSecret = trim((string) env('DEFAULT_CLIENT_SECRET', ''));

        $kreavanaSecret = $explicitKreavanaSecret !== ''
            ? $explicitKreavanaSecret
            : ($rawDefaultSecret !== '' ? hash('sha256', $rawDefaultSecret) : bin2hex(random_bytes(32)));

        $apps = [
            [
                'client_id' => env('DEFAULT_CLIENT_ID', 'kreavana_app'),
                'client_name' => 'Kreavana Creative Ecosystem (Web & Mobile)',
                'client_secret' => $kreavanaSecret,
                'allowed_scopes' => ['openid', 'profile', 'email', 'phone', 'kyc'],
                'is_active' => true,
            ],
            [
                'client_id' => 'ecosystem_edutech',
                'client_name' => 'Future Edutech Platform',
                'client_secret' => trim((string) env('EDUTECH_CLIENT_SECRET', '')) ?: bin2hex(random_bytes(32)),
                'allowed_scopes' => ['openid', 'profile', 'email'],
                'is_active' => true,
            ],
            [
                'client_id' => 'ecosystem_b2b_market',
                'client_name' => 'Future B2B Creative Marketplace',
                'client_secret' => trim((string) env('B2B_CLIENT_SECRET', '')) ?: bin2hex(random_bytes(32)),
                'allowed_scopes' => ['openid', 'profile', 'email', 'kyc'],
                'is_active' => true,
            ],
        ];

        foreach ($apps as $app) {
            $existing = ClientApp::where('client_id', $app['client_id'])->first();
            if (!$existing) {
                ClientApp::create($app);
            } elseif ($app['client_id'] === env('DEFAULT_CLIENT_ID', 'kreavana_app') && $explicitKreavanaSecret !== '') {
                $existing->update(['client_secret' => $explicitKreavanaSecret]);
            }
        }
    }
}
