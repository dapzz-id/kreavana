<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\User;

$user = User::where('email', 'corporate@kreavana.id')->first();
if (!$user) {
    die("User not found\n");
}

$token = Tymon\JWTAuth\Facades\JWTAuth::fromUser($user);

echo "Token: " . $token . "\n";

$ch = curl_init('http://127.0.0.1:8000/api/client-dashboard/overview?role_type=user');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Authorization: Bearer ' . $token,
    'Accept: application/json',
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "HTTP Code: " . $httpCode . "\n";
echo "Response: " . substr($response, 0, 500) . "...\n";
