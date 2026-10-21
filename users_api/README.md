# Universal Identity & Access Management (IAM) Microservice

> **Core Engine:** Centralized Identity, Single Sign-On (SSO), Legal KYC, and Multi-Device Session Provider for the Kreavana Ecosystem and Future Satellite Applications.

---

## 1. Arsitektur & Filosofi
Microservice `users_api` memisahkan entitas **Global Identity** dari domain aplikasi bisnis:
- **`users_api` (Port 8001):** Mengelola autentikasi universal, akun, kredensial, verifikasi identitas (KYC KTP/NIB), dan sesi multi-perangkat.
- **`backend` (Port 8000):** Mengelola domain bisnis khusus Kreavana (kreator, portofolio, job contract, marketplace, kuota storage, dan transaksi).
- **`frontend`:** Client aplikasi (Flutter Web, Android, iOS) yang terhubung ke kedua service secara mulus.

---

## 2. Fitur Utama
1. **Universal SSO (Single Sign-On):** 1 akun dapat digunakan di Kreavana dan aplikasi lain di ekosistem tanpa perlu mendaftar ulang.
2. **Concurrent Multi-Device & Multi-App Sessions:** User dapat membuka beberapa aplikasi dan perangkat secara bersamaan tanpa saling mengeluarkan (*no auto-logout*).
3. **Independent Session Revocation:** User dapat logout dari satu perangkat saja (*Local Logout*) atau keluar dari seluruh perangkat secara global (*Global Security Logout*).
4. **Universal KYC:** Verifikasi KTP dan identitas legal hanya perlu dilakukan satu kali untuk seluruh ekosistem.
5. **OpenID Discovery & JWKS:** Standar industri (`/.well-known/openid-configuration` & `/.well-known/jwks.json`) untuk verifikasi token asimetris/terdesentralisasi.

---

## 3. Endpoints Ringkas (API Contract)

### Public Endpoints:
| Method | Endpoint | Keterangan |
| :--- | :--- | :--- |
| `GET` | `/health` | Status kesehatan service |
| `GET` | `/.well-known/openid-configuration` | OpenID Discovery metadata |
| `GET` | `/.well-known/jwks.json` | Public key endpoint |
| `POST` | `/api/v1/auth/register` | Registrasi akun universal baru |
| `POST` | `/api/v1/auth/login` | Login universal (mengembalikan Access & Refresh Token) |
| `POST` | `/api/v1/auth/social` | Login / auto-register via Google OAuth2 |
| `POST` | `/api/v1/auth/refresh` | Perpanjangan sesi tanpa logout |

### Authenticated Endpoints (Bearer Token):
| Method | Endpoint | Keterangan |
| :--- | :--- | :--- |
| `GET` | `/api/v1/auth/me` | Dapatkan profil akun & status KYC universal |
| `POST` | `/api/v1/auth/logout` | Logout dari sesi saat ini |
| `POST` | `/api/v1/auth/logout-all` | Logout dari seluruh perangkat & aplikasi |
| `PUT` | `/api/v1/profile` | Update profil dasar (Nama, avatar, bahasa, timezone) |
| `POST` | `/api/v1/profile/change-password` | Ganti password akun |
| `GET/POST` | `/api/v1/profile/addresses` | Manajemen alamat universal |
| `POST` | `/api/v1/kyc/submit` | Pengajuan verifikasi identitas legal (KTP/NIB) |
| `GET` | `/api/v1/kyc/status` | Cek status verifikasi KYC |
| `GET` | `/api/v1/sessions` | Daftar perangkat & aplikasi yang sedang aktif |
| `DELETE` | `/api/v1/sessions/{id}` | Putus sesi perangkat tertentu |
| `POST` | `/api/v1/devices` | Pendaftaran perangkat & update FCM Token |

---

## 4. Cara Menjalankan Secara Lokal

```bash
# 1. Pindah ke direktori users_api
cd users_api

# 2. Install dependensi composer
composer install

# 3. Siapkan environment file
cp .env.example .env

# Sesuaikan konfigurasi database lokal (DB_CONNECTION, DB_HOST, DB_PORT, DB_DATABASE, DB_USERNAME, DB_PASSWORD)

# 4. Generate Application Key dan JWT Secret
php artisan key:generate
php artisan jwt:secret --force

# 5. Jalankan migrasi dan seeder akun universal serta client app
php artisan migrate --seed

# 6. Jalankan server lokal pada port 8001 (port 8000 dialokasikan untuk Kreavana Backend)
php artisan serve --host=0.0.0.0 --port=8001
```

---

## 5. Akun Pengujian Default (Seeder)
Semua akun hasil `php artisan migrate --seed` memiliki password default:
- **Password:** `password123`
- **Contoh Akun:**
  - `alvin@example.com`
  - `superadmin@kreavana.com`
  - `client@example.com`
  - `creator@example.com`

