# 📋 Aturan Standar Prompt AI, Data Berbasis Database, & Migrasi Baru

Dokumen ini berisi aturan wajib bagi seluruh developer dan AI Coding Assistant (Antigravity, Gemini, Claude, Copilot, Codex, dll.) setiap kali mengerjakan prompt, fitur, perbaikan bug, pembuatan data dummy, maupun perubahan struktur database di repositori Kreavana.

---

## 1. Wajib Membaca Aturan Terlebih Dahulu (`Baca Aturan Dulu`)

Sebelum membaca codebase secara luas, merancang solusi, mengedit file, membuat data dummy, ataupun menjalankan perintah Git pada **setiap prompt baru**:

1. **WAJIB membaca file aturan proyek terlebih dahulu**:
   - File root: `GEMINI.md`, `AGENTS.md`, `CLAUDE.md`, `.claude/CLAUDE.md`
   - Folder aturan agent: seluruh file di `.agent/rules/*.md`
   - Folder aturan GitHub/Copilot: `.github/copilot-instructions.md` dan seluruh file di `.github/rules/*.md`
2. Dilarang mengabaikan aturan yang berlaku atau membuat alur kerja sendiri yang bertentangan dengan aturan Git Workflow, RBAC & Routing (`1 Page = 1 Route`), arsitektur `users_api` (IAM/S2S HMAC), serta aturan database pada dokumen ini.
3. Lakukan pengecekan ulang terhadap checklist di akhir sesi sebelum commit dan melaporkan hasil ke pengguna.

---

## 2. Data Dummy Wajib Berdasarkan Database (DILARANG Mockup Frontend)

Seluruh tampilan di aplikasi (kartu ringkasan, daftar, tabel, dropdown, detail program/proyek/magang, maupun status) **WAJIB bersumber dari database nyata** melalui API `backend` / `users_api`, bukan data rekaan di UI.

1. **Larangan Keras**:
   - ❌ **DILARANG** membuat array/list dummy statis, mockup hardcoded, fake JSON, atau data cadangan (*fallback sample data*) di widget Flutter, provider, service frontend, maupun controller API (misal: `_mockPrograms`, `_dummyStudents`, atau return array statis saat tabel kosong).
   - Apabila data di database memang belum ada (kosong), API wajib mengembalikan dataset kosong (`[]`, total `0`) dan frontend menampilkan *empty state* yang jujur — bukan menambalnya dengan data mockup.
2. **Prosedur Pembuatan Data Dummy / Contoh yang Benar**:
   - Jika pengguna meminta atau sistem membutuhkan data dummy/demo/testing, buatlah data tersebut **langsung di database** melalui Laravel Seeder (`backend/database/seeders/` atau `users_api/database/seeders/`), Model Factory, atau record database/API yang valid.
   - Struktur isi seeder wajib mengikuti skema tabel asli di database (nama kolom, tipe data, enum status, serta relasi foreign key antar tabel seperti user, institution, corporate, vacancy, application, dst.).
   - Setiap tampilan daftar data dari database tetap mengikuti ketentuan paginasi yang konsisten (mis. `AppPaginationBar` / respons pagination API).

---

## 3. Perubahan Struktur Database Wajib Membuat Migrasi Baru

Riwayat migrasi database bersifat *append-only* (hanya bertambah maju). Mengedit file migrasi lama akan merusak sinkronisasi skema di environment lokal, server `dev`, maupun produksi yang sudah pernah menjalankan `php artisan migrate`.

1. **Larangan Keras**:
   - ❌ **DILARANG** mengubah, menyisipkan kolom, mengganti enum, atau menghapus baris di dalam file migrasi yang sudah ada di `backend/database/migrations/` atau `users_api/database/migrations/`.
2. **Prosedur Wajib Saat Mengedit Tabel Database yang Sudah Ada**:
   - Setiap kali ingin menambah kolom, mengubah tipe/panjang/enum kolom, mengganti nama kolom, menghapus kolom, menambah/menghapus index, atau menambah foreign key pada tabel yang sudah ada:
     1. Buat **file migrasi baru dengan timestamp terbaru** menggunakan `php artisan make:migration <nama_perubahan_deskriptif>` pada direktori service terkait (`backend/` atau `users_api/`).
     2. Tulis perubahan maju di method `up()` serta rollback aman di method `down()` (gunakan pengecekan `Schema::hasColumn(...)` / `hasTable(...)` bila diperlukan).
     3. Perbarui Model Eloquent (`$fillable`, `$casts`, relasi), Seeder, Request validation, dan Controller agar selaras dengan kolom baru.
     4. Verifikasi syntax PHP (`php -l`) dan uji skema migrasi sebelum commit.

---

## 4. Standar Keamanan Big Tech, OWASP Top 10, Audit Advisory Terbaru, & Framing Senior Cyber Security 20 Tahun

Setiap kali menambah, mengedit, atau mengaudit fitur di `backend/`, `users_api/`, maupun `frontend/` (Web & Mobile), wajib mematuhi `.github/rules/security-bigtech-and-owasp-standards.md`:
1. **Framing Wajib Saat Mengecek / Menambahkan Standar Keamanan**:
   - Gunakan selalu instruksi peran:
     > `"Anda adalah seorang senior cyber security yang berpengalaman selama 20 tahun. [konteks]"`
2. **Wajib Standar Big Tech Company & OWASP Top 10 / MASVS**:
   - Tanpa secret hardcoded, S2S HMAC *Fail-Closed*, `TrustHosts` & `EnforceJsonSecurity` aktif (tolak JSON nesting > 16, key `""`, null-byte `\0`), validasi wildcard `.*` wajib memakai `array|list|max:N`, mutasi DB wajib memakai `$validated` (dilarang `$request->all()`), serta RBAC berbasis prefix di `appRouter.redirect` & pencegahan IDOR di server.
3. **Bebas Celah Advisory & Vulnerabilities Terbaru**:
   - Pastikan tidak ada celah dari security advisory maupun CVE terbaru (`composer audit --locked` di `backend/` dan `users_api/` wajib 0 CVE).

---

## ✅ Checklist Kepatuhan AI Sebelum Mengakhiri Tugas
- [ ] Sudah membaca file aturan di `GEMINI.md`, `AGENTS.md`, `CLAUDE.md`, `.agent/rules/*.md`, `.github/rules/*.md`, dan `.github/copilot-instructions.md` sebelum mulai bekerja.
- [ ] Tidak ada array mockup atau dummy data hardcoded di frontend/UI atau controller sebagai pengganti query database.
- [ ] Seluruh data dummy yang dibuat bersumber dari dan tersimpan di database (via Seeder/Factory/DB sesuai skema asli).
- [ ] Semua perubahan pada tabel database yang sudah ada dibuat melalui **file migrasi baru** (`php artisan make:migration`), tanpa menyentuh file migrasi lama.
- [ ] Audit keamanan fitur baru/edit telah dilakukan dengan perspektif `"Anda adalah seorang senior cyber security yang berpengalaman selama 20 tahun. [konteks]"`, sesuai standar Big Tech, OWASP Top 10, dan bebas advisory/vulnerabilities terbaru.
- [ ] Seluruh file PHP lolos `php -l` dan pengujian/migrasi relevan terverifikasi.
