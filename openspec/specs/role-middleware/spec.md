# Purpose
TBD

## Requirements


### Requirement: RoleMiddleware memvalidasi akses berdasarkan role
Sistem HARUS memiliki `RoleMiddleware` yang memeriksa role user dari JWT custom claims dan membandingkan dengan role yang diizinkan pada route.

#### Scenario: User dengan role yang sesuai diizinkan
- **WHEN** user dengan JWT claim `role: "admin"` mengakses route yang dilindungi middleware `role:admin`
- **THEN** request diproses ke controller

#### Scenario: User dengan role yang tidak sesuai ditolak
- **WHEN** user dengan JWT claim `role: "user"` mengakses route yang dilindungi middleware `role:admin`
- **THEN** sistem mengembalikan 403 Forbidden dengan pesan "Anda tidak memiliki akses untuk halaman ini"

#### Scenario: Middleware menerima multiple roles
- **WHEN** route dilindungi middleware `role:admin,creator` dan user memiliki JWT claim `role: "creator"`
- **THEN** request diproses ke controller

#### Scenario: Token tanpa role claim ditolak
- **WHEN** user memiliki JWT token valid tapi tanpa claim `role` (legacy token)
- **THEN** sistem mengembalikan 401 Unauthorized dengan pesan "Token tidak valid, silakan login ulang"

### Requirement: PermissionMiddleware memvalidasi akses berdasarkan permission
Sistem HARUS memiliki `PermissionMiddleware` yang memeriksa permission spesifik dari JWT custom claims.

#### Scenario: User dengan permission yang sesuai diizinkan
- **WHEN** user dengan JWT claim `permissions: ["manage_applications", ...]` mengakses route yang dilindungi middleware `permission:manage_applications`
- **THEN** request diproses ke controller

#### Scenario: User tanpa permission yang diperlukan ditolak
- **WHEN** user dengan JWT claim `permissions: ["view_dashboard"]` mengakses route yang dilindungi middleware `permission:manage_applications`
- **THEN** sistem mengembalikan 403 Forbidden dengan pesan "Anda tidak memiliki permission untuk aksi ini"

#### Scenario: Multiple permissions required (AND logic)
- **WHEN** route dilindungi middleware `permission:manage_applications,manage_users` dan user hanya memiliki `manage_applications`
- **THEN** sistem mengembalikan 403 Forbidden karena tidak semua permission terpenuhi

### Requirement: Config-based permission mapping
Permission per role HARUS didefinisikan di file konfigurasi `config/permissions.php` dan dapat diakses via `config('permissions.<role>')`.

#### Scenario: Mengambil permissions untuk role user
- **WHEN** sistem membutuhkan daftar permissions untuk role `user`
- **THEN** `config('permissions.user')` mengembalikan array permissions yang sesuai

#### Scenario: Role tidak dikenal mengembalikan array kosong
- **WHEN** sistem meminta permissions untuk role yang tidak ada di config
- **THEN** sistem mengembalikan array kosong `[]`

### Requirement: Middleware menggantikan pengecekan manual di controller
Semua pengecekan role manual (`if ($user->role !== 'admin')`) di controller HARUS dihapus dan diganti dengan middleware pada route definition.

#### Scenario: AdminController tidak lagi mengecek role secara manual
- **WHEN** request masuk ke route admin yang dilindungi middleware `role:admin`
- **THEN** `AdminController` method langsung memproses business logic tanpa pengecekan `$user->role`

#### Scenario: Route admin dilindungi di level routing
- **WHEN** route `/api/admin/*` didefinisikan di `routes/api.php`
- **THEN** route group tersebut HARUS memiliki middleware `role:admin` yang terpasang

### Requirement: Middleware terdaftar di aplikasi
`RoleMiddleware` dan `PermissionMiddleware` HARUS terdaftar sebagai route middleware alias di `bootstrap/app.php` atau service provider.

#### Scenario: Middleware dapat digunakan dengan alias
- **WHEN** developer menulis `->middleware('role:admin')` di route definition
- **THEN** Laravel mengenali alias `role` dan menjalankan `RoleMiddleware`

#### Scenario: Middleware permission dapat digunakan dengan alias
- **WHEN** developer menulis `->middleware('permission:manage_applications')` di route definition
- **THEN** Laravel mengenali alias `permission` dan menjalankan `PermissionMiddleware`
