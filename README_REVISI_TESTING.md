# Panduan Revisi Fitur, Testing & Data Dummy Demo Kreavana

Dokumen ini merangkum penyelesaian revisi sistem ulasan/rating proyek, perbaikan navigasi chat partner, serta panduan pengujian langkah demi langkah untuk keperluan presentasi atau pengujian aplikasi **Kreavana**.

---

## 📌 Ringkasan Poin Revisi & Solusi Teknis

### 1. Rating Acara Sebelum Masuk Kreavana (*Rekam Jejak / Rating Eksternal*)
* **Pertanyaan Revisi:** Bagaimana untuk project acara sebelum dimasukkan di Kreavana bisa diketahui rekam jejak atau ratingnya dari luar?
* **Konsep:** Saat klien/institusi membuat kebutuhan proyek baru untuk acara yang sebelumnya sudah pernah diselenggarakan secara offline/di luar Kreavana (misal: konser tahunan, festival, expo, atau gathering yang memiliki ulasan di Google Reviews, Loket.com, Instagram, atau survei kepuasan peserta tahun lalu), klien dapat melampirkan rekam jejak tersebut.
* **Implementasi Fitur:**
  * **Formulir Buat Kebutuhan (`buat_kebutuhan_screen.dart`):** Dilengkapi toggle dan kolom isian:
    * **Nilai Rating Eksternal:** Skala 1.0 – 5.0 (contoh: `4.9`).
    * **Sumber Rating Eksternal:** Keterangan sumber ulasan (contoh: `Loket.com & Google Reviews (Edisi 2025)`).
  * **Tampilan pada Kartu Proyek (`proyek_saya_screen.dart`):** Muncul badge bintang emas terverifikasi, misal `⭐ 4.9 (Loket.com & Google Reviews)`.
  * **Tampilan pada Lembar Detail (`opportunity_detail_sheet.dart`):** Menampilkan banner verifikasi kredibilitas acara sehingga kreator yang ingin melamar merasa yakin dengan kredibilitas penyelenggara.
  * **Struktur Database (`opportunities`):** Kolom `external_rating` (decimal 3,2) dan `external_rating_source` (varchar).

---

### 2. Memberikan Ulasan/Rating untuk Event yang Dibuat di Kreavana (*Internal Review Sistem*)
* **Pertanyaan Revisi:** Untuk project ke depannya yang akan dibuat dan dikerjakan di Kreavana, bagaimana cara memberikan rating atau ulasannya?
* **Konsep:** Setelah pekerjaan atau kontrak acara selesai diselenggarakan di Kreavana, pihak penyelenggara/klien dapat memberikan penilaian kinerja resmi kepada para mitra kerja atau kreator.
* **Implementasi Fitur:**
  * **Pemicu Tombol (`proyek_saya_screen.dart`):** Pada proyek atau kontrak kerja yang statusnya telah mencapai **Selesai** (`Pekerjaan Selesai` / `isCompleted` / `progress == 100%`), sistem otomatis memunculkan tombol aksen emas: **`⭐ Beri Ulasan`**.
  * **Modal Ulasan Interaktif (`opportunity_review_dialog.dart`):**
    * Rating bintang interaktif (1.0 s/d 5.0 bintang).
    * Switch kepuasan ketepatan waktu (*Pekerjaan selesai tepat waktu / On Time Delivery*).
    * Estimasi durasi pengerjaan (*Jumlah hari kerja*).
    * Testimoni / komentar ulasan tertulis.
  * **Dampak Sistem:** Disimpan ke database (`opportunity_reviews`) melalui endpoint `POST /api/opportunities/{id}/reviews`. Ulasan ini otomatis memperbarui skor reputasi performa kreator dan tampil pada portofolio publik mereka di Kreavana.

---

### 3. Perbaikan Navigasi Chat Kontak Partner
* **Masalah Sebelumnya:** Mengklik ikon chat pada kartu proyek atau tombol "Kirim Pesan" di modal Detail Kontrak hanya membuka menu obrolan kosong tanpa otomatis beralih ke kontak partner yang bersangkutan.
* **Solusi & Perbaikan:**
  * **Resolusi Partner Dinamis:** Sistem memeriksa role user yang sedang login:
    * Jika login sebagai **Klien**, partner otomatis diarahkan ke **Kreator** (`contract.creatorId`).
    * Jika login sebagai **Kreator**, partner otomatis diarahkan ke **Klien** (`contract.clientId`).
    * Proteksi pencegahan *self-chat* (chat ke akun sendiri).
  * **Pemanggilan API Personal Chat:** Menghubungkan ke `ChatService.startPersonalChat(partnerId)` yang memuat ID room chat 1-on-1 dengan partner.
  * **Navigasi Responsif:**
    * **Desktop / Layar Lebar (`width > 800`):** Membuka `DirectMessageScreen` dengan percakapan kontak partner langsung aktif di panel sebelah kanan.
    * **Mobile / Ponsel (`width <= 800`):** Langsung membuka layar `ChatDetailSection` bersama partner. Ketika tombol *back* ditekan, user kembali ke halaman Proyek Saya.

---

### 4. Institution (Sekolah): Rentang Tanggal Awal s/d Akhir Agenda (Tanggal, Bulan, Tahun)
* **Masukan Revisi Pak Abi:** Di halaman kegiatan & event tambahkan tanggal, bulan, dan tahun mulai dari awal agenda sampai akhir agenda tersebut.
* **Konsep:** Setiap agenda, workshop, pameran karya, atau evaluasi magang siswa di sekolah seringkali berlangsung selama beberapa hari (misal 3-5 hari kegiatan). Penyelenggara dan siswa perlu melihat kepastian waktu secara jelas mulai dari tanggal buka/mulai sampai tanggal penutupan/akhir agenda lengkap dengan tahunnya.
* **Implementasi Fitur:**
  * **Tampilan Kartu Kegiatan (`agenda_screen.dart`):**
    * **Badge Kotak Tanggal:** Menampilkan rentang hari (`14-18`), bulan (`Nov`), dan **Tahun** (`2026`).
    * **Chip Tanggal Lengkap:** Menampilkan teks rentang penuh berikon kalender: `📅 14 Nov 2026 - 18 Nov 2026` (atau tanggal tunggal jika kegiatan 1 hari).
  * **Formulir Tambah Kegiatan (`_showAddAgendaModal`):**
    * Dilengkapi **Dua Pemilih Tanggal Interaktif (Date Picker)**:
      * **Awal Agenda (Mulai):** Pemilih Tanggal, Bulan, dan Tahun mulai kegiatan.
      * **Akhir Agenda (Selesai):** Pemilih Tanggal, Bulan, dan Tahun berakhirnya kegiatan.
  * **Integrasi Data Otomatis:** Mengambil rentang tanggal dari kontrak kerja (`scheduled_start_date` s/d `scheduled_end_date`) dan proyek/event sekolah (`event_start_date` s/d `event_end_date`).
  * **Dashboard Sekolah (`school_dashboard_screen.dart`):** Widget jadwal/agenda mendatang kini menampilkan rentang tanggal dan tahun lengkap (misal: `14 - 18 NOV 2026`).

---

## 🚀 Panduan Pengujian & Skenario Demo (Testing Guide)

### Persiapan Data (Jalankan Sekali di Terminal Backend)
Data dummy demo telah disiapkan dengan skenario lengkap (Mencari Kreator, Berjalan, Menunggu, dan Selesai). Jika perlu menyegarkan data:
```bash
cd backend
php artisan db:seed --class=PresentationDemoSeeder
```
*(Di frontend cukup tekan **Hot Reload** `r` di terminal Flutter).*

---

### Skenario 1: Menguji Rating Acara dari Luar (*External Rating*)
1. Buka aplikasi Kreavana -> Masuk ke menu **Proyek Saya**.
2. Pilih tab filter **"Mencari Kreator"**.
3. Cari kartu proyek: **`Jakarta Indie Music & Art Fest 2026`**.
4. **Validasi:**
   * Di atas kartu terlihat badge emas: `⭐ 4.9 (Loket.com & Google Reviews (Edisi 2025))`.
   * Klik tombol **"Lihat Detail Kebutuhan"** -> Perhatikan kartu informasi kredibilitas eksternal tercantum lengkap di lembar rincian acara.
5. *(Opsional Pengujian Form)*: Klik tombol **"+ Tambah Kebutuhan"** -> Gulir ke bagian bawah form -> Aktifkan toggle *"Cantumkan Rekam Jejak / Rating Acara Sebelumnya"* -> Isi rating & sumbernya sendiri.

---

### Skenario 2: Menguji Fitur "Beri Ulasan" Proyek yang Sudah Selesai
1. Di halaman **Proyek Saya**, pilih tab filter **"Selesai"**.
2. Temukan kartu proyek/kontrak yang sudah berstatus tuntas, contohnya:
   * **`Produksi Teaser & Aftermovie Cinematic 4K Expo`** (Kontrak Kerja Selesai)
   * atau **`Nusantara Creative & Coffee Expo 2026`**
3. **Validasi:**
   * Terdapat tombol emas **`⭐ Beri Ulasan`** di sebelah tombol "Detail Kontrak".
4. Klik tombol **`⭐ Beri Ulasan`**:
   * Dialog modal **Beri Ulasan Proyek** akan terbuka.
   * Coba ubah rating bintang (1 - 5), tentukan switch tepat waktu, dan ketik testimoni/ulasan.
   * Klik tombol **"Kirim Ulasan"**.
   * Notifikasi berhasil (*Snackbar*) akan muncul dan data ulasan langsung tersimpan ke backend.

---

### Skenario 3: Menguji Navigasi Langsung Chat Kontak Partner
1. Di halaman **Proyek Saya**, pilih tab filter **"Semua"** atau **"Berjalan"**.
2. Cari kartu kontrak aktif, misalnya:
   * **`Management Acara & Show Director Customer Gathering 2026`** (Partner: *Kreavana Demo Event Organizer*)
   * atau **`Desain Visual Backdrop Panggung & Merchandise VIP`** (Partner: *Kreavana Demo Photographer*)
3. **Pengujian Cara A (Ikon Chat pada Kartu):**
   * Klik ikon balon chat `[💬]` di samping tombol "Detail Kontrak".
   * Muncul indikator: *"Membuka obrolan dengan [Nama Partner]..."*.
   * Aplikasi langsung membuka ruang obrolan 1-on-1 dengan partner tersebut (bukan chat kosong).
4. **Pengujian Cara B (Tombol Kirim Pesan di Modal):**
   * Klik tombol **"Detail Kontrak"** pada kartu.
   * Di jendela pop-up rincian kontrak, klik tombol ungu **"Kirim Pesan"**.
   * Modal tertutup dan aplikasi langsung beralih ke ruang obrolan dengan partner yang tertera.
5. **Pengujian Profil Partner:**
   * Pada pop-up detail kontrak yang sama, klik **"Profil & Portofolio"** -> Halaman profil milik partner terbuka secara akurat.

---

### 5. Pindah / Upgrade Storage ke Kapasitas Lebih Besar
* **Pertanyaan Revisi:** Pada saat pertama kali masuk user otomatis menggunakan storage bawaan, apakah bisa dipindahkan/dinaikkan ke storage yang lebih besar?
* **Konsep:** Pengguna baru mendapatkan storage gratis bawaan sebesar **512 MB**. Ketika kebutuhan bertambah (mengunggah portofolio foto RAW, video 4K, atau berkas proyek besar), pengguna dapat langsung menaikkan (upgrade) kapasitas storagenya ke paket yang lebih besar:
  * **Basic (Free):** 512 MB
  * **Plus:** 3 GB (3 * 1024 * 1024 * 1024 bytes)
  * **Pro:** 10 GB (10 * 1024 * 1024 * 1024 bytes)
  * **Super:** 20 GB (20 * 1024 * 1024 * 1024 bytes)
* **Implementasi Fitur:**
  * **Backend Dynamic Quota (`User.php` & `StorageService.php`):** Accessor `storage_limit_bytes` otomatis membaca tier aktif langganan. File lama tidak hilang dan tidak perlu dipindahkan fisik secara manual; plafon kapasitas akun langsung membesar.
  * **Frontend Modal Upgrade (`upgrade_plan_modal.dart`):** Tersedia tombol upgrade di sidebar, menu profil, layar storage, dan banner AI.

---

### 6. Penilaian Value Proyek Dihitung Berdasarkan Quality
* **Pertanyaan Revisi:** Untuk penilaian value per project dihitung berdasarkan quality?
* **Konsep:** Nilai dan reputasi proyek tidak hanya dihitung dari nominal kontrak statis, melainkan dinilai berdasarkan bobot kualitas (Quality Rating 1.0 – 5.0 bintang) yang diberikan klien/partner setelah proyek selesai.
* **Implementasi Fitur:**
  * **Formulir Review (`opportunity_review_dialog.dart`):** Menampung rating bintang kualitas hasil kerja, ketepatan waktu pengerjaan (*on-time*), durasi kerja, dan ulasan tertulis mutu.
  * **Quality Multiplier & Algoritma Boost (`OpportunityReviewController.php` & `User.php`):** Jika ulasan memiliki rating > 4.0, sistem otomatis mencatat `CreatorPerformanceEvent` (`project_rating`), memicu `updatePerformanceBoost()`, dan menaikkan persentase visibilitas serta ranking akun kreator di hasil pencarian & rekomendasi.
  * **Rekapitulasi Mutu:** Menghitung rata-rata bintang, kepuasan klien (*satisfaction rate*), dan tingkat ketepatan waktu (*on-time rate*).

---

### 7. Role Komunitas: Ekosistem Kreativitas, Peluang dan Kolaborasi
* **Konsep Inti:** Mengikuti infografis diagram resmi Kreavana: *"Tempat di mana potensi bertemu kebutuhan, dan menjadi nilai nyata."*
* **Inti Platform:** **Komunitas (Platform & Ekosistem Kolaborasi Kreatif)** yang menjadi hub penggerak interaksi.
* **5 Pilar Utama Hub:**
  1. **Temukan:** Menemukan talenta, peluang proyek, dan mitra strategis.
  2. **Kolaborasi:** Membangun inisiatif bersama antar pelaku kreatif.
  3. **Proyek:** Mengeksekusi kegiatan dan agenda bernilai tinggi.
  4. **Pendapatan:** Pengelolaan kas, pendanaan, sponsorship, dan monetisasi karya.
  5. **Bangun Reputasi:** Meningkatkan kredibilitas melalui rekam jejak & rating nyata.
* **5 Entitas yang Terhubung & Timbal Balik Manfaat:**
  * **Kreator / Freelancer:** Akses job, portofolio terstruktur, networking. Memberi karya, keahlian, dan partisipasi aktif.
  * **Klien / Pemilik Kebutuhan:** Solusi kreatif tepat, proses cepat & aman. Memberi kebutuhan proyek, feedback, dan referensi.
  * **Mitra / Vendor / Penyedia Jasa:** Klien baru, visibilitas bisnis. Memberi layanan kompetitif, fasilitas studio/alat, dan rekam jejak.
  * **Investor / Sponsor:** Brand exposure luas, impact report terukur. Memberi pendanaan, sponsor program, dan aktivasi bersama.
  * **Tim Kreavana:** Fasilitasi platform, inovasi fitur, ekspansi jaringan, dan pendampingan komunitas.
* **Alur Kerja Komunitas (6 Tahapan):**
  1. `Tahap 1`: **Bergabung & Membuat Profil** (Komunitas) - Registrasi kategori (kreatif, hobi, profesi, wilayah), visi misi, bio.
  2. `Tahap 2`: **Verifikasi & Aktivasi** (Admin Kreavana) - Verifikasi kredibilitas akun resmi & lencana terverifikasi.
  3. `Tahap 3`: **Kelola Kegiatan & Agenda** (Komunitas) - Manajemen jadwal workshop, hunting, meetup, pameran, kuota peserta, dan kas kegiatan.
  4. `Tahap 4`: **Terhubung dengan Anggota & Mitra** (Ekosistem) - Rekrutmen anggota dan integrasi mitra/vendor di ekosistem.
  5. `Tahap 5`: **Publikasi & Promosi** (Komunitas & Kreavana) - Rilis pengumuman resmi dan promosi program bersama ke publik.
  6. `Tahap 6`: **Evaluasi & Pengembangan** (Komunitas) - Analisis kepuasan anggota, feedback acara, dan impact report dampak sosial.
* **Fokus Awal: Komunitas (*Bersama Kita Tumbuh*):**
  * Checklist langkah awal adopsi komunitas: Buat halaman komunitas -> Rekrut komunitas kreatif -> Aktifkan fitur diskusi/event/kolaborasi -> Kumpulkan feedback pengembangan.

---

### Skenario 5: Menguji Role Komunitas & Alur Kerja 6 Tahap
1. Login sebagai akun **Komunitas** (Email: `community@kreavana.id` atau `nabila.zahra@kreavana.id`).
2. Masuk ke dashboard komunitas (`CommunityDashboardScreen`):
   * **Banner Hero Ekosistem:** Menampilkan badge terverifikasi dan tagline *"Tempat di mana potensi bertemu kebutuhan, dan menjadi nilai nyata."*
   * **Alur Kerja Komunitas Stepper:** Menampilkan 6 tahap terstruktur (Bergabung -> Verifikasi -> Agenda -> Anggota -> Promosi -> Evaluasi). Klik salah satu langkah untuk melihat detail tanggung jawab dan aksi.
   * **4 Kartu Metrik Komunitas:** Total Kegiatan, Anggota & Mitra Aktif, Event Berjalan, dan Kas / Anggaran Komunitas.
   * **Ekosistem Kolaborasi (5 Pilar & 5 Entitas):** Menampilkan kartu interaktif Kreator, Klien, Mitra/Vendor, Sponsor, dan Tim Kreavana. Klik tombol *"Lihat Seluruh Manfaat Timbal Balik"* untuk melihat modal dialog rincian manfaat yang didapat vs diberikan.
   * **Pusat Kendali Komunitas (Tabs):**
     * **Kegiatan & Agenda:** Klik **"+ Buat Kegiatan"** -> Isi judul, tanggal, lokasi, kuota -> Jadwalkan kegiatan baru.
     * **Anggota & Mitra:** Klik **"+ Tambah Anggota"** -> Masukkan User ID dan peran komunitas -> Tambahkan anggota.
     * **Publikasi & Promosi:** Klik **"+ Buat Pengumuman"** -> Isi judul, tipe, prioritas, pesan -> Rilis publikasi.
     * **Evaluasi & Dampak:** Lihat rating kepuasan (4.9 / 5.0), 98.4% kepuasan peserta, dan ringkasan dampak sosial.
   * **Fokus Awal Komunitas:** Memuat checklist *Bersama Kita Tumbuh* untuk panduan adopsi komunitas.

---

## 📁 Berkas Penting yang Terkait

| Bagian | Path File |
|---|---|
| **Layar Dashboard & Alur Komunitas** | `frontend/lib/features/dashboard/screens/community_dashboard_screen.dart` |
| **Layanan API Komunitas (Frontend)** | `frontend/lib/services/community_service.dart` |
| **Controller Komunitas (Backend)** | `backend/app/Http/Controllers/CommunityController.php` |
| **Seeder Komplit Komunitas** | `backend/database/seeders/CommunityCompleteSeeder.php` |
| **Routing Layanan Sidebar Komunitas** | `frontend/lib/widgets/desktop_sidebar_layout.dart` |
| **Layar Kegiatan & Event Sekolah** | `frontend/lib/screens/agenda_screen.dart` |
| **Widget Jadwal Dashboard Sekolah** | `frontend/lib/features/dashboard/screens/school_dashboard_screen.dart` |
| **Layar Proyek Saya & Navigasi Chat** | `frontend/lib/screens/proyek_saya_screen.dart` |
| **Modal Beri Ulasan Proyek** | `frontend/lib/widgets/opportunity_review_dialog.dart` |
| **Input Rating Eksternal di Form** | `frontend/lib/screens/buat_kebutuhan_screen.dart` |
| **Tampilan Detail & Rekam Jejak Acara** | `frontend/lib/widgets/opportunity_detail_sheet.dart` |
| **Model Data Peluang/Event** | `frontend/lib/models/opportunity_model.dart` |
| **Layanan Chat Obrolan 1-on-1** | `frontend/lib/services/chat_service.dart` |
| **Model Kontrak Kerja Proyek** | `frontend/lib/models/job_contract.dart` |
| **Seeder Data Dummy Presentasi** | `backend/database/seeders/PresentationDemoSeeder.php` |
| **Tabel Ulasan Backend** | `backend/database/migrations/2026_08_10_094256_create_opportunity_reviews_table.php` |


