<?php
/**
 * Get User Profile - Kreavana API
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

require_once '../config/database.php';

$userId = $_GET['user_id'] ?? null;

if (!$userId) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'User ID wajib diisi.'
    ]);
    exit();
}

try {
    // 1. Fetch user data
    $stmt = $conn->prepare("SELECT id, name, username, email, avatar_url, phone, role, selected_pihak, is_creator_approved FROM users WHERE id = ?");
    $stmt->execute([$userId]);
    $user = $stmt->fetch();

    if (!$user) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'User tidak ditemukan.'
        ]);
        exit();
    }

    // Convert types for Flutter
    $user['id'] = (int)$user['id'];
    $user['is_creator_approved'] = (int)$user['is_creator_approved'];

    // 2. Fetch latest creator application
    $stmt = $conn->prepare("SELECT * FROM creator_applications WHERE user_id = ? ORDER BY applied_at DESC LIMIT 1");
    $stmt->execute([$userId]);
    $application = $stmt->fetch();

    if ($application) {
        $application['id'] = (int)$application['id'];
        $application['user_id'] = (int)$application['user_id'];
    }

    // 3. Fetch active roles / pihak categories for this user
    $stmt = $conn->prepare("SELECT pihak_slug, role_type FROM user_pihak WHERE user_id = ? AND is_active = 1");
    $stmt->execute([$userId]);
    $roles = $stmt->fetchAll();

    echo json_encode([
        'success' => true,
        'data' => [
            'user' => $user,
            'application' => $application ?: null,
            'user_pihaks' => $roles
        ]
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Gagal mengambil profil: ' . $e->getMessage()
    ]);
}
