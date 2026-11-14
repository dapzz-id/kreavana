# Mandatory Rules: Page Routing & Permission Guards (1 Page = 1 Dedicated Route & Strict RBAC)

Setiap pengembang maupun AI Assistant yang menambahkan, mengubah, atau memperbarui halaman/fitur pada repositori Kreavana **WAJIB MEMATUHI ATURAN BERIKUT DEMI KEAMANAN DAN KONSISTENSI UX**:

---

## 1. Satu Halaman = Satu Route Khusus (1 Page = 1 Dedicated URL Route)

1. **Setiap Halaman, Sub-Page, Detail, & Form Edit WAJIB Memiliki Path Route Tersendiri**:
   - Daftarkan konstanta route di `AppRoutes` pada `frontend/lib/services/app_router.dart`.
   - Daftarkan `GoRoute` di dalam instance `appRouter`.
   - Nama route harus deskriptif, lowercase, dan menggunakan kebab-case (contoh: `/profil-institusi`, `/proyek/:id`, `/marketplace-karya/:id`, `/jual-karya`, `/wallet/topup`, `/wallet/withdraw`, `/verifikasi-klien`, `/daftar-kreator`).
   - Tidak boleh ada halaman atau sub-halaman penuh yang "tersembunyi" di balik satu URL umum tanpa sinkronisasi address bar browser.

2. **Dilarang Keras Menggunakan Anonymous `Navigator.push` / `pushReplacement` Tanpa Route Terdaftar**:
   - Jangan pernah membuka halaman atau aksi penuh tanpa memperbarui URL browser.
   - Gunakan selalu `context.go(AppRoutes.<namaRoute>)` atau `context.push(AppRoutes.<namaRoute>)`.
   - Dengan begitu, URL di address bar browser selalu sinkron dengan halaman yang sedang dilihat oleh pengguna, mendukung reload browser (F5), dan mendukung deep linking langsung.

3. **Sinkronisasi Sidebar & State Navigasi**:
   - Navigasi melalui sidebar di `MainNavigation` maupun `DesktopSidebarLayout` wajib memanggil `context.go(AppRoutes.<namaRoute>)`.
   - Pertahankan posisi scroll sidebar saat berpindah route menggunakan `SidebarScrollManager.savedOffset`.
   - Pastikan state aktif (`isSelected`) pada sidebar mencerminkan route yang sedang dibuka secara akurat.

---

## 2. Pengamanan Hak Akses & Permission Guard Ketat (Strict RBAC)

Demi keamanan data dan kepatuhan sistem, **TIDAK SEMUA PENGGUNA BISA MENGAKSES SEMUA ROUTE**. Setiap route wajib dilindungi melalui **Role-Based Access Control (RBAC)** berlapis:

1. **Route Guard Terpusat di `appRouter.redirect` (Primary Guard)**:
   - Sebelum widget halaman dibangun, fungsi `redirect` pada `appRouter` wajib memverifikasi permission pengguna.
   - **Tamu / Belum Login (Guest)**:
     - Hanya route di `_publicRoutes` (`/`, `/login`, `/register`, `/verify-email`, `/beranda`, `/explore`, `/peluang-proyek`, `/marketplace-karya`, `/ai`, `/404`, `/bantuan`, `/kebijakan-privasi`) yang boleh diakses.
     - Jika guest mencoba mengakses route terproteksi via address bar, wajib dialihkan (redirect) ke `AppRoutes.login`.
   - **Fitur Jelajahi (Explore) & Peluang Proyek**:
     - Route `/explore` dan `/peluang-proyek` **DILARANG KERAS** untuk akun **Institusi Pendidikan** (`user.isInstitution`) dan **Corporate / Perusahaan** (`user.isCorporate`).
     - Jika peran tersebut mencoba mengakses via address bar atau tautan, sistem wajib mengarahkan ke `AppRoutes.notFound` (404 / 403 Akses Dibatasi).
   - **Akun Administrator**:
     - Route admin (`/dashboard`, `/verifikasi`, `/resolusi`, `/admin-settings`) HANYA boleh diakses jika `user.isAdmin == true`. Pengguna non-admin yang mencoba mengakses wajib dialihkan ke `AppRoutes.beranda`.
   - **Akun Institusi Pendidikan / Sekolah**:
     - Route seperti `/profil-institusi` dan `/karya-siswa` dikhususkan untuk `user.isInstitution` atau `user.isAdmin`. Pengguna lain dialihkan ke `/beranda` atau `/profil`.
     - Route `/pengadaan-vendor` **DILARANG KERAS** untuk institusi pendidikan/sekolah (fitur ini khusus corporate/pemerintah). Institusi yang mencoba mengakses wajib dialihkan ke `AppRoutes.beranda`.
   - **Akun Corporate / Perusahaan**:
     - Route `/lowongan-corporate` dikhususkan untuk `user.isCorporate` atau `user.isAdmin`.
     - Route `/pengadaan-vendor` dikhususkan untuk `user.isCorporate`, `user.isGovernment`, atau `user.isAdmin`.
   - **Ruang Kerja Organisasi / Governance**:
     - Route `/tim-hak-akses`, `/dokumen-institusi`, `/pengumuman-institusi`, `/monitoring-evaluasi`, `/laporan-kegiatan`, `/mitra-industri`, `/realisasi-anggaran` hanya boleh diakses oleh pengguna organisasi resmi (`user.isInstitution || user.isCorporate || user.isGovernment || user.isAdmin`).

2. **Defense-in-Depth di Tingkat Widget (Secondary Guard)**:
   - Setiap widget halaman atau layout tetap wajib memvalidasi role pengguna.
   - Jika pengguna tidak memenuhi kriteria izin atau tab tertentu dipicu secara tidak sengaja, widget wajib merender `NotFoundScreen` dengan kode 404/403 atau menampilkan dialog peringatan resmi (`AppSweetAlert.error` / `AuthGuardDialog`).
   - `GoRouter` wajib memiliki `errorBuilder` yang merender `NotFoundScreen` untuk setiap route yang tidak terdaftar.

---

## 3. Checklist untuk AI Saat Membuat atau Mengubah Halaman:

- [ ] Apakah konstanta route sudah ditambahkan ke `AppRoutes`?
- [ ] Apakah `GoRoute` sudah didaftarkan di `appRouter.routes`?
- [ ] Apakah aturan permission sudah ditambahkan ke fungsi `redirect:` di `appRouter`?
- [ ] Apakah role yang tidak memiliki fitur tersebut dicegah mengaksesnya (redirect ke `/404` atau `/beranda`)?
- [ ] Apakah navigasi dari sidebar atau tombol menggunakan `context.go` atau `context.push` dengan konstanta route resmi?
- [ ] Apakah URL address bar browser terupdate saat halaman/sub-page dibuka?
- [ ] Apakah reload browser (F5) pada URL tersebut tetap membuka halaman yang benar dan mampu memuat data via deep link?
- [ ] Apakah `NotFoundScreen` tampil jika route tidak ada atau akses dilarang?
