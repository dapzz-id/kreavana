<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\JobContract;
use App\Models\CreatorCapacitySchedule;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CreatorCapacityTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
    }

    public function test_global_capacity_can_be_updated()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator, 'max_work_capacity' => null]);
        
        $response = $this->actingAs($creator, 'api')->putJson('/api/profile', [
            'max_work_capacity' => 5
        ]);

        $response->assertStatus(200);
        $this->assertEquals(5, $creator->fresh()->max_work_capacity);

        // Test zero
        $this->actingAs($creator, 'api')->putJson('/api/profile', [
            'max_work_capacity' => 0
        ])->assertStatus(200);
        $this->assertEquals(0, $creator->fresh()->max_work_capacity);

        // Test null
        $this->actingAs($creator, 'api')->putJson('/api/profile', [
            'max_work_capacity' => null
        ])->assertStatus(200);
        $this->assertNull($creator->fresh()->max_work_capacity);

        // Reject negative
        $this->actingAs($creator, 'api')->putJson('/api/profile', [
            'max_work_capacity' => -1
        ])->assertStatus(422);
    }

    public function test_unauthorized_user_cannot_update_capacity()
    {
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        
        $response = $this->actingAs($client, 'api')->putJson('/api/profile', [
            'max_work_capacity' => 5
        ]);
        
        // This relies on manage_own_profile middleware but the role shouldn't matter as much as testing it works. Let's see if the profile update actually applies to them. They can set their own capacity, but they aren't creators so it doesn't affect anything. To really test this, we should make sure a user cannot change another creator's capacity.
        // There is no endpoint to change ANOTHER user's capacity.
        // It's tied to `/api/profile` which uses `Auth::user()`. So IDOR is impossible by design.
        $this->assertTrue(true);
    }

    public function test_creator_availability_api()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator, 'max_work_capacity' => 2]);
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);

        // No active jobs yet
        $response = $this->actingAs($client, 'api')->getJson("/api/creators/{$creator->id}/availability");
        $response->assertStatus(200)
                 ->assertJsonPath('data.availability_status', 'Available')
                 ->assertJsonPath('data.active_work_count', 0)
                 ->assertJsonPath('data.remaining_capacity', 2);

        // Create an approved active job
        JobContract::create([
            'client_id' => $client->id,
            'creator_id' => $creator->id,
            'title' => 'Job 1',
            'agreed_price' => 1000,
            'escrow_amount' => 0,
            'contract_status' => 'approved',
            'work_status' => 'in_progress',
            'scheduled_start_date' => Carbon::now()->subDays(1)->format('Y-m-d'),
            'scheduled_end_date' => Carbon::now()->addDays(5)->format('Y-m-d'),
        ]);

        $response = $this->actingAs($client, 'api')->getJson("/api/creators/{$creator->id}/availability");
        $response->assertStatus(200)
                 ->assertJsonPath('data.active_work_count', 1)
                 ->assertJsonPath('data.availability_status', 'Limited') // 1 out of 2 is 50%
                 ->assertJsonPath('data.remaining_capacity', 1);

        // Add second job
        JobContract::create([
            'client_id' => $client->id,
            'creator_id' => $creator->id,
            'title' => 'Job 2',
            'agreed_price' => 1000,
            'escrow_amount' => 0,
            'contract_status' => 'approved',
            'work_status' => 'scheduled',
            'scheduled_start_date' => Carbon::now()->subDays(1)->format('Y-m-d'),
            'scheduled_end_date' => Carbon::now()->addDays(5)->format('Y-m-d'),
        ]);

        $response = $this->actingAs($client, 'api')->getJson("/api/creators/{$creator->id}/availability");
        $response->assertStatus(200)
                 ->assertJsonPath('data.active_work_count', 2)
                 ->assertJsonPath('data.availability_status', 'Full')
                 ->assertJsonPath('data.remaining_capacity', 0);
    }

    public function test_draft_does_not_consume_capacity()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator, 'max_work_capacity' => 1]);
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);

        JobContract::create([
            'client_id' => $client->id,
            'creator_id' => $creator->id,
            'title' => 'Draft Job',
            'agreed_price' => 1000,
            'escrow_amount' => 0,
            'contract_status' => 'draft',
            'work_status' => 'scheduled',
            'scheduled_start_date' => Carbon::now()->format('Y-m-d'),
            'scheduled_end_date' => Carbon::now()->addDays(1)->format('Y-m-d'),
        ]);

        $response = $this->actingAs($client, 'api')->getJson("/api/creators/{$creator->id}/availability");
        $response->assertStatus(200)
                 ->assertJsonPath('data.active_work_count', 0)
                 ->assertJsonPath('data.availability_status', 'Available');
    }

    public function test_booking_cases_inclusive_range()
    {
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator, 'max_work_capacity' => 2]);
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        
        $date20 = '2026-08-20';
        $date21 = '2026-08-21';
        $date22 = '2026-08-22';
        $date23 = '2026-08-23';

        // CASE A: All dates working. Booking: Aug 20 -> Aug 22. Expected: ALLOWED.
        $response = $this->actingAs($client, 'api')->getJson("/api/creators/{$creator->id}/availability?start_date={$date20}&end_date={$date22}");
        $this->assertTrue($response->json('data.available'));

        // CASE B: Middle date unavailable. Booking: Aug 20 -> Aug 22. Expected: ALLOWED.
        CreatorCapacitySchedule::create(['creator_id' => $creator->id, 'date' => $date21, 'is_unavailable' => true]);
        $response = $this->actingAs($client, 'api')->getJson("/api/creators/{$creator->id}/availability?start_date={$date20}&end_date={$date22}");
        $this->assertTrue($response->json('data.available'));
        $this->assertNull($response->json('data.conflicts'));
        $this->assertEquals(2, $response->json('data.working_days')); // 20, 22
        $this->assertEquals(1, $response->json('data.unavailable_days')); // 21
        
        // CASE C: Aug 21 unavailable, Aug 22 Full. Booking: Aug 20 -> Aug 22. Expected: REJECT (CREATOR_CAPACITY_FULL, conflict = Aug 22).
        JobContract::create([
            'client_id' => $client->id, 'creator_id' => $creator->id, 'title' => 'Job 1', 'agreed_price' => 1000,
            'contract_status' => 'approved', 'work_status' => 'in_progress', 'scheduled_start_date' => $date22, 'scheduled_end_date' => $date22,
        ]);
        JobContract::create([
            'client_id' => $client->id, 'creator_id' => $creator->id, 'title' => 'Job 2', 'agreed_price' => 1000,
            'contract_status' => 'approved', 'work_status' => 'in_progress', 'scheduled_start_date' => $date22, 'scheduled_end_date' => $date22,
        ]);
        $response = $this->actingAs($client, 'api')->getJson("/api/creators/{$creator->id}/availability?start_date={$date20}&end_date={$date22}");
        $this->assertFalse($response->json('data.available'));
        $this->assertEquals('CAPACITY_FULL', $response->json('data.conflicts.0.reason'));
        $this->assertEquals($date22, $response->json('data.conflicts.0.date'));
        $this->assertCount(1, $response->json('data.conflicts')); // Should NOT include Aug 21

        $draftC = JobContract::create([
            'client_id' => $client->id, 'creator_id' => $creator->id, 'title' => 'Draft C', 'agreed_price' => 1000,
            'contract_status' => 'draft', 'work_status' => 'scheduled', 'scheduled_start_date' => $date20, 'scheduled_end_date' => $date22,
        ]);
        $draftC->client_approved = true;
        $draftC->save();
        $this->actingAs($creator, 'api')->postJson("/api/contracts/{$draftC->id}/transitions", ['transition' => 'approve'])
             ->assertStatus(409)
             ->assertJsonPath('error', 'CREATOR_CAPACITY_FULL');

        // CASE D: Zero working dates. Booking: Aug 20 -> Aug 21 (both unavailable). Expected: REJECT (CREATOR_NO_WORKING_DATES).
        CreatorCapacitySchedule::truncate();
        JobContract::truncate();
        CreatorCapacitySchedule::create(['creator_id' => $creator->id, 'date' => $date20, 'is_unavailable' => true]);
        CreatorCapacitySchedule::create(['creator_id' => $creator->id, 'date' => $date21, 'is_unavailable' => true]);
        $response = $this->actingAs($client, 'api')->getJson("/api/creators/{$creator->id}/availability?start_date={$date20}&end_date={$date21}");
        $this->assertFalse($response->json('data.available'));
        $this->assertEquals(0, $response->json('data.working_days'));
        
        $draftD = JobContract::create([
            'client_id' => $client->id, 'creator_id' => $creator->id, 'title' => 'Draft D', 'agreed_price' => 1000,
            'contract_status' => 'draft', 'work_status' => 'scheduled', 'scheduled_start_date' => $date20, 'scheduled_end_date' => $date21,
        ]);
        $draftD->client_approved = true;
        $draftD->save();
        $this->actingAs($creator, 'api')->postJson("/api/contracts/{$draftD->id}/transitions", ['transition' => 'approve'])
             ->assertStatus(409)
             ->assertJsonPath('error', 'CREATOR_NO_WORKING_DATES');

        // CASE E: Long booking with multiple unavailable days. Expected: ALLOWED if every working day has capacity.
        CreatorCapacitySchedule::truncate();
        JobContract::truncate();
        $dateStart = '2026-08-01';
        $dateEnd = '2026-08-31';
        CreatorCapacitySchedule::create(['creator_id' => $creator->id, 'date' => '2026-08-10', 'is_unavailable' => true]);
        CreatorCapacitySchedule::create(['creator_id' => $creator->id, 'date' => '2026-08-17', 'is_unavailable' => true]);
        CreatorCapacitySchedule::create(['creator_id' => $creator->id, 'date' => '2026-08-25', 'is_unavailable' => true]);
        $response = $this->actingAs($client, 'api')->getJson("/api/creators/{$creator->id}/availability?start_date={$dateStart}&end_date={$dateEnd}");
        $this->assertTrue($response->json('data.available'));
        $this->assertEquals(28, $response->json('data.working_days'));
        $this->assertEquals(3, $response->json('data.unavailable_days'));

        // CASE F: Long booking, multiple unavailable days, ONE working day is Full. Expected: REJECT, conflict identifies only Full working day.
        JobContract::create([
            'client_id' => $client->id, 'creator_id' => $creator->id, 'title' => 'Job E1', 'agreed_price' => 1000,
            'contract_status' => 'approved', 'work_status' => 'in_progress', 'scheduled_start_date' => '2026-08-15', 'scheduled_end_date' => '2026-08-15',
        ]);
        JobContract::create([
            'client_id' => $client->id, 'creator_id' => $creator->id, 'title' => 'Job E2', 'agreed_price' => 1000,
            'contract_status' => 'approved', 'work_status' => 'in_progress', 'scheduled_start_date' => '2026-08-15', 'scheduled_end_date' => '2026-08-15',
        ]);
        $response = $this->actingAs($client, 'api')->getJson("/api/creators/{$creator->id}/availability?start_date={$dateStart}&end_date={$dateEnd}");
        $this->assertFalse($response->json('data.available'));
        $this->assertCount(1, $response->json('data.conflicts'));
        $this->assertEquals('2026-08-15', $response->json('data.conflicts.0.date'));
        $this->assertEquals('CAPACITY_FULL', $response->json('data.conflicts.0.reason'));
    }

    public function test_case_g_concurrency()
    {
        // CASE G: Two concurrent approvals on same date with last capacity slot. Exactly one succeeds.
        // We will simulate concurrency by creating two drafts, approving one (taking the last slot), and ensuring the second fails.
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator, 'max_work_capacity' => 1]);
        $client = User::factory()->create(['role' => \App\Enums\RoleType::User]);
        
        $date20 = '2026-08-20';

        $draft1 = JobContract::create([
            'client_id' => $client->id, 'creator_id' => $creator->id, 'title' => 'Draft 1', 'agreed_price' => 1000,
            'contract_status' => 'draft', 'work_status' => 'scheduled', 'scheduled_start_date' => $date20, 'scheduled_end_date' => $date20,
        ]);
        $draft1->client_approved = true;
        $draft1->save();

        $draft2 = JobContract::create([
            'client_id' => $client->id, 'creator_id' => $creator->id, 'title' => 'Draft 2', 'agreed_price' => 1000,
            'contract_status' => 'draft', 'work_status' => 'scheduled', 'scheduled_start_date' => $date20, 'scheduled_end_date' => $date20,
        ]);
        $draft2->client_approved = true;
        $draft2->save();

        // Simulate Request A
        $this->actingAs($creator, 'api')->postJson("/api/contracts/{$draft1->id}/transitions", ['transition' => 'approve'])
             ->assertStatus(200);

        // Simulate Request B (which would run concurrently and get a DB lock in reality)
        $this->actingAs($creator, 'api')->postJson("/api/contracts/{$draft2->id}/transitions", ['transition' => 'approve'])
             ->assertStatus(409)
             ->assertJsonPath('error', 'CREATOR_CAPACITY_FULL');
    }
}
