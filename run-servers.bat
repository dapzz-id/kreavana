@echo off
title Kreavana Services Launcher
echo ========================================================
echo   MENJALANKAN LAYANAN BACKEND KREAVANA
echo ========================================================
echo.
echo [1/2] Menjalankan Kreavana Core Backend di Port 8000...
start "Kreavana Core Backend (Port 8000)" cmd /k "cd /d %~dp0backend && php artisan serve --port=8000"

echo [2/2] Menjalankan Users API (Identity IAM) di Port 8001...
start "Kreavana Users API (Port 8001)" cmd /k "cd /d %~dp0users_api && php artisan serve --port=8001"

echo.
echo ========================================================
echo   Semua server telah dibuka di jendela masing-masing!
echo   - Backend Utama : http://127.0.0.1:8000
echo   - Users API     : http://127.0.0.1:8001
echo ========================================================
pause

