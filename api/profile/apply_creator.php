<?php
/**
 * Apply to become a Creator - Kreavana API
 * Auto-approves for demo purposes.
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Origin: *');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

require_once '../config/database.php';

$input = json_decode(file_get_contents('php://input'), true);

$userId = $input['user_id'] ?? null;
$pihakCategory = $input['pihak_category'] ?? null;
$skillDescription = $input['skill_description'] ?? null;
$portfolioLink = $input['portfolio_link'] ?? null;
$experience = $input['experience'] ?? null;

if (!$userId || !$pihakCategory || !$skillDescription) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'User ID, kategori pihak, dan deskripsi keahlian wajib diisi.'
    ]);
    exit();
}

try {
    $conn->beginTransaction();

    // 1. Insert application (status: approved for demo)
    $stmt = $conn->prepare("INSERT INTO creator_applications 
        (user_id, pihak_category, skill_description, portfolio_link, experience, status, admin_note, reviewed_at) 
        VALUES (?, ?, ?, ?, ?, 'approved', 'Disetujui otomatis untuk demo sistem.', CURRENT_TIMESTAMP)");
    $stmt->execute([$userId, $pihakCategory, $skillDescription, $portfolioLink, $experience]);

    // Fetch pihak category name for notification
    $stmtPihak = $conn->prepare("SELECT name FROM pihak_categories WHERE slug = ?");
    $stmtPihak->execute([$pihakCategory]);
    $pihakData = $stmtPihak->fetch();
    $pihakName = $pihakData ? $pihakData['name'] : ucfirst($pihakCategory);

    // 2. Update user profile to role = 'creator' and is_creator_approved = 1 and selected_pihak = applied pihak category
    $stmtUser = $conn->prepare("UPDATE users SET role = 'creator', is_creator_approved = 1, selected_pihak = ? WHERE id = ?");
    $stmtUser->execute([$pihakCategory, $userId]);

    // 3. Upsert user_pihak to active 'creator' role for this category
    $stmtUserPihak = $conn->prepare("INSERT INTO user_pihak (user_id, pihak_slug, role_type, is_active) 
        VALUES (?, ?, 'creator', 1) 
        ON DUPLICATE KEY UPDATE is_active = 1");
    $stmtUserPihak->execute([$userId, $pihakCategory]);

    // 4. Also add the user role 'user' for this category if it doesn't exist
    $stmtUserPihak2 = $conn->prepare("INSERT INTO user_pihak (user_id, pihak_slug, role_type, is_active) 
        VALUES (?, ?, 'user', 1) 
        ON DUPLICATE KEY UPDATE is_active = 1");
    $stmtUserPihak2->execute([$userId, $pihakCategory]);

    // 5. Send notification
    $stmtNotif = $conn->prepare("INSERT INTO notifications (user_id, title, message, type) 
        VALUES (?, 'Pengajuan Kreator Disetujui!', ?, 'creator_approved')");
    $notifMsg = "Selamat! Pengajuan Anda sebagai Kreator di kategori $pihakName telah disetujui. Dashboard Kreator Anda kini aktif.";
    $stmtNotif->execute([$userId, $notifMsg]);

    $conn->commit();

    // Fetch updated user details
    $stmtSelect = $conn->prepare("SELECT id, name, username, email, avatar_url, phone, role, selected_pihak, is_creator_approved FROM users WHERE id = ?");
    $stmtSelect->execute([$userId]);
    $user = $stmtSelect->fetch();

    $user['id'] = (int)$user['id'];
    $user['is_creator_approved'] = (int)$user['is_creator_approved'];

    echo json_encode([
        'success' => true,
        'message' => 'Pengajuan Kreator berhasil disetujui.',
        'data' => $user
    ]);

} catch (PDOException $e) {
    if ($conn->inTransaction()) {
        $conn->rollBack();
    }
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Gagal memproses pengajuan kreator: ' . $e->getMessage()
    ]);
}
