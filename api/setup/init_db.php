<?php
/**
 * Setup Database - Kreavana API
 * Membuat semua tabel dan data awal (seed)
 * Jalankan sekali untuk inisialisasi database
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

$host = 'localhost';
$username = 'root';
$password = '';
$charset = 'utf8mb4';

try {
    // 1. Koneksi tanpa database dulu, lalu buat database
    $pdo = new PDO("mysql:host=$host;charset=$charset", $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
    ]);

    $pdo->exec("CREATE DATABASE IF NOT EXISTS `kreavana_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
    $pdo->exec("USE `kreavana_db`");

    // 2. Drop tabel (urutan sesuai foreign key)
    $pdo->exec("SET FOREIGN_KEY_CHECKS = 0");
    $tables = ['dashboard_stats', 'notifications', 'opportunities', 'user_pihak', 'creator_applications', 'pihak_categories', 'users'];
    foreach ($tables as $table) {
        $pdo->exec("DROP TABLE IF EXISTS `$table`");
    }
    $pdo->exec("SET FOREIGN_KEY_CHECKS = 1");

    // 3. Buat tabel users
    $pdo->exec("
        CREATE TABLE users (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            username VARCHAR(50) UNIQUE NOT NULL,
            email VARCHAR(150) UNIQUE NOT NULL,
            password VARCHAR(255) NOT NULL,
            avatar_url VARCHAR(500) DEFAULT NULL,
            phone VARCHAR(20) DEFAULT NULL,
            role ENUM('user','creator') DEFAULT 'user',
            selected_pihak VARCHAR(50) DEFAULT 'kreator',
            is_creator_approved TINYINT(1) DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");

    // Buat tabel pihak_categories
    $pdo->exec("
        CREATE TABLE pihak_categories (
            id INT AUTO_INCREMENT PRIMARY KEY,
            slug VARCHAR(50) UNIQUE NOT NULL,
            name VARCHAR(100) NOT NULL,
            description TEXT,
            icon VARCHAR(50),
            color VARCHAR(10)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");

    // Buat tabel creator_applications
    $pdo->exec("
        CREATE TABLE creator_applications (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            pihak_category VARCHAR(50) NOT NULL,
            skill_description TEXT NOT NULL,
            portfolio_link VARCHAR(500),
            experience TEXT,
            status ENUM('pending','approved','rejected') DEFAULT 'pending',
            admin_note TEXT,
            applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            reviewed_at TIMESTAMP NULL,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");

    // Buat tabel user_pihak
    $pdo->exec("
        CREATE TABLE user_pihak (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            pihak_slug VARCHAR(50) NOT NULL,
            role_type ENUM('user','creator') NOT NULL,
            is_active TINYINT(1) DEFAULT 1,
            joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            UNIQUE KEY unique_user_pihak_role (user_id, pihak_slug, role_type)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");

    // Buat tabel opportunities
    $pdo->exec("
        CREATE TABLE opportunities (
            id INT AUTO_INCREMENT PRIMARY KEY,
            title VARCHAR(200) NOT NULL,
            description TEXT,
            pihak_slug VARCHAR(50) NOT NULL,
            location VARCHAR(150),
            deadline DATE,
            budget_range VARCHAR(100),
            status ENUM('open','in_progress','completed','closed') DEFAULT 'open',
            posted_by INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (posted_by) REFERENCES users(id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");

    // Buat tabel notifications
    $pdo->exec("
        CREATE TABLE notifications (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            title VARCHAR(200) NOT NULL,
            message TEXT NOT NULL,
            type VARCHAR(50) DEFAULT 'info',
            is_read TINYINT(1) DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");

    // Buat tabel dashboard_stats
    $pdo->exec("
        CREATE TABLE dashboard_stats (
            id INT AUTO_INCREMENT PRIMARY KEY,
            pihak_slug VARCHAR(50) NOT NULL,
            role_type ENUM('user','creator') NOT NULL,
            stat_label VARCHAR(100) NOT NULL,
            stat_value VARCHAR(50) NOT NULL,
            stat_icon VARCHAR(50),
            display_order INT DEFAULT 0
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ");

    // =============================================
    // SEED DATA
    // =============================================

    // Seed pihak_categories (8 kategori)
    $pihakData = [
        ['kreator', 'Kreator', 'Fotografer, Videografer, MUA, Desainer, MC, Musisi, dll', 'brush', '#F97316'],
        ['eo', 'Event Organizer', 'Cari vendor terpercaya untuk event', 'event', '#3B82F6'],
        ['wo', 'Wedding Organizer', 'Paket vendor lengkap untuk wedding', 'favorite', '#8B5CF6'],
        ['sekolah', 'Sekolah / Kampus', 'Database alumni & talenta, magang & PKL', 'school', '#10B981'],
        ['umkm', 'Perusahaan / UMKM', 'Konten branding & promosi bisnis', 'business', '#06B6D4'],
        ['pemerintah', 'Pemerintah', 'Publikasi program & kegiatan resmi', 'gavel', '#1E3A8A'],
        ['komunitas', 'Komunitas', 'Event komunitas & kolaborasi', 'groups', '#EC4899'],
        ['organisasi', 'Organisasi / Asosiasi', 'Direktori anggota & event eksklusif', 'corporate_fare', '#3F51B5'],
    ];

    $stmtPihak = $pdo->prepare("INSERT INTO pihak_categories (slug, name, description, icon, color) VALUES (?, ?, ?, ?, ?)");
    foreach ($pihakData as $p) {
        $stmtPihak->execute($p);
    }

    // Seed user demo untuk posted_by di opportunities
    $demoPassword = password_hash('password123', PASSWORD_DEFAULT);
    $pdo->exec("INSERT INTO users (name, username, email, password, role, selected_pihak, is_creator_approved) VALUES 
        ('Admin Kreavana', 'admin', 'admin@kreavana.id', '$demoPassword', 'creator', 'kreator', 1),
        ('Demo User', 'demo', 'demo@kreavana.id', '$demoPassword', 'user', 'kreator', 0)
    ");

    // Seed dashboard_stats - 4 stat per pihak per role (user & creator)
    $statsData = [
        // kreator
        ['kreator', 'user', 'Peluang Tersedia', '24', 'work', 1],
        ['kreator', 'user', 'Kreator Aktif', '150', 'people', 2],
        ['kreator', 'user', 'Rating Rata-rata', '4.7', 'star', 3],
        ['kreator', 'user', 'Proyek Selesai', '89', 'check_circle', 4],
        ['kreator', 'creator', 'Peluang Diterima', '12', 'assignment_turned_in', 1],
        ['kreator', 'creator', 'Proyek Berjalan', '3', 'pending_actions', 2],
        ['kreator', 'creator', 'Selesai', '18', 'task_alt', 3],
        ['kreator', 'creator', 'Rating Kamu', '4.8', 'star', 4],

        // eo
        ['eo', 'user', 'Event Mendatang', '6', 'event', 1],
        ['eo', 'user', 'Vendor Tersedia', '120', 'storefront', 2],
        ['eo', 'user', 'Booking Minggu Ini', '8', 'bookmark', 3],
        ['eo', 'user', 'Rating Vendor', '4.6', 'star', 4],
        ['eo', 'creator', 'Proyek Event', '15', 'event_available', 1],
        ['eo', 'creator', 'Vendor Terpilih', '4', 'how_to_reg', 2],
        ['eo', 'creator', 'Selesai', '23', 'task_alt', 3],
        ['eo', 'creator', 'Rating', '4.9', 'star', 4],

        // wo
        ['wo', 'user', 'Wedding Mendatang', '4', 'favorite', 1],
        ['wo', 'user', 'Vendor Tersedia', '85', 'storefront', 2],
        ['wo', 'user', 'Paket Populer', '12', 'local_offer', 3],
        ['wo', 'user', 'Rating Vendor', '4.8', 'star', 4],
        ['wo', 'creator', 'Wedding Aktif', '5', 'event_busy', 1],
        ['wo', 'creator', 'Vendor Terpilih', '8', 'how_to_reg', 2],
        ['wo', 'creator', 'Selesai', '31', 'task_alt', 3],
        ['wo', 'creator', 'Rating', '4.9', 'star', 4],

        // sekolah
        ['sekolah', 'user', 'Lowongan Magang', '15', 'work', 1],
        ['sekolah', 'user', 'Alumni Terdaftar', '320', 'people', 2],
        ['sekolah', 'user', 'Event Kampus', '7', 'event', 3],
        ['sekolah', 'user', 'Mitra Industri', '25', 'handshake', 4],
        ['sekolah', 'creator', 'Siswa Aktif', '45', 'school', 1],
        ['sekolah', 'creator', 'Magang Berjalan', '6', 'pending_actions', 2],
        ['sekolah', 'creator', 'Lulus Magang', '38', 'task_alt', 3],
        ['sekolah', 'creator', 'Rating Sekolah', '4.5', 'star', 4],

        // umkm
        ['umkm', 'user', 'Kreator Tersedia', '90', 'people', 1],
        ['umkm', 'user', 'Proyek Konten', '18', 'photo_camera', 2],
        ['umkm', 'user', 'Brand Terdaftar', '56', 'business', 3],
        ['umkm', 'user', 'Rating Layanan', '4.6', 'star', 4],
        ['umkm', 'creator', 'Proyek Branding', '8', 'campaign', 1],
        ['umkm', 'creator', 'Klien Aktif', '5', 'people', 2],
        ['umkm', 'creator', 'Selesai', '22', 'task_alt', 3],
        ['umkm', 'creator', 'Rating', '4.7', 'star', 4],

        // pemerintah
        ['pemerintah', 'user', 'Program Aktif', '10', 'account_balance', 1],
        ['pemerintah', 'user', 'Pelatihan Tersedia', '8', 'menu_book', 2],
        ['pemerintah', 'user', 'Peserta Terdaftar', '245', 'people', 3],
        ['pemerintah', 'user', 'Mitra Daerah', '14', 'handshake', 4],
        ['pemerintah', 'creator', 'Proyek Pemerintah', '6', 'gavel', 1],
        ['pemerintah', 'creator', 'Publikasi Aktif', '3', 'article', 2],
        ['pemerintah', 'creator', 'Selesai', '15', 'task_alt', 3],
        ['pemerintah', 'creator', 'Rating', '4.5', 'star', 4],

        // komunitas
        ['komunitas', 'user', 'Event Komunitas', '9', 'groups', 1],
        ['komunitas', 'user', 'Anggota Aktif', '180', 'people', 2],
        ['komunitas', 'user', 'Workshop Tersedia', '5', 'menu_book', 3],
        ['komunitas', 'user', 'Kolaborasi Baru', '12', 'handshake', 4],
        ['komunitas', 'creator', 'Event Dikelola', '7', 'event', 1],
        ['komunitas', 'creator', 'Peserta Total', '320', 'people', 2],
        ['komunitas', 'creator', 'Selesai', '19', 'task_alt', 3],
        ['komunitas', 'creator', 'Rating', '4.8', 'star', 4],

        // organisasi
        ['organisasi', 'user', 'Pelatihan Tersedia', '11', 'menu_book', 1],
        ['organisasi', 'user', 'Anggota Organisasi', '210', 'people', 2],
        ['organisasi', 'user', 'Pameran Mendatang', '3', 'storefront', 3],
        ['organisasi', 'user', 'Mitra Asosiasi', '18', 'handshake', 4],
        ['organisasi', 'creator', 'Event Organisasi', '9', 'corporate_fare', 1],
        ['organisasi', 'creator', 'Anggota Dikelola', '75', 'people', 2],
        ['organisasi', 'creator', 'Selesai', '27', 'task_alt', 3],
        ['organisasi', 'creator', 'Rating', '4.6', 'star', 4],
    ];

    $stmtStats = $pdo->prepare("INSERT INTO dashboard_stats (pihak_slug, role_type, stat_label, stat_value, stat_icon, display_order) VALUES (?, ?, ?, ?, ?, ?)");
    foreach ($statsData as $s) {
        $stmtStats->execute($s);
    }

    // Seed opportunities (2-3 per pihak, posted_by = 1 = Admin)
    $oppData = [
        // kreator
        ['Fotografer Event Jakarta', 'Dibutuhkan fotografer profesional untuk dokumentasi event corporate di Jakarta. Minimal pengalaman 2 tahun.', 'kreator', 'Jakarta', '2026-07-15', 'Rp 3.000.000 - Rp 5.000.000', 'open', 1],
        ['Videografer Wedding Bandung', 'Mencari videografer untuk dokumentasi pernikahan di Bandung. Wajib punya portofolio wedding.', 'kreator', 'Bandung', '2026-07-20', 'Rp 5.000.000 - Rp 8.000.000', 'open', 1],
        ['MUA Fashion Show', 'Dibutuhkan Make Up Artist untuk fashion show brand lokal. 10 model perlu di-makeup.', 'kreator', 'Surabaya', '2026-08-01', 'Rp 4.000.000 - Rp 6.000.000', 'open', 1],

        // eo
        ['Konser Musik Akhir Tahun', 'Event organizer untuk konser musik akhir tahun kapasitas 5000 orang. Termasuk sound, lighting, dan stage.', 'eo', 'Jakarta', '2026-12-20', 'Rp 50.000.000 - Rp 100.000.000', 'open', 1],
        ['Festival Kuliner Nusantara', 'Penyelenggaraan festival kuliner skala kota selama 3 hari. Butuh tim EO berpengalaman.', 'eo', 'Yogyakarta', '2026-09-10', 'Rp 30.000.000 - Rp 60.000.000', 'open', 1],

        // wo
        ['Paket Wedding Premium', 'Wedding organizer untuk acara pernikahan premium 500 tamu. Venue hotel bintang 5.', 'wo', 'Jakarta', '2026-10-15', 'Rp 80.000.000 - Rp 150.000.000', 'open', 1],
        ['Wedding Intimate Garden', 'Wedding organizer untuk intimate wedding 100 tamu di garden venue. Konsep rustic.', 'wo', 'Bali', '2026-08-25', 'Rp 25.000.000 - Rp 50.000.000', 'open', 1],

        // sekolah
        ['Lomba Desain Poster', 'Lomba desain poster antar siswa SMA se-Jawa Barat. Tema: Kreativitas Digital.', 'sekolah', 'Bandung', '2026-08-15', 'Rp 500.000 - Rp 2.000.000', 'open', 1],
        ['Magang Konten Kreator', 'Program magang 3 bulan untuk siswa SMK jurusan multimedia di perusahaan media.', 'sekolah', 'Jakarta', '2026-09-01', 'Rp 1.500.000/bulan', 'open', 1],

        // umkm
        ['Fotografi Produk UMKM', 'Jasa foto produk untuk 50 SKU produk makanan ringan. Butuh studio dan properti.', 'umkm', 'Semarang', '2026-07-30', 'Rp 3.000.000 - Rp 5.000.000', 'open', 1],
        ['Video Promosi Brand Lokal', 'Pembuatan video promosi 60 detik untuk brand fashion lokal. Termasuk talent dan editing.', 'umkm', 'Bandung', '2026-08-10', 'Rp 5.000.000 - Rp 8.000.000', 'open', 1],

        // pemerintah
        ['Festival Budaya Daerah', 'Dokumentasi dan publikasi festival budaya daerah selama 5 hari. Tim foto dan video.', 'pemerintah', 'Solo', '2026-09-20', 'Rp 15.000.000 - Rp 25.000.000', 'open', 1],
        ['Pelatihan UMKM Kreatif', 'Kreator konten untuk dokumentasi dan materi pelatihan UMKM oleh Dinas Koperasi.', 'pemerintah', 'Surabaya', '2026-08-05', 'Rp 5.000.000 - Rp 10.000.000', 'open', 1],

        // komunitas
        ['Workshop Photography', 'Workshop fotografi untuk pemula oleh komunitas fotografer. Butuh mentor dan asisten.', 'komunitas', 'Jakarta', '2026-07-25', 'Rp 2.000.000 - Rp 4.000.000', 'open', 1],
        ['City Photo Hunt', 'Event photo hunt keliling kota untuk anggota komunitas. Butuh guide dan juri.', 'komunitas', 'Malang', '2026-08-15', 'Rp 1.500.000 - Rp 3.000.000', 'open', 1],

        // organisasi
        ['Pelatihan Digital Marketing', 'Pelatihan digital marketing untuk anggota asosiasi UMKM. Sertifikasi nasional.', 'organisasi', 'Jakarta', '2026-09-05', 'Rp 10.000.000 - Rp 20.000.000', 'open', 1],
        ['Pameran Produk Anggota', 'Pameran produk tahunan anggota organisasi. Butuh tim desain booth dan dokumentasi.', 'organisasi', 'Surabaya', '2026-10-01', 'Rp 15.000.000 - Rp 30.000.000', 'open', 1],
    ];

    $stmtOpp = $pdo->prepare("INSERT INTO opportunities (title, description, pihak_slug, location, deadline, budget_range, status, posted_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
    foreach ($oppData as $o) {
        $stmtOpp->execute($o);
    }

    // Seed notifikasi untuk demo user
    $pdo->exec("INSERT INTO notifications (user_id, title, message, type) VALUES 
        (2, 'Selamat Datang!', 'Selamat datang di Kreavana! Jelajahi peluang kreatif dan mulai berkarya.', 'welcome'),
        (2, 'Peluang Baru', 'Ada 5 peluang baru di kategori Kreator minggu ini.', 'opportunity'),
        (1, 'Sistem', 'Database berhasil diinisialisasi.', 'system')
    ");

    // Response sukses
    echo json_encode([
        'success' => true,
        'message' => 'Database kreavana_db berhasil diinisialisasi!',
        'data' => [
            'tables_created' => ['users', 'pihak_categories', 'creator_applications', 'user_pihak', 'opportunities', 'notifications', 'dashboard_stats'],
            'seed_summary' => [
                'pihak_categories' => count($pihakData),
                'dashboard_stats' => count($statsData),
                'opportunities' => count($oppData),
                'demo_users' => 2,
                'notifications' => 3
            ]
        ]
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error inisialisasi database: ' . $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}
