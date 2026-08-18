<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Enums\RoleType;
use App\Enums\CreatorSubRole;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Carbon\Carbon;

class CreatorScheduleSeeder extends Seeder
{
    public function run(): void
    {
        $creators = User::where('role', RoleType::Creator->value)->get();

        $serviceProviders = [
            CreatorSubRole::MC->value,
            CreatorSubRole::SINGER->value,
            CreatorSubRole::WEDDING_ORGANIZER->value,
            CreatorSubRole::EVENT_ORGANIZER->value,
            CreatorSubRole::MAKEUP_ARTIST->value,
            CreatorSubRole::PHOTOGRAPHER->value,
            CreatorSubRole::EDITOR->value,
            CreatorSubRole::VIDEOGRAPHER->value,
        ];

        foreach ($creators as $creator) {
            $subRole = $creator->sub_role instanceof \BackedEnum ? $creator->sub_role->value : $creator->sub_role;
            if (!$subRole || !in_array($subRole, $serviceProviders)) continue;

            $dateAvailable = Carbon::now()->addDays(5)->format('Y-m-d');
            $dateBooked = Carbon::now()->addDays(6)->format('Y-m-d');

            DB::table('creator_capacity_schedules')->updateOrInsert(
                ['creator_id' => $creator->id, 'date' => $dateAvailable],
                [
                    'id' => Str::uuid(),
                    'max_capacity' => 1,
                    'is_unavailable' => false,
                    'notes' => 'Tersedia untuk booking',
                    'created_at' => now(),
                    'updated_at' => now(),
                ]
            );

            DB::table('creator_capacity_schedules')->updateOrInsert(
                ['creator_id' => $creator->id, 'date' => $dateBooked],
                [
                    'id' => Str::uuid(),
                    'max_capacity' => 0,
                    'is_unavailable' => true,
                    'notes' => 'Sudah dibooking penuh',
                    'created_at' => now(),
                    'updated_at' => now(),
                ]
            );
        }
    }
}
