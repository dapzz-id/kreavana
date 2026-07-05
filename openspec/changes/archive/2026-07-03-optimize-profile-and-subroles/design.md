## Context

Aplikasi Kreavana telah beralih menggunakan pola arsitektur berbasis microservices untuk autentikasi dan otorisasi. Namun, saat ini frontend belum sepenuhnya menangani payload minimal dari endpoint autentikasi, dan endpoint profil (`/api/auth/me`) masih memuat seluruh data yang cukup besar tanpa adanya batasan, filter, ataupun paginasi. Selain itu, *role* kreator memerlukan pengategorian lebih dalam (*sub-role*) seperti pemerintah, *event organizer*, atau *wedding organizer* untuk memberikan akses spesifik (OWASP) namun belum memiliki struktur database atau API yang terpisah.

## Goals / Non-Goals

**Goals:**
- Menyesuaikan *state management* profil pengguna di frontend agar dapat menggunakan token untuk meminta data detail.
- Menerapkan paginasi dan filter tahun pada endpoint pengambilan data profil (seperti transaksi atau history terkait user).
- Memecah rute yang berhubungan dengan *role* menjadi lebih terperinci (rute khusus untuk *get role*, token, dan *sub-role*).
- Menambahkan kolom enum `sub_role` di database dan fitur pengelolaannya secara dinamis dan menghapus kolom `selected_pihak` di database `users`.

**Non-Goals:**
- Mendesain ulang seluruh struktur UI di frontend (perubahan hanya pada logika pengambilan data).
- Migrasi database skala besar di luar tabel `users` (atau tabel terkait profil).

## Decisions

1. **Frontend Data Fetching:**
   Alih-alih bergantung pada payload saat login, *state management* (seperti Provider/Riverpod) akan langsung memanggil endpoint `/api/auth/me` dengan menyertakan bearer token untuk mengambil seluruh informasi profil dan *sub-role*.
2. **Backend Pagination & Filtering:**
   Rute profil atau resource yang berat akan mengadopsi fitur paginasi Laravel (`->paginate(15)`) serta fitur filtering melalui *query params* (`?year=2026`).
3. **Database Schema:**
   Kolom `sub_role` akan ditambahkan pada tabel `users`. Untuk fleksibilitas, enum bisa dibuat di level *database* atau cukup di level *application logic/validasi* (string biasa dengan aturan validasi di backend). Kita akan menggunakan validasi Enum di Laravel.

## Risks / Trade-offs

- [Risk] Panggilan API yang bertambah (login + get profile) akan meningkatkan latensi awal saat login.
  → **Mitigation:** Frontend akan menggunakan *loading screen/splash* yang efisien, dan data profil minimal akan disajikan terlebih dahulu.
- [Risk] Filter dan paginasi membutuhkan indeks tambahan di database.
  → **Mitigation:** Database *migration* akan menambahkan indeks pada kolom `created_at` (untuk filter tahun) atau relasi kunci lainnya.
