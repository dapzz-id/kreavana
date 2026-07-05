<?php

return [
    'access_ttl_minutes' => (int) env('JWT_TTL', 5),

    'jwt' => [
        'production_algo' => 'RS256',
        'development_algo' => env('JWT_ALGO', 'HS256'),
        'issuer' => env('JWT_ISSUER', env('APP_URL')),
        'audience' => env('JWT_AUDIENCE', env('APP_URL')),
    ],

    'refresh' => [
        'cookie' => env('AUTH_REFRESH_COOKIE', 'refresh_token'),
        'ttl_minutes' => (int) env('AUTH_REFRESH_TTL', 60 * 24 * 7),
        'path' => '/api/auth/refresh',
        'same_site' => 'Strict',
    ],

    'redis_prefixes' => [
        'refresh' => env('AUTH_REFRESH_REDIS_PREFIX', 'auth:refresh:'),
        'refresh_family' => env('AUTH_REFRESH_FAMILY_REDIS_PREFIX', 'auth:refresh-family:'),
        'refresh_used' => env('AUTH_REFRESH_USED_REDIS_PREFIX', 'auth:refresh-used:'),
        'refresh_lock' => env('AUTH_REFRESH_LOCK_REDIS_PREFIX', 'auth:refresh-lock:'),
        'jti_active' => env('AUTH_JTI_ACTIVE_REDIS_PREFIX', 'auth:jti:active:'),
        'jti_revoked' => env('AUTH_JTI_REVOKED_REDIS_PREFIX', 'auth:jti:revoked:'),
        'rate_limit' => env('AUTH_RATE_LIMIT_REDIS_PREFIX', 'auth:rate-limit:'),
    ],
];
