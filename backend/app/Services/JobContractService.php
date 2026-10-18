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

            $contract = $this->contractRepo->create($contractData);

            // Large transaction detection & audit record creation
            $threshold = config('app.large_transaction_threshold', 100000000);
            if ((float) $contract->agreed_price >= (float) $threshold) {
                \App\Models\LargeTransactionReview::create([
                    'job_contract_id' => $contract->id,
                    'threshold_amount' => $threshold,
                    'contract_amount' => $contract->agreed_price,
                    'status' => 'pending_review',
                ]);
            }

            // Notify partner
            $targetUserId = ($data['my_role'] === 'client') ? $creatorId : $clientId;
            \App\Models\Notification::create([
                'user_id' => $targetUserId,
                'title' => 'Kontrak Kerja Baru Diajukan',
                'message' => $user->name . ' telah mengajukan kontrak kerja baru: "' . $contract->title . '".',
                'type' => 'contract',
                'data' => ['contract_id' => $contract->id],
                'is_read' => false,
                'created_at' => now(),
            ]);

            return $contract;
        });
    }

    public function repeatOrder(User $user, string $contractId, array $data): JobContract
    {
        $previousContract = JobContract::findOrFail($contractId);

        // Security: user must be the client of this previous contract (or admin)
        if ($user->role !== \App\Enums\RoleType::Admin && $previousContract->client_id !== $user->id) {
            throw new Exception('Hanya klien pemilik kontrak sebelumnya yang dapat melakukan repeat order.', 403);
        }

        $creator = User::findOrFail($previousContract->creator_id);

        $title = !empty($data['title']) ? $data['title'] : 'Repeat Order - ' . $previousContract->title;
        $description = !empty($data['description']) ? $data['description'] : $previousContract->description;
        $terms = !empty($data['terms']) ? $data['terms'] : $previousContract->terms;
        $agreedPrice = isset($data['agreed_price']) && (float) $data['agreed_price'] > 0
            ? (float) $data['agreed_price']
            : (float) $previousContract->agreed_price;

        $startDate = !empty($data['scheduled_start_date'])
            ? $data['scheduled_start_date']
            : now()->addDays(2)->toDateString();

        $endDate = !empty($data['scheduled_end_date'])
            ? $data['scheduled_end_date']
            : now()->addDays(7)->toDateString();

        $deadline = !empty($data['deadline'])
            ? $data['deadline']
            : $endDate;

        return DB::transaction(function () use ($user, $creator, $previousContract, $title, $description, $terms, $agreedPrice, $startDate, $endDate, $deadline, $data) {
            $newContract = $this->contractRepo->create([
                'client_id' => $user->id,
                'creator_id' => $creator->id,
                'opportunity_id' => $previousContract->opportunity_id,
                'creator_service_id' => $previousContract->creator_service_id,
                'title' => $title,
                'description' => $description,
                'terms' => $terms,
                'agreed_price' => $agreedPrice,
                'escrow_amount' => 0.00,
                'contract_status' => 'draft',
                'work_status' => 'scheduled',
                'deadline' => $deadline,
                'scheduled_start_date' => $startDate,
                'scheduled_end_date' => $endDate,
            ]);

            \App\Models\JobStatusHistory::create([
                'job_contract_id' => $newContract->id,
                'actor_id' => $user->id,
                'transition' => 'repeat_order',
                'from_contract_status' => 'draft',
                'to_contract_status' => 'draft',
                'from_work_status' => 'scheduled',
                'to_work_status' => 'scheduled',
                'metadata' => [
                    'source_contract_id' => $previousContract->id,
                    'notes' => $data['notes'] ?? null,
                ],
                'created_at' => now(),
            ]);

            // Notify Creator
            \App\Models\Notification::create([
                'user_id' => $creator->id,
                'title' => 'Repeat Order Diterima!',
                'message' => 'Klien ' . $user->name . ' telah melakukan Repeat Order untuk proyek: "' . $title . '".',
                'type' => 'contract',
                'data' => [
                    'contract_id' => $newContract->id,
                    'source_contract_id' => $previousContract->id,
                ],
                'is_read' => false,
                'created_at' => now(),
            ]);

            // Notify Client
            \App\Models\Notification::create([
                'user_id' => $user->id,
                'title' => 'Repeat Order Berhasil Dibuat',
                'message' => 'Kontrak Repeat Order "' . $title . '" dengan kreator ' . $creator->name . ' berhasil diajukan.',
                'type' => 'contract',
                'data' => [
                    'contract_id' => $newContract->id,
                ],
                'is_read' => false,
                'created_at' => now(),
            ]);

            return $newContract;
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
