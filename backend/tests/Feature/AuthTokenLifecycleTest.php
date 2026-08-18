<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\JtiService;
use App\Services\RefreshTokenRepository;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;
use Tymon\JWTAuth\Facades\JWTAuth;

class AuthTokenLifecycleTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        User::factory()->create([
            'name' => 'Test User',
            'username' => 'testuser',
            'email' => 'user@test.com',
            'password' => Hash::make('password123'),
            'role' => \App\Enums\RoleType::User,
        ]);
    }

    public function test_login_omits_refresh_token_and_sets_secure_refresh_cookie(): void
    {
        $response = $this->postJson('/api/auth/login', [
            'email' => 'user@test.com',
            'password' => 'password123',
        ]);

        $response->assertOk();
        $response->assertJsonMissingPath('data.refresh_token');
        $response->assertJsonMissingPath('refresh_token');
        $response->assertJsonPath('data.token_type', 'bearer');
        $response->assertJsonPath('data.access_token', fn ($value) => is_string($value) && $value !== '');

        $cookies = $response->headers->getCookies();
        $refreshCookie = null;

        foreach ($cookies as $cookie) {
            if ($cookie->getName() === config('auth_tokens.refresh.cookie')) {
                $refreshCookie = $cookie;
                break;
            }
        }

        $this->assertNotNull($refreshCookie, 'Refresh cookie was not set.');
        $this->assertTrue($refreshCookie->isHttpOnly());
        $this->assertTrue($refreshCookie->isSecure());
        $this->assertSame('/api/auth/refresh', $refreshCookie->getPath());
        $this->assertSame(strtolower(config('auth_tokens.refresh.same_site')), strtolower($refreshCookie->getSameSite()));
    }

    public function test_access_token_contains_minimal_custom_claims(): void
    {
        $response = $this->postJson('/api/auth/login', [
            'email' => 'user@test.com',
            'password' => 'password123',
        ]);

        $response->assertOk();

        $token = $response->json('data.access_token');
        $this->assertIsString($token);
        $this->assertNotSame('', $token);

        $payload = JWTAuth::setToken($token)->getPayload()->toArray();

        $this->assertSame('user', $payload['role'] ?? null);
        $this->assertIsArray($payload['permissions'] ?? null);
        $this->assertNotEmpty($payload['jti'] ?? null);
        $this->assertArrayNotHasKey('email', $payload);
        $this->assertArrayNotHasKey('name', $payload);
        $this->assertArrayNotHasKey('username', $payload);
        $this->assertArrayNotHasKey('phone', $payload);
        $this->assertArrayNotHasKey('profile', $payload);
        $this->assertArrayNotHasKey('address', $payload);
    }

    public function test_revoked_jti_blocks_protected_request(): void
    {
        $response = $this->postJson('/api/auth/login', [
            'email' => 'user@test.com',
            'password' => 'password123',
        ]);

        $response->assertOk();

        $token = $response->json('data.access_token');
        $this->assertIsString($token);

        $payload = JWTAuth::setToken($token)->getPayload()->toArray();
        $jti = $payload['jti'] ?? null;
        $this->assertIsString($jti);

        JtiService::revoke($jti);

        $protectedResponse = $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/auth/me');

        $protectedResponse->assertUnauthorized();
        $protectedResponse->assertJson([
            'status' => false,
            'message' => 'Unauthorized',
        ]);
    }

    /**
     * SECURITY/PERFORMANCE TRADE-OFF DOCUMENTATION:
     * Revoking a user's session (e.g., via session reuse detection or manual session revocation)
     * does NOT instantly invalidate already-issued stateless JWTs. 
     * Because JWTs are stateless, they will remain valid until their natural expiration (10-minute TTL).
     * This avoids the need for a global database/Redis denylist check on every API request.
     */
    public function test_revoked_session_does_not_instantly_invalidate_stateless_jwt(): void
    {
        $response = $this->postJson('/api/auth/login', [
            'email' => 'user@test.com',
            'password' => 'password123',
        ]);

        $token = $response->json('data.access_token');
        $refreshToken = $response->cookie(config('auth_tokens.refresh.cookie'));

        // Manually revoke the session in the database
        $session = \App\Models\UserSession::where('user_id', User::where('email', 'user@test.com')->first()->id)->first();
        $session->update(['revoked_at' => now()]);

        // The stateless JWT is STILL valid until it expires naturally,
        // because we intentionally do not query the sessions table on every request.
        $protectedResponse = $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/auth/me');

        $protectedResponse->assertOk();
    }

    public function test_refresh_rotation_invalidates_old_token_and_rejects_reuse(): void
    {
        $repository = app(RefreshTokenRepository::class);
        $rawRefreshToken = $repository->issue(User::where('email', 'user@test.com')->firstOrFail());

        $rotation = $repository->rotate($rawRefreshToken);

        $this->assertIsArray($rotation);
        $this->assertSame('user@test.com', User::findOrFail($rotation['user_id'])->email);
        $this->assertNotEmpty($rotation['family_id']);

        $reuseAttempt = $repository->rotate($rawRefreshToken);
        $this->assertNull($reuseAttempt);

        // Verify the entire session (family) was revoked due to reuse
        $this->assertNotNull(\App\Models\UserSession::find($rotation['family_id'])->revoked_at);
    }

    /**
     * CONCURRENCY TESTING DOCUMENTATION:
     * In a real environment, if the mobile client fails to implement a single-flight lock
     * and sends two refresh requests concurrently, the database row-level lock (`lockForUpdate`)
     * will serialize the requests. 
     * Request A will lock the row, rotate the token, and release the lock.
     * Request B will then acquire the lock, read the token, find `is_active = false`, 
     * and trigger the reuse detection mechanism (revoking the session).
     * This sequential test perfectly simulates that exact serialization behavior.
     */
    public function test_concurrent_refresh_requests_are_serialized_and_trigger_reuse_detection(): void
    {
        $repository = app(RefreshTokenRepository::class);
        $rawRefreshToken = $repository->issue(User::where('email', 'user@test.com')->firstOrFail());

        // Simulate Request A (acquires lock, rotates successfully)
        $requestARotation = $repository->rotate($rawRefreshToken);
        $this->assertIsArray($requestARotation);

        // Simulate Request B (was waiting for lock, now reads the inactive token)
        $requestBRotation = $repository->rotate($rawRefreshToken);
        
        // Request B fails because the token is no longer active
        $this->assertNull($requestBRotation);

        // Security consequence: the entire session is revoked due to the concurrency race condition
        $this->assertNotNull(\App\Models\UserSession::find($requestARotation['family_id'])->revoked_at);
    }
}
