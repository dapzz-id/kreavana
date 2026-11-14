<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\User;
use App\Models\UserSubRole;
use App\Enums\RoleType;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tymon\JWTAuth\Facades\JWTAuth;

class CorporateKtpVerificationBypassTest extends TestCase
{
    use RefreshDatabase;

    public function test_corporate_user_can_create_opportunity_without_ktp_verification()
    {
        $corp = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'corporate',
            'is_verified' => false,
        ]);

        UserSubRole::create([
            'user_id' => $corp->id,
            'sub_role_slug' => 'corporate',
            'role_type' => RoleType::User->value,
            'is_active' => true,
        ]);

        $this->assertTrue($corp->isCorporate());

        $token = JWTAuth::fromUser($corp);

        $response = $this->withHeader('Authorization', 'Bearer ' . $token)
            ->postJson('/api/opportunities', [
                'title' => 'Tender Pengadaan Video Profil B2B',
                'description' => 'Membutuhkan tim videografer profesional untuk corporate profile.',
                'type' => 'project',
                'sub_role_slug' => 'videographer',
                'budget' => 25000000,
                'location' => 'Jakarta Selatan',
            ]);

        $this->assertNotEquals(403, $response->getStatusCode());
    }

    public function test_unverified_regular_client_is_blocked_from_creating_opportunity()
    {
        $client = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => null,
            'is_verified' => false,
        ]);

        $this->assertFalse($client->isCorporate());

        $token = JWTAuth::fromUser($client);

        $response = $this->withHeader('Authorization', 'Bearer ' . $token)
            ->postJson('/api/opportunities', [
                'title' => 'Proyek Foto Studio',
                'description' => 'Membutuhkan fotografer untuk sesi foto produk.',
                'type' => 'project',
                'sub_role_slug' => 'photographer',
                'budget' => 5000000,
                'location' => 'Jakarta',
            ]);

        $response->assertStatus(403)
            ->assertJsonFragment([
                'message' => 'Klien wajib melakukan verifikasi KTP terlebih dahulu sebelum mempublikasikan kebutuhan proyek.',
            ]);
    }

    public function test_corporate_user_cannot_apply_for_personal_ktp_verification()
    {
        $corp = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'corporate',
            'is_verified' => false,
        ]);

        $token = JWTAuth::fromUser($corp);

        $response = $this->withHeader('Authorization', 'Bearer ' . $token)
            ->postJson('/api/verification/client', [
                'nik' => '3201012345670001',
                'full_name_ktp' => 'Budi Corporate',
                'ktp_photo_url' => 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
                'selfie_photo_url' => 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
            ]);

        $response->assertStatus(422)
            ->assertJsonFragment([
                'message' => 'Akun Anda telah berstatus Corporate. Verifikasi KTP Klien tidak diperlukan untuk akun Corporate.',
            ]);
    }

    public function test_corporate_user_has_is_verified_true_via_model_attribute()
    {
        $corp = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'corporate',
            'is_verified' => false,
        ]);

        $this->assertTrue($corp->isCorporate());
        $this->assertTrue($corp->is_verified);
        $this->assertEquals('corporate', $corp->verification_type);
    }

    public function test_corporate_user_verification_status_endpoint_returns_verified_true()
    {
        $corp = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'corporate',
            'is_verified' => false,
        ]);

        $token = JWTAuth::fromUser($corp);

        $response = $this->withHeader('Authorization', 'Bearer ' . $token)
            ->getJson('/api/verification/status');

        $response->assertStatus(200)
            ->assertJsonPath('data.is_verified', true)
            ->assertJsonPath('data.verification_type', 'corporate');
    }

    public function test_corporate_can_create_lowongan_with_magang_or_job_type_and_it_normalizes_to_project()
    {
        $corp = User::factory()->create([
            'role' => RoleType::User,
            'sub_role' => 'corporate',
            'is_verified' => false,
        ]);

        $token = JWTAuth::fromUser($corp);

        $response = $this->withHeader('Authorization', 'Bearer ' . $token)
            ->postJson('/api/opportunities', [
                'title' => 'Program Magang MBKM 3D Modeler Batch I 2026',
                'description' => 'Kerja sama penempatan talenta vokasi dan mahasiswa magang.',
                'type' => 'magang', // Testing normalization from magang to project
                'sub_role_slug' => 'magang',
                'budget_range' => 'Rp 2.500.000 - Rp 3.500.000 / bulan',
                'deadline' => '2026-09-21T00:00:00.000',
                'requirements' => [
                    [
                        'sub_role_slug' => 'photographer',
                        'quantity' => 10,
                        'notes' => 'Spesialisasi Photographer (10 kuota)',
                    ],
                    [
                        'sub_role_slug' => 'videographer',
                        'quantity' => 10,
                        'notes' => 'Spesialisasi Videographer (10 kuota)',
                    ],
                    [
                        'sub_role_slug' => 'kualifikasi',
                        'quantity' => 1,
                        'notes' => 'Siswa SMK vokasi atau Mahasiswa aktif',
                    ],
                ],
            ]);

        $response->assertStatus(201)
            ->assertJsonPath('status', true)
            ->assertJsonPath('data.title', 'Program Magang MBKM 3D Modeler Batch I 2026')
            ->assertJsonPath('data.type', 'project')
            ->assertJsonPath('data.sub_role_slug', 'magang');

        $oppId = $response->json('data.id');
        $this->assertNotNull($oppId);

        // Verify it appears in my opportunities
        $myResponse = $this->withHeader('Authorization', 'Bearer ' . $token)
            ->getJson('/api/opportunities/my');
        $myResponse->assertStatus(200);
        $myIds = collect($myResponse->json('data'))->pluck('id')->all();
        $this->assertContains($oppId, $myIds);

        // Verify it appears in public list for institution/schools
        $publicResponse = $this->getJson('/api/opportunities?limit=50');
        $publicResponse->assertStatus(200);
        $publicIds = collect($publicResponse->json('data'))->pluck('id')->all();
        $this->assertContains($oppId, $publicIds);
    }
}
