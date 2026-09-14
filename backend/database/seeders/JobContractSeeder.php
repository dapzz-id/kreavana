<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\JobContract;
use App\Models\JobStatusHistory;
use App\Enums\RoleType;
use App\Enums\CreatorSubRole;
use App\Enums\ContractStatus;
use App\Enums\WorkStatus;
use Carbon\Carbon;

use App\Models\CreatorService;

class JobContractSeeder extends Seeder
{
    public function run(): void
    {
        $client = User::where('email', 'client@kreavana.id')->first();
        if (!$client) return;

        $creators = User::where('role', RoleType::Creator->value)->get();

        $contractMappings = [
            CreatorSubRole::INSTITUTION->value => [
                'title' => 'Kerjasama Program UMKM',
                'contract_status' => ContractStatus::Completed,
                'work_status' => WorkStatus::Completed,
                'scheduled_start_date' => Carbon::now()->subDays(14)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->subDays(5)->format('Y-m-d'),
                'deadline' => Carbon::now()->subDays(4)->format('Y-m-d'),
            ],
            CreatorSubRole::GOVERNMENT->value => [
                'title' => 'Dokumentasi Dinas Daerah',
                'contract_status' => ContractStatus::Active,
                'work_status' => WorkStatus::InProgress,
                'scheduled_start_date' => Carbon::now()->subDays(1)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->addDays(3)->format('Y-m-d'),
                'deadline' => Carbon::now()->addDays(4)->format('Y-m-d'),
            ],
            CreatorSubRole::MC->value => [
                'title' => 'MC Seminar Tech',
                'contract_status' => ContractStatus::Proposed,
                'work_status' => WorkStatus::Pending,
                'scheduled_start_date' => Carbon::now()->addDays(5)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->addDays(7)->format('Y-m-d'),
                'deadline' => Carbon::now()->addDays(8)->format('Y-m-d'),
            ],
            CreatorSubRole::SINGER->value => [
                'title' => 'Performer Wedding Reception',
                'contract_status' => ContractStatus::Approved,
                'work_status' => WorkStatus::Scheduled,
                'scheduled_start_date' => Carbon::now()->addDays(2)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->addDays(4)->format('Y-m-d'),
                'deadline' => Carbon::now()->addDays(5)->format('Y-m-d'),
            ],
            CreatorSubRole::WEDDING_ORGANIZER->value => [
                'title' => 'Wedding Planning Budi & Ani',
                'contract_status' => ContractStatus::Active,
                'work_status' => WorkStatus::InProgress,
                'scheduled_start_date' => Carbon::now()->subDays(2)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->addDays(4)->format('Y-m-d'),
                'deadline' => Carbon::now()->addDays(5)->format('Y-m-d'),
            ],
            CreatorSubRole::EVENT_ORGANIZER->value => [
                'title' => 'Festival Kuliner Nusantara',
                'contract_status' => ContractStatus::Proposed,
                'work_status' => WorkStatus::Pending,
                'scheduled_start_date' => Carbon::now()->addDays(7)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->addDays(10)->format('Y-m-d'),
                'deadline' => Carbon::now()->addDays(12)->format('Y-m-d'),
            ],
            CreatorSubRole::COMMUNITY->value => [
                'title' => 'Gathering Komunitas Tech',
                'contract_status' => ContractStatus::Completed,
                'work_status' => WorkStatus::Completed,
                'scheduled_start_date' => Carbon::now()->subDays(10)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->subDays(2)->format('Y-m-d'),
                'deadline' => Carbon::now()->subDays(1)->format('Y-m-d'),
            ],
            CreatorSubRole::MAKEUP_ARTIST->value => [
                'title' => 'Makeup Prewedding',
                'contract_status' => ContractStatus::Active,
                'work_status' => WorkStatus::Review,
                'scheduled_start_date' => Carbon::now()->subDays(1)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->addDays(3)->format('Y-m-d'),
                'deadline' => Carbon::now()->addDays(4)->format('Y-m-d'),
            ],
            CreatorSubRole::PHOTOGRAPHER->value => [
                'title' => 'Sesi Foto Produk Kosmetik',
                'contract_status' => ContractStatus::Active,
                'work_status' => WorkStatus::InProgress,
                'scheduled_start_date' => Carbon::now()->subDays(1)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->addDays(4)->format('Y-m-d'),
                'deadline' => Carbon::now()->addDays(5)->format('Y-m-d'),
            ],
            CreatorSubRole::EDITOR->value => [
                'title' => 'Editing Vlog Traveling',
                'contract_status' => ContractStatus::Active,
                'work_status' => WorkStatus::Revision,
                'scheduled_start_date' => Carbon::now()->subDays(2)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->addDays(3)->format('Y-m-d'),
                'deadline' => Carbon::now()->addDays(4)->format('Y-m-d'),
            ],
            CreatorSubRole::VIDEOGRAPHER->value => [
                'title' => 'Video Profil Perusahaan',
                'contract_status' => ContractStatus::Completed,
                'work_status' => WorkStatus::Completed,
                'scheduled_start_date' => Carbon::now()->subDays(15)->format('Y-m-d'),
                'scheduled_end_date' => Carbon::now()->subDays(3)->format('Y-m-d'),
                'deadline' => Carbon::now()->subDays(2)->format('Y-m-d'),
            ],
        ];

        foreach ($creators as $creator) {
            $subRole = $creator->sub_role instanceof \BackedEnum ? $creator->sub_role->value : $creator->sub_role;
            if (!$subRole || !isset($contractMappings[$subRole])) continue;

            $mapping = $contractMappings[$subRole];
            $service = CreatorService::where('creator_id', $creator->id)->first();
            $price = $service ? (float)$service->price : 2500000.00;
            $isCompletedOrActive = in_array($mapping['contract_status'], [ContractStatus::Active, ContractStatus::Completed]);

            $contract = JobContract::updateOrCreate(
                [
                    'client_id' => $client->id,
                    'creator_id' => $creator->id,
                    'title' => $mapping['title'],
                ],
                [
                    'creator_service_id' => $service?->id,
                    'description' => 'Pekerjaan proyek ' . $mapping['title'] . ' untuk kebutuhan promosi dan operasional.',
                    'terms' => 'Pembayaran via Escrow Kreavana, revisi maksimal 2 kali.',
                    'agreed_price' => $price,
                    'escrow_amount' => $isCompletedOrActive ? $price : 0.00,
                    'contract_status' => $mapping['contract_status'],
                    'work_status' => $mapping['work_status'],
                    'scheduled_start_date' => $mapping['scheduled_start_date'],
                    'scheduled_end_date' => $mapping['scheduled_end_date'],
                    'deadline' => $mapping['deadline'],
                    'creator_approved' => true,
                    'client_approved' => in_array($mapping['contract_status'], [ContractStatus::Approved, ContractStatus::Active, ContractStatus::Completed]),
                ]
            );

            // Base history: Created
            JobStatusHistory::firstOrCreate([
                'job_contract_id' => $contract->id,
                'actor_id' => $client->id,
                'transition' => 'created',
                'to_contract_status' => ContractStatus::Draft->value,
                'to_work_status' => WorkStatus::Pending->value,
            ]);

            // If Proposed or beyond
            if (in_array($mapping['contract_status'], [ContractStatus::Proposed, ContractStatus::Approved, ContractStatus::Active, ContractStatus::Completed])) {
                JobStatusHistory::firstOrCreate([
                    'job_contract_id' => $contract->id,
                    'actor_id' => $creator->id,
                    'transition' => 'proposed',
                    'from_contract_status' => ContractStatus::Draft->value,
                    'to_contract_status' => ContractStatus::Proposed->value,
                    'from_work_status' => WorkStatus::Pending->value,
                    'to_work_status' => WorkStatus::Pending->value,
                ]);
            }

            // If Approved or beyond
            if (in_array($mapping['contract_status'], [ContractStatus::Approved, ContractStatus::Active, ContractStatus::Completed])) {
                JobStatusHistory::firstOrCreate([
                    'job_contract_id' => $contract->id,
                    'actor_id' => $client->id,
                    'transition' => 'approved',
                    'from_contract_status' => ContractStatus::Proposed->value,
                    'to_contract_status' => ContractStatus::Approved->value,
                    'from_work_status' => WorkStatus::Pending->value,
                    'to_work_status' => WorkStatus::Scheduled->value,
                ]);
            }

            // If Active or beyond
            if (in_array($mapping['contract_status'], [ContractStatus::Active, ContractStatus::Completed])) {
                JobStatusHistory::firstOrCreate([
                    'job_contract_id' => $contract->id,
                    'actor_id' => $client->id,
                    'transition' => 'activated',
                    'from_contract_status' => ContractStatus::Approved->value,
                    'to_contract_status' => ContractStatus::Active->value,
                    'from_work_status' => WorkStatus::Scheduled->value,
                    'to_work_status' => WorkStatus::InProgress->value,
                ]);

                if (in_array($mapping['work_status'], [WorkStatus::Review, WorkStatus::Revision, WorkStatus::Completed])) {
                    JobStatusHistory::firstOrCreate([
                        'job_contract_id' => $contract->id,
                        'actor_id' => $creator->id,
                        'transition' => 'submitted',
                        'from_contract_status' => ContractStatus::Active->value,
                        'to_contract_status' => ContractStatus::Active->value,
                        'from_work_status' => WorkStatus::InProgress->value,
                        'to_work_status' => WorkStatus::Review->value,
                    ]);
                }
            }

            // If Completed
            if ($mapping['contract_status'] === ContractStatus::Completed) {
                JobStatusHistory::firstOrCreate([
                    'job_contract_id' => $contract->id,
                    'actor_id' => $client->id,
                    'transition' => 'completed',
                    'from_contract_status' => ContractStatus::Active->value,
                    'to_contract_status' => ContractStatus::Completed->value,
                    'from_work_status' => WorkStatus::Review->value,
                    'to_work_status' => WorkStatus::Completed->value,
                ]);
            }
        }
    }
}
