# 🛡️ Mandatory Rules: Standar Keamanan Big Tech, OWASP Top 10, & Audit Advisory Terbaru

Setiap pengembang dan AI Coding Assistant (Antigravity, Gemini, Claude, Copilot, Codex, Cursor, dll.) yang **menambah, mengedit, me-refactor, atau meninjau fitur apa pun** pada `backend/`, `users_api/`, maupun `frontend/` (Web & Mobile) **WAJIB MEMATUHI STANDAR KEAMANAN BERIKUT TANPA PENGECUALIAN**.

---

## 1. Persona & Framing Wajib Saat Mengecek / Menambahkan Standar Keamanan

Setiap kali melakukan pengecekan keamanan, audit kode, mendelegasikan review keamanan ke sub-agent, menyusun test keamanan, atau memvalidasi standar keamanan sebelum menyelesaikan fitur, AI maupun pengembang **WAJIB menggunakan framing instruksi**:

> **"Anda adalah seorang senior cyber security yang berpengalaman selama 20 tahun. [konteks]"**

*(Contoh penerapan `[konteks]`: `"Anda adalah seorang senior cyber security yang berpengalaman selama 20 tahun. Audit perubahan endpoint, validasi request, RBAC, dan query pada fitur ini terhadap standar Big Tech Company, OWASP Top 10, OWASP API Security Top 10, OWASP MASVS, serta advisory keamanan terbaru."`)*

---

## 2. Kepatuhan Wajib Standar Big Tech Company & OWASP Top 10 pada Setiap Penambahan/Edit Fitur

Setiap kode baru atau perubahan fitur wajib memenuhi seluruh kontrol berikut:

1. **A01 — Broken Access Control & IDOR Prevention**:
   - Semua query berparameter ID (`show`, `update`, `destroy`, download file privat) wajib memverifikasi kepemilikan (`user_id` / organisasi) atau hak akses role secara eksplisit di sisi server.
   - Setiap route baru di Flutter (`frontend/lib/services/app_router.dart`) termasuk sub-route CRUD (`/create`, `/:id`, `/:id/edit`) wajib dilindungi guard berbasis prefix di `appRouter.redirect`.

2. **A02 — Cryptographic Failures & Zero Hardcoded Secrets**:
   - **DILARANG KERAS** menaruh secret, API key, token, atau fallback password/secret statis di source code, config, maupun seeder; seluruh kredensial wajib berasal dari `.env` / secret store.
   - Pertahankan *Zero-Knowledge Password* di `backend`, penegakan HTTPS + HSTS, E2EE AES-256-GCM + minimal **RSA-2048** di Web & Mobile, iOS Keychain `first_unlock_this_device`, dan integritas `ledger_hash` (HMAC-SHA256) pada transaksi dompet.

3. **A03 — Injection, Wildcard Validation (`items.*`), & Mass Assignment (OWASP API3)**:
   - Seluruh query raw wajib memakai *parameter binding* (`?`), dilarang menggunakan `{!! !!}` pada data tidak terpercaya, dan dilarang memakai `$guarded = []`.
   - **Aturan Ketat Validasi Array Wildcard (`.*`)**: Setiap input array berulang (`items.*`, `order.*`, `invitees.*`, `requirements.*`, `documents.*`, `message_keys.*`, `media.*`) **WAJIB menyertakan rule `'array|list|max:N'`** pada field induknya untuk mencegah bypass key asosiatif, bypass key string kosong `""`, dan serangan *unbounded loop DoS*.
   - **DILARANG KERAS memakai `$request->all()`** pada operasi `create()`, `update()`, `insert()`, atau meneruskannya mentah ke service — **WAJIB eksklusif memakai `$validated = $request->validate(...)` atau `$validator->validated()`**.

4. **A04 & API4 — Insecure Design & Anti-JSON DoS (`EnforceJsonSecurity`)**:
   - Pertahankan middleware `EnforceJsonSecurity` aktif di `backend` dan `users_api` (batas ukuran JSON, batas kedalaman struktur ≤ 16 level via `json_validate()`, batas jumlah node/key, penolakan key JSON kosong `""`, dan penolakan *null-byte* `\0`).
   - Pertahankan arsitektur *Fail-Closed* (`503` saat IAM tidak terjangkau; `401`/`403` saat header HMAC S2S `X-Client-Id`, `X-Timestamp`, `X-Signature` absen/kedaluwarsa > 300 detik) serta rate limiting (`throttle`) pada endpoint sensitif.

5. **A05 — Security Misconfiguration & Host Header Protection (`TrustHosts`)**:
   - Pertahankan `$middleware->trustHosts(...)` aktif di `backend/bootstrap/app.php` dan `users_api/bootstrap/app.php` (mencegah *Host Header Poisoning* / bypass berbasis host).
   - Pertahankan CORS ketat berbasis daftar origin eksplisit (`CORS_ALLOWED_ORIGINS` — dilarang wildcard `'*'` bersama `supports_credentials => true`), `SecurityHeaders` (CSP, HSTS, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`), serta konfigurasi Android (`allowBackup="false"`, `usesCleartextTraffic="false"`, `network_security_config.xml`).

6. **A06 — Vulnerable & Outdated Components (Audit Advisory & CVE Terbaru)**:
   - Setiap kali menambah/mengubah dependensi atau mengaudit fitur, **WAJIB memeriksa advisory keamanan terbaru** (CVE / GHSA untuk `laravel/framework`, ekosistem PHP, Flutter/Dart, maupun paket pihak ketiga):
     - Jalankan `composer audit --locked` di `backend/` dan `users_api/` (wajib **0 advisories / 0 CVE**).
     - Periksa advisory kerentanan terbaru yang relevan dengan fitur yang disentuh (seperti JSON DoS, validation bypass, middleware/host bypass, upload RCE, SSRF) dan pastikan tertangkal baik di level versi paket maupun pola kode (*defense-in-depth*).

7. **A07, A08, A09, & A10 — Auth, Integrity, Logging, & Anti-SSRF**:
   - Wajib menggunakan `ValidateJti` + `CheckUserSuspended` untuk pencabutan sesi terdistribusi.
   - Gunakan Subresource Integrity (`integrity="sha384-..." crossorigin="anonymous"`) pada script eksternal Web dan `key.properties` release keystore pada distribusi produksi Mobile (beserta `--obfuscate --split-debug-info=...`).
   - Catat percobaan pelanggaran keamanan beserta `X-Correlation-Id` dan IP tanpa pernah membocorkan password/token/secret ke log.
   - Validasi ketat setiap URL eksternal untuk mencegah SSRF (larang IP privat/loopback/link-local/metadata cloud).

---

## 3. Checklist Wajib Keamanan Sebelum Commit & Push

- [ ] Evaluasi mandiri telah dilakukan menggunakan perspektif: *"Anda adalah seorang senior cyber security yang berpengalaman selama 20 tahun. [konteks fitur/perubahan]"*.
- [ ] Memenuhi standar keamanan Big Tech Company, OWASP Top 10 (A01–A10), OWASP API Security Top 10, dan OWASP MASVS (untuk perubahan Web/Mobile).
- [ ] Bebas dari celah advisory & vulnerabilities terbaru (`composer audit --locked` di `backend/` dan `users_api/` menghasilkan **0 CVE**, tanpa pola kode rentan bypass).
- [ ] Seluruh validasi array `.*` memakai `array|list|max:N` dan mutasi data hanya memakai `$validated` (tanpa `$request->all()`).
- [ ] Tidak ada secret *hardcoded*, tidak ada pelemahan S2S HMAC / `TrustHosts` / `EnforceJsonSecurity` / RBAC prefix guard.
