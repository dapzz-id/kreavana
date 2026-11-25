# Kreavana Repository Developer & AI Agent Instructions

## 🚨 Mandatory Git Workflow Rules (STRICT ENFORCEMENT)

Setiap pengembang maupun AI Assistant yang membuat, mengubah, atau memperbarui kode pada repositori ini **WAJIB MENGIKUTI ALUR KERJA BERIKUT**:

1. **Wajib `git pull origin main` di branch `main` terlebih dahulu** sebelum membuat branch atau melakukan pekerjaan apa pun. Pastikan seluruh perubahan remote telah diambil.
2. **Buat branch baru** dari `main` yang sudah ter-update (`git checkout -b <tipe>/<nama-branch>`).
3. **Commit perubahan** di branch baru tersebut.
4. **Sebelum push ke branch baru, wajib lakukan sinkronisasi dan merge lokal dengan `main` terbaru**:
   - `git checkout main && git pull origin main`
   - `git checkout <nama-branch> && git merge main`
   - Pastikan tidak ada konflik sebelum push.
5. **Push branch baru ke remote origin**:
   - `git push -u origin <nama-branch>`
6. **Merge lokal ke `main` dan push ke `origin/main`**:
   - `git checkout main`
   - `git pull origin main` (verifikasi pull kembali)
   - `git merge <nama-branch>`
   - `git push origin main`

### Dilarang Keras:
- Jangan langsung push ke remote sebelum melakukan pull `main` terbaru dan merge lokal.
- Jangan push ke branch `main` tanpa melakukan pull `main` terlebih dahulu.
- Jangan pernah force-push (`git push -f`) ke `main`.
- **ATURAN KHUSUS CLAUDE:** Jika menggunakan Claude (Anthropic / Claude Code), **JANGAN LAKUKAN OTOMATISASI PUSH KE BRANCH ATAU MAIN** agar Claude tidak tercatat berkontribusi di GitHub. Claude hanya boleh mengedit lokal; biarkan push dieksekusi secara manual oleh pengguna atau agen Antigravity.

---

## 🔒 Mandatory Rules: Page Routing & Permission Guards (1 Page = 1 Route & Strict RBAC)

Lihat detail lengkap di `.agent/rules/page-routing-and-permissions.md` atau `.github/rules/page-routing-and-permissions.md`.

1. **1 Page = 1 Dedicated URL Route**:
   - Setiap screen/page di Kreavana WAJIB memiliki konstanta route di `AppRoutes` dan didaftarkan pada `appRouter`.
   - Dilarang membuka page utama dengan `Navigator.push` tanpa mengubah URL browser.
   - Semua navigasi WAJIB menggunakan `context.go(AppRoutes.<route>)` sehingga address bar browser selalu sinkron dan mendukung refresh (F5).
2. **Strict Route Permissions & RBAC Guarding**:
   - Seluruh route dilindungi secara terpusat di `appRouter.redirect`.
   - Tamu (guest) dilarang mengakses route terproteksi (redirect ke `/login`).
   - Admin routes (`/dashboard`, `/verifikasi`, `/resolusi`, `/admin-settings`) hanya untuk `isAdmin`.
   - Institusi (`/profil-institusi`, `/karya-siswa`) hanya untuk `isInstitution` / `isAdmin`.
   - Institusi DILARANG mengakses `/pengadaan-vendor` (khusus corporate/pemerintah).
   - Corporate (`/lowongan-corporate`, `/pengadaan-vendor`) hanya untuk `isCorporate` / `isAdmin`.
   - Workspace instansi/organisasi (`/tim-hak-akses`, `/dokumen-institusi`, `/pengumuman-institusi`, `/monitoring-evaluasi`, `/laporan-kegiatan`, `/mitra-industri`, `/realisasi-anggaran`) hanya untuk role organisasi resmi atau admin.

---

## 📋 Mandatory Rules: AI Prompt Discipline, Database-Backed Data & Migrations

Lihat detail lengkap di `.agent/rules/ai-prompt-and-database-standards.md` atau `.github/rules/ai-prompt-and-database-standards.md`.

1. **Wajib Baca Aturan Terlebih Dahulu (`Baca Aturan Dulu`)**:
   - Pada setiap prompt baru, AI **WAJIB membaca seluruh file aturan terlebih dahulu** (`GEMINI.md`, `AGENTS.md`, `CLAUDE.md`, `.claude/CLAUDE.md`, `.agent/rules/*.md`, `.github/rules/*.md`, dan `.github/copilot-instructions.md`) sebelum merancang solusi atau mengedit kode.
2. **Data Dummy Berdasarkan Database (DILARANG Mockup Frontend)**:
   - Dilarang membuat data dummy statis / array mockup hardcoded di frontend Flutter atau fallback array statis di controller API.
   - Seluruh data tampilan wajib berasal dari database nyata (`backend` / `users_api`); tampilkan *empty state* bersih jika database kosong.
   - Jika perlu membuat data dummy/demo/testing, buatlah melalui Laravel Seeder (`backend/database/seeders/`, `users_api/database/seeders/`), Factory, atau record database asli sesuai skema tabel.
3. **Edit Database Wajib Membuat Migrasi Baru**:
   - Dilarang mengedit, mengubah, atau menghapus file migrasi lama di `backend/database/migrations/` atau `users_api/database/migrations/`.
   - Setiap perubahan pada tabel database yang sudah ada (tambah/ubah/hapus kolom, enum, index, atau foreign key) **WAJIB membuat file migrasi baru** (`php artisan make:migration <nama_deskriptif>`) serta memperbarui Model/Seeder terkait dan mengecek syntax dengan `php -l`.

---

## 🛡️ Mandatory Rules: Standar Keamanan Big Tech, OWASP Top 10, & Audit Advisory Terbaru

Lihat detail lengkap di `.agent/rules/security-bigtech-and-owasp-standards.md` atau `.github/rules/security-bigtech-and-owasp-standards.md`.

1. **Wajib Standar Big Tech Company & OWASP Top 10 / MASVS di Setiap Tambah/Edit Fitur**:
   - Seluruh penambahan atau perubahan fitur di `backend/`, `users_api/`, dan `frontend/` (Web & Mobile) wajib memenuhi standar Big Tech & OWASP Top 10: tanpa secret hardcoded, S2S HMAC *Fail-Closed*, `EnforceJsonSecurity` & `TrustHosts` aktif, validasi array wildcard `.*` wajib memakai `array|list|max:N`, mutasi DB wajib eksklusif memakai `$validated` (dilarang `$request->all()`), serta proteksi IDOR & RBAC berbasis prefix.
2. **Wajib Bebas Celah Advisory & Vulnerabilities Terbaru**:
   - Pastikan tidak ada celah dari security advisory maupun CVE terbaru (`composer audit --locked` pada `backend/` & `users_api/` wajib 0 CVE).
3. **Kalimat/Framing Wajib Saat Mengecek atau Menambahkan Standar Keamanan**:
   - Setiap kali mengecek, mengaudit, atau menambahkan standar keamanan, gunakan kalimat:
     > `"Anda adalah seorang senior cyber security yang berpengalaman selama 20 tahun. [konteks]"`

