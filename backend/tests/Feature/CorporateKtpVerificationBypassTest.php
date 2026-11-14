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
}
