## Context

Kreavana membutuhkan halaman dashboard klien yang menampilkan ringkasan aktivitas, metrik utama, rekomendasi vendor, dan daftar tipe klien seperti pada layar referensi. Perubahan ini akan menambahkan tampilan dashboard klien khusus yang menyesuaikan informasi berdasarkan jenis klien: Klien umum, UMKM/Perusahaan, Event Organizer, Wedding Organizer, Sekolah/Perguruan Tinggi, Desa Wisata, Individu/Keluarga, Pemerintah/Instansi, dan Komunitas.

Dashboard ini harus dirancang agar mudah dibaca, dengan kartu metrik utama, grafik ringkasan, panel aktivitas terbaru, rekomendasi vendor, dan panel profil klien.

## Goals / Non-Goals

**Goals:**
- Hadirkan halaman dashboard klien baru yang menampilkan metrik proyek, status pembayaran, dan aktivitas terbaru.
- Tampilkan daftar tipe klien / nama klien di area sesuai referensi layar, sehingga pengguna dapat melihat kategori klien dengan cepat.
- Sajikan rekomendasi vendor favorit dan ringkasan profil klien dengan kemudahan navigasi.
- Gunakan pola UI kartu, grafik, dan daftar yang konsisten dengan antarmuka Kreavana yang ada.

**Non-Goals:**
- Tidak melakukan refactor besar pada sistem otentikasi, role, atau permission yang sudah ada.
- Tidak membahas pembuatan modul klien baru yang rumit di backend; fokus pada endpoint dashboard dan agregasi data yang ada.
- Tidak mengganti seluruh dashboard admin atau creator yang sudah ada.

## Decisions

- **Gunakan API dashboard terpusat**: Memperluas layanan dashboard backend yang sudah ada untuk menyediakan ringkasan pelanggan, alih-alih membuat service baru yang terpisah. Hal ini meminimalkan duplikasi dan menjaga konsistensi metrik.
- **Panel tipe klien hard-coded dari UI referensi**: Karena screenshot menyajikan nama-nama tipe klien tertentu, dashboard akan menampilkan daftar tipe klien yang diperkenalkan secara eksplisit di UI. Sistem harus tetap dapat menambahkan tipe baru di masa depan, tetapi implementasi awal akan fokus pada daftar yang disebutkan.
- **Reuse komponen chart dan card depan**: Frontend akan menggunakan kembali pola tampilan kartu statistik dan grafik yang ada dalam `dashboard_screen.dart` serta menambahkan komponen baru untuk `client-profile-summary`, `client-activity-feed`, dan `client-vendor-recommendations`.
- **Single overview endpoint**: Backend akan menyediakan satu endpoint `GET /api/client-dashboard/overview` yang mengembalikan ringkasan metrik, daftar aktivitas, rekomendasi vendor, dan daftar tipe klien sebagai payload tunggal. Ini memudahkan frontend untuk memuat data sekali dan mengurangi jumlah permintaan.

## Risks / Trade-offs

- [Data Volume] → Agregasi activity feed dan vendor favorit bisa menghasilkan payload besar. Mitigasi: batasi hasil ke 5-7 item terbaru dan hanya kirim ringkasan yang diperlukan.
- [UI Complexity] → Menyajikan banyak blok informasi dalam satu layar dapat membuat layout padat. Mitigasi: gunakan card grouped dan scroll vertikal yang jelas, serta prioritas informasi di atas.
- [Client Type Mapping] → Jika tipe klien berubah atau tidak seragam, nama hard-coded bisa menjadi tidak akurat. Mitigasi: simpan daftar tipe di frontend dengan fallback ke label yang disediakan backend jika tersedia.
- [Cross-role reuse] → Menggunakan API dashboard umum bisa memengaruhi creator/admin jika tidak diisolasi. Mitigasi: pastikan endpoint dan response hanya untuk klien dan tidak mengubah skema dashboard existing.

## Migration Plan

1. Tambahkan endpoint `client-dashboard/overview` di backend, gunakan layanan dashboard yang ada.
2. Tambahkan query untuk statistik proyek, pembayaran, aktivitas terbaru, vendor favorit, dan tipe klien yang diperlukan.
3. Implementasikan frontend screen baru dan komponen kartu yang ditampilkan sesuai desain referensi.
4. Verifikasi data dari API ditampilkan dengan benar di semua tipe klien.
5. Lakukan QA tampilan untuk memastikan layout responsif dan sesuai yang ditunjukkan pada gambar.

## Open Questions

- Apakah daftar tipe klien pada gambar referensi bersifat statis atau harus ditentukan berdasarkan konfigurasi data pengguna?
- Detail data mana yang harus diprioritaskan untuk setiap tipe klien yang berbeda, seperti nilai proyek untuk instansi versus event organizer?
- Perlukah fitur filter aktif berdasarkan tipe klien di dashboard atau hanya tampilan ringkas statik?
