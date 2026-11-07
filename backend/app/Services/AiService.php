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

            // Map deprecated or legacy Gemini model IDs to active Gemini 3.5 Flash Lite
            if (empty($model) || in_array($model, ['gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-2.0-flash', 'gemini-2.5-flash', 'gemini-2.5-flash-lite'])) {
                $model = 'gemini-3.5-flash-lite';
            }

            $modelsToTry = [$model];
            if ($model !== 'gemini-3.5-flash-lite') {
                $modelsToTry[] = 'gemini-3.5-flash-lite';
            }

            $lastError = null;
            foreach ($modelsToTry as $currentModelToTry) {
                try {
                    $url = "https://generativelanguage.googleapis.com/v1beta/models/{$currentModelToTry}:generateContent?key={$apiKey}";
                    $response = Http::withHeaders([
                        'x-goog-api-key' => $apiKey,
                    ])->timeout(25)->post($url, [
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

                    $lastError = $response->json()['error']['message'] ?? $response->body();
                } catch (\Throwable $e) {
                    $lastError = $e->getMessage();
                }
            }

            throw new Exception("Google Gemini Error: " . substr($lastError ?? 'Layanan tidak merespons.', 0, 200));

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
        $includeData = !empty($payload['include_data_kreavana']);

        $recommendationCards = [];

        if ($mode === 'polish') {
            $prompt = "Perhalus pesan berikut agar terdengar lebih ramah, profesional, dan persuasif untuk komunikasi bisnis kreatif:\n\"{$message}\"";
        } elseif ($mode === 'smart_reply') {
            $prompt = "Berikan 2 alternatif balasan cepat yang sopan dan profesional untuk pesan berikut:\n\"{$message}\"";
        } else {
            $prompt = $message;

            if ($includeData) {
                try {
                    $recommendationCards = $this->findRelevantCreators($message, 100);

                    if (!empty($recommendationCards)) {
                        $count = count($recommendationCards);
                        $prompt = $message . "\n\n[SISTEM PLATFORM KREAVANA]:\nDitemukan {$count} akun kreator terverifikasi yang cocok dengan kriteria pencarian dan telah ditampilkan secara visual pada daftar kartu rekomendasi sistem.\nTUGAS ANDA: Berikan pesan pengantar yang sangat singkat, ramah, dan langsung ke intinya (cukup 1-2 kalimat saja, contoh: 'Berikut adalah rekomendasi {$count} akun kreator terverifikasi di Kreavana yang sesuai dengan kebutuhan Anda:').\nATURAN KETAT: JANGAN menjabarkan atau menjelaskan kelebihan, ulasan, atau profil kreator satu per satu di rangkuman teks ini, karena seluruh akun beserta portofolio dan profil lengkapnya sudah ditampilkan langsung pada kartu rekomendasi sistem.";
                    }
                } catch (\Throwable $e) {
                    // Fallback to original prompt if query fails
                }
            }
        }

        $answer = $this->generateContent($prompt);

        return [
            'answer' => $answer,
            'polished_message' => $answer,
            'recommendation_cards' => $recommendationCards,
            'ai_provider' => SystemSetting::get('ai_provider', 'gemini'),
        ];
    }

    /**
     * Cari dan rangking kreator yang relevan dengan pertanyaan / prompt pengguna.
     * Mendukung deteksi sub-role spesifik (Wedding Organizer, Videografer, Fotografer, dll.),
     * deteksi lokasi geografis (Bekasi, Jakarta, Bandung, dll.), serta perangkingan booster akun.
     */
    protected function findRelevantCreators(string $message, int $limit = 100): array
    {
        $normalizedMsg = strtolower($message);

        // 1. Deteksi sub_role spesifik berdasarkan konteks pesan pengguna
        $detectedSubRoles = [];

        if (preg_match('/\b(wedding\s*organi[sz]e*r*|organi[sz]e*r*\s*wedding|wo\b|pernikahan|pengantin|nikah|resepsi|walimah|wedding)\b/i', $normalizedMsg)) {
            $detectedSubRoles[] = 'wedding_organizer';
        }
        if (preg_match('/\b(event\s*organi[sz]e*r*|organi[sz]e*r*\s*event|organi[sz]e*r*\s*acara|eo\b|konser|festival|gathering|bazar|expo|pameran)\b/i', $normalizedMsg)) {
            $detectedSubRoles[] = 'event_organizer';
        }
        if (preg_match('/\b(make\s*up|mua\b|tata\s*rias|rias\b|beauty)\b/i', $normalizedMsg)) {
            $detectedSubRoles[] = 'makeup_artist';
        }
        if (preg_match('/\b(fotografer|photographer|fotografi|photography|foto|photo|pemotretan)\b/i', $normalizedMsg)) {
            $detectedSubRoles[] = 'photographer';
        }
        if (preg_match('/\b(videografer|videographer|videografi|videography|video|shooting|cinematic|sinematik|aftermovie|reels)\b/i', $normalizedMsg)) {
            $detectedSubRoles[] = 'videographer';
        }
        if (preg_match('/\b(pembawa\s*acara|master\s*of\s*ceremon|mc\b|host\b|moderator)\b/i', $normalizedMsg)) {
            $detectedSubRoles[] = 'mc';
        }
        if (preg_match('/\b(penyanyi|singer|vokalis|vokal|solois)\b/i', $normalizedMsg)) {
            $detectedSubRoles[] = 'singer';
        }
        if (preg_match('/\b(musisi|musician|pemain\s*musik|band\b|akustik|gitaris|keyboardist)\b/i', $normalizedMsg)) {
            $detectedSubRoles[] = 'musician';
        }
        if (preg_match('/\b(tukang\s*kendang|kendang|gendang|ketipung)\b/i', $normalizedMsg)) {
            $detectedSubRoles[] = 'tukang_kendang';
        }
        if (preg_match('/\b(editor|editing|edit\s*video|edit\s*foto|color\s*grading)\b/i', $normalizedMsg)) {
            $detectedSubRoles[] = 'editor';
        }
        if (preg_match('/\b(desain|design|desainer|designer|grafis|graphic|logo|branding|poster|banner|ilustrator)\b/i', $normalizedMsg)) {
            $detectedSubRoles[] = 'designer';
        }
        if (preg_match('/\b(animator|animasi|animation|motion\s*graphic|3d\s*artist)\b/i', $normalizedMsg)) {
            $detectedSubRoles[] = 'animator';
        }
        if (preg_match('/\b(drone|pilot\s*drone|aerial)\b/i', $normalizedMsg)) {
            $detectedSubRoles[] = 'drone_pilot';
        }
        if (preg_match('/\b(talent\b|model\b|aktor|aktris)\b/i', $normalizedMsg)) {
            $detectedSubRoles[] = 'talent';
        }
        if (preg_match('/\b(content\s*creator|konten\s*kreator|influencer|selebgram|tiktoker)\b/i', $normalizedMsg)) {
            $detectedSubRoles[] = 'content_creator';
        }
        if (preg_match('/\b(vendor\b|katering|catering|tenda\b|panggung|sound\s*system|dekorasi)\b/i', $normalizedMsg)) {
            $detectedSubRoles[] = 'vendor';
        }
        if (preg_match('/\b(mitra\s*jasa|mitra\s*pendukung|jasa\s*pendukung)\b/i', $normalizedMsg)) {
            $detectedSubRoles[] = 'mitra_pendukung';
        }
        if (preg_match('/\b(studio\b|sewa\s*studio)\b/i', $normalizedMsg)) {
            $detectedSubRoles[] = 'studio';
        }
        if (preg_match('/\b(rental\b|sewa\s*kamera|sewa\s*alat|rental\s*kamera|sewa\s*lensa)\b/i', $normalizedMsg)) {
            $detectedSubRoles[] = 'rental_alat';
        }
        if (preg_match('/\b(komunitas|community|paguyuban|kolektif)\b/i', $normalizedMsg)) {
            $detectedSubRoles[] = 'community';
        }

        // Disambiguasi: jika user menyebut "wedding organizer", jangan sertakan event_organizer
        if (in_array('wedding_organizer', $detectedSubRoles) && !preg_match('/\b(event|acara\s*kantor|konser|festival|gathering)\b/i', $normalizedMsg)) {
            $detectedSubRoles = array_values(array_diff($detectedSubRoles, ['event_organizer']));
        }

        // 2. Deteksi Lokasi dari Pesan
        $cityMap = [
            'bekasi' => 'Bekasi',
            'jakarta selatan' => 'Jakarta Selatan',
            'jakarta barat' => 'Jakarta Barat',
            'jakarta pusat' => 'Jakarta Pusat',
            'jakarta timur' => 'Jakarta Timur',
            'jakarta utara' => 'Jakarta Utara',
            'jakarta' => 'Jakarta',
            'jaksel' => 'Jakarta Selatan',
            'jakpus' => 'Jakarta Pusat',
            'jakbar' => 'Jakarta Barat',
            'jaktim' => 'Jakarta Timur',
            'jakut' => 'Jakarta Utara',
            'bogor' => 'Bogor',
            'depok' => 'Depok',
            'tangerang selatan' => 'Tangerang Selatan',
            'tangsel' => 'Tangerang Selatan',
            'tangerang' => 'Tangerang',
            'bandung' => 'Bandung',
            'surabaya' => 'Surabaya',
            'semarang' => 'Semarang',
            'yogyakarta' => 'Yogyakarta',
            'jogja' => 'Yogyakarta',
            'solo' => 'Solo',
            'surakarta' => 'Solo',
            'malang' => 'Malang',
            'bali' => 'Bali',
            'denpasar' => 'Denpasar',
            'medan' => 'Medan',
            'makassar' => 'Makassar',
            'palembang' => 'Palembang',
            'karawang' => 'Karawang',
            'cirebon' => 'Cirebon',
            'sukabumi' => 'Sukabumi',
            'serang' => 'Serang',
            'batam' => 'Batam',
        ];

        $detectedLocation = null;
        foreach ($cityMap as $k => $locName) {
            if (preg_match('/\b' . preg_quote($k, '/') . '\b/i', $normalizedMsg)) {
                $detectedLocation = $locName;
                break;
            }
        }

        // 3. Query Kreator
        $query = \App\Models\User::where('role', \App\Enums\RoleType::Creator)
            ->where('is_creator_approved', true)
            ->with(['addresses']);

        // Jika sub_role terdeteksi, filter HANYA ke sub_role tersebut
        if (!empty($detectedSubRoles)) {
            $query->where(function ($q) use ($detectedSubRoles) {
                $q->whereIn('sub_role', $detectedSubRoles)
                  ->orWhereHas('userSubRoles', function ($sq) use ($detectedSubRoles) {
                      $sq->whereIn('sub_role_slug', $detectedSubRoles);
                  });
            });
        }

        $creators = $query->get();

        if ($creators->isEmpty()) {
            return [];
        }

        // 4. Hitung Skor Relevansi & Perangkingan
        $scored = $creators->map(function ($c) use ($detectedLocation, $normalizedMsg) {
            $score = 0;

            // Prioritas Booster platform (Sistem Booster Akun)
            $boost = (float) ($c->performance_boost ?? 0);
            $score += $boost * 10;

            // Tier langganan
            $tier = $c->subscription_tier ?? 'free';
            if ($tier === 'super') $score += 20;
            elseif ($tier === 'pro') $score += 10;
            elseif ($tier === 'plus') $score += 5;

            // Alamat / Kota
            $addr = $c->addresses->firstWhere('is_default', true) ?? $c->addresses->first();
            $city = $addr?->city;
            $province = $addr?->province;
            $creatorLocation = ($city && $province) ? "{$city}, {$province}" : ($city ?? $province ?? null);

            if ($detectedLocation) {
                $locLower = strtolower($detectedLocation);
                $isLocationMatch = ($city && str_contains(strtolower($city), $locLower))
                    || ($province && str_contains(strtolower($province), $locLower))
                    || ($addr && str_contains(strtolower($addr->address), $locLower))
                    || str_contains(strtolower($c->name), $locLower)
                    || str_contains(strtolower($c->username), $locLower);

                if ($isLocationMatch) {
                    $score += 1000; // Prioritas tertinggi: kreator yang berada di lokasi pencarian
                }
            }

            // Nama atau username spesifik
            if (str_contains($normalizedMsg, strtolower($c->name)) || str_contains($normalizedMsg, strtolower($c->username))) {
                $score += 50;
            }

            $subRoleEnum = \App\Enums\CreatorSubRole::tryFrom($c->sub_role ?? '');
            $subRoleLabel = $subRoleEnum?->label() ?? ucfirst(str_replace('_', ' ', $c->sub_role ?? 'Kreator'));

            $resolvedLoc = $creatorLocation ?? ($detectedLocation ? "{$detectedLocation} & Sekitarnya" : 'Indonesia');

            return [
                'score' => $score,
                'data' => [
                    'type' => 'creator',
                    'id' => $c->id,
                    'name' => $c->name,
                    'username' => $c->username,
                    'sub_role' => $c->sub_role ?? 'creator',
                    'sub_role_label' => $subRoleLabel,
                    'location' => $resolvedLoc,
                    'performance_boost' => $boost > 0 ? "⚡ {$boost}x Booster" : '⭐ Terverifikasi',
                    'rating' => 4.9,
                    'review_count' => 'Kreator Terverifikasi',
                    'avatar_url' => $c->avatar_url,
                    'action_label' => 'Lihat Profil',
                ],
            ];
        });

        return $scored->sortByDesc('score')->take($limit)->pluck('data')->values()->all();
    }
}
