# Mandatory Rules: Page Routing & Permission Guards (1 Page = 1 Dedicated Route & Strict RBAC)

Setiap pengembang maupun AI Assistant yang menambahkan, mengubah, atau memperbarui halaman/fitur pada repositori Kreavana **WAJIB MEMATUHI ATURAN BERIKUT DEMI KEAMANAN DAN KONSISTENSI UX**:

---

## 1. Satu Halaman = Satu Route Khusus (1 Page = 1 Dedicated URL Route)

1. **Setiap halaman/layanan utama WAJIB memiliki path route tersendiri**:
   - Daftarkan konstanta route di `AppRoutes` pada `frontend/lib/services/app_router.dart`.
   - Daftarkan `GoRoute` di dalam instance `appRouter`.
   - Nama route harus deskriptif, lowercase, dan menggunakan kebab-case (contoh: `/profil-institusi`, `/tim-hak-akses`, `/karya-siswa`, `/lowongan-corporate`, `/pengadaan-vendor`).

2. **Dilarang keras menggunakan anonymous `Navigator.push` atau `Navigator.pushReplacement` untuk membuka halaman utama**:
   - Jangan pernah membuka halaman utama tanpa memperbarui URL browser.
   - Gunakan selalu `context.go(AppRoutes.<namaRoute>)` atau metode routing GoRouter.
   - Dengan begitu, URL di address bar browser selalu sinkron dengan halaman yang sedang dilihat oleh pengguna, mendukung reload browser (F5), dan mendukung deep linking.

3. **Sinkronisasi Sidebar & State Navigasi**:
   - Navigasi melalui sidebar di `MainNavigation` maupun `DesktopSidebarLayout` wajib memanggil `context.go(AppRoutes.<namaRoute>)`.
   - Pertahankan posisi scroll sidebar saat berpindah route menggunakan `SidebarScrollManager.savedOffset`.
   - Pastikan state aktif (`isSelected`) pada sidebar mencerminkan route yang sedang dibuka.

---

## 2. Pengamanan Hak Akses & Permission Guard Ketat (Strict RBAC)

Demi keamanan data dan kepatuhan sistem, **TIDAK SEMUA PENGGUNA BISA MENGAKSES SEMUA ROUTE**. Setiap route wajib dilindungi melalui **Role-Based Access Control (RBAC)** berlapis:

1. **Route Guard Terpusat di `appRouter.redirect` (Primary Guard)**:
   - Sebelum widget halaman dibangun, fungsi `redirect` pada `appRouter` wajib memverifikasi permission pengguna.
   - **Tamu / Belum Login (Guest)**:
     - Hanya route di `_publicRoutes` (`/`, `/login`, `/register`, `/verify-email`, `/beranda`, `/explore`, `/peluang-proyek`, `/marketplace-karya`, `/ai`) yang boleh diakses.
     - Jika guest mencoba mengakses route terproteksi via address bar, wajib dialihkan (redirect) ke `AppRoutes.login`.
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
   - Jika pengguna tidak memenuhi kriteria izin, tampilkan tampilan akses ditolak (403 Access Denied) atau dialog peringatan resmi (`AppSweetAlert.error` / `AuthGuardDialog`).

---

## 3. Checklist untuk AI Saat Membuat Page Baru:

- [ ] Apakah konstanta route sudah ditambahkan ke `AppRoutes`?
- [ ] Apakah `GoRoute` sudah didaftarkan di `appRouter.routes`?
- [ ] Apakah aturan permission sudah ditambahkan ke fungsi `redirect:` di `appRouter`?
- [ ] Apakah navigasi dari sidebar atau tombol menggunakan `context.go(AppRoutes.<route>)`?
- [ ] Apakah URL address bar browser terupdate saat halaman dibuka?
- [ ] Apakah refresh browser (F5) pada URL tersebut tetap membuka halaman yang benar?
- [ ] Apakah user tanpa role/permission yang sesuai dicegah (redirect ke `/beranda` atau `/login`)?
