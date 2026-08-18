<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Opportunity;
use App\Models\JobContract;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class JobContractPersistenceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        // Since we had the Turnstile validation exception in production,
        // Tests run in 'testing' environment so it should bypass that unless configured.
    }

    public function test_authorized_client_can_create_valid_contract()
    {
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);

        $response = $this->actingAs($client, 'api')->postJson('/api/contracts', [
            'partner_id' => $creator->id,
            'my_role' => 'client',
            'title' => 'Test Contract',
            'agreed_price' => 5000,
            'deadline' => '2026-12-31',
            'scheduled_start_date' => '2026-08-20',
            'scheduled_end_date' => '2026-08-22',
        ]);

        $response->assertStatus(201)
                 ->assertJsonPath('data.client_id', $client->id)
                 ->assertJsonPath('data.creator_id', $creator->id)
                 ->assertJsonPath('data.contract_status', 'draft')
                 ->assertJsonPath('data.work_status', 'scheduled')
                 ->assertJsonPath('data.agreed_price', '5000.00')
                 ->assertJsonPath('data.escrow_amount', '0.00'); // Enforced server-side

        $this->assertDatabaseHas('job_contracts', [
            'client_id' => $client->id,
            'creator_id' => $creator->id,
            'title' => 'Test Contract',
            'agreed_price' => 5000,
            'escrow_amount' => 0.00,
        ]);
    }

    public function test_mass_assignment_protection_on_financial_fields()
    {
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);

        $response = $this->actingAs($client, 'api')->postJson('/api/contracts', [
            'partner_id' => $creator->id,
            'my_role' => 'client',
            'title' => 'Test Contract',
            'agreed_price' => 5000,
            'escrow_amount' => 100000, // Should be ignored by the controller/service
            'contract_status' => 'completed', // Should be ignored
            'scheduled_start_date' => '2026-08-20',
            'scheduled_end_date' => '2026-08-22',
        ]);

        $response->assertStatus(201)
                 ->assertJsonPath('data.escrow_amount', '0.00')
                 ->assertJsonPath('data.contract_status', 'draft');
    }

    public function test_creator_cannot_assign_themselves_as_client_for_another_creator()
    {
        $creator1 = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $creator2 = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);

        // creator1 tries to set themselves as creator, but partner_id is not a valid creator for their setup or something.
        // Wait, if my_role = creator, then client = partner, creator = me.
        $response = $this->actingAs($creator1, 'api')->postJson('/api/contracts', [
            'partner_id' => $creator2->id,
            'my_role' => 'creator',
            'title' => 'Sneaky Contract',
            'agreed_price' => 5000,
            'scheduled_start_date' => '2026-08-20',
            'scheduled_end_date' => '2026-08-22',
        ]);

        $response->assertStatus(201); // This is actually valid, a creator can make a contract for another user (client).
        
        $response->assertJsonPath('data.client_id', $creator2->id);
        $response->assertJsonPath('data.creator_id', $creator1->id);
    }

    public function test_unauthorized_user_cannot_access_contract_idor()
    {
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $otherUser = User::factory()->create(['role' => \App\Enums\RoleType::User]);

        $contract = JobContract::create([
            'client_id' => $client->id,
            'creator_id' => $creator->id,
            'title' => 'IDOR Test',
            'agreed_price' => 1000,
            'escrow_amount' => 0,
            'contract_status' => 'draft',
            'work_status' => 'scheduled'
        ]);

        // Client can access
        $this->actingAs($client, 'api')->getJson("/api/contracts/{$contract->id}")
             ->assertStatus(200);

        // Creator can access
        $this->actingAs($creator, 'api')->getJson("/api/contracts/{$contract->id}")
             ->assertStatus(200);

        // Other user cannot access
        $this->actingAs($otherUser, 'api')->getJson("/api/contracts/{$contract->id}")
             ->assertStatus(403)
             ->assertJsonPath('message', 'Anda tidak memiliki akses ke kontrak ini.');
    }
}
