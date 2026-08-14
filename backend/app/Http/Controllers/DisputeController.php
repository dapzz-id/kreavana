<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\DisputeCase;
use App\Models\MarketplacePurchase;
use App\Models\Opportunity;
use App\Models\CreatorPerformanceEvent;
use App\Models\WalletTransaction;
use App\Models\User;
use App\Services\DisputeService;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class DisputeController extends Controller
{
    protected $disputeService;

    public function __construct(DisputeService $disputeService)
    {
        $this->disputeService = $disputeService;
    }

    /**
     * Get disputes assigned to current admin
     */
    public function assignedDisputes(Request $request)
    {
        $adminId = Auth::id();
        $disputes = DisputeCase::where('assigned_admin_id', $adminId)
            ->with(['requester:id,name', 'otherParty:id,name'])
            ->orderBy('created_at', 'desc')
            ->get();
            
        // Provide enough context but not plaintext messages
        return response()->json([
            'status' => true,
            'data' => $disputes->map(function($d) {
                return [
                    'id' => $d->id,
                    'case_type' => $d->case_type,
                    'chat_id' => $d->chat_id,
                    'status' => $d->status,
                    'requester' => $d->requester,
                    'other_party' => $d->otherParty,
                    'created_at' => $d->created_at,
                ];
            })
        ]);
    }

    /**
     * Users submit a marketplace refund dispute
     */
    public function storeRefund(Request $request)
    {
        $request->validate([
            'marketplace_purchase_id' => 'required|uuid',
            'reason' => 'required|string|max:2000',
        ]);

        $userId = Auth::id();

        return DB::transaction(function () use ($request, $userId) {
            // Authorize and validate purchase with lock
            $purchase = MarketplacePurchase::where('id', $request->marketplace_purchase_id)
                ->where('user_id', $userId)
                ->lockForUpdate()
                ->first();

            if (!$purchase) {
                return response()->json(['status' => false, 'message' => 'Purchase not found or unauthorized.'], 403);
            }

            if ($purchase->status === 'refunded') {
                return response()->json(['status' => false, 'message' => 'Purchase is already refunded.'], 400);
            }

            // Idempotency: Prevent duplicate active disputes for this purchase
            $existingDispute = DisputeCase::where('marketplace_purchase_id', $purchase->id)
                ->whereIn('status', ['pending', 'under_review', 'awaiting_settlement', 'approved'])
                ->exists();

            if ($existingDispute) {
                return response()->json(['status' => false, 'message' => 'An active dispute already exists for this purchase.'], 400);
            }

            try {
                $dispute = $this->disputeService->createCase([
                    'case_type' => 'marketplace_refund',
                    'requester_id' => $userId,
                    'other_party_id' => $purchase->item->user_id,
                    'marketplace_purchase_id' => $purchase->id,
                    'reason' => $request->reason,
                ]);

                return response()->json([
                    'status' => true,
                    'message' => 'Dispute case created successfully. An admin will review it.',
                    'data' => $dispute
                ], 201);
            } catch (\Exception $e) {
                return response()->json(['status' => false, 'message' => $e->getMessage()], 500);
            }
        });
    }

    /**
     * Users submit an opportunity cancellation dispute
     */
    public function storeCancellation(Request $request)
    {
        $request->validate([
            'opportunity_id' => 'required|uuid',
            'reason' => 'required|string|max:2000',
        ]);

        $userId = Auth::id();

        return DB::transaction(function () use ($request, $userId) {
            // Validate Opportunity with lock
            $opportunity = Opportunity::lockForUpdate()->find($request->opportunity_id);
            if (!$opportunity) {
                return response()->json(['status' => false, 'message' => 'Opportunity not found.'], 404);
            }

            if ($opportunity->status === 'closed') {
                return response()->json(['status' => false, 'message' => 'Cannot refund or cancel a completed project.'], 409);
            }

            if ($opportunity->posted_by !== $userId) {
                return response()->json(['status' => false, 'message' => 'Unauthorized to cancel this opportunity.'], 403);
            }

            // Idempotency
            $existingDispute = DisputeCase::where('opportunity_id', $opportunity->id)
                ->whereIn('status', ['pending', 'under_review', 'approved'])
                ->exists();

            if ($existingDispute) {
                return response()->json(['status' => false, 'message' => 'An active dispute already exists for this opportunity.'], 400);
            }

            try {
                // Set opportunity status to under_dispute
                $opportunity->update(['status' => 'under_dispute']);

                $dispute = $this->disputeService->createCase([
                    'case_type' => 'opportunity_cancellation',
                    'requester_id' => $userId,
                    'other_party_id' => $userId, // Default to owner if no other party found
                    'opportunity_id' => $opportunity->id,
                    'reason' => $request->reason,
                ]);

                return response()->json([
                    'status' => true,
                    'message' => 'Cancellation dispute created successfully. An admin will review it.',
                    'data' => $dispute
                ], 201);
            } catch (\Exception $e) {
                return response()->json(['status' => false, 'message' => $e->getMessage()], 500);
            }
        });
    }

    /**
     * Show a dispute
     */
    public function show($id)
    {
        $dispute = DisputeCase::with(['requester', 'otherParty', 'assignedAdmin', 'chat'])->findOrFail($id);
        $user = Auth::user();

        // Authorization: must be requester, other_party, or assigned admin (or just any admin)
        if ($dispute->requester_id !== $user->id && $dispute->other_party_id !== $user->id && $user->role !== 'admin') {
            return response()->json(['status' => false, 'message' => 'Unauthorized'], 403);
        }

        return response()->json(['status' => true, 'data' => $dispute]);
    }

    /**
     * ADMIN: Decide Marketplace Refund
     */
    public function adminDecideRefund(Request $request, $id)
    {
        $request->validate([
            'decision' => 'required|in:approve,reject',
            'resolution' => 'nullable|string|max:2000'
        ]);

        $admin = Auth::user();
        if ($admin->role !== 'admin') {
            return response()->json(['status' => false, 'message' => 'Forbidden.'], 403);
        }

        try {
            return DB::transaction(function () use ($request, $id, $admin) {
                $dispute = DisputeCase::lockForUpdate()->findOrFail($id);

                if ($dispute->case_type !== 'marketplace_refund') {
                    throw new \Exception('Invalid dispute type.', 400);
                }

                if ($dispute->status === 'resolved' || $dispute->status === 'approved' || $dispute->status === 'rejected') {
                    throw new \Exception('Dispute already decided.', 400);
                }

                if ($request->decision === 'reject') {
                    $dispute->update([
                        'status' => 'rejected',
                        'resolution' => $request->resolution
                    ]);
                    return response()->json(['status' => true, 'message' => 'Refund rejected.', 'data' => $dispute]);
                }

                // If Approved, do atomic financial reversal
                $purchase = MarketplacePurchase::lockForUpdate()->findOrFail($dispute->marketplace_purchase_id);
                
                if ($purchase->status === 'refunded') {
                    throw new \Exception('Purchase already refunded.', 400);
                }

                $buyerId = $purchase->user_id;
                $sellerId = $purchase->item->user_id;

                $userIds = [$buyerId, $sellerId];
                sort($userIds);

                $lockedUsers = User::whereIn('id', $userIds)->lockForUpdate()->get()->keyBy('id');
                $buyer = $lockedUsers[$buyerId];
                $seller = $lockedUsers[$sellerId];

                $price = (float) $purchase->amount;
                $fee = $price * 0.05;
                $netAmount = $price - $fee;

                // Validate seller balance doesn't go dangerously negative
                // Instead, park it as awaiting_settlement
                if ($seller->balance < $netAmount) {
                    $dispute->update([
                        'status' => 'awaiting_settlement',
                        'resolution' => $request->resolution . ' [Awaiting seller balance settlement]'
                    ]);
                    return response()->json([
                        'status' => true,
                        'message' => 'Seller balance insufficient. Dispute parked awaiting settlement.',
                        'data' => $dispute
                    ]);
                }

                $buyer->balance += $price;
                $buyer->save();

                $seller->balance -= $netAmount;
                $seller->save();

                $refNumber = 'RF-' . strtoupper(\Illuminate\Support\Str::random(8)) . '-' . time();

                // Reversal Ledgers
                WalletTransaction::create([
                    'user_id' => $buyerId,
                    'type' => 'marketplace_refund_receive',
                    'amount' => $price,
                    'fee' => 0.00,
                    'payment_method' => 'wallet',
                    'status' => 'completed',
                    'reference_number' => $refNumber . '-BUY-' . $purchase->id,
                    'description' => 'Pengembalian dana (Refund) untuk karya "' . $purchase->item->title . '"',
                ]);

                WalletTransaction::create([
                    'user_id' => $sellerId,
                    'type' => 'marketplace_refund_deduct',
                    'amount' => $netAmount,
                    'fee' => 0.00,
                    'payment_method' => 'wallet',
                    'status' => 'completed',
                    'reference_number' => $refNumber . '-SELL-' . $purchase->id,
                    'description' => 'Penarikan dana refund untuk karya "' . $purchase->item->title . '"',
                ]);

                $purchase->update(['status' => 'refunded']);

                // Deactivate Performance Boost
                $perfEvent = CreatorPerformanceEvent::where('reference_id', $purchase->id)
                    ->where('event_type', 'marketplace_sale')
                    ->where('is_active', true)
                    ->first();

                if ($perfEvent) {
                    $perfEvent->update(['is_active' => false]);
                    $seller->refresh();
                    $seller->updatePerformanceBoost();
                }

                $dispute->update([
                    'status' => 'approved',
                    'resolution' => $request->resolution
                ]);

                return response()->json([
                    'status' => true,
                    'message' => 'Refund approved and executed successfully.',
                    'data' => $dispute
                ]);
            });
        } catch (\Exception $e) {
            $code = $e->getCode() ?: 500;
            if ($code < 100 || $code > 599) $code = 500;
            return response()->json(['status' => false, 'message' => $e->getMessage()], $code);
        }
    }

    /**
     * ADMIN: Settle Marketplace Refund from awaiting_settlement
     */
    public function adminSettleRefund(Request $request, $id)
    {
        $admin = Auth::user();
        if ($admin->role !== 'admin') {
            return response()->json(['status' => false, 'message' => 'Forbidden.'], 403);
        }

        try {
            return DB::transaction(function () use ($id, $admin) {
                $dispute = DisputeCase::lockForUpdate()->findOrFail($id);

                if ($dispute->case_type !== 'marketplace_refund') {
                    throw new \Exception('Invalid dispute type.', 400);
                }

                if ($dispute->status !== 'awaiting_settlement') {
                    throw new \Exception('Dispute is not awaiting settlement.', 400);
                }

                $purchase = MarketplacePurchase::lockForUpdate()->findOrFail($dispute->marketplace_purchase_id);
                
                if ($purchase->status === 'refunded') {
                    throw new \Exception('Purchase already refunded.', 400);
                }

                $buyerId = $purchase->user_id;
                $sellerId = $purchase->item->user_id;

                $userIds = [$buyerId, $sellerId];
                sort($userIds);

                $lockedUsers = User::whereIn('id', $userIds)->lockForUpdate()->get()->keyBy('id');
                $buyer = $lockedUsers[$buyerId];
                $seller = $lockedUsers[$sellerId];

                $price = (float) $purchase->amount;
                $fee = $price * 0.05;
                $netAmount = $price - $fee;

                if ($seller->balance < $netAmount) {
                    return response()->json([
                        'status' => false,
                        'message' => 'Seller balance still insufficient.',
                        'data' => $dispute
                    ], 400);
                }

                $buyer->balance += $price;
                $buyer->save();

                $seller->balance -= $netAmount;
                $seller->save();

                $refNumber = 'RF-STL-' . strtoupper(\Illuminate\Support\Str::random(6)) . '-' . time();

                WalletTransaction::create([
                    'user_id' => $buyerId,
                    'type' => 'marketplace_refund_receive',
                    'amount' => $price,
                    'fee' => 0.00,
                    'payment_method' => 'wallet',
                    'status' => 'completed',
                    'reference_number' => $refNumber . '-BUY-' . $purchase->id,
                    'description' => 'Pengembalian dana (Refund Settlement) untuk karya "' . $purchase->item->title . '"',
                ]);

                WalletTransaction::create([
                    'user_id' => $sellerId,
                    'type' => 'marketplace_refund_deduct',
                    'amount' => $netAmount,
                    'fee' => 0.00,
                    'payment_method' => 'wallet',
                    'status' => 'completed',
                    'reference_number' => $refNumber . '-SELL-' . $purchase->id,
                    'description' => 'Penarikan dana refund settlement untuk karya "' . $purchase->item->title . '"',
                ]);

                $purchase->update(['status' => 'refunded']);

                $perfEvent = CreatorPerformanceEvent::where('reference_id', $purchase->id)
                    ->where('event_type', 'marketplace_sale')
                    ->where('is_active', true)
                    ->first();

                if ($perfEvent) {
                    $perfEvent->update(['is_active' => false]);
                    $seller->refresh();
                    $seller->updatePerformanceBoost();
                }

                $dispute->update([
                    'status' => 'refunded',
                    'resolution' => $dispute->resolution . ' [Settlement Completed]'
                ]);

                return response()->json([
                    'status' => true,
                    'message' => 'Refund settlement executed successfully.',
                    'data' => $dispute
                ]);
            });
        } catch (\Exception $e) {
            $code = $e->getCode() ?: 500;
            if ($code < 100 || $code > 599) $code = 500;
            return response()->json(['status' => false, 'message' => $e->getMessage()], $code);
        }
    }

    /**
     * ADMIN: Decide Opportunity Cancellation
     */
    public function adminDecideCancellation(Request $request, $id)
    {
        $request->validate([
            'decision' => 'required|in:approve,reject',
            'resolution' => 'nullable|string|max:2000'
        ]);

        $admin = Auth::user();
        if ($admin->role !== 'admin') {
            return response()->json(['status' => false, 'message' => 'Forbidden.'], 403);
        }

        try {
            return DB::transaction(function () use ($request, $id) {
                $dispute = DisputeCase::lockForUpdate()->findOrFail($id);

                if ($dispute->case_type !== 'opportunity_cancellation') {
                    throw new \Exception('Invalid dispute type.', 400);
                }

                if ($dispute->status === 'resolved' || $dispute->status === 'approved' || $dispute->status === 'rejected') {
                    throw new \Exception('Dispute already decided.', 400);
                }

                if ($request->decision === 'reject') {
                    // Return opportunity back to open
                    $opportunity = Opportunity::lockForUpdate()->findOrFail($dispute->opportunity_id);
                    if ($opportunity->status === 'under_dispute') {
                        $opportunity->update(['status' => 'open']);
                    }

                    $dispute->update([
                        'status' => 'rejected',
                        'resolution' => $request->resolution
                    ]);
                    return response()->json(['status' => true, 'message' => 'Cancellation rejected.', 'data' => $dispute]);
                }

                // If Approved, update opportunity status to cancelled
                $opportunity = Opportunity::lockForUpdate()->findOrFail($dispute->opportunity_id);
                $opportunity->update(['status' => 'cancelled']);

                $dispute->update([
                    'status' => 'approved',
                    'resolution' => $request->resolution
                ]);

                return response()->json([
                    'status' => true,
                    'message' => 'Cancellation approved successfully.',
                    'data' => $dispute
                ]);
            });
        } catch (\Exception $e) {
            $code = $e->getCode() ?: 500;
            if ($code < 100 || $code > 599) $code = 500;
            return response()->json(['status' => false, 'message' => $e->getMessage()], $code);
        }
    }
}
