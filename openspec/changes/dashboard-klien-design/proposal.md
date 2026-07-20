## Why

Kreavana membutuhkan halaman dashboard klien yang menampilkan ringkasan aktivitas, metrik utama, dan akses cepat ke fungsi proyek agar pengguna dapat melihat status proyek, vendor favorit, dan rekomendasi secara langsung.

## What Changes

- Tambahkan tampilan dashboard klien baru yang menampilkan metrik proyek, ringkasan aktivitas, dan rekomendasi vendor.
- Tambahkan panel berbeda untuk berbagai tipe pengguna klien: Klien umum, instansi, komunitas, dan penyelenggara event.
- Buat layout yang menyerupai konten Google Drive/drive-like interface dengan kartu proyek, daftar aktivitas, grafik ringkasan, dan navigasi samping.
- Tambahkan fitur daftar klien identitas/jenis klien di area yang sesuai seperti pada gambar klien ke-9.

## Capabilities

### New Capabilities
- `client-dashboard`: Dashboard klien dengan ringkasan metrik, aktivitas terbaru, rekomendasi vendor, dan tampilan grafik.
- `client-profile-summary`: Panel profil singkat klien dengan status proyek, reputasi, dan tombol tindakan cepat.
- `client-activity-feed`: Daftar aktivitas terbaru dan event/proyek terkait untuk klien.
- `client-vendor-recommendations`: Rekomendasi vendor/kreator favorit dengan informasi rating dan status.
- `client-status-summary`: Panel ringkasan status proyek dan anggaran yang menampilkan metrik seperti Proyek Aktif, Total Pembayaran, dan Pending Pembayaran.

### Modified Capabilities
- `none`: Tidak ada perubahan spesifik pada kemampuan existing yang memerlukan delta spec.

## Impact

- Backend route/API untuk menampilkan data dashboard klien dan ringkasan proyek.
- Frontend UI/UX untuk halaman dashboard dashboard klien dan komponen kartu metrik.
- Database query untuk mengambil data proyek, vendor favorit, aktivitas terbaru, dan profil klien.
- Dependencies: komponen chart, tabel, dan styling UI dashboard di frontend.
