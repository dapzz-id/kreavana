<?php

namespace Tests\Unit;

use Tests\TestCase;
use App\Services\AiService;
use App\Models\User;
use App\Models\UserAddress;
use App\Enums\RoleType;
use App\Enums\CreatorSubRole;
use Illuminate\Foundation\Testing\RefreshDatabase;

class AiServiceCreatorRecommendationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        // Seed 1 wedding organizer in Bekasi
        $wo = User::factory()->create([
            'name' => 'Kreavana Wedding Organizer',
            'username' => 'kreavana_wo',
            'role' => RoleType::Creator,
            'sub_role' => CreatorSubRole::WEDDING_ORGANIZER->value,
            'is_creator_approved' => true,
        ]);
        UserAddress::create([
            'user_id' => $wo->id,
            'label' => 'Kantor',
            'recipient_name' => $wo->name,
            'phone' => '081234567890',
            'address' => 'Jl. Ahmad Yani',
            'city' => 'Kota Bekasi',
            'province' => 'Jawa Barat',
            'postal_code' => '17144',
            'is_default' => true,
        ]);

        // Seed 1 photographer in Jakarta
        $photo = User::factory()->create([
            'name' => 'Jakarta Photo',
            'username' => 'jkt_photo',
            'role' => RoleType::Creator,
            'sub_role' => CreatorSubRole::PHOTOGRAPHER->value,
            'is_creator_approved' => true,
        ]);
        UserAddress::create([
            'user_id' => $photo->id,
            'label' => 'Studio',
            'recipient_name' => $photo->name,
            'phone' => '081234567891',
            'address' => 'Jl. Sudirman',
            'city' => 'Jakarta Pusat',
            'province' => 'DKI Jakarta',
            'postal_code' => '10220',
            'is_default' => true,
        ]);

        // Seed 1 community (should NOT match wedding organizer)
        User::factory()->create([
            'name' => 'Komunitas Kreatif',
            'username' => 'komunitas_kreatif',
            'role' => RoleType::Creator,
            'sub_role' => CreatorSubRole::COMMUNITY->value,
            'is_creator_approved' => true,
        ]);
    }

    public function test_wedding_organizer_query_only_returns_wedding_organizers()
    {
        $aiService = app(AiService::class);

        $reflection = new \ReflectionClass($aiService);
        $method = $reflection->getMethod('findRelevantCreators');
        $method->setAccessible(true);

        $results = $method->invoke($aiService, 'rekomendasi wedding organizeer di bekasi', 6);

        $this->assertNotEmpty($results, 'Harus menemukan wedding organizer');

        foreach ($results as $card) {
            $this->assertEquals('wedding_organizer', $card['sub_role'], 'Semua kartu rekomendasi harus bertipe wedding_organizer');
            $this->assertNotEquals('community', $card['sub_role'], 'Tidak boleh ada community di hasil wedding organizer');
        }
    }

    public function test_photographer_query_only_returns_photographers()
    {
        $aiService = app(AiService::class);

        $reflection = new \ReflectionClass($aiService);
        $method = $reflection->getMethod('findRelevantCreators');
        $method->setAccessible(true);

        $results = $method->invoke($aiService, 'cari fotografer profesional di jakarta', 6);

        $this->assertNotEmpty($results, 'Harus menemukan fotografer');

        foreach ($results as $card) {
            $this->assertEquals('photographer', $card['sub_role'], 'Semua kartu rekomendasi harus bertipe photographer');
        }
    }
}
