# Panduan & Aturan Claude untuk Repositori Kreavana (CLAUDE.md)

Dokumen ini adalah instruksi operasional wajib (**Mandatory System Instructions**) untuk model Claude (Anthropic / Claude Code / Claude Desktop / API / IDE Extension) dalam setiap sesi pengerjaan kode di repositori **Kreavana**.

---

## 🚨 ATURAN 1: LARANGAN KERAS OTOMATISASI GIT PUSH (NO AUTOMATED GIT PUSH)

Jika Anda adalah Claude:
1. **DILARANG KERAS MENJALANKAN PERINTAH `git push`**:
   - Claude **TIDAK BOLEH** mengeksekusi perintah `git push` ke remote origin dalam bentuk apa pun (`git push`, `git push origin <branch>`, maupun `git push origin main`).
   - Aturan ini mutlak untuk menjamin **Claude tidak pernah tercatat berkontribusi, committer, atau pusher** pada riwayat commit GitHub repositori ini.
2. **Tindakan yang Diizinkan untuk Claude**:
   - Membaca, menganalisis, dan memodifikasi file kode secara lokal.
   - Membuat branch lokal dan membuat commit lokal (`git commit -m "..."`).
   - Menguji kode lokal (linting PHP `php -l`, build check, `flutter analyze`).
3. **Penyelesaian Task**:
   - Setelah pekerjaan selesai dan di-commit secara lokal, **berikan instruksi langkah manual kepada pengguna** agar pengguna melakukan push sendiri, ATAU serahkan proses push kepada AI Coding Assistant resmi yang berwenang (Antigravity).

---

## 🔄 ATURAN 2: PROSEDUR WAJIB 6 LANGKAH GIT WORKFLOW

Setiap pengerjaan perubahan wajib mengikuti prosedur standar di `.github/rules/git-workflow.md`:
1. **Pull Main Terbaru**: Sebelum memulai branch baru, wajib `git checkout main && git pull origin main`. Pastikan working tree dalam keadaan bersih (`clean`).
2. **Buat Branch Kerja**: Gunakan format konvensional `git checkout -b <tipe>/<nama-branch>` (`feature/`, `fix/`, `refactor/`, `chore/`).
3. **Modifikasi & Commit Lokal**: Uji kode sebelum commit. Format commit: `tipe(scope): deskripsi singkat`.
4. **Wajib Sinkronisasi Lokal Sebelum Push**:
   - Beralih ke main: `git checkout main && git pull origin main`.
   - Kembali ke branch kerja: `git checkout <nama-branch> && git merge main`.
   - Pastikan bebas konflik (*merge conflict*).
5. **Push ke Branch Baru**: (Dieksekusi manual oleh user atau Antigravity, **BUKAN Claude**).
6. **Merge ke Main & Push**: (Dieksekusi manual oleh user atau Antigravity, **BUKAN Claude**).

---

## 🔐 ATURAN 3: INTEGRASI WAJIB BACKEND DENGAN `users_api` (DECOUPLED IAM)

1. **Backend Wajib Selalu Terhubung ke `users_api`**:
   - Backend Kreavana bertindak sebagai **BFF (Backend for Frontend) & Resource Server**.
   - Otoritas autentikasi utama adalah microservice terpusat **`users_api`** (Universal Identity & Access Management).
   - Seluruh request autentikasi publik (`login`, `register`, `social login`, `change password`) **WAJIB** diteruskan melalui proxy `App\Services\UsersApiClient`.
2. **Prinsip Zero-Knowledge Password di Backend**:
   - **DILARANG KERAS** menambahkan kembali kolom `password` ke tabel `users` di backend. Kolom `password` telah di-drop secara permanen di database backend!
   - Kredensial rahasia (hash password, token provider eksternal) **HANYA** disimpan di database `users_api` (`user_credentials`).
3. **Pola Shadow User Synchronization**:
   - Backend hanya mengelola atribut konteks bisnis lokal (`role`, `sub_role`, `is_creator_approved`, `balance`, `wallet_pin`, kuota kerja).
   - Sinkronisasi profil dari `users_api` ke backend selalu menggunakan `UsersApiClient::syncShadowUser($userApiData)`.

---

## 🛡️ ATURAN 4: STANDAR KEAMANAN INDUSTRI BIG TECH (ENTERPRISE HARDENING)

Dilarang keras melemahkan atau menghapus lapisan keamanan yang telah dibangun. Seluruh kode baru harus memenuhi standar berikut:

### 1. Machine-to-Machine (S2S) Cryptographic Authentication
- Setiap komunikasi antar-layanan (`backend` $\rightarrow$ `users_api` maupun sebaliknya) **WAJIB** menyertakan 4 header keamanan:
  1. `X-Client-Id`: Identifier aplikasi klien (misal `kreavana_app`).
  2. `X-Timestamp`: Epoch UNIX timestamp saat request dibuat.
  3. `X-Correlation-Id`: UUID unik untuk *distributed tracing*.
  4. `X-Signature`: Tanda tangan digital HMAC-SHA256 (`hash_hmac('sha256', clientId . '.' . timestamp . '.' . rawBody, secret)`).
- **Anti-Replay Protection**: Verifikasi di middleware `VerifyClientApp.php` dan `VerifyInternalServiceSignature.php` membatasi toleransi waktu maksimal 300 detik (5 menit). Dilarang menghapus atau mem-bypass verifikasi ini!

### 2. Arsitektur Fail-Closed (Anti-Downgrade Attack)
- Jika layanan `users_api` tidak dapat dijangkau atau mengalami gangguan, backend **WAJIB** mengembalikan respons `503 Service Unavailable` secara aman (*Fail-Closed*).
- **DILARANG KERAS** menambahkan fallback login lokal (seperti `Auth::attempt()` lama) yang berpotensi memicu kerentanan downgrade attack dan fatal SQL error.

### 3. Integritas Ledger Dompet & Keuangan (Cryptographic Ledger Chain)
- Saldo pengguna (`balance`) dilindungi oleh sistem ledger kriptografis pada tabel `wallet_transactions` menggunakan signature **`ledger_hash` (HMAC-SHA256)**.
- **DILARANG KERAS** mengupdate atau mengubah saldo `users.balance` secara langsung tanpa membuat entri transaksi yang sah dengan `ledger_hash`.
- Saldo default untuk akun baru atau seeder **WAJIB bernilai `0.00`** (bukan angka arbitrer/5jt).

### 4. Distributed Session Revocation & Suspension
- Endpoint internal S2S di backend:
  - `POST /api/internal/v1/sessions/revoke`
  - `POST /api/internal/v1/users/suspend`
  Harus tetap aktif dan diproteksi oleh `VerifyInternalServiceSignature`.
- Setiap token revocation harus terintegrasi dengan `JtiService::revoke($jti)` dan middleware `CheckUserSuspended`.

---

## 📋 CHECKSUM KEPATUHAN UNTUK PROMPTING SELANJUTNYA

Sebelum mengakhiri sesi pengerjaan, Claude wajib memverifikasi:
- [ ] Tidak ada perintah `git push` yang dijalankan oleh Claude.
- [ ] Kolom `password` tidak dimunculkan kembali di tabel `users` backend.
- [ ] Tidak ada mekanisme fallback auth lokal yang merusak prinsip *Fail-Closed*.
- [ ] Header keamanan HMAC (`X-Client-Id`, `X-Timestamp`, `X-Signature`, `X-Correlation-Id`) tetap aktif pada `UsersApiClient`.
- [ ] Syntax PHP lolos `php -l` tanpa error.
