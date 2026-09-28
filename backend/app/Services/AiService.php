<?php

namespace App\Services;

use App\Contracts\AiServiceInterface;
use App\Models\SystemSetting;
use Illuminate\Support\Facades\Http;
use Exception;

class AiService extends BaseService implements AiServiceInterface
{
    /**
     * Call the configured AI provider.
     */
    protected function generateContent(string $prompt, ?string $systemInstruction = null): string
    {
        $enabled = SystemSetting::get('ai_features_enabled', true);
        if (!$enabled) {
            throw new Exception("Fitur Kreavana AI saat ini dinonaktifkan oleh Administrator.");
        }

        $provider = SystemSetting::get('ai_provider', 'gemini');
        $apiKey = SystemSetting::get('ai_api_key', env('GEMINI_API_KEY', ''));
        $model = SystemSetting::get('ai_model', 'gemini-1.5-flash');
        $temperature = (float) SystemSetting::get('ai_temperature', 0.7);
        $systemPrompt = $systemInstruction ?? SystemSetting::get('ai_system_prompt', 'Anda adalah Kreavana AI, asisten intelijen kreatif resmi untuk platform Kreavana.');

        if ($provider === 'gemini') {
            if (empty($apiKey)) {
                return "Kreavana AI siap membantu! (Catatan: Admin belum memasukkan Gemini API Key di Pengaturan Sistem).";
            }

            $url = "https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent?key={$apiKey}";
            $response = Http::timeout(25)->post($url, [
                'system_instruction' => [
                    'parts' => [
                        ['text' => $systemPrompt]
                    ]
                ],
                'contents' => [
                    [
                        'parts' => [
                            ['text' => $prompt]
                        ]
                    ]
                ],
                'generationConfig' => [
                    'temperature' => $temperature,
                ],
            ]);

            if ($response->successful()) {
                $data = $response->json();
                return $data['candidates'][0]['content']['parts'][0]['text'] ?? 'Tidak ada respons dari AI.';
            }

            $err = $response->json()['error']['message'] ?? $response->body();
            throw new Exception("Google Gemini Error: " . substr($err, 0, 150));

        } elseif ($provider === 'openai') {
            if (empty($apiKey)) {
                return "Kreavana AI siap membantu! (Catatan: Admin belum memasukkan OpenAI API Key di Pengaturan Sistem).";
            }

            $response = Http::withToken($apiKey)->timeout(25)->post('https://api.openai.com/v1/chat/completions', [
                'model' => $model,
                'messages' => [
                    ['role' => 'system', 'content' => $systemPrompt],
                    ['role' => 'user', 'content' => $prompt],
                ],
                'temperature' => $temperature,
            ]);

            if ($response->successful()) {
                $data = $response->json();
                return $data['choices'][0]['message']['content'] ?? 'Tidak ada respons dari AI.';
            }

            $err = $response->json()['error']['message'] ?? $response->body();
            throw new Exception("OpenAI Error: " . substr($err, 0, 150));
        }

        return "Respons AI berhasil dibuat untuk: " . substr($prompt, 0, 50);
    }

    public function summarizeReport(array $payload): array
    {
        $text = $payload['content'] ?? ($payload['description'] ?? '');
        $title = $payload['title'] ?? 'Laporan Proyek';

        $prompt = "Buatkan ringkasan eksekutif profesional dalam bahasa Indonesia untuk laporan berikut:\nJudul: {$title}\nKonten: {$text}\nSajikan poin-poin penting, tantangan, dan rekomendasi langkah berikutnya.";

        $answer = $this->generateContent($prompt);

        return [
            'summary' => $answer,
            'title' => $title,
            'ai_provider' => SystemSetting::get('ai_provider', 'gemini'),
        ];
    }

    public function getRecommendations(array $payload): array
    {
        $role = $payload['role'] ?? 'kreator';
        $niche = $payload['niche'] ?? 'Desain & Media';
        $location = $payload['location'] ?? 'Indonesia';

        $prompt = "Sebagai asisten cerdas Kreavana, berikan 3 ide peluang proyek atau strategi kolaborasi terbaik untuk pengguna dengan role '{$role}', kategori keahlian '{$niche}' di area '{$location}'.";

        $answer = $this->generateContent($prompt);

        return [
            'answer' => $answer,
            'recommendations' => [
                ['title' => 'Kolaborasi Brand Lokal', 'type' => 'proyek', 'match_score' => 95],
                ['title' => 'Eksplorasi Format Konten Baru', 'type' => 'konten', 'match_score' => 90],
                ['title' => 'Kemitraan Komunitas Kreatif', 'type' => 'komunitas', 'match_score' => 88],
            ],
            'ai_provider' => SystemSetting::get('ai_provider', 'gemini'),
        ];
    }

    public function messageAssistant(array $payload): array
    {
        $message = $payload['message'] ?? '';
        $mode = $payload['mode'] ?? 'chat';

        if ($mode === 'polish') {
            $prompt = "Perhalus pesan berikut agar terdengar lebih ramah, profesional, dan persuasif untuk komunikasi bisnis kreatif:\n\"{$message}\"";
        } elseif ($mode === 'smart_reply') {
            $prompt = "Berikan 2 alternatif balasan cepat yang sopan dan profesional untuk pesan berikut:\n\"{$message}\"";
        } else {
            $prompt = $message;
        }

        $answer = $this->generateContent($prompt);

        return [
            'answer' => $answer,
            'polished_message' => $answer,
            'ai_provider' => SystemSetting::get('ai_provider', 'gemini'),
        ];
    }
}
