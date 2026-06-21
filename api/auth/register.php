<?php
/**
 * Register User Baru - Kreavana API
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

require_once '../config/database.php';

// Get request body
$input = json_decode(file_get_contents('php://input'), true);

$name = $input['name'] ?? null;
$username = $input['username'] ?? null;
$email = $input['email'] ?? null;
$password = $input['password'] ?? null;

if (!$name || !$username || !$email || !$password) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Nama, username, email, dan password wajib diisi.'
    ]);
    exit();
}

try {
    // Check if username already exists
    $stmt = $conn->prepare("SELECT id FROM users WHERE username = ?");
    $stmt->execute([$username]);
    if ($stmt->fetch()) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Username sudah terdaftar.'
        ]);
        exit();
    }

    // Check if email already exists
    $stmt = $conn->prepare("SELECT id FROM users WHERE email = ?");
    $stmt->execute([$email]);
    if ($stmt->fetch()) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Email sudah terdaftar.'
        ]);
        exit();
    }

    // Hash password
    $hashedPassword = password_hash($password, PASSWORD_DEFAULT);

    // Insert user (default role is 'user', selected_pihak is 'kreator')
    $stmt = $conn->prepare("INSERT INTO users (name, username, email, password, role, selected_pihak) VALUES (?, ?, ?, ?, 'user', 'kreator')");
    $stmt->execute([$name, $username, $email, $hashedPassword]);
    $userId = $conn->lastInsertId();

    // Create user_pihak entry for default role
    $stmt = $conn->prepare("INSERT INTO user_pihak (user_id, pihak_slug, role_type) VALUES (?, 'kreator', 'user')");
    $stmt->execute([$userId]);

    // Send welcome notification
    $stmt = $conn->prepare("INSERT INTO notifications (user_id, title, message, type) VALUES (?, 'Selamat Datang!', 'Selamat bergabung di Kreavana! Temukan peluang kolaborasi terbaik disini.', 'welcome')");
    $stmt->execute([$userId]);

    // Fetch user back
    $stmt = $conn->prepare("SELECT id, name, username, email, avatar_url, phone, role, selected_pihak, is_creator_approved FROM users WHERE id = ?");
    $stmt->execute([$userId]);
    $user = $stmt->fetch();

    echo json_encode([
        'success' => true,
        'message' => 'Registrasi berhasil.',
        'data' => $user
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Gagal melakukan registrasi: ' . $e->getMessage()
    ]);
}
