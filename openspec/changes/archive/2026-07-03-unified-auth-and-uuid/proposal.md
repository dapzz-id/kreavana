## Why

Saat ini backend memisahkan endpoint login untuk setiap peran (user, creator, admin) meskipun di frontend hanya ada satu portal login. Hal ini menambah kompleksitas. Selain itu, *primary key* untuk pengguna masih menggunakan *auto-increment* (`id`), yang kurang aman dan kurang *scalable* dibandingkan UUID. Terakhir, struktur rute API belum sepenuhnya dipisahkan secara granular untuk setiap operasi CRUD (REST) maupun pengambilan meta-data spesifik (seperti *get role*), sehingga bisa menyebabkan pemborosan *bandwidth* jika payload memuat terlalu banyak informasi.

## What Changes

- **BREAKING**: Menyatukan rute autentikasi dari `/api/auth/{role}/login` menjadi satu endpoint terpadu `/api/auth/login`. Endpoint ini akan mengidentifikasi peran (role) berdasarkan data pengguna dan mengembalikannya dalam *response*.
- **BREAKING**: Mengubah *primary key* pada tabel `users` (dan seluruh foreign key yang terkait di tabel lain) dari `id` (integer) menjadi `uid` (UUID).
- Memisahkan rute API secara granular. Setiap sumber daya akan memiliki rute mandiri untuk GET, POST, PUT, PATCH, dan DELETE, termasuk endpoint khusus untuk mengambil profil minimalis atau peran (misal: `/api/roles`).
- Menyesuaikan implementasi frontend (Flutter/Dart) agar mendukung rute login terpadu, penggunaan tipe data string/UUID untuk ID pengguna, serta modularisasi pemanggilan API.

## Capabilities

### New Capabilities
- `unified-auth`: Endpoint autentikasi satu pintu (single portal login) untuk semua jenis peran pengguna.
- `rest-api-granularity`: Desain rute modular untuk seluruh resource (GET, POST, PUT, PATCH, DELETE terpisah sesuai entitas) guna mengoptimalkan *bandwidth*.

### Modified Capabilities
- `auth-response-optimization`: Penyesuaian response autentikasi untuk mengakomodasi penggabungan login tanpa memuat profil lengkap, melainkan mengembalikan informasi *role* dan UID dasar.

## Impact

- **Database**: Semua tabel yang memiliki relasi `user_id` perlu diubah struktur datanya (migration dari int ke UUID). Hal ini mencakup `wallet_transactions`, `creator_applications`, dsb.
- **Backend API**: Controller autentikasi (AuthControllers) akan dilebur atau disederhanakan. Rute di `api.php` dirombak.
- **Frontend**: Perubahan model `UserModel` (mengubah tipe data ID ke `String`), serta penyesuaian pada `AuthService` dan halaman login.
