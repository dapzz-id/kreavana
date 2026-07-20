## 1. Backend Dashboard API

- [x] 1.1 Tambahkan endpoint API `GET /api/client-dashboard/overview` di backend.
- [x] 1.2 Perbarui `DashboardController` dan `DashboardService` untuk mengumpulkan ringkasan metrik, status pembayaran, aktivitas terbaru, rekomendasi vendor, dan daftar tipe klien.
- [x] 1.3 Tambahkan query/repository method untuk mengambil data proyek aktif, total pembayaran, pending payment, dan rekomendasi vendor favorit.
- [x] 1.4 Pastikan API mengembalikan payload terstruktur yang dapat di-render langsung oleh frontend.

## 2. Frontend Client Dashboard UI

- [x] 2.1 Buat screen/dashboard baru untuk klien yang memuat data dari `client-dashboard/overview`.
- [x] 2.2 Tambahkan panel daftar tipe klien dengan nama-nama klien sesuai referensi (Umum, UMKM/Perusahaan, EO, WO, Sekolah/Perguruan Tinggi, Desa Wisata, Individu/Keluarga, Pemerintah/Instansi, Komunitas).
- [x] 2.3 Tambahkan kartu ringkasan metrik utama: total proyek, proyek aktif, total pembayaran, pending pembayaran, dan favorit.
- [x] 2.4 Tambahkan komponen profile summary, activity feed, rekomendasi vendor, dan grafik ringkasan.
- [x] 2.5 Pastikan tampilan dashboard mengikuti gaya kartu, spacing, dan visual hierarki seperti pada screenshot referensi.

## 3. Data, Tests, and Verification

- [x] 3.1 Siapkan mock data atau sample fixtures untuk tipe klien dan data dashboard saat pengujian.
- [x] 3.2 Tambahkan atau perbarui unit/integration test backend untuk memastikan endpoint mengembalikan struktur yang benar.
- [x] 3.3 Verifikasi tampilan frontend dengan data nyata / mock untuk memastikan informasi klien dan daftar tipe tampil dengan benar.
