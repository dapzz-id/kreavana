<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;

class JtiService
{
    /**
     * Store JTI in Redis with a TTL.
     *
     * @param string $jti
     * @param int $ttlSeconds
     * @return void
     */
    public static function store(string $jti, int $ttlSeconds): void
    {
        Cache::put(self::activeKey($jti), true, $ttlSeconds);
        Cache::forget(self::revokedKey($jti));
    }

    /**
     * Check if a JTI exists in cache.
     *
     * @param string $jti
     * @return bool
     */
    public static function exists(string $jti): bool
    {
        if (Cache::has(self::revokedKey($jti))) {
            return false;
        }

        return Cache::has(self::activeKey($jti));
    }

    /**
     * Revoke (delete) a JTI from cache.
     *
     * @param string $jti
     * @return void
     */
    public static function revoke(string $jti, ?int $ttlSeconds = null): void
    {
        Cache::forget(self::activeKey($jti));
        Cache::put(self::revokedKey($jti), true, $ttlSeconds ?? ((int) config('auth_tokens.access_ttl_minutes', 5) * 60));
    }

    private static function activeKey(string $jti): string
    {
        return config('auth_tokens.redis_prefixes.jti_active').$jti;
    }

    private static function revokedKey(string $jti): string
    {
        return config('auth_tokens.redis_prefixes.jti_revoked').$jti;
    }
}
