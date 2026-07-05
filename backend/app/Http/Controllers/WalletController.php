<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
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

        return $this->successResponse('Data dompet berhasil diambil', $info);
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
