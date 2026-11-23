<?php

return [
    'paths' => ['api/*', '.well-known/*'],

    'allowed_methods' => ['*'],

    'allowed_origins' => array_values(array_filter(array_map(
        'trim',
        explode(',', (string) env('CORS_ALLOWED_ORIGINS', ''))
    ))),

    'allowed_origins_patterns' => array_merge(
        in_array(env('APP_ENV', 'production'), ['local', 'testing'], true)
            ? [
                '#^https?://localhost(?::\d+)?$#',
                '#^https?://127\.0\.0\.1(?::\d+)?$#',
            ]
            : [],
        array_values(array_filter(array_map(
            'trim',
            explode(',', (string) env('CORS_ALLOWED_ORIGIN_PATTERNS', ''))
        )))
    ),

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => true,
];
