## 1. Permission Config & Foundation

- [x] 1.1 Buat file `config/permissions.php` dengan mapping role → permissions (user, creator, admin)
- [x] 1.2 Update `User.php` model — method `getJWTCustomClaims()` mengembalikan `role` dan `permissions` dari config

## 2. Middleware

- [x] 2.1 Buat `app/Http/Middleware/RoleMiddleware.php` — validasi role dari JWT claims, support multiple roles (comma-separated)
- [x] 2.2 Buat `app/Http/Middleware/PermissionMiddleware.php` — validasi permission dari JWT claims, AND logic untuk multiple permissions
- [x] 2.3 Daftarkan kedua middleware sebagai alias (`role`, `permission`) di `bootstrap/app.php`

## 3. Auth Controllers per Role

- [x] 3.1 Buat `app/Http/Controllers/Auth/UserAuthController.php` — login, register, logout, refresh untuk role user. Inherit logic dari `AuthController` yang sudah ada.
- [x] 3.2 Buat `app/Http/Controllers/Auth/CreatorAuthController.php` — login, logout, refresh. Login memvalidasi `role === 'creator'`. Tidak ada endpoint register.
- [x] 3.3 Buat `app/Http/Controllers/Auth/AdminAuthController.php` — login, logout, refresh. Login memvalidasi `role === 'admin'`. Tidak ada endpoint register.
- [x] 3.4 Buat trait `app/Http/Controllers/Auth/AuthResponder.php` — extract shared `respondWithToken()` dan `refresh()` logic ke trait yang dipakai ketiga controller

## 4. Route Restructuring

- [x] 4.1 Tambahkan route group baru di `routes/api.php` untuk `/api/auth/user/*`, `/api/auth/creator/*`, `/api/auth/admin/*`
- [x] 4.2 Pertahankan endpoint lama (`/api/auth/login`, `/api/auth/register`) yang mengarah ke `UserAuthController` dengan deprecated header
- [x] 4.3 Tambahkan middleware `role:admin` pada route group `/api/admin/*`
- [x] 4.4 Review dan tambahkan middleware role/permission pada route group lain yang memerlukan (opportunities, dashboard stats, dll)

## 5. Refactor Existing Controllers

- [x] 5.1 Hapus pengecekan role manual dari `AdminController.php` (`if ($user->role !== 'admin')`) — sudah ditangani middleware
- [x] 5.2 Review `DashboardController.php` dan controller lain untuk pengecekan role manual, ganti dengan middleware

## 6. Testing & Verification

- [x] 6.1 Test login via `/api/auth/user/login` — pastikan JWT mengandung role & permissions claims
- [x] 6.2 Test login via `/api/auth/creator/login` — pastikan non-creator ditolak 403
- [x] 6.3 Test login via `/api/auth/admin/login` — pastikan non-admin ditolak 403
- [x] 6.4 Test middleware role — akses route admin dengan token user, pastikan 403
- [x] 6.5 Test middleware permission — akses route dengan permission yang tidak dimiliki, pastikan 403
- [x] 6.6 Test backward compat — login via `/api/auth/login` lama, pastikan tetap berfungsi dengan deprecation header
- [x] 6.7 Test token refresh — pastikan claims diperbarui sesuai role terkini dari DB
