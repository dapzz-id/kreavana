<?php

namespace Tests\Feature;

use App\Enums\RoleType;
use App\Models\InstitutionResource;
use App\Models\InstitutionSubAccount;
use App\Models\User;
use App\Services\UsersApiClient;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request as HttpClientRequest;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class ProfileUsersApiSyncAndSubAccountTest extends TestCase
{
    use RefreshDatabase;

    public function test_primary_user_profile_update_syncs_identity_to_users_api_with_hmac_headers(): void
    {
        $institution = User::factory()->create([
            'name' => 'Kreavana Demo Institution',
            'username' => 'institution_demo',
            'email' => 'institution@kreavana.id',
            'phone' => null,
            'role' => RoleType::User,
            'sub_role' => 'institution',
        ]);

        Http::fake([
            '*/api/internal/v1/users/profile' => Http::response([
                'status' => true,
                'message' => 'Profil universal berhasil diperbarui.',
                'data' => [
                    'user' => [
                        'id' => 'iam-uuid-9999',
                        'username' => 'smk_telesandi',
                        'email' => 'pic@smktelesandi.sch.id',
                        'phone' => '081234567890',
                        'full_name' => 'SMK Telekomunikasi Telesandi',
                        'display_name' => 'SMK Telekomunikasi Telesandi',
                        'avatar_url' => null,
                    ],
                ],
            ], 200),
        ]);

        $response = $this->actingAsApi($institution)->putJson('/api/profile', [
            'name' => 'SMK Telekomunikasi Telesandi',
            'username' => 'SMK_TELESANDI',
            'email' => 'PIC@SMKTELESANDI.SCH.ID',
            'phone' => '081234567890',
        ]);

        $response->assertOk()
            ->assertJsonPath('status', true)
            ->assertJsonPath('data.user.username', 'smk_telesandi')
            ->assertJsonPath('data.user.email', 'pic@smktelesandi.sch.id')
            ->assertJsonPath('data.user.phone', '081234567890')
            ->assertJsonPath('data.user.name', 'SMK Telekomunikasi Telesandi');

        $fresh = $institution->fresh();
        $this->assertSame('smk_telesandi', $fresh->username);
        $this->assertSame('pic@smktelesandi.sch.id', $fresh->email);
        $this->assertSame('081234567890', $fresh->phone);

        Http::assertSent(function (HttpClientRequest $request) use ($institution) {
            if ($request->method() !== 'PUT' || !str_ends_with($request->url(), '/api/internal/v1/users/profile')) {
                return false;
            }

            $clientId = $request->header('X-Client-Id')[0] ?? '';
            $timestamp = $request->header('X-Timestamp')[0] ?? '';
            $signature = $request->header('X-Signature')[0] ?? '';
            $correlationId = $request->header('X-Correlation-Id')[0] ?? '';
            $data = $request->data();

            $rawPayload = json_encode($data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
            $expectedSig = hash_hmac('sha256', $clientId . '.' . $timestamp . '.' . $rawPayload, UsersApiClient::getClientSecret());

            return $clientId === UsersApiClient::getClientId()
                && $correlationId !== ''
                && hash_equals($expectedSig, $signature)
                && ($data['user_id'] ?? null) === $institution->id
                && ($data['current_email'] ?? null) === 'institution@kreavana.id'
                && ($data['current_username'] ?? null) === 'institution_demo'
                && ($data['username'] ?? null) === 'smk_telesandi'
                && ($data['email'] ?? null) === 'pic@smktelesandi.sch.id'
                && ($data['phone'] ?? null) === '081234567890';
        });
    }

    public function test_primary_user_profile_update_does_not_mutate_backend_if_users_api_rejects_or_is_unavailable(): void
    {
        $user = User::factory()->create([
            'name' => 'Kreavana Demo Institution',
            'username' => 'institution_demo',
            'email' => 'institution@kreavana.id',
            'phone' => null,
            'role' => RoleType::User,
            'sub_role' => 'institution',
        ]);

        Http::fake([
            '*/api/internal/v1/users/profile' => Http::sequence()
                ->push([
                    'status' => false,
                    'message' => 'Username ini sudah digunakan oleh akun lain.',
                    'errors' => ['username' => ['validation.unique']],
                ], 422)
                ->push([
                    'status' => false,
                    'message' => 'Service Unavailable',
                ], 503),
        ]);

        // 1. Rejection (422) must abort before saving locally
        $this->actingAsApi($user)->putJson('/api/profile', [
            'username' => 'taken_username',
        ])->assertStatus(422)
            ->assertJsonPath('status', false);

        $this->assertSame('institution_demo', $user->fresh()->username);

        // 2. Service unavailable (503) must Fail-Closed without local drift
        $this->actingAsApi($user)->putJson('/api/profile', [
            'username' => 'smk_telesandi',
        ])->assertStatus(503)
            ->assertJsonPath('status', false);

        $this->assertSame('institution_demo', $user->fresh()->username);
    }

    public function test_shadow_user_sync_on_login_updates_username_email_and_phone(): void
    {
        $shadow = User::factory()->create([
            'name' => 'Old Name',
            'username' => 'institution_demo',
            'email' => 'institution@kreavana.id',
            'phone' => null,
            'role' => RoleType::User,
            'sub_role' => 'institution',
        ]);

        $synced = UsersApiClient::syncShadowUser([
            'id' => 'iam-different-uuid',
            'username' => 'SMK_TELESANDI',
            'email' => 'institution@kreavana.id',
            'phone' => '081299988877',
            'full_name' => 'SMK Telekomunikasi Telesandi',
        ]);

        $this->assertSame($shadow->id, $synced->id);
        $this->assertSame('smk_telesandi', $synced->username);
        $this->assertSame('081299988877', $synced->phone);
        $this->assertSame('SMK Telekomunikasi Telesandi', $synced->name);
    }

    public function test_institution_sub_account_is_managed_exclusively_in_backend(): void
    {
        Http::fake();

        $institution = User::factory()->create([
            'name' => 'SMK Telesandi',
            'username' => 'smk_telesandi',
            'email' => 'institution@smktelesandi.sch.id',
            'role' => RoleType::User,
            'sub_role' => 'institution',
        ]);

        // 1. Institution creates staff sub-account -> ZERO calls to users_api
        $createRes = $this->actingAsApi($institution)->postJson('/api/institution/resources', [
            'resource_type' => 'members',
            'title' => 'Guru Koordinator PKL',
            'description' => 'Koordinator BKK',
            'status' => 'published',
            'metadata' => [
                'email' => 'bkk@smktelesandi.sch.id',
                'username' => 'bkk_telesandi',
                'password' => 'Rahasia123!',
                'role' => 'Karyawan / Staf',
                'permissions' => ['program_magang'],
                'department' => 'BKK Sekolah',
            ],
        ]);

        $createRes->assertCreated()
            ->assertJsonPath('data.metadata.username', 'bkk_telesandi')
            ->assertJsonPath('data.metadata.email', 'bkk@smktelesandi.sch.id');

        Http::assertNothingSent();

        $resourceId = $createRes->json('data.id');
        $staffUser = User::where('email', 'bkk@smktelesandi.sch.id')->firstOrFail();
        $this->assertTrue($staffUser->isInstitutionSubAccount());
        $this->assertDatabaseHas('institution_sub_accounts', [
            'user_id' => $staffUser->id,
            'institution_id' => $institution->id,
            'institution_resource_id' => $resourceId,
            'is_active' => true,
        ]);

        // 2. Sub-account logs in via backend auth without calling users_api
        $loginRes = $this->postJson('/api/auth/login', [
            'email' => 'bkk_telesandi',
            'password' => 'Rahasia123!',
        ]);
        $loginRes->assertOk()
            ->assertJsonPath('data.user.username', 'bkk_telesandi')
            ->assertJsonPath('data.user.institution_role', 'staff')
            ->assertJsonPath('data.user.parent_institution_id', $institution->id)
            ->assertJsonPath('data.user.is_institution_sub_account', true);

        Http::assertNothingSent();

        // 3. Sub-account updates its own profile (username/email/phone/name) in backend ONLY -> ZERO calls to users_api
        $this->actingAsApi($staffUser)->putJson('/api/profile', [
            'name' => 'Ketua BKK Baru',
            'username' => 'BKK_TELESANDI_2',
            'email' => 'bkk2@smktelesandi.sch.id',
            'phone' => '081355566677',
        ])->assertOk()
            ->assertJsonPath('data.user.username', 'bkk_telesandi_2')
            ->assertJsonPath('data.user.email', 'bkk2@smktelesandi.sch.id')
            ->assertJsonPath('data.user.phone', '081355566677');

        Http::assertNothingSent();

        $updatedResource = InstitutionResource::findOrFail($resourceId);
        $this->assertSame('Ketua BKK Baru', $updatedResource->title);
        $this->assertSame('bkk2@smktelesandi.sch.id', $updatedResource->metadata['email'] ?? null);
        $this->assertSame('bkk_telesandi_2', $updatedResource->metadata['username'] ?? null);

        // 4. Can login with newly updated sub-account username
        $this->postJson('/api/auth/login', [
            'email' => 'BKK_TELESANDI_2',
            'password' => 'Rahasia123!',
        ])->assertOk();

        // 5. Institution admin updates staff password -> works without users.password column
        $this->actingAsApi($institution)->putJson("/api/institution/resources/{$resourceId}", [
            'title' => 'Ketua BKK Updated',
            'metadata' => [
                'password' => 'PasswordBaru99!',
            ],
        ])->assertOk();

        $this->postJson('/api/auth/login', [
            'email' => 'bkk2@smktelesandi.sch.id',
            'password' => 'Rahasia123!',
        ])->assertStatus(401);

        $this->postJson('/api/auth/login', [
            'email' => 'bkk2@smktelesandi.sch.id',
            'password' => 'PasswordBaru99!',
        ])->assertOk();

        // 6. Sub-account can change own password locally
        $this->actingAsApi($staffUser)->postJson('/api/auth/user/change-password', [
            'current_password' => 'PasswordBaru99!',
            'new_password' => 'Mandiri123!',
        ])->assertOk();

        $this->postJson('/api/auth/login', [
            'email' => 'bkk_telesandi_2',
            'password' => 'Mandiri123!',
        ])->assertOk();

        // 7. Deleting sub-account deactivates login access
        $this->actingAsApi($institution)->deleteJson("/api/institution/resources/{$resourceId}")
            ->assertOk();

        $this->assertFalse(InstitutionSubAccount::where('user_id', $staffUser->id)->first()->is_active);

        $this->postJson('/api/auth/login', [
            'email' => 'bkk_telesandi_2',
            'password' => 'Mandiri123!',
        ])->assertStatus(401);

        Http::assertNothingSent();
    }

    public function test_primary_user_login_remains_fail_closed_when_users_api_is_unavailable(): void
    {
        User::factory()->create([
            'username' => 'regular_user',
            'email' => 'regular@kreavana.id',
            'role' => RoleType::User,
        ]);

        Http::fake([
            '*/api/v1/auth/login' => Http::response(['message' => 'Unavailable'], 503),
        ]);

        $this->postJson('/api/auth/login', [
            'email' => 'regular_user',
            'password' => 'anypassword',
        ])->assertStatus(503);
    }
}
