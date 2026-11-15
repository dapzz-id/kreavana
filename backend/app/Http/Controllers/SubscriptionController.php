<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Subscription;
use App\Models\WalletTransaction;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class SubscriptionController extends Controller
{
    /**
     * Single source of truth for plan pricing & features.
     * NEVER expose raw prices from the frontend — always fetch this.
     */
    private array $plans = [
        'basic' => [
            'tier'     => 'basic',
            'name'     => 'Basic',
            'price'    => 0,
            'label'    => 'Saat ini',
            'features' => [
                'Durasi call standar',
                'Storage 512 MB',
                'Tanpa boost',
            ],
            'is_popular' => false,
        ],
        'plus' => [
            'tier'     => 'plus',
            'name'     => 'Plus',
            'price'    => 69999,
            'label'    => 'Rp 69.999 / bln',
            'features' => [
                'Boost akun 1.5x',
                'Voice call: 80 menit',
                'Video call: 45 menit',
                'Storage 3 GB',
                'Rekomendasi AI (Kreator & Peluang)',
            ],
            'is_popular' => false,
        ],
        'pro' => [
            'tier'     => 'pro',
            'name'     => 'Pro',
            'price'    => 199999,
            'label'    => 'Rp 199.999 / bln',
            'features' => [
                'Boost akun 2x',
                'Voice call: 100 menit',
                'Video call: 60 menit',
                'Storage 10 GB',
                'Fitur AI & Rekomendasi Pintar',
            ],
            'is_popular' => true,
        ],
        'super' => [
            'tier'     => 'super',
            'name'     => 'Super',
            'price'    => 379999,
            'label'    => 'Rp 379.999 / bln',
            'features' => [
                'Boost akun 5x',
                'Voice call: 120 menit',
                'Video call: 75 menit',
                'Storage 20 GB',
                'Fitur AI & Rekomendasi Pintar',
                'Layanan Prioritas',
            ],
            'is_popular' => false,
        ],
    ];

    /**
     * GET /subscription/plans
     * Returns all plan definitions (name, price, features).
     * This is the ONLY place prices are defined; frontend must not hardcode them.
     */
    public function plans(Request $request)
    {
        $authUser = auth('api')->user();
        $currentTier = $authUser ? strtolower($authUser->subscription_tier ?? 'basic') : null;

        $plans = array_values(array_map(function ($plan) use ($currentTier) {
            // Sembunyikan teks "Boost akun" / "Tanpa boost" sementara pada Pilih Paket Upgrade
            // karena fitur belum siap utuh untuk institusi; logika boost di backend tetap dipertahankan.
            $plan['features'] = array_values(array_filter($plan['features'], function ($feature) {
                return !preg_match('/boost/i', $feature);
            }));

            $isCurrent = ($currentTier === $plan['tier']) 
                || (empty($currentTier) && $plan['tier'] === 'basic')
                || ($currentTier === 'free' && $plan['tier'] === 'basic');
            $plan['is_current'] = $isCurrent;

            return $plan;
        }, $this->plans));

        return response()->json([
            'status' => true,
            'data'   => $plans,
        ]);
    }

    public function purchase(Request $request)
    {
        $request->validate([
            'tier'       => 'required|in:plus,pro,super',
            'auto_renew' => 'boolean',
            'pin'        => 'required|string|min:4|max:8',
        ]);

        $user = $request->user();

        // ── Wallet PIN gate (same logic as ShopeePay) ───────────────────────
        if (empty($user->wallet_pin)) {
            return response()->json([
                'message' => 'Wallet belum diaktifkan. Silakan aktifkan wallet dan atur PIN terlebih dahulu.',
                'error_code' => 'wallet_not_activated',
            ], 422);
        }

        if (!Hash::check($request->pin, $user->wallet_pin)) {
            return response()->json(['message' => 'PIN Dompet salah.'], 403);
        }

        $tier = $request->tier;
        $price = $this->plans[$tier]['price'];

        // ── Guard: Cegah downgrade ke paket yang lebih rendah ──
        $tierRanks = [
            'free'  => 0,
            'basic' => 0,
            'plus'  => 1,
            'pro'   => 2,
            'super' => 3,
        ];
        $currentTier = strtolower($user->subscription_tier ?? 'free');
        $currentRank = $tierRanks[$currentTier] ?? 0;
        $requestedRank = $tierRanks[$tier] ?? 0;

        if ($requestedRank < $currentRank) {
            return response()->json([
                'message' => 'Tidak dapat memilih paket yang lebih rendah dari paket aktif Anda.',
                'error_code' => 'downgrade_not_allowed',
            ], 400);
        }

        $isRenewal = ($requestedRank === $currentRank && $currentRank > 0);

        if ($user->balance < $price) {
            return response()->json([
                'message' => 'Saldo dompet tidak mencukupi untuk ' . ($isRenewal ? 'memperpanjang' : 'berlangganan') . ' paket ini.',
                'error_code' => 'insufficient_balance',
                'required' => $price,
                'current' => $user->balance
            ], 400);
        }

        $autoRenew = $request->boolean('auto_renew', false);

        DB::beginTransaction();
        try {
            // 1. Potong saldo user
            $user->balance -= $price;
            $user->save();

            if ($isRenewal) {
                // Perpanjang langganan aktif yang ada (+1 bulan dari masa aktif saat ini)
                $activeSub = $user->activeSubscription;
                $currentExpiry = ($activeSub && $activeSub->expires_at && Carbon::parse($activeSub->expires_at)->isFuture())
                    ? Carbon::parse($activeSub->expires_at)
                    : now();
                $newExpiry = $currentExpiry->copy()->addMonth();

                if ($activeSub) {
                    $activeSub->expires_at = $newExpiry;
                    if ($request->has('auto_renew')) {
                        $activeSub->auto_renew = $autoRenew;
                    }
                    $activeSub->save();
                    $subscription = $activeSub;
                } else {
                    $subscription = Subscription::create([
                        'user_id' => $user->id,
                        'tier' => $tier,
                        'price_paid' => $price,
                        'auto_renew' => $autoRenew,
                        'expires_at' => $newExpiry,
                    ]);
                }

                $txDescription = 'Perpanjangan Paket ' . ucfirst($tier) . ' (+1 Bulan)';
                $successMessage = 'Berhasil memperpanjang paket ' . ucfirst($tier) . ' selama 1 bulan.';
            } else {
                // 2. Kadaluarsakan langganan aktif sebelumnya jika ada
                Subscription::where('user_id', $user->id)
                    ->where(function ($q) {
                        $q->whereNull('expires_at')->orWhere('expires_at', '>', now());
                    })
                    ->update(['expires_at' => now(), 'auto_renew' => false]);

                // 3. Buat data langganan baru
                $subscription = Subscription::create([
                    'user_id' => $user->id,
                    'tier' => $tier,
                    'price_paid' => $price,
                    'auto_renew' => $autoRenew,
                    'expires_at' => now()->addMonth(),
                ]);

                $txDescription = 'Pembelian Paket ' . ucfirst($tier) . ' (1 Bulan)';
                $successMessage = 'Berhasil berlangganan paket ' . ucfirst($tier);
            }

            // 4. Catat riwayat transaksi wallet
            WalletTransaction::create([
                'user_id' => $user->id,
                'type' => 'subscription_payment',
                'amount' => $price,
                'fee' => 0,
                'payment_method' => 'wallet',
                'status' => 'completed',
                'reference_number' => 'SUB-' . Str::upper(Str::random(10)),
                'description' => $txDescription,
            ]);

            // 5. Update performance boost jika kreator (setelah langganan aktif tercatat di DB)
            $userRole = is_object($user->role) ? $user->role->value : (string) $user->role;
            if (in_array(strtolower($userRole), ['creator', 'kreator'])) {
                $user->updatePerformanceBoost();
            }

            DB::commit();

            return response()->json([
                'message' => $successMessage,
                'subscription' => $subscription,
                'tier' => $subscription->tier,
                'is_renewal' => $isRenewal,
                'expires_at' => $subscription->expires_at,
                'auto_renew' => $subscription->auto_renew,
                'new_balance' => $user->balance
            ]);
        } catch (\Exception $e) {
            DB::rollBack();
            \Illuminate\Support\Facades\Log::error('Gagal memproses langganan: ' . $e->getMessage(), [
                'user_id' => $user->id ?? null,
                'tier' => $tier ?? null,
                'trace' => $e->getTraceAsString(),
            ]);
            return response()->json(['message' => 'Gagal memproses langganan.', 'error' => $e->getMessage()], 500);
        }
    }

    public function toggleAutoRenew(Request $request)
    {
        $user = $request->user();
        $activeSub = $user->activeSubscription;

        if (!$activeSub) {
            return response()->json([
                'status' => false,
                'message' => 'Anda tidak memiliki paket langganan aktif saat ini.',
            ], 404);
        }

        $activeSub->auto_renew = $request->has('auto_renew')
            ? $request->boolean('auto_renew')
            : !$activeSub->auto_renew;
        $activeSub->save();

        return response()->json([
            'status' => true,
            'message' => $activeSub->auto_renew
                ? 'Perpanjangan otomatis berhasil diaktifkan.'
                : 'Perpanjangan otomatis berhasil dinonaktifkan.',
            'auto_renew' => $activeSub->auto_renew,
            'subscription' => $activeSub,
        ]);
    }

    public function getCurrent(Request $request)
    {
        $user = $request->user();
        $activeSub = $user->activeSubscription;

        $expiresAtFormatted = null;
        $daysRemaining = null;
        if ($activeSub && $activeSub->expires_at) {
            $exp = Carbon::parse($activeSub->expires_at);
            $expiresAtFormatted = $exp->translatedFormat('d F Y');
            $daysRemaining = max(0, (int) now()->diffInDays($exp, false));
        }

        return response()->json([
            'status' => true,
            'tier' => $user->subscription_tier,
            'storage_limit_bytes' => $user->storage_limit_bytes,
            'used_storage_bytes' => $user->used_storage_bytes,
            'active_subscription' => $activeSub,
            'auto_renew' => $activeSub ? (bool) $activeSub->auto_renew : false,
            'expires_at' => $activeSub?->expires_at,
            'expires_at_formatted' => $expiresAtFormatted,
            'days_remaining' => $daysRemaining,
        ]);
    }
}
