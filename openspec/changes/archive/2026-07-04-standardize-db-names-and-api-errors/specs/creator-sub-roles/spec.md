## MODIFIED Requirements

### Requirement: Creator Sub-Roles
Sistem HARUS memungkinkan pengguna dengan role `creator` untuk memiliki `sub_role` yang spesifik (contoh: pemerintah, event_organizer, wedding_organizer). Nilai-nilai ini HARUS didukung oleh validasi Enum di backend, dan disimpan dalam struktur tabel yang menggunakan penamaan bahasa Inggris (seperti `user_sub_roles`).

#### Scenario: Assigning a sub-role to a creator
- **WHEN** seorang pengguna mendaftar atau diperbarui sebagai `creator` dan memilih `sub_role` (misalnya, `event_organizer`)
- **THEN** sistem menyimpan informasi `sub_role` tersebut pada tabel `user_sub_roles` pengguna dan mengembalikannya saat rute profil dipanggil.
