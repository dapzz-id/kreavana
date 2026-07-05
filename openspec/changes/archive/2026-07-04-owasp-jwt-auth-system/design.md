## Context

**Current state:**
- JWT signed with HS256 (symmetric HMAC) — secret shared between sign & verify. If secret leaks, all tokens can be forged.
- `refresh_token` dikirim via JSON response body, disimpan di `SharedPreferences` di Flutter — plaintext, accessible oleh proses lain atau malware.
- Tidak ada JTI tracking — logout tidak benar-benar mencabut token; token tetap valid sampai expired.
- Tidak ada rate limiting di auth endpoints — rentan brute-force.
- JWT payload mengandung data user yang bisa berisi informasi melebihi minimal (potensi information leakage).
- HTTP client Flutter menggunakan `http` package tanpa interceptor layer — retry logic ditulis manual.

**Target state:**
- RS256 (asymmetric) — backend signs dengan private key, verifies dengan public key. Bahkan jika public key bocor, token tidak bisa dipalsu.
- Refresh token dikirim sebagai `HttpOnly; Secure; SameSite=Strict` cookie — tidak accessible dari JavaScript/Dart code, hanya dikirim otomatis oleh browser/http client saat request ke origin yang sama.
- Setiap JWT memiliki `jti` (unique ID) yang disimpan di Redis. Middleware memvalidasi `jti` di setiap request — logout segera mencabut akses.
- Rate limiting via Laravel middleware / throttle rule di route.
- JWT payload hanya: `sub` (UUID user), `role`, `permissions` (array), `jti` (UUID).
- Dio dengan Interceptor otomatis menangani 401, call `/auth/refresh`, retry original request.

## Goals / Non-Goals

**Goals:**
- RS256 JWT signing dengan RSA key-pair yang dikelola backend.
- Redis-backed JTI revocation list untuk real-time logout enforcement.
- Refresh token via HttpOnly cookie (tidak tampak di response body Flutter).
- Rate limiting: `/auth/login` max 5 req/min, `/auth/refresh` max 10 req/min per IP.
- Audit log tabel `auth_logs`: kolom `user_id`, `action` (login/refresh/logout), `ip_address`, `user_agent`, `created_at`.
- Flutter: `flutter_secure_storage` untuk access token, Dio + Interceptor untuk auto-refresh.
- Generic error messages untuk mencegah user enumeration.

**Non-Goals:**
- Multi-factor authentication (MFA) — di luar scope perubahan ini.
- OAuth2 / SSO integration.
- Migrasi database user yang sudah ada — hanya session/token model yang berubah.
- Perubahan seluruh UI frontend.

## Decisions

### D1: RS256 via `tymon/jwt-auth` dengan RSA key-pair
- **Pilihan**: Generate RSA key-pair (`private.pem` + `public.pem`), konfigurasi `JWT_ALGO=RS256` di `.env`, set path keys di `config/jwt.php`.
- **Alternatif ditolak**: ES256 — support lebih terbatas di `tymon/jwt-auth v2`. HS256 — tetap simetris, tidak memenuhi requirement.
- **Rationale**: RS256 adalah standar industri yang well-supported, tymon/jwt-auth v2 mendukungnya via konfigurasi `keys`.

### D2: Redis JTI via `predis/predis`
- **Pilihan**: Tambah `predis/predis` ke `composer.json`. Gunakan `Redis::setex("jti:{$jti}", $ttl, "1")` saat login/refresh. Middleware `ValidateJti` memeriksa key ada di Redis sebelum memproses request. Saat logout, `Redis::del("jti:{$jti}")`.
- **Alternatif ditolak**: Database-backed JTI list — terlalu lambat untuk setiap request, menambah beban DB.
- **Rationale**: Redis O(1) lookup, TTL otomatis membersihkan expired JTI, in-memory untuk performa.

### D3: Refresh token via HttpOnly Cookie
- **Implikasi Flutter**: Flutter `http`/`dio` tidak mengelola cookie secara otomatis seperti browser. Untuk mobile, kita perlu menggunakan `dio_cookie_manager` + `cookie_jar` agar cookie dikirim otomatis, **ATAU** — karena ini mobile app bukan browser — kita tetap simpan refresh token di `flutter_secure_storage` (yang sudah aman, tidak accessible dari JS karena tidak ada browser). HttpOnly cookie hanya relevan untuk web context.
- **Keputusan**: Untuk Flutter **mobile**, simpan refresh token di `flutter_secure_storage`. Untuk Flutter **web**, gunakan cookie via `dio_cookie_manager`. Backend tetap mengirim cookie + juga mengirim refresh token di response body (hanya untuk mobile fallback) — mobile client mengambil dari body, web client mengambil dari cookie.
- **Rationale**: Pragmatis — mobile app tidak rentan XSS dari browser. `flutter_secure_storage` menggunakan Keychain (iOS) / Keystore (Android) — encrypted dan secure.

### D4: Dio sebagai HTTP client dengan Interceptor
- **Pilihan**: Tambah `dio: ^5.x` ke pubspec, buat `DioClient` singleton dengan `InterceptorsWrapper`. Pada response 401: panggil `/auth/refresh`, simpan token baru, retry request original.
- **Alternatif ditolak**: Mempertahankan `http` package — tidak memiliki interceptor built-in, retry logic harus ditulis manual (dan sudah ada bug saat ini).
- **Rationale**: Dio adalah standar de-facto Flutter untuk HTTP dengan interceptor. Kode lebih bersih, retry lebih reliable, cancellation support.

### D5: Audit Log tanpa data sensitif
- **Pilihan**: Tabel baru `auth_logs`. Log: `user_id` (UUID), `action`, `ip_address`, `user_agent`, `created_at`. **Tidak** log: password attempt, token values, email content.
- **Rationale**: OWASP A09 (Security Logging) — perlu audit trail tanpa membuat logging menjadi attack surface baru.

## Risks / Trade-offs

- **[Risk] Cookie tidak bekerja di Flutter mobile secara default** → Mitigation: Gunakan `flutter_secure_storage` untuk mobile (lebih secure), cookie untuk web.
- **[Risk] RSA key-pair perlu dikelola** (rotasi, backup) → Mitigation: Dokumentasikan prosedur generate key; untuk dev gunakan key yang sudah di-generate dan disimpan di `.env` yang di-gitignore.
- **[Risk] Breaking change — semua session lama invalid** → Mitigation: Deploy dengan announcement; backend support graceful fallback selama window migrasi singkat (opsional).
- **[Risk] Redis dependency** — jika Redis down, semua auth akan gagal → Mitigation: Gunakan `try/catch` di middleware JTI validation; jika Redis unreachable, log error dan **fail-open dengan warning** (degraded mode) atau **fail-closed** (lebih secure, pilih sesuai kebutuhan bisnis).

## Migration Plan

1. Generate RSA key-pair (`php artisan jwt:generate-secret --algo=RS256` atau via openssl).
2. Update `config/jwt.php` dan `.env`.
3. Tambah `predis/predis` via composer.
4. Buat tabel `auth_logs` via migration baru.
5. Update `AuthService`, `AuthResponder`, `AuthController` untuk RS256 + JTI + Cookie.
6. Buat middleware `ValidateJti`.
7. Update route throttle rules.
8. Di Flutter: update `pubspec.yaml`, rewrite `api_service.dart` ke Dio, update `auth_service.dart`.
9. Force-logout semua user (clear `user_sessions` table) saat deploy.
10. Monitor Redis dan `auth_logs` post-deploy.
