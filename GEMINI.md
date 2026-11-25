# Panduan & Aturan Gemini / Antigravity untuk Repositori Kreavana (GEMINI.md)

Dokumen ini adalah instruksi operasional wajib (**Mandatory System Instructions**) untuk model **Gemini / Antigravity** (Antigravity IDE, Gemini CLI, API, maupun IDE Extension) dalam setiap sesi pengerjaan kode di repositori **Kreavana**.

> **STOP DAN BACA ATURAN DULU**: Sebelum menganalisis kode secara luas, menyusun rencana, mengedit file, membuat data dummy, atau mengubah struktur database pada **setiap** prompt, Anda WAJIB membaca seluruh file aturan repositori di `.agent/rules/*.md`, `.github/rules/*.md`, `.github/copilot-instructions.md`, `AGENTS.md`, `CLAUDE.md`, dan dokumen ini terlebih dahulu.

---

## 🚀 ATURAN 1: OTORISASI & ATURAN EKSEKUSI `git push` (DIIZINKAN DENGAN SYARAT)

Jika Anda adalah Gemini / Antigravity:
1. **Perintah `git push` DIIZINKAN**:
   - Berbeda dengan model Claude, Gemini / Antigravity **DIPERBOLEHKAN** mengeksekusi perintah `git push` (`git push -u origin <nama-branch>` maupun `git push origin main`) untuk mengirimkan perubahan ke repositori remote.
2. **Syarat Mutlak Sebelum Menjalankan `git push`**:
   - **DILARANG KERAS** melakukan `git push` pada branch kerja tanpa melakukan sinkronisasi dan merge lokal dari `main` terbaru terlebih dahulu (`git checkout main && git pull origin main`, lalu `git checkout <nama-branch> && git merge main`).
   - **DILARANG KERAS** melakukan `git push origin main` tanpa melakukan `git pull origin main` dan verifikasi merge lokal tepat sebelumnya.
   - **DILARANG KERAS** melakukan *Force Push* (`git push -f` / `git push --force`) ke branch `main` atau branch bersama.
   - Pastikan hanya file yang memang masuk lingkup tugas yang di-commit dan di-push; jangan mencampurkan perubahan *working tree* lain yang tidak terkait tanpa kejelasan.
3. **Tindakan yang Diizinkan**:
   - Membaca, menganalisis, dan memodifikasi file kode secara lokal.
   - Membuat branch lokal, menjalankan pengujian lokal (`php -l`, unit/feature test, `flutter analyze`, `flutter test`), dan membuat commit lokal (`git commit -m "..."`).
   - Menjalankan sinkronisasi, merge lokal, serta `git push` ke branch kerja dan `main` sesuai Aturan 2.
4. **Catatan Khusus Lintas-Model (Claude)**:
   - Jika suatu tugas atau sub-agen dijalankan menggunakan model **Claude** (Anthropic), aturan larangan keras `git push` di `CLAUDE.md` tetap berlaku penuh — Claude hanya mengedit & commit lokal, sedangkan push dilakukan manual oleh pengguna atau Antigravity.

---

## 🔄 ATURAN 2: PROSEDUR WAJIB 6 LANGKAH GIT WORKFLOW

Setiap pengerjaan perubahan wajib mengikuti prosedur standar di `.agent/rules/git-workflow.md` dan `.github/rules/git-workflow.md`:
1. **Pull Main Terbaru**: Sebelum memulai branch baru, wajib `git checkout main && git pull origin main`. Pastikan tidak ada commit remote yang tertinggal.
2. **Buat Branch Kerja**: Gunakan format konvensional `git checkout -b <tipe>/<nama-branch>` (`feature/`, `fix/`, `refactor/`, `chore/`).
3. **Modifikasi, Uji, & Commit Lokal**: Uji kode sebelum commit. Format commit: `tipe(scope): deskripsi singkat`.
4. **Wajib Sinkronisasi Lokal Sebelum Push**:
   - Beralih ke main: `git checkout main && git pull origin main`.
   - Kembali ke branch kerja: `git checkout <nama-branch> && git merge main`.
   - Pastikan bebas konflik (*merge conflict*).
5. **Push ke Branch Baru**: `git push -u origin <nama-branch>` *(diizinkan untuk Gemini / Antigravity setelah Langkah 4 bersih)*.
6. **Merge ke Main & Push**: `git checkout main && git pull origin main && git merge <nama-branch> && git push origin main` *(diizinkan untuk Gemini / Antigravity)*.

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
- Setiap komunikasi antar-layanan (`backend` → `users_api` maupun sebaliknya) **WAJIB** menyertakan 4 header keamanan:
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

### 5. Standar OWASP Top 10, Advisory Terbaru, & Framing Wajib Senior Cyber Security (20 Tahun)
- **Wajib Sesuai Standar Big Tech & OWASP Top 10 di Setiap Penambahan/Edit Fitur**:
  - Setiap penambahan atau perubahan fitur di `backend/`, `users_api/`, maupun `frontend/` (Web & Mobile) wajib memenuhi `.agent/rules/security-bigtech-and-owasp-standards.md`: bebas secret hardcoded, `EnforceJsonSecurity` & `TrustHosts` tetap aktif, seluruh validasi wildcard `.*` wajib memakai `array|list|max:N`, dilarang memakai `$request->all()` pada mutasi DB (wajib `$validated`), dan wajib memiliki proteksi IDOR + RBAC berbasis prefix.
- **Bebas Celah Advisory & Vulnerabilities Terbaru**:
  - Wajib memastikan tidak ada kerentanan dari CVE atau security advisory terbaru (`composer audit --locked` = `0 CVE` pada `backend/` & `users_api/`, tanpa pola kode rentan bypass).
- **Kalimat/Framing Wajib Saat Mengecek & Menambahkan Standar Keamanan**:
  - Setiap kali mengecek, mengaudit, mendelegasikan review ke sub-agen, atau menambahkan standar keamanan, **WAJIB menggunakan kalimat pembuka**:
    > `"Anda adalah seorang senior cyber security yang berpengalaman selama 20 tahun. [konteks]"`

---

## 🗄️ ATURAN 5: KEPATUHAN ATURAN PROMPT AI, DATA BERBASIS DATABASE (TANPA MOCKUP), MIGRASI BARU, & ROUTING RBAC

1. **Baca Aturan Terlebih Dahulu (`Baca Aturan Dulu`)**:
   - Pada setiap awal prompt/sesi, Gemini / Antigravity **WAJIB membaca seluruh file aturan repositori terlebih dahulu** (`GEMINI.md`, `AGENTS.md`, `CLAUDE.md`, `.claude/CLAUDE.md`, `.agent/rules/*.md`, `.github/rules/*.md`, dan `.github/copilot-instructions.md`) sebelum menganalisis, merencanakan, atau mengedit kode.
2. **Data Dummy Wajib Berdasarkan Database (DILARANG Mockup) & Paginasi**:
   - Dilarang keras membuat data mockup/dummy statis hardcoded di frontend Flutter atau fallback array statis di backend controller/service.
   - Seluruh data tampilan (layar, KPI dashboard, daftar, detail) wajib berasal langsung dari query database nyata (`backend` / `users_api`); jika data kosong, tampilkan *empty state* jujur dan hitungan `0`.
   - Apabila dibutuhkan data dummy/contoh/testing, buatlah **langsung di database** melalui Laravel Seeder (`backend/database/seeders/` atau `users_api/database/seeders/`), Factory, atau record database asli sesuai kolom, tipe data, enum, dan relasi foreign key aktual.
   - Seluruh tampilan daftar multi-item yang bersumber dari database wajib menggunakan paginasi yang konsisten (misal `AppPaginationBar` / endpoint API terpaginasi).
3. **Edit Tabel Database Wajib Membuat Migrasi Baru**:
   - Dilarang mengubah, menyisipkan kolom, atau mengedit file migrasi historis yang sudah ada di `backend/database/migrations/` atau `users_api/database/migrations/`.
   - Setiap modifikasi pada tabel yang sudah ada (tambah/ubah/ganti nama/hapus kolom, enum, index, maupun foreign key) **WAJIB membuat file migrasi baru** menggunakan `php artisan make:migration <nama_perubahan>`, menyertakan `up()` dan `down()`, memperbarui Model/Seeder terkait, serta mengecek `php -l`.
4. **Routing `1 Page = 1 Route` & Strict RBAC**:
   - Patuhi `.agent/rules/page-routing-and-permissions.md`: setiap halaman wajib terdaftar di `AppRoutes` dan `appRouter`, navigasi halaman penuh menggunakan `context.go(AppRoutes.<route>)` (tanpa anonymous `Navigator.push`), dan seluruh akses role dijaga ketat di `appRouter.redirect`.

---

## 📋 CHECKSUM KEPATUHAN UNTUK PROMPTING SELANJUTNYA

Sebelum mengakhiri sesi pengerjaan, Gemini / Antigravity wajib memverifikasi:
- [ ] Seluruh aturan proyek (`.agent/rules/*.md`, `.github/rules/*.md`, `.github/copilot-instructions.md`, `GEMINI.md`, `AGENTS.md`, `CLAUDE.md`) sudah dibaca sebelum memulai pengerjaan.
- [ ] Alur 6 langkah Git Workflow dipatuhi sebelum menjalankan `git push` (pull `main` -> branch kerja -> commit -> sync & merge lokal `main` -> push branch -> merge ke `main` & push `main`), tanpa `git push --force`.
- [ ] Tidak ada data mockup / dummy hardcoded di frontend atau controller; seluruh data dummy dibuat di database (Seeder/Factory/DB) dengan paginasi konsisten pada tampilan daftar.
- [ ] Setiap perubahan skema tabel database yang sudah ada dibuat melalui **file migrasi baru** tanpa mengedit migrasi lama.
- [ ] Setiap halaman dan perubahan navigasi mematuhi aturan `1 Page = 1 Route` serta strict RBAC pada `appRouter.redirect`.
- [ ] Kolom `password` tidak dimunculkan kembali di tabel `users` backend.
- [ ] Tidak ada mekanisme fallback auth lokal yang merusak prinsip *Fail-Closed*.
- [ ] Header keamanan HMAC (`X-Client-Id`, `X-Timestamp`, `X-Signature`, `X-Correlation-Id`) tetap aktif pada `UsersApiClient`.
- [ ] Perubahan saldo dompet selalu melalui `wallet_transactions` yang sah (`ledger_hash`), dengan saldo default akun baru `0.00`.
- [ ] Setiap penambahan/edit fitur telah dicek memakai framing `"Anda adalah seorang senior cyber security yang berpengalaman selama 20 tahun. [konteks]"`, memenuhi standar Big Tech & OWASP Top 10, serta bebas celah advisory/vulnerabilities terbaru (`0 CVE`).
- [ ] Syntax PHP lolos `php -l` (dan pengujian / analyzer relevan terverifikasi) tanpa error.
