<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Zero-Trust JSON API Guard (OWASP API4 / GHSA-8h64-cpq2-9h2g / GHSA-cq3g-fj94-c8p3):
 * 1. Enforces strict maximum JSON payload size.
 * 2. Enforces C-level maximum JSON nesting depth via json_validate() before memory allocation.
 * 3. Rejects empty-string object keys (""), null-bytes (\0), and excessive node/key counts.
 */
class EnforceJsonSecurity
{
    public function handle(Request $request, Closure $next): Response
    {
        $contentType = strtolower((string) $request->header('Content-Type', ''));
        if (!$request->isJson() && !str_contains($contentType, 'json')) {
            return $next($request);
        }

        $raw = $request->getContent();
        if ($raw === '') {
            return $next($request);
        }

        $maxBytes = (int) env('API_MAX_JSON_BYTES', 12 * 1024 * 1024); // 12 MB
        if (strlen($raw) > $maxBytes) {
            return response()->json([
                'status' => false,
                'message' => 'Ukuran payload JSON melebihi batas maksimum yang diizinkan.',
            ], 413);
        }

        $maxDepth = (int) env('API_MAX_JSON_DEPTH', 16);
        if (!json_validate($raw, $maxDepth)) {
            return response()->json([
                'status' => false,
                'message' => 'Payload JSON tidak valid atau melebihi batas kedalaman struktur maksimum.',
            ], 400);
        }

        $decoded = json_decode($raw, true, $maxDepth);
        if (!is_array($decoded)) {
            return $next($request);
        }

        $maxNodes = (int) env('API_MAX_JSON_NODES', 5000);
        $nodes = 0;
        $stack = [$decoded];

        while ($stack !== []) {
            $current = array_pop($stack);
            if (array_key_exists('', $current)) {
                return response()->json([
                    'status' => false,
                    'message' => 'Key JSON kosong ("") tidak diizinkan.',
                ], 422);
            }

            foreach ($current as $key => $value) {
                $nodes++;
                if ($nodes > $maxNodes) {
                    return response()->json([
                        'status' => false,
                        'message' => 'Jumlah elemen/key JSON melebihi batas keamanan maksimum.',
                    ], 422);
                }

                if (is_string($key) && str_contains($key, "\0")) {
                    return response()->json([
                        'status' => false,
                        'message' => 'Karakter ilegal terdeteksi pada key JSON.',
                    ], 422);
                }

                if (is_string($value) && str_contains($value, "\0")) {
                    return response()->json([
                        'status' => false,
                        'message' => 'Karakter null-byte tidak diizinkan pada input.',
                    ], 422);
                }

                if (is_array($value)) {
                    $stack[] = $value;
                }
            }
        }

        return $next($request);
    }
}
