<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Models\User;
use App\Models\Opportunity;
use App\Models\OpportunityApplication;
use Tymon\JWTAuth\Facades\JWTAuth;
use Illuminate\Support\Str;

class OpportunityApplicationsTest extends TestCase
{
    use RefreshDatabase;

    protected function getAuthHeaders(User $user): array
    {
        $token = JWTAuth::fromUser($user);
        return ['Authorization' => "Bearer {$token}"];
    }

    public function test_owner_can_get_opportunity_applications()
    {
        $client = User::factory()->create([
            'role' => \App\Enums\RoleType::User,
        ]);

        $creator = User::factory()->create([
            'role' => \App\Enums\RoleType::Creator,
        ]);

        $opp = Opportunity::create([
            'id' => Str::uuid(),
            'title' => 'Test Opportunity',
            'sub_role_slug' => 'fotografi',
            'type' => 'project',
            'posted_by' => $client->id,
            'status' => 'open',
        ]);

        $app = OpportunityApplication::create([
            'id' => Str::uuid(),
            'opportunity_id' => $opp->id,
            'creator_id' => $creator->id,
            'sub_role_slug' => 'fotografi',
            'pitch_message' => 'Saya berpengalaman dalam fotografi.',
            'status' => 'pending',
        ]);

        $response = $this->withHeaders($this->getAuthHeaders($client))
            ->getJson("/api/opportunities/{$opp->id}/applications");

        $response->assertStatus(200);
        $response->assertJsonStructure([
            'status',
            'message',
            'data' => [
                '*' => [
                    'id',
                    'opportunity_id',
                    'creator' => [
                        'id',
                        'name',
                        'username',
                        'avatar_url',
                        'sub_role',
                        'rating',
                        'subscription_tier',
                        'is_verified',
                        'completed_projects_count',
                    ],
                    'sub_role_slug',
                    'pitch_message',
                    'status',
                ]
            ]
        ]);

        $this->assertCount(1, $response->json('data'));
    }

    public function test_non_owner_is_denied()
    {
        $owner = User::factory()->create();
        $stranger = User::factory()->create();

        $opp = Opportunity::create([
            'id' => Str::uuid(),
            'title' => 'Test Opportunity',
            'sub_role_slug' => 'fotografi',
            'type' => 'project',
            'posted_by' => $owner->id,
            'status' => 'open',
        ]);

        $response = $this->withHeaders($this->getAuthHeaders($stranger))
            ->getJson("/api/opportunities/{$opp->id}/applications");

        $response->assertStatus(403);
    }
}
