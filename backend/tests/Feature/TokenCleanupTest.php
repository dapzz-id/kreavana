<?php

namespace Tests\Feature;

use App\Models\UserSession;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class TokenCleanupTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = User::create([
            'name' => 'Cleanup Test',
            'username' => 'cleanuptest',
            'email' => 'cleanup@test.com',
            'password' => Hash::make('password123'),
            'role' => \App\Enums\RoleType::User,
        ]);
    }

    public function test_cleanup_does_not_remove_records_required_for_reuse_detection(): void
    {
        // Session 1: Revoked 5 days ago (should NOT be cleaned up because retention is 30 days)
        $session1 = UserSession::create([
            'user_id' => $this->user->id,
            'expires_at' => now()->addDays(30),
            'revoked_at' => now()->subDays(5),
            'last_used_at' => now()->subDays(5),
        ]);
        
        // Session 2: Expired 31 days ago (SHOULD be cleaned up)
        $session2 = UserSession::create([
            'user_id' => $this->user->id,
            'expires_at' => now()->subDays(31),
            'last_used_at' => now()->subDays(31),
        ]);

        Artisan::call('auth:cleanup-sessions', ['--days' => 30]);

        $this->assertDatabaseHas('user_sessions', ['id' => $session1->id]);
        $this->assertDatabaseMissing('user_sessions', ['id' => $session2->id]);
    }

    public function test_cleanup_is_idempotent(): void
    {
        UserSession::create([
            'user_id' => $this->user->id,
            'expires_at' => now()->subDays(31),
            'last_used_at' => now()->subDays(31),
        ]);

        // Run once
        Artisan::call('auth:cleanup-sessions', ['--days' => 30]);
        $this->assertDatabaseCount('user_sessions', 0);

        // Run again
        $exitCode = Artisan::call('auth:cleanup-sessions', ['--days' => 30]);
        $this->assertEquals(0, $exitCode); // Should succeed without errors
    }
}
