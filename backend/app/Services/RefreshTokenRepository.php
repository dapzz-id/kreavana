<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Str;

class RefreshTokenRepository
{
    public function issue(User $user, ?string $familyId = null): string
    {
        $selector = $this->randomHex(16);
        $secret = $this->randomToken();
        $familyId ??= (string) Str::uuid();
        $ttl = $this->ttlSeconds();

        $entry = [
            'user_id' => (string) $user->getKey(),
            'family_id' => $familyId,
            'hash' => $this->hash($secret),
            'issued_at' => now()->toISOString(),
            'expires_at' => now()->addSeconds($ttl)->toISOString(),
        ];

        Redis::setex($this->refreshKey($selector), $ttl, json_encode($entry, JSON_THROW_ON_ERROR));
        Redis::sadd($this->familyKey($familyId), $selector);
        Redis::expire($this->familyKey($familyId), $ttl);

        return "{$selector}.{$secret}";
    }

    public function rotate(string $rawToken): ?array
    {
        [$selector, $secret] = $this->parse($rawToken);
        if (!$selector || !$secret) {
            return null;
        }

        $lock = Cache::lock($this->lockKey($selector), 5);

        try {
            return $lock->block(2, function () use ($selector, $secret) {
            $encoded = Redis::get($this->refreshKey($selector));

            if (!$encoded) {
                $this->revokeUsedFamily($selector);
                return null;
            }

            $entry = json_decode((string) $encoded, true);
            if (!is_array($entry) || !hash_equals((string) ($entry['hash'] ?? ''), $this->hash($secret))) {
                if (is_array($entry) && isset($entry['family_id'])) {
                    $this->revokeFamily((string) $entry['family_id']);
                }
                return null;
            }

            Redis::del($this->refreshKey($selector));
            Redis::setex($this->usedKey($selector), $this->ttlSeconds(), json_encode([
                'family_id' => $entry['family_id'],
                'user_id' => $entry['user_id'],
            ], JSON_THROW_ON_ERROR));

            return [
                'user_id' => $entry['user_id'],
                'family_id' => $entry['family_id'],
            ];
            });
        } catch (\Throwable) {
            return null;
        }
    }

    public function revokeRaw(?string $rawToken): void
    {
        if (!$rawToken) {
            return;
        }

        [$selector] = $this->parse($rawToken);
        if ($selector) {
            Redis::del($this->refreshKey($selector));
        }
    }

    public function revokeFamily(string $familyId): void
    {
        $selectors = Redis::smembers($this->familyKey($familyId));
        foreach ($selectors ?: [] as $selector) {
            Redis::del($this->refreshKey((string) $selector));
            Redis::setex($this->usedKey((string) $selector), $this->ttlSeconds(), json_encode([
                'family_id' => $familyId,
            ], JSON_THROW_ON_ERROR));
        }

        Redis::del($this->familyKey($familyId));
    }

    private function revokeUsedFamily(string $selector): void
    {
        $encoded = Redis::get($this->usedKey($selector));
        if (!$encoded) {
            return;
        }

        $entry = json_decode((string) $encoded, true);
        if (is_array($entry) && isset($entry['family_id'])) {
            $this->revokeFamily((string) $entry['family_id']);
        }
    }

    private function parse(string $rawToken): array
    {
        $parts = explode('.', $rawToken, 2);

        return count($parts) === 2 ? $parts : [null, null];
    }

    private function randomHex(int $bytes): string
    {
        return bin2hex(random_bytes($bytes));
    }

    private function randomToken(): string
    {
        return rtrim(strtr(base64_encode(random_bytes(48)), '+/', '-_'), '=');
    }

    private function hash(string $secret): string
    {
        return hash_hmac('sha256', $secret, (string) config('app.key'));
    }

    private function ttlSeconds(): int
    {
        return max(60, (int) config('auth_tokens.refresh.ttl_minutes') * 60);
    }

    private function refreshKey(string $selector): string
    {
        return config('auth_tokens.redis_prefixes.refresh').$selector;
    }

    private function familyKey(string $familyId): string
    {
        return config('auth_tokens.redis_prefixes.refresh_family').$familyId;
    }

    private function usedKey(string $selector): string
    {
        return config('auth_tokens.redis_prefixes.refresh_used').$selector;
    }

    private function lockKey(string $selector): string
    {
        return config('auth_tokens.redis_prefixes.refresh_lock').$selector;
    }
}
