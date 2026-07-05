## ADDED Requirements

### Requirement: Creator Sub-Roles
Sistem HARUS memungkinkan pengguna dengan role `creator` untuk memiliki `sub_role` yang spesifik (contoh: pemerintah, event_organizer, wedding_organizer). Nilai-nilai ini HARUS didukung oleh validasi Enum di backend.

#### Scenario: Assigning a sub-role to a creator
- **WHEN** seorang pengguna mendaftar atau diperbarui sebagai `creator` dan memilih `sub_role` (misalnya, `event_organizer`)
- **THEN** sistem menyimpan informasi `sub_role` tersebut pada tabel pengguna dan mengembalikannya saat rute profil dipanggil.

### Requirement: Dedicated Sub-Role Route
Sistem HARUS menyediakan endpoint terpisah untuk mengambil dan mengelola daftar sub-role yang tersedia untuk memastikan kepatuhan terhadap standar OWASP dan pemisahan *concern* (microservices).

#### Scenario: Fetching available sub-roles
- **WHEN** frontend meminta data sub-role yang tersedia melalui rute khusus (misalnya, `/api/roles/creator/sub-roles`)
- **THEN** sistem mengembalikan daftar semua `sub_role` yang valid yang didefinisikan dalam Enum backend.
