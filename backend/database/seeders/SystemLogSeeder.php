<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class SystemLogSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $logs = [
            [
                'id' => \Illuminate\Support\Str::uuid(),
                'user_id' => null,
                'action' => 'SYSTEM_SEEDING',
                'title' => 'Sistem Seeding Berhasil',
                'description' => 'Update data seeder admin@kreavana.id berhasil diterapkan.',
                'type' => 'system',
                'metadata' => json_encode(['env' => 'development']),
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'id' => \Illuminate\Support\Str::uuid(),
                'user_id' => null,
                'action' => 'DATABASE_BACKUP',
                'title' => 'Backup Database Harian',
                'description' => 'Automated backup database berhasil diunggah ke cloud storage.',
                'type' => 'backup',
                'metadata' => json_encode(['storage' => 's3', 'size_mb' => 25]),
                'created_at' => now()->subHour(),
                'updated_at' => now()->subHour(),
            ],
            [
                'id' => \Illuminate\Support\Str::uuid(),
                'user_id' => null,
                'action' => 'TOKEN_REFRESH',
                'title' => 'Auth Token Refreshed',
                'description' => 'Sistem membersihkan sesi JWT expired sebanyak 14 token.',
                'type' => 'authentication',
                'metadata' => json_encode(['cleared_count' => 14]),
                'created_at' => now()->subHours(3),
                'updated_at' => now()->subHours(3),
            ],
            [
                'id' => \Illuminate\Support\Str::uuid(),
                'user_id' => null,
                'action' => 'API_GATEWAY_CHECK',
                'title' => 'Koneksi Gateway API',
                'description' => 'Status koneksi server laravel terdeteksi online (200 OK).',
                'type' => 'network',
                'metadata' => json_encode(['status_code' => 200]),
                'created_at' => now()->subHours(5),
                'updated_at' => now()->subHours(5),
            ]
        ];

        \Illuminate\Support\Facades\DB::table('system_logs')->insert($logs);
    }
}
