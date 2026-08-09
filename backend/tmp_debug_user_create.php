<?php
require __DIR__ . '/vendor/autoload.php';
$app = require __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\User;
use Illuminate\Support\Facades\Hash;

try {
    $user = User::create([
        'name' => 'Test User',
        'username' => 'testuser',
        'email' => 'user@test.com',
        'password' => Hash::make('password123'),
        'role' => 'user',
    ]);
    echo 'USER=' . var_export($user?->toArray(), true) . "\n";
    echo 'ID=' . var_export($user?->id, true) . "\n";
} catch (Throwable $e) {
    echo 'EXCEPTION: ' . get_class($e) . ': ' . $e->getMessage() . "\n";
    echo $e->getTraceAsString();
}
