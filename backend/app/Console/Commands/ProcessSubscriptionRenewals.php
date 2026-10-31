<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Subscription;
use App\Models\WalletTransaction;
use App\Models\Notification;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class ProcessSubscriptionRenewals extends Command
{
    protected $signature = 'subscription:process-renewals';
    protected $description = 'Process automatic renewal for active subscriptions with auto_renew=true';

    private array $plans = [
        'plus'  => 69999,
        'pro'   => 199999,
        'super' => 379999,
    ];

    public function handle()
    {
        $this->info('Starting subscription auto-renewal process...');

        $now = Carbon::now();
        // Subscriptions due for renewal: auto_renew = true, expires_at <= now, and within last 3 days
        $dueSubs = Subscription::with('user')
            ->where('auto_renew', true)
            ->whereNotNull('expires_at')
            ->where('expires_at', '<=', $now)
            ->where('expires_at', '>=', $now->copy()->subDays(3))
            ->get();

        $processed = 0;
        $failed = 0;

        foreach ($dueSubs as $sub) {
            $user = $sub->user;
            if (!$user) continue;

            $price = $this->plans[$sub->tier] ?? 0;
            if ($price <= 0) continue;

            if ($user->balance < $price) {
                // Saldo tidak cukup: matikan auto_renew dan kirim notifikasi
                $sub->auto_renew = false;
                $sub->save();

                Notification::create([
                    'user_id' => $user->id,
                    'title'   => 'Perpanjangan Langganan Gagal',
                    'message' => 'Perpanjangan otomatis paket ' . ucfirst($sub->tier) . ' gagal karena saldo dompet tidak mencukupi (Rp ' . number_format($price, 0, ',', '.') . '). Silakan isi saldo untuk memperpanjang.',
                    'type'    => 'payment',
                    'data'    => ['tier' => $sub->tier],
                    'is_read' => false,
                ]);

                $this->warn("User {$user->id} insufficient balance for auto-renew {$sub->tier}");
                $failed++;
                continue;
            }

            DB::beginTransaction();
            try {
                $user->balance -= $price;
                $user->save();

                $newExpiry = Carbon::parse($sub->expires_at)->addMonth();
                if ($newExpiry->isPast()) {
                    $newExpiry = $now->copy()->addMonth();
                }
                $sub->expires_at = $newExpiry;
                $sub->save();

                WalletTransaction::create([
                    'user_id'          => $user->id,
                    'type'             => 'subscription_payment',
                    'amount'           => $price,
                    'fee'              => 0,
                    'payment_method'   => 'wallet',
                    'status'           => 'completed',
                    'reference_number' => 'SUB-RENEW-' . Str::upper(Str::random(8)),
                    'description'      => 'Perpanjangan Otomatis Paket ' . ucfirst($sub->tier) . ' (+1 Bulan)',
                ]);

                Notification::create([
                    'user_id' => $user->id,
                    'title'   => 'Langganan Berhasil Diperpanjang!',
                    'message' => 'Paket ' . ucfirst($sub->tier) . ' Anda telah diperpanjang otomatis hingga ' . $newExpiry->translatedFormat('d F Y') . '.',
                    'type'    => 'payment',
                    'data'    => ['tier' => $sub->tier, 'expires_at' => $newExpiry->toIso8601String()],
                    'is_read' => false,
                ]);

                DB::commit();
                $this->info("Auto-renewed {$sub->tier} for user {$user->id} until {$newExpiry}");
                $processed++;
            } catch (\Exception $e) {
                DB::rollBack();
                $this->error("Failed to auto-renew for user {$user->id}: " . $e->getMessage());
                $failed++;
            }
        }

        $this->info("Subscription renewals completed: {$processed} processed, {$failed} failed.");
    }
}
