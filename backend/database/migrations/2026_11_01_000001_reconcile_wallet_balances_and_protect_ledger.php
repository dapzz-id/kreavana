<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;
use App\Models\User;
use App\Models\WalletTransaction;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Tambahkan kolom ledger_hash untuk proteksi integritas kriptografis ala blockchain
        if (!Schema::hasColumn('wallet_transactions', 'ledger_hash')) {
            Schema::table('wallet_transactions', function (Blueprint $table) {
                $table->string('ledger_hash', 64)->nullable()->after('description');
            });
        }

        // 2. Rekonsiliasi saldo pengguna yang terdampak seeder reset
        try {
            $users = User::all();
            foreach ($users as $user) {
                $completedCredits = (float) DB::table('wallet_transactions')
                    ->where('user_id', $user->id)
                    ->where('status', 'completed')
                    ->whereIn('type', ['topup', 'transfer_receive', 'refund', 'escrow_refund'])
                    ->sum('amount');

                $completedDebits = (float) DB::table('wallet_transactions')
                    ->where('user_id', $user->id)
                    ->where('status', 'completed')
                    ->whereIn('type', ['transfer_send', 'withdrawal', 'payment', 'contract_payment'])
                    ->sum('amount');

                $netMovement = $completedCredits - $completedDebits;
                $expectedBalance = max(0.0, $netMovement);

                // Jika saldo pengguna saat ini di bawah kalkulasi ledger (tertimpa seeder), pulihkan nilainya
                if ($completedCredits > 0 && (float) $user->balance < $expectedBalance) {
                    DB::table('users')->where('id', $user->id)->update([
                        'balance' => $expectedBalance,
                    ]);
                }
            }

            // 3. Generate initial ledger hash untuk transaksi yang belum memiliki hash
            $transactions = DB::table('wallet_transactions')->whereNull('ledger_hash')->get();
            $appKey = config('app.key') ?: 'kreavana_cryptographic_ledger_seed';

            foreach ($transactions as $tx) {
                $payload = implode('|', [
                    $tx->id,
                    $tx->user_id,
                    number_format((float) $tx->amount, 2, '.', ''),
                    $tx->type,
                    $tx->reference_number,
                    $tx->status,
                ]);
                $hash = hash_hmac('sha256', $payload, $appKey);

                DB::table('wallet_transactions')
                    ->where('id', $tx->id)
                    ->update(['ledger_hash' => $hash]);
            }
        } catch (\Throwable $e) {
            // Log & continue agar migrasi tidak menggagalkan deploy jika tabel kosong
            \Illuminate\Support\Facades\Log::warning('Wallet balance ledger reconciliation note: ' . $e->getMessage());
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('wallet_transactions', 'ledger_hash')) {
            Schema::table('wallet_transactions', function (Blueprint $table) {
                $table->dropColumn('ledger_hash');
            });
        }
    }
};

