## 1. Migrasi Database & UUID

- [x] 1.1 Buat dan jalankan skrip migrasi untuk mengubah tipe `users.id` menjadi tipe `uuid` (atau `string` yang memadai).
- [x] 1.2 Sesuaikan seluruh tabel terkait (seperti `wallet_transactions`, `creator_applications`, dsb) yang memiliki *foreign key* `user_id` agar bertipe `uuid` yang selaras.

## 2. Implementasi Backend API

- [x] 2.1 Refactor file `routes/api.php` agar menerapkan rute REST API yang granular (pisahkan operasi `GET`, `POST`, `PUT`, `DELETE` ke semua rute sumber daya masing-masing, hindari route gemuk/monolitik (pastikan response time < 300ms, jika tidak maka refactor lagi)). Termasuk endpoint mandiri untuk *roles*.
- [x] 2.2 Gabungkan endpoint autentikasi menjadi satu rute sentral `/api/auth/login` (atau sejenisnya) dan hapus pemisahan berdasarkan nama role di rute.
- [x] 2.3 Perbarui logika `AuthController` terpadu agar mengembalikan payload respons minimal berupa `access_token` beserta objek user berisi `name`, `username`, `email`, dan `role`. Untuk `uid` users itu bersifat hidden di frontend, jadi tidak perlu dikembalikan.

## 3. Penyesuaian Frontend (Flutter)

- [x] 3.1 Ubah properti `id` (integer) pada `UserModel` menjadi `uid` atau `id` (String) untuk mengakomodasi tipe UUID.
- [x] 3.2 Perbarui `AuthService` atau halaman login agar menembak endpoint `/api/auth/login` terpadu alih-alih merouting berdasarkan role.
- [x] 3.3 Pastikan *parsing* respons mengolah data role dari backend dengan benar agar aplikasi dapat menentukan menu (user/kreator/admin) tanpa harus *fetch* seluruh detail profil terlebih dahulu.

## 4. Pengujian & Verifikasi

- [x] 4.1 Uji jalannya *database migrations* dengan aman tanpa menghilangkan integritas referensial (*foreign key checks*).
- [x] 4.2 Lakukan pemanggilan API (misal menggunakan cURL atau Postman/Test) untuk login dan memverifikasi *granular endpoints* berfungsi baik dengan payload ringan.
- [x] 4.3 Uji alur masuk di Frontend (Flutter) untuk memastikan login, manajemen status, dan *routing* aplikasi (tergantung *role*) berjalan sempurna dengan UUID.
