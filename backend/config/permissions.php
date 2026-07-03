<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Role-Based Permissions
    |--------------------------------------------------------------------------
    |
    | Mapping dari setiap role ke daftar permissions yang dimilikinya.
    | Digunakan oleh RoleMiddleware dan PermissionMiddleware untuk
    | validasi akses, serta disertakan dalam JWT custom claims.
    |
    */

    'user' => [
        'view_dashboard',
        'view_opportunities',
        'manage_own_profile',
        'use_chat',
        'submit_report',
    ],

    'creator' => [
        'view_dashboard',
        'view_opportunities',
        'create_opportunity',
        'manage_own_profile',
        'use_chat',
        'submit_report',
    ],

    'admin' => [
        'view_dashboard',
        'manage_applications',
        'manage_users',
        'view_opportunities',
        'create_opportunity',
        'manage_own_profile',
        'use_chat',
        'manage_reports',
    ],

];
