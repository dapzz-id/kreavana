<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use App\Services\WalletService;
use App\Http\Requests\TopupRequest;
use App\Http\Requests\SimulatePayRequest;
use App\Http\Requests\TransferRequest;
use App\Http\Requests\WithdrawRequest;
use App\Traits\ApiResponse;
use Exception;

class WalletController extends Controller
{
    use ApiResponse;

    protected WalletService $walletService;

    public function __construct(WalletService $walletService)
    {
        $this->walletService = $walletService;
    }

    public function info()
    {
        $user = Auth::guard('api')->user();
        $info = $this->walletService->getInfo($user->id);

        // Expose whether wallet PIN is configured (so frontend can gate transactions)
        $info['has_pin'] = !empty($user->wallet_pin);

        return $this->successResponse('Data dompet berhasil diambil', $info);
    }

    /**
     * GET /wallet/has-pin
     * Returns whether the authenticated user has configured a wallet PIN.
     * Use this to decide if the wallet is "activated" (like ShopeePay).
     */
    public function hasPin()
    {
        $user = Auth::guard('api')->user();
        $hasPin = !empty($user->wallet_pin);

        return $this->successResponse('Status PIN dompet.', [
            'has_pin' => $hasPin,
        ]);
    }

    /**
     * POST /wallet/set-pin
     * Sets the wallet PIN if it hasn't been set yet.
     */
    public function setPin(Request $request)
    {
        $request->validate(['pin' => 'required|string|min:4|max:8']);

        $user = Auth::guard('api')->user();

        if (!empty($user->wallet_pin)) {
            return $this->errorResponse('PIN wallet sudah diatur sebelumnya.', 422);
        }

        $user->wallet_pin = Hash::make($request->pin);
        $user->save();

        return $this->successResponse('PIN wallet berhasil diatur dan wallet diaktifkan.');
    }

    /**
     * POST /wallet/verify-pin
     * Validates the user's wallet PIN without executing any transaction.
     * Returns {valid: true/false}.
     */
    public function verifyPin(Request $request)
    {
        $request->validate(['pin' => 'required|string|min:4|max:8']);

        $user = Auth::guard('api')->user();

        if (empty($user->wallet_pin)) {
            return $this->errorResponse('Wallet PIN belum diatur. Aktifkan wallet terlebih dahulu.', 422);
        }

        $valid = Hash::check($request->pin, $user->wallet_pin);

        if (!$valid) {
            return $this->errorResponse('PIN salah.', 401);
        }

        return $this->successResponse('PIN valid.', ['valid' => true]);
    }

    public function topup(TopupRequest $request)
    {
        $user = Auth::guard('api')->user();
        $result = $this->walletService->createTopup($user->id, $request->validated());

        return $this->successResponse('Transaksi top up pending berhasil dibuat.', $result, 201);
    }

    public function simulatePay(SimulatePayRequest $request)
    {
        $user = Auth::guard('api')->user();

        try {
            $result = $this->walletService->simulatePay($user->id, $request->reference_number);
            return $this->successResponse('Simulasi pembayaran sukses berhasil diproses.', $result);
        } catch (Exception $e) {
            return $this->errorResponse($e->getMessage(), $e->getCode() ?: 500);
        }
    }

    public function transfer(TransferRequest $request)
    {
        $sender = Auth::guard('api')->user();

        try {
            $result = $this->walletService->transfer($sender->id, $request->validated());
            return $this->successResponse('Transfer berhasil dikirim.', $result);
        } catch (Exception $e) {
            return $this->errorResponse($e->getMessage(), $e->getCode() ?: 500);
        }
    }

    public function withdraw(WithdrawRequest $request)
    {
        $user = Auth::guard('api')->user();

        try {
            $result = $this->walletService->withdraw($user->id, $request->validated());
            return $this->successResponse('Penarikan saldo berhasil diproses.', $result);
        } catch (Exception $e) {
            return $this->errorResponse($e->getMessage(), $e->getCode() ?: 500);
        }
    }
}
