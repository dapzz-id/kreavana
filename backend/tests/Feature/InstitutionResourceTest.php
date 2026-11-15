<?php

namespace Tests\Feature;

use App\Enums\RoleType;
use App\Models\InstitutionResource;
use App\Models\Opportunity;
use App\Models\OpportunityApplication;
use App\Models\OpportunityRequirement;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
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

    public function test_corporate_search_matches_name_username_and_at_prefix_case_insensitively(): void
    {
        $institution = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'institution',
        ]);

        $corporate = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'corporate',
            'name' => 'PT Kreavana Nusantara Korporat',
            'username' => 'corporate_demo',
            'is_verified' => true,
        ]);

        $this->actingAsApi($institution)
            ->getJson('/api/institution/resources/corporate-search?q=kreavana')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $corporate->id);

        $this->actingAsApi($institution)
            ->getJson('/api/institution/resources/corporate-search?q=corporate_demo')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.username', 'corporate_demo');

        $this->actingAsApi($institution)
            ->getJson('/api/institution/resources/corporate-search?q=@corporate_demo')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $corporate->id);
    }

    public function test_partner_proposal_requires_description_and_one_to_three_cooperation_files(): void
    {
        Storage::fake('public');

        $institution = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'institution',
        ]);

        // Reject unsupported extension on upload-mou
        $this->actingAsApi($institution)
            ->post('/api/institution/resources/upload-mou', [
                'mou_file' => UploadedFile::fake()->create('script.txt', 10, 'text/plain'),
            ])
            ->assertStatus(422);

        // Missing description -> 422
        $this->actingAsApi($institution)
            ->postJson('/api/institution/resources', [
                'resource_type' => 'partners',
                'title' => 'PT Mitra Contoh',
                'description' => '',
                'metadata' => [
                    'mou_files' => [
                        ['url' => 'https://example.test/doc1.pdf', 'filename' => 'doc1.pdf'],
                    ],
                ],
            ])
            ->assertStatus(422);

        // Missing cooperation file -> 422
        $this->actingAsApi($institution)
            ->postJson('/api/institution/resources', [
                'resource_type' => 'partners',
                'title' => 'PT Mitra Contoh',
                'description' => 'Kerjasama magang siswa DKV & animasi.',
                'metadata' => [],
            ])
            ->assertStatus(422);

        // Exceeding max 3 files -> 422
        $this->actingAsApi($institution)
            ->postJson('/api/institution/resources', [
                'resource_type' => 'partners',
                'title' => 'PT Mitra Contoh',
                'description' => 'Kerjasama magang siswa DKV & animasi.',
                'metadata' => [
                    'mou_files' => [
                        ['url' => 'https://example.test/1.pdf', 'filename' => '1.pdf'],
                        ['url' => 'https://example.test/2.pdf', 'filename' => '2.pdf'],
                        ['url' => 'https://example.test/3.pdf', 'filename' => '3.pdf'],
                        ['url' => 'https://example.test/4.pdf', 'filename' => '4.pdf'],
                    ],
                ],
            ])
            ->assertStatus(422);
    }

    public function test_partner_proposal_with_three_files_syncs_to_corporate_and_publishes_documents_on_approval(): void
    {
        Storage::fake('public');

        $institution = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'institution',
            'name' => 'SMK Telekomunikasi Telesandi Bekasi',
            'username' => 'institution_demo',
        ]);

        $corporate = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'corporate',
            'name' => 'PT Kreavana Nusantara Korporat',
            'username' => 'corporate_demo',
        ]);

        $otherCorporate = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'corporate',
            'name' => 'PT Lain Tidak Terkait',
            'username' => 'other_corp',
        ]);

        // Upload 3 real files via upload-mou endpoint
        $uploadedFiles = [];
        foreach (['mou_draf.pdf', 'lampiran_kurikulum.docx', 'silabus_pkl.pdf'] as $idx => $name) {
            $mime = str_ends_with($name, '.docx')
                ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
                : 'application/pdf';
            $uploadRes = $this->actingAsApi($institution)
                ->post('/api/institution/resources/upload-mou', [
                    'mou_file' => UploadedFile::fake()->create($name, 100 + ($idx * 50), $mime),
                ])
                ->assertOk();
            $uploadedFiles[] = $uploadRes->json('data');
        }

        // Submit simplified 3-part partnership proposal (PT, Deskripsi, max 3 Berkas)
        $createRes = $this->actingAsApi($institution)
            ->postJson('/api/institution/resources', [
                'resource_type' => 'partners',
                'title' => $corporate->name,
                'description' => 'Program magang siswa SMK jurusan Animasi & DKV serta kunjungan guru tamu.',
                'metadata' => [
                    'corporate_user_id' => $corporate->id,
                    'corporate_name' => $corporate->name,
                    'corporate_username' => $corporate->username,
                    'mou_files' => $uploadedFiles,
                ],
            ]);

        $createRes->assertStatus(201)
            ->assertJsonPath('data.status', 'pending')
            ->assertJsonPath('data.metadata.institution_name', 'SMK Telekomunikasi Telesandi Bekasi')
            ->assertJsonPath('data.metadata.mou_url', $uploadedFiles[0]['url'])
            ->assertJsonCount(3, 'data.metadata.mou_files');

        $partnerId = $createRes->json('data.id');

        // Corporate sees the incoming proposal with 3 files and institution owner details
        $corpPartnersRes = $this->actingAsApi($corporate)
            ->getJson('/api/institution/resources?type=partners')
            ->assertOk();

        $matching = collect($corpPartnersRes->json('data'))->firstWhere('id', $partnerId);
        $this->assertNotNull($matching);
        $this->assertSame('SMK Telekomunikasi Telesandi Bekasi', $matching['metadata']['institution_name']);
        $this->assertCount(3, $matching['metadata']['mou_files']);
        $this->assertSame('institution_demo', $matching['owner']['username']);

        // Unrelated corporate cannot approve
        $this->actingAsApi($otherCorporate)
            ->postJson("/api/institution/resources/{$partnerId}/approve")
            ->assertStatus(403);

        // Target corporate approves
        $approveRes = $this->actingAsApi($corporate)
            ->postJson("/api/institution/resources/{$partnerId}/approve")
            ->assertOk()
            ->assertJsonPath('data.partner.status', 'active')
            ->assertJsonCount(3, 'data.document.metadata.mou_files');

        $documentId = $approveRes->json('data.document.id');

        // Both Institution and Corporate see the published MoU document in type=documents
        $schoolDocs = $this->actingAsApi($institution)
            ->getJson('/api/institution/resources?type=documents')
            ->assertOk();
        $this->assertNotNull(collect($schoolDocs->json('data'))->firstWhere('id', $documentId));

        $corpDocs = $this->actingAsApi($corporate)
            ->getJson('/api/institution/resources?type=documents')
            ->assertOk();
        $corpDoc = collect($corpDocs->json('data'))->firstWhere('id', $documentId);
        $this->assertNotNull($corpDoc);
        $this->assertCount(3, $corpDoc['metadata']['mou_files']);
    }

    public function test_corporate_can_reject_partner_proposal(): void
    {
        $institution = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'institution',
        ]);
        $corporate = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'corporate',
            'username' => 'pt_rejection_target',
        ]);

        $res = $this->actingAsApi($institution)
            ->postJson('/api/institution/resources', [
                'resource_type' => 'partners',
                'title' => $corporate->name,
                'description' => 'Kerjasama riset industri.',
                'metadata' => [
                    'corporate_user_id' => $corporate->id,
                    'corporate_username' => $corporate->username,
                    'mou_files' => [
                        ['url' => 'https://example.test/proposal.pdf', 'filename' => 'proposal.pdf'],
                    ],
                ],
            ])
            ->assertStatus(201);

        $partnerId = $res->json('data.id');

        $this->actingAsApi($corporate)
            ->postJson("/api/institution/resources/{$partnerId}/reject")
            ->assertOk()
            ->assertJsonPath('data.status', 'rejected')
            ->assertJsonPath('data.metadata.approval_status', 'rejected');
    }
}
