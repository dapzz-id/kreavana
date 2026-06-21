<?php
/**
 * Get User Notifications - Kreavana API
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
    $stmt = $conn->prepare("SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC");
    $stmt->execute([$userId]);
    $notifications = $stmt->fetchAll();

    // Format types for Flutter compatibility
    foreach ($notifications as &$notif) {
        $notif['id'] = (int)$notif['id'];
        $notif['user_id'] = (int)$notif['user_id'];
        $notif['is_read'] = (int)$notif['is_read'];
    }

    echo json_encode([
        'success' => true,
        'data' => $notifications
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Gagal mengambil notifikasi: ' . $e->getMessage()
    ]);
}
