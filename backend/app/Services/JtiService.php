<?php

namespace App\Services;

use Illuminate\Support\Facades\Redis;

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
        Redis::setex(self::activeKey($jti), $ttlSeconds, "1");
        Redis::del(self::revokedKey($jti));
    }

    /**
     * Check if a JTI exists in Redis.
     *
     * @param string $jti
     * @return bool
     */
    public static function exists(string $jti): bool
    {
        if ((bool) Redis::exists(self::revokedKey($jti))) {
            return false;
        }

        return (bool) Redis::exists(self::activeKey($jti));
    }

    /**
     * Revoke (delete) a JTI from Redis.
     *
     * @param string $jti
     * @return void
     */
    public static function revoke(string $jti, ?int $ttlSeconds = null): void
    {
        Redis::del(self::activeKey($jti));
        Redis::setex(self::revokedKey($jti), $ttlSeconds ?? ((int) config('auth_tokens.access_ttl_minutes', 5) * 60), "1");
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
