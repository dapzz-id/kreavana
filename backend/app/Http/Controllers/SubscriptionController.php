<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Subscription;
use App\Models\WalletTransaction;
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
                'Storage bawaan',
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
                'Fitur AI',
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
                'Fitur AI',
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
    public function plans()
    {
        return response()->json([
            'status' => true,
            'data'   => array_values($this->plans),
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
            return response()->json(['message' => 'PIN salah.'], 401);
        }
        // ────────────────────────────────────────────────────────────────────

        $tier      = $request->tier;
        $price     = $this->plans[$tier]['price'];
        $autoRenew = $request->input('auto_renew', false);

        if ($user->balance < $price) {
            return response()->json(['message' => 'Saldo tidak mencukupi untuk membeli paket ini.'], 400);
        }

        try {
            DB::beginTransaction();

            $user->balance -= $price;
            $user->save();

            WalletTransaction::create([
                'user_id' => $user->id,
                'type' => 'subscription_payment',
                'amount' => -$price,
                'fee' => 0,
                'status' => 'completed',
                'reference_number' => 'SUB-' . Str::upper(Str::random(10)),
                'description' => 'Pembelian Paket ' . ucfirst($tier) . ' (1 Bulan)',
            ]);

            $subscription = Subscription::create([
                'user_id' => $user->id,
                'tier' => $tier,
                'price_paid' => $price,
                'auto_renew' => $autoRenew,
                'expires_at' => now()->addMonth(),
            ]);

            DB::commit();

            return response()->json([
                'message' => 'Berhasil berlangganan paket ' . ucfirst($tier),
                'subscription' => $subscription,
                'new_balance' => $user->balance
            ]);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['message' => 'Gagal memproses langganan.', 'error' => $e->getMessage()], 500);
        }
    }

    public function getCurrent(Request $request)
    {
        $user = $request->user();
        return response()->json([
            'tier' => $user->subscription_tier,
            'storage_limit_bytes' => $user->storage_limit_bytes,
            'used_storage_bytes' => $user->used_storage_bytes,
            'active_subscription' => $user->activeSubscription,
        ]);
    }
}
