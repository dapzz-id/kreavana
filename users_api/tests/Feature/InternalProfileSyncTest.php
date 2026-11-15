<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\UserCredential;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\TestCase;

class InternalProfileSyncTest extends TestCase
{
    use RefreshDatabase;

    private function signedHeaders(array $payload, ?string $secretOverride = null): array
    {
        $clientId = 'kreavana_app';
        $secret = $secretOverride ?? hash('sha256', 'kreavana_ecosystem_secret_key_2026');
        $timestamp = (string) time();
        $rawBody = !empty($payload) ? json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) : '';
        $signature = hash_hmac('sha256', $clientId . '.' . $timestamp . '.' . $rawBody, $secret);

        return [
            'Accept' => 'application/json',
            'X-Client-Id' => $clientId,
            'X-Timestamp' => $timestamp,
            'X-Correlation-Id' => (string) Str::uuid(),
            'X-Signature' => $signature,
        ];
    }

    public function test_internal_profile_update_rejects_missing_or_invalid_hmac_signature(): void
    {
        $payload = ['current_email' => 'institution@kreavana.id', 'username' => 'smk_telesandi'];

        $this->putJson('/api/internal/v1/users/profile', $payload)
            ->assertStatus(401);

        $badHeaders = $this->signedHeaders($payload, 'wrong-secret');
        $this->withHeaders($badHeaders)
            ->putJson('/api/internal/v1/users/profile', $payload)
            ->assertStatus(403);
    }

    public function test_internal_profile_update_syncs_username_email_phone_and_updates_login(): void
    {
        $user = User::create([
            'username' => 'institution_demo',
            'email' => 'institution@kreavana.id',
            'phone' => null,
            'full_name' => 'Kreavana Demo Institution',
            'display_name' => 'Kreavana Demo Institution',
            'is_active' => true,
            'is_suspended' => false,
        ]);

        UserCredential::create([
            'user_id' => $user->id,
            'password_hash' => Hash::make('password123'),
            'is_email_verified' => true,
            'email_verified_at' => now(),
            'password_changed_at' => now(),
        ]);

        // Simulate backend shadow user having a different UUID and sending current_email lookup
        $payload = [
            'user_id' => (string) Str::uuid(),
            'current_email' => 'institution@kreavana.id',
            'current_username' => 'institution_demo',
            'full_name' => 'SMK Telekomunikasi Telesandi',
            'display_name' => 'SMK Telekomunikasi Telesandi',
            'username' => 'SMK_TELESANDI',
            'email' => 'pic@smktelesandi.sch.id',
            'phone' => '081234567890',
        ];

        $this->withHeaders($this->signedHeaders($payload))
            ->putJson('/api/internal/v1/users/profile', $payload)
            ->assertOk()
            ->assertJsonPath('status', true)
            ->assertJsonPath('data.user.username', 'smk_telesandi')
            ->assertJsonPath('data.user.email', 'pic@smktelesandi.sch.id')
            ->assertJsonPath('data.user.phone', '081234567890');

        // Login with old username must now fail
        $this->flushHeaders();
        $this->withHeaders(['X-Client-Id' => 'kreavana_app'])
            ->postJson('/api/v1/auth/login', [
                'identifier' => 'institution_demo',
                'password' => 'password123',
            ])->assertStatus(401);

        // Login with new username (both lowercase & uppercase) must succeed and return phone
        $this->flushHeaders();
        $this->withHeaders(['X-Client-Id' => 'kreavana_app'])
            ->postJson('/api/v1/auth/login', [
                'identifier' => 'SMK_TELESANDI',
                'password' => 'password123',
            ])->assertOk()
            ->assertJsonPath('data.user.username', 'smk_telesandi')
            ->assertJsonPath('data.user.email', 'pic@smktelesandi.sch.id')
            ->assertJsonPath('data.user.phone', '081234567890');
    }

    public function test_internal_profile_update_validates_duplicate_username_and_phone(): void
    {
        User::create([
            'username' => 'existing_user',
            'email' => 'existing@kreavana.id',
            'phone' => '08111111111',
            'full_name' => 'Existing User',
        ]);

        $target = User::create([
            'username' => 'target_user',
            'email' => 'target@kreavana.id',
            'phone' => null,
            'full_name' => 'Target User',
        ]);

        $payload = [
            'user_id' => $target->id,
            'username' => 'EXISTING_USER',
            'phone' => '08111111111',
        ];

        $this->withHeaders($this->signedHeaders($payload))
            ->putJson('/api/internal/v1/users/profile', $payload)
            ->assertStatus(422)
            ->assertJsonPath('status', false);
    }
}
