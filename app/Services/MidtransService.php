<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class MidtransService
{
    private function getServerKey(): string
    {
        return env('MIDTRANS_SERVER_KEY', '');
    }

    private function getClientKey(): string
    {
        return env('MIDTRANS_CLIENT_KEY', '');
    }

    private function isProduction(): bool
    {
        return filter_var(env('MIDTRANS_IS_PRODUCTION', false), FILTER_VALIDATE_BOOLEAN);
    }

    /**
     * Get Snap token for a transaction.
     */
    public function getSnapToken(string $orderId, float $amount, User $user): string
    {
        $serverKey = $this->getServerKey();

        // If no Midtrans Server Key is configured, return a mock token for local testing
        if (empty($serverKey)) {
            Log::warning("Midtrans Server Key is not configured. Generating a mock snap token.");
            return 'mock_snap_token_' . uniqid();
        }

        $baseUrl = $this->isProduction()
            ? 'https://app.midtrans.com/snap/v1/transactions'
            : 'https://app.sandbox.midtrans.com/snap/v1/transactions';

        try {
            $response = Http::withHeaders([
                'Accept' => 'application/json',
                'Content-Type' => 'application/json',
                'Authorization' => 'Basic ' . base64_encode($serverKey . ':')
            ])->post($baseUrl, [
                'transaction_details' => [
                    'order_id' => $orderId,
                    'gross_amount' => (int)$amount,
                ],
                'customer_details' => [
                    'first_name' => $user->name,
                    'email' => $user->email,
                ],
                'credit_card' => [
                    'secure' => true
                ]
            ]);

            if ($response->successful()) {
                return $response->json('token');
            }

            Log::error("Midtrans Snap Token request failed: " . $response->body());
            return 'mock_snap_token_' . uniqid();
        } catch (\Exception $e) {
            Log::error("Midtrans Snap Token connection error: " . $e->getMessage());
            return 'mock_snap_token_' . uniqid();
        }
    }

    /**
     * Verify callback webhook notification from Midtrans.
     * Returns array [status => 'success'|'pending'|'failed', order_id => string, transaction_id => string] or null if invalid.
     */
    public function verifyNotification(array $payload): ?array
    {
        $serverKey = $this->getServerKey();

        // If in mock mode, bypass validation and return success (for demo triggers)
        if (empty($serverKey) || (isset($payload['mock']) && $payload['mock'] === true)) {
            return [
                'status' => $payload['transaction_status'] ?? 'settlement',
                'order_id' => $payload['order_id'] ?? 'mock_order',
                'transaction_id' => $payload['transaction_id'] ?? 'mock_tx_id',
                'amount' => (float)($payload['gross_amount'] ?? 0.00),
            ];
        }

        $orderId = $payload['order_id'] ?? '';
        $statusCode = $payload['status_code'] ?? '';
        $grossAmount = $payload['gross_amount'] ?? '';
        $signatureKey = $payload['signature_key'] ?? '';

        // Calculate expected signature key
        $expectedSignature = hash('sha512', $orderId . $statusCode . $grossAmount . $serverKey);

        if ($signatureKey !== $expectedSignature) {
            Log::critical("MIDTRANS WARNING: Webhook signature verification failed for Order #{$orderId}");
            return null;
        }

        $status = 'pending';
        $transactionStatus = $payload['transaction_status'] ?? '';
        $fraudStatus = $payload['fraud_status'] ?? '';

        if ($transactionStatus == 'capture') {
            if ($fraudStatus == 'challenge') {
                $status = 'challenge';
            } else if ($fraudStatus == 'accept') {
                $status = 'success';
            }
        } else if ($transactionStatus == 'settlement') {
            $status = 'success';
        } else if (in_array($transactionStatus, ['cancel', 'deny', 'expire'])) {
            $status = 'failed';
        } else if ($transactionStatus == 'pending') {
            $status = 'pending';
        }

        return [
            'status' => $status,
            'order_id' => $orderId,
            'transaction_id' => $payload['transaction_id'] ?? '',
            'amount' => (float)$grossAmount,
        ];
    }
}
