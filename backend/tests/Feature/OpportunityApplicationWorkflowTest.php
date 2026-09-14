<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\User;
use App\Models\Opportunity;
use App\Models\OpportunityApplication;
use App\Enums\RoleType;
use Illuminate\Foundation\Testing\RefreshDatabase;

class OpportunityApplicationWorkflowTest extends TestCase
{
    use RefreshDatabase;

    protected User $owner;
    protected User $creator1;
    protected User $creator2;
    protected User $regularUser;
    protected Opportunity $opportunity;

    protected function setUp(): void
    {
        parent::setUp();

        $this->owner = User::factory()->create(['role' => RoleType::User]);
        $this->creator1 = User::factory()->create([
            'role' => RoleType::Creator,
            'is_creator_approved' => true,
        ]);
        $this->creator2 = User::factory()->create([
            'role' => RoleType::Creator,
            'is_creator_approved' => true,
        ]);
        $this->regularUser = User::factory()->create(['role' => RoleType::User]);

        $this->opportunity = Opportunity::create([
            'title' => 'Wedding Organizer & Dokumentasi',
            'sub_role_slug' => 'wedding_organizer',
            'type' => 'project',
            'location' => 'Bandung',
            'status' => 'open',
            'posted_by' => $this->owner->id,
            'created_at' => now(),
        ]);
    }

    public function test_creator_can_apply_to_opportunity()
    {
        $response = $this->actingAsApi($this->creator1)
            ->postJson("/api/opportunities/{$this->opportunity->id}/applications", [
                'sub_role_slug' => 'wedding_organizer',
                'pitch_message' => 'Kami berpengalaman menangani 50+ event pernikahan tradisional dan modern.',
                'questions_notes' => 'Apakah konsumsi tim vendor disediakan oleh pihak EO?',
                'bid_price' => 15000000,
            ]);

        $response->assertStatus(201)
            ->assertJsonPath('status', true);

        $this->assertDatabaseHas('opportunity_applications', [
            'opportunity_id' => $this->opportunity->id,
            'creator_id' => $this->creator1->id,
            'sub_role_slug' => 'wedding_organizer',
            'status' => 'pending',
        ]);
    }

    public function test_duplicate_application_is_prevented()
    {
        OpportunityApplication::create([
            'opportunity_id' => $this->opportunity->id,
            'creator_id' => $this->creator1->id,
            'sub_role_slug' => 'wedding_organizer',
            'pitch_message' => 'Lamaran pertama saya.',
            'status' => 'pending',
        ]);

        $response = $this->actingAsApi($this->creator1)
            ->postJson("/api/opportunities/{$this->opportunity->id}/applications", [
                'sub_role_slug' => 'wedding_organizer',
                'pitch_message' => 'Lamaran kedua yang duplikat.',
            ]);

        $response->assertStatus(409);
    }

    public function test_non_creator_cannot_apply()
    {
        $response = $this->actingAsApi($this->regularUser)
            ->postJson("/api/opportunities/{$this->opportunity->id}/applications", [
                'sub_role_slug' => 'wedding_organizer',
                'pitch_message' => 'Saya ingin mencoba proyek ini.',
            ]);

        $response->assertStatus(403);
    }

    public function test_owner_cannot_apply_to_own_project()
    {
        // Even if owner is creator role
        $this->owner->role = RoleType::Creator;
        $this->owner->save();

        $response = $this->actingAsApi($this->owner)
            ->postJson("/api/opportunities/{$this->opportunity->id}/applications", [
                'sub_role_slug' => 'wedding_organizer',
                'pitch_message' => 'Saya pemiliknya.',
            ]);

        $response->assertStatus(400);
    }

    public function test_owner_can_view_applications_but_non_owner_cannot()
    {
        OpportunityApplication::create([
            'opportunity_id' => $this->opportunity->id,
            'creator_id' => $this->creator1->id,
            'sub_role_slug' => 'wedding_organizer',
            'pitch_message' => 'Proposal vendor WO.',
            'status' => 'pending',
        ]);

        // Non-owner should be denied
        $resNonOwner = $this->actingAsApi($this->creator2)
            ->getJson("/api/opportunities/{$this->opportunity->id}/applications");
        $resNonOwner->assertStatus(403);

        // Owner can access
        $resOwner = $this->actingAsApi($this->owner)
            ->getJson("/api/opportunities/{$this->opportunity->id}/applications");
        $resOwner->assertStatus(200)
            ->assertJsonPath('status', true);
        $this->assertCount(1, $resOwner->json('data'));
    }

    public function test_owner_can_approve_application()
    {
        $app = OpportunityApplication::create([
            'opportunity_id' => $this->opportunity->id,
            'creator_id' => $this->creator1->id,
            'sub_role_slug' => 'wedding_organizer',
            'pitch_message' => 'Proposal WO.',
            'status' => 'pending',
        ]);

        $response = $this->actingAsApi($this->owner)
            ->postJson("/api/opportunities/applications/{$app->id}/approve");

        $response->assertStatus(200);

        $app->refresh();
        $this->assertEquals('approved', $app->status);
        $this->assertNotNull($app->reviewed_at);
    }

    public function test_owner_can_reject_application_with_reason()
    {
        $app = OpportunityApplication::create([
            'opportunity_id' => $this->opportunity->id,
            'creator_id' => $this->creator1->id,
            'sub_role_slug' => 'wedding_organizer',
            'pitch_message' => 'Proposal WO.',
            'status' => 'pending',
        ]);

        $response = $this->actingAsApi($this->owner)
            ->postJson("/api/opportunities/applications/{$app->id}/reject", [
                'reason' => 'Portofolio belum sesuai dengan tema adat yang kami perlukan.',
            ]);

        $response->assertStatus(200);

        $app->refresh();
        $this->assertEquals('rejected', $app->status);
        $this->assertEquals('Portofolio belum sesuai dengan tema adat yang kami perlukan.', $app->rejection_reason);
    }

    public function test_unauthorized_user_cannot_approve_application()
    {
        $app = OpportunityApplication::create([
            'opportunity_id' => $this->opportunity->id,
            'creator_id' => $this->creator1->id,
            'sub_role_slug' => 'wedding_organizer',
            'pitch_message' => 'Proposal WO.',
            'status' => 'pending',
        ]);

        $response = $this->actingAsApi($this->creator2)
            ->postJson("/api/opportunities/applications/{$app->id}/approve");

        $response->assertStatus(403);
    }

    public function test_owner_cannot_exceed_requirement_capacity()
    {
        // Set capacity requirement: 1 Videographer
        \App\Models\OpportunityRequirement::create([
            'opportunity_id' => $this->opportunity->id,
            'sub_role_slug' => 'videographer',
            'quantity' => 1,
        ]);

        $app1 = OpportunityApplication::create([
            'opportunity_id' => $this->opportunity->id,
            'creator_id' => $this->creator1->id,
            'sub_role_slug' => 'videographer',
            'pitch_message' => 'Videographer A',
            'status' => 'pending',
        ]);

        $app2 = OpportunityApplication::create([
            'opportunity_id' => $this->opportunity->id,
            'creator_id' => $this->creator2->id,
            'sub_role_slug' => 'videographer',
            'pitch_message' => 'Videographer B',
            'status' => 'pending',
        ]);

        // 1. Approve first creator -> succeeds
        $res1 = $this->actingAsApi($this->owner)
            ->postJson("/api/opportunities/applications/{$app1->id}/approve");
        $res1->assertStatus(200);
        $app1->refresh();
        $this->assertEquals('approved', $app1->status);

        // 2. Attempt to approve second creator -> rejected because capacity is full (1/1)
        $res2 = $this->actingAsApi($this->owner)
            ->postJson("/api/opportunities/applications/{$app2->id}/approve");
        $res2->assertStatus(422)
            ->assertJsonPath('message', 'Kapasitas kebutuhan untuk posisi Videographer sudah terpenuhi (1/1).');

        $app2->refresh();
        $this->assertEquals('pending', $app2->status);
    }

    public function test_approved_application_does_not_automatically_activate_job_contract()
    {
        $app = OpportunityApplication::create([
            'opportunity_id' => $this->opportunity->id,
            'creator_id' => $this->creator1->id,
            'sub_role_slug' => 'wedding_organizer',
            'pitch_message' => 'Proposal WO.',
            'status' => 'pending',
        ]);

        $this->actingAsApi($this->owner)
            ->postJson("/api/opportunities/applications/{$app->id}/approve")
            ->assertStatus(200);

        // Invariant check: Application is approved, but NO JobContract is created automatically
        $app->refresh();
        $this->assertEquals('approved', $app->status);
        $this->assertDatabaseMissing('job_contracts', [
            'creator_id' => $this->creator1->id,
            'client_id' => $this->owner->id,
        ]);
    }
}
