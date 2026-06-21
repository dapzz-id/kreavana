<?php

namespace App\Http\Controllers;

use App\Models\Photo;
use App\Models\User;
use App\Repositories\Contracts\PhotoRepositoryInterface;
use App\Repositories\Contracts\PurchaseRepositoryInterface;
use App\Repositories\Contracts\UserRepositoryInterface;
use App\Services\LedgerService;
use App\Services\MidtransService;
use App\Notifications\SystemNotification;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * PaymentController — Checkout, Top-Up & Midtrans Webhook
 *
 * SRP : Handles payment flows only.
 * DIP : Injects services & repositories; no raw Eloquent in business logic.
 */
class PaymentController extends Controller
{
    public function __construct(
        private readonly LedgerService              $ledgerService,
        private readonly MidtransService            $midtransService,
        private readonly PhotoRepositoryInterface   $photoRepository,
        private readonly PurchaseRepositoryInterface $purchaseRepository,
        private readonly UserRepositoryInterface    $userRepository,
    ) {}

    /**
     * Show top-up balance page.
     */
    public function showTopUp(Request $request)
    {
        if (!Auth::check()) {
            return redirect()->route('login');
        }

        $user    = Auth::user();
        $balance = $user->balance;
        $ledger  = $user->ledgerEntries()->latest()->take(15)->get();

        // Flash status from Snap callback redirect
        if ($request->query('status') === 'success') {
            session()->flash('success', 'Pembayaran berhasil! Saldo akan dikreditkan setelah konfirmasi dari Midtrans.');
        } elseif ($request->query('status') === 'pending') {
            session()->flash('success', 'Pembayaran sedang diproses. Saldo akan ditambahkan otomatis setelah konfirmasi.');
        }

        return view('payment.topup', compact('user', 'balance', 'ledger'));
    }

    /**
     * Request a Midtrans Snap Token for top-up.
     */
    public function processTopUp(Request $request)
    {
        if (!Auth::check()) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        $request->validate(['amount' => 'required|numeric|min:10000']);

        $user      = Auth::user();
        $amount    = (float) $request->amount;
        $orderId   = 'TOPUP-' . $user->id . '-' . time();
        $snapToken = $this->midtransService->getSnapToken($orderId, $amount, $user);

        return response()->json([
            'success'    => true,
            'snap_token' => $snapToken,
            'order_id'   => $orderId,
            'amount'     => $amount,
        ]);
    }

    // simulatedTopUp() REMOVED — production-only codebase

    /**
     * Checkout — purchase all cart items using the user's ledger balance.
     */
    public function checkout(Request $request)
    {
        if (!Auth::check()) {
            return redirect()->route('login')->with('error', 'Silakan masuk untuk melakukan checkout.');
        }

        $user = Auth::user();
        $cart = session()->get('cart', []);

        if (empty($cart)) {
            return redirect()->route('cart.index')->with('error', 'Keranjang belanja Anda kosong.');
        }

        $photos    = Photo::whereIn('id', $cart)->get();
        $subtotal  = $photos->sum('price');
        $adminFee  = 1000.00;
        $totalCost = $subtotal + $adminFee;

        try {
            $balance = $user->balance;
            if ($balance < $totalCost) {
                return redirect()->route('cart.index')->with(
                    'error',
                    'Saldo ledger Anda tidak mencukupi (Saldo: Rp ' . number_format($balance, 0, ',', '.') .
                    ', Total: Rp ' . number_format($totalCost, 0, ',', '.') . '). Silakan top-up terlebih dahulu.'
                );
            }
        } catch (\Exception $e) {
            return redirect()->route('cart.index')->with('error', 'Kesalahan integritas saldo: ' . $e->getMessage());
        }

        DB::beginTransaction();
        try {
            foreach ($photos as $photo) {
                if ($photo->user_id === $user->id) {
                    throw new \Exception("Anda tidak dapat membeli foto Anda sendiri ({$photo->title}).");
                }

                if ($user->hasPurchased($photo->id)) {
                    continue; // Already owned, skip silently
                }

                $purchaseId = 'BUY-' . $user->id . '-' . $photo->id . '-' . time();

                $this->purchaseRepository->create([
                    'user_id'                 => $user->id,
                    'photo_id'                => $photo->id,
                    'amount'                  => $photo->price,
                    'payment_status'          => 'completed',
                    'midtrans_transaction_id' => 'LEDGER-' . uniqid(),
                ]);

                // Debit buyer for the photo
                $this->ledgerService->addTransaction($user, -$photo->price, 'purchase', $purchaseId);

                // Credit photographer
                $seller = $this->userRepository->findById($photo->user_id);
                $this->ledgerService->addTransaction($seller, $photo->price, 'earning', $purchaseId);

                // Trigger notification to photographer
                $seller->notify(new SystemNotification(
                    'Foto Terjual',
                    'Selamat! Foto Anda "' . $photo->title . '" telah dibeli oleh ' . $user->name . ' seharga Rp ' . number_format($photo->price, 0, ',', '.'),
                    route('photographer.dashboard'),
                    'purchase'
                ));
            }

            // Debit buyer for Admin Fee
            $this->ledgerService->addTransaction($user, -$adminFee, 'purchase', 'ADMINFEE-' . time());

            session()->forget('cart');
            DB::commit();

            return redirect()->route('profile')
                ->with('success', 'Pembelian berhasil! Foto-foto premium kini dapat diunduh tanpa watermark.');

        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Checkout failed: ' . $e->getMessage());
            return redirect()->route('cart.index')->with('error', 'Gagal memproses pembelian: ' . $e->getMessage());
        }
    }

    /**
     * Handle Midtrans payment webhook notification.
     */
    public function midtransWebhook(Request $request)
    {
        $payload = $request->all();
        Log::info('Midtrans Webhook received: ', $payload);

        $notification = $this->midtransService->verifyNotification($payload);

        if (!$notification) {
            return response()->json(['error' => 'Invalid signature or webhook payload'], 400);
        }

        ['order_id' => $orderId, 'status' => $status, 'amount' => $amount] = $notification;

        if ($status === 'success' && str_starts_with($orderId, 'TOPUP-')) {
            $userId = explode('-', $orderId)[1] ?? null;
            $user   = $userId ? $this->userRepository->findById((int) $userId) : null;

            if ($user) {
                $alreadyProcessed = DB::table('ledgers')
                    ->where('user_id', $user->id)
                    ->where('reference_id', $orderId)
                    ->exists();

                if (!$alreadyProcessed) {
                    try {
                        $this->ledgerService->addTransaction($user, $amount, 'deposit', $orderId);
                        Log::info("Midtrans deposit processed for User #{$user->id}, Rp {$amount}");

                        // Trigger notification to user
                        $user->notify(new SystemNotification(
                            'Deposit Berhasil',
                            'Deposit saldo Anda sebesar Rp ' . number_format($amount, 0, ',', '.') . ' telah berhasil dikreditkan.',
                            route('payment.topup'),
                            'deposit'
                        ));
                    } catch (\Exception $e) {
                        Log::error('Ledger error on Midtrans webhook: ' . $e->getMessage());
                        return response()->json(['error' => 'Ledger system integrity error'], 500);
                    }
                }
            }
        }

        return response()->json(['success' => true]);
    }
}
