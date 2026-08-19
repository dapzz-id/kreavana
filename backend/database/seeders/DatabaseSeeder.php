<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $this->call([
            UserSeeder::class,
            CreatorPortfolioSeeder::class,
            CreatorServiceSeeder::class,
            CreatorScheduleSeeder::class,
            JobContractSeeder::class,
            ChatSeeder::class,
            RemainingTablesSeeder::class,
            OpportunityLocationSeeder::class,
            DashboardMockSeeder::class,
        ]);
    }
}
