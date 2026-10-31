# Panduan Kontribusi & Alur Git Kreavana (Contributing Guidelines)

Selamat datang di proyek **Kreavana**. Seluruh kontributor (Developer, Engineer, dan AI Assistant) wajib mematuhi aturan kerja Git di bawah ini agar riwayat commit tetap rapi, aman, dan tidak menimpa pekerjaan anggota tim lain.

---

## Aturan Standar Git Push & Merge

Setiap kali melakukan pembaruan kode:

1. **Pull Branch Utama Terlebih Dahulu**
   ```bash
   git checkout main
   git pull origin main
   ```
2. **Buat Branch Baru**
   ```bash
   git checkout -b <tipe>/<nama-tugas>
   # Contoh: git checkout -b fix/auth-token-refresh
   ```
3. **Commit Pekerjaan di Branch Baru**
   ```bash
   git add <file>
   git commit -m "tipe: pesan commit deskriptif"
   ```
4. **Sinkronisasi & Merge Lokal dari Main Sebelum Push**
   ```bash
   git checkout main
   git pull origin main
   git checkout <tipe>/<nama-tugas>
   git merge main
   ```
5. **Push ke Branch Baru di Origin**
   ```bash
   git push -u origin <tipe>/<nama-tugas>
   ```
6. **Merge Lokal ke Main & Push ke Origin Main**
   ```bash
   git checkout main
   git pull origin main
   git merge <tipe>/<nama-tugas>
   git push origin main
   ```

---

## Larangan
* Dilarang push langsung ke branch baru tanpa pull `main` terbaru dan merge lokal.
* Dilarang push ke `main` tanpa melakukan pull `main` terlebih dahulu.
* Dilarang melakukan force-push (`git push -f`) ke `main`.
