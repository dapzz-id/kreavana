## Why

Sistem autentikasi Kreavana saat ini monolitik — satu `AuthController` menangani semua role (user, creator, admin) tanpa pemisahan akses yang jelas. Pengecekan role dilakukan secara manual di setiap controller (if `$user->role !== 'admin'`), tidak ada middleware role-based, dan tidak ada isolasi antara domain auth masing-masing role. Ini menyulitkan scaling, menambah risiko security, dan membuat kode sulit di-maintain seiring bertambahnya fitur per role.

Perubahan ini memisahkan modul autentikasi berdasarkan role menggunakan pendekatan microservice — setiap role (User, Creator, Admin) memiliki auth flow, guard, middleware, dan endpoint yang terisolasi.

## What Changes

- **Memisahkan auth endpoint per role** — Route auth dipisah menjadi `/api/auth/user`, `/api/auth/creator`, dan `/api/auth/admin` masing-masing dengan controller tersendiri.
- **Menambahkan role-based middleware** — Middleware `RoleMiddleware` yang memvalidasi role dari JWT claim, menggantikan pengecekan manual `if ($user->role !== 'admin')` di setiap controller.
- **Memperkaya JWT claims dengan role** — Method `getJWTCustomClaims()` di User model akan menyertakan `role` dan `permissions` sehingga middleware bisa validasi tanpa query DB.
- **Membuat guard terpisah per role** — Konfigurasi `auth.php` diperluas dengan guard `api-user`, `api-creator`, `api-admin` untuk isolasi auth domain.
- **Menambah permission system sederhana** — Mapping role → permissions yang mendefinisikan akses per fitur (manage_opportunities, manage_users, approve_applications, dll).
- **Menambah registration flow terpisah** — Admin hanya bisa dibuat via seeder/command, Creator melalui application approval, User melalui public registration.
- **Refactor existing controllers** — Menghapus pengecekan role manual dari `AdminController`, `DashboardController`, dll dan mengandalkan middleware.

## Capabilities

### New Capabilities
- `role-based-auth`: Sistem autentikasi terpisah per role (user/creator/admin) dengan dedicated controller, guard, dan middleware. Mencakup JWT custom claims, permission mapping, dan registration flow isolation.
- `role-middleware`: Middleware untuk validasi akses berdasarkan role dan permission dari JWT, menggantikan pengecekan manual di controller.

### Modified Capabilities
_Tidak ada spec yang sudah ada yang perlu dimodifikasi (folder `openspec/specs/` kosong)._

## Impact

- **Backend Routes** (`routes/api.php`): Restrukturisasi route auth dari flat ke nested per role. Route lain yang memerlukan proteksi role ditambahkan middleware.
- **Controllers**: `AuthController` dipecah menjadi `UserAuthController`, `CreatorAuthController`, `AdminAuthController`. `AdminController` direfactor menghapus cek role manual.
- **Models** (`User.php`): `getJWTCustomClaims()` diperkaya dengan role & permissions.
- **Config** (`config/auth.php`): Penambahan guard dan provider per role.
- **Middleware**: File middleware baru `RoleMiddleware.php` dan `PermissionMiddleware.php`.
- **Database**: Potensi migration baru untuk tabel `permissions` atau `role_permissions` jika permission disimpan di DB (alternatif: config-based).
- **Frontend (Flutter)**: `api_service.dart` perlu diupdate untuk endpoint auth baru. Token handling tetap compatible (JWT).
- **Breaking**: **BREAKING** — Endpoint `/api/auth/login` dan `/api/auth/register` akan deprecated, diganti dengan `/api/auth/user/login` dan `/api/auth/user/register`.
