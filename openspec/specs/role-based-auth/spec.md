# Purpose
TBD

## Requirements


### Requirement: Role-separated auth controllers
Sistem HARUS memiliki controller autentikasi terpisah untuk setiap role: `UserAuthController`, `CreatorAuthController`, dan `AdminAuthController`, masing-masing di namespace `App\Http\Controllers\Auth\`.

#### Scenario: User login via dedicated endpoint
- **WHEN** user mengirim POST ke `/api/auth/user/login` dengan email dan password valid
- **THEN** sistem mengembalikan JWT access token, refresh token, session token, dan data user dengan role `user`

#### Scenario: Creator login via dedicated endpoint
- **WHEN** creator mengirim POST ke `/api/auth/creator/login` dengan email dan password valid
- **THEN** sistem memvalidasi bahwa user memiliki role `creator`, dan mengembalikan JWT token dengan claims role `creator` beserta permissions yang sesuai

#### Scenario: Creator login ditolak untuk non-creator
- **WHEN** user dengan role `user` mencoba login via `/api/auth/creator/login`
- **THEN** sistem mengembalikan 403 Forbidden dengan pesan "Akun Anda tidak memiliki akses sebagai Creator"

#### Scenario: Admin login via dedicated endpoint
- **WHEN** admin mengirim POST ke `/api/auth/admin/login` dengan email dan password valid
- **THEN** sistem memvalidasi bahwa user memiliki role `admin`, dan mengembalikan JWT token dengan claims role `admin` beserta permissions yang sesuai

#### Scenario: Admin login ditolak untuk non-admin
- **WHEN** user tanpa role `admin` mencoba login via `/api/auth/admin/login`
- **THEN** sistem mengembalikan 403 Forbidden dengan pesan "Akun Anda tidak memiliki akses sebagai Admin"

### Requirement: Public registration hanya untuk role user
Hanya role `user` yang HARUS dapat melakukan registrasi publik. Creator didaftarkan melalui proses approval, admin melalui seeder/command.

#### Scenario: User melakukan registrasi publik
- **WHEN** user mengirim POST ke `/api/auth/user/register` dengan data valid (name, username, email, password)
- **THEN** sistem membuat akun baru dengan role `user` dan mengembalikan data user

#### Scenario: Tidak ada endpoint registrasi untuk creator
- **WHEN** client mengirim POST ke `/api/auth/creator/register`
- **THEN** sistem mengembalikan 404 Not Found (endpoint tidak ada)

#### Scenario: Tidak ada endpoint registrasi untuk admin
- **WHEN** client mengirim POST ke `/api/auth/admin/register`
- **THEN** sistem mengembalikan 404 Not Found (endpoint tidak ada)

### Requirement: JWT custom claims mengandung role dan permissions
Setiap JWT token yang dihasilkan HARUS menyertakan `role` dan `permissions` di custom claims.

#### Scenario: JWT claims untuk user role
- **WHEN** user dengan role `user` berhasil login
- **THEN** JWT token mengandung claim `role: "user"` dan `permissions` array sesuai konfigurasi role user

#### Scenario: JWT claims untuk creator role
- **WHEN** user dengan role `creator` berhasil login
- **THEN** JWT token mengandung claim `role: "creator"` dan `permissions` array sesuai konfigurasi role creator

#### Scenario: JWT claims untuk admin role
- **WHEN** user dengan role `admin` berhasil login
- **THEN** JWT token mengandung claim `role: "admin"` dan `permissions` array sesuai konfigurasi role admin

### Requirement: Token refresh memperbarui claims
Ketika token di-refresh, claims HARUS diperbarui berdasarkan role terkini user di database.

#### Scenario: Claims diperbarui setelah role change
- **WHEN** user yang tadinya role `user` sudah di-upgrade menjadi `creator` oleh admin, kemudian melakukan token refresh
- **THEN** JWT baru mengandung claim `role: "creator"` dengan permissions creator

### Requirement: Backward compatibility endpoint lama
Endpoint auth lama (`/api/auth/login`, `/api/auth/register`) HARUS tetap berfungsi selama masa transisi, diarahkan ke flow user auth.

#### Scenario: Login via endpoint lama tetap berfungsi
- **WHEN** client mengirim POST ke `/api/auth/login` (endpoint lama)
- **THEN** sistem memproses login sebagai user auth dan mengembalikan response dengan header `Deprecation: true`

#### Scenario: Register via endpoint lama tetap berfungsi
- **WHEN** client mengirim POST ke `/api/auth/register` (endpoint lama)
- **THEN** sistem memproses registrasi sebagai user auth dan mengembalikan response dengan header `Deprecation: true`
