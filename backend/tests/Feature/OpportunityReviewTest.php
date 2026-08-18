<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\WithFaker;
use Tests\TestCase;
use App\Models\User;
use App\Models\Opportunity;
use App\Models\OpportunityReview;
use App\Models\CreatorPerformanceEvent;
use Tymon\JWTAuth\Facades\JWTAuth;

class OpportunityReviewTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        // Since we are using UUIDs and JWT Auth, setting up basic things.
    }

    
    public function test_valid_completed_opportunity_review_with_rating_ge_4_awards_bonus()
    {
        $poster = User::factory()->create();
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);

        $opportunity = Opportunity::factory()->create([
            'posted_by' => $poster->id,
            'status' => 'closed',
        ]);

        $response = $this->withHeaders($this->getAuthHeaders($poster))->postJson("/api/opportunities/{$opportunity->id}/reviews", [
            'creator_id' => $creator->id,
            'rating' => 4.5,
            'comment' => 'Great job!',
        ]);

        $response->assertStatus(200);

        $this->assertDatabaseHas('opportunity_reviews', [
            'opportunity_id' => $opportunity->id,
            'reviewer_id' => $poster->id,
            'creator_id' => $creator->id,
            'rating' => 4.5,
        ]);

        $this->assertDatabaseHas('creator_performance_events', [
            'user_id' => $creator->id,
            'event_type' => 'project_rating',
            'bonus_percentage' => 1.0,
        ]);

        // Default performance boost is 0.0, after bonus it should be 1.0 * 1.0 = 1.0
        $this->assertEquals(1.0, $creator->fresh()->performance_boost);
    }

    public function test_valid_completed_opportunity_review_with_rating_lt_4_awards_no_bonus()
    {
        $poster = User::factory()->create();
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);

        $opportunity = Opportunity::factory()->create([
            'posted_by' => $poster->id,
            'status' => 'closed',
        ]);

        $response = $this->withHeaders($this->getAuthHeaders($poster))->postJson("/api/opportunities/{$opportunity->id}/reviews", [
            'creator_id' => $creator->id,
            'rating' => 3.5,
        ]);

        $response->assertStatus(200);

        $this->assertDatabaseMissing('creator_performance_events', [
            'user_id' => $creator->id,
            'event_type' => 'project_rating',
        ]);

        $this->assertEquals(0.0, $creator->fresh()->performance_boost);
    }

    public function test_incomplete_opportunity_cannot_be_reviewed()
    {
        $poster = User::factory()->create();
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);

        $opportunity = Opportunity::factory()->create([
            'posted_by' => $poster->id,
            'status' => 'open',
        ]);

        $response = $this->withHeaders($this->getAuthHeaders($poster))->postJson("/api/opportunities/{$opportunity->id}/reviews", [
            'creator_id' => $creator->id,
            'rating' => 5.0,
        ]);

        $response->assertStatus(400);
        $response->assertJsonFragment(['message' => 'You can only review completed opportunities.']);
    }

    public function test_unauthorized_user_cannot_review()
    {
        $poster = User::factory()->create();
        $otherUser = User::factory()->create();
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);

        $opportunity = Opportunity::factory()->create([
            'posted_by' => $poster->id,
            'status' => 'closed',
        ]);

        $response = $this->withHeaders($this->getAuthHeaders($otherUser))->postJson("/api/opportunities/{$opportunity->id}/reviews", [
            'creator_id' => $creator->id,
            'rating' => 5.0,
        ]);

        $response->assertStatus(403);
    }

    public function test_duplicate_review_is_rejected()
    {
        $poster = User::factory()->create();
        $creator = User::factory()->create(['role' => \App\Enums\RoleType::Creator]);

        $opportunity = Opportunity::factory()->create([
            'posted_by' => $poster->id,
            'status' => 'closed',
        ]);

        // First review
        $this->withHeaders($this->getAuthHeaders($poster))->postJson("/api/opportunities/{$opportunity->id}/reviews", [
            'creator_id' => $creator->id,
            'rating' => 5.0,
        ]);

        // Second review
        $response = $this->withHeaders($this->getAuthHeaders($poster))->postJson("/api/opportunities/{$opportunity->id}/reviews", [
            'creator_id' => $creator->id,
            'rating' => 4.0,
        ]);

        $response->assertStatus(400);
        $response->assertJsonFragment(['message' => 'You have already reviewed this creator for this opportunity.']);

        $eventsCount = CreatorPerformanceEvent::where('user_id', $creator->id)->count();
        $this->assertEquals(1, $eventsCount);
    }
}
