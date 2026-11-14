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

