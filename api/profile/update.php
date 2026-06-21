<?php
/**
 * Update User Profile - Kreavana API
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

require_once '../config/database.php';

$input = json_decode(file_get_contents('php://input'), true);

$userId = $input['user_id'] ?? null;
$name = $input['name'] ?? null;
$phone = $input['phone'] ?? null;
$avatarUrl = $input['avatar_url'] ?? null;
$selectedPihak = $input['selected_pihak'] ?? null;

if (!$userId) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'User ID wajib diisi.'
    ]);
    exit();
}

try {
    // Check if user exists
    $stmt = $conn->prepare("SELECT role FROM users WHERE id = ?");
    $stmt->execute([$userId]);
    $userCheck = $stmt->fetch();

    if (!$userCheck) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'User tidak ditemukan.'
        ]);
        exit();
    }

    // Build update query dynamically based on inputs
    $fields = [];
    $params = [];

    if ($name !== null) {
        $fields[] = "name = ?";
        $params[] = $name;
    }
    if ($phone !== null) {
        $fields[] = "phone = ?";
        $params[] = $phone;
    }
    if ($avatarUrl !== null) {
        $fields[] = "avatar_url = ?";
        $params[] = $avatarUrl;
    }
    if ($selectedPihak !== null) {
        $fields[] = "selected_pihak = ?";
        $params[] = $selectedPihak;

        // When switching selected_pihak, ensure user_pihak entry exists for the current user-role context
        // Check user's role: 'user' or 'creator'
        $currentRole = $userCheck['role'];
        
        // Upsert user_pihak
        $stmtPihak = $conn->prepare("INSERT INTO user_pihak (user_id, pihak_slug, role_type, is_active) 
                                      VALUES (?, ?, ?, 1) 
                                      ON DUPLICATE KEY UPDATE is_active = 1");
        $stmtPihak->execute([$userId, $selectedPihak, $currentRole]);
    }

    if (!empty($fields)) {
        $sql = "UPDATE users SET " . implode(", ", $fields) . " WHERE id = ?";
        $params[] = $userId;
        $stmt = $conn->prepare($sql);
        $stmt->execute($params);
    }

    // Fetch updated user
    $stmt = $conn->prepare("SELECT id, name, username, email, avatar_url, phone, role, selected_pihak, is_creator_approved FROM users WHERE id = ?");
    $stmt->execute([$userId]);
    $user = $stmt->fetch();

    $user['id'] = (int)$user['id'];
    $user['is_creator_approved'] = (int)$user['is_creator_approved'];

    echo json_encode([
        'success' => true,
        'message' => 'Profil berhasil diperbarui.',
        'data' => $user
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Gagal memperbarui profil: ' . $e->getMessage()
    ]);
}
