<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\WithFaker;
use Tests\TestCase;
use App\Models\User;

class E2EEKeyTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_update_public_key()
    {
        $user = User::factory()->create();

        $publicKey = "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA\n-----END PUBLIC KEY-----";

        $response = $this->actingAsApi($user)->putJson('/api/user/public-key', [
            'public_key' => $publicKey,
        ]);

        $response->assertStatus(200);
        $response->assertJsonPath('data.public_key', $publicKey);

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'public_key' => $publicKey,
        ]);
    }

    public function test_unauthenticated_request_is_rejected()
    {
        $publicKey = "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA\n-----END PUBLIC KEY-----";

        $response = $this->putJson('/api/user/public-key', [
            'public_key' => $publicKey,
        ]);

        $response->assertStatus(401);
    }

    public function test_reject_private_key()
    {
        $user = User::factory()->create();

        $privateKey = "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0B\n-----END PRIVATE KEY-----";

        $response = $this->actingAsApi($user)->putJson('/api/user/public-key', [
            'public_key' => $privateKey,
        ]);

        $response->assertStatus(422);
        
        $this->assertDatabaseMissing('users', [
            'id' => $user->id,
            'public_key' => $privateKey,
        ]);
    }

    public function test_reject_invalid_format()
    {
        $user = User::factory()->create();

        $response = $this->actingAsApi($user)->putJson('/api/user/public-key', [
            'public_key' => "invalid format string",
        ]);

        $response->assertStatus(422);
    }
}
