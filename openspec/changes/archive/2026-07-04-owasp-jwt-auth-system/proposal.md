## Why

Sistem autentikasi Kreavana saat ini menggunakan JWT dengan algoritma **HS256 (simetris)** dan menyimpan `session_token` + `refresh_token` di `SharedPreferences` (frontend). Ini melanggar beberapa prinsip OWASP: algoritma simetris rentan jika secret bocor, `SharedPreferences` tidak aman untuk menyimpan token sensitif (rentan XSS/root access), refresh token dikirim via JSON body (bukan cookie), dan tidak ada validasi JTI real-time via Redis. Upgrade diperlukan untuk membawa sistem ke standar keamanan enterprise.

## What Changes

- **BREAKING**: Ganti algoritma JWT dari `HS256` → `RS256` (asimetris). Backend menggunakan private key untuk sign, public key untuk verify.
- **BREAKING**: `refresh_token` tidak lagi dikirim dalam JSON response — dikelola via `HttpOnly, Secure, SameSite=Strict` cookie dari backend.
- Tambahkan `jti` (JWT ID) ke JWT payload untuk mendukung real-time revocation.
- Integrasikan **Redis** untuk menyimpan daftar JTI aktif; setiap request yang masuk divalidasi JTI-nya.
- Implementasikan **Refresh Token Rotation**: refresh token lama dicabut setiap kali digunakan.
- Tambahkan **Rate Limiting** di endpoint `/auth/login` dan `/auth/refresh` (misal: 5 request/menit).
- Terapkan **Audit Log** untuk aktivitas login/logout/refresh (IP, User-Agent, Timestamp) — disimpan tanpa data sensitif.
- Frontend: Ganti `SharedPreferences` → `flutter_secure_storage` untuk menyimpan access token.
- Frontend: Ganti HTTP client `http` → `dio` untuk mendapatkan Interceptors otomatis pada 401.
- JWT payload dipersempit: hanya `sub`, `role`, `permissions`, `jti` — tidak boleh ada PII.

## Capabilities

### New Capabilities
- `jwt-rs256-signing`: JWT ditandatangani dengan RS256 menggunakan RSA key-pair.
- `redis-jti-revocation`: Validasi dan revokasi JTI via Redis secara real-time.
- `secure-refresh-cookie`: Refresh token dikelola via HttpOnly cookie, bukan JSON response.
- `auth-rate-limiting`: Rate limiting pada endpoint autentikasi untuk mitigasi brute-force.
- `auth-audit-log`: Pencatatan aktivitas autentikasi (login, refresh, logout) untuk auditability.
- `flutter-dio-interceptor`: Penggantian HTTP client ke Dio dengan auto-refresh interceptor.
- `flutter-secure-token-storage`: Penyimpanan token di flutter_secure_storage, bukan SharedPreferences.

### Modified Capabilities
- `unified-auth`: JWT payload diperbarui (hanya `sub`, `role`, `permissions`, `jti`). Algoritma berubah dari HS256 → RS256. Cookie menggantikan refresh token dalam response body.

## Impact

- **Backend**: `config/jwt.php`, `AuthService`, `AuthResponder`, `AuthController`, `UserSession` model/migration, route middleware, `composer.json` (tambah `predis/predis`), kebutuhan RSA key-pair.
- **Frontend**: `pubspec.yaml` (tambah `dio`, `flutter_secure_storage`), `api_service.dart` (full rewrite ke Dio + Interceptor), `auth_service.dart`, semua service yang memanggil ApiService.
- **Breaking**: Semua active session user akan invalid setelah deploy (karena perubahan algo & payload). Perlu force logout / invalidasi semua token lama.
- **Infrastructure**: Redis harus tersedia di environment backend. Perlu generate RSA key-pair untuk production.
