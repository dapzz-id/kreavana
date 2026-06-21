<?php
/**
 * Login User - Kreavana API
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

require_once '../config/database.php';

// Get request body
$input = json_decode(file_get_contents('php://input'), true);

$usernameOrEmail = $input['email'] ?? $input['username'] ?? null;
$password = $input['password'] ?? null;

if (!$usernameOrEmail || !$password) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Username/Email dan password wajib diisi.'
    ]);
    exit();
}

try {
    // Find user by email or username
    $stmt = $conn->prepare("SELECT * FROM users WHERE email = ? OR username = ?");
    $stmt->execute([$usernameOrEmail, $usernameOrEmail]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, $user['password'])) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'message' => 'Username/Email atau password salah.'
        ]);
        exit();
    }

    // Generate a simple token (base64 of user_id:timestamp)
    $token = base64_encode($user['id'] . ':' . time());

    // Remove password hash from response
    unset($user['password']);

    // Cast types correctly for Flutter
    $user['id'] = (int)$user['id'];
    $user['is_creator_approved'] = (int)$user['is_creator_approved'];

    echo json_encode([
        'success' => true,
        'message' => 'Login berhasil.',
        'data' => [
            'token' => $token,
            'user' => $user
        ]
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Gagal melakukan login: ' . $e->getMessage()
    ]);
}
