<?php

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use App\Models\User;
use App\Enums\RoleType;

$emails = [
    'admin@kreavana.id',
    'budi@test.com',
    'photographer@kreavana.id'
];

foreach ($emails as $email) {
    $user = User::where('email', $email)->first();
    if ($user) {
        $isEnum = $user->role instanceof RoleType ? 'true' : 'false';
        $roleName = $user->role instanceof RoleType ? $user->role->name : $user->role;
        echo "{$email} -> {$roleName} (Enum? {$isEnum})\n";
    } else {
        echo "{$email} -> Not Found\n";
    }
}
