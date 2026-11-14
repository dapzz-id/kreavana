# Panduan Integrasi Universal Identity Service ke Backend Kreavana

Dokumen ini menjelaskan strategi integrasi antara **Kreavana Backend (`backend/`)** dengan **Universal Identity Service (`users_api/`)**.

---

## 1. Arsitektur Komunikasi
```text
[Frontend / Client]
        │
        ├── 1. POST /api/v1/auth/login ───────────► [ users_api (Port 8001) ]
        │      (Mendapatkan Universal JWT)
        │
        └── 2. GET /api/opportunities ────────────► [ backend (Port 8000) ]
               (Header: Bearer <Universal JWT>)
```

## 2. Validasi Token Stateless (Tanpa Bottleneck Jaringan)
1. Backend `backend/` memvalidasi JWT yang diterbitkan oleh `users_api` secara mandiri.
2. Shared JWT Secret atau Public Key didistribusikan antar service (atau diakses via `http://127.0.0.1:8001/.well-known/jwks.json`).
3. Backend membaca `sub` (User UUID) dari token untuk mengidentifikasi siapa pengguna yang sedang membuat request.

## 3. Just-In-Time (JIT) Shadow Profile Provisioning
Ketika pengguna baru dari ekosistem login pertama kali ke Kreavana:
1. Backend mengecek apakah `users.id` sudah ada di database Kreavana.
2. Jika belum ada, backend secara otomatis membuat baris profil lokal:
   ```php
   $user = User::firstOrCreate(
       ['id' => $jwtPayload['sub']],
       [
           'email' => $jwtPayload['email'],
           'username' => $jwtPayload['username'],
           'name' => $jwtPayload['full_name'],
           'role' => 'user',
           'balance' => 0.00,
           'is_creator_approved' => false,
       ]
   );
   ```
3. Data spesifik Kreavana (reputasi, rating, kuota, portofolio) dikelola sepenuhnya di database `backend`, sementara data akun inti tetap bersih di `users_api`.
