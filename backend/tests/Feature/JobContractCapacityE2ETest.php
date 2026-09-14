<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\JobContract;
use App\Models\CreatorCapacitySchedule;
use App\Enums\RoleType;
use App\Enums\ContractStatus;
use App\Enums\WorkStatus;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class JobContractCapacityE2ETest extends TestCase
{
    use RefreshDatabase;

    private User $creatorA;
    private User $creatorB;
    private User $clientA;
    private User $clientB;

    protected function setUp(): void
    {
        parent::setUp();

        $this->creatorA = User::factory()->create([
            'role' => RoleType::Creator,
            'max_work_capacity' => 3,
        ]);

        $this->creatorB = User::factory()->create([
            'role' => RoleType::Creator,
            'max_work_capacity' => 2,
        ]);

        $this->clientA = User::factory()->create([
            'role' => RoleType::User,
        ]);

        $this->clientB = User::factory()->create([
            'role' => RoleType::User,
        ]);
    }

    /**
     * 1. Baseline: Zero active contracts -> used_capacity = 0, remaining = max, Available
     */
    public function test_creator_with_no_active_contracts_has_full_capacity(): void
    {
        $response = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorA->id}/availability");

        $response->assertStatus(200)
            ->assertJsonPath('data.max_work_capacity', 3)
            ->assertJsonPath('data.active_work_count', 0)
            ->assertJsonPath('data.remaining_capacity', 3)
            ->assertJsonPath('data.availability_status', 'Available');
    }

    /**
     * 2-7. Full Lifecycle Progression & Capacity Impact
     * Verifies that capacity consumption dynamically follows the exact contract lifecycle:
     * proposed+pending (0) -> approved+scheduled (1) -> active+in_progress (1)
     * -> active+review (1) -> active+revision (1) -> completed+completed (0)
     */
    public function test_capacity_dynamically_tracks_contract_lifecycle_stages(): void
    {
        $today = Carbon::now()->format('Y-m-d');
        $end = Carbon::now()->addDays(5)->format('Y-m-d');

        // Stage A: Proposed + Pending (Must NOT consume capacity)
        $contract = JobContract::create([
            'client_id' => $this->clientA->id,
            'creator_id' => $this->creatorA->id,
            'title' => 'Lifecycle Job',
            'agreed_price' => 1500000.00,
            'escrow_amount' => 0.00,
            'contract_status' => ContractStatus::Proposed,
            'work_status' => WorkStatus::Pending,
            'scheduled_start_date' => $today,
            'scheduled_end_date' => $end,
            'creator_approved' => true,
            'client_approved' => false,
        ]);

        $resProposed = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorA->id}/availability");
        $resProposed->assertStatus(200)
            ->assertJsonPath('data.active_work_count', 0)
            ->assertJsonPath('data.remaining_capacity', 3);

        // Stage B: Approved + Scheduled (Must consume capacity - 1 slot)
        $contract->update([
            'contract_status' => ContractStatus::Approved,
            'work_status' => WorkStatus::Scheduled,
            'client_approved' => true,
        ]);

        $resApproved = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorA->id}/availability");
        $resApproved->assertStatus(200)
            ->assertJsonPath('data.active_work_count', 1)
            ->assertJsonPath('data.remaining_capacity', 2);

        // Stage C: Active + InProgress (Must consume capacity)
        $contract->update([
            'contract_status' => ContractStatus::Active,
            'work_status' => WorkStatus::InProgress,
        ]);

        $resInProgress = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorA->id}/availability");
        $resInProgress->assertStatus(200)
            ->assertJsonPath('data.active_work_count', 1)
            ->assertJsonPath('data.remaining_capacity', 2);

        // Stage D: Active + Review (Must consume capacity)
        $contract->update([
            'work_status' => WorkStatus::Review,
        ]);

        $resReview = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorA->id}/availability");
        $resReview->assertStatus(200)
            ->assertJsonPath('data.active_work_count', 1)
            ->assertJsonPath('data.remaining_capacity', 2);

        // Stage E: Active + Revision (Must consume capacity)
        $contract->update([
            'work_status' => WorkStatus::Revision,
        ]);

        $resRevision = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorA->id}/availability");
        $resRevision->assertStatus(200)
            ->assertJsonPath('data.active_work_count', 1)
            ->assertJsonPath('data.remaining_capacity', 2);

        // Stage F: Completed + Completed (Must RESTORE capacity back to 0 active / 3 remaining)
        $contract->update([
            'contract_status' => ContractStatus::Completed,
            'work_status' => WorkStatus::Completed,
        ]);

        $resCompleted = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorA->id}/availability");
        $resCompleted->assertStatus(200)
            ->assertJsonPath('data.active_work_count', 0)
            ->assertJsonPath('data.remaining_capacity', 3)
            ->assertJsonPath('data.availability_status', 'Available');
    }

    /**
     * 8. Date Range Boundary Tests:
     * Validates before, start_date, middle_date, end_date, and after range without off-by-one errors.
     */
    public function test_date_range_boundaries_precisely_isolate_capacity_consumption(): void
    {
        $startDate = '2026-10-10';
        $endDate = '2026-10-15';

        JobContract::create([
            'client_id' => $this->clientA->id,
            'creator_id' => $this->creatorA->id,
            'title' => 'Boundary Job',
            'agreed_price' => 1000000.00,
            'escrow_amount' => 0.00,
            'contract_status' => ContractStatus::Active,
            'work_status' => WorkStatus::InProgress,
            'scheduled_start_date' => $startDate,
            'scheduled_end_date' => $endDate,
            'client_approved' => true,
            'creator_approved' => true,
        ]);

        // Before range (2026-10-09) -> Unaffected
        $resBefore = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorA->id}/availability?date=2026-10-09");
        $resBefore->assertStatus(200)
            ->assertJsonPath('data.used_capacity', 0)
            ->assertJsonPath('data.remaining_capacity', 3);

        // Exactly on start date (2026-10-10) -> Consumes capacity
        $resStart = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorA->id}/availability?date=2026-10-10");
        $resStart->assertStatus(200)
            ->assertJsonPath('data.used_capacity', 1)
            ->assertJsonPath('data.remaining_capacity', 2);

        // In middle of range (2026-10-12) -> Consumes capacity
        $resMiddle = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorA->id}/availability?date=2026-10-12");
        $resMiddle->assertStatus(200)
            ->assertJsonPath('data.used_capacity', 1)
            ->assertJsonPath('data.remaining_capacity', 2);

        // Exactly on end date (2026-10-15) -> Consumes capacity
        $resEnd = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorA->id}/availability?date=2026-10-15");
        $resEnd->assertStatus(200)
            ->assertJsonPath('data.used_capacity', 1)
            ->assertJsonPath('data.remaining_capacity', 2);

        // After range (2026-10-16) -> Unaffected
        $resAfter = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorA->id}/availability?date=2026-10-16");
        $resAfter->assertStatus(200)
            ->assertJsonPath('data.used_capacity', 0)
            ->assertJsonPath('data.remaining_capacity', 3);
    }

    /**
     * 9. Schedule Unavailable Day (Off-Duty):
     * Tests that a specific unavailable date returns is_working_day = false and availability_status = Unavailable,
     * and in range queries reports working_days and unavailable_days accurately without conflicts.
     */
    public function test_schedule_unavailable_day_marks_date_off_duty(): void
    {
        $offDate = '2026-10-20';

        CreatorCapacitySchedule::create([
            'creator_id' => $this->creatorA->id,
            'date' => $offDate,
            'is_unavailable' => true,
            'notes' => 'Hari Libur Terjadwal',
        ]);

        // Specific date query on off-duty day
        $resDate = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorA->id}/availability?date={$offDate}");

        $resDate->assertStatus(200)
            ->assertJsonPath('data.is_working_day', false)
            ->assertJsonPath('data.effective_capacity', 0)
            ->assertJsonPath('data.availability_status', 'Unavailable')
            ->assertJsonPath('data.notes', 'Hari Libur Terjadwal');

        // Range query spanning 3 days (2026-10-19 to 2026-10-21)
        $resRange = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorA->id}/availability?start_date=2026-10-19&end_date=2026-10-21");

        $resRange->assertStatus(200)
            ->assertJsonPath('data.available', true)
            ->assertJsonPath('data.working_days', 2)
            ->assertJsonPath('data.unavailable_days', 1)
            ->assertJsonPath('data.conflicts', null);
    }

    /**
     * 10. Schedule Custom Capacity Override:
     * Overriding default capacity (3) to 1 on a specific date.
     */
    public function test_schedule_capacity_override_on_specific_date(): void
    {
        $specialDate = '2026-10-25';

        CreatorCapacitySchedule::create([
            'creator_id' => $this->creatorA->id,
            'date' => $specialDate,
            'max_capacity' => 1,
            'is_unavailable' => false,
            'notes' => 'Kapasitas Terbatas',
        ]);

        $res = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorA->id}/availability?date={$specialDate}");

        $res->assertStatus(200)
            ->assertJsonPath('data.is_working_day', true)
            ->assertJsonPath('data.effective_capacity', 1)
            ->assertJsonPath('data.remaining_capacity', 1)
            ->assertJsonPath('data.availability_status', 'Available');
    }

    /**
     * 11. Read Availability when Full:
     * Creator A has max 2 jobs on 2026-10-28. Both slots are filled.
     * GET availability returns remaining_capacity = 0 and availability_status = Full.
     */
    public function test_read_availability_when_capacity_is_exhausted(): void
    {
        $fullDate = '2026-10-28';

        JobContract::create([
            'client_id' => $this->clientA->id,
            'creator_id' => $this->creatorB->id, // max_work_capacity = 2
            'title' => 'Job 1',
            'agreed_price' => 500000.00,
            'contract_status' => ContractStatus::Active,
            'work_status' => WorkStatus::InProgress,
            'scheduled_start_date' => $fullDate,
            'scheduled_end_date' => $fullDate,
            'client_approved' => true,
            'creator_approved' => true,
        ]);

        JobContract::create([
            'client_id' => $this->clientB->id,
            'creator_id' => $this->creatorB->id,
            'title' => 'Job 2',
            'agreed_price' => 500000.00,
            'contract_status' => ContractStatus::Approved,
            'work_status' => WorkStatus::Scheduled,
            'scheduled_start_date' => $fullDate,
            'scheduled_end_date' => $fullDate,
            'client_approved' => true,
            'creator_approved' => true,
        ]);

        // Specific date query
        $resDate = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorB->id}/availability?date={$fullDate}");

        $resDate->assertStatus(200)
            ->assertJsonPath('data.used_capacity', 2)
            ->assertJsonPath('data.remaining_capacity', 0)
            ->assertJsonPath('data.availability_status', 'Full');

        // Range query including the full date
        $resRange = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorB->id}/availability?start_date={$fullDate}&end_date={$fullDate}");

        $resRange->assertStatus(200)
            ->assertJsonPath('data.available', false)
            ->assertJsonPath('data.conflicts.0.date', $fullDate)
            ->assertJsonPath('data.conflicts.0.reason', 'CAPACITY_FULL');
    }

    /**
     * 12. Mutation/Transition Guard (Write):
     * Transitioning a proposed/draft contract to approved when capacity is full
     * must be rejected with 409 Conflict and CREATOR_CAPACITY_FULL error code.
     */
    public function test_contract_approval_is_blocked_with_409_when_capacity_is_full(): void
    {
        $targetDate = '2026-11-05';

        // Creator B has capacity = 2. Fill both slots.
        for ($i = 1; $i <= 2; $i++) {
            JobContract::create([
                'client_id' => $this->clientA->id,
                'creator_id' => $this->creatorB->id,
                'title' => "Filled Job {$i}",
                'agreed_price' => 500000.00,
                'contract_status' => ContractStatus::Active,
                'work_status' => WorkStatus::InProgress,
                'scheduled_start_date' => $targetDate,
                'scheduled_end_date' => $targetDate,
                'client_approved' => true,
                'creator_approved' => true,
            ]);
        }

        // Draft contract attempting to take slot 3 on targetDate
        $pendingContract = JobContract::create([
            'client_id' => $this->clientA->id,
            'creator_id' => $this->creatorB->id,
            'title' => 'Excess Job',
            'agreed_price' => 500000.00,
            'contract_status' => ContractStatus::Draft,
            'work_status' => WorkStatus::Scheduled,
            'scheduled_start_date' => $targetDate,
            'scheduled_end_date' => $targetDate,
            'client_approved' => true,
            'creator_approved' => false,
        ]);

        // Attempting to transition to approve by creator
        $response = $this->actingAs($this->creatorB, 'api')
            ->postJson("/api/contracts/{$pendingContract->id}/transitions", [
                'transition' => 'approve',
            ]);

        $response->assertStatus(409)
            ->assertJsonPath('status', false)
            ->assertJsonPath('error', 'CREATOR_CAPACITY_FULL');
    }

    /**
     * 13. Creator Isolation:
     * Active contracts on Creator A must not affect Creator B's capacity.
     */
    public function test_creator_capacity_is_strictly_isolated_between_creators(): void
    {
        $date = '2026-11-10';

        // Fill Creator A completely (3 contracts)
        for ($i = 1; $i <= 3; $i++) {
            JobContract::create([
                'client_id' => $this->clientA->id,
                'creator_id' => $this->creatorA->id,
                'title' => "Creator A Job {$i}",
                'agreed_price' => 500000.00,
                'contract_status' => ContractStatus::Active,
                'work_status' => WorkStatus::InProgress,
                'scheduled_start_date' => $date,
                'scheduled_end_date' => $date,
                'client_approved' => true,
                'creator_approved' => true,
            ]);
        }

        // Creator A should be Full
        $resA = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorA->id}/availability?date={$date}");
        $resA->assertStatus(200)
            ->assertJsonPath('data.used_capacity', 3)
            ->assertJsonPath('data.remaining_capacity', 0)
            ->assertJsonPath('data.availability_status', 'Full');

        // Creator B must remain completely Available with 0 used capacity
        $resB = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorB->id}/availability?date={$date}");
        $resB->assertStatus(200)
            ->assertJsonPath('data.used_capacity', 0)
            ->assertJsonPath('data.remaining_capacity', 2)
            ->assertJsonPath('data.availability_status', 'Available');
    }

    /**
     * 14. Client Data Isolation:
     * Client A should never see Client B's contracts on GET /api/contracts.
     */
    public function test_client_contract_list_strictly_isolates_client_data(): void
    {
        $contractA = JobContract::create([
            'client_id' => $this->clientA->id,
            'creator_id' => $this->creatorA->id,
            'title' => 'Secret Project Client A',
            'agreed_price' => 2000000.00,
            'contract_status' => ContractStatus::Active,
            'work_status' => WorkStatus::InProgress,
            'scheduled_start_date' => '2026-11-15',
            'scheduled_end_date' => '2026-11-20',
        ]);

        $contractB = JobContract::create([
            'client_id' => $this->clientB->id,
            'creator_id' => $this->creatorA->id,
            'title' => 'Secret Project Client B',
            'agreed_price' => 3000000.00,
            'contract_status' => ContractStatus::Active,
            'work_status' => WorkStatus::InProgress,
            'scheduled_start_date' => '2026-11-15',
            'scheduled_end_date' => '2026-11-20',
        ]);

        // Client A gets contracts
        $resClientA = $this->actingAs($this->clientA, 'api')
            ->getJson('/api/contracts');

        $resClientA->assertStatus(200);
        $clientAContracts = collect($resClientA->json('data'));
        $this->assertTrue($clientAContracts->contains('id', $contractA->id));
        $this->assertFalse($clientAContracts->contains('id', $contractB->id));

        // Client B gets contracts
        $resClientB = $this->actingAs($this->clientB, 'api')
            ->getJson('/api/contracts');

        $resClientB->assertStatus(200);
        $clientBContracts = collect($resClientB->json('data'));
        $this->assertTrue($clientBContracts->contains('id', $contractB->id));
        $this->assertFalse($clientBContracts->contains('id', $contractA->id));
    }

    /**
     * 15. Disjoint Contract and Schedule (User suggestion #9):
     * Contract active on [T+1, T+3]. Schedule has unavailable off-duty on T+6.
     * Verifies that on T+1 capacity is consumed by contract,
     * while on T+6 creator is unavailable strictly due to calendar schedule (used_capacity = 0).
     */
    public function test_contract_availability_and_calendar_schedule_do_not_conflate(): void
    {
        $contractStart = '2026-12-01';
        $contractEnd = '2026-12-03';
        $offDutyDate = '2026-12-06';

        // Contract on [Dec 1, Dec 3]
        JobContract::create([
            'client_id' => $this->clientA->id,
            'creator_id' => $this->creatorA->id,
            'title' => 'Early December Job',
            'agreed_price' => 1000000.00,
            'contract_status' => ContractStatus::Active,
            'work_status' => WorkStatus::InProgress,
            'scheduled_start_date' => $contractStart,
            'scheduled_end_date' => $contractEnd,
        ]);

        // Schedule off-duty on Dec 6
        CreatorCapacitySchedule::create([
            'creator_id' => $this->creatorA->id,
            'date' => $offDutyDate,
            'is_unavailable' => true,
            'notes' => 'Off Duty Weekend',
        ]);

        // Check on Contract Day (Dec 2): Working day, used_capacity = 1, remaining = 2
        $resContractDay = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorA->id}/availability?date=2026-12-02");
        $resContractDay->assertStatus(200)
            ->assertJsonPath('data.is_working_day', true)
            ->assertJsonPath('data.used_capacity', 1)
            ->assertJsonPath('data.remaining_capacity', 2)
            ->assertJsonPath('data.availability_status', 'Available');

        // Check on Off-Duty Day (Dec 6): Not working day due to schedule, but used_capacity = 0
        $resOffDutyDay = $this->actingAs($this->clientA, 'api')
            ->getJson("/api/creators/{$this->creatorA->id}/availability?date={$offDutyDate}");
        $resOffDutyDay->assertStatus(200)
            ->assertJsonPath('data.is_working_day', false)
            ->assertJsonPath('data.used_capacity', 0) // No contract running!
            ->assertJsonPath('data.effective_capacity', 0)
            ->assertJsonPath('data.availability_status', 'Unavailable');
    }
}
