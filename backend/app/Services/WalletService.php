<?php

namespace App\Services;

use App\Repositories\WalletTransactionRepository;
use App\Repositories\UserRepository;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Exception;

class WalletService extends BaseService
{
    protected WalletTransactionRepository $walletRepo;
    protected UserRepository $userRepo;

    public function __construct(WalletTransactionRepository $walletRepo, UserRepository $userRepo)
    {
        $this->walletRepo = $walletRepo;
        $this->userRepo = $userRepo;
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
            $user = $this->userRepo->find($userId);
            $this->userRepo->update($userId, ['balance' => $user->balance + $transaction->amount]);

            DB::commit();

            return [
                'balance' => (double) ($user->balance + $transaction->amount),
                'transaction' => $this->walletRepo->find($transaction->id),
            ];
        } catch (Exception $e) {
            DB::rollBack();
            throw new Exception('Gagal memproses simulasi pembayaran. Silakan coba lagi.', 500);
        }
    }

    public function transfer(int $senderId, array $data): array
    {
        $sender = $this->userRepo->find($senderId);
        $receiver = $this->userRepo->findByEmailOrUsername($data['receiver_username']); // Using existing method

        if (!$receiver) {
             throw new Exception('Penerima tidak ditemukan.', 404);
        }

        if ($sender->id === $receiver->id) {
            throw new Exception('Tidak dapat mengirim saldo ke diri sendiri.', 400);
        }

        if ($sender->balance < $data['amount']) {
            throw new Exception('Saldo tidak mencukupi untuk transfer.', 400);
        }

        try {
            DB::beginTransaction();
            $fee = $data['amount'] * 0.05;
            $netAmount = $data['amount'] - $fee;
            $refNumber = 'TX-' . strtoupper(Str::random(8)) . '-' . time();

            $this->userRepo->update($sender->id, ['balance' => $sender->balance - $data['amount']]);
            $this->userRepo->update($receiver->id, ['balance' => $receiver->balance + $netAmount]);

            $senderTx = $this->walletRepo->create([
                'user_id' => $sender->id,
                'type' => 'transfer_send',
                'amount' => $data['amount'],
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

            DB::commit();

            return [
                'sender_balance' => (double) ($sender->balance - $data['amount']),
                'fee' => $fee,
                'net_amount' => $netAmount,
                'transaction' => $senderTx,
            ];
        } catch (Exception $e) {
            DB::rollBack();
            throw new Exception('Transfer gagal diproses. Silakan coba lagi.', 500);
        }
    }

    public function withdraw(string $userId, array $data): array
    {
        $user = $this->userRepo->find($userId);

        if ($user->balance < $data['amount']) {
            throw new Exception('Saldo tidak mencukupi untuk melakukan penarikan.', 400);
        }

        try {
            DB::beginTransaction();
            $tax = $data['amount'] * 0.05; 
            $netAmount = $data['amount'] - $tax;
            $refNumber = 'WD-' . strtoupper(Str::random(8)) . '-' . time();

            $this->userRepo->update($user->id, ['balance' => $user->balance - $data['amount']]);

            $transaction = $this->walletRepo->create([
                'user_id' => $user->id,
                'type' => 'withdrawal',
                'amount' => $data['amount'],
                'fee' => $tax,
                'payment_method' => $data['payment_method'],
                'payment_provider' => $data['payment_provider'],
                'status' => 'completed',
                'reference_number' => $refNumber,
                'description' => "Penarikan saldo ke {$data['payment_provider']} ({$data['account_number']}). Potongan pajak 5%: Rp " . number_format($tax, 0, ',', '.'),
            ]);

            DB::commit();

            return [
                'balance' => (double) ($user->balance - $data['amount']),
                'tax' => $tax,
                'net_amount' => $netAmount,
                'transaction' => $transaction,
            ];
        } catch (Exception $e) {
            DB::rollBack();
            throw new Exception('Penarikan saldo gagal. Silakan coba lagi.', 500);
        }
    }
}
