## Context

Sistem saat ini menggunakan ID berjenis *integer* dengan *auto-increment* untuk tabel pengguna (`users`), yang mana juga digunakan sebagai *foreign key* di beberapa tabel lainnya. Hal ini memunculkan kekhawatiran terkait keamanan ID prediksi (ID enumeration). Pada sisi autentikasi, API menyediakan beberapa endpoint login terpisah untuk *user*, *creator*, dan *admin* (`/api/auth/{role}/login`), padahal antarmuka pengguna (Frontend) hanya menggunakan satu layar login. Sistem juga mengembalikan data dalam jumlah besar pada beberapa panggilan API karena fungsi-fungsi belum dipisahkan rutenya secara modular.

## Goals / Non-Goals

**Goals:**
- Merombak arsitektur autentikasi API agar menggunakan satu rute tunggal `/api/auth/login`.
- Melakukan migrasi database (termasuk *foreign keys*) dari tipe `integer` menjadi `uuid` untuk ID pengguna.
- Memecah endpoint REST API menjadi rute-rute independen dan granular untuk operasi *get*, *post*, *put*, *patch*, *delete*, termasuk endpoint spesifik untuk mengambil daftar *role* atau *sub-role*.
- Menyesuaikan kode frontend (state management dan model) agar kompatibel dengan tipe `String` untuk ID dan perubahan skema routing.

**Non-Goals:**
- Perombakan total UI frontend di luar integrasi data API.
- Refactor kode di luar cakupan autentikasi, profil, dan pengelolaan peran (role).

## Decisions

- **Penggunaan UUID:** Kita akan menggunakan fungsi UUID standar bawaan Laravel (`Str::uuid()`) sebagai nilai dasar tabel `users`. Pembaruan *database migration* akan mencakup penyesuaian semua *foreign key* yang mengarah ke tabel `users` (seperti `wallet_transactions`, `creator_applications`, dsb) untuk menyesuaikan dengan tipe `uuid`.
- **Unified Login Endpoint:** Controller login akan dipusatkan pada `AuthController@login`. Logika pemisahan akan diatasi secara internal di dalam controller (berdasarkan data user), dan payload kembalian akan mengembalikan peran (role) sehingga Frontend cukup mengonsumsi satu API.
- **Microservices-style REST API Routing:** Setiap endpoint akan dikelompokkan berdasarkan entitas dengan mematuhi prinsip REST (seperti `Route::get('roles')`). Meminimalisir payload dengan cara memisahkan endpoint untuk pengambilan metadata dari endpoint untuk pengambilan data penuh (seperti profil lengkap).

## Risks / Trade-offs

- **Risiko Migrasi Database:** Mengubah tipe *primary key* pada tabel yang sudah terisi data sangat berisiko. 
  - *Mitigasi*: Menulis file migrasi baru yang secara hati-hati melakukan modifikasi kolom, melepaskan *foreign key constraint* terlebih dahulu, mengubah tipe data kolom `id`, memperbarui data eksisting (jika ada) ke format UUID yang sesuai, lalu memasang kembali *constraint*.
- **Risiko Kerusakan State Frontend:** Karena model `UserModel` di Flutter berubah secara drastis pada atribut ID (dari `int` ke `String`), ini dapat menyebabkan error *type mismatch*. 
  - *Mitigasi*: Penyesuaian `user_model.dart` dengan metode `fromJson` yang fleksibel atau secara eksplisit menguraikan ke bentuk `String`, serta mengosongkan cache login yang lama (`SharedPreferences`).
