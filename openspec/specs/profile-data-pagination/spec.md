## ADDED Requirements

### Requirement: Profile Data Pagination and Filtering
Sistem HARUS memecah respons data besar (misalnya, transaksi, history, atau riwayat pengguna) menggunakan paginasi, dan HARUS mendukung *filtering* parameter (seperti `?year=2026`) untuk membatasi ukuran respons endpoint.

#### Scenario: Fetching paginated profile history
- **WHEN** pengguna melakukan request ke rute data history profil dengan parameter `page=1` dan `year=2026`
- **THEN** sistem mengembalikan data dalam format paginasi, dengan maksimal *N* item per halaman yang difilter khusus untuk tahun 2026.
