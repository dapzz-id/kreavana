<?php

namespace App\Services;

use App\Models\DisputeCase;
use App\Models\Chat;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class DisputeService
{
    /**
     * Create a new dispute case securely, assign an admin, and create a group chat.
     */
    public function createCase(array $data)
    {
        return DB::transaction(function () use ($data) {
            // Find an eligible admin randomly to distribute workload
            $admin = User::where('role', \App\Enums\RoleType::Admin)->inRandomOrder()->first();

            if (!$admin) {
                throw new \Exception('Saat ini tidak ada admin yang tersedia untuk menangani sengketa.', 503);
            }

            // Create the chat
            $chatName = 'Dispute - ' . ($data['case_type'] === 'marketplace_refund' ? 'Marketplace Refund' : 'Opportunity Cancellation');
            $chat = Chat::create([
                'type' => 'group',
                'name' => $chatName,
                'description' => 'Dispute group between parties and admin',
                'only_admin_can_add' => true,
            ]);

            // Add participants
            $chat->participants()->createMany([
                ['user_id' => $data['requester_id']],
                ['user_id' => $data['other_party_id']],
                ['user_id' => $admin->id],
            ]);

            // Create dispute case
            $disputeCase = DisputeCase::create([
                'case_type' => $data['case_type'],
                'requester_id' => $data['requester_id'],
                'other_party_id' => $data['other_party_id'],
                'assigned_admin_id' => $admin->id,
                'marketplace_purchase_id' => $data['marketplace_purchase_id'] ?? null,
                'opportunity_id' => $data['opportunity_id'] ?? null,
                'chat_id' => $chat->id,
                'reason' => $data['reason'],
                'status' => 'pending',
            ]);

            return $disputeCase;
        });
    }
}
