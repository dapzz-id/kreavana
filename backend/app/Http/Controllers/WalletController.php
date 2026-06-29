<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use App\Models\User;
use App\Models\WalletTransaction;

class WalletController extends Controller
{
    /**
     * Get wallet balance and transactions.
     */
    public function info()
    {
        $user = Auth::guard('api')->user();

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Pengguna tidak terautentikasi.',
            ], 401);
        }

        $transactions = WalletTransaction::where('user_id', $user->id)
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'success' => true,
            'data' => [
                'balance' => (double) $user->balance,
                'transactions' => $transactions,
            ],
        ]);
    }

    /**
     * Create a pending top-up transaction.
     */
    public function topup(Request $request)
    {
        $user = Auth::guard('api')->user();

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Pengguna tidak terautentikasi.',
            ], 401);
        }

        $request->validate([
            'amount' => 'required|numeric|min:10000',
            'payment_method' => 'required|string|in:qris,bank_transfer,e_wallet',
            'payment_provider' => 'required|string|max:100',
        ]);

        $refNumber = 'TOPUP-' . strtoupper(Str::random(8)) . '-' . time();
        $description = 'Top Up Saldo via ' . $request->payment_provider;

        $transaction = WalletTransaction::create([
            'user_id' => $user->id,
            'type' => 'topup',
            'amount' => $request->amount,
            'fee' => 0.00,
            'payment_method' => $request->payment_method,
            'payment_provider' => $request->payment_provider,
            'status' => 'pending',
            'reference_number' => $refNumber,
            'description' => $description,
        ]);

        // Generate payment details/instructions
        $paymentDetails = [];
        if ($request->payment_method === 'bank_transfer') {
            $paymentDetails = [
                'va_number' => '88012' . str_pad($user->phone ?? $user->id, 11, '0', STR_PAD_LEFT),
                'bank_name' => strtoupper($request->payment_provider),
                'account_name' => 'KREAVANA - ' . strtoupper($user->name),
            ];
        } elseif ($request->payment_method === 'e_wallet') {
            $paymentDetails = [
                'deeplink' => 'kreavana://pay/wallet/' . $refNumber,
                'qr_url' => 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=kreavana_ewallet_' . $refNumber,
                'phone_number' => $user->phone ?? '081234567890',
            ];
        } else { // qris
            $paymentDetails = [
                'qr_string' => '00020101021126670016ID.CO.QRIS.WWW0118936000020111111115204000053033605802ID5920KREAVANA PLATFORM6009JAKARTA61051212062070703A016304523F',
                'qr_url' => 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=kreavana_qris_' . $refNumber,
            ];
        }

        return response()->json([
            'success' => true,
            'message' => 'Transaksi top up pending berhasil dibuat.',
            'data' => [
                'transaction' => $transaction,
                'payment_details' => $paymentDetails,
            ],
        ], 201);
    }

    /**
     * Simulate a successful payment for a pending top-up.
     */
    public function simulatePay(Request $request)
    {
        $request->validate([
            'reference_number' => 'required|string|exists:wallet_transactions,reference_number',
        ]);

        $transaction = WalletTransaction::where('reference_number', $request->reference_number)->first();

        if ($transaction->status !== 'pending') {
            return response()->json([
                'success' => false,
                'message' => 'Transaksi ini sudah diproses atau tidak lagi pending.',
            ], 400);
        }

        if ($transaction->type !== 'topup') {
            return response()->json([
                'success' => false,
                'message' => 'Hanya transaksi top-up yang dapat disimulasikan pembayarannya.',
            ], 400);
        }

        DB::beginTransaction();
        try {
            // Update transaction status
            $transaction->status = 'completed';
            $transaction->save();

            // Update user balance
            $user = User::find($transaction->user_id);
            $user->balance += $transaction->amount;
            $user->save();

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Simulasi pembayaran sukses berhasil diproses.',
                'data' => [
                    'balance' => (double) $user->balance,
                    'transaction' => $transaction,
                ],
            ]);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Gagal memproses simulasi pembayaran: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Transfer balance to another user.
     */
    public function transfer(Request $request)
    {
        $sender = Auth::guard('api')->user();

        if (!$sender) {
            return response()->json([
                'success' => false,
                'message' => 'Pengguna tidak terautentikasi.',
            ], 401);
        }

        $request->validate([
            'receiver_username' => 'required|string|exists:users,username',
            'amount' => 'required|numeric|min:10000',
            'description' => 'nullable|string|max:255',
        ]);

        $receiver = User::where('username', $request->receiver_username)->first();

        if ($sender->id === $receiver->id) {
            return response()->json([
                'success' => false,
                'message' => 'Tidak dapat mengirim saldo ke diri sendiri.',
            ], 400);
        }

        if ($sender->balance < $request->amount) {
            return response()->json([
                'success' => false,
                'message' => 'Saldo tidak mencukupi untuk transfer.',
            ], 400);
        }

        DB::beginTransaction();
        try {
            $fee = $request->amount * 0.05; // 5% fee / pajak transaksi
            $netAmount = $request->amount - $fee;
            $refNumber = 'TX-' . strtoupper(Str::random(8)) . '-' . time();

            // Deduct sender balance
            $sender->balance -= $request->amount;
            $sender->save();

            // Add receiver balance
            $receiver->balance += $netAmount;
            $receiver->save();

            // Create transaction for sender (outgoing)
            $senderTx = WalletTransaction::create([
                'user_id' => $sender->id,
                'type' => 'transfer_send',
                'amount' => $request->amount,
                'fee' => $fee,
                'payment_method' => 'wallet',
                'payment_provider' => 'Kreavana Wallet',
                'status' => 'completed',
                'reference_number' => $refNumber . '-SEND',
                'description' => "Kirim saldo ke @{$receiver->username}. " . ($request->description ?? ''),
            ]);

            // Create transaction for receiver (incoming)
            $receiverTx = WalletTransaction::create([
                'user_id' => $receiver->id,
                'type' => 'transfer_receive',
                'amount' => $netAmount,
                'fee' => $fee,
                'payment_method' => 'wallet',
                'payment_provider' => 'Kreavana Wallet',
                'status' => 'completed',
                'reference_number' => $refNumber . '-RCV',
                'description' => "Terima saldo dari @{$sender->username}. " . ($request->description ?? ''),
            ]);

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Transfer berhasil dikirim.',
                'data' => [
                    'sender_balance' => (double) $sender->balance,
                    'fee' => $fee,
                    'net_amount' => $netAmount,
                    'transaction' => $senderTx,
                ],
            ]);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Transfer gagal diproses: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Withdraw balance to bank or e-wallet.
     */
    public function withdraw(Request $request)
    {
        $user = Auth::guard('api')->user();

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Pengguna tidak terautentikasi.',
            ], 401);
        }

        $request->validate([
            'amount' => 'required|numeric|min:10000',
            'payment_method' => 'required|string|in:bank_transfer,e_wallet',
            'payment_provider' => 'required|string|max:100',
            'account_number' => 'required|string|max:100',
        ]);

        if ($user->balance < $request->amount) {
            return response()->json([
                'success' => false,
                'message' => 'Saldo tidak mencukupi untuk melakukan penarikan.',
            ], 400);
        }

        DB::beginTransaction();
        try {
            // Apply 5% tax/fee for app creator revenue
            $tax = $request->amount * 0.05; 
            $netAmount = $request->amount - $tax;
            $refNumber = 'WD-' . strtoupper(Str::random(8)) . '-' . time();

            // Deduct user balance
            $user->balance -= $request->amount;
            $user->save();

            // Create transaction record
            $transaction = WalletTransaction::create([
                'user_id' => $user->id,
                'type' => 'withdrawal',
                'amount' => $request->amount,
                'fee' => $tax,
                'payment_method' => $request->payment_method,
                'payment_provider' => $request->payment_provider,
                'status' => 'completed', // Completed instantly for simulation
                'reference_number' => $refNumber,
                'description' => "Penarikan saldo ke {$request->payment_provider} ({$request->account_number}). Potongan pajak 5%: Rp " . number_format($tax, 0, ',', '.'),
            ]);

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Penarikan saldo berhasil diproses.',
                'data' => [
                    'balance' => (double) $user->balance,
                    'tax' => $tax,
                    'net_amount' => $netAmount,
                    'transaction' => $transaction,
                ],
            ]);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Penarikan saldo gagal: ' . $e->getMessage(),
            ], 500);
        }
    }
}
