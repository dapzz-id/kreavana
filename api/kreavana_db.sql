-- phpMyAdmin SQL Dump
-- version 5.2.0
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Jun 21, 2026 at 10:30 AM
-- Server version: 8.0.30
-- PHP Version: 8.3.31

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `kreavana_db`
--

-- --------------------------------------------------------

--
-- Table structure for table `creator_applications`
--

CREATE TABLE `creator_applications` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `pihak_category` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `skill_description` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `portfolio_link` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `experience` text COLLATE utf8mb4_unicode_ci,
  `status` enum('pending','approved','rejected') COLLATE utf8mb4_unicode_ci DEFAULT 'pending',
  `admin_note` text COLLATE utf8mb4_unicode_ci,
  `applied_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `reviewed_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `creator_applications`
--

INSERT INTO `creator_applications` (`id`, `user_id`, `pihak_category`, `skill_description`, `portfolio_link`, `experience`, `status`, `admin_note`, `applied_at`, `reviewed_at`) VALUES
(1, 3, 'wo', 'designer', 'https://www.youtube.com/c/lordzik/videos', 'LKS NASIONAL JUARA 1', 'approved', 'Disetujui otomatis untuk demo sistem.', '2026-06-21 09:24:36', '2026-06-21 09:24:36');

-- --------------------------------------------------------

--
-- Table structure for table `dashboard_stats`
--

CREATE TABLE `dashboard_stats` (
  `id` int NOT NULL,
  `pihak_slug` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role_type` enum('user','creator') COLLATE utf8mb4_unicode_ci NOT NULL,
  `stat_label` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `stat_value` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `stat_icon` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `display_order` int DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `dashboard_stats`
--

INSERT INTO `dashboard_stats` (`id`, `pihak_slug`, `role_type`, `stat_label`, `stat_value`, `stat_icon`, `display_order`) VALUES
(1, 'kreator', 'user', 'Peluang Tersedia', '24', 'work', 1),
(2, 'kreator', 'user', 'Kreator Aktif', '150', 'people', 2),
(3, 'kreator', 'user', 'Rating Rata-rata', '4.7', 'star', 3),
(4, 'kreator', 'user', 'Proyek Selesai', '89', 'check_circle', 4),
(5, 'kreator', 'creator', 'Peluang Diterima', '12', 'assignment_turned_in', 1),
(6, 'kreator', 'creator', 'Proyek Berjalan', '3', 'pending_actions', 2),
(7, 'kreator', 'creator', 'Selesai', '18', 'task_alt', 3),
(8, 'kreator', 'creator', 'Rating Kamu', '4.8', 'star', 4),
(9, 'eo', 'user', 'Event Mendatang', '6', 'event', 1),
(10, 'eo', 'user', 'Vendor Tersedia', '120', 'storefront', 2),
(11, 'eo', 'user', 'Booking Minggu Ini', '8', 'bookmark', 3),
(12, 'eo', 'user', 'Rating Vendor', '4.6', 'star', 4),
(13, 'eo', 'creator', 'Proyek Event', '15', 'event_available', 1),
(14, 'eo', 'creator', 'Vendor Terpilih', '4', 'how_to_reg', 2),
(15, 'eo', 'creator', 'Selesai', '23', 'task_alt', 3),
(16, 'eo', 'creator', 'Rating', '4.9', 'star', 4),
(17, 'wo', 'user', 'Wedding Mendatang', '4', 'favorite', 1),
(18, 'wo', 'user', 'Vendor Tersedia', '85', 'storefront', 2),
(19, 'wo', 'user', 'Paket Populer', '12', 'local_offer', 3),
(20, 'wo', 'user', 'Rating Vendor', '4.8', 'star', 4),
(21, 'wo', 'creator', 'Wedding Aktif', '5', 'event_busy', 1),
(22, 'wo', 'creator', 'Vendor Terpilih', '8', 'how_to_reg', 2),
(23, 'wo', 'creator', 'Selesai', '31', 'task_alt', 3),
(24, 'wo', 'creator', 'Rating', '4.9', 'star', 4),
(25, 'sekolah', 'user', 'Lowongan Magang', '15', 'work', 1),
(26, 'sekolah', 'user', 'Alumni Terdaftar', '320', 'people', 2),
(27, 'sekolah', 'user', 'Event Kampus', '7', 'event', 3),
(28, 'sekolah', 'user', 'Mitra Industri', '25', 'handshake', 4),
(29, 'sekolah', 'creator', 'Siswa Aktif', '45', 'school', 1),
(30, 'sekolah', 'creator', 'Magang Berjalan', '6', 'pending_actions', 2),
(31, 'sekolah', 'creator', 'Lulus Magang', '38', 'task_alt', 3),
(32, 'sekolah', 'creator', 'Rating Sekolah', '4.5', 'star', 4),
(33, 'umkm', 'user', 'Kreator Tersedia', '90', 'people', 1),
(34, 'umkm', 'user', 'Proyek Konten', '18', 'photo_camera', 2),
(35, 'umkm', 'user', 'Brand Terdaftar', '56', 'business', 3),
(36, 'umkm', 'user', 'Rating Layanan', '4.6', 'star', 4),
(37, 'umkm', 'creator', 'Proyek Branding', '8', 'campaign', 1),
(38, 'umkm', 'creator', 'Klien Aktif', '5', 'people', 2),
(39, 'umkm', 'creator', 'Selesai', '22', 'task_alt', 3),
(40, 'umkm', 'creator', 'Rating', '4.7', 'star', 4),
(41, 'pemerintah', 'user', 'Program Aktif', '10', 'account_balance', 1),
(42, 'pemerintah', 'user', 'Pelatihan Tersedia', '8', 'menu_book', 2),
(43, 'pemerintah', 'user', 'Peserta Terdaftar', '245', 'people', 3),
(44, 'pemerintah', 'user', 'Mitra Daerah', '14', 'handshake', 4),
(45, 'pemerintah', 'creator', 'Proyek Pemerintah', '6', 'gavel', 1),
(46, 'pemerintah', 'creator', 'Publikasi Aktif', '3', 'article', 2),
(47, 'pemerintah', 'creator', 'Selesai', '15', 'task_alt', 3),
(48, 'pemerintah', 'creator', 'Rating', '4.5', 'star', 4),
(49, 'komunitas', 'user', 'Event Komunitas', '9', 'groups', 1),
(50, 'komunitas', 'user', 'Anggota Aktif', '180', 'people', 2),
(51, 'komunitas', 'user', 'Workshop Tersedia', '5', 'menu_book', 3),
(52, 'komunitas', 'user', 'Kolaborasi Baru', '12', 'handshake', 4),
(53, 'komunitas', 'creator', 'Event Dikelola', '7', 'event', 1),
(54, 'komunitas', 'creator', 'Peserta Total', '320', 'people', 2),
(55, 'komunitas', 'creator', 'Selesai', '19', 'task_alt', 3),
(56, 'komunitas', 'creator', 'Rating', '4.8', 'star', 4),
(57, 'organisasi', 'user', 'Pelatihan Tersedia', '11', 'menu_book', 1),
(58, 'organisasi', 'user', 'Anggota Organisasi', '210', 'people', 2),
(59, 'organisasi', 'user', 'Pameran Mendatang', '3', 'storefront', 3),
(60, 'organisasi', 'user', 'Mitra Asosiasi', '18', 'handshake', 4),
(61, 'organisasi', 'creator', 'Event Organisasi', '9', 'corporate_fare', 1),
(62, 'organisasi', 'creator', 'Anggota Dikelola', '75', 'people', 2),
(63, 'organisasi', 'creator', 'Selesai', '27', 'task_alt', 3),
(64, 'organisasi', 'creator', 'Rating', '4.6', 'star', 4);

-- --------------------------------------------------------

--
-- Table structure for table `notifications`
--

CREATE TABLE `notifications` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `title` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `message` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'info',
  `is_read` tinyint(1) DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `notifications`
--

INSERT INTO `notifications` (`id`, `user_id`, `title`, `message`, `type`, `is_read`, `created_at`) VALUES
(1, 2, 'Selamat Datang!', 'Selamat datang di Kreavana! Jelajahi peluang kreatif dan mulai berkarya.', 'welcome', 0, '2026-06-21 09:10:20'),
(2, 2, 'Peluang Baru', 'Ada 5 peluang baru di kategori Kreator minggu ini.', 'opportunity', 0, '2026-06-21 09:10:20'),
(3, 1, 'Sistem', 'Database berhasil diinisialisasi.', 'system', 0, '2026-06-21 09:10:20'),
(4, 3, 'Selamat Datang!', 'Selamat bergabung di Kreavana! Temukan peluang kolaborasi terbaik disini.', 'welcome', 0, '2026-06-21 09:16:57'),
(5, 3, 'Pengajuan Kreator Disetujui!', 'Selamat! Pengajuan Anda sebagai Kreator di kategori Wedding Organizer telah disetujui. Dashboard Kreator Anda kini aktif.', 'creator_approved', 0, '2026-06-21 09:24:36');

-- --------------------------------------------------------

--
-- Table structure for table `opportunities`
--

CREATE TABLE `opportunities` (
  `id` int NOT NULL,
  `title` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `pihak_slug` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `location` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `deadline` date DEFAULT NULL,
  `budget_range` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('open','in_progress','completed','closed') COLLATE utf8mb4_unicode_ci DEFAULT 'open',
  `posted_by` int NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `opportunities`
--

INSERT INTO `opportunities` (`id`, `title`, `description`, `pihak_slug`, `location`, `deadline`, `budget_range`, `status`, `posted_by`, `created_at`) VALUES
(1, 'Fotografer Event Jakarta', 'Dibutuhkan fotografer profesional untuk dokumentasi event corporate di Jakarta. Minimal pengalaman 2 tahun.', 'kreator', 'Jakarta', '2026-07-15', 'Rp 3.000.000 - Rp 5.000.000', 'open', 1, '2026-06-21 09:10:20'),
(2, 'Videografer Wedding Bandung', 'Mencari videografer untuk dokumentasi pernikahan di Bandung. Wajib punya portofolio wedding.', 'kreator', 'Bandung', '2026-07-20', 'Rp 5.000.000 - Rp 8.000.000', 'open', 1, '2026-06-21 09:10:20'),
(3, 'MUA Fashion Show', 'Dibutuhkan Make Up Artist untuk fashion show brand lokal. 10 model perlu di-makeup.', 'kreator', 'Surabaya', '2026-08-01', 'Rp 4.000.000 - Rp 6.000.000', 'open', 1, '2026-06-21 09:10:20'),
(4, 'Konser Musik Akhir Tahun', 'Event organizer untuk konser musik akhir tahun kapasitas 5000 orang. Termasuk sound, lighting, dan stage.', 'eo', 'Jakarta', '2026-12-20', 'Rp 50.000.000 - Rp 100.000.000', 'open', 1, '2026-06-21 09:10:20'),
(5, 'Festival Kuliner Nusantara', 'Penyelenggaraan festival kuliner skala kota selama 3 hari. Butuh tim EO berpengalaman.', 'eo', 'Yogyakarta', '2026-09-10', 'Rp 30.000.000 - Rp 60.000.000', 'open', 1, '2026-06-21 09:10:20'),
(6, 'Paket Wedding Premium', 'Wedding organizer untuk acara pernikahan premium 500 tamu. Venue hotel bintang 5.', 'wo', 'Jakarta', '2026-10-15', 'Rp 80.000.000 - Rp 150.000.000', 'open', 1, '2026-06-21 09:10:20'),
(7, 'Wedding Intimate Garden', 'Wedding organizer untuk intimate wedding 100 tamu di garden venue. Konsep rustic.', 'wo', 'Bali', '2026-08-25', 'Rp 25.000.000 - Rp 50.000.000', 'open', 1, '2026-06-21 09:10:20'),
(8, 'Lomba Desain Poster', 'Lomba desain poster antar siswa SMA se-Jawa Barat. Tema: Kreativitas Digital.', 'sekolah', 'Bandung', '2026-08-15', 'Rp 500.000 - Rp 2.000.000', 'open', 1, '2026-06-21 09:10:20'),
(9, 'Magang Konten Kreator', 'Program magang 3 bulan untuk siswa SMK jurusan multimedia di perusahaan media.', 'sekolah', 'Jakarta', '2026-09-01', 'Rp 1.500.000/bulan', 'open', 1, '2026-06-21 09:10:20'),
(10, 'Fotografi Produk UMKM', 'Jasa foto produk untuk 50 SKU produk makanan ringan. Butuh studio dan properti.', 'umkm', 'Semarang', '2026-07-30', 'Rp 3.000.000 - Rp 5.000.000', 'open', 1, '2026-06-21 09:10:20'),
(11, 'Video Promosi Brand Lokal', 'Pembuatan video promosi 60 detik untuk brand fashion lokal. Termasuk talent dan editing.', 'umkm', 'Bandung', '2026-08-10', 'Rp 5.000.000 - Rp 8.000.000', 'open', 1, '2026-06-21 09:10:20'),
(12, 'Festival Budaya Daerah', 'Dokumentasi dan publikasi festival budaya daerah selama 5 hari. Tim foto dan video.', 'pemerintah', 'Solo', '2026-09-20', 'Rp 15.000.000 - Rp 25.000.000', 'open', 1, '2026-06-21 09:10:20'),
(13, 'Pelatihan UMKM Kreatif', 'Kreator konten untuk dokumentasi dan materi pelatihan UMKM oleh Dinas Koperasi.', 'pemerintah', 'Surabaya', '2026-08-05', 'Rp 5.000.000 - Rp 10.000.000', 'open', 1, '2026-06-21 09:10:20'),
(14, 'Workshop Photography', 'Workshop fotografi untuk pemula oleh komunitas fotografer. Butuh mentor dan asisten.', 'komunitas', 'Jakarta', '2026-07-25', 'Rp 2.000.000 - Rp 4.000.000', 'open', 1, '2026-06-21 09:10:20'),
(15, 'City Photo Hunt', 'Event photo hunt keliling kota untuk anggota komunitas. Butuh guide dan juri.', 'komunitas', 'Malang', '2026-08-15', 'Rp 1.500.000 - Rp 3.000.000', 'open', 1, '2026-06-21 09:10:20'),
(16, 'Pelatihan Digital Marketing', 'Pelatihan digital marketing untuk anggota asosiasi UMKM. Sertifikasi nasional.', 'organisasi', 'Jakarta', '2026-09-05', 'Rp 10.000.000 - Rp 20.000.000', 'open', 1, '2026-06-21 09:10:20'),
(17, 'Pameran Produk Anggota', 'Pameran produk tahunan anggota organisasi. Butuh tim desain booth dan dokumentasi.', 'organisasi', 'Surabaya', '2026-10-01', 'Rp 15.000.000 - Rp 30.000.000', 'open', 1, '2026-06-21 09:10:20');

-- --------------------------------------------------------

--
-- Table structure for table `pihak_categories`
--

CREATE TABLE `pihak_categories` (
  `id` int NOT NULL,
  `slug` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `icon` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `color` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `pihak_categories`
--

INSERT INTO `pihak_categories` (`id`, `slug`, `name`, `description`, `icon`, `color`) VALUES
(1, 'kreator', 'Kreator', 'Fotografer, Videografer, MUA, Desainer, MC, Musisi, dll', 'brush', '#F97316'),
(2, 'eo', 'Event Organizer', 'Cari vendor terpercaya untuk event', 'event', '#3B82F6'),
(3, 'wo', 'Wedding Organizer', 'Paket vendor lengkap untuk wedding', 'favorite', '#8B5CF6'),
(4, 'sekolah', 'Sekolah / Kampus', 'Database alumni & talenta, magang & PKL', 'school', '#10B981'),
(5, 'umkm', 'Perusahaan / UMKM', 'Konten branding & promosi bisnis', 'business', '#06B6D4'),
(6, 'pemerintah', 'Pemerintah', 'Publikasi program & kegiatan resmi', 'gavel', '#1E3A8A'),
(7, 'komunitas', 'Komunitas', 'Event komunitas & kolaborasi', 'groups', '#EC4899'),
(8, 'organisasi', 'Organisasi / Asosiasi', 'Direktori anggota & event eksklusif', 'corporate_fare', '#3F51B5');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` int NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `username` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `avatar_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `phone` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `role` enum('user','creator') COLLATE utf8mb4_unicode_ci DEFAULT 'user',
  `selected_pihak` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'kreator',
  `is_creator_approved` tinyint(1) DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `name`, `username`, `email`, `password`, `avatar_url`, `phone`, `role`, `selected_pihak`, `is_creator_approved`, `created_at`, `updated_at`) VALUES
(1, 'Admin Kreavana', 'admin', 'admin@kreavana.id', '$2y$10$4rijZgCiS6w12ONfk4Bbs.8BbIvIJotJUXxfQqqXPF.h.HCOuRe3W', NULL, NULL, 'creator', 'kreator', 1, '2026-06-21 09:10:20', '2026-06-21 09:10:20'),
(2, 'Demo User', 'demo', 'demo@kreavana.id', '$2y$10$4rijZgCiS6w12ONfk4Bbs.8BbIvIJotJUXxfQqqXPF.h.HCOuRe3W', NULL, NULL, 'user', 'kreator', 0, '2026-06-21 09:10:20', '2026-06-21 09:10:20'),
(3, 'Fikri Alifa Alfan Ramadhan', 'Alpan', 'alfanalifa2008@gmail.com', '$2y$10$62TQSnVGtm9KYLKRHjZVm..mMJGMqmvufDh.ucp9d7.H0JhjiVae6', NULL, NULL, 'creator', 'eo', 1, '2026-06-21 09:16:57', '2026-06-21 10:24:38');

-- --------------------------------------------------------

--
-- Table structure for table `user_pihak`
--

CREATE TABLE `user_pihak` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `pihak_slug` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role_type` enum('user','creator') COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_active` tinyint(1) DEFAULT '1',
  `joined_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `user_pihak`
--

INSERT INTO `user_pihak` (`id`, `user_id`, `pihak_slug`, `role_type`, `is_active`, `joined_at`) VALUES
(1, 3, 'kreator', 'user', 1, '2026-06-21 09:16:57'),
(9, 3, 'wo', 'creator', 0, '2026-06-21 09:24:36'),
(10, 3, 'wo', 'user', 1, '2026-06-21 09:24:36'),
(18, 3, 'kreator', 'creator', 1, '2026-06-21 09:25:50'),
(19, 3, 'organisasi', 'creator', 1, '2026-06-21 09:25:55'),
(24, 3, 'sekolah', 'creator', 1, '2026-06-21 09:37:46'),
(25, 3, 'umkm', 'creator', 1, '2026-06-21 09:37:58'),
(27, 3, 'eo', 'creator', 1, '2026-06-21 09:44:03'),
(33, 3, 'komunitas', 'creator', 0, '2026-06-21 10:08:18'),
(34, 3, 'pemerintah', 'creator', 1, '2026-06-21 10:08:18');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `creator_applications`
--
ALTER TABLE `creator_applications`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`);

--
-- Indexes for table `dashboard_stats`
--
ALTER TABLE `dashboard_stats`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `notifications`
--
ALTER TABLE `notifications`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`);

--
-- Indexes for table `opportunities`
--
ALTER TABLE `opportunities`
  ADD PRIMARY KEY (`id`),
  ADD KEY `posted_by` (`posted_by`);

--
-- Indexes for table `pihak_categories`
--
ALTER TABLE `pihak_categories`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `slug` (`slug`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `username` (`username`),
  ADD UNIQUE KEY `email` (`email`);

--
-- Indexes for table `user_pihak`
--
ALTER TABLE `user_pihak`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_user_pihak_role` (`user_id`,`pihak_slug`,`role_type`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `creator_applications`
--
ALTER TABLE `creator_applications`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `dashboard_stats`
--
ALTER TABLE `dashboard_stats`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=65;

--
-- AUTO_INCREMENT for table `notifications`
--
ALTER TABLE `notifications`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `opportunities`
--
ALTER TABLE `opportunities`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18;

--
-- AUTO_INCREMENT for table `pihak_categories`
--
ALTER TABLE `pihak_categories`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `user_pihak`
--
ALTER TABLE `user_pihak`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=114;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `creator_applications`
--
ALTER TABLE `creator_applications`
  ADD CONSTRAINT `creator_applications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `notifications`
--
ALTER TABLE `notifications`
  ADD CONSTRAINT `notifications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `opportunities`
--
ALTER TABLE `opportunities`
  ADD CONSTRAINT `opportunities_ibfk_1` FOREIGN KEY (`posted_by`) REFERENCES `users` (`id`);

--
-- Constraints for table `user_pihak`
--
ALTER TABLE `user_pihak`
  ADD CONSTRAINT `user_pihak_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
