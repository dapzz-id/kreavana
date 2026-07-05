## MODIFIED Requirements

### Requirement: Role-separated auth controllers
Sistem MUST memiliki controller autentikasi terpisah untuk setiap role: `UserAuthController`, `CreatorAuthController`, dan `AdminAuthController`, masing-masing di namespace `App\Http\Controllers\Auth\`, dan setiap controller MUST mengikuti kontrak secure token lifecycle untuk access token JSON dan refresh token cookie-only.

#### Scenario: User login via dedicated endpoint
- **WHEN** user mengirim POST ke `/api/auth/user/login` dengan email dan password valid
- **THEN** sistem mengembalikan JWT access token dalam JSON, mengirim refresh token melalui secure cookie, dan tidak mengembalikan refresh token atau session token dalam response body

#### Scenario: Creator login via dedicated endpoint
- **WHEN** creator mengirim POST ke `/api/auth/creator/login` dengan email dan password valid
- **THEN** sistem memvalidasi bahwa user memiliki role `creator`, mengembalikan JWT access token dengan claims role `creator` beserta permissions yang sesuai, dan mengirim refresh token melalui secure cookie

#### Scenario: Creator login ditolak untuk non-creator
- **WHEN** user dengan role `user` mencoba login via `/api/auth/creator/login`
- **THEN** sistem mengembalikan 403 Forbidden dengan pesan generik yang tidak membocorkan keberadaan akun atau detail role internal

#### Scenario: Admin login via dedicated endpoint
- **WHEN** admin mengirim POST ke `/api/auth/admin/login` dengan email dan password valid
- **THEN** sistem memvalidasi bahwa user memiliki role `admin`, mengembalikan JWT access token dengan claims role `admin` beserta permissions yang sesuai, dan mengirim refresh token melalui secure cookie

#### Scenario: Admin login ditolak untuk non-admin
- **WHEN** user tanpa role `admin` mencoba login via `/api/auth/admin/login`
- **THEN** sistem mengembalikan 403 Forbidden dengan pesan generik yang tidak membocorkan keberadaan akun atau detail role internal

### Requirement: JWT custom claims mengandung role dan permissions
Setiap JWT token yang dihasilkan MUST menyertakan `role`, `permissions`, `sub`, dan `jti` di claims. JWT token MUST NOT menyertakan PII atau data sensitif.

#### Scenario: JWT claims untuk user role
- **WHEN** user dengan role `user` berhasil login
- **THEN** JWT token mengandung claim `sub`, `role: "user"`, `permissions` array sesuai konfigurasi role user, dan `jti`

#### Scenario: JWT claims untuk creator role
- **WHEN** user dengan role `creator` berhasil login
- **THEN** JWT token mengandung claim `sub`, `role: "creator"`, `permissions` array sesuai konfigurasi role creator, dan `jti`

#### Scenario: JWT claims untuk admin role
- **WHEN** user dengan role `admin` berhasil login
- **THEN** JWT token mengandung claim `sub`, `role: "admin"`, `permissions` array sesuai konfigurasi role admin, dan `jti`

#### Scenario: JWT claims tidak mengandung PII
- **WHEN** sistem menerbitkan JWT token untuk role apa pun
- **THEN** JWT token tidak mengandung email, name, username, phone, profile, address, atau data sensitif lainnya

### Requirement: Token refresh memperbarui claims
Ketika token di-refresh, claims MUST diperbarui berdasarkan role terkini user di database, refresh token lama MUST dibatalkan di Redis, dan refresh token baru MUST dikirim melalui secure cookie.

#### Scenario: Claims diperbarui setelah role change
- **WHEN** user yang tadinya role `user` sudah di-upgrade menjadi `creator` oleh admin, kemudian melakukan token refresh
- **THEN** JWT baru mengandung claim `role: "creator"` dengan permissions creator, refresh token lama tidak lagi valid, dan refresh token baru dikirim melalui secure cookie
