<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\JobContract;
use App\Models\JobStatusHistory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use Illuminate\Support\Str;

class JobContractStateMachineTest extends TestCase
{
    use RefreshDatabase;

    public function test_valid_client_approval_transition()
    {
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $contract = JobContract::create([
            'client_id' => $client->id,
            'creator_id' => $creator->id,
            'title' => 'Test Contract',
            'contract_status' => 'draft',
            'work_status' => 'scheduled'
        ]);

        $response = $this->actingAs($client, 'api')->postJson("/api/contracts/{$contract->id}/transitions", [
            'transition' => 'approve'
        ]);

        $response->assertStatus(200);
        
        $contract->refresh();
        $this->assertTrue($contract->client_approved);
        $this->assertFalse($contract->creator_approved);
        $this->assertEquals('draft', $contract->contract_status->value); // still draft because creator hasn't approved
        
        // Assert history created
        $this->assertDatabaseHas('job_status_histories', [
            'job_contract_id' => $contract->id,
            'actor_id' => $client->id,
            'transition' => 'approve'
        ]);
    }

    public function test_contract_becomes_approved_after_both_parties_approve()
    {
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $contract = JobContract::create([
            'client_id' => $client->id,
            'creator_id' => $creator->id,
            'title' => 'Test Contract',
            'contract_status' => 'draft',
            'work_status' => 'scheduled',
            'client_approved' => true // client already approved
        ]);

        $response = $this->actingAs($creator, 'api')->postJson("/api/contracts/{$contract->id}/transitions", [
            'transition' => 'approve'
        ]);

        $response->assertStatus(200);
        
        $contract->refresh();
        $this->assertTrue($contract->creator_approved);
        $this->assertEquals('approved', $contract->contract_status->value);
    }

    public function test_escrow_payment_transition_is_blocked_in_phase_3()
    {
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $contract = JobContract::create([
            'client_id' => $client->id,
            'creator_id' => $creator->id,
            'title' => 'Test',
            'contract_status' => 'approved',
            'work_status' => 'scheduled',
        ]);

        $response = $this->actingAs($client, 'api')->postJson("/api/contracts/{$contract->id}/transitions", [
            'transition' => 'pay_escrow'
        ]);

        $response->assertStatus(400);
        $this->assertStringContainsString('disabled', $response->json('message'));
        
        // Ensure no state change
        $this->assertEquals('approved', $contract->fresh()->contract_status->value);
        $this->assertEquals(0, JobStatusHistory::count());
    }

    public function test_submit_work_transition()
    {
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $contract = JobContract::create([
            'client_id' => $client->id,
            'creator_id' => $creator->id,
            'title' => 'Test',
            'contract_status' => 'approved',
            'work_status' => 'in_progress', // forcefully reached in_progress for this test
        ]);

        $response = $this->actingAs($creator, 'api')->postJson("/api/contracts/{$contract->id}/transitions", [
            'transition' => 'submit_work'
        ]);

        $response->assertStatus(200);
        
        $contract->refresh();
        $this->assertEquals('review', $contract->work_status->value);
        $this->assertNotNull($contract->submitted_at);
        
        $this->assertDatabaseHas('job_status_histories', [
            'transition' => 'submit_work',
            'from_work_status' => 'in_progress',
            'to_work_status' => 'review',
        ]);
    }

    public function test_client_cannot_perform_creator_only_transition()
    {
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $contract = JobContract::create([
            'client_id' => $client->id,
            'creator_id' => $creator->id,
            'title' => 'Test',
            'contract_status' => 'approved',
            'work_status' => 'in_progress',
        ]);

        $response = $this->actingAs($client, 'api')->postJson("/api/contracts/{$contract->id}/transitions", [
            'transition' => 'submit_work'
        ]);

        $response->assertStatus(403);
    }

    public function test_completed_contract_cannot_return_to_draft()
    {
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $contract = JobContract::create([
            'client_id' => $client->id,
            'creator_id' => $creator->id,
            'title' => 'Test',
            'contract_status' => 'completed',
            'work_status' => 'completed',
        ]);

        // Attempting to approve a completed contract to see if it goes back to draft
        $response = $this->actingAs($client, 'api')->postJson("/api/contracts/{$contract->id}/transitions", [
            'transition' => 'approve'
        ]);

        $response->assertStatus(400); // already past draft
    }
    
    public function test_cancellation_logic()
    {
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $contract = JobContract::create([
            'client_id' => $client->id,
            'creator_id' => $creator->id,
            'title' => 'Test',
            'contract_status' => 'approved',
            'work_status' => 'in_progress',
        ]);

        // 1. Client requests cancellation
        $response = $this->actingAs($client, 'api')->postJson("/api/contracts/{$contract->id}/transitions", [
            'transition' => 'request_cancellation',
            'metadata' => ['reason' => 'Changed my mind']
        ]);
        $response->assertStatus(200);
        $contract->refresh();
        $this->assertEquals('cancel_requested', $contract->contract_status->value);
        
        // 2. Client cannot confirm their own request
        $response = $this->actingAs($client, 'api')->postJson("/api/contracts/{$contract->id}/transitions", [
            'transition' => 'confirm_cancellation'
        ]);
        $response->assertStatus(403); // cannot confirm own request
        
        // 3. Creator confirms cancellation
        $response = $this->actingAs($creator, 'api')->postJson("/api/contracts/{$contract->id}/transitions", [
            'transition' => 'confirm_cancellation'
        ]);
        $response->assertStatus(200);
        
        $contract->refresh();
        $this->assertEquals('cancelled', $contract->contract_status->value);
        $this->assertEquals('cancelled', $contract->work_status->value);
        $this->assertNotNull($contract->cancelled_at);
        
        $this->assertEquals(2, JobStatusHistory::where('job_contract_id', $contract->id)->count());
    }

    public function test_approve_work_updates_work_status_but_not_contract_status_per_phase3_rules()
    {
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);
        $contract = JobContract::create([
            'client_id' => $client->id,
            'creator_id' => $creator->id,
            'title' => 'Test',
            'contract_status' => 'escrow_paid', // simulating it was paid
            'work_status' => 'review',
        ]);

        $response = $this->actingAs($client, 'api')->postJson("/api/contracts/{$contract->id}/transitions", [
            'transition' => 'approve_work'
        ]);

        $response->assertStatus(200);
        
        $contract->refresh();
        $this->assertEquals('completed', $contract->work_status->value);
        $this->assertEquals('escrow_paid', $contract->contract_status->value); // Stays escrow_paid, pending Phase 4 escrow logic
        $this->assertNotNull($contract->completed_at);
    }
}
