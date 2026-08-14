<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class AvatarController extends Controller
{
    /**
     * Sajikan file avatar dari public/avatars atau storage/avatar.
     * Route ini lewat middleware CORS (api/*) sehingga gambar bisa dimuat
     * dari Flutter Web yang berjalan di origin berbeda.
     */
    public function show(Request $request, string $file): BinaryFileResponse
    {
        if (!preg_match('/^[a-zA-Z0-9_\-\.]+\.(jpg|jpeg|png|gif|webp|svg|heic)$/i', $file)) {
            abort(404);
        }

        // Cari di beberapa lokasi penyimpanan avatar
        $possiblePaths = [
            public_path('avatars/' . $file),
            storage_path('app/public/avatar/' . $file),
            storage_path('app/public/avatars/' . $file),
            public_path('storage/avatar/' . $file),
            public_path('storage/avatars/' . $file),
        ];

        $path = null;
        foreach ($possiblePaths as $p) {
            if (file_exists($p)) {
                $path = $p;
                break;
            }
        }

        if (!$path) {
            abort(404);
        }

        $mime = match (strtolower(pathinfo($file, PATHINFO_EXTENSION))) {
            'png' => 'image/png',
            'gif' => 'image/gif',
            'webp' => 'image/webp',
            'svg' => 'image/svg+xml',
            default => 'image/jpeg',
        };

        return response()->file($path, [
            'Content-Type' => $mime,
            'Cache-Control' => 'public, max-age=31536000',
        ]);
    }
}
