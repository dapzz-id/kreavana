## MODIFIED Requirements

### Requirement: RoleMiddleware memvalidasi akses berdasarkan role
Sistem MUST memiliki `RoleMiddleware` yang memeriksa role user dari JWT custom claims, memvalidasi `jti` token terhadap Redis untuk mendukung real-time revocation, dan membandingkan role dengan role yang diizinkan pada route.

#### Scenario: User dengan role yang sesuai diizinkan
- **WHEN** user dengan JWT claim `role: "admin"` dan `jti` yang valid di Redis mengakses route yang dilindungi middleware `role:admin`
- **THEN** request diproses ke controller

#### Scenario: User dengan role yang tidak sesuai ditolak
- **WHEN** user dengan JWT claim `role: "user"` dan `jti` yang valid di Redis mengakses route yang dilindungi middleware `role:admin`
- **THEN** sistem mengembalikan 403 Forbidden dengan pesan generik

#### Scenario: Middleware menerima multiple roles
- **WHEN** route dilindungi middleware `role:admin,creator` dan user memiliki JWT claim `role: "creator"` serta `jti` yang valid di Redis
- **THEN** request diproses ke controller

#### Scenario: Token tanpa role claim ditolak
- **WHEN** user memiliki JWT token valid tapi tanpa claim `role` (legacy token)
- **THEN** sistem mengembalikan 401 Unauthorized dengan pesan generik

#### Scenario: Token dengan jti revoked ditolak
- **WHEN** user memiliki JWT token dengan signature valid tetapi `jti` sudah dicabut di Redis
- **THEN** sistem mengembalikan 401 Unauthorized dengan pesan generik sebelum memeriksa role

### Requirement: PermissionMiddleware memvalidasi akses berdasarkan permission
Sistem MUST memiliki `PermissionMiddleware` yang memeriksa permission spesifik dari JWT custom claims setelah token `jti` divalidasi terhadap Redis.

#### Scenario: User dengan permission yang sesuai diizinkan
- **WHEN** user dengan JWT claim `permissions: ["manage_applications", ...]` dan `jti` yang valid di Redis mengakses route yang dilindungi middleware `permission:manage_applications`
- **THEN** request diproses ke controller

#### Scenario: User tanpa permission yang diperlukan ditolak
- **WHEN** user dengan JWT claim `permissions: ["view_dashboard"]` dan `jti` yang valid di Redis mengakses route yang dilindungi middleware `permission:manage_applications`
- **THEN** sistem mengembalikan 403 Forbidden dengan pesan generik

#### Scenario: Multiple permissions required (AND logic)
- **WHEN** route dilindungi middleware `permission:manage_applications,manage_users` dan user hanya memiliki `manage_applications`
- **THEN** sistem mengembalikan 403 Forbidden karena tidak semua permission terpenuhi

#### Scenario: Token dengan jti revoked ditolak sebelum permission
- **WHEN** user memiliki JWT token dengan permission yang sesuai tetapi `jti` sudah dicabut di Redis
- **THEN** sistem mengembalikan 401 Unauthorized dengan pesan generik sebelum memeriksa permission
