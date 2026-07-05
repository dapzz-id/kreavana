## 1. Setup Database dan Enum

- [x] 1.1 Buat migration baru untuk menambahkan kolom `sub_role` dan menghapus kolom `selected_pihak` pada tabel `users`.
- [x] 1.2 Buat Enum class di Laravel untuk definisi `CreatorSubRole` (contoh: `pemerintah`, `event_organizer`, `wedding_organizer`).
- [x] 1.3 Perbarui model `User` agar mendukung kolom `sub_role` beserta *casting* ke Enum yang sesuai.

## 2. Implementasi Backend Profile & Sub-Role

- [x] 2.1 Buat endpoint khusus (`GET /api/roles/creator/sub-roles`) untuk mengembalikan daftar *sub-role* yang valid sesuai standar microservices/OWASP.
- [x] 2.2 Sesuaikan endpoint `/api/auth/me` agar tidak mengembalikan relasi data berat secara utuh, melainkan hanya profil utama dan *sub-role*.
- [x] 2.3 Buat atau sesuaikan endpoint khusus (misal: `/api/profile/history` atau sejenisnya) dengan fitur paginasi dan *filtering* (misal: berdasarkan `year=2026`).

## 3. Implementasi Frontend

- [x] 3.1 Perbarui logika autentikasi (state management) agar saat menerima respons login minimal, aplikasi langsung melakukan request ke `/api/auth/me` menggunakan `access_token` untuk mendapatkan data lengkap profil.
- [x] 3.2 Tambahkan field `sub_role` ke dalam model user di frontend (Dart/Flutter).
- [x] 3.3 Terapkan pemanggilan API secara paginasi dan filter tahun pada halaman yang membutuhkan riwayat profil yang panjang.

## 4. Pengujian & Verifikasi

- [x] 4.1 Uji endpoint baru untuk mengambil data `sub_role`.
- [x] 4.2 Uji endpoint profil yang dipisah untuk paginasi dan filter tahun memastikan respons lebih cepat.
- [x] 4.3 Jalankan *flow* login di frontend untuk memastikan aplikasi berjalan mulus meskipun payload autentikasi sangat minimal.
