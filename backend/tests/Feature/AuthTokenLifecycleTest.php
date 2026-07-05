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

        User::create([
            'name' => 'Test User',
            'username' => 'testuser',
            'email' => 'user@test.com',
            'password' => Hash::make('password123'),
            'role' => 'user',
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
        $this->assertSame('strict', $refreshCookie->getSameSite());
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
    }
}
