<?php

namespace Tests\Feature;

use App\Jobs\SendEmailVerificationJob;
use App\Jobs\SendPasswordResetJob;
use App\Jobs\SendSocialLoginPasswordJob;
use App\Mail\EmailVerificationMail;
use App\Mail\PasswordResetMail;
use App\Mail\SocialLoginPasswordMail;
use App\Models\User;
use App\Models\UserSession;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request as HttpClientRequest;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class EmailQueueFlowsTest extends TestCase
{
    use RefreshDatabase;

    public function test_register_dispatches_queued_verification_email_and_verify_syncs_to_users_api(): void
    {
        Queue::fake();
        Mail::fake();

        Http::fake([
            '*/api/v1/auth/register' => Http::response([
                'status' => true,
                'message' => 'Registrasi identitas universal berhasil.',
                'data' => [
                    'user' => [
                        'id' => '019a0000-0000-7000-8000-000000000001',
                        'username' => 'newmember',
                        'email' => 'newmember@example.com',
                        'full_name' => 'New Member',
                        'is_email_verified' => false,
                    ],
                ],
            ], 201),
            '*/api/internal/v1/users/verify-email' => Http::response([
                'status' => true,
                'data' => ['is_email_verified' => true],
            ], 200),
        ]);

        // 1. Register must keep shadow user unverified and dispatch SendEmailVerificationJob
        $regRes = $this->postJson('/api/auth/register', [
            'name' => 'New Member',
            'username' => 'newmember',
            'email' => 'newmember@example.com',
            'password' => 'SecretPass123',
        ]);

        $regRes->assertStatus(201)
            ->assertJsonPath('status', true)
            ->assertJsonPath('data.requires_verification', true)
            ->assertJsonPath('data.email', 'newmember@example.com');

        $user = User::where('email', 'newmember@example.com')->firstOrFail();
        $this->assertNull($user->email_verified_at);
        $this->assertNotEmpty($user->email_verification_code_hash);

        Queue::assertPushed(SendEmailVerificationJob::class, 1);

        // Extract OTP from queued job & execute handle() to confirm Mailable rendering
        $otp = null;
        Queue::assertPushed(SendEmailVerificationJob::class, function (SendEmailVerificationJob $job) use (&$otp) {
            $ref = new \ReflectionClass($job);
            $otpProp = $ref->getProperty('otp');
            $otpProp->setAccessible(true);
            $otp = (string) $otpProp->getValue($job);
            $job->handle();
            return true;
        });

        $this->assertMatchesRegularExpression('/^[0-9]{6}$/', (string) $otp);
        Mail::assertSent(EmailVerificationMail::class, fn ($m) => $m->hasTo('newmember@example.com'));

        // 2. Verify OTP marks local user verified and calls users_api internal verify-email
        $this->postJson('/api/auth/verify-email', [
            'email' => 'newmember@example.com',
            'code' => $otp,
        ])->assertOk()->assertJsonPath('status', true);

        $this->assertNotNull($user->fresh()->email_verified_at);

        Http::assertSent(fn (HttpClientRequest $req) => str_ends_with($req->url(), '/api/internal/v1/users/verify-email')
            && ($req->data()['current_email'] ?? null) === 'newmember@example.com');
    }

    public function test_unverified_login_returns_resolved_email_and_resend_dispatches_job(): void
    {
        Queue::fake();

        Http::fake([
            '*/api/v1/auth/login' => Http::response([
                'status' => false,
                'message' => 'Email Anda belum diverifikasi.',
                'error_code' => 'email_not_verified',
                'data' => [
                    'email' => 'pending@example.com',
                    'user' => [
                        'id' => '019a0000-0000-7000-8000-000000000002',
                        'username' => 'pendinguser',
                        'email' => 'pending@example.com',
                        'full_name' => 'Pending User',
                        'is_email_verified' => false,
                    ],
                ],
            ], 403),
        ]);

        // Even when logging in by username, response resolves canonical email
        $loginRes = $this->postJson('/api/auth/login', [
            'email' => 'pendinguser',
            'password' => 'SecretPass123',
        ]);

        $loginRes->assertStatus(403)
            ->assertJsonPath('error_code', 'email_not_verified')
            ->assertJsonPath('data.email', 'pending@example.com');

        // Resend verification dispatches job onto Queue
        $this->postJson('/api/auth/resend-verification', [
            'email' => 'pending@example.com',
        ])->assertOk()->assertJsonPath('status', true);

        Queue::assertPushed(SendEmailVerificationJob::class, 1);
    }

    public function test_new_google_social_login_syncs_temp_password_and_queues_email(): void
    {
        Queue::fake();
        Mail::fake();

        Http::fake([
            '*/api/v1/auth/social' => Http::response([
                'status' => true,
                'message' => 'Login Google berhasil.',
                'data' => [
                    'is_new_user' => true,
                    'user' => [
                        'id' => '019a0000-0000-7000-8000-000000000003',
                        'username' => 'googlecreator',
                        'email' => 'googlecreator@example.com',
                        'full_name' => 'Google Creator',
                        'is_email_verified' => true,
                    ],
                ],
            ], 200),
            '*/api/internal/v1/users/set-password' => Http::response([
                'status' => true,
            ], 200),
        ]);

        $res = $this->postJson('/api/auth/social', [
            'provider' => 'google',
            'id_token' => 'fake-google-id-token',
        ]);

        $res->assertOk()
            ->assertJsonPath('status', true)
            ->assertJsonPath('data.is_new_user', true);

        Queue::assertPushed(SendSocialLoginPasswordJob::class, function (SendSocialLoginPasswordJob $job) {
            $job->handle();
            return true;
        });

        Mail::assertSent(SocialLoginPasswordMail::class, fn ($m) => $m->hasTo('googlecreator@example.com'));

        Http::assertSent(function (HttpClientRequest $req) {
            return str_ends_with($req->url(), '/api/internal/v1/users/set-password')
                && ($req->data()['current_email'] ?? null) === 'googlecreator@example.com'
                && strlen((string) ($req->data()['password'] ?? '')) >= 8;
        });
    }

    public function test_forgot_password_queues_reset_mail_and_reset_password_updates_and_revokes_sessions(): void
    {
        Queue::fake();
        Mail::fake();

        $shadow = User::factory()->create([
            'name' => 'Lupa Sandi',
            'username' => 'lupasandi',
            'email' => 'lupasandi@example.com',
            'email_verified_at' => null,
        ]);

        UserSession::create([
            'user_id' => $shadow->id,
            'token_hash' => hash('sha256', 'old-refresh-token'),
            'family_id' => 'fam-1',
            'expires_at' => now()->addDays(7),
        ]);

        Http::fake([
            '*/api/internal/v1/auth/password-reset/request' => Http::response([
                'status' => true,
                'data' => [
                    'found' => true,
                    'email' => 'lupasandi@example.com',
                    'name' => 'Lupa Sandi',
                    'otp' => '482910',
                ],
            ], 200),
            '*/api/internal/v1/auth/password-reset/confirm' => Http::response([
                'status' => true,
                'message' => 'Kata sandi berhasil diatur ulang. Silakan masuk dengan kata sandi baru Anda.',
                'data' => [
                    'user_id' => $shadow->id,
                    'email' => 'lupasandi@example.com',
                ],
            ], 200),
        ]);

        $this->postJson('/api/auth/forgot-password', [
            'email' => 'lupasandi@example.com',
        ])->assertOk()->assertJsonPath('status', true);

        Queue::assertPushed(SendPasswordResetJob::class, function (SendPasswordResetJob $job) {
            $job->handle();
            return true;
        });

        Mail::assertSent(PasswordResetMail::class, fn ($m) => $m->hasTo('lupasandi@example.com'));

        $this->postJson('/api/auth/reset-password', [
            'email' => 'lupasandi@example.com',
            'code' => '482910',
            'password' => 'NewPassword123!',
            'password_confirmation' => 'NewPassword123!',
        ])->assertOk()->assertJsonPath('status', true);

        $this->assertNotNull($shadow->fresh()->email_verified_at);
        $this->assertNotNull(UserSession::where('user_id', $shadow->id)->first()->revoked_at);
    }

    public function test_forgot_password_fails_closed_when_users_api_is_unavailable(): void
    {
        Queue::fake();

        Http::fake([
            '*/api/internal/v1/auth/password-reset/request' => Http::response([
                'status' => false,
                'message' => 'Down',
            ], 503),
        ]);

        $this->postJson('/api/auth/forgot-password', [
            'email' => 'failclosed@example.com',
        ])->assertStatus(503);

        Queue::assertNothingPushed();
    }
}
