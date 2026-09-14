<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\User;
use App\Models\Opportunity;
use App\Enums\RoleType;
use Illuminate\Foundation\Testing\RefreshDatabase;

class GuestPublicBrowsingTest extends TestCase
{
    use RefreshDatabase;

    public function test_guest_can_browse_opportunities_and_map_without_token()
    {
        $creator = User::factory()->create(['role' => RoleType::Creator]);
        Opportunity::create([
            'title' => 'Konser Amal Bandung',
            'sub_role_slug' => 'singer',
            'type' => 'location',
            'location' => 'Bandung',
            'latitude' => -6.9175,
            'longitude' => 107.6191,
            'status' => 'open',
            'posted_by' => $creator->id,
            'created_at' => now(),
        ]);

        // 1. Guest can browse opportunity list
        $resList = $this->getJson('/api/opportunities');
        $resList->assertStatus(200)
            ->assertJsonPath('status', true);
        $this->assertNotEmpty($resList->json('data'));

        // 2. Guest can browse opportunity map locations
        $resMap = $this->getJson('/api/opportunities/map');
        $resMap->assertStatus(200)
            ->assertJsonPath('status', true);
        $this->assertNotEmpty($resMap->json('data'));

        // 3. Guest can fetch client-dashboard overview
        $resOverview = $this->getJson('/api/client-dashboard/overview');
        $resOverview->assertStatus(200)
            ->assertJsonPath('status', true)
            ->assertJsonPath('data.summary.role_type', 'guest');
    }

    public function test_guest_cannot_perform_protected_actions()
    {
        // 1. Cannot create opportunity
        $resCreate = $this->postJson('/api/opportunities', [
            'title' => 'Proyek Ilegal Guest',
            'sub_role_slug' => 'mc',
            'type' => 'project',
        ]);
        $resCreate->assertStatus(401);

        // 2. Cannot apply to opportunity
        $resApply = $this->postJson('/api/opportunities/00000000-0000-0000-0000-000000000000/applications', [
            'sub_role_slug' => 'mc',
            'pitch_message' => 'Saya guest ingin melamar.',
        ]);
        $resApply->assertStatus(401);
    }
}
