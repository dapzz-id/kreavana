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
                'direct_message_enabled' => SystemSetting::get('direct_message_enabled', true),
                'voice_call_enabled' => SystemSetting::get('voice_call_enabled', true),
                'video_call_enabled' => SystemSetting::get('video_call_enabled', true),
                'ai_features_enabled' => SystemSetting::get('ai_features_enabled', true),
                'marketplace_enabled' => SystemSetting::get('marketplace_enabled', true),
                'collaboration_enabled' => SystemSetting::get('collaboration_enabled', true),
                'opportunities_enabled' => SystemSetting::get('opportunities_enabled', true),
                'wallet_enabled' => SystemSetting::get('wallet_enabled', true),
                'client_verification_enabled' => SystemSetting::get('client_verification_enabled', true),
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
                'key' => 'direct_message_enabled',
                'name' => 'Direct Message & Chat',
                'description' => 'Sistem obrolan langsung, pesan teks real-time, berbagi media, dan grup perpesanan.',
                'enabled' => SystemSetting::get('direct_message_enabled', true),
                'category' => 'Komunikasi & Pesan',
                'target_audience' => 'both',
                'icon' => 'chat',
            ],
            [
                'key' => 'voice_call_enabled',
                'name' => 'Panggilan Suara (Voice Call)',
                'description' => 'Panggilan suara real-time WebRTC di dalam ruang obrolan langsung (Direct Message).',
                'enabled' => SystemSetting::get('voice_call_enabled', true),
                'category' => 'Komunikasi & Pesan',
                'target_audience' => 'both',
                'icon' => 'call',
            ],
            [
                'key' => 'video_call_enabled',
                'name' => 'Panggilan Video (Video Call)',
                'description' => 'Panggilan tatap muka video real-time dengan kamera dan mikrofon di Direct Message.',
                'enabled' => SystemSetting::get('video_call_enabled', true),
                'category' => 'Komunikasi & Pesan',
                'target_audience' => 'both',
                'icon' => 'videocam',
            ],
            [
                'key' => 'ai_features_enabled',
                'name' => 'Kreavana AI Assistant',
                'description' => 'Fitur asisten AI cerdas untuk rekomendasi kreator, pembuatan brief, dan riset ide.',
                'enabled' => SystemSetting::get('ai_features_enabled', true),
                'category' => 'AI & Intelijen',
                'target_audience' => 'both',
                'icon' => 'auto_awesome',
            ],
            [
                'key' => 'marketplace_enabled',
                'name' => 'Marketplace Karya & Jasa',
                'description' => 'Katalog etalase karya digital, aset kreatif, dan pemesanan portofolio jasa kreator.',
                'enabled' => SystemSetting::get('marketplace_enabled', true),
                'category' => 'Transaksi & Penjualan',
                'target_audience' => 'both',
                'icon' => 'storefront',
            ],
            [
                'key' => 'collaboration_enabled',
                'name' => 'Kolaborasi & Manajemen Proyek',
                'description' => 'Pencarian partner kolaborasi, kontrak kerja milestone, dan pengerjaan proyek.',
                'enabled' => SystemSetting::get('collaboration_enabled', true),
                'category' => 'Kolaborasi',
                'target_audience' => 'both',
                'icon' => 'handshake',
            ],
            [
                'key' => 'opportunities_enabled',
                'name' => 'Peluang Proyek & Tender',
                'description' => 'Publikasi lowongan/kebutuhan proyek oleh klien dan pelamaran kerja oleh kreator.',
                'enabled' => SystemSetting::get('opportunities_enabled', true),
                'category' => 'Peluang Kerja',
                'target_audience' => 'both',
                'icon' => 'work_outline',
            ],
            [
                'key' => 'wallet_enabled',
                'name' => 'Sistem Dompet & Pembayaran Escrow',
                'description' => 'Dompet digital, penarikan saldo withdraw, dan rekening bersama (escrow) aman.',
                'enabled' => SystemSetting::get('wallet_enabled', true),
                'category' => 'Keuangan',
                'target_audience' => 'both',
                'icon' => 'account_balance_wallet',
            ],
            [
                'key' => 'client_verification_enabled',
                'name' => 'Verifikasi KTP Klien (Centang Biru)',
                'description' => 'Pengajuan dan verifikasi KTP resmi bagi klien untuk validitas penerbitan proyek.',
                'enabled' => SystemSetting::get('client_verification_enabled', true),
                'category' => 'Autentikasi & Akun',
                'target_audience' => 'client',
                'icon' => 'verified_user',
            ],
            [
                'key' => 'creator_registration_enabled',
                'name' => 'Pengajuan Upgrade Kreator (Centang Hijau)',
                'description' => 'Formulir pengajuan verifikasi portofolio dan NIK untuk upgrade ke akun Kreator resmi.',
                'enabled' => SystemSetting::get('creator_registration_enabled', true),
                'category' => 'Autentikasi & Akun',
                'target_audience' => 'creator',
                'icon' => 'verified',
            ],
            [
                'key' => 'user_registration_enabled',
                'name' => 'Registrasi Pengguna Baru',
                'description' => 'Mengizinkan pengguna baru untuk mendaftar akun klien atau kreator di platform.',
                'enabled' => SystemSetting::get('user_registration_enabled', true),
                'category' => 'Autentikasi & Akun',
                'target_audience' => 'both',
                'icon' => 'person_add',
            ],
            [
                'key' => 'maintenance_mode',
                'name' => 'Mode Pemeliharaan (Maintenance Mode)',
                'description' => 'Kunci akses publik untuk sementara waktu saat pembaruan infrastruktur sistem.',
                'enabled' => SystemSetting::get('maintenance_mode', false),
                'category' => 'Sistem & Server',
                'target_audience' => 'system',
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

        $currentModel = SystemSetting::get('ai_model', 'gemini-3.5-flash-lite');
        if (in_array($currentModel, ['gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-2.0-flash', 'gemini-2.5-flash', 'gemini-2.5-flash-lite'])) {
            $currentModel = 'gemini-3.5-flash-lite';
        }

        $config = [
            'provider' => SystemSetting::get('ai_provider', 'gemini'),
            'api_key_masked' => $maskedKey,
            'has_api_key' => !empty($apiKey),
            'model' => $currentModel,
            'temperature' => (float) SystemSetting::get('ai_temperature', 0.7),
            'max_tokens' => (int) SystemSetting::get('ai_max_tokens', 2048),
            'system_prompt' => SystemSetting::get('ai_system_prompt', 'Anda adalah Kreavana AI, asisten intelijen kreatif resmi untuk platform Kreavana. Bantu kreator dan klien mengoptimalkan ide, peluang proyek, dan strategi bisnis kreatif di Indonesia.'),
            'custom_endpoint' => SystemSetting::get('ai_custom_endpoint', ''),
            'available_models' => [
                'gemini' => [
                    ['id' => 'gemini-3.5-flash-lite', 'name' => 'Google Gemini 3.5 Flash Lite (Direkomendasikan - Paling Cepat & Stabil)'],
                    ['id' => 'gemini-3.8-flash', 'name' => 'Google Gemini 3.8 Flash (Next-Gen Flagship - Respon Kadang Lambat/Antrean)'],
                    ['id' => 'gemini-flash-latest', 'name' => 'Google Gemini Flash Latest'],
                    ['id' => 'gemini-2.5-pro', 'name' => 'Google Gemini 2.5 Pro (Analisis Kompleks)'],
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
                if (empty($model) || in_array($model, ['gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-2.0-flash', 'gemini-2.5-flash', 'gemini-2.5-flash-lite'])) {
                    $model = 'gemini-3.5-flash-lite';
                }

                $endpoint = "https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent?key={$apiKey}";
                $response = Http::withHeaders([
                    'x-goog-api-key' => $apiKey,
                ])->timeout(25)->post($endpoint, [
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
            $msg = $e->getMessage();
            if (str_contains($msg, 'Operation timed out') || str_contains($msg, 'cURL error 28')) {
                $msg = "Waktu koneksi habis (Timeout setelah 25 detik). Server model '{$model}' sedang mengalami antrean/beban tinggi dari Google. Disarankan memilih model 'Google Gemini 3.5 Flash Lite' yang jauh lebih cepat dan stabil.";
            }

            return response()->json([
                'status' => false,
                'message' => 'Gagal terhubung ke server AI: ' . $msg,
            ], 500);
        }
    }

    /**
     * GET /api/admin/system/contract-signature
     */
    public function getContractSignature()
    {
        return response()->json([
            'status' => true,
            'data' => [
                'admin_name' => SystemSetting::get('admin_contract_signer_name', 'Tim Legal & Penjamin Escrow Kreavana'),
                'admin_title' => SystemSetting::get('admin_contract_signer_title', 'Otoritas Penjamin Transaksi PT Kreavana Digital Indonesia'),
                'admin_signature_url' => SystemSetting::get('admin_contract_signature_image', '/assets/images/kreavana_official_signature.png'),
            ],
        ]);
    }

    /**
     * POST /api/admin/system/contract-signature
     * Upload foto tanda tangan & nama admin untuk auto-input sistem ke kontrak digital
     */
    public function updateContractSignature(Request $request)
    {
        $validated = $request->validate([
            'admin_name' => 'required|string|max:150',
            'admin_title' => 'nullable|string|max:150',
            'signature_image' => 'nullable',
        ]);

        SystemSetting::set('admin_contract_signer_name', $validated['admin_name'], 'contracts');
        if (!empty($validated['admin_title'])) {
            SystemSetting::set('admin_contract_signer_title', $validated['admin_title'], 'contracts');
        }

        if ($request->hasFile('signature_image')) {
            $file = $request->file('signature_image');
            $filename = 'admin_sig_' . time() . '.' . $file->getClientOriginalExtension();
            $path = $file->storeAs('signatures', $filename, 'public');
            $signatureUrl = '/storage/' . $path;
            SystemSetting::set('admin_contract_signature_image', $signatureUrl, 'contracts');
        } elseif ($request->filled('signature_image_base64')) {
            $raw = $request->input('signature_image_base64');
            if (preg_match('/^data:image\/(\w+);base64,/', $raw, $type)) {
                $raw = substr($raw, strpos($raw, ',') + 1);
                $type = strtolower($type[1]);
                $image = base64_decode($raw);
                if ($image !== false) {
                    $filename = 'admin_sig_' . time() . '.' . $type;
                    \Illuminate\Support\Facades\Storage::disk('public')->put('signatures/' . $filename, $image);
                    $signatureUrl = '/storage/signatures/' . $filename;
                    SystemSetting::set('admin_contract_signature_image', $signatureUrl, 'contracts');
                }
            }
        } elseif ($request->filled('signature_url')) {
            SystemSetting::set('admin_contract_signature_image', $request->input('signature_url'), 'contracts');
        }

        return response()->json([
            'status' => true,
            'message' => 'Tanda tangan dan identitas Admin Kreavana untuk auto-input kontrak digital berhasil diperbarui.',
            'data' => [
                'admin_name' => SystemSetting::get('admin_contract_signer_name'),
                'admin_title' => SystemSetting::get('admin_contract_signer_title'),
                'admin_signature_url' => SystemSetting::get('admin_contract_signature_image'),
            ],
        ]);
    }
}
