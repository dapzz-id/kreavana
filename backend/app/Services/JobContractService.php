<?php

namespace App\Services;

use App\Models\JobContract;
use App\Models\MarketplaceItem;
use App\Models\User;
use App\Repositories\JobContractRepository;
use Exception;
use Illuminate\Support\Facades\DB;

class JobContractService extends BaseService
{
    protected JobContractRepository $contractRepo;

    public function __construct(JobContractRepository $contractRepo)
    {
        $this->contractRepo = $contractRepo;
    }

    public function createContract(User $user, array $data): JobContract
    {
        // Determine Ownership
        if ($data['my_role'] === 'client') {
            $clientId = $user->id;
            $creatorId = $data['partner_id'];
        } else {
            $creatorId = $user->id;
            $clientId = $data['partner_id'];
            
            // A creator must have the 'creator' role to act as one.
            if ($user->role !== \App\Enums\RoleType::Creator) {
                throw new Exception('Anda bukan kreator terdaftar.', 403);
            }
        }

        // Validate partner exists
        $partner = User::find($data['partner_id']);
        if (!$partner) {
            throw new Exception('Partner tidak ditemukan.', 404);
        }

        if ($data['my_role'] === 'client' && $partner->role !== \App\Enums\RoleType::Creator) {
            throw new Exception('Partner bukan kreator terdaftar.', 400);
        }

        if ($clientId === $creatorId) {
            throw new Exception('Klien dan Kreator tidak boleh sama.', 400);
        }

        // Handle CreatorService Snapshotting
        if (!empty($data['creator_service_id'])) {
            $item = \App\Models\CreatorService::find($data['creator_service_id']);
            if (!$item) {
                throw new Exception('Layanan tidak ditemukan.', 404);
            }
            if ($item->creator_id !== $creatorId) {
                throw new Exception('Layanan bukan milik kreator ini.', 400);
            }
            if ($item->status !== 'active') {
                throw new Exception('Layanan tidak tersedia.', 400);
            }

            // Snapshot authoritative values
            $data['title'] = $item->title;
            $data['description'] = $item->description;
            $data['agreed_price'] = $item->price;
        }

        // Create the contract
        return DB::transaction(function () use ($clientId, $creatorId, $data) {
            $contractData = [
                'client_id' => $clientId,
                'creator_id' => $creatorId,
                'opportunity_id' => $data['opportunity_id'] ?? null,
                'creator_service_id' => $data['creator_service_id'] ?? null,
                'title' => $data['title'],
                'description' => $data['description'] ?? null,
                'terms' => $data['terms'] ?? null,
                'agreed_price' => $data['agreed_price'],
                'escrow_amount' => 0.00, // Escrow paid in a future phase
                'contract_status' => 'draft',
                'work_status' => 'scheduled',
                'deadline' => $data['deadline'] ?? null,
                'scheduled_start_date' => $data['scheduled_start_date'],
                'scheduled_end_date' => $data['scheduled_end_date'],
            ];

            return $this->contractRepo->create($contractData);
        });
    }

    public function getContractForUser(string $contractId, User $user): JobContract
    {
        $contract = $this->contractRepo->find($contractId);
        
        if (!$contract) {
            throw new Exception('Kontrak tidak ditemukan.', 404);
        }

        // IDOR Prevention: Only client, creator, or admin can view
        if ($user->role !== \App\Enums\RoleType::Admin && $contract->client_id !== $user->id && $contract->creator_id !== $user->id) {
            throw new Exception('Anda tidak memiliki akses ke kontrak ini.', 403);
        }

        return $contract;
    }

    public function getUserContracts(User $user, int $limit = 50)
    {
        return $this->contractRepo->getByUserId($user->id, $limit);
    }
}
