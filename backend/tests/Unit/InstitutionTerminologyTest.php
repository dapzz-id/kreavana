<?php

namespace Tests\Unit;

use App\Services\AiService;
use App\Services\DashboardService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class InstitutionTerminologyTest extends TestCase
{
    use RefreshDatabase;

    public function test_dashboard_service_institution_stats_use_general_peserta_terminology(): void
    {
        /** @var DashboardService $service */
        $service = app(DashboardService::class);

        $stats = $service->getStats('institution', 'institution');
        $labels = collect($stats)->pluck('stat_label')->all();

        $this->assertContains('Karya Peserta', $labels);
        $this->assertNotContains('Karya Siswa', $labels);

        $schoolAliasStats = $service->getStats('school', 'client');
        $aliasLabels = collect($schoolAliasStats)->pluck('stat_label')->all();
        $this->assertContains('Karya Peserta', $aliasLabels);
        $this->assertNotContains('Karya Siswa', $aliasLabels);
    }

    public function test_ai_service_institution_recommendations_use_general_peserta_terminology(): void
    {
        /** @var AiService $aiService */
        $aiService = app(AiService::class);

        $reflection = new \ReflectionClass($aiService);
        $method = $reflection->getMethod('generateContextualFallbackRecommendations');
        $method->setAccessible(true);

        $cards = $method->invoke($aiService, 'institution', 'Institusi Pendidikan', 'Bekasi');

        $this->assertIsArray($cards);
        $this->assertNotEmpty($cards);

        $serialized = strtolower(json_encode($cards, JSON_UNESCAPED_UNICODE) ?: '');
        $this->assertStringContainsString('peserta', $serialized);
        $this->assertStringNotContainsString('siswa', $serialized);
        $this->assertStringNotContainsString('mahasiswa', $serialized);

        $titles = collect($cards)->pluck('title')->all();
        $this->assertContains('Pameran Karya Peserta & Showcase Kurasi Talenta', $titles);
    }
}
