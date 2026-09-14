<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\User;
use App\Models\PortfolioItem;
use App\Enums\RoleType;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

class ExternalPortfolioTest extends TestCase
{
    use RefreshDatabase;

    protected User $creator;
    protected User $otherCreator;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');

        $this->creator = User::factory()->create([
            'role' => RoleType::Creator,
            'is_creator_approved' => true,
        ]);
        $this->otherCreator = User::factory()->create([
            'role' => RoleType::Creator,
            'is_creator_approved' => true,
        ]);
    }

    public function test_creator_can_create_external_pre_kreavana_portfolio()
    {
        $file = UploadedFile::fake()->image('wedding_past.jpg');

        $response = $this->actingAsApi($this->creator)
            ->postJson('/api/portfolio', [
                'title' => 'Dokumentasi Pernikahan Adat Sunda',
                'category' => 'wedding',
                'description' => 'Dokumentasi foto & video adat sunda sebelum bergabung di Kreavana.',
                'event_date' => '2025-06-15',
                'location' => 'Bandung',
                'source' => 'external',
                'client_name' => 'Keluarga Bpk. Hartono',
                'image' => $file,
            ]);

        $response->assertStatus(201)
            ->assertJsonPath('status', true);

        $itemId = $response->json('data.id');
        $this->assertDatabaseHas('portfolio_items', [
            'id' => $itemId,
            'user_id' => $this->creator->id,
            'title' => 'Dokumentasi Pernikahan Adat Sunda',
            'location' => 'Bandung',
            'source' => 'external',
            'verification_status' => 'self_reported',
            'client_name' => 'Keluarga Bpk. Hartono',
        ]);

        $item = PortfolioItem::find($itemId);
        $this->assertEquals('2025-06-15', $item->event_date?->format('Y-m-d'));
    }

    public function test_creator_cannot_modify_another_creators_portfolio()
    {
        $item = PortfolioItem::create([
            'user_id' => $this->creator->id,
            'title' => 'Konser Rock Bandung',
            'category' => 'event',
            'image_url' => 'portfolio/test.jpg',
            'sort_order' => 0,
            'source' => 'external',
        ]);

        $response = $this->actingAsApi($this->otherCreator)
            ->putJson("/api/portfolio/{$item->id}", [
                'title' => 'Judul Diretas',
            ]);

        $response->assertStatus(404);
    }
}
