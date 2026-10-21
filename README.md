# Kreavana

## Panduan Menjalankan Backend

1. Untuk menjalankan realtime jalankan `php artisan reverb:start`
2. Untuk menjalankan fitur Voice Call dan Video Call gunakan docker dengan perintah `docker compose up` dan ganti IP Coturn dengan IP Local kamu pada file `coturn/turnserver.conf`.
3. Jalankan dengan host=0.0.0.0 dengan perintah `php artisan serve --host=0.0.0.0 --port=8000`
4. Pastikan API Key Pusher/Reverb di Flutter pada file `lib/services/api_service.dart` sudah sesuai dengan API Key Pusher di Laravel pada file `.env`.

## Panduan Menjalankan Universal Identity Service (users_api)

1. Masuk ke direktori service: `cd users_api`
2. Install dependensi dengan perintah `composer install`
3. Salin file konfigurasi environment: `cp .env.example .env` (sesuaikan konfigurasi database lokal kamu).
4. Generate Application Key dan JWT Secret Key:
   - `php artisan key:generate`
   - `php artisan jwt:secret --force`
5. Jalankan migrasi database dan seeder akun universal: `php artisan migrate --seed`
6. Jalankan service dengan port 8001: `php artisan serve --host=0.0.0.0 --port=8001`
7. Cek endpoint untuk memverifikasi service:
   - Health check: `http://127.0.0.1:8001/api/health`
   - OpenID SSO Discovery: `http://127.0.0.1:8001/api/.well-known/openid-configuration`
   - Endpoints Auth: `/api/v1/auth/login`, `/api/v1/auth/register`, `/api/v1/auth/social`

## Panduan Menjalankan Frontend

1. Untuk menjalankan frontend jalankan `flutter run`
2. Ganti IP pada file `lib/services/dio_client.dart` dengan IP Local kamu.
3. Jika ingin menjalankan web menggunakan hasil build. Ubah path terminal agar masuk ke folder `frontend/build/web`, dan gunakan kode berikut: `npx serve -s -l tcp://127.0.0.1:5001`. Pastikan kamu sudah menginstall NodeJS di perangkatmu.

## Panduan Build APK/AAB/WEB

1. Menggunakan kode `flutter build apk --obfuscate --split-debug-info=./debug_info --release --android-skip-build-dependency-validation` untuk build apk rilis.
2. Menggunakan kode `flutter build apk --debug` untuk build apk debug.
3. Menggunakan kode `flutter build appbundle --obfuscate --split-debug-info=./debug_info --release --android-skip-build-dependency-validation` untuk build appbundle rilis.
4. Menggunakan kode `flutter build appbundle --debug` untuk build appbundle debug.
5. Menggunakan kode `flutter build web` untuk build web for production.
6. Menggunakan kode `flutter build web --dart-define=ENV=development` untuk build web for debug.
