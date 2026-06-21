<?php
/**
 * Dashboard / Explore Opportunities - Kreavana API
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

require_once '../config/database.php';

$pihak = $_GET['pihak'] ?? null;
$limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 10;

try {
    $sql = "SELECT o.*, u.name as poster_name, u.avatar_url as poster_avatar 
            FROM opportunities o 
            LEFT JOIN users u ON o.posted_by = u.id";
    
    $params = [];
    if ($pihak && $pihak !== 'all') {
        $sql .= " WHERE o.pihak_slug = ?";
        $params[] = $pihak;
    }
    
    $sql .= " ORDER BY o.created_at DESC LIMIT " . $limit;
    
    $stmt = $conn->prepare($sql);
    $stmt->execute($params);
    $opportunities = $stmt->fetchAll();

    // Format types for Flutter compatibility
    foreach ($opportunities as &$op) {
        $op['id'] = (int)$op['id'];
        $op['posted_by'] = (int)$op['posted_by'];
    }

    echo json_encode([
        'success' => true,
        'data' => $opportunities
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Gagal mengambil peluang: ' . $e->getMessage()
    ]);
}
