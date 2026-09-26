<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\SystemSetting;
use Illuminate\Support\Facades\Http;
use Exception;

class AdminSystemSettingController extends Controller
{
    /**
     * Public module statuses for client app initialization.
     */
    public function getPublicModuleStatuses()
    {
        return response()->json([
            'status' => true,
            'data' => [
                'ai_features_enabled' => SystemSetting::get('ai_features_enabled', true),
                'marketplace_enabled' => SystemSetting::get('marketplace_enabled', true),
                'collaboration_enabled' => SystemSetting::get('collaboration_enabled', true),
                'wallet_enabled' => SystemSetting::get('wallet_enabled', true),
                'user_registration_enabled' => SystemSetting::get('user_registration_enabled', true),
                'creator_registration_enabled' => SystemSetting::get('creator_registration_enabled', true),
                'maintenance_mode' => SystemSetting::get('maintenance_mode', false),
            ],
        ]);
    }

    /**
     * GET /api/admin/modules
     * List all platform modules and their toggle states.
     */
    public function getModules()
    {
        $modules = [
            [
                'key' => 'ai_features_enabled',
                'name' => 'Kreavana AI Assistant',
                'description' => 'Fitur asisten AI cerdas untuk rekomendasi, copywriting, dan riset kreatif.',
                'enabled' => SystemSetting::get('ai_features_enabled', true),
                'category' => 'AI & Intelijen',
                'icon' => 'auto_awesome',
            ],
            [
                'key' => 'marketplace_enabled',
                'name' => 'Marketplace Karya & Jasa',
                'description' => 'Katalog etalase karya digital, aset kreatif, dan pemesanan jasa kreator.',
                'enabled' => SystemSetting::get('marketplace_enabled', true),
                'category' => 'Transaksi & Penjualan',
                'icon' => 'storefront',
            ],
            [
                'key' => 'collaboration_enabled',
                'name' => 'Kolaborasi & Manajemen Proyek',
                'description' => 'Pencarian partner kolaborasi, kontrak kerja, dan pengerjaan proyek bersama.',
                'enabled' => SystemSetting::get('collaboration_enabled', true),
                'category' => 'Kolaborasi',
                'icon' => 'handshake',
            ],
            [
                'key' => 'wallet_enabled',
                'name' => 'Sistem Dompet & Pembayaran Escrow',
                'description' => 'Dompet digital, penarikan saldo, dan rekening bersama (escrow) aman.',
                'enabled' => SystemSetting::get('wallet_enabled', true),
                'category' => 'Keuangan',
                'icon' => 'account_balance_wallet',
            ],
            [
                'key' => 'user_registration_enabled',
                'name' => 'Registrasi Pengguna Baru',
                'description' => 'Mengizinkan pengguna baru untuk mendaftar akun klien atau kreator.',
                'enabled' => SystemSetting::get('user_registration_enabled', true),
                'category' => 'Autentikasi & Akun',
                'icon' => 'person_add',
            ],
            [
                'key' => 'creator_registration_enabled',
                'name' => 'Pengajuan Upgrade Kreator',
                'description' => 'Menerima formulir pengajuan baru untuk verifikasi dan upgrade ke status kreator.',
                'enabled' => SystemSetting::get('creator_registration_enabled', true),
                'category' => 'Autentikasi & Akun',
                'icon' => 'verified',
            ],
            [
                'key' => 'maintenance_mode',
                'name' => 'Mode Pemeliharaan (Maintenance Mode)',
                'description' => 'Kunci akses publik untuk sementara waktu saat pembaruan infrastruktur sistem.',
                'enabled' => SystemSetting::get('maintenance_mode', false),
                'category' => 'Sistem & Server',
                'icon' => 'build',
            ],
        ];

        return response()->json([
            'status' => true,
            'data' => $modules,
        ]);
    }

    /**
     * PUT /api/admin/modules/{key}
     * Toggle a module state.
     */
    public function updateModule(Request $request, string $key)
    {
        $request->validate([
            'enabled' => 'required|boolean',
        ]);

        $enabled = (bool) $request->input('enabled');
        SystemSetting::set($key, $enabled, 'modules', 'boolean');

        return response()->json([
            'status' => true,
            'message' => "Status modul '{$key}' berhasil diperbarui.",
            'data' => [
                'key' => $key,
                'enabled' => $enabled,
            ],
        ]);
    }

    /**
     * GET /api/admin/ai-config
     * Retrieve AI Engine configurations (API key masked for security).
     */
    public function getAiConfig()
    {
        $apiKey = SystemSetting::get('ai_api_key', env('GEMINI_API_KEY', ''));
        $maskedKey = '';
        if (!empty($apiKey)) {
            $len = strlen($apiKey);
            if ($len > 8) {
                $maskedKey = substr($apiKey, 0, 4) . str_repeat('•', max(0, $len - 8)) . substr($apiKey, -4);
            } else {
                $maskedKey = '••••••••';
            }
        }

        $config = [
            'provider' => SystemSetting::get('ai_provider', 'gemini'),
            'api_key_masked' => $maskedKey,
            'has_api_key' => !empty($apiKey),
            'model' => SystemSetting::get('ai_model', 'gemini-1.5-flash'),
            'temperature' => (float) SystemSetting::get('ai_temperature', 0.7),
            'max_tokens' => (int) SystemSetting::get('ai_max_tokens', 2048),
            'system_prompt' => SystemSetting::get('ai_system_prompt', 'Anda adalah Kreavana AI, asisten intelijen kreatif resmi untuk platform Kreavana. Bantu kreator dan klien mengoptimalkan ide, peluang proyek, dan strategi bisnis kreatif di Indonesia.'),
            'custom_endpoint' => SystemSetting::get('ai_custom_endpoint', ''),
            'available_models' => [
                'gemini' => [
                    ['id' => 'gemini-1.5-flash', 'name' => 'Google Gemini 1.5 Flash (Cepat & Hemat Kuota)'],
                    ['id' => 'gemini-1.5-pro', 'name' => 'Google Gemini 1.5 Pro (Kemampuan Analisis Tinggi)'],
                    ['id' => 'gemini-2.0-flash', 'name' => 'Google Gemini 2.0 Flash (Next-Gen Ultrafast)'],
                    ['id' => 'gemini-2.5-flash', 'name' => 'Google Gemini 2.5 Flash'],
                ],
                'openai' => [
                    ['id' => 'gpt-4o-mini', 'name' => 'OpenAI GPT-4o Mini (Efisiensi Tinggi)'],
                    ['id' => 'gpt-4o', 'name' => 'OpenAI GPT-4o (Multimodal Flagship)'],
                    ['id' => 'gpt-3.5-turbo', 'name' => 'OpenAI GPT-3.5 Turbo (Klasik)'],
                ],
                'anthropic' => [
                    ['id' => 'claude-3-5-sonnet', 'name' => 'Anthropic Claude 3.5 Sonnet (Penulisan Kreatif Terbaik)'],
                    ['id' => 'claude-3-haiku', 'name' => 'Anthropic Claude 3 Haiku (Kecepatan Tinggi)'],
                ],
                'custom' => [
                    ['id' => 'custom-model', 'name' => 'Custom Endpoint / Local LLM (Ollama / vLLM)'],
                ],
            ],
        ];

        return response()->json([
            'status' => true,
            'data' => $config,
        ]);
    }

    /**
     * POST /api/admin/ai-config
     * Update AI Engine configuration.
     */
    public function updateAiConfig(Request $request)
    {
        $request->validate([
            'provider' => 'required|string|in:gemini,openai,anthropic,custom',
            'api_key' => 'nullable|string',
            'model' => 'required|string|max:100',
            'temperature' => 'nullable|numeric|min:0|max:2',
            'max_tokens' => 'nullable|integer|min:256|max:8192',
            'system_prompt' => 'nullable|string|max:2000',
            'custom_endpoint' => 'nullable|string|max:500',
        ]);

        SystemSetting::set('ai_provider', $request->input('provider'), 'ai');
        SystemSetting::set('ai_model', $request->input('model'), 'ai');

        if ($request->filled('api_key') && !str_contains($request->input('api_key'), '•')) {
            SystemSetting::set('ai_api_key', trim($request->input('api_key')), 'ai');
        }

        if ($request->has('temperature')) {
            SystemSetting::set('ai_temperature', (float) $request->input('temperature'), 'ai', 'float');
        }

        if ($request->has('max_tokens')) {
            SystemSetting::set('ai_max_tokens', (int) $request->input('max_tokens'), 'ai', 'integer');
        }

        if ($request->has('system_prompt')) {
            SystemSetting::set('ai_system_prompt', $request->input('system_prompt'), 'ai');
        }

        if ($request->has('custom_endpoint')) {
            SystemSetting::set('ai_custom_endpoint', $request->input('custom_endpoint'), 'ai');
        }

        return response()->json([
            'status' => true,
            'message' => 'Konfigurasi AI Engine berhasil disimpan.',
        ]);
    }

    /**
     * POST /api/admin/ai-config/test
     * Test connection to selected AI provider using provided or saved credentials.
     */
    public function testAiConnection(Request $request)
    {
        $provider = $request->input('provider') ?? SystemSetting::get('ai_provider', 'gemini');
        $model = $request->input('model') ?? SystemSetting::get('ai_model', 'gemini-1.5-flash');
        $apiKey = $request->input('api_key');

        if (empty($apiKey) || str_contains($apiKey, '•')) {
            $apiKey = SystemSetting::get('ai_api_key', env('GEMINI_API_KEY', ''));
        }

        if (empty($apiKey) && $provider !== 'custom') {
            return response()->json([
                'status' => false,
                'message' => 'API Key wajib diisi untuk melakukan pengujian koneksi.',
            ], 422);
        }

        $startTime = microtime(true);

        try {
            if ($provider === 'gemini') {
                $endpoint = "https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent?key={$apiKey}";
                $response = Http::timeout(10)->post($endpoint, [
                    'contents' => [
                        [
                            'parts' => [
                                ['text' => 'Halo! Jawab hanya dalam 1 kata: "Online"']
                            ]
                        ]
                    ]
                ]);

                $latency = round((microtime(true) - $startTime) * 1000);

                if ($response->successful()) {
                    $json = $response->json();
                    $reply = $json['candidates'][0]['content']['parts'][0]['text'] ?? 'Online';
                    return response()->json([
                        'status' => true,
                        'message' => "Koneksi ke Google Gemini ({$model}) BERHASIL!",
                        'latency_ms' => $latency,
                        'reply' => trim($reply),
                    ]);
                } else {
                    $error = $response->json()['error']['message'] ?? $response->body();
                    return response()->json([
                        'status' => false,
                        'message' => "Koneksi Google Gemini Gagal: " . substr($error, 0, 200),
                        'latency_ms' => $latency,
                    ], 400);
                }
            } elseif ($provider === 'openai') {
                $response = Http::withToken($apiKey)->timeout(10)->post('https://api.openai.com/v1/chat/completions', [
                    'model' => $model,
                    'messages' => [
                        ['role' => 'user', 'content' => 'Halo! Jawab hanya dalam 1 kata: "Online"']
                    ],
                    'max_tokens' => 10,
                ]);

                $latency = round((microtime(true) - $startTime) * 1000);

                if ($response->successful()) {
                    $json = $response->json();
                    $reply = $json['choices'][0]['message']['content'] ?? 'Online';
                    return response()->json([
                        'status' => true,
                        'message' => "Koneksi ke OpenAI ({$model}) BERHASIL!",
                        'latency_ms' => $latency,
                        'reply' => trim($reply),
                    ]);
                } else {
                    $error = $response->json()['error']['message'] ?? $response->body();
                    return response()->json([
                        'status' => false,
                        'message' => "Koneksi OpenAI Gagal: " . substr($error, 0, 200),
                        'latency_ms' => $latency,
                    ], 400);
                }
            } elseif ($provider === 'anthropic') {
                $response = Http::withHeaders([
                    'x-api-key' => $apiKey,
                    'anthropic-version' => '2023-06-01',
                    'content-type' => 'application/json',
                ])->timeout(10)->post('https://api.anthropic.com/v1/messages', [
                    'model' => $model,
                    'max_tokens' => 10,
                    'messages' => [
                        ['role' => 'user', 'content' => 'Halo! Jawab dalam 1 kata: "Online"']
                    ],
                ]);

                $latency = round((microtime(true) - $startTime) * 1000);

                if ($response->successful()) {
                    $json = $response->json();
                    $reply = $json['content'][0]['text'] ?? 'Online';
                    return response()->json([
                        'status' => true,
                        'message' => "Koneksi ke Anthropic Claude ({$model}) BERHASIL!",
                        'latency_ms' => $latency,
                        'reply' => trim($reply),
                    ]);
                } else {
                    $error = $response->json()['error']['message'] ?? $response->body();
                    return response()->json([
                        'status' => false,
                        'message' => "Koneksi Anthropic Gagal: " . substr($error, 0, 200),
                        'latency_ms' => $latency,
                    ], 400);
                }
            } else {
                $customUrl = $request->input('custom_endpoint') ?? SystemSetting::get('ai_custom_endpoint', '');
                if (empty($customUrl)) {
                    return response()->json([
                        'status' => false,
                        'message' => 'Custom Endpoint URL wajib diisi untuk provider custom.',
                    ], 422);
                }

                $response = Http::timeout(10)->get($customUrl);
                $latency = round((microtime(true) - $startTime) * 1000);

                return response()->json([
                    'status' => $response->successful(),
                    'message' => $response->successful() ? "Koneksi Custom Endpoint Berhasil ({$latency}ms)" : "Custom Endpoint Error {$response->status()}",
                    'latency_ms' => $latency,
                ]);
            }
        } catch (Exception $e) {
            return response()->json([
                'status' => false,
                'message' => 'Gagal terhubung ke server AI: ' . $e->getMessage(),
            ], 500);
        }
    }
}
