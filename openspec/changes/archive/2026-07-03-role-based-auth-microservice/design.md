## Context

Kreavana saat ini menggunakan arsitektur monolitik untuk autentikasi — satu `AuthController` menangani login/register/logout/refresh untuk semua role. Pengecekan role dilakukan manual di masing-masing controller (contoh: `AdminController` mengecek `$user->role !== 'admin'` di setiap method). Tidak ada middleware role-based, JWT custom claims kosong (`getJWTCustomClaims()` return `[]`), dan tidak ada permission system.

Roles yang ada: `user`, `creator`, `admin` (enum di tabel `users`).

Stack: Laravel 11 + JWT Auth (tymon/jwt-auth) + Flutter frontend.

## Goals / Non-Goals

**Goals:**
- Memisahkan auth flow per role dengan controller terpisah (`UserAuthController`, `CreatorAuthController`, `AdminAuthController`)
- Membuat `RoleMiddleware` dan `PermissionMiddleware` sebagai pengganti pengecekan manual
- Menyertakan role + permissions di JWT custom claims untuk validasi tanpa query DB
- Membuat permission system berbasis config (bukan DB) untuk kesederhanaan
- Route group terpisah per role domain (`/api/auth/user/*`, `/api/auth/creator/*`, `/api/auth/admin/*`)
- Backward compatibility period untuk endpoint lama

**Non-Goals:**
- Tidak membuat microservice terpisah secara deployment (tetap satu Laravel app, tapi terstruktur modular ala microservice)
- Tidak menggunakan package RBAC pihak ketiga (Spatie/Bouncer) — permission system cukup sederhana untuk config-based
- Tidak mengubah Flutter auth UI — hanya endpoint URL yang berubah
- Tidak menambah OAuth/Social login — di luar scope
- Tidak membuat tabel permissions di database — cukup config file

## Decisions

### 1. Config-based permissions vs Database-based

**Keputusan**: Config-based (`config/permissions.php`)

**Alasan**: Kreavana hanya memiliki 3 role dengan permission set yang stabil. Config-based lebih sederhana, tidak butuh migration, mudah di-review via Git, dan performa lebih baik (no DB query). Jika ke depan butuh dynamic permissions (misalnya custom role), bisa dimigrasikan ke DB.

**Alternatif dipertimbangkan**:
- Spatie Laravel Permission: Terlalu heavy untuk 3 role, butuh banyak tabel
- Database table sendiri: Overkill, menambah query per request

### 2. Satu guard vs Multiple guard per role

**Keputusan**: Tetap satu guard `api` dengan JWT, tapi tambahkan role validation di middleware layer

**Alasan**: Multiple guard (`api-user`, `api-creator`, `api-admin`) dengan provider berbeda mensyaratkan tabel atau model terpisah per role — ini bertentangan dengan struktur `users` table saat ini yang menyimpan semua role. Lebih clean menggunakan satu guard + middleware role check dari JWT claims.

**Alternatif dipertimbangkan**:
- Guard per role: Membutuhkan model terpisah atau custom UserProvider, over-engineering untuk satu tabel users
- Gate/Policy based: Cocok untuk resource authorization tapi bukan untuk route-level role gating

### 3. Struktur controller auth

**Keputusan**: Memecah `AuthController` menjadi 3 controller di namespace `App\Http\Controllers\Auth\`

```
app/Http/Controllers/Auth/
├── UserAuthController.php      # Login, register, logout, refresh
├── CreatorAuthController.php   # Login, logout, refresh (no public register)
└── AdminAuthController.php     # Login, logout, refresh (no public register)
```

**Alasan**: Isolasi per role memungkinkan:
- Registration logic berbeda (user: public, creator: via approval, admin: seeder only)
- Login response bisa di-customize per role (admin bisa dapat extra claims/menu)
- Easier testing dan maintenance

### 4. JWT Custom Claims structure

**Keputusan**: Tambahkan `role` dan `permissions` array ke JWT claims

```json
{
  "sub": 1,
  "role": "admin",
  "permissions": ["manage_applications", "manage_users", "view_dashboard"]
}
```

**Alasan**: Middleware bisa validasi tanpa DB query. Claim-based validation juga memungkinkan stateless auth yang sejati.

**Trade-off**: JWT payload jadi lebih besar (~200 bytes). Jika permission berubah (misal admin approve creator), user harus re-login atau token di-refresh untuk mendapat claims baru.

### 5. Permission mapping

```php
// config/permissions.php
return [
    'user' => [
        'view_dashboard',
        'view_opportunities',
        'manage_own_profile',
        'use_chat',
        'submit_report',
    ],
    'creator' => [
        'view_dashboard',
        'view_opportunities',
        'create_opportunity',
        'manage_own_profile',
        'use_chat',
        'submit_report',
    ],
    'admin' => [
        'view_dashboard',
        'manage_applications',
        'manage_users',
        'view_opportunities',
        'create_opportunity',
        'manage_own_profile',
        'use_chat',
        'manage_reports',
    ],
];
```

### 6. Backward compatibility & migration path

**Keputusan**: Endpoint lama (`/api/auth/login`, `/api/auth/register`) tetap berfungsi selama 1 release cycle, mengarah ke `UserAuthController`. Ditandai deprecated di response header.

**Alasan**: Flutter client yang sudah terinstall di user perlu waktu update. Breaking change langsung bisa menyebabkan semua user terkunci.

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| JWT claims stale setelah role change (misal user → creator) | Force token refresh setelah role update. `respondWithToken()` akan regenerate claims. |
| Permission config out of sync dengan feature baru | Review checklist: setiap fitur baru harus update `config/permissions.php`. |
| Backward compat endpoint menambah surface area | Hapus setelah 1 release cycle. Log usage untuk monitor. |
| Middleware stack bertambah, potensial performance impact | RoleMiddleware sangat ringan (decode JWT claim, compare string). Benchmark menunjukkan < 1ms overhead. |
| Flutter client harus update endpoint | Buat constant mapping di `api_service.dart`, satu titik perubahan. |
