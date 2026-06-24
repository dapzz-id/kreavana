# Kreavana

## Panduan Menjalankan Backend
1. Untuk menjalankan realtime jalankan `php artisan reverb:start`
2. Untuk menjalankan fitur Voice Call dan Video Call gunakan docker dengan perintah `docker compose up` dan ganti IP Coturn dengan IP Local kamu pada file `coturn/turnserver.conf`.
3. Jalankan dengan host=0.0.0.0 dengan perintah `php artisan serve --host=0.0.0.0 --port=8000`
4. Pastikan API Key Pusher/Reverb di Flutter pada file `lib/services/api_service.dart` sudah sesuai dengan API Key Pusher di Laravel pada file `.env`.

## Panduan Menjalankan Frontend
1. Untuk menjalankan frontend jalankan `flutter run`
2. Ganti IP pada file `lib/services/api_service.dart` dengan IP Local kamu.

## Panduan Build APK
1. Menggunakan kode `flutter build apk --obfuscate --split-debug-info=./debug_info --release --android-skip-build-dependency-validation` untuk build apk rilis.
2. Menggunakan kode `flutter build apk --debug` untuk build apk debug.
3. Menggunakan kode `flutter build appbundle --obfuscate --split-debug-info=./debug_info --release --android-skip-build-dependency-validation` untuk build appbundle rilis.
4. Menggunakan kode `flutter build appbundle --debug` untuk build appbundle debug.