# 📦 Panduan Instalasi & Konfigurasi MinIO di VPS Ubuntu (Kreavana)

Dokumen ini adalah panduan lengkap langkah-demi-langkah untuk menginstal, mengonfigurasi, mengamankan (SSL/HTTPS via Nginx), dan menghubungkan **MinIO Object Storage** (kompatibel S3) dengan backend **Kreavana (Laravel)** di server VPS Linux Ubuntu.

---

## 📑 Daftar Isi
1. [Pengantar MinIO di Kreavana](#1-pengantar-minio-di-kreavana)
2. [Prasyarat Server VPS Ubuntu](#2-prasyarat-server-vps-ubuntu)
3. [Metode Instalasi A: Binary Native & Systemd (Rekomendasi)](#3-metode-instalasi-a-binary-native--systemd-rekomendasi)
4. [Metode Instalasi B: Docker & Docker Compose](#4-metode-instalasi-b-docker--docker-compose)
5. [Konfigurasi Reverse Proxy Nginx & SSL Certbot](#5-konfigurasi-reverse-proxy-nginx--ssl-certbot)
6. [Setup Bucket & Kredensial di MinIO Console](#6-setup-bucket--kredensial-di-minio-console)
7. [Integrasi dengan Backend Laravel Kreavana](#7-integrasi-dengan-backend-laravel-kreavana)
8. [Pengujian & Verifikasi](#8-pengujian--verifikasi)

---

## 1. Pengantar MinIO di Kreavana

MinIO adalah server object storage open-source berkinerja tinggi yang 100% kompatibel dengan Amazon S3 API. Dengan mengintegrasikan MinIO:
- **Penyimpanan Terpusat & Terisolasi:** File media (avatar, poster acara, dokumen KYC, lampiran chat, bukti hasil kerja) tidak lagi membebani folder aplikasi lokal atau web server.
- **Biaya Nol / Gratis Lisensi:** MinIO bersifat self-hosted dan gratis (AGPLv3), tidak ada biaya per-request atau per-gigabyte seperti AWS S3.
- **Skalabilitas:** Kapasitas penyimpanan hanya dibatasi oleh ukuran storage VPS/Disk server Anda (misal disk VPS 80GB, block storage tambahan, dsb.).

---

## 2. Prasyarat Server VPS Ubuntu

- VPS Ubuntu 20.04 / 22.04 / 24.04 LTS dengan akses `root` atau `sudo`.
- Domain / Subdomain yang sudah diarahkan (DNS A Record) ke IP VPS Anda, contoh:
  - `storage.kreavana.com` ➔ diarahkan ke IP VPS (untuk S3 API Port 9000)
  - `console.storage.kreavana.com` ➔ diarahkan ke IP VPS (untuk Web Dashboard Port 9001)
- Port firewall terbuka:
  - `80/tcp` dan `443/tcp` (HTTP/HTTPS Nginx)
  - Port `9000` & `9001` (hanya perlu diakses lokal oleh Nginx reverse proxy).

---

## 3. Metode Instalasi A: Binary Native & Systemd (Rekomendasi)

Metode ini sangat ringan karena berjalan langsung sebagai service native Linux tanpa overhead container.

### Langkah 1: Unduh Binary MinIO Server
```bash
sudo apt update && sudo apt install -y wget curl
wget https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
sudo mv minio /usr/local/bin/
```

### Langkah 2: Buat User Sistem Khusus & Direktori Data
```bash
# Buat user sistem 'minio-user' tanpa akses login shell demi keamanan
sudo useradd -r minio-user -s /sbin/nologin

# Buat direktori penyimpanan data storage
sudo mkdir -p /var/minio/data
sudo chown -R minio-user:minio-user /var/minio

# Buat direktori konfigurasi lingkungan
sudo mkdir -p /etc/minio
sudo chown -R minio-user:minio-user /etc/minio
```

### Langkah 3: Konfigurasi File Lingkungan MinIO
Buat file konfigurasi `/etc/minio/minio.conf`:
```bash
sudo nano /etc/minio/minio.conf
```
Isi dengan konfigurasi berikut:
```ini
# Direktori data penyimpanan
MINIO_VOLUMES="/var/minio/data"

# Port API S3 (9000) dan Web Console (9001)
MINIO_OPTS="--address 127.0.0.1:9000 --console-address 127.0.0.1:9001"

# Kredensial Superadmin Awal (Ubah password ini!)
MINIO_ROOT_USER=kreavana_root_admin
MINIO_ROOT_PASSWORD=KreavanaSuperSecretPassword2026!

# URL Public S3 Server jika berada di balik reverse proxy
MINIO_SERVER_URL="https://storage.kreavana.com"
MINIO_BROWSER_REDIRECT_URL="https://console.storage.kreavana.com"
```
Amankan hak akses file:
```bash
sudo chown minio-user:minio-user /etc/minio/minio.conf
sudo chmod 600 /etc/minio/minio.conf
```

### Langkah 4: Buat Service Systemd
Buat file `/etc/systemd/system/minio.service`:
```bash
sudo nano /etc/systemd/system/minio.service
```
Isi dengan:
```ini
[Unit]
Description=MinIO Object Storage
Documentation=https://min.io/docs/minio/linux/index.html
Wants=network-online.target
After=network-online.target

[Service]
User=minio-user
Group=minio-user
ProtectProc=invisible
EnvironmentFile=/etc/minio/minio.conf
ExecStart=/usr/local/bin/minio server $MINIO_OPTS $MINIO_VOLUMES
Restart=always
RestartSec=5
LimitNOFILE=65536
TasksMax=infinity
TimeoutStopSec=infinity
SendSIGKILL=no

[Install]
WantedBy=multi-user.target
```

### Langkah 5: Jalankan & Aktifkan Service
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now minio
sudo systemctl status minio
```

---

## 4. Metode Instalasi B: Docker & Docker Compose

Jika server Anda menggunakan Docker:

Buat direktori dan file `docker-compose.yml`:
```bash
mkdir -p ~/minio && cd ~/minio
nano docker-compose.yml
```
Isi konfigurasi:
```yaml
version: '3.8'

services:
  minio:
    image: quay.io/minio/minio:latest
    container_name: kreavana-minio
    restart: always
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: kreavana_root_admin
      MINIO_ROOT_PASSWORD: KreavanaSuperSecretPassword2026!
      MINIO_SERVER_URL: "https://storage.kreavana.com"
      MINIO_BROWSER_REDIRECT_URL: "https://console.storage.kreavana.com"
    ports:
      - "127.0.0.1:9000:9000"
      - "127.0.0.1:9001:9001"
    volumes:
      - ./data:/data
```
Jalankan dengan perintah:
```bash
docker compose up -d
```

---

## 5. Konfigurasi Reverse Proxy Nginx & SSL Certbot

Agar MinIO dapat diakses dengan protokol `https://` yang aman dan tanpa port rumit, gunakan Nginx reverse proxy.

### Langkah 1: Buat Virtual Host Nginx
```bash
sudo nano /etc/nginx/sites-available/minio.conf
```
Isi konfigurasi berikut:
```nginx
# 1. MinIO S3 API (storage.kreavana.com) -> Port 9000
server {
    server_name storage.kreavana.com;

    # Izinkan upload file besar tanpa terpotong
    client_max_body_size 100M;
    client_body_buffer_size 128k;

    # Nonaktifkan buffer transfer untuk streaming cepat
    proxy_buffering off;
    proxy_request_buffering off;

    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 300;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        chunked_transfer_encoding off;
    }
}

# 2. MinIO Web Console (console.storage.kreavana.com) -> Port 9001
server {
    server_name console.storage.kreavana.com;

    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:9001;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-NginX-Proxy true;

        # Mendukung WebSocket untuk MinIO Console
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        chunked_transfer_encoding off;
    }
}
```

Aktifkan konfigurasi dan uji Nginx:
```bash
sudo ln -s /etc/nginx/sites-available/minio.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Langkah 2: Pasang Sertifikat SSL Gratis (Certbot)
```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d storage.kreavana.com -d console.storage.kreavana.com
```
Pilih opsi pengalihan otomatis ke HTTPS (*Redirect*).

---

## 6. Setup Bucket & Kredensial di MinIO Console

1. Buka browser dan kunjungi: `https://console.storage.kreavana.com`.
2. Login menggunakan kredensial root:
   - **Username:** `kreavana_root_admin`
   - **Password:** `KreavanaSuperSecretPassword2026!`
3. **Buat Bucket:**
   - Masuk ke menu **Buckets** ➔ klik **Create Bucket**.
   - Masukkan nama bucket: `kreavana`.
   - Klik **Create Bucket**.
4. **Atur Policy Download Publik:**
   - Klik pada bucket `kreavana` ➔ menu **Access Policy**.
   - Ubah dari `Private` ke `Public` atau buat aturan prefix (`custom policy`) agar file aset seperti poster/avatar dapat diakses publik via URL langsung:
     - Policy: `Prefix: *` ➔ `Access: Read-Only` (atau Read & Write jika ingin upload langsung).
5. **Buat Access Key & Secret Key untuk Backend:**
   - Masuk ke menu **Access Keys** ➔ klik **Create access key**.
   - Sistem akan menampilkan:
     - **Access Key:** (contoh: `uR3xABCD1234EFGH`)
     - **Secret Key:** (contoh: `xyz987654321AbcdEfghIjklMnopQrstUvwxYz`)
   - Simpan kredensial ini untuk diisikan ke `.env` Laravel.

---

## 7. Integrasi dengan Backend Laravel Kreavana

Di server aplikasi Kreavana (atau di komputer lokal Anda):

### 1. Perbarui File `.env`
Buka file `.env` di folder `backend/`:
```env
# Aktifkan MinIO sebagai storage driver default
FILESYSTEM_DISK=minio

# Konfigurasi Kredensial MinIO
MINIO_KEY=uR3xABCD1234EFGH
MINIO_SECRET=xyz987654321AbcdEfghIjklMnopQrstUvwxYz
MINIO_REGION=us-east-1
MINIO_BUCKET=kreavana

# Endpoint API S3 MinIO
MINIO_ENDPOINT=https://storage.kreavana.com

# URL Publik untuk mengakses file langsung
MINIO_URL=https://storage.kreavana.com/kreavana

# Wajib TRUE untuk MinIO
MINIO_USE_PATH_STYLE_ENDPOINT=true
```

### 2. Bersihkan & Cache Konfigurasi Laravel
```bash
php artisan config:clear
php artisan cache:clear
php artisan config:cache
```

---

## 8. Pengujian & Verifikasi

Uji integrasi MinIO dengan Tinker:
```bash
php artisan tinker
```
Jalankan perintah berikut di console tinker:
```php
// 1. Simpan file pengujian ke bucket MinIO
Storage::disk('minio')->put('test.txt', 'Integrasi MinIO Kreavana Berhasil!');

// 2. Cek apakah file ada di MinIO
Storage::disk('minio')->exists('test.txt'); // output: true

// 3. Cek URL publik file
Storage::disk('minio')->url('test.txt');
// output: https://storage.kreavana.com/kreavana/test.txt

// 4. Hapus file pengujian
Storage::disk('minio')->delete('test.txt');
```

Selamat! Sistem penyimpanan object storage MinIO Anda kini telah aktif, aman dengan HTTPS, dan terintegrasi penuh dengan seluruh fitur upload di platform **Kreavana**.
