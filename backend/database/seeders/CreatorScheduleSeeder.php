<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\CreatorCapacitySchedule;
use App\Enums\RoleType;
use Carbon\Carbon;

class CreatorScheduleSeeder extends Seeder
{
    public function run(): void
    {
        $creators = User::where('role', RoleType::Creator->value)->get();

        foreach ($creators as $creator) {
            // Day +5: Available with custom capacity 1 (e.g. Sesi Tambahan)
            $dateCustom = Carbon::now()->addDays(5)->format('Y-m-d');
            CreatorCapacitySchedule::updateOrCreate(
                ['creator_id' => $creator->id, 'date' => $dateCustom],
                [
                    'max_capacity' => 1,
                    'is_unavailable' => false,
                    'notes' => 'Sesi Tambahan Terbatas',
                ]
            );

            // Day +6: Unavailable day (Off / Libur) - non-conflicting with active contracts
            $dateUnavailable = Carbon::now()->addDays(6)->format('Y-m-d');
            CreatorCapacitySchedule::updateOrCreate(
                ['creator_id' => $creator->id, 'date' => $dateUnavailable],
                [
                    'max_capacity' => 0,
                    'is_unavailable' => true,
                    'notes' => 'Libur / Off Duty',
                ]
            );

            // Day +7: Available with normal capacity 2
            $dateNormal = Carbon::now()->addDays(7)->format('Y-m-d');
            CreatorCapacitySchedule::updateOrCreate(
                ['creator_id' => $creator->id, 'date' => $dateNormal],
                [
                    'max_capacity' => 2,
                    'is_unavailable' => false,
                    'notes' => 'Jadwal Reguler',
                ]
            );
        }
    }
}

