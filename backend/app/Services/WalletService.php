<?php

namespace App\Services;

use App\Models\User;
use App\Repositories\WalletTransactionRepository;
use App\Repositories\UserRepository;
use App\Repositories\NotificationRepository;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Exception;

class WalletService extends BaseService
{
    protected WalletTransactionRepository $walletRepo;
    protected UserRepository $userRepo;
    protected NotificationRepository $notificationRepo;

    public function __construct(WalletTransactionRepository $walletRepo, UserRepository $userRepo, NotificationRepository $notificationRepo)
    {
        $this->walletRepo = $walletRepo;
        $this->userRepo = $userRepo;
        $this->notificationRepo = $notificationRepo;
    }

    public function getInfo(string $userId): array
    {
        $user = $this->userRepo->find($userId);
        $transactions = $this->walletRepo->getHistoryByUser($userId, null, 100);

        return [
            'balance' => (double) $user->balance,
            'transactions' => $transactions->items(),
        ];
    }

    public function createTopup(string $userId, array $data): array
    {
        $user = $this->userRepo->find($userId);
        $refNumber = 'TOPUP-' . strtoupper(Str::random(8)) . '-' . time();
        $description = 'Top Up Saldo via ' . $data['payment_provider'];

        $transaction = $this->walletRepo->create([
            'user_id' => $user->id,
            'type' => 'topup',
            'amount' => $data['amount'],
            'fee' => 0.00,
            'payment_method' => $data['payment_method'],
            'payment_provider' => $data['payment_provider'],
            'status' => 'pending',
            'reference_number' => $refNumber,
            'description' => $description,
        ]);

        $paymentDetails = [];
        if ($data['payment_method'] === 'bank_transfer') {
            $paymentDetails = [
                'va_number' => '88012' . str_pad($user->phone ?? $user->id, 11, '0', STR_PAD_LEFT),
                'bank_name' => strtoupper($data['payment_provider']),
                'account_name' => 'KREAVANA - ' . strtoupper($user->name),
            ];
        } elseif ($data['payment_method'] === 'e_wallet') {
            $paymentDetails = [
                'deeplink' => 'kreavana://pay/wallet/' . $refNumber,
                'qr_url' => 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=kreavana_ewallet_' . $refNumber,
                'phone_number' => $user->phone ?? '081234567890',
            ];
        } else {
            $paymentDetails = [
                'qr_string' => '00020101021126670016ID.CO.QRIS.WWW0118936000020111111115204000053033605802ID5920KREAVANA PLATFORM6009JAKARTA61051212062070703A016304523F',
                'qr_url' => 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=kreavana_qris_' . $refNumber,
            ];
        }

        return [
            'transaction' => $transaction,
            'payment_details' => $paymentDetails,
        ];
    }

    public function simulatePay(string $userId, string $referenceNumber): array
    {
        $transaction = $this->walletRepo->all()->where('reference_number', $referenceNumber)->first();

        if ($transaction->user_id !== $userId) {
            throw new Exception('Anda tidak memiliki akses ke transaksi ini.', 403);
        }

        if ($transaction->status !== 'pending') {
            throw new Exception('Transaksi ini sudah diproses atau tidak lagi pending.', 400);
        }

        if ($transaction->type !== 'topup') {
            throw new Exception('Hanya transaksi top-up yang dapat disimulasikan pembayarannya.', 400);
        }

        try {
            DB::beginTransaction();

            $this->walletRepo->update($transaction->id, ['status' => 'completed']);
            $user = User::where('id', $userId)->lockForUpdate()->first();
            if (!$user) {
                throw new Exception('Pengguna tidak ditemukan.', 404);
            }
            $user->balance += $transaction->amount;
            $user->save();

            $this->notificationRepo->create([
                'user_id' => $userId,
                'title' => 'Top Up Berhasil',
                'message' => 'Saldo sebesar Rp ' . number_format($transaction->amount, 0, ',', '.') . ' berhasil ditambahkan ke dompet Anda.',
                'type' => 'wallet',
                'data' => ['transaction_id' => $transaction->id, 'amount' => $transaction->amount],
                'is_read' => false,
                'created_at' => now(),
            ]);

            DB::commit();

            return [
                'balance' => (double) $user->balance,
                'transaction' => $this->walletRepo->find($transaction->id),
            ];
        } catch (Exception $e) {
            DB::rollBack();
            throw new Exception($e->getCode() === 404 ? $e->getMessage() : 'Gagal memproses simulasi pembayaran. Silakan coba lagi.', $e->getCode() ?: 500);
        }
    }

    public function transfer(string $senderId, array $data): array
    {
        $amount = (float) $data['amount'];
        $receiverUser = $this->userRepo->findByEmailOrUsername($data['receiver_username']);

        if (!$receiverUser) {
             throw new Exception('Penerima tidak ditemukan.', 404);
        }

        if ($senderId === $receiverUser->id) {
            throw new Exception('Tidak dapat mengirim saldo ke diri sendiri.', 400);
        }

        try {
            DB::beginTransaction();

            // Lock both users in sorted order to avoid deadlock
            $userIds = [$senderId, $receiverUser->id];
            sort($userIds);

            $lockedUsers = User::whereIn('id', $userIds)
                ->lockForUpdate()
                ->get()
                ->keyBy('id');

            $sender = $lockedUsers[$senderId] ?? null;
            $receiver = $lockedUsers[$receiverUser->id] ?? null;

            if (!$sender || !$receiver) {
                throw new Exception('Data pengguna tidak ditemukan.', 404);
            }

            if ($sender->balance < $amount) {
                throw new Exception('Saldo tidak mencukupi untuk transfer.', 400);
            }

            $fee = $amount * 0.05;
            $netAmount = $amount - $fee;
            $refNumber = 'TX-' . strtoupper(Str::random(8)) . '-' . time();

            $sender->balance -= $amount;
            $sender->save();

            $receiver->balance += $netAmount;
            $receiver->save();

            $senderTx = $this->walletRepo->create([
                'user_id' => $sender->id,
                'type' => 'transfer_send',
                'amount' => $amount,
                'fee' => $fee,
                'payment_method' => 'wallet',
                'payment_provider' => 'Kreavana Wallet',
                'status' => 'completed',
                'reference_number' => $refNumber . '-SEND',
                'description' => "Kirim saldo ke @{$receiver->username}. " . ($data['description'] ?? ''),
            ]);

            $this->walletRepo->create([
                'user_id' => $receiver->id,
                'type' => 'transfer_receive',
                'amount' => $netAmount,
                'fee' => $fee,
                'payment_method' => 'wallet',
                'payment_provider' => 'Kreavana Wallet',
                'status' => 'completed',
                'reference_number' => $refNumber . '-RCV',
                'description' => "Terima saldo dari @{$sender->username}. " . ($data['description'] ?? ''),
            ]);

            $this->notificationRepo->create([
                'user_id' => $receiver->id,
                'title' => 'Saldo Masuk',
                'message' => 'Anda menerima transfer saldo sebesar Rp ' . number_format($netAmount, 0, ',', '.') . ' dari @' . $sender->username . '.',
                'type' => 'wallet',
                'data' => ['sender_id' => $sender->id, 'amount' => $netAmount, 'fee' => $fee],
                'is_read' => false,
                'created_at' => now(),
            ]);

            DB::commit();

            return [
                'sender_balance' => (double) $sender->balance,
                'fee' => $fee,
                'net_amount' => $netAmount,
                'transaction' => $senderTx,
            ];
        } catch (Exception $e) {
            DB::rollBack();
            if (in_array($e->getCode(), [400, 404])) {
                throw $e;
            }
            throw new Exception('Transfer gagal diproses. Silakan coba lagi.', 500);
        }
    }

    public function withdraw(string $userId, array $data): array
    {
        $amount = (float) $data['amount'];

        try {
            DB::beginTransaction();

            $user = User::where('id', $userId)->lockForUpdate()->first();

            if (!$user) {
                throw new Exception('Pengguna tidak ditemukan.', 404);
            }

            if ($user->balance < $amount) {
                throw new Exception('Saldo tidak mencukupi untuk melakukan penarikan.', 400);
            }

            $tax = $amount * 0.05; 
            $netAmount = $amount - $tax;
            $refNumber = 'WD-' . strtoupper(Str::random(8)) . '-' . time();

            $user->balance -= $amount;
            $user->save();

            $transaction = $this->walletRepo->create([
                'user_id' => $user->id,
                'type' => 'withdrawal',
                'amount' => $amount,
                'fee' => $tax,
                'payment_method' => $data['payment_method'],
                'payment_provider' => $data['payment_provider'],
                'status' => 'completed',
                'reference_number' => $refNumber,
                'description' => "Penarikan saldo ke {$data['payment_provider']} ({$data['account_number']}). Potongan pajak 5%: Rp " . number_format($tax, 0, ',', '.'),
            ]);

            DB::commit();

            return [
                'balance' => (double) $user->balance,
                'tax' => $tax,
                'net_amount' => $netAmount,
                'transaction' => $transaction,
            ];
        } catch (Exception $e) {
            DB::rollBack();
            if (in_array($e->getCode(), [400, 404])) {
                throw $e;
            }
            throw new Exception('Penarikan saldo gagal. Silakan coba lagi.', 500);
        }
    }
}
