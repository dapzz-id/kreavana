<?php

namespace App\Services;

use App\Models\User;
use App\Models\Ledger;
use App\Repositories\Contracts\LedgerRepositoryInterface;
use Illuminate\Support\Facades\Log;

/**
 * LedgerService — Tamper-Evident Financial Ledger
 *
 * Each transaction is AES-256-CBC encrypted and chained via HMAC-SHA256
 * hashes (blockchain-style). Tampering any DB row breaks the chain and
 * throws an exception before any balance is returned.
 *
 * SRP: This service is solely responsible for financial integrity.
 * DI : It depends on LedgerRepositoryInterface, not on concrete Eloquent.
 */
class LedgerService
{
    public function __construct(
        private readonly LedgerRepositoryInterface $ledgerRepository
    ) {}

    // ── Private Cryptography Helpers ─────────────────────────────────────────

    private function getEncryptionKey(): string
    {
        $key = env('LEDGER_ENCRYPTION_KEY');
        if (empty($key)) {
            $key = hash('sha256', env('APP_KEY', 'kreavana_secret_fallback') . '_ledger_enc');
        }
        return $key;
    }

    private function getSigningKey(): string
    {
        $key = env('LEDGER_SIGNING_KEY');
        if (empty($key)) {
            $key = hash('sha256', env('APP_KEY', 'kreavana_secret_fallback') . '_ledger_sign');
        }
        return $key;
    }

    private function encryptAmount(float $amount): string
    {
        $key      = substr(hash('sha256', $this->getEncryptionKey()), 0, 32);
        $ivLength = openssl_cipher_iv_length('aes-256-cbc');
        $iv       = openssl_random_pseudo_bytes($ivLength);
        $encrypted = openssl_encrypt((string) $amount, 'aes-256-cbc', $key, 0, $iv);
        return base64_encode($encrypted . '::' . base64_encode($iv));
    }

    private function decryptAmount(string $encryptedString): float
    {
        try {
            $key     = substr(hash('sha256', $this->getEncryptionKey()), 0, 32);
            $decoded = base64_decode($encryptedString);
            if (!$decoded || !str_contains($decoded, '::')) {
                return 0.00;
            }
            [$encryptedData, $ivBase64] = explode('::', $decoded, 2);
            $iv        = base64_decode($ivBase64);
            $decrypted = openssl_decrypt($encryptedData, 'aes-256-cbc', $key, 0, $iv);
            return $decrypted === false ? 0.00 : (float) $decrypted;
        } catch (\Exception $e) {
            Log::error('Ledger decryption failed: ' . $e->getMessage());
            return 0.00;
        }
    }

    private function generateSignature(int $userId, float $amount, string $type, ?string $referenceId, ?string $previousHash): string
    {
        $payload = implode('|', [
            $userId,
            sprintf('%.2f', $amount),
            $type,
            $referenceId ?? 'NULL',
            $previousHash ?? 'START',
        ]);
        return hash_hmac('sha256', $payload, $this->getSigningKey());
    }

    // ── Public API ───────────────────────────────────────────────────────────

    /**
     * Publicly expose decryption for display purposes only (e.g., Ledger model accessor).
     * Do NOT use for balance arithmetic — use getBalance() instead.
     */
    public function decryptForDisplay(string $encrypted): float
    {
        return $this->decryptAmount($encrypted);
    }

    /**
     * Append a new transaction to the user's ledger.
     */
    public function addTransaction(User $user, float $amount, string $type, ?string $referenceId = null): Ledger
    {
        $this->verifyLedgerIntegrity($user);

        $lastEntry    = $this->ledgerRepository->getLastEntryForUser($user->id);
        $previousHash = $lastEntry?->hash_signature;

        return $this->ledgerRepository->create([
            'user_id'          => $user->id,
            'amount_encrypted' => $this->encryptAmount($amount),
            'hash_signature'   => $this->generateSignature($user->id, $amount, $type, $referenceId, $previousHash),
            'previous_hash'    => $previousHash,
            'transaction_type' => $type,
            'reference_id'     => $referenceId,
        ]);
    }

    /**
     * Compute and verify the user's current balance from the ledger chain.
     */
    public function getBalance(User $user): float
    {
        $entries      = $this->ledgerRepository->getAllForUser($user->id);
        $balance      = 0.00;
        $previousHash = null;

        foreach ($entries->sortBy('id') as $entry) {
            $amount            = $this->decryptAmount($entry->amount_encrypted);
            $expectedSignature = $this->generateSignature(
                $user->id,
                $amount,
                $entry->transaction_type,
                $entry->reference_id,
                $previousHash
            );

            if ($entry->hash_signature !== $expectedSignature) {
                Log::critical("SECURITY: Ledger entry #{$entry->id} for User #{$user->id} tampered!");
                throw new \Exception('Integritas saldo terganggu. Hubungi Customer Support.');
            }

            if ($entry->previous_hash !== $previousHash) {
                Log::critical("SECURITY: Ledger chain broken at Entry #{$entry->id} for User #{$user->id}!");
                throw new \Exception('Rantai riwayat transaksi terputus. Hubungi Customer Support.');
            }

            $balance     += $amount;
            $previousHash = $entry->hash_signature;
        }

        return $balance;
    }

    /**
     * Verify ledger integrity; returns true or throws on tampering.
     */
    public function verifyLedgerIntegrity(User $user): bool
    {
        try {
            $this->getBalance($user);
            return true;
        } catch (\Exception $e) {
            Log::critical("Integritas ledger User #{$user->id} ({$user->email}) GAGAL: " . $e->getMessage());
            throw $e;
        }
    }

    /**
     * Audit all users' ledgers and return a status report.
     */
    public function auditAllUsers(): array
    {
        $users  = \App\Models\User::all();
        $report = [];

        foreach ($users as $user) {
            try {
                $balance  = $this->getBalance($user);
                $report[] = [
                    'user_id' => $user->id,
                    'name'    => $user->name,
                    'email'   => $user->email,
                    'status'  => 'SECURE',
                    'balance' => $balance,
                    'error'   => null,
                ];
            } catch (\Exception $e) {
                $report[] = [
                    'user_id' => $user->id,
                    'name'    => $user->name,
                    'email'   => $user->email,
                    'status'  => 'TAMPERED',
                    'balance' => 0.00,
                    'error'   => $e->getMessage(),
                ];
            }
        }

        return $report;
    }
}
