## Why

Optimalisasi performa server dan keamanan adalah hal yang krusial untuk aplikasi berskala besar. Saat ini, endpoint `/api/auth/me` atau endpoint profil mengembalikan data user secara utuh yang dapat membebani server jika datanya sangat besar. Selain itu, sejalan dengan arsitektur microservices dan panduan keamanan OWASP, pemisahan rute berdasarkan fungsi dan *role* akan membatasi akses secara ketat dan mengurangi beban pada satu rute monolitik. Terakhir, kebutuhan untuk mengategorikan kreator secara lebih spesifik (seperti pemerintah, event organizer, dll) mengharuskan adanya fitur *sub-role* yang dinamis.

## What Changes

- **Penerapan Payload Auth Minimal di Frontend**: Menyesuaikan frontend agar dapat memproses respons login yang minimal (hanya `access_token` dan data user dasar) dan mengambil profil lengkap secara terpisah jika diperlukan.
- **Optimalisasi Endpoint Profil**: Memecah pengembalian data besar pada `/auth/user/me` menjadi bagian-bagian yang lebih kecil, menambahkan filter (contoh: berdasarkan tahun), dan fitur paginasi.
- **Pemisahan Rute Microservices (OWASP)**: Memisahkan rute secara spesifik berdasarkan fungsionalitasnya (misalnya: rute khusus untuk mengambil *role*, rute khusus token, dan rute khusus *sub-role*).
- **Penambahan Fitur Sub-Role Kreator**: Menambahkan entitas/kolom *sub-role* dinamis untuk *role* kreator (contoh: pemerintah, event_organizer, wedding_organizer) di backend (menggunakan Enum Laravel) beserta rute pengelolaannya tersendiri.

## Capabilities

### New Capabilities
- `creator-sub-roles`: Fitur pengelolaan dan pengambilan *sub-role* khusus untuk pengguna dengan role kreator, didukung oleh Enum dan rute spesifik.
- `profile-data-pagination`: Fitur paginasi dan penyaringan data (seperti berdasarkan tahun) untuk pengambilan data profil atau data terkait user yang berskala besar.

### Modified Capabilities
- `auth-response-optimization`: Perubahan cara frontend memproses login dan cara backend menangani *fetching* data detail profil secara terpisah dengan paginasi.

## Impact

- **Frontend**: Perubahan pada *service* autentikasi dan state management profil untuk menyesuaikan dengan payload login baru dan rute profil terpisah.
- **Backend (API)**: Penambahan middleware, pembaruan pada `UserAuthController`, dan penambahan controller/rute baru untuk pengelolaan *sub-role*. Pembaruan skema database (`users` table) untuk mendukung *sub-role*.
- **Keamanan & Performa**: Peningkatan postur keamanan sesuai OWASP melalui pembatasan rute dan peningkatan performa server berkat payload yang lebih ringan dan paginasi.
