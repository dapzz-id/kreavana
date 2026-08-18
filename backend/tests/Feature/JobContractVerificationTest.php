<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Opportunity;
use App\Models\JobContract;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use Illuminate\Support\Str;

class JobContractVerificationTest extends TestCase
{
    use RefreshDatabase;

    public function test_contract_list_idor_protection()
    {
        $client1 = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $creator1 = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $contract1 = JobContract::create([
            'client_id' => $client1->id,
            'creator_id' => $creator1->id,
            'title' => 'Contract A',
            'agreed_price' => 1000, 'scheduled_start_date' => date('Y-m-d'), 'scheduled_end_date' => date('Y-m-d'),
            'escrow_amount' => 0,
            'contract_status' => 'draft',
            'work_status' => 'scheduled'
        ]);

        $client2 = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $creator2 = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $contract2 = JobContract::create([
            'client_id' => $client2->id,
            'creator_id' => $creator2->id,
            'title' => 'Contract B',
            'agreed_price' => 2000,
            'escrow_amount' => 0,
            'contract_status' => 'draft',
            'work_status' => 'scheduled'
        ]);

        // Client 1 should only see Contract A
        $response = $this->actingAs($client1, 'api')->getJson('/api/contracts');
        $response->assertStatus(200);
        $response->assertJsonCount(1, 'data');
        $response->assertJsonPath('data.0.id', $contract1->id);

        // Client 2 should only see Contract B
        $response2 = $this->actingAs($client2, 'api')->getJson('/api/contracts');
        $response2->assertStatus(200);
        $response2->assertJsonCount(1, 'data');
        $response2->assertJsonPath('data.0.id', $contract2->id);
    }

    public function test_input_validation_invalid_role()
    {
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);

        $response = $this->actingAs($client, 'api')->postJson('/api/contracts', [
            'partner_id' => $creator->id,
            'my_role' => 'admin', // invalid
            'title' => 'Test',
            'agreed_price' => 100,
        ]);
        $response->assertStatus(422)->assertJsonValidationErrors(['my_role']);
    }

    public function test_input_validation_missing_partner()
    {
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        
        $response = $this->actingAs($client, 'api')->postJson('/api/contracts', [
            'my_role' => 'client',
            'title' => 'Test',
            'agreed_price' => 100,
        ]);
        $response->assertStatus(422)->assertJsonValidationErrors(['partner_id']);
    }

    public function test_input_validation_nonexistent_partner()
    {
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        
        $response = $this->actingAs($client, 'api')->postJson('/api/contracts', [
            'partner_id' => Str::uuid()->toString(),
            'my_role' => 'client',
            'title' => 'Test',
            'agreed_price' => 100,
        ]);
        $response->assertStatus(422)->assertJsonValidationErrors(['partner_id']);
    }

    public function test_input_validation_invalid_price()
    {
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);

        $response = $this->actingAs($client, 'api')->postJson('/api/contracts', [
            'partner_id' => $creator->id,
            'my_role' => 'client',
            'title' => 'Test',
            'agreed_price' => -50,
        ]);
        $response->assertStatus(422)->assertJsonValidationErrors(['agreed_price']);
    }

    public function test_input_validation_invalid_deadline()
    {
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);

        $response = $this->actingAs($client, 'api')->postJson('/api/contracts', [
            'partner_id' => $creator->id,
            'my_role' => 'client',
            'title' => 'Test',
            'agreed_price' => 50,
            'deadline' => 'invalid-date',
        ]);
        $response->assertStatus(422)->assertJsonValidationErrors(['deadline']);
    }

    public function test_input_validation_unauthorized_creator()
    {
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $partner = User::factory()->create(['role' => \App\Enums\RoleType::User]); // not a creator

        $response = $this->actingAs($client, 'api')->postJson('/api/contracts', [
            'partner_id' => $partner->id,
            'my_role' => 'client',
            'title' => 'Test',
            'agreed_price' => 100,
            'scheduled_start_date' => date('Y-m-d'),
            'scheduled_end_date' => date('Y-m-d'),
        ]);
        $response->assertStatus(400)->assertJsonPath('message', 'Partner bukan kreator terdaftar.');
    }

    public function test_ownership_integrity()
    {
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $attacker = User::factory()->create(['role' => \App\Enums\RoleType::User]);

        // Attacker tries to create a contract for Client and Creator, bypassing themselves
        // Since my_role is required, the controller always uses $request->user()->id for one of the sides.
        // If attacker says my_role = client, then client_id = attacker.id, creator_id = partner_id.
        // It's impossible to set client_id = $client->id and creator_id = $creator->id.
        $response = $this->actingAs($attacker, 'api')->postJson('/api/contracts', [
            'partner_id' => $creator->id,
            'my_role' => 'client',
            'title' => 'Sneaky',
            'agreed_price' => 100,
            'scheduled_start_date' => date('Y-m-d'),
            'scheduled_end_date' => date('Y-m-d'),
        ]);
        
        $response->assertStatus(201);
        $response->assertJsonPath('data.client_id', $attacker->id);
        $response->assertJsonPath('data.creator_id', $creator->id);
    }

    public function test_financial_immutability()
    {
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User, 'balance' => 50000]);
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator, 'balance' => 10000]);

        $response = $this->actingAs($client, 'api')->postJson('/api/contracts', [
            'partner_id' => $creator->id,
            'my_role' => 'client',
            'title' => 'Finance Test',
            'agreed_price' => 10000,
            'scheduled_start_date' => date('Y-m-d'),
            'scheduled_end_date' => date('Y-m-d'),
            'escrow_amount' => 10000, // malicious attempt
            'contract_status' => 'escrow_paid', // malicious attempt
            'work_status' => 'completed', // malicious attempt
        ]);

        $response->assertStatus(201)
                 ->assertJsonPath('data.escrow_amount', '0.00')
                 ->assertJsonPath('data.contract_status', 'draft')
                 ->assertJsonPath('data.work_status', 'scheduled');

        // Verify balance hasn't changed
        $this->assertEquals(50000, $client->fresh()->balance);
        $this->assertEquals(10000, $creator->fresh()->balance);
    }
}
