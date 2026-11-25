<?php

namespace Tests\Feature;

use App\Enums\RoleType;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Middleware\TrustHosts;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Exception\SuspiciousOperationException;
use Tests\TestCase;

class LaravelAdvisoryHardeningTest extends TestCase
{
    use RefreshDatabase;

    public function test_deeply_nested_and_malformed_json_payloads_are_rejected_with_400(): void
    {
        $deep = '"leaf"';
        for ($i = 0; $i < 20; $i++) {
            $deep = '{"nested":' . $deep . '}';
        }

        $resDeep = $this->call(
            'POST',
            '/api/login',
            [],
            [],
            [],
            $this->transformHeadersToServerVars([
                'Accept' => 'application/json',
                'Content-Type' => 'application/json',
            ]),
            $deep
        );
        $resDeep->assertStatus(400)
            ->assertJsonPath('status', false);

        $resMalformed = $this->call(
            'POST',
            '/api/login',
            [],
            [],
            [],
            $this->transformHeadersToServerVars([
                'Accept' => 'application/json',
                'Content-Type' => 'application/json',
            ]),
            '{"email": "broken"'
        );
        $resMalformed->assertStatus(400)
            ->assertJsonPath('status', false);
    }

    public function test_empty_string_json_keys_and_null_bytes_are_rejected_with_422(): void
    {
        $emptyRootKey = '{"":"bypass","email":"test@kreavana.com","password":"secret"}';
        $resEmpty = $this->call(
            'POST',
            '/api/login',
            [],
            [],
            [],
            $this->transformHeadersToServerVars([
                'Accept' => 'application/json',
                'Content-Type' => 'application/json',
            ]),
            $emptyRootKey
        );
        $resEmpty->assertStatus(422)
            ->assertJsonPath('status', false);

        $nestedEmptyKey = '{"order":{"":1}}';
        $resNested = $this->call(
            'PUT',
            '/api/portfolio/reorder',
            [],
            [],
            [],
            $this->transformHeadersToServerVars([
                'Accept' => 'application/json',
                'Content-Type' => 'application/json',
            ]),
            $nestedEmptyKey
        );
        $resNested->assertStatus(422)
            ->assertJsonPath('status', false);

        $nullByte = '{"email":"user\u0000@kreavana.com","password":"secret"}';
        $resNull = $this->call(
            'POST',
            '/api/login',
            [],
            [],
            [],
            $this->transformHeadersToServerVars([
                'Accept' => 'application/json',
                'Content-Type' => 'application/json',
            ]),
            $nullByte
        );
        $resNull->assertStatus(422)
            ->assertJsonPath('status', false);
    }

    public function test_wildcard_array_validation_rejects_associative_keys_and_accepts_list(): void
    {
        $creator = User::factory()->create([
            'role' => RoleType::Creator,
            'is_creator_approved' => 1,
        ]);

        // Associative key attempt on order.* must fail validation due to 'list' rule
        $this->actingAsApi($creator)
            ->putJson('/api/portfolio/reorder', [
                'order' => ['non_numeric_index' => 1, 'another_key' => 2],
            ])
            ->assertStatus(422);

        // Duplicate IDs must fail due to 'distinct' rule
        $this->actingAsApi($creator)
            ->putJson('/api/portfolio/reorder', [
                'order' => [10, 10],
            ])
            ->assertStatus(422);

        // Valid sequential integer list succeeds cleanly
        $this->actingAsApi($creator)
            ->putJson('/api/portfolio/reorder', [
                'order' => [10, 20],
            ])
            ->assertOk()
            ->assertJsonPath('status', true);
    }

    public function test_trusted_hosts_allow_kreavana_domains_and_reject_spoofed_host(): void
    {
        $trustHosts = new TrustHosts($this->app);
        $patterns = array_filter($trustHosts->hosts());
        $this->assertNotEmpty($patterns);

        try {
            Request::setTrustedHosts($patterns);

            $prodReq = Request::create('https://api.kreavana.com/api/health');
            $this->assertSame('api.kreavana.com', $prodReq->getHost());

            $devReq = Request::create('https://dev-api.kreavana.com/api/health');
            $this->assertSame('dev-api.kreavana.com', $devReq->getHost());

            $localReq = Request::create('http://127.0.0.1:8000/api/health');
            $this->assertSame('127.0.0.1', $localReq->getHost());

            $spoofed = Request::create('https://evil-attacker.example.org/api/health');
            $this->expectException(SuspiciousOperationException::class);
            $spoofed->getHost();
        } finally {
            Request::setTrustedHosts([]);
        }
    }
}
