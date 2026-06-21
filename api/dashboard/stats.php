<?php
/**
 * Dashboard Stats - Kreavana API
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

require_once '../config/database.php';

$pihak = $_GET['pihak'] ?? 'kreator';
$role = $_GET['role_type'] ?? 'user';

try {
    $stmt = $conn->prepare("SELECT stat_label as label, stat_value as value, stat_icon as icon FROM dashboard_stats WHERE pihak_slug = ? AND role_type = ? ORDER BY display_order ASC");
    $stmt->execute([$pihak, $role]);
    $stats = $stmt->fetchAll();

    // If no stats found, return default dummy stats for safety
    if (empty($stats)) {
        $stats = [
            ['label' => 'Peluang Tersedia', 'value' => '10+', 'icon' => 'explore'],
            ['label' => 'Mitra Aktif', 'value' => '50+', 'icon' => 'people'],
            ['label' => 'Proyek Selesai', 'value' => '20+', 'icon' => 'done_all'],
            ['label' => 'Rating Kepuasan', 'value' => '4.8', 'icon' => 'star']
        ];
    }

    echo json_encode([
        'success' => true,
        'data' => $stats
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Gagal mengambil dashboard stats: ' . $e->getMessage()
    ]);
}
