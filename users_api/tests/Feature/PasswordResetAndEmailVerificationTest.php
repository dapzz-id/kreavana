<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\UserCredential;
use App\Models\UserSession;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\TestCase;

class PasswordResetAndEmailVerificationTest extends TestCase
{
    use RefreshDatabase;

    private function signedHeaders(array $payload, ?string $secretOverride = null): array
    {
        $clientId = 'kreavana_app';
        $secret = $secretOverride ?? hash('sha256', env('DEFAULT_CLIENT_SECRET', 'kreavana_ecosystem_secret_key_2026'));
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

    public function test_unverified_user_login_is_blocked_until_internal_verify_email_runs(): void
    {
        $registerRes = $this->withHeaders(['X-Client-Id' => 'kreavana_app'])
            ->postJson('/api/v1/auth/register', [
                'username' => 'emailtestuser',
                'email' => 'emailtest@example.com',
                'password' => 'Password123!',
                'full_name' => 'Email Test User',
            ]);

        $registerRes->assertStatus(201)
            ->assertJsonPath('data.user.is_email_verified', false);

        // Login before email verification returns 403 email_not_verified
        $this->flushHeaders();
        $this->withHeaders(['X-Client-Id' => 'kreavana_app'])
            ->postJson('/api/v1/auth/login', [
                'identifier' => 'emailtestuser',
                'password' => 'Password123!',
            ])
            ->assertStatus(403)
            ->assertJsonPath('error_code', 'email_not_verified')
            ->assertJsonPath('data.email', 'emailtest@example.com');

        // Unsigned verify-email call is rejected
        $verifyPayload = ['email' => 'emailtest@example.com'];
        $this->flushHeaders();
        $this->postJson('/api/internal/v1/users/verify-email', $verifyPayload)
            ->assertStatus(401);

        // HMAC-signed internal verify-email marks credential verified
        $this->flushHeaders();
        $this->withHeaders($this->signedHeaders($verifyPayload))
            ->postJson('/api/internal/v1/users/verify-email', $verifyPayload)
            ->assertOk()
            ->assertJsonPath('data.is_email_verified', true);

        // Subsequent login succeeds
        $this->flushHeaders();
        $this->withHeaders(['X-Client-Id' => 'kreavana_app'])
            ->postJson('/api/v1/auth/login', [
                'identifier' => 'emailtestuser',
                'password' => 'Password123!',
            ])
            ->assertOk()
            ->assertJsonPath('data.user.is_email_verified', true);
    }

    public function test_password_reset_otp_flow_updates_password_and_revokes_sessions(): void
    {
        $user = User::create([
            'username' => 'resetuser',
            'email' => 'reset@example.com',
            'full_name' => 'Reset User',
            'is_active' => true,
            'is_suspended' => false,
        ]);

        UserCredential::create([
            'user_id' => $user->id,
            'password_hash' => Hash::make('OldPassword123!'),
            'is_email_verified' => true,
            'email_verified_at' => now(),
            'password_changed_at' => now(),
        ]);

        UserSession::create([
            'user_id' => $user->id,
            'client_id' => 'kreavana_app',
            'refresh_token_id' => hash('sha256', 'active-refresh-token'),
            'expires_at' => now()->addDays(7),
            'is_revoked' => false,
        ]);

        // 1. Request reset OTP
        $reqPayload = ['email' => 'RESET@EXAMPLE.COM'];
        $reqRes = $this->withHeaders($this->signedHeaders($reqPayload))
            ->postJson('/api/internal/v1/auth/password-reset/request', $reqPayload)
            ->assertOk()
            ->assertJsonPath('data.found', true)
            ->assertJsonPath('data.email', 'reset@example.com');

        $otp = $reqRes->json('data.otp');
        $this->assertMatchesRegularExpression('/^[0-9]{6}$/', (string) $otp);

        // 2. Wrong OTP fails with invalid_reset_code & increments attempts
        $badPayload = [
            'email' => 'reset@example.com',
            'code' => '000000' === $otp ? '111111' : '000000',
            'password' => 'NewPassword123!',
            'password_confirmation' => 'NewPassword123!',
        ];
        $this->flushHeaders();
        $this->withHeaders($this->signedHeaders($badPayload))
            ->postJson('/api/internal/v1/auth/password-reset/confirm', $badPayload)
            ->assertStatus(422)
            ->assertJsonPath('error_code', 'invalid_reset_code');

        $this->assertSame(1, (int) DB::table('password_reset_tokens')->where('email', 'reset@example.com')->value('attempts'));

        // 3. Valid OTP updates password, removes token, and revokes existing sessions
        $goodPayload = [
            'email' => 'reset@example.com',
            'code' => $otp,
            'password' => 'NewPassword123!',
            'password_confirmation' => 'NewPassword123!',
        ];
        $this->flushHeaders();
        $this->withHeaders($this->signedHeaders($goodPayload))
            ->postJson('/api/internal/v1/auth/password-reset/confirm', $goodPayload)
            ->assertOk()
            ->assertJsonPath('status', true);

        $this->assertDatabaseMissing('password_reset_tokens', ['email' => 'reset@example.com']);
        $this->assertTrue((bool) UserSession::where('user_id', $user->id)->first()->is_revoked);

        // Old password fails; new password succeeds
        $this->flushHeaders();
        $this->withHeaders(['X-Client-Id' => 'kreavana_app'])
            ->postJson('/api/v1/auth/login', [
                'identifier' => 'resetuser',
                'password' => 'OldPassword123!',
            ])->assertStatus(401);

        $this->flushHeaders();
        $this->withHeaders(['X-Client-Id' => 'kreavana_app'])
            ->postJson('/api/v1/auth/login', [
                'identifier' => 'resetuser',
                'password' => 'NewPassword123!',
            ])->assertOk();
    }

    public function test_internal_set_password_syncs_new_credential_hash(): void
    {
        $user = User::create([
            'username' => 'googleuser',
            'email' => 'googleuser@example.com',
            'full_name' => 'Google User',
            'is_active' => true,
            'is_suspended' => false,
        ]);

        UserCredential::create([
            'user_id' => $user->id,
            'password_hash' => Hash::make('RandomOld123'),
            'is_email_verified' => true,
            'email_verified_at' => now(),
        ]);

        $payload = [
            'email' => 'googleuser@example.com',
            'password' => 'SyncedTemp99!',
        ];
        $this->withHeaders($this->signedHeaders($payload))
            ->postJson('/api/internal/v1/users/set-password', $payload)
            ->assertOk();

        $this->flushHeaders();
        $this->withHeaders(['X-Client-Id' => 'kreavana_app'])
            ->postJson('/api/v1/auth/login', [
                'identifier' => 'googleuser@example.com',
                'password' => 'SyncedTemp99!',
            ])->assertOk();
    }
}
