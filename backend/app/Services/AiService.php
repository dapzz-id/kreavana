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
    protected function generateContent(string $prompt, ?string $systemInstruction = null, int $timeoutSeconds = 25): string
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
                    ])->timeout($timeoutSeconds)->post($url, [
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
        $niche = $payload['niche'] ?? 'Industri Kreatif';
        $subRole = strtolower(trim((string) ($payload['sub_role'] ?? 'all')));
        if ($subRole === '' || $subRole === 'semua') {
            $subRole = 'all';
        }
        $rawLocation = trim((string) ($payload['location'] ?? ''));
        $location = (!empty($rawLocation) && $rawLocation !== 'Lokasi Sekarang') ? $rawLocation : 'Indonesia & Jabodetabek';

        $subRoleLabelMap = [
            'all' => 'Seluruh Industri Kreatif',
            'corporate' => 'Perusahaan / Corporate & Brand Enterprise',
            'photographer' => 'Fotografer & Visual Content',
            'event_organizer' => 'Event Organizer (EO) & Manajemen Acara',
            'school' => 'Institusi Pendidikan & Vokasi',
            'institution' => 'Institusi Pendidikan & Vokasi',
            'videographer' => 'Videografer & Sinematografi',
            'wedding_organizer' => 'Wedding Organizer (WO) & Pernikahan',
            'editor' => 'Video Editor & Colorist',
            'mc' => 'Master of Ceremony (MC) & Host',
            'makeup_artist' => 'Makeup Artist (MUA) & Tata Rias',
            'singer' => 'Penyanyi & Musisi',
            'community' => 'Komunitas Kreatif',
        ];

        $subRoleLabel = $subRoleLabelMap[$subRole] ?? ucfirst(str_replace('_', ' ', $subRole));

        // 1. Query Real Matched Items from Database (Truth from database - No Mockups)
        $matchedItems = $this->queryMatchedDatabaseItems($subRole, $location);

        // 2. Formulate AI Prompt for Structured Recommendations
        $systemInstruction = "Anda adalah Kreavana AI, konsultan strategi bisnis dan intelijen kreatif resmi platform Kreavana. Anda memberikan wawasan taktis, peluang proyek nyata, dan strategi kolaborasi yang berdampak tinggi di Indonesia.";

        $prompt = "Sebagai Kreavana AI, buatlah tepat 3 rekomendasi peluang proyek, inovasi layanan, atau strategi kolaborasi bisnis yang paling prospektif dan bernilai ekonomi tinggi untuk:
- Target Profesi / Sub-Role: {$subRoleLabel}
- Bidang Spesialisasi: {$niche}
- Area / Lokasi: {$location}
- Peran Akun: {$role}

Kembalikan HANYA format JSON valid tanpa tanda petik pembuka markdown atau backtick:
{
  \"summary\": \"Ringkasan tren peluang dan iklim industri kreatif di wilayah {$location} (1-2 kalimat).\",
  \"recommendations\": [
    {
      \"title\": \"Judul inisiatif/peluang yang menarik dan konkret\",
      \"category\": \"Peluang Proyek / Kemitraan Strategis / Inovasi Layanan\",
      \"reason\": \"Alasan mendalam mengapa peluang ini sangat dibutuhkan dan menjanjikan di wilayah ini saat ini (2-3 kalimat jelas)\",
      \"impact\": \"Estimasi dampak konkret (contoh: 'Peningkatan potensi omset +35% & jangkauan pasar baru')\",
      \"match_score\": \"98% Cocok\",
      \"action_label\": \"Jelajahi Peluang Terkait\"
    }
  ]
}";

        $recs = [];
        $summaryText = null;

        try {
            $rawContent = $this->generateContent($prompt, $systemInstruction, 10);
            // Clean markdown code blocks if wrapped by AI
            $cleanJson = trim($rawContent);
            if (str_starts_with($cleanJson, '```json')) {
                $cleanJson = substr($cleanJson, 7);
            }
            if (str_starts_with($cleanJson, '```')) {
                $cleanJson = substr($cleanJson, 3);
            }
            if (str_ends_with($cleanJson, '```')) {
                $cleanJson = substr($cleanJson, 0, -3);
            }
            $cleanJson = trim($cleanJson);

            $decoded = json_decode($cleanJson, true);
            if (is_array($decoded) && !empty($decoded['recommendations']) && is_array($decoded['recommendations'])) {
                foreach ($decoded['recommendations'] as $r) {
                    if (!empty($r['title']) && !empty($r['reason'])) {
                        $recs[] = [
                            'title' => (string) $r['title'],
                            'category' => (string) ($r['category'] ?? 'Peluang Proyek'),
                            'reason' => (string) $r['reason'],
                            'impact' => (string) ($r['impact'] ?? 'Peningkatan peluang kolaborasi & portofolio'),
                            'match_score' => (string) ($r['match_score'] ?? '96% Cocok'),
                            'action_label' => (string) ($r['action_label'] ?? 'Jelajahi Peluang'),
                        ];
                    }
                }
                $summaryText = $decoded['summary'] ?? null;
            }
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('AI Recommendations JSON parse error: ' . $e->getMessage());
        }

        // If AI generation didn't return valid 3 items, provide contextual dynamic items based on subRole & location
        if (count($recs) < 3) {
            $fallbackRecs = $this->generateContextualFallbackRecommendations($subRole, $subRoleLabel, $location);
            $recs = array_slice(array_merge($recs, $fallbackRecs), 0, 3);
        }

        return [
            'summary' => $summaryText ?? "Tren peluang kolaborasi dan permintaan jasa {$subRoleLabel} di {$location} sedang bertumbuh positif.",
            'recommendations' => $recs,
            'matched_items' => $matchedItems,
            'ai_provider' => SystemSetting::get('ai_provider', 'gemini'),
        ];
    }

    /**
     * Extract searchable location tokens from user-provided location filter.
     *
     * @return array<int, string>
     */
    protected function extractLocationTokens(string $location): array
    {
        $locLower = strtolower($location);
        $cleanLoc = str_replace(
            ['seluruh', 'semua', 'lokasi sekarang', 'gps', 'indonesia', '&', 'dan', 'sekitarnya', '(', ')'],
            ' ',
            $locLower
        );
        $cleanLoc = trim(preg_replace('/\s+/', ' ', $cleanLoc) ?? '');

        if ($cleanLoc === '' || $cleanLoc === 'all') {
            return [];
        }

        if ($cleanLoc === 'jabodetabek') {
            return ['jabodetabek', 'jakarta', 'bogor', 'depok', 'tangerang', 'bekasi'];
        }

        return [$cleanLoc];
    }

    /**
     * Corporate sub-role keyword slugs used across accounts and opportunities.
     *
     * @return array<int, string>
     */
    protected function corporateKeywordSlugs(): array
    {
        return ['corporate', 'company', 'business', 'perusahaan', 'bisnis', 'enterprise', 'b2b'];
    }

    /**
     * Apply corporate entity constraints onto a User query builder.
     */
    protected function applyCorporateUserFilter(\Illuminate\Database\Eloquent\Builder $query): void
    {
        $keywords = $this->corporateKeywordSlugs();
        $query->where(function ($sub) use ($keywords) {
            $sub->whereIn('sub_role', $keywords)
                ->orWhereIn('role', $keywords)
                ->orWhereHas('userSubRoles', fn($sq) => $sq->whereIn('sub_role_slug', $keywords)->where('is_active', true))
                ->orWhere('username', 'corporate_demo')
                ->orWhere('email', 'like', 'corporate%@%');
        });
    }

    /**
     * Build a base Opportunity query filtered cleanly by target subRole.
     */
    protected function buildFilteredOpportunityQuery(string $subRole): \Illuminate\Database\Eloquent\Builder
    {
        $oppQuery = \App\Models\Opportunity::query()->where('status', 'open');

        if ($subRole === 'all') {
            return $oppQuery;
        }

        if ($subRole === 'corporate') {
            $keywords = $this->corporateKeywordSlugs();
            return $oppQuery->where(function ($q) use ($keywords) {
                $q->whereIn('sub_role_slug', $keywords)
                    ->orWhereHas('user', function ($uq) {
                        $this->applyCorporateUserFilter($uq);
                    });
            });
        }

        if (in_array($subRole, ['school', 'institution'], true)) {
            $schoolSlugs = ['school', 'institution', 'institusi', 'sekolah', 'kampus', 'campus', 'education'];
            return $oppQuery->where(function ($q) use ($schoolSlugs) {
                $q->whereIn('sub_role_slug', $schoolSlugs)
                    ->orWhereHas('requirements', fn($rq) => $rq->whereIn('sub_role_slug', $schoolSlugs));
            });
        }

        return $oppQuery->where(function ($q) use ($subRole) {
            $q->where('sub_role_slug', $subRole)
                ->orWhere('sub_role_slug', 'all')
                ->orWhere('sub_role_slug', 'kreator')
                ->orWhereHas('requirements', fn($rq) => $rq->where('sub_role_slug', $subRole));
        });
    }

    /**
     * Build a base User query filtered cleanly by target subRole (without invalid user columns).
     */
    protected function buildFilteredPartnerUserQuery(string $subRole): \Illuminate\Database\Eloquent\Builder
    {
        $query = \App\Models\User::query()
            ->where('is_suspended', false)
            ->with(['addresses', 'activeSubscription']);

        if ($subRole === 'corporate') {
            $this->applyCorporateUserFilter($query);
            return $query;
        }

        $query->where('role', \App\Enums\RoleType::Creator)
            ->where('is_creator_approved', true);

        if ($subRole === 'all') {
            return $query;
        }

        $slugs = in_array($subRole, ['school', 'institution'], true)
            ? ['school', 'institution', 'institusi', 'sekolah', 'kampus', 'campus', 'education']
            : [$subRole];

        return $query->where(function ($q) use ($slugs) {
            $q->whereIn('sub_role', $slugs)
                ->orWhereHas('userSubRoles', fn($sq) => $sq->whereIn('sub_role_slug', $slugs)->where('is_active', true));
        });
    }

    /**
     * Query real matching opportunities and creators/partners from database (Rule: Database-backed data only).
     */
    protected function queryMatchedDatabaseItems(string $subRole, string $location): array
    {
        $items = [];
        $locationTokens = $this->extractLocationTokens($location);

        // 1. Query Real Opportunities from Database
        $oppQuery = $this->buildFilteredOpportunityQuery($subRole);
        if (!empty($locationTokens)) {
            $oppQuery->where(function ($q) use ($locationTokens) {
                foreach ($locationTokens as $token) {
                    $q->orWhere('location', 'like', "%{$token}%")
                        ->orWhere('address', 'like', "%{$token}%");
                }
            });
        }

        $opportunities = $oppQuery->latest('created_at')->take(4)->get();

        // Fallback to general open opportunities for the SAME sub_role when city filter yields 0
        if ($opportunities->isEmpty() && !empty($locationTokens)) {
            $opportunities = $this->buildFilteredOpportunityQuery($subRole)
                ->latest('created_at')
                ->take(3)
                ->get();
        }

        foreach ($opportunities as $opp) {
            $items[] = [
                'type' => 'opportunity',
                'id' => (string) $opp->id,
                'title' => (string) $opp->title,
                'description' => (string) ($opp->description ?? 'Peluang proyek terverifikasi di platform Kreavana.'),
                'sub_role' => (string) ($opp->sub_role_slug ?? 'kreator'),
                'location' => (string) ($opp->location ?? 'Indonesia'),
                'budget_range' => (string) ($opp->budget_range ?? 'Kompetitif'),
                'match_score' => '97% Cocok',
                'status' => (string) $opp->status,
                'created_at' => $opp->created_at ? (string) $opp->created_at : null,
            ];
        }

        // 2. Query Real Approved Creators / Corporate Partners from Database (addresses relation only)
        $creatorQuery = $this->buildFilteredPartnerUserQuery($subRole);
        if (!empty($locationTokens)) {
            $creatorQuery->whereHas('addresses', function ($aq) use ($locationTokens) {
                $aq->where(function ($inner) use ($locationTokens) {
                    foreach ($locationTokens as $token) {
                        $inner->orWhere('city', 'like', "%{$token}%")
                            ->orWhere('province', 'like', "%{$token}%")
                            ->orWhere('address', 'like', "%{$token}%");
                    }
                });
            });
        }

        $creators = $creatorQuery->orderByDesc('performance_boost')->take(4)->get();

        // Fallback to general users for the SAME sub_role when city filter yields 0
        if ($creators->isEmpty() && !empty($locationTokens)) {
            $creators = $this->buildFilteredPartnerUserQuery($subRole)
                ->orderByDesc('performance_boost')
                ->take(3)
                ->get();
        }

        foreach ($creators as $c) {
            $addr = $c->addresses->firstWhere('is_default', true) ?? $c->addresses->first();
            $city = $addr?->city;
            $prov = $addr?->province;
            $loc = ($city && $prov) ? "{$city}, {$prov}" : ($city ?? ($addr?->address ?: 'Indonesia'));
            $boost = (float) ($c->performance_boost ?? 0);
            $effectiveSubRole = $c->isCorporate() ? 'corporate' : ((string) ($c->sub_role ?? 'creator'));
            $subRoleLabel = $c->isCorporate()
                ? 'Corporate'
                : (\App\Enums\CreatorSubRole::tryFrom($effectiveSubRole)?->label() ?? ucfirst(str_replace('_', ' ', $effectiveSubRole)));

            $items[] = [
                'type' => 'creator',
                'id' => (string) $c->id,
                'name' => (string) $c->name,
                'username' => (string) $c->username,
                'sub_role' => $effectiveSubRole,
                'sub_role_label' => $subRoleLabel,
                'location' => $loc,
                'avatar_url' => $c->avatar_url,
                'match_score' => ($boost > 0 ? '99% ' : '96% ') . 'Cocok',
                'performance_boost' => $boost > 0 ? "⚡ {$boost}x Booster" : '⭐ Terverifikasi',
            ];
        }

        return $items;
    }

    /**
     * Contextual fallback recommendations tailored to subRole and location.
     */
    protected function generateContextualFallbackRecommendations(string $subRole, string $subRoleLabel, string $location): array
    {
        switch ($subRole) {
            case 'photographer':
                return [
                    [
                        'title' => 'Paket Dokumentasi Komersial & Produk Brand Lokal',
                        'category' => 'Peluang Proyek',
                        'reason' => "Permintaan konten visual produk berkualitas tinggi untuk katalog digital dan media sosial brand lokal di area {$location} sedang meningkat pesat seiring akselerasi e-commerce.",
                        'impact' => 'Potensi peningkatan konversi klien komersial +35% dengan retensi kontrak bulanan.',
                        'match_score' => '98% Cocok',
                        'action_label' => 'Jelajahi Proyek Foto',
                    ],
                    [
                        'title' => 'Aliansi Vendor Wedding Organizer & Paket Bundling Pre-Wedding',
                        'category' => 'Kemitraan Strategis',
                        'reason' => "Bermitra dengan Wedding Organizer dan venue pernikahan terkemuka di area {$location} untuk paket bundling dokumentasi foto & sinematik eksklusif.",
                        'impact' => 'Peningkatan rata-rata nilai transaksi proyek hingga +45%.',
                        'match_score' => '95% Cocok',
                        'action_label' => 'Cari Mitra WO',
                    ],
                    [
                        'title' => 'Pameran Portofolio Budaya & Lisensi Marketplace',
                        'category' => 'Inovasi Layanan',
                        'reason' => "Menampilkan seri karya fotografi arsitektur dan human interest kawasan {$location} di Marketplace Kreavana untuk membuka penjualan lisensi digital.",
                        'impact' => 'Monetisasi portofolio pasif tanpa mengganggu jadwal pemotretan aktif.',
                        'match_score' => '92% Cocok',
                        'action_label' => 'Unggah ke Marketplace',
                    ],
                ];

            case 'videographer':
                return [
                    [
                        'title' => 'Produksi Video Reels & Kampanye Brand Dinamis',
                        'category' => 'Peluang Proyek',
                        'reason' => "Brand lokal dan bisnis F&B/lifestyle di wilayah {$location} membutuhkan format video pendek bernarasi estetik untuk meningkatkan engagement media sosial.",
                        'impact' => 'Frekuensi repeat order proyek naik +50% dengan sistem langganan bulanan.',
                        'match_score' => '98% Cocok',
                        'action_label' => 'Jelajahi Peluang Video',
                    ],
                    [
                        'title' => 'Aftermovie & Dokumentasi Sinematik Event Perusahaan',
                        'category' => 'Kemitraan Strategis',
                        'reason' => "Kolaborasi bersama Event Organizer untuk produksi highlight video dan multi-camera recording acara korporat atau festival di {$location}.",
                        'impact' => 'Akses ke proyek skala besar dengan anggaran multi-juta.',
                        'match_score' => '96% Cocok',
                        'action_label' => 'Hubungi Partner EO',
                    ],
                    [
                        'title' => 'Jasa Color Grading & Post-Production Jarak Jauh',
                        'category' => 'Inovasi Layanan',
                        'reason' => "Menawarkan keahlian teknis editing lanjutan dan color grading kepada kreator konten luar kota yang memerlukan standarisasi visual broadcast.",
                        'impact' => 'Memperluas basis klien tanpa keterbatasan mobilitas fisik.',
                        'match_score' => '91% Cocok',
                        'action_label' => 'Tawarkan Jasa',
                    ],
                ];

            case 'wedding_organizer':
                return [
                    [
                        'title' => 'Paket Pernikahan Terintegrasi (All-In-One Package)',
                        'category' => 'Peluang Proyek',
                        'reason' => "Calon pengantin di area {$location} mengutamakan efisiensi dan transparansi anggaran dengan memilih paket terintegrasi (WO, MUA, dekorasi, dokumentasi) yang terverifikasi.",
                        'impact' => 'Peningkatan rasio closing deal calon pengantin hingga +50%.',
                        'match_score' => '98% Cocok',
                        'action_label' => 'Buat Paket Pernikahan',
                    ],
                    [
                        'title' => 'Kemitraan Eksklusif Venue & Hotel Berbintang',
                        'category' => 'Kemitraan Strategis',
                        'reason' => "Menjadi rekanan resmi hotel dan gedung pernikahan di wilayah {$location} sebagai penyedia jasa perencana pernikahan berlisensi.",
                        'impact' => 'Aliran leads calon pengantin stabil sepanjang tahun.',
                        'match_score' => '96% Cocok',
                        'action_label' => 'Ajukan Kemitraan',
                    ],
                    [
                        'title' => 'Layanan Digital Wedding Planner & RSVP Terpusat',
                        'category' => 'Inovasi Layanan',
                        'reason' => "Menghadirkan koordinasi rundown digital dan buku tamu QR-code untuk modernisasi pengalaman hari pernikahan pengantin.",
                        'impact' => 'Peningkatan kepuasan review klien hingga skor 4.9+ bintang.',
                        'match_score' => '94% Cocok',
                        'action_label' => 'Jelajahi Solusi Digital',
                    ],
                ];

            case 'event_organizer':
                return [
                    [
                        'title' => 'Kurasi Festival Kreatif & Bazar Komunitas UMKM',
                        'category' => 'Peluang Proyek',
                        'reason' => "Peluang kolaborasi dengan dinas pariwisata atau pengelola ruang publik di {$location} untuk menyelenggarakan festival seni dan kuliner berkonsep terpadu.",
                        'impact' => 'Kemitraan sponsorship brand lokal dan perolehan tiket/booth partisipan.',
                        'match_score' => '97% Cocok',
                        'action_label' => 'Rancang Proposal Acara',
                    ],
                    [
                        'title' => 'Konsorsium Vendor Terpadu (Sound, Panggung & Dokumentasi)',
                        'category' => 'Kemitraan Strategis',
                        'reason' => "Mengikat kemitraan jangka panjang dengan vendor panggung, audio visual, dan fotografer lokal terverifikasi di Kreavana untuk penawaran kompetitif satu pintu.",
                        'impact' => 'Efisiensi biaya operasional hingga 25% dan kepuasan klien meningkat.',
                        'match_score' => '95% Cocok',
                        'action_label' => 'Bentuk Konsorsium Vendor',
                    ],
                    [
                        'title' => 'Pengelolaan Gathering Korporat & Aktivasi Merek Hybrid',
                        'category' => 'Inovasi Layanan',
                        'reason' => "Merancang konsep acara korporat interaktif dengan live-streaming multi-platform untuk perusahaan dan instansi pemerintah di {$location}.",
                        'impact' => 'Diferensiasi layanan premium dibanding EO konvensional.',
                        'match_score' => '93% Cocok',
                        'action_label' => 'Jelajahi Proyek Korporat',
                    ],
                ];

            case 'corporate':
            case 'company':
            case 'business':
                return [
                    [
                        'title' => "Pengadaan Kampanye Branding & Konten Enterprise di {$location}",
                        'category' => 'Peluang Proyek',
                        'reason' => "Perusahaan dan brand korporat di area {$location} mengoptimalkan kolaborasi bersama agensi, fotografer, dan rumah produksi terkurasi untuk kampanye peluncuran produk serta laporan tahunan.",
                        'impact' => 'Efisiensi biaya pengadaan kreatif B2B hingga 25% dengan kontrak SLA terjamin.',
                        'match_score' => '98% Cocok',
                        'action_label' => 'Jelajahi Mitra Korporat',
                    ],
                    [
                        'title' => 'Program Kemitraan Magang Vokasi & Rekrutmen Talenta DUDI',
                        'category' => 'Kemitraan Strategis',
                        'reason' => "Menghubungkan divisi kreatif perusahaan di {$location} dengan sekolah/kampus vokasi untuk membangun pipeline talenta desain, videografi, dan media digital.",
                        'impact' => 'Mempercepat kesiapan talenta muda dan memperkuat program CSR pendidikan.',
                        'match_score' => '96% Cocok',
                        'action_label' => 'Lihat Program Magang',
                    ],
                    [
                        'title' => 'Konsolidasi Vendor Produksi Event, MICE & Aktivasi Merek',
                        'category' => 'Inovasi Layanan',
                        'reason' => "Standarisasi pengadaan EO, MC bilingual, panggung, dan tim dokumentasi multi-kamera melalui skema escrow aman di Kreavana.",
                        'impact' => 'Pengendalian mutu acara korporat lebih terukur dan transparan.',
                        'match_score' => '94% Cocok',
                        'action_label' => 'Kelola Vendor Mitra',
                    ],
                ];

            case 'institution':
            case 'school':
                return [
                    [
                        'title' => 'Program Kemitraan Magang Industri Vokasi (DUDI)',
                        'category' => 'Kemitraan Strategis',
                        'reason' => "Menghubungkan program magang siswa dengan mitra industri kreatif terverifikasi di area {$location} untuk meningkatkan relevansi kurikulum.",
                        'impact' => 'Penyaluran talenta siswa mencapai target IKU & akreditasi institusi.',
                        'match_score' => '98% Cocok',
                        'action_label' => 'Ajukan Kerjasama Industri',
                    ],
                    [
                        'title' => 'Pameran Karya Siswa & Showcase Kurasi Talenta',
                        'category' => 'Peluang Proyek',
                        'reason' => "Mempublikasikan karya unggulan siswa SMK/Mahasiswa pada Galeri Karya Kreavana agar dilirik oleh studio kreatif dan agensi perekrut.",
                        'impact' => 'Tingkat serapan kerja lulusan meningkat pesat pasca kelulusan.',
                        'match_score' => '95% Cocok',
                        'action_label' => 'Kurasi Karya Siswa',
                    ],
                    [
                        'title' => 'Workshop Praktisi Mengajar & Sertifikasi Industri',
                        'category' => 'Inovasi Layanan',
                        'reason' => "Mengundang mentor industri terkemuka di Kreavana untuk mengisi kuliah tamu dan pendampingan proyek nyata di kampus/sekolah.",
                        'impact' => 'Kualitas kompetensi lulusan terstandarisasi kebutuhan pasar kerja.',
                        'match_score' => '93% Cocok',
                        'action_label' => 'Undang Praktisi Mengajar',
                    ],
                ];

            case 'editor':
                return [
                    [
                        'title' => 'Layanan Editing Video Pendek Retainer untuk Brand & Kreator',
                        'category' => 'Peluang Proyek',
                        'reason' => "Banyak konten kreator dan brand di {$location} membutuhkan editor andal dengan sistem kontrak bulanan untuk konsistensi unggahan harian.",
                        'impact' => 'Arus kas bulanan stabil dengan retensi klien minimal 3-6 bulan.',
                        'match_score' => '97% Cocok',
                        'action_label' => 'Cari Klien Retainer',
                    ],
                    [
                        'title' => 'Kolaborasi Rumah Produksi & Agensi Iklan',
                        'category' => 'Kemitraan Strategis',
                        'reason' => "Menjadi partner post-production terpercaya untuk agensi digital di {$location} dalam pengolahan iklan komersial berstandar tinggi.",
                        'impact' => 'Portofolio bertaraf nasional dan nilai kontrak proyek lebih besar.',
                        'match_score' => '95% Cocok',
                        'action_label' => 'Tawarkan Jasa Editing',
                    ],
                    [
                        'title' => 'Spesialisasi Motion Graphics & Visual Branding',
                        'category' => 'Inovasi Layanan',
                        'reason' => "Mengembangkan keahlian animasi 2D/3D pendukung video untuk memenuhi kebutuhan animasi aset interaktif di era digital.",
                        'impact' => 'Penetapan tarif jasa premium hingga 2x lipat tarif standar.',
                        'match_score' => '92% Cocok',
                        'action_label' => 'Promosikan Motion Graphic',
                    ],
                ];

            case 'mc':
                return [
                    [
                        'title' => 'Hosting Acara Korporat, Seminar & Peluncuran Produk',
                        'category' => 'Peluang Proyek',
                        'reason' => "Banyak instansi pemerintah dan perusahaan di kawasan {$location} mencari MC bilingual profesional dengan penguasaan panggung yang dinamis.",
                        'impact' => 'Peningkatan frekuensi booking acara formal dengan honor premium.',
                        'match_score' => '98% Cocok',
                        'action_label' => 'Jelajahi Proyek MC',
                    ],
                    [
                        'title' => 'Aliansi Bersama Event Organizer & Wedding Planner',
                        'category' => 'Kemitraan Strategis',
                        'reason' => "Menjadi MC rekanan tetap untuk EO dan WO di area {$location} agar selalu dimasukkan dalam rekomendasi utama paket acara.",
                        'impact' => 'Jadwal acara terisi penuh pada akhir pekan sepanjang musim pernikahan.',
                        'match_score' => '96% Cocok',
                        'action_label' => 'Hubungi Partner WO/EO',
                    ],
                    [
                        'title' => 'Pelatihan Public Speaking & Personal Branding Masterclass',
                        'category' => 'Inovasi Layanan',
                        'reason' => "Membuka sesi coaching komunikasi publik untuk calon profesional dan mahasiswa di Kreavana.",
                        'impact' => 'Membangun reputasi mentor dan memperluas relasi komunitas.',
                        'match_score' => '91% Cocok',
                        'action_label' => 'Buka Kelas Mentoring',
                    ],
                ];

            case 'makeup_artist':
                return [
                    [
                        'title' => 'Paket Rias Pengantin & Foto Studio Pre-Wedding',
                        'category' => 'Peluang Proyek',
                        'reason' => "Tingginya permintaan rias pengantin modern dan flawless di wilayah {$location} membuka peluang kerja sama intensif dengan studio foto lokal.",
                        'impact' => 'Peningkatan pemesanan terintegrasi dan omset musim pernikahan.',
                        'match_score' => '98% Cocok',
                        'action_label' => 'Lihat Peluang MUA',
                    ],
                    [
                        'title' => 'Kemitraan Vendor Wedding Organizer & Sanggar Busana',
                        'category' => 'Kemitraan Strategis',
                        'reason' => "Bermitra dengan WO terdaftar di Kreavana untuk menjadi MUA prioritas pengantin dan keluarga besar.",
                        'impact' => 'Rata-rata 4-8 penanganan pengantin per bulan secara teratur.',
                        'match_score' => '95% Cocok',
                        'action_label' => 'Ajukan Kerjasama WO',
                    ],
                    [
                        'title' => 'Beauty Workshop & Rias Komersial Wisuda',
                        'category' => 'Inovasi Layanan',
                        'reason' => "Mengadakan kelas kecantikan tematik dan paket bundling wisuda institusi pendidikan sekitar {$location}.",
                        'impact' => 'Pendapatan tambahan pada momen wisuda berkala.',
                        'match_score' => '92% Cocok',
                        'action_label' => 'Buka Paket Wisuda',
                    ],
                ];

            case 'singer':
                return [
                    [
                        'title' => 'Pengisi Acara Musik Akustik Wedding & Kafe Lifestyle',
                        'category' => 'Peluang Proyek',
                        'reason' => "Kafe, restoran, dan resepsi pernikahan di area {$location} mencari talent musisi live-acoustic dengan aransemen lagu kontemporer yang elegan.",
                        'impact' => 'Jadwal manggung mingguan reguler dengan pemasukan terprediksi.',
                        'match_score' => '97% Cocok',
                        'action_label' => 'Jelajahi Proyek Musik',
                    ],
                    [
                        'title' => 'Kemitraan Bersama Event Organizer & Wedding Planner',
                        'category' => 'Kemitraan Strategis',
                        'reason' => "Menjadi talent musik tetap dalam paket pernikahan dan gathering perusahaan di wilayah {$location}.",
                        'impact' => 'Kontrak performa profesional berulang dengan tarif kompetitif.',
                        'match_score' => '95% Cocok',
                        'action_label' => 'Bermitra dengan EO/WO',
                    ],
                    [
                        'title' => 'Lisensi Musik Komersial & Jingle Brand Lokal',
                        'category' => 'Inovasi Layanan',
                        'reason' => "Memproduksi jingle audio branding dan sound effect untuk kebutuhan iklan produk UMKM di Kreavana.",
                        'impact' => 'Royalti dan penjualan hak pakai karya audio di marketplace.',
                        'match_score' => '92% Cocok',
                        'action_label' => 'Jual Karya Audio',
                    ],
                ];

            default:
                return [
                    [
                        'title' => "Kolaborasi Konsorsium Proyek Brand di {$location}",
                        'category' => 'Kemitraan Strategis',
                        'reason' => "Membangun konsorsium tim kreatif gabungan di area {$location} untuk menangani tender kampanye branding dan produksi digital skala korporat.",
                        'impact' => 'Peluang memenangkan kontrak proyek bernilai tinggi meningkat hingga +40%.',
                        'match_score' => '98% Cocok',
                        'action_label' => 'Jelajahi Kolaborasi',
                    ],
                    [
                        'title' => 'Ekspansi Jasa Kreatif Digital & Portofolio Interaktif',
                        'category' => 'Inovasi Layanan',
                        'reason' => "Memaksimalkan fitur etalase dan reputasi terverifikasi di Kreavana untuk menjangkau klien korporat dan institusi di {$location} yang mencari talenta profesional terpercaya.",
                        'impact' => 'Perluasan pangsa pasar dan kredibilitas profil terverifikasi.',
                        'match_score' => '95% Cocok',
                        'action_label' => 'Tingkatkan Profil',
                    ],
                    [
                        'title' => "Kemitraan Komunitas & Inkubasi Talenta Kreatif {$location}",
                        'category' => 'Peluang Proyek',
                        'reason' => "Menginisiasi workshop bersama komunitas dan asosiasi kreatif di {$location} untuk membangun pipeline talenta dan prospek klien baru.",
                        'impact' => 'Membangun reputasi otoritas industri dan aliran prospek organik.',
                        'match_score' => '92% Cocok',
                        'action_label' => 'Lihat Komunitas',
                    ],
                ];
        }
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
                    if ($this->isCreatorRecommendationIntent($message)) {
                        $recommendationCards = $this->findRelevantCreators($message, 15);

                        if (!empty($recommendationCards)) {
                            $count = count($recommendationCards);
                            $prompt = $message . "\n\n[SISTEM PLATFORM KREAVANA]:\nDitemukan {$count} akun kreator terverifikasi yang cocok dengan kriteria pencarian dan telah ditampilkan secara visual pada daftar kartu rekomendasi sistem di layar pengguna.\nTUGAS ANDA: Berikan pesan pengantar yang sangat singkat, ramah, dan langsung ke intinya (cukup 1-2 kalimat saja, contoh: 'Berikut adalah rekomendasi {$count} akun kreator terverifikasi di Kreavana yang sesuai dengan kebutuhan Anda:').\nATURAN KETAT: JANGAN menjabarkan atau menulis ulang profil kreator satu per satu di rangkuman teks ini, karena seluruh akun beserta portofolio dan profil lengkapnya sudah ditampilkan langsung pada kartu rekomendasi sistem.";
                        } else {
                            $prompt = $message . "\n\n[SISTEM PLATFORM KREAVANA]:\nPengguna mencari rekomendasi kreator/jasa, namun sistem belum menemukan akun kreator yang cocok dengan spesifikasi tersebut di database saat ini.\nTUGAS ANDA: Beritahu pengguna dengan sopan dan ramah bahwa belum ditemukan kreator yang spesifik sesuai kriteria tersebut di database, dan sarankan mereka untuk mempublikasikan lowongan/kebutuhan melalui menu 'Proyek Saya' agar kreator yang berminat dapat langsung mengajukan proposal.";
                        }
                    } else {
                        // User TIDAK meminta rekomendasi akun atau kreator.
                        // Berikan jawaban langsung atas pertanyaan atau sapaan pengguna.
                        $prompt = $message . "\n\n[SISTEM PLATFORM KREAVANA]:\nTUGAS ANDA: Jawab pertanyaan, sapaan, atau pesan pengguna di atas secara langsung, jelas, ramah, dan solutif sebagai asisten resmi Kreavana.\nATURAN KETAT: JANGAN menyapa dengan menawarkan daftar rekomendasi akun kreator atau membuat daftar rekomendasi akun fiktif, karena pengguna tidak meminta rekomendasi akun. Fokuslah sepenuhnya untuk menjawab pertanyaan pengguna dengan tepat.";
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
     * Cek apakah pesan pengguna memang bermaksud mencari atau meminta rekomendasi akun/kreator/jasa.
     */
    protected function isCreatorRecommendationIntent(string $message): bool
    {
        $msg = strtolower(trim($message));
        if (empty($msg)) {
            return false;
        }

        // 1. Abaikan sapaan umum murni (greetings)
        if (preg_match('/^(hi|halo|hello|hai|hei|p|ping|selamat\s*(pagi|siang|sore|malam)|assalamu[\'\w]*|tes|test|oy|woy|help)[\s\!\.\?]*$/i', $msg)) {
            return false;
        }

        // 2. Pertanyaan definisi/penjelasan (apa itu, jelaskan, bagaimana cara, kenapa, dll.)
        if (preg_match('/^(apa\s*itu|jelaskan|apakah|bagaimana\s*cara|gimana\s*cara|mengapa|kenapa|tips|panduan|tutorial)\b/i', $msg)) {
            // Kecuali jika ada kata "rekomendasi akun/kreator"
            if (!preg_match('/\b(rekomendasi|rekomendasikan)\s+(akun|kreator|creator|talent|freelance|vendor|fotografer|videografer|desainer|mc|mua|wo|eo)\b/i', $msg)) {
                return false;
            }
        }

        // 3. Keyword eksplisit minta rekomendasi akun / kreator / talent / jasa
        if (preg_match('/\b(rekomendasi|rekomendasikan|sarankan|referensi)\b/i', $msg)) {
            if (preg_match('/\b(kreator|creator|akun|orang|talent|freelance|freelancer|vendor|mitra|jasa|siapa|wo\b|eo\b|wedding\s*organi[sz]e*r*|event\s*organi[sz]e*r*|fotografer|photographer|videografer|videographer|desainer|designer|editor|animator|mc|mua|makeup|singer|penyanyi|musisi|musician|band|drone|model)\b/i', $msg)) {
                return true;
            }
            if (preg_match('/^(minta\s*)?rekomendasi(\s*(dong|ya|pls|please|kreator|akun))?$/i', $msg)) {
                return true;
            }
        }

        // 4. Keyword pencarian / perekrutan / kebutuhan kreator
        $hasSearchVerb = preg_match('/\b(cari|carikan|mencari|butuh|membutuhkan|perlu|memerlukan|hire|pekerjakan|sewa|booking|kontrak|ada\s*ga|ada\s*gk|ada\s*kah|adakah|ada\s*yang\s*bisa|siapa\s*yang\s*bisa|tolong\s*carikan)\b/i', $msg);

        $hasCreatorTarget = preg_match('/\b(kreator|creator|talent|freelance|freelancer|vendor|mitra|jasa|wo\b|eo\b|wedding\s*organi[sz]e*r*|event\s*organi[sz]e*r*|fotografer|photographer|foto|videografer|videographer|video|shooting|edit\s*video|editing|editor|desain|desainer|designer|logo|animator|animasi|mc|host|pembawa\s*acara|mua|makeup|tata\s*rias|singer|penyanyi|musisi|musician|band|tukang\s*kendang|drone|model)\b/i', $msg);

        if ($hasSearchVerb && $hasCreatorTarget) {
            // Hindari false-positive seperti "bagaimana cara mencari proyek" atau "cara cari kerja"
            if (!preg_match('/\b(cara|panduan|tips)\s*(cari|mencari)\s*(event|proyek|project|pekerjaan|lowongan|job|klien)\b/i', $msg)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Cari dan rangking kreator yang relevan dengan pertanyaan / prompt pengguna.
     * Mendukung deteksi sub-role spesifik (Wedding Organizer, Videografer, Fotografer, dll.),
     * deteksi lokasi geografis (Bekasi, Jakarta, Bandung, dll.), serta perangkingan booster akun.
     */
    protected function findRelevantCreators(string $message, int $limit = 15): array
    {
        if (!$this->isCreatorRecommendationIntent($message)) {
            return [];
        }

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
