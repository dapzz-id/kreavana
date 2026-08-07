<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class AvatarController extends Controller
{
    /**
     * Sajikan file avatar dari public/avatars.
     * Route ini lewat middleware CORS (api/*) sehingga gambar bisa dimuat
     * dari Flutter Web yang berjalan di origin berbeda.
     */
    public function show(Request $request, string $file): BinaryFileResponse
    {
        if (!preg_match('/^[a-zA-Z0-9_\-\.]+\.(jpg|jpeg|png|gif|webp)$/', $file)) {
            abort(404);
        }

        $path = public_path('avatars/' . $file);

        if (!file_exists($path)) {
            abort(404);
        }

        $mime = match (pathinfo($file, PATHINFO_EXTENSION)) {
            'png' => 'image/png',
            'gif' => 'image/gif',
            'webp' => 'image/webp',
            default => 'image/jpeg',
        };

        return response()->file($path, [
            'Content-Type' => $mime,
            'Cache-Control' => 'public, max-age=31536000',
        ]);
    }
}
