## 1. Backend Infrastructure Setup

- [x] 1.1 Tambah `predis/predis` ke `composer.json` dan jalankan `composer require predis/predis`. Konfigurasi `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD` di `.env`. Set `CACHE_DRIVER=redis` dan `SESSION_DRIVER=redis`.
- [x] 1.2 Generate RSA key-pair: `openssl genrsa -out storage/jwt-private.pem 4096` dan `openssl rsa -in storage/jwt-private.pem -pubout -out storage/jwt-public.pem`. Tambahkan path ke `.env` sebagai `JWT_PRIVATE_KEY` dan `JWT_PUBLIC_KEY`.
- [x] 1.3 Update `config/jwt.php`: set `'algo' => env('JWT_ALGO', 'RS256')`, konfigurasi `'keys'` array dengan `'private'` dan `'public'` path dari `.env`. Pastikan `secret` tidak digunakan saat RS256.
- [x] 1.4 Buat migration `2026_01_01_000019_create_auth_logs_table.php` dengan kolom: `id` (bigint auto), `user_id` (uuid nullable FK→users), `action` (varchar 50: login/logout/refresh/login_failed), `ip_address` (varchar 45), `user_agent` (text nullable), `created_at` (timestamp). Index pada `(user_id, created_at)`.
- [x] 1.5 Jalankan `php artisan migrate` untuk membuat tabel `auth_logs`.

## 2. Backend — JWT Payload & JTI Service

- [x] 2.1 Buat `App\Services\JtiService` dengan method: `store(string $jti, int $ttlSeconds)` — simpan ke Redis dengan key `jti:{$jti}` dan TTL. `exists(string $jti): bool` — cek apakah JTI ada di Redis. `revoke(string $jti)` — hapus key dari Redis.
- [x] 2.2 Update `AuthService::generateTokenPayload()` — setelah `Auth::guard('api')->login/attempt()`, ekstrak `jti` dari token menggunakan `JWTAuth::setToken($token)->getPayload()->get('jti')`. Panggil `JtiService::store($jti, $ttlSeconds)`.
- [x] 2.3 Pastikan JWT payload hanya berisi `sub`, `role`, `permissions`, `jti` — update `App\Http\Controllers\Auth\AuthResponder` agar response body tidak mengekspos data PII melebihi yang diperlukan.

## 3. Backend — Middleware ValidateJti

- [x] 3.1 Buat `App\Http\Middleware\ValidateJti`: pada setiap request yang melewati middleware ini, ekstrak JWT dari header `Authorization: Bearer ...`, ambil `jti` dari payload, periksa ke `JtiService::exists($jti)`. Jika tidak ada → return 401 generic.
- [x] 3.2 Daftarkan `ValidateJti` di `app/Http/Kernel.php` (atau `bootstrap/app.php` jika Laravel 11) di kelompok middleware `api`.
- [x] 3.3 Pastikan endpoint `POST /auth/login`, `POST /auth/register`, dan `POST /auth/refresh` dikecualikan dari middleware `ValidateJti` (karena belum ada valid JTI saat login).

## 4. Backend — Rate Limiting

- [x] 4.1 Tambahkan route throttle di `routes/api.php`: `Route::post('auth/login', [...])::middleware('throttle:5,1')` (5 requests per 1 menit per IP) dan `Route::post('auth/refresh', [...])::middleware('throttle:10,1')`.
- [x] 4.2 Pastikan throttle response mengembalikan HTTP 429 dengan header `Retry-After`.

## 5. Backend — Audit Logging

- [x] 5.1 Buat `App\Models\AuthLog` dengan fillable: `user_id`, `action`, `ip_address`, `user_agent`.
- [x] 5.2 Update `AuthService::login()` / `AuthController::login()` — setelah sukses, panggil `AuthLog::create(['user_id' => $user->id, 'action' => 'login', 'ip_address' => $request->ip(), 'user_agent' => $request->userAgent()])`. Untuk login gagal, log `action = 'login_failed'` dengan `user_id = null`.
- [x] 5.3 Update `AuthService::logout()` / `AuthResponder` — log `action = 'logout'`.
- [x] 5.4 Update `AuthService::refresh()` / `AuthResponder` — log `action = 'refresh'`. Saat refresh token replay terdeteksi, log `action = 'refresh_replay_attack'`.
- [x] 5.5 Inject `Request $request` ke `AuthService` atau teruskan IP/UA dari controller ke service.

## 6. Backend — Secure Refresh Token & Rotation

- [x] 6.1 Update `AuthResponder::respondWithToken()` — tambahkan cookie `refresh_token` dengan flags `HttpOnly; Secure; SameSite=Strict; Path=/api/auth`. Untuk mobile support, JUGA sertakan `refresh_token` di response body.
- [x] 6.2 Update `AuthResponder::handleRefresh()` — baca refresh token dari cookie JIKA tersedia (`$request->cookie('refresh_token')`), fallback ke request body untuk mobile. Setelah refresh berhasil: `JtiService::revoke($oldJti)`, buat token baru, `JtiService::store($newJti, $ttl)`.
- [x] 6.3 Implementasikan deteksi replay attack: jika refresh token yang digunakan tidak ditemukan di database (sudah dirotasi), segera hapus semua session user tersebut (force logout seluruh device) dan log sebagai `refresh_replay_attack`.
- [x] 6.4 Update `AuthResponder::handleLogout()` — tambahkan `JtiService::revoke($jti)` setelah menghapus session. Revoke semua JTI aktif untuk user ini jika tersedia.

## 7. Backend — Cleanup Errors & Generic Messages

- [x] 7.1 Audit `AuthController::login()` dan `AuthService::login()` — pastikan response 401 hanya mengembalikan pesan generik (contoh: `"Authentication failed."`) baik saat user tidak ditemukan maupun password salah.
- [x] 7.2 Update `AuthController::register()` — pastikan validasi error tidak mengekspos informasi sensitif.

## 8. Frontend — Dependencies

- [x] 8.1 Update `frontend/pubspec.yaml` — tambah `dio: ^5.7.0` dan `flutter_secure_storage: ^9.2.2`. Hapus `shared_preferences` dari auth-related code (boleh tetap ada untuk non-auth preferences).
- [x] 8.2 Jalankan `flutter pub get`.

## 9. Frontend — Rewrite ApiService ke Dio

- [x] 9.1 Buat `frontend/lib/services/dio_client.dart` — singleton `DioClient` dengan `BaseOptions` (baseUrl, connectTimeout, receiveTimeout). Tambah `InterceptorsWrapper`:
  - `onRequest`: baca access token dari `flutter_secure_storage`, tambahkan ke header `Authorization: Bearer $token`.
  - `onError`: jika `error.response?.statusCode == 401` dan bukan endpoint `/auth/refresh`, panggil `_refreshToken()`. Jika berhasil, retry request. Jika gagal, `_forceLogout()`.
- [x] 9.2 Implementasi `_refreshToken()` di `DioClient` — gunakan `Dio` tanpa interceptor (inner Dio) untuk menghindari infinite loop. Baca `refresh_token` dari `flutter_secure_storage`, POST ke `/auth/refresh`, simpan token baru ke `flutter_secure_storage`.
- [x] 9.3 Implementasi concurrency lock — gunakan `Completer<bool>` untuk memastikan hanya satu refresh berlangsung sekaligus. Request lain yang mendapat 401 bersamaan menunggu hasil refresh yang sama.
- [x] 9.4 Update `frontend/lib/services/api_service.dart` — ubah semua method (`get`, `post`, `put`, `patch`, `delete`) untuk menggunakan `DioClient.instance.dio` sebagai pengganti `http.Client`.

## 10. Frontend — Secure Token Storage

- [x] 10.1 Buat `frontend/lib/services/secure_storage_service.dart` — wrapper di atas `FlutterSecureStorage` dengan method: `saveToken(String token)`, `getToken()`, `saveRefreshToken(String token)`, `getRefreshToken()`, `clearAll()`.
- [x] 10.2 Update `frontend/lib/services/auth_service.dart` — ganti semua `SharedPreferences` calls untuk token ke `SecureStorageService`. `login()` simpan `access_token` dan `refresh_token` ke secure storage. `logout()` panggil `SecureStorageService.clearAll()`.
- [x] 10.3 Update `DioClient` untuk menggunakan `SecureStorageService` (bukan `SharedPreferences`) saat membaca/menulis token.

## 11. Verifikasi & Testing

- [x] 11.1 Jalankan `php artisan migrate:fresh --seed` untuk memastikan semua migration berjalan, termasuk `auth_logs`.
- [x] 11.2 Test login: verifikasi JWT header mengandung `alg: RS256`, payload hanya berisi `sub`, `role`, `permissions`, `jti`.
- [x] 11.3 Test JTI di Redis: setelah login, periksa `redis-cli GET jti:{jti_value}` — harus ada. Setelah logout, harus hilang.
- [x] 11.4 Test rate limiting: kirim >5 request ke `/auth/login` dalam 1 menit → harus dapat 429.
- [x] 11.5 Test refresh token rotation: gunakan refresh token untuk refresh → berhasil. Gunakan refresh token yang sama lagi → harus 401.
- [x] 11.6 Test replay attack: setelah rotasi, coba gunakan token lama → pastikan semua session user dihapus.
- [x] 11.7 Test Flutter Dio interceptor: simulasi 401 response dari server → pastikan token di-refresh otomatis dan request di-retry tanpa user tahu.
- [x] 11.8 Verifikasi `auth_logs` terisi dengan benar untuk login, logout, refresh, dan login_failed.
