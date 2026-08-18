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
                'work_status' => WorkStatus::Done,
            ],
            CreatorSubRole::GOVERNMENT->value => [
                'title' => 'Dokumentasi Dinas Daerah',
                'contract_status' => ContractStatus::Active,
                'work_status' => WorkStatus::InProgress,
            ],
            CreatorSubRole::MC->value => [
                'title' => 'MC Seminar Tech',
                'contract_status' => ContractStatus::Proposed,
                'work_status' => WorkStatus::Pending,
            ],
            CreatorSubRole::SINGER->value => [
                'title' => 'Performer Wedding Reception',
                'contract_status' => ContractStatus::Active,
                'work_status' => WorkStatus::Scheduled,
            ],
            CreatorSubRole::WEDDING_ORGANIZER->value => [
                'title' => 'Wedding Planning Budi & Ani',
                'contract_status' => ContractStatus::Active,
                'work_status' => WorkStatus::InProgress,
            ],
            CreatorSubRole::EVENT_ORGANIZER->value => [
                'title' => 'Festival Kuliner Nusantara',
                'contract_status' => ContractStatus::Proposed,
                'work_status' => WorkStatus::Pending,
            ],
            CreatorSubRole::COMMUNITY->value => [
                'title' => 'Gathering Komunitas Tech',
                'contract_status' => ContractStatus::Completed,
                'work_status' => WorkStatus::Done,
            ],
            CreatorSubRole::MAKEUP_ARTIST->value => [
                'title' => 'Makeup Prewedding',
                'contract_status' => ContractStatus::Active,
                'work_status' => WorkStatus::Scheduled,
            ],
            CreatorSubRole::PHOTOGRAPHER->value => [
                'title' => 'Sesi Foto Produk Kosmetik',
                'contract_status' => ContractStatus::Active,
                'work_status' => WorkStatus::InProgress,
            ],
            CreatorSubRole::EDITOR->value => [
                'title' => 'Editing Vlog Traveling',
                'contract_status' => ContractStatus::Active,
                'work_status' => WorkStatus::Submitted,
            ],
            CreatorSubRole::VIDEOGRAPHER->value => [
                'title' => 'Video Profil Perusahaan',
                'contract_status' => ContractStatus::Completed,
                'work_status' => WorkStatus::Done,
            ],
        ];

        foreach ($creators as $creator) {
            $subRole = $creator->sub_role instanceof \BackedEnum ? $creator->sub_role->value : $creator->sub_role;
            if (!$subRole || !isset($contractMappings[$subRole])) continue;

            $mapping = $contractMappings[$subRole];

            $contract = JobContract::updateOrCreate(
                [
                    'client_id' => $client->id,
                    'creator_id' => $creator->id,
                    'title' => $mapping['title'],
                ],
                [
                    'agreed_price' => rand(10, 50) * 100000.00,
                    'contract_status' => $mapping['contract_status'],
                    'work_status' => $mapping['work_status'],
                    'creator_approved' => true,
                    'client_approved' => true,
                ]
            );

            // Base history: Created
            JobStatusHistory::firstOrCreate([
                'job_contract_id' => $contract->id,
                'actor_id' => $client->id,
                'transition' => 'created',
                'to_contract_status' => ContractStatus::Draft,
                'to_work_status' => WorkStatus::Pending,
            ]);

            // If Proposed or beyond
            if (in_array($mapping['contract_status'], [ContractStatus::Proposed, ContractStatus::Active, ContractStatus::Completed])) {
                JobStatusHistory::firstOrCreate([
                    'job_contract_id' => $contract->id,
                    'actor_id' => $creator->id,
                    'transition' => 'proposed',
                    'from_contract_status' => ContractStatus::Draft,
                    'to_contract_status' => ContractStatus::Proposed,
                    'from_work_status' => WorkStatus::Pending,
                    'to_work_status' => WorkStatus::Pending,
                ]);
            }

            // If Active or beyond
            if (in_array($mapping['contract_status'], [ContractStatus::Active, ContractStatus::Completed])) {
                JobStatusHistory::firstOrCreate([
                    'job_contract_id' => $contract->id,
                    'actor_id' => $client->id,
                    'transition' => 'activated',
                    'from_contract_status' => ContractStatus::Proposed,
                    'to_contract_status' => ContractStatus::Active,
                    'from_work_status' => WorkStatus::Pending,
                    'to_work_status' => WorkStatus::Scheduled, // default after active
                ]);

                if (in_array($mapping['work_status'], [WorkStatus::InProgress, WorkStatus::Submitted, WorkStatus::Done])) {
                    JobStatusHistory::firstOrCreate([
                        'job_contract_id' => $contract->id,
                        'actor_id' => $creator->id,
                        'transition' => 'started',
                        'from_contract_status' => ContractStatus::Active,
                        'to_contract_status' => ContractStatus::Active,
                        'from_work_status' => WorkStatus::Scheduled,
                        'to_work_status' => WorkStatus::InProgress,
                    ]);
                }

                if (in_array($mapping['work_status'], [WorkStatus::Submitted, WorkStatus::Done])) {
                    JobStatusHistory::firstOrCreate([
                        'job_contract_id' => $contract->id,
                        'actor_id' => $creator->id,
                        'transition' => 'submitted',
                        'from_contract_status' => ContractStatus::Active,
                        'to_contract_status' => ContractStatus::Active,
                        'from_work_status' => WorkStatus::InProgress,
                        'to_work_status' => WorkStatus::Submitted,
                    ]);
                }
            }

            // If Completed
            if ($mapping['contract_status'] === ContractStatus::Completed) {
                JobStatusHistory::firstOrCreate([
                    'job_contract_id' => $contract->id,
                    'actor_id' => $client->id,
                    'transition' => 'completed',
                    'from_contract_status' => ContractStatus::Active,
                    'to_contract_status' => ContractStatus::Completed,
                    'from_work_status' => WorkStatus::Submitted,
                    'to_work_status' => WorkStatus::Done,
                ]);
            }
        }
    }
}
