<?php

namespace Tests\Feature;

use App\Enums\RoleType;
use App\Models\InstitutionResource;
use App\Models\Opportunity;
use App\Models\OpportunityApplication;
use App\Models\OpportunityRequirement;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class InstitutionResourceTest extends TestCase
{
    use RefreshDatabase;

    public function test_institution_can_create_update_and_delete_its_own_resource(): void
    {
        $institution = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'institution',
        ]);

        $created = $this->actingAsApi($institution)->postJson('/api/institution/resources', [
            'resource_type' => 'budgets',
            'title' => 'Anggaran Layanan Digital',
            'description' => 'Realisasi program layanan digital tahun berjalan.',
            'status' => 'in_progress',
            'metadata' => [
                'period' => '2026',
                'allocation' => '100000000',
                'realization' => '25000000',
            ],
        ]);

        $created->assertCreated()
            ->assertJsonPath('data.status', 'in_progress')
            ->assertJsonPath('data.metadata.allocation', '100000000');

        $resourceId = $created->json('data.id');
        $this->getJson('/api/institution/resources?type=budgets')
            ->assertOk()
            ->assertJsonPath('data.0.id', $resourceId);

        $this->putJson("/api/institution/resources/{$resourceId}", [
            'title' => 'Anggaran Layanan Terpadu',
            'status' => 'completed',
        ])->assertOk()->assertJsonPath('data.status', 'completed');

        $this->deleteJson("/api/institution/resources/{$resourceId}")->assertOk();
        $this->assertDatabaseMissing('institution_resources', ['id' => $resourceId]);
    }

    public function test_institution_resources_are_account_scoped(): void
    {
        $owner = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'institution',
        ]);
        $other = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'institution',
        ]);
        $resource = InstitutionResource::create([
            'user_id' => $owner->id,
            'resource_type' => 'documents',
            'title' => 'Peraturan Instansi',
            'status' => 'draft',
        ]);

        $this->actingAsApi($other)
            ->putJson("/api/institution/resources/{$resource->id}", ['title' => 'Diambil alih'])
            ->assertNotFound();

        $this->actingAsApi($other)
            ->deleteJson("/api/institution/resources/{$resource->id}")
            ->assertNotFound();
    }

    public function test_only_published_announcements_are_public(): void
    {
        $institution = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'institution',
        ]);
        InstitutionResource::create([
            'user_id' => $institution->id,
            'resource_type' => 'announcements',
            'title' => 'Pengumuman Terbit',
            'status' => 'published',
            'published_at' => now(),
        ]);
        InstitutionResource::create([
            'user_id' => $institution->id,
            'resource_type' => 'announcements',
            'title' => 'Pengumuman Draft',
            'status' => 'draft',
        ]);

        $this->getJson('/api/institution/announcements')
            ->assertOk()
            ->assertJsonFragment(['title' => 'Pengumuman Terbit'])
            ->assertJsonMissing(['title' => 'Pengumuman Draft']);
    }

    public function test_institution_resources_do_not_auto_seed_dummy_data_when_empty(): void
    {
        $institution = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'institution',
        ]);

        $this->actingAsApi($institution)
            ->getJson('/api/institution/resources?type=partners')
            ->assertOk()
            ->assertExactJson([
                'status' => true,
                'message' => 'Data instansi berhasil diambil.',
                'data' => [],
            ]);

        $this->assertDatabaseCount('institution_resources', 0);
    }

    public function test_institution_can_submit_multiple_and_additional_internship_students_from_database(): void
    {
        $corporate = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'corporate',
        ]);

        $institution = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'institution',
        ]);

        $opp = Opportunity::create([
            'title' => 'Program Magang 3D Artist Batch I',
            'description' => 'Penempatan siswa magang industri animasi.',
            'sub_role_slug' => 'magang',
            'type' => 'project',
            'status' => 'open',
            'posted_by' => $corporate->id,
            'created_at' => now(),
        ]);

        OpportunityRequirement::create([
            'opportunity_id' => $opp->id,
            'sub_role_slug' => '3d_artist',
            'quantity' => 5,
            'notes' => 'Kuota 5 siswa',
        ]);

        // Initial student submission by institution
        $first = $this->actingAsApi($institution)->postJson("/api/opportunities/{$opp->id}/applications", [
            'sub_role_slug' => '3d_artist',
            'pitch_message' => 'Mengajukan siswa pertama untuk program magang 3D Artist.',
            'submitted_documents' => [[
                'student_name' => 'Dimas Aditya',
                'major_class' => 'XII Animasi 1',
                'role' => '3D Artist',
                'portfolio_url' => 'https://portfolio.example.com/dimas',
                'note' => 'Menguasai Blender',
                'is_additional' => false,
                'is_replacement' => false,
            ]],
        ]);

        $first->assertCreated()
            ->assertJsonPath('data.status', 'pending')
            ->assertJsonPath('data.submitted_documents.0.student_name', 'Dimas Aditya');

        $firstAppId = $first->json('data.id');

        // Duplicate same student name is rejected
        $this->actingAsApi($institution)->postJson("/api/opportunities/{$opp->id}/applications", [
            'sub_role_slug' => '3d_artist',
            'pitch_message' => 'Mengajukan ulang siswa yang sama.',
            'submitted_documents' => [[
                'student_name' => 'Dimas Aditya',
                'major_class' => 'XII Animasi 1',
            ]],
        ])->assertStatus(409);

        // Corporate approves initial student -> school now has an approved student
        $this->actingAsApi($corporate)
            ->postJson("/api/opportunities/applications/{$firstAppId}/approve")
            ->assertOk();

        // Institution submits additional student -> stays pending without altering approved student
        $second = $this->actingAsApi($institution)->postJson("/api/opportunities/{$opp->id}/applications", [
            'sub_role_slug' => '3d_artist',
            'pitch_message' => 'Mengajukan siswa tambahan setelah sekolah disetujui.',
            'submitted_documents' => [[
                'student_name' => 'Siti Nurhaliza',
                'major_class' => 'XII Animasi 2',
                'role' => '3D Artist',
                'is_additional' => true,
            ]],
        ]);

        $this->assertSame(201, $second->status(), $second->getContent());
        $second->assertJsonPath('data.status', 'pending')
            ->assertJsonPath('data.submitted_documents.0.student_name', 'Siti Nurhaliza');

        $this->assertDatabaseHas('opportunity_applications', [
            'id' => $firstAppId,
            'status' => 'approved',
        ]);

        $this->actingAsApi($institution)
            ->getJson('/api/opportunities/my')
            ->assertOk()
            ->assertJsonPath('data.0.has_applied', true);
    }
}
