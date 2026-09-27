<?php

namespace Tests\Feature;

use App\Enums\RoleType;
use App\Models\InstitutionResource;
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
}
