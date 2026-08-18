<?php

namespace App\Services;

use App\Models\JobContract;
use App\Models\JobStatusHistory;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Exception;

class JobContractTransitionService extends BaseService
{
    public function transition(JobContract $contract, User $actor, string $transitionName, array $metadata = []): JobContract
    {
        return DB::transaction(function () use ($contract, $actor, $transitionName, $metadata) {
            // Lock the contract row
            $lockedContract = JobContract::where('id', $contract->id)->lockForUpdate()->firstOrFail();

            $fromContractStatus = $lockedContract->contract_status?->value ?? $lockedContract->contract_status;
            $fromWorkStatus = $lockedContract->work_status?->value ?? $lockedContract->work_status;

            $toContractStatus = $fromContractStatus;
            $toWorkStatus = $fromWorkStatus;

            $this->validateAndApplyTransition($lockedContract, $actor, $transitionName, $toContractStatus, $toWorkStatus, $metadata);

            if ($transitionName === 'approve' && $toContractStatus === 'approved') {
                $availabilityService = app(CreatorAvailabilityService::class);
                $creator = User::find($lockedContract->creator_id);
                $start = \Carbon\Carbon::parse($lockedContract->scheduled_start_date);
                $end = \Carbon\Carbon::parse($lockedContract->scheduled_end_date);
                $availabilityService->validateDateRangeCapacity($creator, $start, $end);
            }

            // If nothing changed, we might not want to create a history, or maybe we do if it's an internal state update (like first approval)
            $isStatusChanged = ($fromContractStatus !== $toContractStatus) || ($fromWorkStatus !== $toWorkStatus);
            $isInternalApproval = ($transitionName === 'approve' && $toContractStatus === 'draft'); // 1 party approved, still draft

            if ($isStatusChanged || $isInternalApproval) {
                $lockedContract->contract_status = $toContractStatus;
                $lockedContract->work_status = $toWorkStatus;
                $lockedContract->save();

                JobStatusHistory::create([
                    'job_contract_id' => $lockedContract->id,
                    'actor_id' => $actor->id,
                    'transition' => $transitionName,
                    'from_contract_status' => $fromContractStatus,
                    'to_contract_status' => $toContractStatus,
                    'from_work_status' => $fromWorkStatus,
                    'to_work_status' => $toWorkStatus,
                    'metadata' => $metadata,
                    'created_at' => now(),
                ]);
            }

            return $lockedContract;
        });
    }

    private function validateAndApplyTransition(JobContract $contract, User $actor, string $transitionName, &$toContractStatus, &$toWorkStatus, array $metadata)
    {
        $isClient = $actor->id === $contract->client_id;
        $isCreator = $actor->id === $contract->creator_id;

        if (!$isClient && !$isCreator) {
            throw new Exception("Unauthorized. You are not a party in this contract.", 403);
        }

        switch ($transitionName) {
            case 'approve':
                if (($contract->contract_status?->value ?? $contract->contract_status) !== 'draft') {
                    throw new Exception("Contract is already past the draft stage.", 400);
                }

                if ($isClient) {
                    if ($contract->client_approved) throw new Exception("You have already approved this contract.", 400);
                    $contract->client_approved = true;
                    $contract->client_approved_at = now();
                } else {
                    if ($contract->creator_approved) throw new Exception("You have already approved this contract.", 400);
                    $contract->creator_approved = true;
                    $contract->creator_approved_at = now();
                }

                // If both approved, move to approved status
                if ($contract->client_approved && $contract->creator_approved) {
                    $toContractStatus = 'approved';
                }
                break;

            case 'pay_escrow':
                // Deferred in Phase 3 due to missing Escrow system
                throw new Exception("Escrow payment transition is currently disabled pending future Escrow system implementation. Please contact support.", 400);

            case 'submit_work':
                if (!$isCreator) throw new Exception("Only the creator can submit work.", 403);
                
                // Note: since pay_escrow is disabled, work_status might never naturally reach in_progress unless we force it or use a bypass for testing.
                // Assuming it somehow reaches in_progress or revision:
                if (!in_array($contract->work_status?->value ?? $contract->work_status, ['in_progress', 'revision'])) {
                    throw new Exception("Work can only be submitted when status is in_progress or revision.", 400);
                }
                $toWorkStatus = 'review';
                $contract->submitted_at = now();
                break;

            case 'request_revision':
                if (!$isClient) throw new Exception("Only the client can request a revision.", 403);
                if (($contract->work_status?->value ?? $contract->work_status) !== 'review') {
                    throw new Exception("You can only request revision when work is submitted for review.", 400);
                }
                $toWorkStatus = 'revision';
                break;

            case 'approve_work':
                if (!$isClient) throw new Exception("Only the client can approve work.", 403);
                if (($contract->work_status?->value ?? $contract->work_status) !== 'review') {
                    throw new Exception("You can only approve work when it is submitted for review.", 400);
                }
                $toWorkStatus = 'completed';
                $contract->completed_at = now();
                // Note: Contract status is deliberately NOT set to completed here, pending future escrow release logic.
                break;

            case 'request_cancellation':
                // Cannot cancel if already completed, cancelled, or disputed
                if (in_array($contract->contract_status?->value ?? $contract->contract_status, ['completed', 'cancelled', 'disputed'])) {
                    throw new Exception("Cannot cancel a contract in this state.", 400);
                }
                $toContractStatus = 'cancel_requested';
                if (isset($metadata['reason'])) {
                    $contract->cancel_reason = $metadata['reason'];
                }
                break;

            case 'confirm_cancellation':
                if (($contract->contract_status?->value ?? $contract->contract_status) !== 'cancel_requested') {
                    throw new Exception("There is no cancellation request to confirm.", 400);
                }
                
                // The party who requested CANNOT confirm their own request.
                // We determine who requested by checking who is the actor of the last cancel_requested history.
                $lastCancelRequest = JobStatusHistory::where('job_contract_id', $contract->id)
                    ->where('transition', 'request_cancellation')
                    ->latest('created_at')
                    ->first();
                
                if ($lastCancelRequest && $lastCancelRequest->actor_id === $actor->id) {
                    throw new Exception("You cannot confirm your own cancellation request.", 403);
                }

                $toContractStatus = 'cancelled';
                $toWorkStatus = 'cancelled';
                $contract->cancelled_at = now();
                // Note: Refund/Escrow logic deliberately omitted here per Phase 3 rules.
                break;

            case 'open_dispute':
                // Cannot open dispute if draft, cancelled, or completed
                if (in_array($contract->contract_status?->value ?? $contract->contract_status, ['completed', 'cancelled', 'draft'])) {
                    throw new Exception("Cannot open dispute for this contract state.", 400);
                }
                if (($contract->contract_status?->value ?? $contract->contract_status) === 'disputed') {
                    throw new Exception("Contract is already in dispute.", 400);
                }
                $toContractStatus = 'disputed';
                break;

            default:
                throw new Exception("Invalid transition: {$transitionName}", 400);
        }
    }
}
