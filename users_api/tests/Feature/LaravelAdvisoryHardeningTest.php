<?php

namespace Tests\Feature;

use App\Models\ClientApp;
use App\Models\User;
use App\Models\UserCredential;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Middleware\TrustHosts;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Exception\SuspiciousOperationException;
use Tests\TestCase;
use Tymon\JWTAuth\Facades\JWTAuth;

class LaravelAdvisoryHardeningTest extends TestCase
{
    use RefreshDatabase;

    private string $clientSecret = 'testing_users_api_s2s_hmac_secret_64chars_not_for_production_0001';

    protected function setUp(): void
    {
        parent::setUp();

        ClientApp::create([
            'client_id' => 'kreavana_app',
            'client_name' => 'Kreavana Test App',
            'client_secret' => $this->clientSecret,
            'allowed_scopes' => ['openid', 'profile', 'email', 'phone', 'kyc'],
            'is_active' => true,
        ]);
    }

    private function signedRawHeaders(string $rawJson): array
    {
        $clientId = 'kreavana_app';
        $timestamp = (string) time();
        $signature = hash_hmac('sha256', $clientId . '.' . $timestamp . '.' . $rawJson, $this->clientSecret);

        return [
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'X-Client-Id' => $clientId,
            'X-Timestamp' => $timestamp,
            'X-Correlation-Id' => (string) Str::uuid(),
            'X-Signature' => $signature,
        ];
    }

    public function test_deeply_nested_json_payload_is_rejected_before_controller(): void
    {
        $deep = '"leaf"';
        for ($i = 0; $i < 22; $i++) {
            $deep = '{"a":' . $deep . '}';
        }

        $res = $this->call(
            'POST',
            '/api/v1/auth/login',
            [],
            [],
            [],
            $this->transformHeadersToServerVars($this->signedRawHeaders($deep)),
            $deep
        );

        $res->assertStatus(400)
            ->assertJsonPath('status', false);
    }

    public function test_empty_string_json_key_and_null_byte_are_rejected(): void
    {
        $emptyKeyJson = '{"":"admin","identifier":"user","password":"secret"}';
        $resEmpty = $this->call(
            'POST',
            '/api/v1/auth/login',
            [],
            [],
            [],
            $this->transformHeadersToServerVars($this->signedRawHeaders($emptyKeyJson)),
            $emptyKeyJson
        );
        $resEmpty->assertStatus(422)
            ->assertJsonPath('status', false);

        $nullByteJson = '{"identifier":"user\u0000admin","password":"secret"}';
        $resNull = $this->call(
            'POST',
            '/api/v1/auth/login',
            [],
            [],
            [],
            $this->transformHeadersToServerVars($this->signedRawHeaders($nullByteJson)),
            $nullByteJson
        );
        $resNull->assertStatus(422)
            ->assertJsonPath('status', false);
    }

    public function test_add_address_validates_optional_coordinates_and_ignores_unvalidated_fields(): void
    {
        $user = User::create([
            'username' => 'secuser',
            'email' => 'secuser@kreavana.com',
            'full_name' => 'Sec User',
            'is_active' => true,
            'is_suspended' => false,
        ]);
        UserCredential::create([
            'user_id' => $user->id,
            'password_hash' => Hash::make('StrongPass123!'),
            'is_email_verified' => true,
            'email_verified_at' => now(),
        ]);

        $token = JWTAuth::fromUser($user);

        // Out-of-range latitude must fail validation (previously bypassed via $request->all())
        $badPayload = json_encode([
            'label' => 'Kantor',
            'recipient_name' => 'Sec User',
            'phone_number' => '08123456789',
            'street_address' => 'Jl. Sudirman No. 1',
            'city' => 'Jakarta',
            'state' => 'DKI Jakarta',
            'postal_code' => '10220',
            'latitude' => 999.99,
        ], JSON_UNESCAPED_SLASHES);

        $headers = array_merge(
            $this->signedRawHeaders($badPayload),
            ['Authorization' => 'Bearer ' . $token]
        );

        $resBad = $this->call(
            'POST',
            '/api/v1/profile/addresses',
            [],
            [],
            [],
            $this->transformHeadersToServerVars($headers),
            $badPayload
        );
        $resBad->assertStatus(422);

        // Attempt to mass-assign another user_id must be ignored and stay bound to authenticated user
        $otherId = (string) Str::uuid();
        $goodPayload = json_encode([
            'user_id' => $otherId,
            'label' => 'Kantor',
            'recipient_name' => 'Sec User',
            'phone_number' => '08123456789',
            'street_address' => 'Jl. Sudirman No. 1',
            'city' => 'Jakarta',
            'state' => 'DKI Jakarta',
            'postal_code' => '10220',
            'latitude' => -6.2088,
            'longitude' => 106.8456,
        ], JSON_UNESCAPED_SLASHES);

        $goodHeaders = array_merge(
            $this->signedRawHeaders($goodPayload),
            ['Authorization' => 'Bearer ' . $token]
        );

        $resGood = $this->call(
            'POST',
            '/api/v1/profile/addresses',
            [],
            [],
            [],
            $this->transformHeadersToServerVars($goodHeaders),
            $goodPayload
        );
        $resGood->assertStatus(201)
            ->assertJsonPath('data.user_id', $user->id);
    }

    public function test_trusted_hosts_allow_kreavana_and_reject_spoofed_host(): void
    {
        $trustHosts = new TrustHosts($this->app);
        $patterns = array_filter($trustHosts->hosts());
        $this->assertNotEmpty($patterns);

        try {
            Request::setTrustedHosts($patterns);

            $legit = Request::create('https://auth-dev.kreavana.com/api/health');
            $this->assertSame('auth-dev.kreavana.com', $legit->getHost());

            $spoofed = Request::create('https://evil-attacker.example.org/api/health');
            $this->expectException(SuspiciousOperationException::class);
            $spoofed->getHost();
        } finally {
            Request::setTrustedHosts([]);
        }
    }
}
