<?php

namespace Tests\Feature;

use App\Enums\ContractStatus;
use App\Enums\RoleType;
use App\Enums\WorkStatus;
use App\Models\InstitutionResource;
use App\Models\JobContract;
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

    public function test_bidirectional_corporate_to_institution_partnership_flow_and_phone_contacts(): void
    {
        Storage::fake('public');

        $institution = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'institution',
            'name' => 'SMK Telekomunikasi Telesandi Bekasi',
            'username' => 'smk_telesandi',
            'phone' => '081111222333',
            'is_verified' => true,
        ]);

        $corporate = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'corporate',
            'name' => 'PT Kreavana Nusantara Korporat',
            'username' => 'corporate_demo',
            'phone' => '082222333444',
            'is_verified' => true,
        ]);

        // Corporate searches institutions by @username
        $searchRes = $this->actingAsApi($corporate)
            ->getJson('/api/institution/resources/corporate-search?q=@smk_telesandi')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $institution->id)
            ->assertJsonPath('data.0.phone', '081111222333');
        $this->assertSame('institution', $searchRes->json('data.0.selected_sub_role'));

        // Corporate submits partnership proposal targeting Institution
        $createRes = $this->actingAsApi($corporate)
            ->postJson('/api/institution/resources', [
                'resource_type' => 'partners',
                'title' => $institution->name,
                'description' => 'Program perekrutan lulusan magang dan teaching factory.',
                'metadata' => [
                    'target_user_id' => $institution->id,
                    'target_name' => $institution->name,
                    'target_username' => $institution->username,
                    'institution_user_id' => $institution->id,
                    'institution_username' => $institution->username,
                    'mou_files' => [
                        ['url' => 'https://example.test/corp_mou.pdf', 'filename' => 'corp_mou.pdf', 'extension' => 'pdf'],
                        ['url' => 'https://example.test/lampiran.docx', 'filename' => 'lampiran.docx', 'extension' => 'docx'],
                    ],
                ],
            ])
            ->assertStatus(201)
            ->assertJsonPath('data.status', 'pending')
            ->assertJsonPath('data.metadata.sender_phone', '082222333444')
            ->assertJsonPath('data.metadata.target_phone', '081111222333')
            ->assertJsonPath('data.recipient.phone', '081111222333');

        $partnerId = $createRes->json('data.id');

        // Corporate (sender) sees viewer_is_sender=true and cannot approve/reject own proposal
        $corpList = $this->actingAsApi($corporate)
            ->getJson('/api/institution/resources?type=partners')
            ->assertOk();
        $corpRow = collect($corpList->json('data'))->firstWhere('id', $partnerId);
        $this->assertNotNull($corpRow);
        $this->assertTrue($corpRow['viewer_is_sender']);
        $this->assertFalse($corpRow['viewer_is_recipient']);
        $this->assertFalse($corpRow['viewer_can_review']);

        $this->actingAsApi($corporate)->postJson("/api/institution/resources/{$partnerId}/approve")->assertStatus(403);
        $this->actingAsApi($corporate)->postJson("/api/institution/resources/{$partnerId}/reject")->assertStatus(403);

        // Institution (recipient) sees proposal with Corporate's phone and cannot edit sender data
        $instList = $this->actingAsApi($institution)
            ->getJson('/api/institution/resources?type=partners')
            ->assertOk();
        $instRow = collect($instList->json('data'))->firstWhere('id', $partnerId);
        $this->assertNotNull($instRow);
        $this->assertFalse($instRow['viewer_is_sender']);
        $this->assertTrue($instRow['viewer_is_recipient']);
        $this->assertTrue($instRow['viewer_can_review']);
        $this->assertSame('082222333444', $instRow['owner']['phone']);
        $this->assertSame('082222333444', $instRow['metadata']['sender_phone']);

        $this->actingAsApi($institution)
            ->putJson("/api/institution/resources/{$partnerId}", ['title' => 'Diedit Penerima'])
            ->assertStatus(403);

        // Institution (recipient) approves -> publishes MoU document visible to both parties
        $approveRes = $this->actingAsApi($institution)
            ->postJson("/api/institution/resources/{$partnerId}/approve")
            ->assertOk()
            ->assertJsonPath('data.partner.status', 'active');
        $docId = $approveRes->json('data.document.id');

        $corpDocs = $this->actingAsApi($corporate)->getJson('/api/institution/resources?type=documents')->assertOk();
        $instDocs = $this->actingAsApi($institution)->getJson('/api/institution/resources?type=documents')->assertOk();
        $this->assertNotNull(collect($corpDocs->json('data'))->firstWhere('id', $docId));
        $this->assertNotNull(collect($instDocs->json('data'))->firstWhere('id', $docId));
    }

    public function test_sender_cannot_approve_or_reject_own_proposal_and_approved_partner_is_immutable(): void
    {
        $institution = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'institution',
            'phone' => '081900001111',
        ]);
        $corporate = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'corporate',
            'phone' => '082900002222',
        ]);

        $createRes = $this->actingAsApi($institution)
            ->postJson('/api/institution/resources', [
                'resource_type' => 'partners',
                'title' => $corporate->name,
                'description' => 'Kerjasama vokasi dan sertifikasi industri.',
                'metadata' => [
                    'corporate_user_id' => $corporate->id,
                    'corporate_username' => $corporate->username,
                    'mou_files' => [
                        ['url' => 'https://example.test/mou_asli.pdf', 'filename' => 'mou_asli.pdf', 'extension' => 'pdf'],
                    ],
                ],
            ])
            ->assertStatus(201);

        $partnerId = $createRes->json('data.id');

        // Sender cannot approve or reject their own submission
        $this->actingAsApi($institution)->postJson("/api/institution/resources/{$partnerId}/approve")->assertStatus(403);
        $this->actingAsApi($institution)->postJson("/api/institution/resources/{$partnerId}/reject")->assertStatus(403);

        // Sender cannot force-activate pending partnership via PUT
        $this->actingAsApi($institution)
            ->putJson("/api/institution/resources/{$partnerId}", ['status' => 'active'])
            ->assertStatus(403);

        // Target Corporate approves
        $approveRes = $this->actingAsApi($corporate)
            ->postJson("/api/institution/resources/{$partnerId}/approve")
            ->assertOk();
        $documentId = $approveRes->json('data.document.id');

        // Once approved, neither partner data/MoU files nor synced MoU document can be edited
        $this->actingAsApi($institution)
            ->putJson("/api/institution/resources/{$partnerId}", [
                'title' => 'Ubah Nama Setelah Disetujui',
                'description' => 'Ubah deskripsi',
                'metadata' => [
                    'mou_files' => [
                        ['url' => 'https://example.test/ganti.pdf', 'filename' => 'ganti.pdf'],
                    ],
                ],
            ])
            ->assertStatus(403);

        $this->actingAsApi($institution)
            ->putJson("/api/institution/resources/{$documentId}", [
                'title' => 'Ubah MoU Resmi',
            ])
            ->assertStatus(403);

        $this->actingAsApi($corporate)
            ->postJson("/api/institution/resources/{$partnerId}/reject")
            ->assertStatus(422);
    }

    public function test_documents_include_live_project_contracts_wet_mou_letters_and_uploaded_files_without_duplicates(): void
    {
        $institution = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'institution',
            'name' => 'SMK Telekomunikasi Telesandi',
            'username' => 'smk_telesandi',
        ]);
        $creator = User::factory()->create([
            'role' => RoleType::Creator,
            'sub_role' => 'videographer',
            'name' => 'Kreator Video',
            'username' => 'videographer_demo',
        ]);
        $otherInstitution = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'institution',
            'name' => 'Sekolah Lain',
        ]);

        // Project owned by institution with wet-signature MoU, official letter, submitted docs & deliverables
        $opp = Opportunity::create([
            'title' => 'Riset Kolaborasi Preservasi Budaya Digital',
            'description' => 'Pembuatan arsip 3D photogrammetry.',
            'sub_role_slug' => 'videographer',
            'type' => 'project',
            'status' => 'open',
            'wet_signature_document_url' => 'https://example.test/mou_ttd_basah.pdf',
            'wet_signature_verified_at' => now(),
            'official_acceptance_letter_url' => 'https://example.test/surat_resmi.pdf',
            'official_acceptance_letter_name' => 'Surat_Resmi_Riset.pdf',
            'official_acceptance_letter_uploaded_at' => now(),
            'posted_by' => $institution->id,
            'created_at' => now(),
        ]);

        $contract = JobContract::create([
            'contract_number' => 'KRV/CTR/2026/001',
            'client_id' => $institution->id,
            'creator_id' => $creator->id,
            'opportunity_id' => $opp->id,
            'title' => $opp->title,
            'description' => 'Kontrak riset kolaborasi digital.',
            'agreed_price' => 65000000,
            'escrow_amount' => 65000000,
            'contract_status' => ContractStatus::Active,
            'work_status' => WorkStatus::InProgress,
            'client_approved' => true,
            'creator_approved' => true,
            'deliverables' => [
                [
                    'title' => 'Laporan Hasil Kerja Final.pdf',
                    'url' => 'https://example.test/hasil_kerja_final.pdf',
                    'type' => 'document',
                ],
            ],
        ]);

        OpportunityApplication::create([
            'opportunity_id' => $opp->id,
            'creator_id' => $creator->id,
            'sub_role_slug' => 'videographer',
            'pitch_message' => 'Proposal dan hasil kerja proyek.',
            'contract_number' => 'KRV/CTR/2026/001',
            'status' => 'approved',
            'submitted_documents' => [
                [
                    'title' => 'Proposal Teknis Lapangan.pdf',
                    'url' => 'https://example.test/proposal_teknis.pdf',
                    'type' => 'document',
                ],
            ],
            // Duplicate URL matching JobContract.deliverables should be deduplicated
            'submitted_deliverables' => [
                [
                    'title' => 'Laporan Hasil Kerja Final.pdf',
                    'url' => 'https://example.test/hasil_kerja_final.pdf',
                    'type' => 'document',
                ],
            ],
        ]);

        // Unrelated other institution project must never leak
        $unrelatedOpp = Opportunity::create([
            'title' => 'Proyek Rahasia Sekolah Lain',
            'sub_role_slug' => 'editor',
            'type' => 'project',
            'status' => 'open',
            'wet_signature_document_url' => 'https://example.test/secret_other.pdf',
            'posted_by' => $otherInstitution->id,
            'created_at' => now(),
        ]);

        $res = $this->actingAsApi($institution)
            ->getJson('/api/institution/resources?type=documents')
            ->assertOk();

        $docs = collect($res->json('data'));
        $titles = $docs->pluck('title')->all();

        $this->assertContains('Kontrak Proyek - Riset Kolaborasi Preservasi Budaya Digital', $titles);
        $this->assertContains('MoU Tanda Tangan Basah - Riset Kolaborasi Preservasi Budaya Digital', $titles);
        $this->assertContains('Surat Resmi Penerimaan - Riset Kolaborasi Preservasi Budaya Digital', $titles);
        $this->assertContains('Proposal Teknis Lapangan.pdf — Riset Kolaborasi Preservasi Budaya Digital', $titles);
        $this->assertContains('Laporan Hasil Kerja Final.pdf — Riset Kolaborasi Preservasi Budaya Digital', $titles);
        $this->assertCount(5, $docs);
        $this->assertNull($docs->firstWhere('id', 'project-wet-mou-' . $unrelatedOpp->id));

        // Guard against Postgres UUID 22P02 when mutating or deleting linked project IDs via institution endpoint
        $this->actingAsApi($institution)
            ->putJson("/api/institution/resources/project-contract-{$contract->id}", ['title' => 'Edit'])
            ->assertStatus(403);
        $this->actingAsApi($institution)
            ->deleteJson("/api/institution/resources/project-contract-{$contract->id}")
            ->assertStatus(403);

        // When project & contract are deleted, linked documents vanish automatically
        $contract->delete();
        OpportunityApplication::where('opportunity_id', $opp->id)->delete();
        $opp->delete();

        $afterDelete = $this->actingAsApi($institution)
            ->getJson('/api/institution/resources?type=documents')
            ->assertOk();
        $this->assertCount(0, $afterDelete->json('data'));
    }

    public function test_deleting_partner_removes_synced_mou_document_and_excludes_orphaned_partner_documents(): void
    {
        $institution = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'institution',
            'name' => 'SMK Telekomunikasi Telesandi',
        ]);
        $corporate = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'corporate',
            'name' => 'CV Transforma Alam Kreasi',
        ]);

        // Pending partner owned by institution can be deleted via API alongside any linked doc
        $pendingPartner = InstitutionResource::create([
            'user_id' => $institution->id,
            'resource_type' => 'partners',
            'title' => 'PT Mitra Pending',
            'description' => 'Kerjasama magang pending.',
            'status' => 'pending',
        ]);
        $pendingLinkedDoc = InstitutionResource::create([
            'user_id' => $institution->id,
            'resource_type' => 'documents',
            'title' => 'Perjanjian Kerjasama (MoU) - PT Mitra Pending',
            'status' => 'published',
            'metadata' => ['partner_resource_id' => $pendingPartner->id],
        ]);

        $this->actingAsApi($institution)
            ->deleteJson("/api/institution/resources/{$pendingPartner->id}")
            ->assertOk();

        $this->assertDatabaseMissing('institution_resources', ['id' => $pendingPartner->id]);
        $this->assertDatabaseMissing('institution_resources', ['id' => $pendingLinkedDoc->id]);

        // Approved partner deleted directly in DB -> its orphaned synced MoU is automatically excluded
        $createRes = $this->actingAsApi($institution)
            ->postJson('/api/institution/resources', [
                'resource_type' => 'partners',
                'title' => $corporate->name,
                'description' => 'Kerjasama resmi industri.',
                'metadata' => [
                    'corporate_user_id' => $corporate->id,
                    'mou_files' => [
                        ['url' => 'https://example.test/mou_corp.pdf', 'filename' => 'mou_corp.pdf'],
                    ],
                ],
            ])
            ->assertStatus(201);

        $partnerId = $createRes->json('data.id');
        $approveRes = $this->actingAsApi($corporate)
            ->postJson("/api/institution/resources/{$partnerId}/approve")
            ->assertOk();
        $syncedDocId = $approveRes->json('data.document.id');

        $this->assertNotNull(
            collect($this->actingAsApi($institution)->getJson('/api/institution/resources?type=documents')->json('data'))
                ->firstWhere('id', $syncedDocId)
        );

        // Simulate direct SQL DELETE FROM institution_resources WHERE resource_type = 'partners'
        InstitutionResource::where('id', $partnerId)->delete();

        $docsAfterDirectDelete = collect(
            $this->actingAsApi($institution)->getJson('/api/institution/resources?type=documents')->assertOk()->json('data')
        );
        $this->assertNull($docsAfterDirectDelete->firstWhere('id', $syncedDocId));
    }
}
