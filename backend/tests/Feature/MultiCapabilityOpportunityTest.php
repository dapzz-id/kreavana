<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\User;
use App\Models\Opportunity;
use App\Models\OpportunityRequirement;
use App\Enums\RoleType;
use App\Enums\CreatorSubRole;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tymon\JWTAuth\Facades\JWTAuth;

class MultiCapabilityOpportunityTest extends TestCase
{
    use RefreshDatabase;

    protected User $client;
    protected string $clientToken;

    protected function setUp(): void
    {
        parent::setUp();

        $this->client = User::factory()->create([
            'role' => RoleType::User,
        ]);
        $this->clientToken = JWTAuth::fromUser($this->client);
    }

    public function test_can_create_opportunity_with_multi_capability_requirements()
    {
        $response = $this->actingAsApi($this->client)
            ->postJson('/api/opportunities', [
                'title' => 'Festival Musik Tradisional & Modern',
                'description' => 'Membutuhkan pemain kendang, fotografer, dan sound engineer.',
                'type' => 'project',
                'location' => 'Bandung, Jawa Barat',
                'budget_range' => 'Rp15.000.000 - Rp25.000.000',
                'requirements' => [
                    [
                        'sub_role_slug' => 'tukang_kendang',
                        'quantity' => 2,
                        'notes' => 'Menguasai kendang jaipong dan sunda',
                    ],
                    [
                        'sub_role_slug' => 'photographer',
                        'quantity' => 1,
                        'notes' => 'Dokumentasi stage photography',
                    ],
                ],
            ]);

        $response->assertStatus(201)
            ->assertJsonPath('status', true);

        $oppId = $response->json('data.id');
        $this->assertDatabaseHas('opportunities', [
            'id' => $oppId,
            'title' => 'Festival Musik Tradisional & Modern',
            'sub_role_slug' => 'tukang_kendang',
        ]);

        $this->assertDatabaseHas('opportunity_requirements', [
            'opportunity_id' => $oppId,
            'sub_role_slug' => 'tukang_kendang',
            'quantity' => 2,
        ]);

        $this->assertDatabaseHas('opportunity_requirements', [
            'opportunity_id' => $oppId,
            'sub_role_slug' => 'photographer',
            'quantity' => 1,
        ]);
    }

    public function test_can_filter_opportunities_by_multi_subroles()
    {
        $opp1 = Opportunity::create([
            'title' => 'Proyek Kendang Jaipong',
            'sub_role_slug' => 'tukang_kendang',
            'type' => 'project',
            'location' => 'Bandung',
            'status' => 'open',
            'posted_by' => $this->client->id,
            'created_at' => now(),
        ]);

        $opp2 = Opportunity::create([
            'title' => 'Video Klip Dangdut',
            'sub_role_slug' => 'videographer',
            'type' => 'project',
            'location' => 'Jakarta',
            'status' => 'open',
            'posted_by' => $this->client->id,
            'created_at' => now(),
        ]);

        $opp3 = Opportunity::create([
            'title' => 'MC Seminar Teknologi',
            'sub_role_slug' => 'mc',
            'type' => 'project',
            'location' => 'Surabaya',
            'status' => 'open',
            'posted_by' => $this->client->id,
            'created_at' => now(),
        ]);

        // Filter for tukang_kendang and videographer
        $res = $this->getJson('/api/opportunities?sub_roles[]=tukang_kendang&sub_roles[]=videographer');
        $res->assertStatus(200);
        $data = $res->json('data');

        $titles = collect($data)->pluck('title')->all();
        $this->assertContains('Proyek Kendang Jaipong', $titles);
        $this->assertContains('Video Klip Dangdut', $titles);
        $this->assertNotContains('MC Seminar Teknologi', $titles);
    }

    public function test_nearby_spatial_distance_filter()
    {
        // Bandung coordinates: -6.9175, 107.6191
        $oppBandung = Opportunity::create([
            'title' => 'Event Gedung Sate',
            'sub_role_slug' => 'photographer',
            'type' => 'location',
            'location' => 'Bandung',
            'latitude' => -6.9025,
            'longitude' => 107.6186,
            'status' => 'open',
            'posted_by' => $this->client->id,
            'created_at' => now(),
        ]);

        // Jakarta coordinates: -6.2088, 106.8456 (approx 120km from Bandung)
        $oppJakarta = Opportunity::create([
            'title' => 'Event Monas',
            'sub_role_slug' => 'photographer',
            'type' => 'location',
            'location' => 'Jakarta',
            'latitude' => -6.1754,
            'longitude' => 106.8272,
            'status' => 'open',
            'posted_by' => $this->client->id,
            'created_at' => now(),
        ]);

        // Query near Bandung with 25km radius
        $res = $this->getJson('/api/opportunities/map?lat=-6.9175&lng=107.6191&radius_km=25');
        $res->assertStatus(200);
        $data = $res->json('data');

        $titles = collect($data)->pluck('title')->all();
        $this->assertContains('Event Gedung Sate', $titles);
        $this->assertNotContains('Event Monas', $titles);
    }
}
